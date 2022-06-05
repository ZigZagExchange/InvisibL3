const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;

var fs = require("fs");

// const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
// const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
// const ecSub = require("../circomlib/src/babyjub.js").subPoint;
// const F = require("../circomlib/src/babyjub.js").F;
// const G = require("../circomlib/src/babyjub.js").Generator;
// const H = require("../circomlib/src/babyjub.js").Base8;

const {
  transaction_A,
  transaction_B,
  multiSwapInputs,
  padSwapInputs,
} = require("./5_swap_inputs");

const assert = chai.assert;

describe("swap transaction verification test", function () {
  // it("should verify a swap transaction", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(__dirname, "../../circuits/transactions", "swap_tx.circom")
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     // console.log(
  //     //   "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
  //     // );
  //     return;
  //   }

  //   const inputs = padSwapInputs(3);

  //   console.time("t1");
  //   for (let i = 0; i < 1; i++) {
  //     const w = await circuit.calculateWitness(inputs);
  //   }
  //   console.timeEnd("t1");

  //   // await circuit.checkConstraints(w);
  // }).timeout(300000);
  //? // ===================================================================
  it("should verify a multiswap transaction", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(
          __dirname,
          "../../circuits/transactions",
          "multiswap_tx.circom"
        )
      );
    } catch (e) {
      console.log(e);
      // console.log(
      //   "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
      // );
      return;
    }

    // console.log(circuit);

    const inputs = multiSwapInputs(1, 3);

    console.time("t10");
    for (let i = 0; i < 10; i++) {
      const w = await circuit.calculateWitness(inputs);
    }
    console.timeEnd("t10");

    // await circuit.checkConstraints(w);
  }).timeout(100000);
});

function dim(mat) {
  if (mat instanceof Array) {
    return [mat.length].concat(dim(mat[0]));
  } else {
    return [];
  }
}
