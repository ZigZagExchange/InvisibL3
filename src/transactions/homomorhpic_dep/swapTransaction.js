const poseidon = require("../../circomlib/src/poseidon.js");
const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

const Secp256k1 = require("@enumatech/secp256k1-js");
const Note = require("../notes/noteUtils.js").Note;
const noteUtils = require("../notes/noteUtils.js");
const Transaction = require("ethereumjs-tx");

//TODO Temporary randomness for one time address
const RAND_SEED = 123456789;
module.exports = class Swap {
  constructor(takerTx, makerTx) {
    this.takerTx = takerTx;
    this.makerTx = makerTx;
  }

  verify(
    signatureA,
    signatureB,
    //? Could just be replaced with the takerTx and makerTx prices
    tokenX, // taker token out —> sent to the maker  (spent token)
    tokenXAmount,
    tokenY, // maker token out  —> sent to the taker  (received token)
    tokenYAmount
  ) {
    //* TAKER TRANSACTION:

    this.takerTx.verifySig(signatureA);
    this.takerTx.verifySums();

    //* MAKER TRANSACTION:

    this.makerTx.verifySig(signatureB);
    this.makerTx.verifySums();

    //* SWAP VERIFICATIONS:

    if (
      this.takerTx.tokenSpent !== tokenX ||
      this.takerTx.tokenReceived !== tokenY ||
      this.makerTx.tokenSpent !== tokenY ||
      this.makerTx.tokenReceived !== tokenX
    ) {
      throw "token types are incorrect";
    }

    if (
      this.takerTx.spentAmount !== tokenXAmount ||
      this.takerTx.receivedAmount !== tokenYAmount ||
      this.makerTx.spentAmount !== tokenYAmount ||
      this.makerTx.receivedAmount !== tokenXAmount
    ) {
      throw "token amounts are incorrect";
    }

    //* NON_CONSTRAINED (not included in the circuit constraints)

    //Todo check the maker and taker sent the exchange fee (*and stardust)

    console.log("swap transaction verified");
  }

  // DEPRECATED =============
  signCorrectSwapQuotesCmtz(
    takerAmount,
    makerAmount,
    takerblinding,
    makerblinding,
    aPrice,
    bPrice
  ) {
    let C1_taker = this.takerTx.notesOut[0].commitment;
    let C1_maker = this.makerTx.notesOut[0].commitment;

    const taker_C = ecAdd(ecMul(G, takerblinding), ecMul(H, takerAmount));
    if (taker_C[0] !== C1_taker[0] || taker_C[1] !== C1_taker[1]) {
      throw "taker amount or blinding factor is incorrect";
    }
    const maker_C = ecAdd(ecMul(G, makerblinding), ecMul(H, makerAmount));
    if (maker_C[0] !== C1_maker[0] || maker_C[1] !== C1_maker[1]) {
      throw "maker amount or blinding factor is incorrect";
    }

    if (takerAmount * aPrice !== makerAmount * bPrice) {
      throw "taker and maker amounts are incorrect";
    }

    //make a commitment to zero
    let ws;
    let pos; // 0 if x1 is bigger than x2 and 1 otherwise
    const x1 = takerblinding * aPrice;
    const x2 = makerblinding * bPrice;
    if (x1 > x2) {
      ws = x1 - x2;
      pos = 0;
    } else {
      ws = x2 - x1;
      pos = 1;
    }

    let alpha = randomBigInt(240);
    let aG = ecMul(G, alpha);

    let c = poseidon([pos, aG[0], aG[1]]);

    const r = alpha + ws + c;

    const sig = [c, r];
    return { ws, pos, sig };
  }

  verifyCorrectSwapQuotesCmtz(aPrice, bPrice, pos, swapQuoteSig) {
    let c = swapQuoteSig[0];
    let r = swapQuoteSig[1];

    let C_taker = this.takerTx.notesOut[0].commitment;
    let aC1 = ecMul(C_taker, aPrice);

    let C_maker = this.makerTx.notesOut[0].commitment;
    let bC1 = ecMul(C_maker, bPrice);

    let W = pos ? ecSub(bC1, aC1) : ecSub(aC1, bC1);

    let c_input = ecSub(ecMul(G, r), ecAdd(W, ecMul(G, c)));

    let c_prime = poseidon([pos, c_input[0], c_input[1]]);

    if (c_prime !== c) {
      throw "swap quote signature verification failed";
    } else {
      console.log("swap quote signature verified");
    }
  }

  verifyCorrectSwapQuotes_deprecated(xPrice, yPrice) {
    //? For now we assume that only one output note is addressed to the recipient, later this can be up to four
    let xPx = this.takerTx.amountsOut[0] * xPrice;
    let yPy = this.makerTx.amountsOut[0] * yPrice;

    let diff = xPx - yPy;

    if ((diff * 10n ** 8n) / xPx > 0) {
      throw "taker and maker amounts are incorrect";
    } else {
      console.log("taker and maker amounts are correct");
    }
  }
  // DEPRECATED =============

  logSwap(signatureA, signatureB) {
    this.takerTx.logTransaction(signatureA, "_A");
    this.makerTx.logTransaction(signatureB, "_B");
  }
};
