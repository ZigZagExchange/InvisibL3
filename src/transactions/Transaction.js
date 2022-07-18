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

const MAX_AMOUNT = 2n ** 90n;
const MAX_NONCE = 2n ** 32n;
const MAX_EXPIRATION_TIMESTAMP = 2n ** 32n;

// A wrapper class that uses Swap, Deposits and Withdrawal classes
module.exports = class Transaction {
  constructor(transaction) {
    this.transaction = transaction;
    this.txType = transaction.transactionType;
  }

  // & This function verifies the signature, executes the transaction and updates the state
  execute(batchInitTree, tree, preimage, updatedNoteHashes) {
    switch (this.txType) {
      case "deposit":
        this.transaction.executeDeposit(
          batchInitTree,
          tree,
          preimage,
          updatedNoteHashes
        );
        break;

      case "withdrawal":
        this.transaction.executeWithdrawal(
          batchInitTree,
          tree,
          preimage,
          updatedNoteHashes
        );
        break;

      case "swap":
        this.transaction.executeSwap(
          batchInitTree,
          tree,
          preimage,
          updatedNoteHashes
        );
        break;

      default:
        throw new Error("Not one of the valid transaction types");
    }
  }
};
