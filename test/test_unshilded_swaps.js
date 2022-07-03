const poseidon = require("../circomlib/src/poseidon");
var bigInt = require("big-integer");
const randomBigInt = require("random-bigint");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");

const Tree = require("../src/merkle_trees/tree");
const {
  UnshieldedUser,
  AccountSpace,
  UnshieldedSwap,
} = require("../src/notes/UnshildedUser");

let swap_input_JSON = {};

let users = generateUsers(7);
let limitOrders = generateLimitOrders(users);

// console.log(limitOrders);

function test_swap() {
  let swaps = [];

  // Log initial state =====================================
  let account_spaces = [];
  users.forEach((user) => {
    account_spaces = account_spaces.concat(user.all_account_spaces());
  });

  let initUserSpaces = account_spaces.map((space) =>
    Object.assign(Object.create(Object.getPrototypeOf(space)), space)
  );
  console.log(
    "account_spaces",
    initUserSpaces.map((acc) => acc.hash),
    "\n\n"
  );
  // =======================================================

  // Execute swap and update the state =====================
  for (let i = 0; i < limitOrders.length; i += 3) {
    let limitOrder1 = limitOrders[i];
    let limitOrder2 = limitOrders[i + 1];
    let limitOrder3 = limitOrders[i + 2];

    let user1 = users[i];
    let user2 = users[i + 1];
    let user3 = users[i + 2];

    let swap1 = new UnshieldedSwap(limitOrder1, limitOrder2, user1, user2);
    let swap2 = new UnshieldedSwap(limitOrder1, limitOrder3, user1, user3);

    let sig1 = user1.sign_order(limitOrder1.order_hash);
    let sig2 = user2.sign_order(limitOrder2.order_hash);
    let sig3 = user3.sign_order(limitOrder3.order_hash);

    swap1.executeSwap(sig1, sig2);
    swap2.executeSwap(sig1, sig3);

    swaps.push(swap1);
    swaps.push(swap2);
  }

  // =======================================================

  // Log all swaps and the updated state ===================
  swaps.forEach((swap) => {
    swap.logSwap();
  });

  account_spaces = [];
  users.forEach((user) => {
    account_spaces = account_spaces.concat(user.all_account_spaces());
  });

  let updatedUserSpaces = account_spaces.map((space) =>
    Object.assign(Object.create(Object.getPrototypeOf(space)), space)
  );
  // console.log("\n\n\naccount_spaces", updatedUserSpaces, "\n\n");
  // =======================================================

  let { preimage, prev_root, new_root } = update_merkle_tree(
    initUserSpaces,
    updatedUserSpaces
  );

  console.log(
    ',"preimage": ',
    JSON.stringify(preimage, (key, value) => {
      return typeof value === "bigint" ? value.toString() : value;
    })
  );
  console.log(',"prev_root": ', prev_root);
  console.log(',"new_root": ', new_root);
}

test_swap();

function generateUsers(n) {
  let users = [];
  n = n - (n % 3); // For simplicity
  for (let i = 0; i < n; i++) {
    let user = new UnshieldedUser(i, 123456789 * i + 123456789);
    user.init_account_space(0, 10000n, 4 * i);
    user.init_account_space(1, 10000n, 4 * i + 1);
    user.init_account_space(2, 10000n, 4 * i + 2);
    user.init_account_space(3, 10000n, 4 * i + 3);
    // user.init_account_space(0, 10000n, 5 * i + 4);

    users.push(user);
  }

  return users;
}

function generateLimitOrders(users) {
  let tokenIdxs1 = [0, 1, 1, 2, 3, 3, 0, 1, 1, 2, 3, 3]; //4, 5, 5, 6, 7, 7, 8, 9, 9];
  let tokenIdxs2 = [1, 0, 0, 3, 2, 2, 1, 0, 0, 3, 2, 2]; //5, 4, 4, 7, 6, 6, 9, 8, 8];
  let amounts1 = [
    5000, 1500, 1000, 4000, 1500, 500, 3000, 1000, 500, 2000, 700, 300, 1000,
    350, 150,
  ];
  let amounts2 = [
    2500, 3000, 2000, 2000, 3000, 1000, 1500, 2000, 1000, 1000, 1400, 600, 500,
    700, 300,
  ];

  let limitOrders = [];
  for (let i = 0; i < users.length; i++) {
    const user = users[i];

    let limitOrder = user.make_limit_order(
      i,
      1000,
      tokenIdxs1[i],
      tokenIdxs2[i],
      amounts1[i],
      amounts2[i],
      user.account_space_idxs[tokenIdxs1[i]],
      user.account_space_idxs[tokenIdxs2[i]],
      10
    );

    limitOrders.push(limitOrder);
  }

  return limitOrders;
}

function update_merkle_tree(prev_acc_spaces, new_acc_spaces) {
  if (prev_acc_spaces.length != new_acc_spaces.length) {
    throw "Error: prev_acc_spaces.length != new_acc_spaces.length";
  }

  let prev_hashes = prev_acc_spaces.map((space) => space.hash);
  // let new_hashes = new_acc_spaces.map((space) => space.hash);

  let depth = Math.ceil(Math.log2(prev_acc_spaces.length));

  let tree = new Tree(prev_hashes, depth);

  let prev_root = tree.root;

  // ============================================================
  console.time("multiUpdateProofsIn");
  let multiUpdateProofsIn = [];
  let proofsIn = [];
  for (let i = 0; i < prev_hashes.length; i++) {
    let proof = tree.getProof(prev_acc_spaces[i].index);
    let multiUpdateProof = tree.getMultiUpdateProof(
      prev_hashes[i],
      proof.proof,
      proof.proofPos
    );
    multiUpdateProofsIn.push(multiUpdateProof);
    if (i == 0) {
      proofsIn.push(proof.proof);
    }
  }
  console.timeEnd("multiUpdateProofsIn");

  // ============================================================

  console.time("tree Updates");
  for (let i = 0; i < new_acc_spaces.length; i++) {
    tree.updateNode(
      new_acc_spaces[i].hash,
      new_acc_spaces[i].index,
      proofsIn[i]
    );

    if (i < new_acc_spaces.length - 1) {
      let nextProof = tree.getProof(new_acc_spaces[i + 1].index);
      proofsIn.push(nextProof.proof);
    }
  }
  console.timeEnd("tree Updates");

  // ============================================================

  console.time("multiUpdateProofsOut");
  let multiUpdateProofsOut = [];
  for (let i = 0; i < new_acc_spaces.length; i++) {
    let proof = tree.getProof(new_acc_spaces[i].index); //(notes_out[i].index);
    let multiUpdateProof2 = tree.getMultiUpdateProof(
      new_acc_spaces[i].hash,
      proof.proof,
      proof.proofPos
    );

    multiUpdateProofsOut.push(multiUpdateProof2);
  }
  console.timeEnd("multiUpdateProofsOut");

  // ============================================================

  console.time("preimage_dict");
  let preimage = {};
  for (let i = 0; i < multiUpdateProofsIn.length; i++) {
    multiUpdateProofsIn[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }
  for (let i = 0; i < multiUpdateProofsOut.length; i++) {
    multiUpdateProofsOut[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }
  console.timeEnd("preimage_dict");

  return { preimage, prev_root, new_root: tree.root };
}

function dummy___swaps() {
  let pk1 = 123456789n;
  let pk2 = 987654321n;
  let pk3 = 16425612212n;

  const user1 = new UnshieldedUser(0, pk1);
  const user2 = new UnshieldedUser(1, pk2);
  const user3 = new UnshieldedUser(2, pk3);

  // token1 = 2 * token2;

  let acc_spaceA_index1 = 0;
  let acc_spaceA_index2 = 1;
  let acc_spaceB_index1 = 2;
  let acc_spaceB_index2 = 3;
  let acc_spaceC_index1 = 4;
  let acc_spaceC_index2 = 5;

  // taker
  let token1 = 0;
  let amount_spent_A = 500;
  let amount_received_A = 1000;
  // makers
  let token2 = 1;
  let amount_spent_B = 700;
  let amount_received_B = 350;

  let fee_A = 0;
  let fee_B = 0;

  let amount_spent_C = 305;
  let amount_received_C = 150;

  user1.init_account_space(token1, 1100, acc_spaceA_index1);
  user1.init_account_space(token2, 0, acc_spaceA_index2);
  user2.init_account_space(token1, 0, acc_spaceB_index1);
  user2.init_account_space(token2, 1440, acc_spaceB_index2);
  user3.init_account_space(token1, 0, acc_spaceC_index1);
  user3.init_account_space(token2, 660, acc_spaceC_index2);

  let initUserSpaces = user1
    .all_account_spaces()
    .concat(user2.all_account_spaces())
    .concat(user3.all_account_spaces());

  initUserSpaces = initUserSpaces.map((space) =>
    Object.assign(Object.create(Object.getPrototypeOf(space)), space)
  );

  let dummy_fee_limit = 10;

  // user1<=>user2 --swap-- 350 token1 <=> 700 token2
  // user1<=>user3 --swap-- 305 token1 <=> 150 token2

  let limitOrder1 = user1.make_limit_order(
    0,
    1000,
    token1,
    token2,
    amount_spent_A,
    amount_received_A,
    acc_spaceA_index1,
    acc_spaceA_index2,
    dummy_fee_limit
  );

  let limitOrder2 = user2.make_limit_order(
    1,
    1000,
    token2,
    token1,
    amount_spent_B,
    amount_received_B,
    acc_spaceB_index2,
    acc_spaceB_index1,
    dummy_fee_limit
  );

  let limitOrder3 = user3.make_limit_order(
    2,
    1000,
    token2,
    token1,
    amount_spent_C,
    amount_received_C,
    acc_spaceC_index2,
    acc_spaceC_index1,
    dummy_fee_limit
  );

  user1.verify_order_signature(limitOrder1.signature, limitOrder1.order_hash);
  user2.verify_order_signature(limitOrder2.signature, limitOrder2.order_hash);
  user3.verify_order_signature(limitOrder3.signature, limitOrder3.order_hash);

  // initUserSpaces.forEach((space) => space.logAccountSpace());

  limitOrder1.logLimitOrder();
  limitOrder2.logLimitOrder();
  limitOrder3.logLimitOrder();

  user1.swap_update_balances(
    token1,
    amount_spent_A,
    token2,
    amount_spent_C - fee_B + amount_spent_B - fee_B
  );
  user2.swap_update_balances(
    token2,
    amount_spent_B,
    token1,
    amount_received_B - fee_B
  );
  user3.swap_update_balances(
    token2,
    amount_spent_C,
    token1,
    amount_received_C - fee_B
  );

  // let swap1 = new UnshieldedSwap(limitOrder1, limitOrder2, user1, user2);
  // let swap2 = new UnshieldedSwap(limitOrder1, limitOrder3, user1, user3);

  // let sig1 = user1.sign_order(limitOrder1.order_hash);
  // let sig2 = user2.sign_order(limitOrder2.order_hash);
  // let sig3 = user3.sign_order(limitOrder3.order_hash);

  // swap1.executeSwap(sig1, sig2);
  // swap2.executeSwap(sig1, sig3);
}
