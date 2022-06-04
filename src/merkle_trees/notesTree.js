const Tree = require("./tree.js");
// const Transaction = require("./transaction2.js");

const ZERO_HASH =
  1972593120533667380477339603313231606809289461898419477679735141070009144584n;

module.exports = class NoteTree extends Tree {
  constructor(_notes, depth = 4) {
    let noteHashes = _notes.map((n) => n.hash);

    let notesPadded = padArrayEnd(noteHashes, 2 ** depth, ZERO_HASH);

    super(notesPadded);
    this.notes = _notes; // Actual notes
    this.noteHashes = noteHashes; // Hashes of notes
  }

  checkNoteExistence(noteLeaf, noteProof) {
    let idx = this.leafNodes.findIndex((x) => x === noteLeaf);

    if (!this.verifyProof(noteLeaf, idx, noteProof)) {
      console.log("given note hash", noteLeaf);
      console.log("given note proof", noteProof);

      throw "note does not exist";
    }
  }

  getNoteProof(noteLeaf) {
    if (!noteLeaf) {
      return;
    }
    let idx = this.leafNodes.findIndex((x) => x === noteLeaf);

    if (idx < 0) {
      throw "note does not exist";
    }
    const proofObj = this.getProof(idx);
    return [proofObj.proof, proofObj.proofPos];
  }

  addNote(note) {
    // update this.notes
    this.notes.push(note);
    this.noteHashes.push(note.hash);

    // get the proof and update the intermidiate nodes
    const noteProof = this.getNoteProof(this.leafNodes[this.notes.length - 1]);

    this.updateNode(note.hash, this.notes.length - 1, noteProof[0]);
  }

  replaceNote(prevNote, newNote) {
    if (!prevNote && !newNote) {
      return;
    } else if (!prevNote) {
      this.addNote(newNote);
    } else if (!newNote) {
      this.removeNote(prevNote.hash);
    } else {
      let idx = this.noteHashes.findIndex((x) => x === prevNote.hash);

      this.notes[idx] = newNote;
      this.noteHashes[idx] = newNote.hash;

      const treeIdx = this.leafNodes.findIndex((x) => x === prevNote.hash);

      const noteProof = this.getNoteProof(prevNote.hash);

      this.updateNode(newNote.hash, treeIdx, noteProof[0]);
    }
  }

  removeNote(noteLeaf) {
    let idx = this.noteHashes.findIndex((x) => x === noteLeaf);

    this.notes.splice(idx, 1);
    this.noteHashes.splice(idx, 1);

    const noteProof = this.getNoteProof(noteLeaf);

    let idx2 = this.leafNodes.findIndex((x) => x === noteLeaf);

    this.updateNode(ZERO_HASH, idx2, noteProof[0]);
  }

  updateNotesWithProofs(notesIn, notesOut) {
    let proofs = [];
    let intermidiateRoots = [this.root];

    let len = 5; //Math.max(notesIn.length, notesOut.length);
    for (let i = 0; i < len; i++) {
      const noteHash = notesIn[i] ? notesIn[i].hash : ZERO_HASH;

      let proof = this.getNoteProof(noteHash);
      proofs.push(proof);

      this.replaceNote(notesIn[i], notesOut[i]);
      intermidiateRoots.push(this.root);
    }

    return { proofs, intermidiateRoots };
  }
};

function padArrayEnd(arr, len, padding) {
  return arr.concat(Array(len - arr.length).fill(padding));
}
