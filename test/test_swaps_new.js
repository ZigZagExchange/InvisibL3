const {
  Note,
  generateOneTimeAddress,
  oneTimeAddressPrivKey,
} = require("../src/notes/noteUtils");
const Secp256k1 = require("@enumatech/secp256k1-js");
// const poseidon = require("../circomlib/src/poseidon");
const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

const User = require("../src/notes/User.js");

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

const NoteTree = require("../src/merkle_trees/notesTree.js");
const NoteTransaction = require("../src/transactions/noteTransaction");
const Swap = require("../src/transactions/swapTransaction");

const poseidon = require("../circomlib/src/poseidon");
const Tree = require("../src/merkle_trees/tree");
const { pedersen } = require("starknet/utils/hash");

async function storeUsers() {
  const tx_r = 123344545462324n;
  const NUM_NOTES = 5;

  let userDataA = User.generateRandomUserData();
  let userA = new User(
    userDataA.id,
    userDataA.privViewKey,
    userDataA.privSpendKey
  );

  let prev_r = 111122223333444455556666777788889999n;
  const TOKEN = 1;

  let Ko = generateOneTimeAddress(userA.pubViewKey, userA.pubSpendKey, prev_r);

  let ko = oneTimeAddressPrivKey(
    userA.pubViewKey,
    userDataA.privSpendKey,
    prev_r
  );

  let notes = [];
  let amounts = [];
  let blindings = [];
  let kos = [];
  for (let i = 0; i < NUM_NOTES; i++) {
    let amount = randomBigInt(32) * 100n;
    let blinding = randomBigInt(250);

    let comm = pedersen([amount, blinding]);

    let note = new Note(Ko, comm, TOKEN, i);

    notes.push(note);
    amounts.push(amount);
    blindings.push(blinding);
    kos.push(ko);
  }

  userA.addNotes(notes, amounts, blindings, kos);

  let newNotes = [];
  for (let i = 0; i < NUM_NOTES; i++) {
    let n = notes[i];
    let newNote = new Note(n.address, n.commitment, 2);
    newNotes.push(newNote);
  }
  userA.addNotes(newNotes, amounts, blindings, kos);

  storeNewUser(userA).then(console.log("stored"));
}
// storeUsers().then(console.log("done")).catch(console.log);

async function fetchUsers() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);

  console.log(userA);
  console.log(userB);
}
// fetchUsers();

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

  const outNoteDataA = userA.generateOutputNotes(
    X_AMOUNT,
    TOKEN_X,
    subaddressB.Kvi,
    subaddressB.Ksi,
    tx_r
  );

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

  let subPrivKeysA = userA.subaddressPrivKeys(1);
  let ko = oneTimeAddressPrivKey(subaddressA.Kvi, subPrivKeysA.ksi, tx_r); // ith subaddress private key
  let retAddrSigA = txA.signReturnAddressSig(ko);

  let KoA = generateOneTimeAddress(subaddressA.Kvi, subaddressA.Ksi, tx_r);
  txA.verifyRetAddrSig(retAddrSigA, KoA);

  let sigA = txA.signTx(outNoteDataA.kosIn);
  txA.verifySig(sigA);

  txA.logTransaction(retAddrSigA, sigA);

  let { preimage, prev_root, new_root } = update_state(
    outNoteDataA.notesIn,
    outNoteDataA.notesOut
  );

  console.log(',"preimage":', preimage);
  console.log(',"prev_root":', prev_root);
  console.log(',"new_root":', new_root);

  // ==========================================================================0

  // let res = userB.calculateAmounts(X_AMOUNT, TOKEN_X_PRICE, TOKEN_Y_PRICE);
  // let Y_AMOUNT = res.outputAmount;

  // const outNoteDataB = userB.generateOutputNotes(
  //   Y_AMOUNT,
  //   TOKEN_Y,
  //   subaddressA.Kvi,
  //   subaddressA.Ksi,
  //   tx_r
  // );

  // const txB = new NoteTransaction(
  //   outNoteDataB.notesIn,
  //   outNoteDataB.notesOut,
  //   outNoteDataB.amountsIn,
  //   outNoteDataB.amountsOut,
  //   outNoteDataB.blindingsIn,
  //   outNoteDataB.blindingsOut,
  //   TOKEN_Y,
  //   TOKEN_Y_PRICE,
  //   TOKEN_X,
  //   TOKEN_X_PRICE,
  //   subaddressB.Ksi,
  //   subaddressB.Kvi,
  //   tx_r
  // );

  // let subPrivKeysB = userB.subaddressPrivKeys(1); // ith subaddress private keys
  // let koB = oneTimeAddressPrivKey(subaddressB.Kvi, subPrivKeysB.ksi, tx_r);
  // const retAddrSigB = txB.signReturnAddressSig(koB);

  // let KoB = generateOneTimeAddress(subaddressB.Kvi, subaddressB.Ksi, tx_r);
  // txB.verifyRetAddrSig(retAddrSigB, KoB);

  // const sigB = txB.signTx(outNoteDataB.kosIn);
  // txB.verifySig(sigB);

  // SWAP ==========================================================

  // const swap = new Swap(txA, txB);

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
}

function update_state(notes_in, notes_out) {
  // todo figure out indexes
  let init_state = notes_in.map((n) => n.hash);

  init_state = padArrayEnd(init_state, 8, 0);

  let tree = new Tree(init_state, 3);

  let maxLen = Math.max(notes_in.length, notes_out.length);

  let prev_root = tree.root;

  let proofs_in = [];
  let preimages_in = [];
  for (let i = 0; i < notes_in.length; i++) {
    let proof = tree.getProof(i); //(notes_in[i].index);
    let multiUpdateProof = tree.getMultiUpdateProof(
      notes_in[i].hash,
      proof.proof,
      proof.proofPos
    );
    proofs_in.push(proof.proof);
    preimages_in.push(multiUpdateProof);
  }
  for (let i = notes_in.length; i < maxLen; i++) {
    let proof = tree.getProof(i); //(notes_in[i].index);
    let multiUpdateProof = tree.getMultiUpdateProof(
      0,
      proof.proof,
      proof.proofPos
    );
    proofs_in.push(proof.proof);
    preimages_in.push(multiUpdateProof);
  }

  for (let i = 0; i < notes_out.length; i++) {
    tree.updateNode(notes_out[i].hash, i, proofs_in[i]);
  }
  for (let i = notes_out.length; i < maxLen; i++) {
    tree.updateNode(0, i, proofs_in[i]);
  }

  let proofs_out = [];
  let preimages_out = [];
  for (let i = 0; i < notes_out.length; i++) {
    let proof = tree.getProof(i); //(notes_out[i].index);
    let multiUpdateProof2 = tree.getMultiUpdateProof(
      notes_out[i].hash,
      proof.proof,
      proof.proofPos
    );

    proofs_out.push(proof.proof);
    preimages_out.push(multiUpdateProof2);
  }
  for (let i = notes_out.length; i < maxLen; i++) {
    let proof = tree.getProof(i); //(notes_in[i].index);
    let multiUpdateProof = tree.getMultiUpdateProof(
      0,
      proof.proof,
      proof.proofPos
    );
    proofs_out.push(proof.proof);
    preimages_out.push(multiUpdateProof);
  }

  let preimage = {};
  for (let i = 0; i < preimages_in.length; i++) {
    preimages_in[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }
  for (let i = 0; i < preimages_out.length; i++) {
    preimages_out[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }

  return { preimage, prev_root, new_root: tree.root };
}

function padArrayEnd(arr, len, padding) {
  return arr.concat(Array(len - arr.length).fill(padding));
}

testSwap().then(console.log("done")).catch(console.log);
