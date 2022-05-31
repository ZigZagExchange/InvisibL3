const { doesNotMatch } = require("assert");
const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;
// const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
// const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
// const ecSub = require("../circomlib/src/babyjub.js").subPoint;
// const F = require("../circomlib/src/babyjub.js").F;
// const G = require("../circomlib/src/babyjub.js").Generator;
// const H = require("../circomlib/src/babyjub.js").Base8;

const {
  returnAddressSigInputs,
  sumVerificationInputs,
  txHashInputs,
  sumVerificationInputsCmtz,
  txInputs,
  verifySigInputs,
  padSumVerificationInputs,
  padSigVerificationInputs,
  padTxHashInputs,
  padTxInputs,
} = require("./4_transaction_inputs");

const { padSwapInputs } = require("./5_swap_inputs");

const assert = chai.assert;

describe("transaction verification test", function () {
  it("should check verifying return address sig", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(
          __dirname,
          "../../circuits/signatures",
          "verify_ret_addr_sig.circom"
        )
      );
    } catch (e) {
      // console.log(e);
      console.log("Uncomment out main component");
      return;
    }
    // let inputs = returnAddressSigInputs;
    let input = padSwapInputs(5);

    const w = await circuit.calculateWitness({
      c: input.returnAddressSig_A[0],
      r: input.returnAddressSig_A[1],
      tokenReceived: input.tokenReceived_A,
      tokenReceivedPrice: input.tokenReceivedPrice_A,
      Ko: input.Ko_A,
    });

    await circuit.checkConstraints(w);
  }).timeout(10000);
  // // ============================================================
  // it("should check verifying input and output sums by cmtz", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/helpers",
  //         "verify_sums_cmtz.circom"
  //       )
  //     );
  //   } catch (e) {
  //     //   console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     );
  //     return;
  //   }
  //   const inputs = sumVerificationInputsCmtz;
  //   const w = await circuit.calculateWitness({
  //     C_in: inputs.C_in,
  //     C_out: inputs.C_out,
  //   });
  //   await circuit.checkConstraints(w);
  // }).timeout(10000);
  // // ============================================================
  // it("should check verifying input and output sums", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(__dirname, "../../circuits/helpers", "verify_sums.circom")
  //     );
  //   } catch (e) {
  //     console.log(
  //       "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     );
  //     return;
  //   }
  //   const inputs = padSumVerificationInputs(5);
  //   const w = await circuit.calculateWitness(inputs);
  //   await circuit.checkConstraints(w);
  // }).timeout(10000);
  // // ============================================================
  // it("should check verifying signature", async () => {
  //   // checks H(aiG) = H(riG - Ki - cZi)  for all i in [0, n]
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(__dirname, "../../circuits/signatures", "verify_sig.circom")
  //     );
  //   } catch (e) {
  //     console.log(
  //       "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     );
  //     return;
  //   }
  //   let inputs = padSigVerificationInputs(5);
  //   const w = await circuit.calculateWitness(inputs);
  //   // await circuit.checkConstraints(w);
  //   // await circuit.assertOut(w, { out: c_input });
  // }).timeout(10000);
  // // ============================================================
  // it("should check hashing a transaction", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/transactions",
  //         "transaction_hash.circom"
  //       )
  //     );
  //   } catch (e) {
  //     // console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     );
  //     return;
  //   }
  //   const inputs = padTxHashInputs(5);
  //   const w = await circuit.calculateWitness(inputs);
  //   await circuit.checkConstraints(w);
  // }).timeout(10000);
  //// ============================================================
  // it("should check verifying a transaction", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/transactions",
  //         "note_transaction.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     // console.log(
  //     //   "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     // );
  //     return;
  //   }
  //   const inputs = padTxInputs(5);

  //   const w = await circuit.calculateWitness(inputs);

  //   await circuit.checkConstraints(w);
  // }).timeout(30000);
});
