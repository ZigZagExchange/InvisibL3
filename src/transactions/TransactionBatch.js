const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const randomBigInt = require("random-bigint");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");
const { assert } = require("chai");
const { Note } = require("../notes/Notes");
const Tree = require("../merkle_trees/Tree");
const InvisibleSwap = require("./InvisibleSwap");

const MAX_AMOUNT = 2n ** 90n;
const MAX_NONCE = 2n ** 32n;
const MAX_EXPIRATION_TIMESTAMP = 2n ** 32n;

// A private limit Order class
module.exports = class TransactionBatch {
  // & batchInitTree is the tree at the beginning of the batch used to get preimages for merkleMultiUpdate
  // & currentStateTree is the tree that represents the current state of the system
  // & preimage is the initial state merkle proofs
  // & updatedNoteHashes is a map of leaf indexes to leaf hashes and merkle paths
  constructor(batchInitTree) {
    this.batchInitTree = batchInitTree;
    this.currentStateTree = batchInitTree.clone();
    this.preimage = {};
    this.updatedNoteHashes = {};
    this.numSwaps = 0;
    this.numDeposits = 0;
    this.numWithdrawals = 0;
    this.txInputObjects = [];
  }

  executeTransaction(transaction, jsonArgumentInput) {
    switch (transaction.transactionType) {
      case "withdrawal":
        this.numWithdrawals++;
        transaction.executeWithdrawal(
          this.batchInitTree,
          this.currentStateTree,
          this.preimage,
          this.updatedNoteHashes
        );
        break;

      case "deposit":
        this.numDeposits++;
        transaction.executeDeposit(
          this.batchInitTree,
          this.currentStateTree,
          this.preimage,
          this.updatedNoteHashes
        );
        break;

      case "swap":
        this.numSwaps++;
        transaction.executeSwap(
          this.batchInitTree,
          this.currentStateTree,
          this.preimage,
          this.updatedNoteHashes,
          jsonArgumentInput
        );
        break;

      default:
        throw new Error("Invalid transaction type");
    }

    let txInputObject = transaction.toInputObject();
    this.txInputObjects.push(txInputObject);
  }

  finalizeBatch() {
    // Gets the remaining proofs to be used in proof generation
    let finalizedPreimages = {};

    for (const [key, value] of Object.entries(this.updatedNoteHashes)) {
      let multiUpdateProof = this.currentStateTree.getMultiUpdateProof(
        value.leafHash,
        value.proof.proof,
        value.proof.proofPos
      );

      multiUpdateProof.forEach((value, key) => {
        finalizedPreimages[key] = value;
      });
    }

    this.preimage = { ...this.preimage, ...finalizedPreimages };
  }

  toInputObject() {
    return {
      numSwaps: this.numSwaps,
      numDeposits: this.numDeposits,
      numWithdrawals: this.numWithdrawals,
      transactions: this.txInputObjects,
      preimage: this.preimage,
      prev_root: this.batchInitTree.root,
      new_root: this.currentStateTree.root,
    };
  }
};
