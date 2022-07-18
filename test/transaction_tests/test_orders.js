const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");

const { Note } = require("../../src/notes/Notes");
const User = require("../../src/notes/Invisibl3User.js");
const Tree = require("../../src/merkle_trees/Tree.js");

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
} = require("../../src/firebase/storeUserData");
const InvisibleSwap = require("../../src/transactions/InvisibleSwap");

var fs = require("fs");

async function storeUsers() {
  const ids = await fetchUserIds();
  const numUsers = ids.nUsers;

  const tx_r = 123344545462324n;
  const NUM_NOTES = 4;

  let userId = Math.floor(Math.random() * 10000);
  let userDataA = User.generateRandomUserData();

  let userA = new User(
    BigInt(userId),
    userDataA.privViewKey,
    userDataA.privSpendKey
  );

  let prev_r = 111122223333444455556666777788889999n;

  let Ko = userA.generateOneTimeAddress(prev_r);

  let ko = userA.oneTimeAddressPrivKey(prev_r);

  let TOKEN = 0;
  for (let i = 0; i < NUM_NOTES; i++) {
    let amount = 20000n * bigInt(i + 1).value; //randomBigInt(16) * 100n;
    let blinding = randomBigInt(250);
    let index = numUsers * 8 + i;
    let note = new Note(Ko, TOKEN, amount, blinding, index);

    userA.addNote(note, ko);
  }

  TOKEN = 1;
  for (let i = 0; i < NUM_NOTES; i++) {
    let amount = 40000n * bigInt(i + 1).value; //randomBigInt(32) * 100n;
    let blinding = randomBigInt(250);
    let index = numUsers * 8 + 4 + i;
    let note = new Note(Ko, TOKEN, amount, blinding, index);

    userA.addNote(note, ko);
  }

  storeNewUser(userA).then(console.log("stored"));
}
storeUsers();

async function fetchUsers() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["5"]);
  // const userB = await fetchStoredUser(ids["1"]);

  console.log(userA);
  // console.log(userB);
}
// fetchUsers();

async function test_order() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);

  // & TOKEN_0 = 2*TOKEN_1
  // & userA wants to swap 1_000_000 of TOKEN_0 for 2_000_000 of TOKEN_1
  // & userB wants to swap 2_000_000 of TOKEN_1 for 1_000_000 of TOKEN_0

  let nonce = 123;
  let expiration_timestamp = 1000;
  let token_spent = 0;
  let token_received = 1;
  let amount_spent = 105_000n;
  let amount_received = 210_000n;
  let fee_limit = 100n;

  // These should be calculated by the user
  let dest_spent_address = 12381246924n;
  let dest_received_address = 1274618923n;
  let blinding_seed = 89122142144n;

  const order = userA.makeLimitOrder(
    nonce,
    expiration_timestamp,
    token_spent,
    token_received,
    amount_spent,
    amount_received,
    fee_limit,
    dest_spent_address,
    dest_received_address,
    blinding_seed
  );
  order.verify_order_signatures();
  // console.log(order.orderToInputObject());
}
// test_order();

async function test_swap() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);

  // & TOKEN_0 = 2*TOKEN_1
  // & userA wants to swap 100_000 of TOKEN_0 for 200_000 of TOKEN_1
  // & userB wants to swap 200_000 of TOKEN_1 for 100_000 of TOKEN_0

  // =====================================================
  // * ORDER A
  let nonce_A = 123;
  let expiration_timestamp_A = 1000;
  let token_spent_A = 0;
  let token_received_A = 1;
  let amount_spent_A = 100_000n;
  let amount_received_A = 200_000n;
  let fee_limit_A = 100n;
  // These should be calculated by the user
  let dest_spent_address_A = ec.g.mul(1872461289123n);
  let dest_received_address_A = ec.g.mul(1872461289123n);
  let blinding_seed_A = 89122142144n;

  const order_A = userA.makeLimitOrder(
    nonce_A,
    expiration_timestamp_A,
    token_spent_A,
    token_received_A,
    amount_spent_A,
    amount_received_A,
    fee_limit_A,
    dest_spent_address_A,
    dest_received_address_A,
    blinding_seed_A
  );

  // =====================================================
  // * ORDER B
  let nonce_B = 68;
  let expiration_timestamp_B = 1000;
  let token_spent_B = 1;
  let token_received_B = 0;
  let amount_spent_B = 120_000n;
  let amount_received_B = 60_000n;
  let fee_limit_B = 100n;
  // These should be calculated by the user
  let dest_spent_address_B = ec.g.mul(871246924n);
  let dest_received_address_B = ec.g.mul(138964184218n);
  let blinding_seed_B = 238956583749235n;

  const order_B = userA.makeLimitOrder(
    nonce_B,
    expiration_timestamp_B,
    token_spent_B,
    token_received_B,
    amount_spent_B,
    amount_received_B,
    fee_limit_B,
    dest_spent_address_B,
    dest_received_address_B,
    blinding_seed_B
  );

  // =====================================================
  let feeTakenA = 10n;
  let feeTakenB = 20n;
  const swap1 = new InvisibleSwap(
    order_A,
    order_B,
    amount_spent_A,
    amount_spent_B,
    feeTakenA,
    feeTakenB
  );

  let { swapNoteA, swapNoteB } = swap1.executeSwap();

  console.log(swapNoteA, swapNoteB);
}
// test_swap();

async function test_partial_fills() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);
  const userC = await fetchStoredUser(ids["2"]);

  // & TOKEN_0 = 2*TOKEN_1
  // & userA wants to swap 100_000 of TOKEN_0 for 200_000 of TOKEN_1
  // & userB wants to swap 120_000 of TOKEN_1 for 60_000 of TOKEN_0
  // & userC wants to swap 80_000 of TOKEN_1 for 40_000 of TOKEN_0

  // =====================================================
  // * ORDER A
  let nonce_A = 123;
  let expiration_timestamp_A = 1000;
  let token_spent_A = 0;
  let token_received_A = 1;
  let amount_spent_A = 100_000n;
  let amount_received_A = 200_000n;
  let fee_limit_A = 100n;
  // These should be calculated by the user
  let dest_spent_address_A = ec.g.mul(1872461289123n);
  let dest_received_address_A = ec.g.mul(1872461289123n);
  let blinding_seed_A = 89122142144n;

  const order_A = userA.makeLimitOrder(
    nonce_A,
    expiration_timestamp_A,
    token_spent_A,
    token_received_A,
    amount_spent_A,
    amount_received_A,
    fee_limit_A,
    dest_spent_address_A,
    dest_received_address_A,
    blinding_seed_A
  );

  // =====================================================
  // * ORDER B
  let nonce_B = 68;
  let expiration_timestamp_B = 1000;
  let token_spent_B = 1;
  let token_received_B = 0;
  let amount_spent_B = 120_000n;
  let amount_received_B = 60_000n;
  let fee_limit_B = 100n;
  // These should be calculated by the user
  let dest_spent_address_B = ec.g.mul(871246924n);
  let dest_received_address_B = ec.g.mul(138964184218n);
  let blinding_seed_B = 238956583749235n;

  const order_B = userB.makeLimitOrder(
    nonce_B,
    expiration_timestamp_B,
    token_spent_B,
    token_received_B,
    amount_spent_B,
    amount_received_B,
    fee_limit_B,
    dest_spent_address_B,
    dest_received_address_B,
    blinding_seed_B
  );

  // =====================================================
  // * ORDER C
  let nonce_C = 311;
  let expiration_timestamp_C = 800;
  let token_spent_C = 1;
  let token_received_C = 0;
  let amount_spent_C = 80_000n;
  let amount_received_C = 40_000n;
  let fee_limit_C = 100n;
  // These should be calculated by the user
  let dest_spent_address_C = ec.g.mul(71538486941123n);
  let dest_received_address_C = ec.g.mul(452739126384n);
  let blinding_seed_C = 3891461497291094;

  const order_C = userC.makeLimitOrder(
    nonce_C,
    expiration_timestamp_C,
    token_spent_C,
    token_received_C,
    amount_spent_C,
    amount_received_C,
    fee_limit_C,
    dest_spent_address_C,
    dest_received_address_C,
    blinding_seed_C
  );

  // =====================================================

  let spendAmountA = 60_000n;
  let spendAmountB = 120_000n;
  let feeTakenA = 10n;
  let feeTakenB = 20n;

  const swapAB = new InvisibleSwap(
    order_A,
    order_B,
    spendAmountA,
    spendAmountB,
    feeTakenA,
    feeTakenB
  );

  let { swapNoteA, swapNoteB } = swapAB.executeSwap();

  // console.log(swapNoteA, swapNoteB);

  // =====================================================

  spendAmountA = 40_000n;
  let spendAmountC = 80_000n;
  feeTakenA = 10n;
  let feeTakenC = 20n;

  const swapAC = new InvisibleSwap(
    order_A,
    order_C,
    spendAmountA,
    spendAmountC,
    feeTakenA,
    feeTakenC
  );

  let { swapNoteA2, swapNoteC } = swapAC.executeSwap();

  // console.log(swapNoteA, swapNoteB);
}
// test_partial_fills();

//* CHECKS VALIDATING SWAPS AND UPDATING THE STATE (MERKLE TREE) =======================================
async function full_swap_tests() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);
  const userC = await fetchStoredUser(ids["2"]);

  // ? STATE TREE ===============================================

  // & We must store the state tree at the beginning of the batch for the merkle proofs
  let batchInitTree = treeFromUsers([userA, userB, userC], [0, 1, 1]);

  let tree = batchInitTree.clone();
  let preimage = {};
  let updatedNoteHashes = {};

  // console.log(
  //   tree.leafNodes.map((v, i) => i.toString() + "<->" + v.toString()),
  //   "\n===============================\n"
  // );

  // ? ORDERS ===================================================

  let orderA = getDummyOrder(userA, 0, 1, 100_000n, 200_000n);
  let orderB = getDummyOrder(userB, 1, 0, 120_000n, 60_000n);
  let orderC = getDummyOrder(userC, 1, 0, 80_000n, 40_000n);

  // ? SWAPS ====================================================
  console.time("swaps");
  // * Swap 1
  let spendAmountA = 60_000n;
  let spendAmountB = 120_000n;
  let feeTakenA = 10n;
  let feeTakenB = 20n;

  const swapAB = new InvisibleSwap(
    orderA,
    orderB,
    spendAmountA,
    spendAmountB,
    feeTakenA,
    feeTakenB
  );

  let swapABResult = swapAB.executeSwap(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes
  );

  // * Swap 2 ===========================================
  spendAmountA = 40_000n;
  let spendAmountC = 80_000n;
  feeTakenA = 10n;
  let feeTakenC = 20n;

  const swapAC = new InvisibleSwap(
    orderA,
    orderC,
    spendAmountA,
    spendAmountC,
    feeTakenA,
    feeTakenC
  );

  let swapACResult = swapAC.executeSwap(
    batchInitTree,
    tree,
    swapABResult.preimage,
    swapABResult.updatedNoteHashes
  );

  console.timeEnd("swaps");
  // * ======================================================

  console.time("preimages");

  let swapABJson = swapAB.swapToInputObject();
  let swapACJson = swapAC.swapToInputObject();

  let swapInputs = [swapABJson, swapACJson];

  let finalizedPreimages = getFinalizedPreimages(
    tree,
    swapACResult.updatedNoteHashes
  );

  preimage = { ...swapACResult.preimage, ...finalizedPreimages };

  let fileOutput = {
    swaps: swapInputs,
    preimage: preimage,
    prev_root: batchInitTree.root,
    new_root: tree.root,
  };

  let JSON_Output = JSON.stringify(fileOutput, (key, value) => {
    return typeof value === "bigint" ? value.toString() : value;
  });

  fs.writeFile("myjsonfile.json", JSON_Output, () => {});

  console.timeEnd("preimages");
}
// full_swap_tests();

// ! HELPERS ============================================================

function getFinalizedPreimages(tree, updatedNoteHashes) {
  let finalizedPreimages = {};
  for (const [key, value] of Object.entries(updatedNoteHashes)) {
    let multiUpdateProof = tree.getMultiUpdateProof(
      value.leafHash,
      value.proof.proof,
      value.proof.proofPos
    );

    multiUpdateProof.forEach((value, key) => {
      finalizedPreimages[key] = value;
    });
  }

  return finalizedPreimages;
}

function treeFromUsers(users, tokens) {
  // & takes an array of users and tokens and returns a merkle tree from the note data

  let notes = new Array(32).fill(0); // 32 is hardcoded for now
  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    const token = tokens[i];

    let userNoteData = user.noteData[token];
    for (let j = 0; j < userNoteData.notes.length; j++) {
      const note = userNoteData.notes[j];
      notes[note.index] = note.hash;
    }
  }

  let tree = new Tree(notes);

  let zeroIdxs = [];
  for (let i = 0; i < notes.length; i++) {
    if (notes[i] === 0) {
      zeroIdxs.push(i);
    }
  }

  // tree.count = 24; // Hardcoded for now
  tree.zeroIdxs = zeroIdxs;

  return tree;
}

function getDummyOrder(
  user,
  token_spent,
  token_received,
  amount_spent,
  amount_received
) {
  // everything else is a dummy value

  // * ORDER A
  let nonce_A = 123;
  let expiration_timestamp_A = 1000;
  let token_spent_A = token_spent;
  let token_received_A = token_received;
  let amount_spent_A = amount_spent;
  let amount_received_A = amount_received;
  let fee_limit_A = 100n;
  // These should be calculated by the user
  let dest_spent_address_A = ec.g.mul(1872461289123n);
  let dest_received_address_A = ec.g.mul(1872461289123n);
  let blinding_seed_A = 89122142144n;

  return user.makeLimitOrder(
    nonce_A,
    expiration_timestamp_A,
    token_spent_A,
    token_received_A,
    amount_spent_A,
    amount_received_A,
    fee_limit_A,
    dest_spent_address_A,
    dest_received_address_A,
    blinding_seed_A
  );
}
