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

    this.updateNode(noteLeaf, this.notes.length - 1, noteProof[0]);
  }

  removeNote(note) {
    let idx = this.noteHashes.findIndex((x) => x === note.hash);

    this.notes.splice(idx, 1);
    this.noteHashes.splice(idx, 1);

    const noteProof = this.getNoteProof(note.hash);

    let idx2 = this.leafNodes.findIndex((x) => x === note.hash);

    this.updateNode(ZERO_HASH, idx2, noteProof[0]);
  }

  // findNoteByPubkey(pubkeyX, pubkeyY) {
  //   return this.notes.filter(
  //     (addr) => addr.pubkeyX == pubkeyX && addr.pubkeyY == pubkeyY
  //   )[0];
  // }
};

function padArrayEnd(arr, len, padding) {
  return arr.concat(Array(len - arr.length).fill(padding));
}
