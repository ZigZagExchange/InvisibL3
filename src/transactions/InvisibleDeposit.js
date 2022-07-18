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

module.exports = class InvisibleDeposit {
  // & The constructor argumentsare public inputs retrieved from the blockchain.
  constructor(deposit_id, token, amount, stark_key, newNotes) {
    this.transactionType = "deposit";
    this.deposit_id = deposit_id;
    this.depositToken = token;
    this.depositAmount = amount;
    this.stark_key = stark_key;
    this.notes = newNotes;
    this.signature = null;
  }

  // * EXECUTING AND UPDATING STATE =====================

  executeDeposit(batchInitTree, tree, preimage, updatedNoteHashes) {
    let zeroIdxs = tree.firstNZeroIdxs(this.notes.length);

    // & Sum the notes and set the zero leaf indexes
    let amountSum = 0n;
    for (let i = 0; i < this.notes.length; i++) {
      if (this.notes[i].token !== this.depositToken) {
        throw new Error("Notes do not match deposit token");
      }
      amountSum += this.notes[i].amount;

      this.notes[i].index = zeroIdxs[i];
    }

    if (amountSum !== this.depositAmount) {
      throw new Error(
        "Amount deposited and newly minted note amounts are inconsistent"
      );
    }

    // ? verify Signature
    this.verifyDepositSignature();

    // ? Update the state
    this.updateStateAfterDeposit(
      batchInitTree,
      tree,
      preimage,
      updatedNoteHashes
    );
  }

  updateStateAfterDeposit(batchInitTree, tree, preimage, updatedNoteHashes) {
    let preimages = this.getInitStatePreimageProofs(batchInitTree, this.notes);
    for (let i = 0; i < preimages.length; i++) {
      preimages[i].forEach((value, key) => {
        preimage[key] = value;
      });
    }

    for (let i = 0; i < this.notes.length; i++) {
      let note = this.notes[i];
      let proof = tree.getProof(note.index);
      tree.updateNode(note.hash, note.index, proof.proof);
      updatedNoteHashes[note.index] = {
        leafHash: note.hash,
        proof: proof,
      };
    }

    return { preimage, updatedNoteHashes };
  }

  getInitStatePreimageProofs(tree, notes) {
    let preimages = [];
    for (let i = 0; i < notes.length; i++) {
      let idx = notes[i].index;
      let { proof, proofPos } = tree.getProof(idx);
      let multiUpdateProof = tree.getMultiUpdateProof(0, proof, proofPos);
      preimages.push(multiUpdateProof);
    }

    return preimages;
  }

  // * SIGNATURES =======================================
  signDeposit(privKey) {
    let depositHash = this.hashDepositTransaction();

    // & privKey should be the private key of this.stark_key
    let keyPair = getKeyPair(privKey);

    this.signature = sign(keyPair, depositHash.toString(16));
  }

  verifyDepositSignature() {
    let depositHash = this.hashDepositTransaction();

    let keyPair = getKeyPairFromPublicKey(this.stark_key);

    // console.log(keyPair.getPublic().getX().toString());

    if (!verify(keyPair, depositHash.toString(16), this.signature)) {
      throw "Invalid signature";
    } else {
      console.log("Signature verified");
    }
  }

  hashDepositTransaction() {
    if (!this.notes) {
      throw "no notes have been created for this deposit";
    }

    let noteHashes = this.notes.map((note) => note.hash);

    return computeHashOnElements([this.deposit_id].concat(noteHashes));
  }

  // * =================================================
  toInputObject() {
    let inputObject = {};

    let on_chain_deposit_info = {
      deposit_id: this.deposit_id,
      token: this.depositToken,
      amount: this.depositAmount,
      stark_key: this.stark_key.getX().toString(),
    };

    inputObject.transactionType = this.transactionType;
    inputObject.on_chain_deposit_info = on_chain_deposit_info;
    inputObject.notes = this.notes.map((note) => note.toInputObject());
    inputObject.signature = this.signature;

    return inputObject;
  }
};
