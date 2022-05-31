const poseidon = require("../../circomlib/src/poseidon.js");
const ecMul = require("../../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../../circomlib/src/babyjub.js").subPoint;
const G = require("../../circomlib/src/babyjub.js").Generator;
const H = require("../../circomlib/src/babyjub.js").Base8;
const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

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
    //! TAKER INPUTS
    // ...takerTx.inputs,
    returnSigA,
    signatureA,
    //! MAKER INPUTS
    // ...makerTx.inputs,
    returnSigB,
    signatureB,
    //! SWAP INPUTS
    //? Could just be replaced with the takerTx and makerTx prices
    tokenX, // taker token out —> sent to the maker  (spent token)
    tokenXPrice,
    tokenY, // maker token out  —> sent to the taker  (received token)
    tokenYPrice
    // pos,   // used for the commitmnt to zero
    // swapQuoteSig // swap quote signature
  ) {
    //* TAKER TRANSACTION:

    //? Verify signatures for public keys and comms to zero

    this.takerTx.verifyPrivReturnAddressSig(
      returnSigA,
      this.makerTx.notesOut[0].address,
      tokenY,
      tokenYPrice
    );

    //? Verify signature for retrun address
    this.takerTx.verifySignature_new(signatureA);

    //? Verify sum of inputs == sum of outputs
    this.takerTx.verifySums();

    //* MAKER TRANSACTION:

    //? Verify signatures for public keys and comms to zero
    this.makerTx.verifyPrivReturnAddressSig(
      returnSigB,
      this.takerTx.notesOut[0].address,
      tokenX,
      tokenXPrice
    );

    //? Verify signature for retrun address
    this.makerTx.verifySignature_new(signatureB);

    //? Verify sum of inputs == sum of outputs
    this.makerTx.verifySums();

    //* SWAP VERIFICATIONS:

    //? a*a_price == b*b_price --> (make comm to zero Ca_out1*a_price - Cb_out1*b_price )
    this.verifyCorrectSwapQuotes(tokenXPrice, tokenYPrice);

    //* NON_CONSTRAINED (not included in the circuit constraints)

    //? check the maker and taker sent the exchange fee (*and stardust)
    // TODO ...

    console.log("swap transaction verified");
  }

  verifyCorrectSwapQuotes(xPrice, yPrice) {
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

  logSwap(returnSigA, signatureA, returnSigB, signatureB) {
    console.log(
      "notesIn_A: ",
      this.takerTx.notesIn.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(
      ",notesOut_A: ",
      this.takerTx.notesOut.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(",pseudoComms_A: ", this.takerTx.pseudo_comms);
    console.log(",pos_A: ", this.takerTx.pos);
    console.log(",tokenSpent_A: ", this.takerTx.tokenSpent);
    console.log(",tokenSpentPrice_A: ", this.takerTx.tokenSpentPrice);
    console.log(",tokenReceived_A: ", this.takerTx.tokenReceived);
    console.log(",tokenReceivedPrice_A: ", this.takerTx.tokenReceivedPrice);
    console.log(",amountsIn_A: ", this.takerTx.amountsIn);
    console.log(",amountsOut_A: ", this.takerTx.amountsOut);
    console.log(",blindingsIn_A: ", this.takerTx.blindingsIn);
    console.log(",blindingsOut_A: ", this.takerTx.blindingsOut);
    console.log(",returnAddressSig_A: ", returnSigA);
    console.log(",signature_A: ", signatureA);

    // console.log("\n=======================================================\n");

    console.log(
      ",notesIn_B: ",
      this.makerTx.notesIn.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(
      ",notesOut_B: ",
      this.makerTx.notesOut.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(",pseudoComms_B: ", this.makerTx.pseudo_comms);
    console.log(",pos_B: ", this.makerTx.pos);
    console.log(",tokenSpent_B: ", this.makerTx.tokenSpent);
    console.log(",tokenSpentPrice_B: ", this.makerTx.tokenSpentPrice);
    console.log(",tokenReceived_B: ", this.makerTx.tokenReceived);
    console.log(",tokenReceivedPrice_B: ", this.makerTx.tokenReceivedPrice);
    console.log(",amountsIn_B: ", this.makerTx.amountsIn);
    console.log(",amountsOut_B: ", this.makerTx.amountsOut);
    console.log(",blindingsIn_B: ", this.makerTx.blindingsIn);
    console.log(",blindingsOut_B: ", this.makerTx.blindingsOut);
    console.log(",returnAddressSig_B: ", returnSigB);
    console.log(",signature_B: ", signatureB);
  }
};
