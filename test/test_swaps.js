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
const NoteTransaction = require("../src/transactions/noteTransaction");
const Swap = require("../src/transactions/swapTransaction");

const {
  noteDataToJSON,
  storeNewUser,
  fetchStoredUser,
  fetchUserIds,
  fetchAllTokens,
} = require("../src/firebase/storeUserData");

//

async function fetchUsers() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["1"]);
  const userB = await fetchStoredUser(ids["2"]);

  tx_r = 1234567890987654321n;

  const subaddressB = userB.generateSubaddress(5);

  //   const sum = userA.noteData["1"].reduce(
  //     (partialSum, nData) => partialSum + nData.amount,
  //     0n
  //   );
  console.log(userA.noteData["2"]);

  const spendAmount = 15534000n;
  20296700n;
  const outNoteDataA = userA.generateOutputNotes(
    spendAmount,
    1,
    subaddressB.Kvi,
    subaddressB.Ksi,
    tx_r
  );

  console.log(outNoteDataA);
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
  for (let i = 0; i < 5; i++) {
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
  for (let i = 0; i < 5; i++) {
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

  let cmtzDataA = noteUtils.cmtzPrivKeys(
    outNoteDataA.notesIn,
    outNoteDataA.amountsIn,
    outNoteDataA.blindingsIn,
    outNoteDataA.blindingsOut
  );

  let pseudoCommsA = noteUtils.newCommitments(
    outNoteDataA.amountsIn,
    cmtzDataA.new_blindings
  );

  const cmtz_pub_keys = noteUtils.cmtzPubKeys(
    outNoteDataA.notesIn,
    pseudoCommsA,
    cmtzDataA.pos
  );

  // User A sends X amount of token 1 to B
  const txA = new NoteTransaction(
    outNoteDataA.notesIn,
    pseudoCommsA,
    cmtzDataA.pos,
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

  let sigA = txA.signTransaction_new(outNoteDataA.kosIn, cmtzDataA.priv_keys_z);

  // txA.verifyPrivReturnAddressSig(retAddrSigA);
  // txA.verifySignature_new(sigA);

  // txA.logHashTxInputs();
  // txA.logTransaction(retAddrSigA, sigA);

  // User B receives X amount of token 1 from A
  // todo (receive hidden values or just unhidden and the hidden values only end up onchain)

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

  let cmtzDataB = noteUtils.cmtzPrivKeys(
    outNoteDataB.notesIn,
    outNoteDataB.amountsIn,
    outNoteDataB.blindingsIn,
    outNoteDataB.blindingsOut
  );

  let pseudoCommsB = noteUtils.newCommitments(
    outNoteDataB.amountsIn,
    cmtzDataB.new_blindings
  );

  const txB = new NoteTransaction(
    outNoteDataB.notesIn,
    pseudoCommsB,
    cmtzDataB.pos,
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

  const sigB = txB.signTransaction_new(
    outNoteDataB.kosIn,
    cmtzDataB.priv_keys_z
  );

  // txB.verifyPrivReturnAddressSig(retAddrSigB);
  // txB.verifySignature(sigB);

  // User A receives X amount of token 2 from B

  // //* Transactions should form a valid swap ===============================================

  const swap = new Swap(txA, txB);

  swap.verify(
    retAddrSigA,
    sigA,
    retAddrSigB,
    sigB,
    TOKEN_X,
    TOKEN_X_PRICE,
    TOKEN_Y,
    TOKEN_Y_PRICE
  );

  swap.logSwap(retAddrSigA, sigA, retAddrSigB, sigB);
}

testSwap().catch(console.log);
// storeUsers();
