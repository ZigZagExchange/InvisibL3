const Tree = require("../src/merkle_trees/tree");
const treeUtils = require("../src/merkle_trees/treeUtils.js");
const NoteTree = require("../src/merkle_trees/notesTree.js");
const { Note } = require("../src/notes/noteUtils.js");

// const G = require("../circomlib/src/babyjub.js").Generator;
// const H = require("../circomlib/src/babyjub.js").Base8;
// const F = require("../circomlib/src/babyjub.js").F;
// const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
// const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
// const ecSub = require("../circomlib/src/babyjub.js").subPoint;

const BAL_DEPTH = 4;

const { padSwapInputs } = require("./circuit_tests/5_swap_inputs");

const ZERO_HASH =
  1972593120533667380477339603313231606809289461898419477679735141070009144584n;

function main() {
  const swapInputs = padSwapInputs(3);

  const notesIn_A = swapInputs.notesIn_A.map(
    (n) => new Note([n[1], n[2]], [n[4], n[5]], n[3], n[0])
  );
  const notesIn_B = swapInputs.notesIn_B.map(
    (n) => new Note([n[1], n[2]], [n[4], n[5]], n[3], n[0])
  );
  const notesOut_A = swapInputs.notesOut_A.map(
    (n) => new Note([n[1], n[2]], [n[4], n[5]], n[3], n[0])
  );
  const notesOut_B = swapInputs.notesOut_B.map(
    (n) => new Note([n[1], n[2]], [n[4], n[5]], n[3], n[0])
  );

  function getMultiUpdateNoteInputs() {
    let inNotes = notesIn_A.concat(notesIn_B);

    let outNotes = notesOut_A.concat(notesOut_B);

    const tree = new NoteTree(Array.from(inNotes), 4);

    const initialRoot = tree.root;
    let proofs = [];
    let intermidiateRoots = [];

    let len = inNotes.length;
    for (let i = 0; i < len; i++) {
      const noteHash = inNotes[i].hash;

      let proof = tree.getNoteProof(noteHash);
      proofs.push(proof);

      tree.replaceNote(inNotes[i], outNotes[i]);
      intermidiateRoots.push(tree.root);
    }

    let Ko_in = inNotes.map((n) => n.address);
    let token_in = inNotes.map((n) => n.token);
    let commitment_in = inNotes.map((n) => n.commitment);
    let Ko_out = outNotes.map((n) => n.address);
    let token_out = outNotes.map((n) => n.token);
    let commitment_out = outNotes.map((n) => n.commitment);
    intermidiateRoots.unshift(initialRoot);
    let paths2rootPos = proofs.map((p) => p[1]);
    let paths2root = proofs.map((p) => p[0]);

    console.log("Ko_in: ", Ko_in);
    console.log(",token_in: ", token_in);
    console.log(",commitment_in: ", commitment_in);
    console.log(",Ko_out: ", Ko_out);
    console.log(",token_out: ", token_out);
    console.log(",commitment_out: ", commitment_out);
    console.log(",initialRoot: ", initialRoot);
    console.log(",intermidiateRoots: ", intermidiateRoots);
    console.log(",paths2rootPos: ", paths2rootPos);
    console.log(",paths2root: ", paths2root);
  }
  getMultiUpdateNoteInputs();

  function getRemoveNoteInputs() {
    let inNotes = notesIn_A
      .concat(notesOut_A)
      .concat(notesIn_B)
      .concat(notesOut_B)
      .filter((n) => n.hash !== ZERO_HASH);

    let inNoteHashes = inNotes.map((n) => n.hash);

    const tree = new NoteTree(Array.from(inNotes), 4);

    let idx = tree.leafNodes.findIndex((x) => x === inNotes[0].hash);

    let proof = tree.getProof(idx);

    tree.removeNote(inNotes[0]);

    console.log("paths2root: ", proof.proof);
    console.log(",paths2rootPos: ", proof.proofPos);
    console.log("newRoot", tree.root);
  }
  // getRemoveNoteInputs()

  function getMultiExistenceCheckInputs() {
    let inNotes = notesIn_A
      .concat(notesOut_A)
      .concat(notesIn_B)
      .concat(notesOut_B)
      .filter((n) => n.hash !== ZERO_HASH);

    let inNoteHashes = inNotes.map((n) => n.hash);

    const tree = new NoteTree(Array.from(inNotes), 4);

    let proofs = [];
    for (let i = 0; i < inNotes.length; i++) {
      const noteHash = inNoteHashes[i];

      let proof = tree.getNoteProof(noteHash);
      proofs.push(proof);
    }

    let Ko = inNotes.map((n) => n.address);
    let token = inNotes.map((n) => n.token);
    let commitment = inNotes.map((n) => n.commitment);
    //   console.log(proofs);
    let paths2rootPos = proofs.map((p) => p[1]);
    let paths2root = proofs.map((p) => p[0]);
    let root = tree.root;

    console.log("Ko: ", Ko);
    console.log(",token: ", token);
    console.log(",commitment: ", commitment);
    console.log(",paths2rootPos: ", paths2rootPos);
    console.log(",paths2root: ", paths2root);
    console.log(",root: ", root);
    s;
  }
  // getMultiExistenceCheckInputs();
}

main();
