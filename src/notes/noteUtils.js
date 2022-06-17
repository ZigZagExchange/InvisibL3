const poseidon = require("../../circomlib/src/poseidon");
const G = require("../../circomlib/src/babyjub.js").Generator;
const H = require("../../circomlib/src/babyjub.js").Base8;
const F = require("../../circomlib/src/babyjub.js").F;
const ecMul = require("../../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../../circomlib/src/babyjub.js").subPoint;
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
    if (this.commitment.length == 2) {
      return poseidon([
        // this.index,
        this.address[0],
        this.address[1],
        this.token,
        this.commitment[0],
        this.commitment[1],
      ]);
    } else {
      return poseidon([
        // this.index,
        this.address[0],
        this.address[1],
        this.token,
        this.commitment,
      ]);
    }
  }
}

//* =============================================================================
//* HELPER FUNCTIONS

function newCommitment(amount, blinding_factor) {
  let Gx = ecMul(G, blinding_factor);
  let Ha = ecMul(H, amount);
  return ecAdd(Gx, Ha);
}

//TODO Move this two functions to User.js Uesr class
function generateOneTimeAddress(pub_view_key, pub_spend_key, r) {
  // takes just the first 250 bits of the hash (both for cairo curve and for circom)
  // Ko =  H(r * Kv)G + Ks

  let rKv = ecMul(pub_view_key, r);
  rKv.push(0);
  let h = poseidon(rKv);

  return ecAdd(ecMul(G, h), pub_spend_key);
}

function oneTimeAddressPrivKey(pub_view_key, priv_spend_key, r) {
  // takes just the first 250 bits of the hash
  // ko = H(r * Kv) + ks
  let rKv = ecMul(pub_view_key, r);
  rKv.push(0);
  let h = poseidon(rKv);
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
};
