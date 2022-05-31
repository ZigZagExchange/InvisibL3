const noteUtils = require("../notes/noteUtils");
const dummyData = require("./dummyData");
var bigInt = require("big-integer");

const { app, db } = require("../../firebaseConfig.js");
const {
  collection,
  addDoc,
  getDocs,
  getDoc,
  doc,
  setDoc,
} = require("firebase/firestore/lite");
const {
  noteToFirebaseObject,
  firebaseObjectToNote,
} = require("../../test/firebaseFunctions");

// let inputNoteData = dummyData.getDummyNotes();

const collectionRef = collection(db, "notes");

function storeNotes(inputNoteData) {
  for (let i = 0; i < inputNoteData.amounts.length; i++) {
    addDoc(collectionRef, {
      note: noteToFirebaseObject(inputNoteData.notes[i]),
      amount: inputNoteData.amounts[i].toString(),
      blinding: inputNoteData.blindings[i].toString(),
      Ko: inputNoteData.Kos[i].toString(),
      ko: inputNoteData.kos[i].toString(),
    });
  }
}

async function retrieveNotes() {
  let Kos = [];
  let kos = [];
  let notes = [];
  let amounts = [];
  let blindings = [];

  const docs = await getDocs(collectionRef);
  docs.docs.forEach((doc) => {
    Kos.push([BigInt(doc.data().note.Kox), BigInt(doc.data().note.Koy)]);
    kos.push(BigInt(doc.data().ko));
    notes.push(firebaseObjectToNote(doc.data().note));
    amounts.push(BigInt(doc.data().amount));
    blindings.push(BigInt(doc.data().blinding));
  });

  return { notes, amounts, blindings, Kos, kos };
}

// let noteData = getTestNotes(5, 3);
// storeNotes(noteData);
// retrieveNotes();

function getTestNotes(nNotes = 5, token) {
  let input_data = dummyData.generateRandomData(nNotes);
  const amounts = input_data.amounts;
  const blindings = input_data.blindings;

  let inputKeys = dummyData.generateRandomKeys(nNotes);
  const privSpendKeys = inputKeys.privSpendKeys;
  const pubSpendKeys = inputKeys.pubSpendKeys;
  const privViewKeys = inputKeys.privViewKeys;
  const pubViewKeys = inputKeys.pubViewKeys;

  let Kos = [];
  let kos = [];
  let notes = [];

  for (let i = 0; i < amounts.length; i++) {
    const Ko = noteUtils.generateOneTimeAddress(
      pubViewKeys[i],
      pubSpendKeys[i],
      123
    );
    const ko = noteUtils.oneTimeAddressPrivKey(
      pubViewKeys[i],
      privSpendKeys[i],
      123
    );

    let comm = noteUtils.newCommitment(amounts[i], blindings[i]);
    let note = new noteUtils.Note(Ko, comm, token, i);

    notes.push(note);
    Kos.push(Ko);
    kos.push(ko);
  }

  return { notes, amounts, blindings, Kos, kos };
}

module.exports = {
  retrieveNotes,
};
