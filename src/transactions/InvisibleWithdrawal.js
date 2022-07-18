const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");
const { Note } = require("../notes/Notes");
const { UINT_128_MAX } = require("starknet/dist/utils/uint256");

module.exports = class InvisibleWithdrawal {
  // & The constructor argumentsare public inputs retrieved from the blockchain.
  constructor(withdraw_id, token, amount, stark_key, notesIn, refundNote) {
    this.transactionType = "withdrawal";
    this.withdraw_id = withdraw_id;
    this.withdraw_token = token;
    this.withdraw_amount = amount;
    this.stark_key = stark_key;
    // ==================================
    this.notesIn = notesIn;
    this.refundNote = refundNote;
    this.signatures = null;
  }

  // * EXECUTING AND UPDATING STATE =====================

  executeWithdrawal(batchInitTree, tree, preimage, updatedNoteHashes) {
    let amountSum = this.notesIn.reduce((acc, note) => {
      if (note.token !== this.withdraw_token) {
        throw new Error("Notes do not match withdrawal token");
      }
      return acc + note.amount;
    }, 0n);

    if (amountSum !== this.withdraw_amount + this.refundNote.amount) {
      throw new Error("Notes do not match withdrawal and refund amount");
    }

    // ? Verify signature
    this.verifySignatures();

    // ? Update state
    this.updateStateAfterwithdraw(
      batchInitTree,
      tree,
      preimage,
      updatedNoteHashes
    );
  }

  updateStateAfterwithdraw(batchInitTree, tree, preimage, updatedNoteHashes) {
    // ? get previous state tree merkle paths
    let preimages = this.getInitStatePreimageProofs(
      batchInitTree,
      this.notesIn
    );
    for (let i = 0; i < preimages.length; i++) {
      preimages[i].forEach((value, key) => {
        preimage[key] = value;
      });
    }

    // ?assert notes exist in the tree
    for (let i = 0; i < this.notesIn.length; i++) {
      if (tree.leafNodes[this.notesIn[i].index] !== this.notesIn[i].hash) {
        console.log(tree.leafNodes);
        console.log(this.notesIn[i].index, this.notesIn[i].hash);
        throw new Error("Note does not exist in the tree");
      }
    }

    // ? Update the state tree
    let proof = tree.getProof(this.notesIn[0].index);
    tree.updateNode(this.refundNote.hash, this.refundNote.index, proof.proof);
    updatedNoteHashes[this.notesIn[0].index] = {
      leafHash: this.refundNote.hash,
      proof: proof,
    };

    for (let i = 1; i < this.notesIn.length; i++) {
      let note = this.notesIn[i];
      let proof = tree.getProof(note.index);
      tree.updateNode(0, note.index, proof.proof);
      updatedNoteHashes[note.index] = {
        leafHash: 0,
        proof: proof,
      };
    }
  }

  getInitStatePreimageProofs(tree, notesIn) {
    let preimages = [];
    for (let i = 0; i < notesIn.length; i++) {
      let idx = notesIn[i].index;
      let { proof, proofPos } = tree.getProof(idx);
      let multiUpdateProof = tree.getMultiUpdateProof(
        notesIn[i].hash,
        proof,
        proofPos
      );
      preimages.push(multiUpdateProof);
    }

    return preimages;
  }

  // * SIGNATURES =======================================
  signwithdrawTransaction(privKeys) {
    let withdrawHash = this.hashWithdrawalTransaction();

    // & privKeys[i] should be the private key of this.notes[i].address_pk
    let signatures = privKeys.map((privKey) => {
      let keyPair = getKeyPair(privKey);
      return sign(keyPair, withdrawHash.toString(16));
    });

    this.signatures = signatures;
  }

  verifySignatures() {
    let withdrawHash = this.hashWithdrawalTransaction();

    for (let i = 0; i < this.notesIn[i].length; i++) {
      let keyPair = getKeyPairFromPublicKey(this.notesIn[i].address_pk);

      if (!verify(keyPair, withdrawHash.toString(16), this.signatures[i])) {
        throw new Error("Invalid signature");
      }
    }

    console.log("Signatures verified");
  }

  hashWithdrawalTransaction() {
    let noteHashes = this.notesIn.map((note) => note.hash);
    let refundNoteHash = this.refundNote.hash;

    return computeHashOnElements(
      [
        this.withdraw_id,
        this.withdraw_token,
        this.withdraw_amount,
        BigInt("0x" + this.stark_key.encode("hex", true).slice(2), 16),
        refundNoteHash,
      ].concat(noteHashes)
    );
  }

  // * JSON ============================================
  toInputObject() {
    let inputObject = {};

    let on_chain_withdraw_info = {
      withdraw_id: this.withdraw_id,
      token: this.withdraw_token,
      amount: this.withdraw_amount,
      stark_key: this.stark_key.getX().toString(),
    };

    inputObject.transactionType = this.transactionType;
    inputObject.on_chain_withdraw_info = on_chain_withdraw_info;
    inputObject.notesIn = this.notesIn.map((note) => note.toInputObject());
    inputObject.refund_note = this.refundNote.toInputObject();
    inputObject.signatures = this.signatures;

    return inputObject;
  }
};
