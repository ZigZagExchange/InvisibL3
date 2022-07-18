const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const randomBigInt = require("random-bigint");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");

// A private limit Order class
module.exports = class InvisibleOrder {
  constructor(
    orderId,
    expiration_timestamp,
    token_spent,
    token_received,
    amount_spent,
    amount_received,
    fee_limit,
    dest_spent_address,
    dest_received_address,
    blinding_seed,
    notesIn,
    refund_note
  ) {
    this.orderId = orderId;
    this.expiration_timestamp = expiration_timestamp;
    this.token_spent = token_spent;
    this.token_received = token_received;
    this.amount_spent = amount_spent;
    this.amount_received = amount_received;
    this.fee_limit = fee_limit;
    this.dest_spent_address = dest_spent_address;
    this.dest_received_address = dest_received_address;
    this.blinding_seed = blinding_seed;
    // ==================================
    this.notesIn = notesIn;
    this.refund_note = refund_note;
    // this.order_hash = this.hashOrder();
    this.signatures = null;
    this.partialFillRefundNote = null;
    this.amountFilled = 0n;
  }

  hashOrder() {
    let noteHashes = this.notesIn.map((note) => note.hash);
    let refundHash = this.refund_note.hash;

    let hashInputs = noteHashes
      .concat(refundHash)
      .concat([
        this.orderId,
        this.expiration_timestamp,
        this.token_spent,
        this.token_received,
        this.amount_spent,
        this.amount_received,
        this.fee_limit,
        BigInt(this.dest_spent_address.getX()),
        BigInt(this.dest_received_address.getX()),
        this.blinding_seed,
      ]);

    return computeHashOnElements(hashInputs);
  }

  sign_order(signingKeys) {
    let signatures = [];
    let order_hash = this.hashOrder();

    for (let i = 0; i < signingKeys.length; i++) {
      const keyPair = signingKeys[i];

      let sig = sign(keyPair, order_hash.toString(16));
      signatures.push(sig);
    }

    this.signatures = signatures;
    return this.signatures;
  }

  verify_order_signatures() {
    let order_hash = this.hashOrder();

    for (let i = 0; i < this.notesIn.length; i++) {
      let verifyKeyPair = getKeyPairFromPublicKey(this.notesIn[i].address_pk_);

      if (!verify(verifyKeyPair, order_hash.toString(16), this.signatures[i])) {
        throw new Error("Signature verification failed");
      }
    }

    console.log("Signature verification successful");
  }

  toInputObject() {
    let inputObject = {};

    inputObject.notes_in = this.notesIn.map((note) => note.toInputObject());
    inputObject.refund_note = this.refund_note.toInputObject();
    inputObject.orderId = this.orderId;
    inputObject.expiration_timestamp = this.expiration_timestamp;
    inputObject.token_spent = this.token_spent;
    inputObject.token_received = this.token_received;
    inputObject.amount_spent = this.amount_spent;
    inputObject.amount_received = this.amount_received;
    inputObject.fee_limit = this.fee_limit;
    inputObject.dest_spent_address = this.dest_spent_address.getX().toString();
    inputObject.dest_received_address = this.dest_received_address
      .getX()
      .toString();
    inputObject.blinding_seed = this.blinding_seed;
    inputObject.signatures = this.signatures;

    // inputObject = JSON.stringify(inputObject, (key, value) => {
    //   return typeof value === "bigint" ? value.toString() : value;
    // });

    return inputObject;
  }
};
