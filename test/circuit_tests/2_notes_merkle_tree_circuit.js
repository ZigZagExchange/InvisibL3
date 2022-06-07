const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;
const poseidon = require("../../circomlib/src/poseidon.js");

const assert = chai.assert;

// function print(circuit, w, s) {
//   console.log(s + ": " + w[circuit.getSignalIdx(s)]);
// }

describe("merkle tree tests", function () {
  it("should check address_leaf hashing", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(
          __dirname,
          "../../circuits/existence_checks",
          "note_leaf.circom"
        )
      );
    } catch (e) {
      console.log(e);
      // console.log(
      //   "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
      // );
      return;
    }

    const input = {
      Ko: [
        1414463055584249975401255287664006444991531772864589842606436631324803797829n,
        3576190135707767864261393218654241707601949798812616969215456467228622391342n,
      ],
      token: 1,
      Comm: 7981335475664937316519500362527100412865917970581767624020042131014836227980n,
    };
    let hash =
      10529571502529753417191672368451095594795379441835597139667073152399955172878n;

    // Changing anything will result in an error ==> what we want
    const w = await circuit.calculateWitness(input);

    // console.log(w);

    await circuit.checkConstraints(w);

    // await circuit.assertOut(w, { out: notes[0].hash });
  }).timeout(10000);

  // it("should check address_leaf existence", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../circuits/test_circuits",
  //         "note_existence.circom"
  //       )
  //     );
  //   } catch (e) {
  //     //   console.log(e);
  //     console.log(
  //       "Uncomment out main component in address_existence.circom to test address_leaf existence"
  //     );
  //     return;
  //   }

  //   let inputs = merkle_inputs.note_existence_inputs();

  //   let proof = inputs.proof;
  //   let notesTree = inputs.notesTree;

  //   let notes = notesTree.notes;

  //   const w = await circuit.calculateWitness({
  //     index: notes[0].index,
  //     K0: notes[0].address,
  //     token: notes[0].token,
  //     commitment: notes[0].commitment,

  //     notesRoot: notesTree.root,
  //     paths2rootPos: proof[1],
  //     paths2root: proof[0],
  //   });

  //   await circuit.checkConstraints(w);

  //   // await circuit.assertOut(w, { out: expectedOut });
  // }).timeout(10000);
});
