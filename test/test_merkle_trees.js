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

  let inNotes = notesIn_A
    .concat(notesIn_B)
    .concat(notesOut_A)
    .concat(notesOut_B)
    .filter((n) => n.hash !== ZERO_HASH);

  let inNoteHashes = inNotes.map((n) => n.hash);

  const tree = new NoteTree(inNotes, 4);

  //   console.log(tree.noteHashes);
  tree.removeNote(notesIn_A[0]);
  //   console.log(tree.noteHashes);

  function getMultiExistenceCheckInputs() {
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
}

main();
