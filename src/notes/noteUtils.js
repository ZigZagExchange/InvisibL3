const poseidon = require("../../circomlib/src/poseidon");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const Secp256k1 = require("@enumatech/secp256k1-js");
const bigInt = require("big-integer");
const randomBigInt = require("random-bigint");

//* =============================================================================
//* CLASSES

class Note {
  constructor(K, C, T, idx = 0) {
    // index is used to position it among other notes in the merkle tree
    this.index = idx;
    this.address = K;
    this.token = T;
    this.commitment = C;
    this.hash = this.hashNote();
  }

  hashNote() {
    let addr;
    if (this.address.length == 3) {
      addr = Secp256k1.JtoA(this.address);
    } else {
      addr = this.address;
    }

    let addrHighLowY = splitUint256(addr[1].toString());
    let addrHighLowX = splitUint256(addr[0].toString());

    return BigInt(
      computeHashOnElements([
        pedersen([addrHighLowX.high, addrHighLowX.low]),
        pedersen([addrHighLowY.high, addrHighLowY.low]),
        this.token,
        this.commitment,
      ]),
      16
    );
  }
}

//* =============================================================================
//* HELPER FUNCTIONS

function split(num) {
  const BASE = bigInt(2).pow(86).value;

  num = BigInt(num);
  let a = [];
  for (let i = 0; i < 3; i++) {
    let res = bigInt(num).divmod(BASE);
    num = res.quotient;
    a.push(res.remainder.value);
  }
  if (num != 0) {
    throw new Error("num is not 0");
  }

  return a;
}

function splitUint256(num) {
  let divRem = bigInt(num).divmod(bigInt(2).pow(128));

  return { high: divRem.quotient.value, low: divRem.remainder.value };
}

function newCommitment(amount, blinding_factor) {
  let Gx = ecMul(G, blinding_factor);
  let Ha = ecMul(H, amount);
  return ecAdd(Gx, Ha);
}

//TODO Move this two functions to User.js User class
function generateOneTimeAddress(Kv, Ks, r) {
  // takes just the first 250 bits of the hash (both for cairo curve and for circom)
  // Ko =  H(r * Kv)G + Ks

  if (Kv.length == 2) {
    Kv = Secp256k1.AtoJ(Kv[0], Kv[1]);
  }
  if (Ks.length == 2) {
    Ks = Secp256k1.AtoJ(Ks[0], Ks[1]);
  }

  let rKv = Secp256k1.ecmul(Kv, Secp256k1.uint256(r));

  rKv = Secp256k1.JtoA(rKv);
  let h = trimHash(poseidon(rKv), 250);

  let hG = Secp256k1.mulG(Secp256k1.uint256(h));
  hG = Secp256k1.AtoJ(hG[0], hG[1]);

  return Secp256k1.ecadd(hG, Ks);
}

function oneTimeAddressPrivKey(Kv, priv_spend_key, r) {
  // takes just the first 250 bits of the hash
  // ko = H(r * Kv) + ks

  if (Kv.length == 2) {
    Kv = Secp256k1.AtoJ(Kv[0], Kv[1]);
  }
  let rKv = Secp256k1.ecmul(Kv, Secp256k1.uint256(r));

  let _rKv = Secp256k1.JtoA(rKv);
  let h = trimHash(poseidon(_rKv), 250);

  return h + priv_spend_key;
}

function trimHash(hash, n_bits = 128) {
  // returns the last n_bits number of the number as bigInt
  return bigInt(hash).and(bigInt(1).shiftLeft(n_bits).prev()).value;
}

function cmtzPrivKeys(notes, amounts, blindings_in, blindings_out) {
  const blindingsOutSum = blindings_out.reduce(
    (partialSum, a) => partialSum + a,
    0n
  );

  // Might change this to zero at all except for the last one by default
  let pos = []; // 0 if previous randomness is grater than the new one, 1 otherwise
  let blindingsSum = 0n;
  let new_blindings = [];
  let priv_keys_z = [];

  for (let i = 0; i < notes.length; i++) {
    const note = notes[i];
    const amount = amounts[i];
    const blinding_factor = blindings_in[i];

    let Gx = ecMul(G, blinding_factor);
    let Ha = ecMul(H, amount);
    if (
      ecAdd(Gx, Ha)[0] !== note.commitment[0] ||
      ecAdd(Gx, Ha)[1] !== note.commitment[1]
    ) {
      throw "amount and blinding factors dont match the commitment";
    }
    if (i == notes.length - 1) {
      let xm_ = blindingsOutSum - blindingsSum;
      let z;
      if (xm_ > blinding_factor) {
        z = xm_ - blinding_factor;
        pos.push(1);
      } else {
        z = blinding_factor - xm_;
        pos.push(0);
      }
      new_blindings.push(xm_);
      priv_keys_z.push(z);
    } else {
      let xi_ = randomBigInt(114);
      new_blindings.push(xi_);

      blindingsSum += xi_;
      let z;
      if (xi_ > blinding_factor) {
        z = xi_ - blinding_factor;
        pos.push(1);
      } else {
        z = blinding_factor - xi_;
        pos.push(0);
      }
      priv_keys_z.push(z);
    }
  }

  return { priv_keys_z, new_blindings, pos };
}

function newCommitments(amounts, blindings) {
  let new_comms = [];
  if (amounts.length !== blindings.length) {
    throw "input lenghts missmatch";
  }

  for (let i = 0; i < amounts.length; i++) {
    if (blindings <= 0 || amounts <= 0) {
      throw "amounts and blindings should always be positive";
    }

    const new_comm = newCommitment(amounts[i], blindings[i]);

    new_comms.push(new_comm);
  }
  return new_comms;
}

function cmtzPubKeys(notes_in, pseudo_commitments, pos) {
  if (notes_in.length != pseudo_commitments.length) {
    throw "length missmatch between previous and new commitments";
  }

  // console.log(notes_in[0].commitment, pseudo_commitments);
  let Zs = [];
  for (let i = 0; i < notes_in.length; i++) {
    // If pos[i] == 1 than new blindings are bigger than the previous ones
    if (pos[i]) {
      Zs.push(ecSub(pseudo_commitments[i], notes_in[i].commitment));
    } else {
      Zs.push(ecSub(notes_in[i].commitment, pseudo_commitments[i]));
    }
  }
  return Zs;
}

module.exports = {
  newCommitment,
  newCommitments,
  generateOneTimeAddress,
  oneTimeAddressPrivKey,
  trimHash,
  cmtzPrivKeys,
  cmtzPubKeys,
  Note,
  split,
  splitUint256,
};
