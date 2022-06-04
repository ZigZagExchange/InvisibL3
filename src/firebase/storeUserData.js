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
    if (typeof value === "string") {
      return bigInt(value).value;
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
};
