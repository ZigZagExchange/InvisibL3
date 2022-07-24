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
const MAX_ORDER_ID = 2n ** 32n;
const MAX_EXPIRATION_TIMESTAMP = 2n ** 32n;

// A private limit Order class
module.exports = class InvisibleSwap {
  constructor(
    orderA,
    orderB,
    spentAmountA,
    spentAmountB,
    feeTakenA,
    feeTakenB
  ) {
    this.transactionType = "swap";
    this.orderA = orderA;
    this.orderB = orderB;
    this.spentAmountA = spentAmountA;
    this.spentAmountB = spentAmountB;
    this.feeTakenA = feeTakenA;
    this.feeTakenB = feeTakenB;
    this.indexes = {};
  }

  // * EXECUTING AND UPDATING STATE ====================================================
  executeSwap(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes,
    jsonArgumentInput
  ) {
    this._consistencyChecks();

    this._rangeChecks();

    const isFirstFillA = this.orderA.amountFilled == 0;
    const isFirstFillB = this.orderB.amountFilled == 0;

    // ? Check the sum of notes in matches refund and output amounts
    if (isFirstFillA) {
      // ? if this is the first fill
      this._checkNoteSums(this.orderA);
      if (this.orderA.notesIn[0].index !== this.orderA.refund_note.index) {
        throw new Error(
          "refund note index is not the same as the first note index"
        );
      }
    } else {
      // ? if order was partially filled befor
      this._checkPrevFillConsistencies(this.orderA, this.spentAmountA);
    }

    if (isFirstFillB) {
      // ? if this is the first fill
      this._checkNoteSums(this.orderB);
      if (this.orderB.notesIn[0].index !== this.orderB.refund_note.index) {
        throw new Error(
          "refund note index is not the same as the first note index"
        );
      }
    } else {
      // ? if order was partially filled before
      this._checkPrevFillConsistencies(this.orderB, this.spentAmountB);
    }

    // Todo: could also just be done the first fill
    // ? Verify that the order were signed correctly
    this.orderA.verify_order_signatures();
    this.orderB.verify_order_signatures();

    // ? Get indexes and create new swap notes
    let zeroIdxs = tree.firstNZeroIdxs(4);

    // & if this is the first fill return either the second note index or an empty index
    // & if this is a later fill return the partialFillRefundNote index
    let swapNoteAIdx = isFirstFillA
      ? this.orderA.notesIn.length > 1
        ? this.orderA.notesIn[1].index
        : zeroIdxs[0]
      : this.orderA.partialFillRefundNote.index;

    let swapNoteA = new Note(
      this.orderA.dest_received_address,
      this.orderA.token_received,
      this.spentAmountB - this.feeTakenA,
      this.orderA.blinding_seed,
      swapNoteAIdx
    );

    let swapNoteBIdx = isFirstFillB
      ? this.orderB.notesIn.length > 1
        ? this.orderB.notesIn[1].index
        : zeroIdxs[1]
      : this.orderB.partialFillRefundNote.index;

    let swapNoteB = new Note(
      this.orderB.dest_received_address,
      this.orderB.token_received,
      this.spentAmountA - this.feeTakenB,
      this.orderB.blinding_seed,
      swapNoteBIdx
    );

    this.orderA.amountFilled += this.spentAmountB;

    let newPartialRefundNoteA = null;
    if (this.orderA.amount_received > this.orderA.amountFilled) {
      //? Order A was partially filled, we must refund the rest

      let prIndex =
        this.orderA.notesIn.length > 2 && isFirstFillA
          ? this.orderA.notesIn[2].index
          : zeroIdxs[2];

      this._refundPartialFill(
        this.orderA,
        isFirstFillA,
        this.spentAmountA,
        prIndex
      );
      newPartialRefundNoteA = this.orderA.partialFillRefundNote;
    }

    this.orderB.amountFilled += this.spentAmountA;

    let newPartialRefundNoteB = null;
    if (this.orderB.amount_received > this.orderB.amountFilled) {
      //? Order B was partially filled, we must refund the rest

      let prIndex =
        this.orderB.notesIn.length > 2 && isFirstFillB
          ? this.orderB.notesIn[2].index
          : zeroIdxs[3];

      this._refundPartialFill(
        this.orderB,
        isFirstFillB,
        this.spentAmountB,
        prIndex
      );
      newPartialRefundNoteB = this.orderB.partialFillRefundNote;
    }

    //
    //
    //

    this.indexes = {
      order_A: {
        swap_note_idx: swapNoteA.index,
        partial_fill_idx: newPartialRefundNoteA
          ? newPartialRefundNoteA.index
          : null,
      },
      order_B: {
        swap_note_idx: swapNoteB.index,
        partial_fill_idx: newPartialRefundNoteB
          ? newPartialRefundNoteB.index
          : null,
      },
    };

    //
    //
    //

    // ? Update the state for order A
    if (isFirstFillA) {
      this.updateStateAfterSwapFirstFill(
        batchInitTree,
        tree,
        preimage,
        updatedNoteHashes,
        this.orderA.notesIn,
        this.orderA.refund_note,
        swapNoteA,
        newPartialRefundNoteA
      );
    } else {
      console.log("swap note A: ", swapNoteA);
      console.log("newPartialRefundNoteA: ", newPartialRefundNoteA);
      console.log("partialFillRefundNote: ", this.orderA.partialFillRefundNote);
      this.updateStateAfterSwapLaterFills(
        batchInitTree,
        tree,
        preimage,
        updatedNoteHashes,
        this.orderA.partialFillRefundNote,
        swapNoteA,
        newPartialRefundNoteA
      );
    }

    // ? Update the state for order B
    if (isFirstFillB) {
      this.updateStateAfterSwapFirstFill(
        batchInitTree,
        tree,
        preimage,
        updatedNoteHashes,
        this.orderB.notesIn,
        this.orderB.refund_note,
        swapNoteB,
        newPartialRefundNoteB
      );
    } else {
      this.updateStateAfterSwapLaterFills(
        batchInitTree,
        tree,
        preimage,
        updatedNoteHashes,
        this.orderB.partialFillRefundNote,
        swapNoteB,
        newPartialRefundNoteB
      );
    }

    return {
      swapNoteA,
      swapNoteB,
      newPartialRefundNoteA,
      newPartialRefundNoteB,
    };
  }

  // ! FIRST FILL UPDATES ------ ------- ------ ------ -------- -------- --------
  updateStateAfterSwapFirstFill(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes,
    notesIn,
    refundNote,
    swapNote,
    partialFillRefundNote
  ) {
    // & takes in batchInitTree, which is the tree from the end of the previous batch,
    // &  the current state tree and the dict of preimages
    // & It updates the state tree and gets new merkle proofs for the preimage dict for one order

    // ? get the merkle paths for previous state tree
    this.getInitStatePreimageProofsFirstFill(
      batchInitTree,
      preimage,
      notesIn,
      swapNote.index,
      partialFillRefundNote
    );

    // ? assert notes exist in the tree
    for (let i = 0; i < notesIn.length; i++) {
      if (tree.leafNodes[notesIn[i].index] !== notesIn[i].hash) {
        console.log(tree.leafNodes);
        console.log(notesIn[i].index, notesIn[i].hash);
        throw new Error("Note does not exist in the tree");
      }
    }

    // ? Update the state tree
    let firstProof = tree.getProof(refundNote.index);
    tree.updateNode(refundNote.hash, refundNote.index, firstProof.proof);
    updatedNoteHashes[refundNote.index] = {
      leafHash: refundNote.hash,
      proof: firstProof,
    };

    let secondProof = tree.getProof(swapNote.index);
    tree.updateNode(swapNote.hash, swapNote.index, secondProof.proof);
    updatedNoteHashes[swapNote.index] = {
      leafHash: swapNote.hash,
      proof: secondProof,
    };

    if (partialFillRefundNote) {
      let { proof, proofPos } = tree.getProof(partialFillRefundNote.index);
      tree.updateNode(
        partialFillRefundNote.hash,
        partialFillRefundNote.index,
        proof
      );
      updatedNoteHashes[partialFillRefundNote.index] = {
        leafHash: partialFillRefundNote.hash,
        proof: { proof, proofPos },
      };
    } else if (notesIn.length > 2) {
      let { proof, proofPos } = tree.getProof(notesIn[2].index);
      tree.updateNode(0, notesIn[2].index, proof);
      updatedNoteHashes[notesIn[2].index] = {
        leafHash: 0,
        proof: { proof, proofPos },
      };
    }
    for (let i = 3; i < notesIn.length; i++) {
      let { proof, proofPos } = tree.getProof(notesIn[i].index);
      tree.updateNode(0, notesIn[i].index, proof);
      updatedNoteHashes[notesIn[i].index] = {
        leafHash: 0,
        proof: { proof, proofPos },
      };
    }
  }

  getInitStatePreimageProofsFirstFill(
    tree,
    preimage,
    notesIn,
    swapNoteIdx,
    partialFillRefundNote
  ) {
    let preimages = [];
    for (let i = 0; i < notesIn.length; i++) {
      let note = notesIn[i];
      let { proof, proofPos } = tree.getProof(note.index);
      let multiUpdateProof = tree.getMultiUpdateProof(
        note.hash,
        proof,
        proofPos
      );
      preimages.push(multiUpdateProof);
    }

    // If less input notes also get proofs for zero leaves at the correct indexes
    if (notesIn.length < 3 && partialFillRefundNote) {
      let { proof, proofPos } = tree.getProof(partialFillRefundNote.index);
      let multiUpdateProof = tree.getMultiUpdateProof(0, proof, proofPos);
      preimages.push(multiUpdateProof);
    }
    if (notesIn.length < 2) {
      let { proof, proofPos } = tree.getProof(swapNoteIdx);
      let multiUpdateProof = tree.getMultiUpdateProof(0, proof, proofPos);
      preimages.push(multiUpdateProof);
    }

    for (let i = 0; i < preimages.length; i++) {
      preimages[i].forEach((value, key) => {
        preimage[key] = value;
      });
    }
  }

  // ! LATER FILL UPDATES ------ ------- ------ ------ -------- -------- --------

  updateStateAfterSwapLaterFills(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes,
    prevPartialFillRefundNote,
    swapNote,
    newPartialFillRefundNote
  ) {
    // ? get the merkle paths for previous state tree
    this.getInitStatePreimageProofsLaterFills(
      batchInitTree,
      preimage,
      prevPartialFillRefundNote
    );

    // ? assert note exist in the tree
    if (
      tree.leafNodes[prevPartialFillRefundNote.index] !==
      prevPartialFillRefundNote.hash
    ) {
      console.log(tree.leafNodes);
      console.log(
        prevPartialFillRefundNote.index,
        prevPartialFillRefundNote.hash
      );
      throw new Error("Note does not exist in the tree");
    }

    // ? Update the state tree
    let firstProof = tree.getProof(swapNote.index);
    tree.updateNode(swapNote.hash, swapNote.index, firstProof.proof);
    updatedNoteHashes[swapNote.index] = {
      leafHash: swapNote.hash,
      proof: firstProof,
    };

    if (newPartialFillRefundNote) {
      let { proof, proofPos } = tree.getProof(newPartialFillRefundNote.index);
      tree.updateNode(
        newPartialFillRefundNote.hash,
        newPartialFillRefundNote.index,
        proof
      );
      updatedNoteHashes[newPartialFillRefundNote.index] = {
        leafHash: newPartialFillRefundNote.hash,
        proof: { proof, proofPos },
      };
    }
  }

  getInitStatePreimageProofsLaterFills(tree, preimage, partialFillRefundNote) {
    if (partialFillRefundNote) {
      let { proof, proofPos } = tree.getProof(partialFillRefundNote.index);
      let multiUpdateProof = tree.getMultiUpdateProof(0, proof, proofPos);

      multiUpdateProof.forEach((value, key) => {
        preimage[key] = value;
      });
    }
  }

  // * HELPER FUNCTIONS ================================================================
  _checkNoteSums(order) {
    let sumNotesA = order.notesIn.reduce((acc, note) => {
      if (note.token !== order.token_spent) {
        throw "spending wrong token";
      }
      return acc + note.amount;
    }, 0n);

    if (sumNotesA < order.refund_note.amount + order.amount_spent) {
      throw new Error("sum of inputs is to small for this order");
    }
  }

  _checkPrevFillConsistencies(order, spendAmountX) {
    if (order.partialFillRefundNote.token !== order.token_spent) {
      throw new Error("spending wrong token");
    }

    if (order.partialFillRefundNote.amount < spendAmountX) {
      throw new Error("refund note amount is to small for this swap");
    }
  }

  _refundPartialFill(order, isFirstFill, spentAmountX, index) {
    let partialRefundAmount = isFirstFill
      ? order.amount_spent - spentAmountX
      : order.partialFillRefundNote.amount - spentAmountX;

    order.partialFillRefundNote = new Note(
      order.dest_spent_address,
      order.token_spent,
      partialRefundAmount,
      order.blinding_seed,
      index
    );
  }

  _consistencyChecks() {
    // ? Check that the tokens swapped match
    if (
      this.orderA.token_spent !== this.orderB.token_received ||
      this.orderA.token_received !== this.orderB.token_spent
    ) {
      throw new Error("Tokens swapped do not match");
    }

    // ? Check that the amounts swapped dont exceed the order amounts
    if (
      this.orderA.amount_spent < this.spentAmountA ||
      this.orderB.amount_spent < this.spentAmountB
    ) {
      throw new Error("Amounts swapped exceed order amounts");
    }

    // ? Check that the fees taken dont exceed the order fees
    if (
      this.feeTakenA * this.orderA.amount_received >
        this.orderA.fee_limit * this.spentAmountB ||
      this.feeTakenB * this.orderB.amount_received >
        this.orderB.fee_limit * this.spentAmountA
    ) {
      throw new Error("Fees taken exceed order fees");
    }

    // ? Verify consistency of amounts swaped
    if (
      this.spentAmountA * this.orderA.amount_received >
        this.spentAmountB * this.orderA.amount_spent ||
      this.spentAmountB * this.orderB.amount_received >
        this.spentAmountA * this.orderB.amount_spent
    ) {
      throw new Error("Amount swapped ratios");
    }
  }

  _rangeChecks() {
    if (
      this.spentAmountA > MAX_AMOUNT ||
      this.spentAmountB > MAX_AMOUNT ||
      this.orderA.orderId > MAX_ORDER_ID ||
      this.orderB.orderId > MAX_ORDER_ID ||
      this.orderA.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP ||
      this.orderB.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
    ) {
      throw new Error("Range checks failed");
    }
  }

  // * JSON ============================================================================
  toInputObject() {
    let inputObject = {};

    inputObject.transactionType = this.transactionType;
    inputObject.orderA = this.orderA.toInputObject();
    inputObject.orderB = this.orderB.toInputObject();
    inputObject.spend_amountA = this.spentAmountA;
    inputObject.spend_amountB = this.spentAmountB;
    inputObject.fee_takenA = this.feeTakenA;
    inputObject.fee_takenB = this.feeTakenB;
    inputObject.indexes = this.indexes;

    // inputObject = JSON.stringify(inputObject, (key, value) => {
    //   return typeof value === "bigint" ? value.toString() : value;
    // });

    return inputObject;
  }
};
