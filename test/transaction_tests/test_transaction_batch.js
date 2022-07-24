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
const fs = require("fs");

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
const TransactionBatch = require("../../src/transactions/TransactionBatch");
const { pedersen } = require("starknet/utils/hash");

async function test_tx_batch() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);
  const userB = await fetchStoredUser(ids["1"]);
  const userC = await fetchStoredUser(ids["2"]);

  const batchInitTree = treeFromUsers([userA, userB, userC], [0, 1, 1]);

  let jsonArgumentInput = {};

  jsonArgumentInput["init_leaves"] = batchInitTree.leafNodes;

  // & TOKEN_0 = 2*TOKEN_1
  // & userA wants to swap 100_000 of TOKEN_0 for 200_000 of TOKEN_1
  // & userB wants to swap 120_000 of TOKEN_1 for 60_000 of TOKEN_0
  // & userC wants to swap 80_000 of TOKEN_1 for 40_000 of TOKEN_0

  // =====================================================
  // * ORDER A
  let nonce_A = 123n;
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

  const orderARes = userA.makeLimitOrder(
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

  let order_A = orderARes.order;
  let signatures_A = orderARes.signatures;

  // =====================================================
  // * ORDER B
  let nonce_B = 68n;
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

  const orderBRes = userB.makeLimitOrder(
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

  let order_B = orderBRes.order;
  let signatures_B = orderBRes.signatures;

  // =====================================================
  // * ORDER C
  let nonce_C = 311n;
  let expiration_timestamp_C = 800;
  let token_spent_C = 1;
  let token_received_C = 0;
  let amount_spent_C = 80_000n;
  let amount_received_C = 40_000n;
  let fee_limit_C = 100n;
  // These should be calculated by the user
  let dest_spent_address_C = ec.g.mul(71538486941123n);
  let dest_received_address_C = ec.g.mul(452739126384n);
  let blinding_seed_C = 3891461497291094n;

  const orderCRes = userC.makeLimitOrder(
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

  let order_C = orderCRes.order;
  let signatures_C = orderCRes.signatures;

  // =====================================================
  //* SWAP AB ------------------
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

  //* SWAP AC ------------------

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

  // =====================================================
  // * WITHDRAWAL C ------------------

  let amountWithdrawnC = 70_000n;
  let tokenWithdrawnC = 1;
  let starkKeyC = getKeyPair(163548712n).getPublic();

  const withdrawalC = userC.makeWithdrawalOrder(
    amountWithdrawnC,
    tokenWithdrawnC,
    starkKeyC
  );

  // * WITHDRAWAL B ------------------

  let amountWithdrawnB = 50_000n;
  let tokenWithdrawnB = 1;
  let starkKeyB_ = getKeyPair(918264918242n).getPublic();

  const withdrawalB = userB.makeWithdrawalOrder(
    amountWithdrawnB,
    tokenWithdrawnB,
    starkKeyB_
  );

  // * WITHDRAWAL A ------------------

  let amountWithdrawnA = 50_000n;
  let tokenWithdrawnA = 0;
  let starkKeyA_ = getKeyPair(918264918242n).getPublic();

  const withdrawalA = userA.makeWithdrawalOrder(
    amountWithdrawnA,
    tokenWithdrawnA,
    starkKeyA_
  );

  // =====================================================
  // * DEPOSIT A ------------------

  let depositIdA = 12654n;
  let amountDepositedA = 100_000n;
  let tokenDepositedA = 0;
  let starkKeyA = null;

  const deposit_A = userA.makeDepositOrder(
    depositIdA,
    amountDepositedA,
    tokenDepositedA,
    starkKeyA
  );

  // * DEPOSIT B ------------------

  let depositIdB = 12654n;
  let amountDepositedB = 120_000n;
  let tokenDepositedB = 1;
  let starkKeyB = null;

  const deposit_B = userB.makeDepositOrder(
    depositIdB,
    amountDepositedB,
    tokenDepositedB,
    starkKeyB
  );

  // * DEPOSIT C ------------------

  let depositIdC = 12654n;
  let amountDepositedC = 120_000n;
  let tokenDepositedC = 1;
  let starkKeyC_ = null;

  const deposit_C = userC.makeDepositOrder(
    depositIdC,
    amountDepositedC,
    tokenDepositedC,
    starkKeyC_
  );

  // =======================================================
  // * EXECUTE TRANSACTION BATCH

  const transactionBatch = new TransactionBatch(batchInitTree);

  jsonArgumentInput["swaps"] = [swapAB.toInputObject(), swapAC.toInputObject()];
  jsonArgumentInput["signatures"] = [signatures_A, signatures_B, signatures_C];

  console.time("executeTransactionBatch");
  transactionBatch.executeTransaction(swapAB);
  transactionBatch.executeTransaction(swapAC);
  // transactionBatch.executeTransaction(withdrawalA);
  // transactionBatch.executeTransaction(deposit_A);
  // transactionBatch.executeTransaction(withdrawalB);
  // transactionBatch.executeTransaction(deposit_B);
  // transactionBatch.executeTransaction(withdrawalC);
  // transactionBatch.executeTransaction(deposit_C);
  // console.timeEnd("executeTransactionBatch");

  console.time("finalizeBatch");
  transactionBatch.finalizeBatch();
  console.timeEnd("finalizeBatch");

  // console.log(
  //   transactionBatch.toInputObject().preimage[
  //     transactionBatch.toInputObject().new_root
  //   ]
  // );

  let jsonOutput = JSON.stringify(
    transactionBatch.toInputObject(),
    (key, value) => (typeof value === "bigint" ? value.toString() : value)
  );

  fs.writeFile("transactionBatchInput.json", jsonOutput, console.log);

  // ==================================================================================
  let jsonOutput2 = JSON.stringify(jsonArgumentInput, (key, value) =>
    typeof value === "bigint" ? value.toString() : value
  );

  fs.writeFile(
    "../../invisible_backend/rust_input.json",
    jsonOutput2,
    console.log
  );
}
test_tx_batch();

function treeFromUsers(users, tokens) {
  // & takes an array of users and tokens and returns a merkle tree from the note data

  let notes = new Array(32).fill(0n); // 32 is hardcoded for now
  for (let i = 0; i < users.length; i++) {
    const user = users[i];
    const token = tokens[i];

    for (let j = 0; j < user.noteData[token].length; j++) {
      const note = user.noteData[token][j];
      notes[note.index] = note.hash;
    }
  }

  let tree = new Tree(notes);

  let zeroIdxs = [];
  for (let i = 0; i < notes.length; i++) {
    if (notes[i] == 0) {
      zeroIdxs.push(i);
    }
  }

  // tree.count = 24; // Hardcoded for now
  tree.zeroIdxs = zeroIdxs;

  return tree;
}
