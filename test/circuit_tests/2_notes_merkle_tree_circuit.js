const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;
const poseidon = require("../circomlib/src/poseidon.js");
const Address = require("../src/address.js");

const Tree = require("../src/tree");
const treeUtils = require("../src/treeUtils");
const merkle_inputs = require("./2_merkle_tree_input.js");

const assert = chai.assert;

// function print(circuit, w, s) {
//   console.log(s + ": " + w[circuit.getSignalIdx(s)]);
// }

describe("merkle tree tests", function () {
  it("should check address_leaf hashing", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(__dirname, "../circuits/test_circuits", "note_leaf.circom")
      );
    } catch (e) {
      //   console.log(e);
      console.log(
        "Uncomment out main component in note_leaf.circom to test address_leaf hashing"
      );
      return;
    }

    let inputs = merkle_inputs.note_inputs();

    let K0s = inputs.K0_pub_keys;
    let notes = inputs.notes;

    // Changing anything will result in an error ==> what we want
    const w = await circuit.calculateWitness({
      index: notes[0].index,
      K0: K0s[0],
      token: notes[0].token,
      Cx: notes[0].commitment[0],
      Cy: notes[0].commitment[1],
    });

    // console.log(w);

    await circuit.checkConstraints(w);

    await circuit.assertOut(w, { out: notes[0].hash });
  }).timeout(10000);

  it("should check address_leaf existence", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(
          __dirname,
          "../circuits/test_circuits",
          "note_existence.circom"
        )
      );
    } catch (e) {
      //   console.log(e);
      console.log(
        "Uncomment out main component in address_existence.circom to test address_leaf existence"
      );
      return;
    }

    let inputs = merkle_inputs.note_existence_inputs();

    let proof = inputs.proof;
    let notesTree = inputs.notesTree;

    let notes = notesTree.notes;

    const w = await circuit.calculateWitness({
      index: notes[0].index,
      K0: notes[0].address,
      token: notes[0].token,
      commitment: notes[0].commitment,

      notesRoot: notesTree.root,
      paths2rootPos: proof[1],
      paths2root: proof[0],
    });

    await circuit.checkConstraints(w);

    // await circuit.assertOut(w, { out: expectedOut });
  }).timeout(10000);
});
