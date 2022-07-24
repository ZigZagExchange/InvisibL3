const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

const { Note } = require("../../src/notes/Notes");
const User = require("../../src/notes/Invisibl3User.js");
const Tree = require("../../src/merkle_trees/Tree.js");

const {
  fetchStoredUser,
  fetchUserIds,
} = require("../../src/firebase/storeUserData");
const InvisibleSwap = require("../../src/transactions/InvisibleSwap");

var fs = require("fs");

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
