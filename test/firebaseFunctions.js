// const { app, db } = require("../firebaseConfig.js");
// const {
//   collection,
//   addDoc,
//   getDocs,
//   getDoc,
//   doc,
//   setDoc,
// } = require("firebase/firestore/lite");
// const { Note } = require("../src/notes/noteUtils.js");

// const collectionRef = collection(db, "notes");

// async function addData() {
//   await setDoc(doc(db, "testtest", "1"), {
//     a: JSON.stringify({ 1: "Tom", 2: "Bob" }),
//   });
// }
// // addData();

// async function getData() {
//   const docRef = doc(db, "testtest", "1");

// const docs = await getDocs(collectionRef);
// docs.docs.forEach((doc) => {
//   console.log(doc.data());
// });

//   const res = await getDoc(docRef);
//   console.log(JSON.parse(res.data().a));
// }
// getData();

// //
// function noteToFirebaseObject(note) {
//   return {
//     index: note.index.toString(),
//     Kox: note.address[0].toString(),
//     Koy: note.address[1].toString(),
//     token: note.token.toString(),
//     Cx: note.commitment[0].toString(),
//     Cy: note.commitment[1].toString(),
//   };
// }

// function firebaseObjectToNote(note) {
//   let comm = [BigInt(note.Cx), BigInt(note.Cx)];
//   let addr = [BigInt(note.Kox), BigInt(note.Koy)];
//   let index = BigInt(note.index);
//   let token = parseInt(note.token);
//   return new Note(addr, comm, token, index);
// }

// module.exports = { noteToFirebaseObject, firebaseObjectToNote };
