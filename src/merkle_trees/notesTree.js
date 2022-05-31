const Tree = require("../tree.js");
// const Transaction = require("./transaction2.js");

module.exports = class NoteTree extends Tree {
  constructor(_notes) {
    super(
      _notes.map((x) => {
        return x.hash ? x.hash : 0;
      })
    );
    this.notes = _notes;
  }

  checkNoteExistence(note, noteProof) {
    if (!this.verifyProof(note.hash, note.index, noteProof)) {
      console.log("given note hash", note.hash);
      console.log("given note proof", noteProof);

      throw "note does not exist";
    }
  }

  getNoteProof(note) {
    if (!note) {
      return;
    }
    const proofObj = this.getProof(note.index);
    return [proofObj.proof, proofObj.proofPos];
  }

  findNoteByPubkey(pubkeyX, pubkeyY) {
    return this.notes.filter(
      (addr) => addr.pubkeyX == pubkeyX && addr.pubkeyY == pubkeyY
    )[0];
  }

  // generateEmptyTx(pubkeyX, pubkeyY, index, prvkey) {
  //   const sender = this.findNoteByPubkey(pubkeyX, pubkeyY);
  //   const nonce = sender.nonce;
  //   const tokenType = sender.tokenType;
  //   var tx = new Transaction(
  //     pubkeyX,
  //     pubkeyY,
  //     index,
  //     pubkeyX,
  //     pubkeyY,
  //     nonce,
  //     0,
  //     tokenType
  //   );
  //   tx.signTxHash(prvkey);
  // }
};
