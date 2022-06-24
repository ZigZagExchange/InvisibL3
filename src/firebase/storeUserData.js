const { db } = require("../../firebaseConfig.js");
const {
  collection,
  addDoc,
  getDocs,
  getDoc,
  doc,
  updateDoc,
  setDoc,
} = require("firebase/firestore/lite");
const { Note } = require("../notes/noteUtils.js");
const User = require("../notes/User");

const bigInt = require("big-integer");
const Secp256k1 = require("@enumatech/secp256k1-js");

// const collectionRef = collection(db, "notes");

async function storeNewUser(user) {
  await setDoc(doc(db, "users", user.id.toString()), {
    id: user.id.toString(),
    kv: user.privViewKey.toString(),
    ks: user.privSpendKey.toString(),
    Kv: user.pubViewKey.toString(),
    Ks: user.pubSpendKey.toString(),
    noteData: noteDataToJSON(user.noteData),
  });

  let userIds_ = doc(db, "users", "userIds");
  let userIds = (await getDoc(userIds_)).data();
  let nUsers = userIds.nUsers;
  await updateDoc(userIds_, {
    nUsers: nUsers + 1,
    [nUsers]: user.id.toString(),
  });
}

async function addNoteToTree(note, idx = null) {
  let index = idx ?? (await getNextNoteIdx());

  await setDoc(doc(db, "state_tree", index.toString()), {
    idx: index.toString(),
    K0: note.address[0].toString(),
    K1: note.address[1].toString(),
    commitment: note.commitment.toString(),
    token: note.token.toString(),
  });

  if (!idx) {
    const numNotesRef = doc(db, "state_tree", "numNotes");
    let numNotesDoc = await getDoc(numNotesRef);
    let numNotes = numNotesDoc.data().num;
    await updateDoc(numNotesRef, {
      num: numNotes + 1,
    });
  }
}

async function updateNote(note, idx) {
  if (idx < 0 || !idx) {
    throw "invalid index";
  }

  let docRef = doc(db, "state_tree", idx.toString());
  await updateDoc(docRef, {
    idx: idx.toString(),
    K0: note.address[0].toString(),
    K1: note.address[1].toString(),
    commitment: note.commitment.toString(),
    token: note.token.toString(),
  });
}

async function getNextNoteIdx() {
  const numNotes = await getDoc(doc(db, "state_tree", "numNotes"));
  return numNotes.data().num;
}

async function initZeroTree(zeroHashes) {
  for (let i = 0; i < zeroHashes.length; i++) {
    let docRef = doc(db, `state_tree/levels/${i}`, "zeroHash");
    await setDoc(docRef, {
      hash: zeroHashes[i].toString(),
    });
  }
}

async function addInnerNodes(innerPos, innerHashes) {
  for (let i = 0; i < innerPos.length; i++) {
    let docRef = doc(db, `innerNodes/levels/${i}`, innerPos[i].toString());
    await setDoc(docRef, {
      hash: innerHashes[i].toString(),
    });
  }
}

// async function updateInnerNodes(affectedPos, affectedInnerNodes) {
//   if (affectedPos.length != affectedInnerNodes.length) {
//     throw "lengths missmatch";
//   }

//   for (let i = 0; i < affectedPos.length; i++) {

//     let docRef = doc(db, "state_tree", idx.toString());
//     updateDoc(docRef, {})
//   }
// }

async function fetchStoredUser(userId) {
  const userDoc = await getDoc(doc(db, "users", userId.toString()));
  const userData = userDoc.data();
  const user = new User(
    bigInt(userId).value,
    bigInt(userData.kv).value,
    bigInt(userData.ks).value
  );
  user.noteData = JSONToNoteData(userData.noteData);

  return user;
}

async function fetchUserIds() {
  const userIds = await getDoc(doc(db, "users", "userIds"));
  return userIds.data();
}

async function fetchAllTokens() {
  const collectionRef = collection(db, "tokens");

  const docs = await getDocs(collectionRef);
  const tokenPrices = {};
  docs.docs.forEach((doc) => {
    tokenPrices[doc.id] = bigInt(
      doc.data().price * 10 ** doc.data().decimals
    ).value;
  });
  return tokenPrices;
}

// //? HELPERS ===================

function noteDataToJSON(noteData) {
  return JSON.stringify(noteData, (key, value) => {
    return typeof value === "bigint" ? value.toString() : value;
  });
}

function JSONToNoteData(jsonString) {
  return JSON.parse(jsonString, (k, value) => {
    if (k === "address") {
      return value.map((v) => Secp256k1.uint256(v));
    } else if (typeof value === "string") {
      try {
        return bigInt(value).value;
      } catch {
        if (value.startsWith("0x")) {
          return BigInt(value, 16);
        } else {
          return BigInt("0x" + value, 16);
        }
      }
    }
    if (k == "note") {
      return new Note(value.address, value.commitment, value.token, value.idx);
    }
    return value;
  });
}

module.exports = {
  noteDataToJSON,
  storeNewUser,
  fetchStoredUser,
  fetchUserIds,
  fetchAllTokens,
  getNextNoteIdx,
  addNoteToTree,
  updateNote,
  initZeroTree,
  addInnerNodes,
};
