const Secp256k1 = require("@enumatech/secp256k1-js");
const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const { KeyPair } = require("starknet/types");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
} = require("starknet/utils/ellipticCurve");

const randomBigInt = require("random-bigint");
const poseidon = require("../../circomlib/src/poseidon.js");

const COMMITMENT_MASK = 112233445566778899n;
const AMOUNT_MASK = 998877665544332112n;
const MAX_AMOUNT = 2n ** 90n;
const MAX_NONCE = 2 ** 32;
const MAX_EXPIRATION_TIMESTAMP = 2 ** 32;

class UnshieldedUser {
  // Each user has a class where he stores all his information (should never be shared with anyone)
  // private keys should be 240 bits
  constructor(id, _privKey) {
    this.id = id;
    this.privKey = _privKey;
    this.keyPair = getKeyPair(_privKey.toString());
    this.pubKey = BigInt(getStarkKey(this.keyPair), 16);

    this.account_space_idxs = {}; // map of {token: idx}
    this.account_spaces = {}; // map of {token: AccountSpace}
  }

  init_account_space(token_id, amount, idx) {
    let accSpace = new AccountSpace(idx, this.pubKey, token_id, amount);
    this.account_spaces[token_id] = accSpace;
    this.account_space_idxs[token_id] = idx;
  }

  increase_token_balance(token_id, amount) {
    // if amount < 0, decrease balance
    if (!this.account_spaces[token_id]) {
      throw "account space not set -- call init_account_space first";
    }
    if (
      amount < 0 &&
      this.account_spaces[token_id].balance < Math.abs(amount)
    ) {
      throw "balance too low";
    }

    this.account_spaces[token_id].increase_balance(amount);
  }

  sign_order(msg) {
    return sign(this.keyPair, msg.toString(16));
  }

  verify_order_signature(signature, order_hash) {
    verify(this.keyPair, order_hash.toString(16), signature);
    console.log("signature verified");
  }

  make_limit_order(
    nonce,
    expiration_timestamp,
    token_spent,
    token_received,
    amount_spent,
    amount_received,
    spender_account_idx,
    receiver_account_idx,
    fee_limit
  ) {
    let limitOrder = new LimitOrder(
      nonce,
      this.pubKey,
      expiration_timestamp,
      token_spent,
      token_received,
      amount_spent,
      amount_received,
      spender_account_idx,
      receiver_account_idx,
      fee_limit
    );

    let sig = this.sign_order(limitOrder.order_hash);

    limitOrder.set_signature(sig);

    return limitOrder;
  }

  swap_update_balances(
    token_spent,
    amount_spent,
    token_received,
    amount_received
  ) {
    this.increase_token_balance(token_spent, -amount_spent);
    this.increase_token_balance(token_received, amount_received);
  }

  all_account_spaces() {
    return Object.values(this.account_spaces);
  }
}

class AccountSpace {
  constructor(index, pubKey, token, balance) {
    this.index = index;
    this.pubKey = pubKey;
    this.token = token;
    this.balance = balance;
    this.hash = this.compute_hash();
  }

  compute_hash() {
    if (this.balance == 0) {
      return 0;
    }
    return BigInt(
      computeHashOnElements([this.pubKey, this.token, this.balance]),
      16
    );
  }

  increase_balance(amount) {
    this.balance += BigInt(amount);
    this.hash = this.compute_hash();
  }

  logAccountSpace() {
    console.log(this.index, ": ", [this.pubKey, this.token, this.balance]);
  }
}

class LimitOrder {
  constructor(
    nonce,
    public_key,
    expiration_timestamp,
    token_spent,
    token_received,
    amount_spent,
    amount_received,
    spender_account_idx,
    receiver_account_idx,
    fee_limit
  ) {
    this.nonce = nonce;
    this.public_key = public_key;
    this.expiration_timestamp = expiration_timestamp;
    this.signature = null;
    this.token_spent = token_spent;
    this.token_received = token_received;
    this.amount_spent = amount_spent;
    this.amount_received = amount_received;
    this.spender_account_idx = spender_account_idx;
    this.receiver_account_idx = receiver_account_idx;
    this.fee_limit = fee_limit;
    this.order_hash = this.hashLimitOrder();
    this.fills_spent = 0;
    this.fills_received = 0;
  }

  hashLimitOrder() {
    let bundled_amounts = bigInt(this.amount_spent)
      .multiply(2n ** 122n)
      .add(bigInt(this.amount_received).multiply(2n ** 32n))
      .add(this.nonce).value;

    let bundled_tokens = bigInt(this.token_spent)
      .multiply(2n ** 150n)
      .add(bigInt(this.token_received).multiply(2n ** 75n))
      .add(this.fee_limit).value;

    let bundled_accounts = bigInt(this.spender_account_idx)
      .multiply(2n ** 122n)
      .add(bigInt(this.receiver_account_idx).multiply(2n ** 32n))
      .add(this.expiration_timestamp).value;

    return BigInt(
      computeHashOnElements([
        bundled_amounts,
        bundled_tokens,
        bundled_accounts,
      ]),
      16
    );
  }

  sign_limit_order(user) {
    this.signature = user.sign_order(this.order_hash);
    return this.signature;
  }

  set_signature(signature) {
    this.signature = signature;
  }

  logLimitOrder() {
    console.log(this.limitOrderToJSON());
  }

  limitOrderToInputObject() {
    let inputObject = {};

    inputObject.nonce = this.nonce;
    inputObject.public_key = this.public_key;
    inputObject.expiration_timestamp = this.expiration_timestamp;
    inputObject.signature = this.signature;
    inputObject.token_spent = this.token_spent;
    inputObject.token_received = this.token_received;
    inputObject.amount_spent = this.amount_spent;
    inputObject.amount_received = this.amount_received;
    inputObject.spender_account_idx = this.spender_account_idx;
    inputObject.receiver_account_idx = this.receiver_account_idx;
    inputObject.fee_limit = this.fee_limit;

    // JSON_Object = JSON.stringify(JSON_Object, (key, value) => {
    //   return typeof value === "bigint" ? value.toString() : value;
    // });

    return inputObject;
  }
}

class UnshieldedSwap {
  constructor(limitOrderA, limitOrderB, userA, userB) {
    this.limitOrderA = limitOrderA;
    this.limitOrderB = limitOrderB;
    this.userA = userA;
    this.userB = userB;
  }

  executeSwap(sigA, sigB) {
    this._range_checks();
    this._balance_checks();

    if (
      this.limitOrderA.token_spent !== this.limitOrderB.token_received ||
      this.limitOrderA.token_received !== this.limitOrderB.token_spent
    ) {
      throw "token missmatch";
    }

    let amount1 = Math.min(
      this.limitOrderA.amount_spent,
      this.limitOrderB.amount_received
    );
    let amount2 = Math.min(
      this.limitOrderA.amount_received,
      this.limitOrderB.amount_spent
    );

    if (
      amount1 * this.limitOrderA.amount_received >
        amount2 * this.limitOrderA.amount_spent ||
      amount2 * this.limitOrderB.amount_received >
        amount1 * this.limitOrderB.amount_spent
    ) {
      throw "amount ratios are incorrect";
    }

    if (
      this.limitOrderA.amount_spent < this.limitOrderA.fills_spent + amount1 ||
      this.limitOrderB.amount_spent < this.limitOrderB.fills_spent + amount2
    ) {
      throw "spending more then user signed on";
    }

    this.userA.verify_order_signature(sigA, this.limitOrderA.order_hash);
    this.userB.verify_order_signature(sigB, this.limitOrderB.order_hash);

    this.limitOrderA.set_signature(sigA);
    this.limitOrderB.set_signature(sigB);

    this.limitOrderA.fills_spent += amount1;
    this.limitOrderB.fills_spent += amount2;
    this.limitOrderA.fills_received += amount2;
    this.limitOrderB.fills_received += amount1;

    // Should add fee mechanism

    this.userA.increase_token_balance(this.limitOrderA.token_spent, -amount1);
    this.userB.increase_token_balance(this.limitOrderB.token_spent, -amount2);
    this.userA.increase_token_balance(this.limitOrderA.token_received, amount2);
    this.userB.increase_token_balance(this.limitOrderB.token_received, amount1);
  }

  _range_checks() {
    if (
      this.limitOrderA.amount_spent > MAX_AMOUNT ||
      this.limitOrderB.amount_spent > MAX_AMOUNT ||
      this.limitOrderA.amount_received > MAX_AMOUNT ||
      this.limitOrderB.amount_received > MAX_AMOUNT
    ) {
      throw "amount is too large";
    }

    if (
      this.limitOrderA.nonce > MAX_NONCE ||
      this.limitOrderB.nonce > MAX_NONCE
    ) {
      throw "nonce is too large";
    }

    if (
      this.limitOrderA.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP ||
      this.limitOrderB.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
    ) {
      throw "expiration timestamp is too large";
    }
  }

  _balance_checks() {
    if (
      this.userA.account_spaces[this.limitOrderA.token_spent].balance <
        this.limitOrderA.amount_spent ||
      this.userB.account_spaces[this.limitOrderB.token_spent].balance <
        this.limitOrderB.amount_spent
    ) {
      throw "insufficient amount";
    }
  }

  logSwap() {
    console.log(this.swapToJSON());
  }

  swapToJSON() {
    let JSON_Object = {};

    let jsonOrderA = this.limitOrderA.limitOrderToInputObject();
    let jsonOrderB = this.limitOrderB.limitOrderToInputObject();

    JSON_Object.limit_order_A = jsonOrderA;
    JSON_Object.limit_order_B = jsonOrderB;
    JSON_Object.fee_A = 0;
    JSON_Object.fee_B = 0;

    JSON_Object = JSON.stringify(JSON_Object, (key, value) => {
      return typeof value === "bigint" ? value.toString() : value;
    });

    return JSON_Object;
  }
}

module.exports = {
  UnshieldedUser,
  AccountSpace,
  UnshieldedSwap,
};
