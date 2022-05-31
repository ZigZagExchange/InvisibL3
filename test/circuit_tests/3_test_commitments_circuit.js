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

const assert = chai.assert;

const { padCommitmentInputs } = require("./4_transaction_inputs");

describe("commitment test", function () {
  // it("should check making a commitment", async () => {
  //   const circuit = await wasm_tester(
  //     path.join(
  //       __dirname,
  //       "../circuits/helpers/commitments",
  //       "commitment.circom"
  //     )
  //   );

  //   let a = 1300000;
  //   let x = 12334234132590235732342331n;

  //   const w = await circuit.calculateWitness({
  //     a: a,
  //     x: x,
  //   });
  //   // console.log(w);

  //   await circuit.checkConstraints(w);

  //   let C = ecAdd(ecMul(G, F.e(x)), ecMul(H, F.e(a)));
  //   await circuit.assertOut(w, { Cx: C[0], Cy: C[1] });
  // });

  it("should check verifying a commitment", async () => {
    const inputs = padCommitmentInputs(5);
    const circuit = await wasm_tester(
      path.join(
        __dirname,
        "../../circuits/transactions",
        "verify_commitments.circom"
      )
    );

    const w = await circuit.calculateWitness(inputs);
    // console.log(w);

    await circuit.checkConstraints(w);
  }).timeout(10000);
});
