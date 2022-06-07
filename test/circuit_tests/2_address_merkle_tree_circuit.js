const chai = require("chai");
const path = require("path");
const wasm_tester = require("circom_tester").wasm;
const poseidon = require("../../circomlib/src/poseidon.js");
// const Address = require("../../src/address.js");

const Tree = require("../../src/merkle_trees/tree");
const treeUtils = require("../../src/merkle_trees/treeUtils");

const {
  merkle_inputs,
  noteLeafExistence,
  noteExistenceInputs,
  multiNoteExistenceInputs,
  testRemoveInputs,
  multiUpdateNoteInputs,
  padMultiUpdateNoteInputs,
} = require("./2_merkle_tree_input.js");

const assert = chai.assert;

// function print(circuit, w, s) {
//   console.log(s + ": " + w[circuit.getSignalIdx(s)]);
// }

describe("merkle tree tests", function () {
  // it("should check address_leaf hashing", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(__dirname, "../circuits/test_circuits", "address_leaf.circom")
  //     );
  //   } catch (e) {
  //     console.log(
  //       "Uncomment out main component in address_leaf.circom to test address_leaf hashing"
  //     );
  //     return;
  //   }

  //   let inputs = merkle_inputs.address_inputs();

  //   // let total_notes = inputs.total_notes;
  //   let K0s = inputs.K0_pub_keys;
  //   let notes_per_address = inputs.notes_per_address;
  //   // let amount_blindings = inputs.amount_blindings_per_address;

  //   let total_addresses = 0;
  //   let addresses = [];
  //   for (let i = 0; i < K0s.length; i++) {
  //     const K0 = K0s[i];
  //     const notes = notes_per_address[0];

  //     let address = new Address(total_addresses, K0[0], K0[1], notes);
  //     addresses.push(address);
  //     total_addresses++;
  //   }

  //   let leaves = addresses.map((addr) => addr.hash);
  //   leaves = treeUtils.padArray(leaves, 0, 0);

  //   let addressesTree = new Tree(leaves);

  //   // console.log(addressesTree);

  //   let note_idxs = [];
  //   let note_tokens = [];
  //   let comms = [];
  //   for (let i = 0; i < inputs.notes_per_address[0].length; i++) {
  //     let note = inputs.notes_per_address[0][i];
  //     note_idxs.push(note.index);
  //     note_tokens.push(note.token_type);
  //     comms.push(note.commitment);
  //   }

  //   // Changing anything will result in an error ==> what we want
  //   const w = await circuit.calculateWitness({
  //     index: inputs.notes_per_address[0][0].index,
  //     pubkeyX: inputs.K0_pub_keys[0][0],
  //     pubkeyY: inputs.K0_pub_keys[0][1],
  //     note_idxs: note_idxs,
  //     note_tokens: note_tokens,
  //     note_comms: comms,
  //   });

  //   // console.log(w);

  //   await circuit.checkConstraints(w);

  //   await circuit.assertOut(w, { out: leaves[0] });
  // }).timeout(10000);
  // // ============================================================
  // it("should check address_leaf existence", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/existence_checks",
  //         "address_existence.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     console.log(
  //       "Uncomment out main component in address_existence.circom to test address_leaf existence"
  //     );
  //     return;
  //   }

  //   let inputs = merkle_inputs.address_existence_inputs();

  //   let proof = inputs.proof;
  //   let addressTree = inputs.address_tree;

  //   let addresses = addressTree.addresses;

  //   let note_idxs = [];
  //   let note_tokens = [];
  //   let note_comms = [];
  //   for (let i = 0; i < addresses[0].notes.length; i++) {
  //     const note = addresses[0].notes[i];

  //     note_idxs.push(note.index);
  //     note_tokens.push(note.token_type);
  //     note_comms.push(note.commitment);
  //   }

  //   const w = await circuit.calculateWitness({
  //     index: addresses[0].index,
  //     pubkeyX: addresses[0].pubkeyX,
  //     pubkeyY: addresses[0].pubkeyY,
  //     note_idxs: note_idxs,
  //     note_tokens: note_tokens,
  //     note_comms: note_comms,

  //     addressRoot: addressTree.root,
  //     paths2rootPos: proof[1],
  //     paths2root: proof[0],
  //   });

  //   await circuit.checkConstraints(w);
  // }).timeout(10000);
  // // ============================================================

  // it("should check note leaf existence", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/existence_checks",
  //         "leaf_existence.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_existence.circom to test note existence"
  //     );
  //     return;
  //   }

  //   const inputs = noteLeafExistence;
  //   const w = await circuit.calculateWitness(inputs);

  //   // console.log(w);

  //   await circuit.checkConstraints(w);

  //   // await circuit.assertOut(w, { out: leaves[0] });
  // }).timeout(10000);

  // it("should check note existence", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/existence_checks",
  //         "note_existence.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_existence.circom to test note existence"
  //     );
  //     return;
  //   }

  //   const inputs = noteExistenceInputs;

  //   console.log(inputs);
  //   const w = await circuit.calculateWitness(inputs);

  //   // console.log(w);

  //   await circuit.checkConstraints(w);

  //   // await circuit.assertOut(w, { out: leaves[0] });
  // }).timeout(10000);

  // it("should check multiple notes existence", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/existence_checks",
  //         "multi_note_existence.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_existence.circom to test note existence"
  //     );
  //     return;
  //   }

  //   const inputs = multiNoteExistenceInputs;

  //   const w = await circuit.calculateWitness(inputs);

  //   // console.log(w);

  //   await circuit.checkConstraints(w);
  // }).timeout(10000);

  // it("should check removing notes", async () => {
  //   let circuit;
  //   try {
  //     circuit = await wasm_tester(
  //       path.join(
  //         __dirname,
  //         "../../circuits/existence_checks",
  //         "remove_note.circom"
  //       )
  //     );
  //   } catch (e) {
  //     console.log(e);
  //     console.log(
  //       "Uncomment out main component in note_existence.circom to test note existence"
  //     );
  //     return;
  //   }

  //   const inputs = testRemoveInputs;

  //   const w = await circuit.calculateWitness({
  //     paths2root: inputs.paths2root,
  //     paths2rootPos: inputs.paths2rootPos,
  //   });

  //   // console.log(w);

  //   await circuit.checkConstraints(w);

  //   // await circuit.assertOut(w, { out: leaves[0] });
  //   await circuit.assertOut(w, { intermidiateRoot: inputs.newRoot });
  // }).timeout(10000);
  // // ============================================================
  it("should check updating multiple notes", async () => {
    let circuit;
    try {
      circuit = await wasm_tester(
        path.join(
          __dirname,
          "../../circuits/existence_checks",
          "multi_note_update.circom"
        )
      );
    } catch (e) {
      console.log(e);
      console.log(
        "Uncomment out main component in note_existence.circom to test note existence"
      );
      return;
    }

    const inputs = padMultiUpdateNoteInputs(3);

    // console.log(inputs);
    console.time("calculateWitness");
    const w = await circuit.calculateWitness(inputs);
    console.timeEnd("calculateWitness");

    // await circuit.checkConstraints(w);

    // await circuit.assertOut(w, {
    //   newComputedRoot:
    //     inputs.intermidiateRoots[inputs.intermidiateRoots.length - 1],
    // });
  }).timeout(10000);
});
