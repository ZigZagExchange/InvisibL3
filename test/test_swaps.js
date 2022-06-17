const noteUtils = require("../src/notes/noteUtils");
// const poseidon = require("../circomlib/src/poseidon");
const G = require("../circomlib/src/babyjub.js").Generator;
const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
const ecSub = require("../circomlib/src/babyjub.js").subPoint;
// const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

const User = require("../src/notes/User.js");
const Note = require("../src/notes/noteUtils").Note;
const NoteTree = require("../src/merkle_trees/notesTree.js");
const NoteTransaction = require("../src/transactions/noteTransaction");
const Swap = require("../src/transactions/swapTransaction");

const {
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
} = require("../src/firebase/storeUserData");
const poseidon = require("../circomlib/src/poseidon");
const Tree = require("../src/merkle_trees/tree");

//

const NUM_NOTES = 3;

const ZERO_HASH =
  3188939322973067328877758594842858906904921945741806511873286077735470116993n;

async function fetchUsers() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["1"]);
  const userB = await fetchStoredUser(ids["2"]);
}

async function storeUsers() {
  const tx_r = 123344545462324n;

  let userDataA = User.generateRandomUserData();
  let userA = new User(
    userDataA.id,
    userDataA.privViewKey,
    userDataA.privSpendKey
  );

  // let userDataB = User.generateRandomUserData();
  // let userB = new User(
  //   userDataB.id,
  //   userDataB.privViewKey,
  //   userDataB.privSpendKey
  // );
  // let subaddressB = userB.generateSubaddress(1);

  let prev_r = 111122223333444455556666777788889999n;
  const TOKEN = 3;

  let Ko = noteUtils.generateOneTimeAddress(
    userA.pubViewKey,
    userA.pubSpendKey,
    prev_r
  );

  let ko = noteUtils.oneTimeAddressPrivKey(
    userA.pubViewKey,
    userDataA.privSpendKey,
    prev_r
  );

  if (ecMul(G, ko)[0] !== Ko[0]) {
    console.log("ERROR");
  }

  let notes = [];
  let amounts = [];
  let blindings = [];
  let kos = [];
  for (let i = 0; i < NUM_NOTES; i++) {
    let amount = randomBigInt(32) * 100n;
    let blinding = randomBigInt(240);

    let comm = noteUtils.newCommitment(amount, blinding);

    let note = new Note(Ko, comm, TOKEN);

    notes.push(note);
    amounts.push(amount);
    blindings.push(blinding);
    kos.push(ko);
  }

  userA.addNotes(notes, amounts, blindings, kos);

  let newNotes = [];
  for (let i = 0; i < NUM_NOTES; i++) {
    let n = notes[i];
    let newNote = new Note(n.address, n.commitment, 1);
    newNotes.push(newNote);
  }
  userA.addNotes(newNotes, amounts, blindings, kos);

  storeNewUser(userA).then(console.log("stored"));
}

async function testSwap() {
  // Preproccessing steps ==============

  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);

  const subaddressA = userA.generateSubaddress(1);
  const subaddressB = userB.generateSubaddress(1);

  const tokenData = await fetchAllTokens();

  userA.pedersenToPoseidon();

  const tx_r = 1234567890987654321n;

  // User A wants to swap X amount of token 1 to token 2 with B
  const TOKEN_X = 1;
  const TOKEN_X_PRICE = tokenData[TOKEN_X];
  const TOKEN_Y = 2;
  const TOKEN_Y_PRICE = tokenData[TOKEN_Y];
  const X_AMOUNT = 1_534_450_000n; //1.534 eth

  //* User A generates the output notes and pseudo commitments ===========================================
  const outNoteDataA = userA.generateOutputNotes(
    X_AMOUNT,
    TOKEN_X,
    subaddressB.Kvi,
    subaddressB.Ksi,
    tx_r
  );

  // User A sends X amount of token 1 to B

  const txA = new NoteTransaction(
    outNoteDataA.notesIn,
    outNoteDataA.notesOut,
    outNoteDataA.amountsIn,
    outNoteDataA.amountsOut,
    outNoteDataA.blindingsIn,
    outNoteDataA.blindingsOut,
    TOKEN_X,
    TOKEN_X_PRICE,
    TOKEN_Y,
    TOKEN_Y_PRICE,
    subaddressA.Ksi,
    subaddressA.Kvi,
    tx_r
  );

  let subPrivKeysA = userA.subaddressPrivKeys(1); // ith subaddress private keys
  let retAddrSigA = txA.signPrivateReturnAddress(subPrivKeysA.ksi);

  let sigA = txA.signTransaction(outNoteDataA.kosIn);

  // txA.verifyPrivReturnAddressSig(retAddrSigA);

  // txA.verifySignature(sigA);

  // txA.logVerifySignature(sigA);
  // txA.logHashTxInputs();
  // txA.logTransaction(retAddrSigA, sigA);

  ///=============================================================

  // User B receives X amount of token 1 from A

  //* User B sends Y amount of token 2 to A =====================================================

  let res = userB.calculateAmounts(X_AMOUNT, TOKEN_X_PRICE, TOKEN_Y_PRICE);
  let Y_AMOUNT = res.outputAmount;

  const outNoteDataB = userB.generateOutputNotes(
    Y_AMOUNT,
    TOKEN_Y,
    subaddressA.Kvi,
    subaddressA.Ksi,
    tx_r
  );

  const txB = new NoteTransaction(
    outNoteDataB.notesIn,
    outNoteDataB.notesOut,
    outNoteDataB.amountsIn,
    outNoteDataB.amountsOut,
    outNoteDataB.blindingsIn,
    outNoteDataB.blindingsOut,
    TOKEN_Y,
    TOKEN_Y_PRICE,
    TOKEN_X,
    TOKEN_X_PRICE,
    subaddressB.Ksi,
    subaddressB.Kvi,
    tx_r
  );

  let subPrivKeysB = userB.subaddressPrivKeys(1); // ith subaddress private keys
  const retAddrSigB = txB.signPrivateReturnAddress(subPrivKeysB.ksi);

  const sigB = txB.signTransaction(outNoteDataB.kosIn);

  // txB.verifyPrivReturnAddressSig(retAddrSigB);
  // txB.verifySignature(sigB);

  // Note merkle tree ==========================================================

  const noteTree = new NoteTree(
    Array.from(outNoteDataA.notesIn.concat(outNoteDataB.notesIn)),
    4
  );

  const initialRoot = noteTree.root;

  let updateProofsA = noteTree.updateNotesWithProofs(
    outNoteDataA.notesIn,
    outNoteDataA.notesOut
  );

  // console.log(
  //   "Ko_in: ",
  //   outNoteDataA.notesIn.map((n) => n.address)
  // );
  // console.log(
  //   ",token_in: ",
  //   outNoteDataA.notesIn.map((n) => n.token)
  // );
  // console.log(
  //   ",commitment_in: ",
  //   outNoteDataA.notesIn.map((n) => n.commitment)
  // );
  // console.log(
  //   ",Ko_out: ",
  //   outNoteDataA.notesOut.map((n) => n.address)
  // );
  // console.log(
  //   ",token_out: ",
  //   outNoteDataA.notesOut.map((n) => n.token)
  // );
  // console.log(
  //   ",commitment_out: ",
  //   outNoteDataA.notesOut.map((n) => n.commitment)
  // );

  let paths2rootPosA = updateProofsA.proofs.map((p) => p[1]);
  let paths2rootA = updateProofsA.proofs.map((p) => p[0]);
  let intermidiateRootsA = updateProofsA.intermidiateRoots;
  console.log(",initialRoot: ", initialRoot);
  console.log(",intermidiateRoots_A: ", intermidiateRootsA);
  console.log(",paths2rootPos_A: ", paths2rootPosA);
  console.log(",paths2root_A: ", paths2rootA);

  let updateProofsB = noteTree.updateNotesWithProofs(
    outNoteDataB.notesIn,
    outNoteDataB.notesOut
  );

  let paths2rootPosB = updateProofsB.proofs.map((p) => p[1]);
  let paths2rootB = updateProofsB.proofs.map((p) => p[0]);
  let intermidiateRootsB = updateProofsB.intermidiateRoots;
  console.log(",intermidiateRoots_B: ", intermidiateRootsB);
  console.log(",paths2rootPos_B: ", paths2rootPosB);
  console.log(",paths2root_B: ", paths2rootB);

  // //* Transactions should form a valid swap ===============================================

  const swap = new Swap(txA, txB);

  // swap.verify(
  //   retAddrSigA,
  //   sigA,
  //   retAddrSigB,
  //   sigB,
  //   TOKEN_X,
  //   TOKEN_X_PRICE,
  //   TOKEN_Y,
  //   TOKEN_Y_PRICE
  // );

  swap.logSwap(retAddrSigA, sigA, retAddrSigB, sigB);
}

// testSwap().catch(console.log);

async function rand_tests() {
  // let nNotes = await getNextNoteIdx();

  let notes = [];
  for (let i = 0; i < 10; i++) {
    let note = new Note(
      [11111111111111 * i, 11111111111111 * i],
      1010101010101010 * i,
      0
    );
    notes.push(note);
  }

  // let empty_arr = Array(8).fill(ZERO_HASH);

  let tree = new NoteTree([], 6);

  let addProofs = [];
  for (const note of notes) {
    addProofs.push(tree.addNote(note));
  }

  // console.log(addProofs.length);

  for (let i = 0; i < addProofs.length; i++) {
    console.time(`addNote ${i}`);
    addInnerNodes(
      addProofs[i].affectedPos,
      addProofs[i].affectedInnerNodes
    ).then(console.log("All good", i));
    console.timeEnd(`addNote ${i}`);
  }

  // addNoteToTree(note).then(console.log("Added"));
  // updateNote(note, 1);
}

rand_tests().catch(console.log);

// let tree = new Tree([0, 0]);
//   let zeroHashes = [];
//   for (let i = 0; i < 32; i++) {
//     const zHash = tree.zeros(i);

//     zeroHashes.push(zHash);
//   }
//   initZeroTree(zeroHashes);
