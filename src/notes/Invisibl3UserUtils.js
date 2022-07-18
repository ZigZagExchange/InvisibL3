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

const {
  trimHash,
  Note,
  newCommitment,
  split,
  splitUint256,
} = require("./Notes.js");

const COMMITMENT_MASK = 112233445566778899n;
const AMOUNT_MASK = 998877665544332112n;

function _generateSubaddress(privSpendKey, privViewKey, i) {
  // Ksi = Ks + H(kv, i)*G   == (ks + H(kv, i))* G
  // Kvi = kv*Ksi         == kv*(ks + H(kv, i))* G

  let ksi = privSpendKey + pedersen([privViewKey, i]);
  let Ksi = ec.g.mul(ksi.toString(16));
  let Kvi = Ksi.mul(privViewKey.toString(16));
  // Kvi = getKeyPairFromPublicKey(Kvi);

  return { Kvi, Ksi };
}

function _subaddressPrivKeys(privSpendKey, privViewKey, i) {
  // ksi = ks + H(kv, i)
  // kvi = kv*ksi

  const ksi = privSpendKey + pedersen([privViewKey, i]);
  const kvi = privViewKey * ksi;

  return { ksi, kvi };
}

// ? Kv and Ks should always be input as points not KeyPairs
function _generateOneTimeAddress(Kv, Ks, r) {
  // Ko =  H(r * Kv)G + Ks

  let rKv = Kv.mul(r.toString(16));
  let h = pedersen([rKv.getX(), rKv.getY()]);

  return ec.g.mul(h.toString(16)).add(Ks);
}

function _oneTimeAddressPrivKey(Kv, ks, r) {
  // ko = H(r * Kv) + ks
  let rKv = Kv.mul(r.toString(16));
  let h = pedersen([rKv.getX(), rKv.getY()]);

  return h + ks;
}

// Each output of a transaction should have this hiding
function _hideValuesForRecipient(recipient_Kv, amount, r) {
  // TODO: Add something so that the blindind is always different
  // r is the transaction priv key (randomly generated)
  // yt = H("comm_mask", H(rKv, t))  (NOTE: t is used to make the values unique and we are omitting it for now)
  // amount_t = bt XOR8 H("amount_mask", H(rKv, t))  -> (where bt is the 64 bit amount of the note)

  let rKv = recipient_Kv.mul(r.toString(16));

  let rKv_hash = pedersen([rKv.getX(), rKv.getY()]);

  let hash8 = trimHash(pedersen([AMOUNT_MASK, rKv_hash]), 64);
  let hiddentAmount = bigInt(amount).xor(hash8).value;

  let yt = pedersen([COMMITMENT_MASK, rKv_hash]); // this is the blinding used in the commitment

  return { yt, hiddentAmount };
}

// Used to reveal the blindings and amounts of the notes addressed to this user's ith subaddress
function _revealHiddenValues(
  rG,
  hiddenAmount,
  privSpendKey,
  privViewKey,
  ith = 1
) {
  // yt = H("comm_mask", H(rG*kv, t))
  // amount_t = bt XOR8 H("amount_mask", H(rG*kv, t))

  const privKeys = _subaddressPrivKeys(privSpendKey, privViewKey, ith);

  let rKv = rG.mul(privKeys.kvi.toString(16));

  let rKv_hash = pedersen([rKv.getX(), rKv.getY()]);

  let hash8 = trimHash(pedersen([AMOUNT_MASK, rKv_hash]), 64);
  let amount = bigInt(hiddenAmount).xor(hash8).value;

  let yt = pedersen([COMMITMENT_MASK, rKv_hash]); // this is the blinding used in the commitment

  return { yt, amount };
}

// Checks if the transaction is addressed to this user's its subaddress
function _checkOwnership(rKsi, Ko, privSpendKey, privViewKey, ith = 1) {
  // Ko is defined as H(rKvi)G + Ksi
  // kv*rKsi = rKvi
  // Ks' = Ko - H(rKvi,0)G
  // If Ks' === Ksi (calculated Ks' equals his subbadress Ksi) than its addressed to him

  const subaddress = _generateSubaddress(privSpendKey, privViewKey, ith);

  let rKvi = rKsi.mul(privViewKey.toString(16));

  let h = pedersen([rKvi.getX(), rKvi.getY()]);
  let hG = ec.g.mul(h.toString(16));
  let hG_neg = hG.neg();

  let Ks_prime = Ko.add(hG_neg);

  return Ks_prime.encode("hex", true) === subaddress.Ksi.encode("hex", true);
}

module.exports = {
  _generateSubaddress,
  _subaddressPrivKeys,
  _generateOneTimeAddress,
  _oneTimeAddressPrivKey,
  _hideValuesForRecipient,
  _revealHiddenValues,
  _checkOwnership,
};
