const poseidon = require("../../circomlib/src/poseidon.js");
const ecMul = require("../../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../../circomlib/src/babyjub.js").subPoint;
const G = require("../../circomlib/src/babyjub.js").Generator;
const H = require("../../circomlib/src/babyjub.js").Base8;

const Secp256k1 = require("@enumatech/secp256k1-js");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");

const {
  Note,
  generateOneTimeAddress,
  oneTimeAddressPrivKey,
  split,
  splitUint256,
  trimHash,
} = require("../notes/noteUtils.js");

const P = 2n ** 251n + 2n ** 192n + 1n;

const NUM_NOTES = 3;

module.exports = class NoteTransaction {
  constructor(
    notesIn,
    notesOut,
    amountsIn,
    amountsOut,
    blindingsIn,
    blindingsOut,
    tokenSpent, // (the token that is being sent)
    tokenSpentPrice,
    tokenReceived, // (the token that is being received)
    tokenReceivedPrice,
    Ksi,
    Kvi,
    tx_r,
    rG = 0, // used to reveal the values sent to the recipient   (might just use r and send rG and rKsi on chain)
    rKsis = [] // used to find notes sent to the recipient
  ) {
    // PUBLIC INPUTS:
    this.notesIn = notesIn;
    this.notesOut = notesOut;
    this.return_sig_r = null; //used to make sure the user recived the trade to the right address
    this.tokenSpent = tokenSpent;
    this.tokenSpentPrice = tokenSpentPrice;

    this.tx_hash = null;

    //PRIVATE INPUTS:  (still shared with exchange or market maker)

    this.tokenReceived = tokenReceived;
    this.tokenReceivedPrice = tokenReceivedPrice;
    this.amountsIn = amountsIn;
    this.amountsOut = amountsOut;
    this.blindingsIn = blindingsIn;
    this.blindingsOut = blindingsOut;
    this.Ksi = Ksi; // the ith subbaddress spend key
    this.Kvi = Kvi; // the ith subbaddress view key
    this.tx_r = tx_r;
  }

  //* MODIFIED ===============================================================

  signTx(priv_keys) {
    let tx_hash = this.hashTransaction();

    let alphas = [];
    let c_input = [tx_hash];
    //?  c = H(tx_hash, -aG)
    for (let i = 0; i < priv_keys.length; i++) {
      // Could reveal something about the private key if alpha is to small*
      const alpha = randomBigInt(250);
      const aG = Secp256k1.mulG(Secp256k1.uint256(alpha));

      // console.log("c_input_i", aG.toString());
      let aGx = splitUint256(aG[0].toString());
      const c_input_i = pedersen([aGx.high, aGx.low]);

      c_input.push(c_input_i);
      alphas.push(alpha);
    }

    let c = BigInt(computeHashOnElements(c_input));
    let rs = [c];

    let c_split = splitUint256(c);
    let c_trimmed = c_split.high + c_split.low;

    //? ri = a + k - c  (where c is trimmed)
    for (let i = 0; i < alphas.length; i++) {
      let ri = bigInt(alphas[i]).add(priv_keys[i]).subtract(c_trimmed).value;

      if (ri >= P || ri < 0) {
        console.log("WRONG ri", ri);
        return this.signTx(priv_keys);
      }

      rs.push(ri);
    }

    return rs;
  }

  verifySig(signature) {
    let c = signature[0];
    let rs = signature.slice(1);
    let tx_hash = this.hashTransaction();

    console.log("-->tx_hash: <-- ", tx_hash);

    let c_input = [tx_hash];

    let c_split = splitUint256(c);
    let c_trimmed = c_split.high + c_split.low;
    let cG = Secp256k1.mulG(Secp256k1.uint256(c_trimmed));
    cG = Secp256k1.AtoJ(cG[0], cG[1]);

    //?  c = H(m, rG - K + c*G)     (where c is trimmed)
    for (let i = 0; i < rs.length; i++) {
      let riG = Secp256k1.mulG(Secp256k1.uint256(rs[i]));
      riG = Secp256k1.AtoJ(riG[0], riG[1]);
      let riG_plus_cG = Secp256k1.ecadd(riG, cG);
      let Ki_neg = Secp256k1.negPoint(Secp256k1.JtoA(this.notesIn[i].address));
      Ki_neg = Secp256k1.AtoJ(Ki_neg[0], Ki_neg[1]);
      let c_input_i = Secp256k1.ecadd(riG_plus_cG, Ki_neg);
      c_input_i = Secp256k1.JtoA(c_input_i);

      let highLow = splitUint256(c_input_i[0].toString());
      c_input.push(pedersen([highLow.high, highLow.low]));
    }

    let c_prime = BigInt(computeHashOnElements(c_input), 16);

    if (c_prime !== c) {
      throw "signature verification failed";
    } else {
      console.log("signature verified");
    }
  }
  signReturnAddressSig(priv_key) {
    let ret_tx_hash = this.hashPrivInputs();

    const alpha = randomBigInt(250);
    const aG = Secp256k1.mulG(Secp256k1.uint256(alpha));

    let aGx = splitUint256(aG[0].toString());
    const c_input = pedersen([aGx.high, aGx.low]);

    const c = BigInt(pedersen([ret_tx_hash, c_input]), 16);

    let c_split = splitUint256(c);
    let c_trimmed = c_split.high + c_split.low;

    let sig = [c];

    const r = bigInt(alpha).add(priv_key).subtract(c_trimmed).value;

    if (r >= P || r < 0) {
      // console.log("r is wrong", r.toString(2).length);
      return this.signReturnAddressSig(priv_key);
    }

    this.return_sig_r = r;
    sig.push(r);

    return sig;
  }

  verifyRetAddrSig(signature, Ko = null, tokenR = null, tokenRPrice = null) {
    let c = signature[0];
    let r = signature[1];
    let ret_tx_hash = this.hashPrivInputs(tokenR, tokenRPrice);

    if (!Ko) {
      Ko = generateOneTimeAddress(this.Kvi, this.Ksi, this.tx_r);
      Ko = Secp256k1.JtoA(Ko);
      console.log("Unsafe: Should provide your own Ko");
    } else if (Ko.length === 3) {
      Ko = Secp256k1.JtoA(Ko);
    }

    let c_split = splitUint256(c);
    let c_trimmed = c_split.high + c_split.low;

    let cG = Secp256k1.mulG(Secp256k1.uint256(c_trimmed));
    cG = Secp256k1.AtoJ(cG[0], cG[1]);

    //?  c = H(m, rG - K + c*G)     (where c is trimmed)
    let rG = Secp256k1.mulG(Secp256k1.uint256(r));
    rG = Secp256k1.AtoJ(rG[0], rG[1]);
    let rG_plus_cG = Secp256k1.ecadd(rG, cG);
    let K_neg = Secp256k1.negPoint(Ko);
    K_neg = Secp256k1.AtoJ(K_neg[0], K_neg[1]);
    let c_input = Secp256k1.ecadd(rG_plus_cG, K_neg);
    c_input = Secp256k1.JtoA(c_input);

    let highLow = splitUint256(c_input[0].toString());
    let c_hash = BigInt(pedersen([highLow.high, highLow.low]), 16);

    let c_prime = BigInt(pedersen([ret_tx_hash, c_hash]), 16);

    if (c_prime !== c) {
      throw "return address signature verification failed";
    } else {
      console.log("return address signature verified");
    }
  }

  // Helpers
  hashTransaction() {
    let return_sig_r = this.return_sig_r;

    // ===================================================
    // hash input notes
    let hashes_in = [];
    for (let i = 0; i < this.notesIn.length; i++) {
      const hash = this.notesIn[i].hash;

      if (this.notesIn[i].token !== this.tokenSpent) {
        throw "token missmatch";
      }
      hashes_in.push(hash);
    }
    // ===================================================
    // hash output notes
    let hashes_out = [];
    for (let i = 0; i < this.notesOut.length; i++) {
      const hash = this.notesOut[i].hash;

      if (this.notesOut[i].token !== this.tokenSpent) {
        throw "token missmatch";
      }

      hashes_out.push(hash);
    }
    // ===================================================

    let hash_input = hashes_in
      .concat(hashes_out)
      .concat([this.tokenSpent, this.tokenSpentPrice, return_sig_r]);

    return BigInt(computeHashOnElements(hash_input), 16);
  }

  hashPrivInputs(tokenReceived, tokenReceivedPrice) {
    //TODO: Add amount and blinding to the signature

    tokenReceived = tokenReceived ?? this.tokenReceived;
    tokenReceivedPrice = tokenReceivedPrice ?? this.tokenReceivedPrice;

    return pedersen([tokenReceived, tokenReceivedPrice]);
  }

  verifySums() {
    let inputSum = 0n;
    let outputSum = 0n;

    for (let i = 0; i < this.notesIn.length; i++) {
      const note = this.notesIn[i];

      let comm = pedersen([this.amountsIn[i], this.blindingsIn[i]]);

      if (note.commitment !== comm) {
        throw "amount or blinding missmatch in input notes";
      }

      inputSum += this.amountsIn[i];
    }

    for (let i = 0; i < this.notesOut.length; i++) {
      const note = this.notesOut[i];

      let comm = pedersen([this.amountsOut[i], this.blindingsOut[i]]);

      if (note.commitment !== comm) {
        throw "amount or blinding missmatch in output notes";
      }

      outputSum += this.amountsOut[i];
    }

    if (inputSum != outputSum) {
      throw "outputs sum is not equal to the inputs sum";
    }
  }

  //* MODIFIED ===============================================================

  //! DEPRECATED ===============================================================

  signPrivateReturnAddress_deprecated(privSpendKey) {
    // using this as a Fiat-Shamir heuristic
    let hash = this.hashPrivateInputs();

    const ko = oneTimeAddressPrivKey(this.Kvi, privSpendKey, this.tx_r);

    let alpha = randomBigInt(240);
    let aG = ecMul(G, alpha);

    let c = poseidon([hash, aG[0], aG[1]]);

    let c_trimed = trimHash(c, 240);

    const r = alpha + ko - c_trimed;

    this.return_sig_r = r;

    if (r < 0) {
      throw "Should set k to 240 bits so r is positive";
    }

    return [c, r];
  }

  signTransaction_deprecated(note_priv_keys) {
    // Currently only supports max 6 notes per transaction (14 inputs, one is the msg_hash)
    if (note_priv_keys.length > NUM_NOTES) {
      throw "currently max NUM_NOTES notes per transaction allowed";
    }

    let tx_hash = this.hashTransaction();
    let alphas = [];
    let c_input = [tx_hash];

    //?  c = H(tx_hash, aG)
    for (let i = 0; i < NUM_NOTES; i++) {
      if (i >= note_priv_keys.length) {
        c_input.push(0n);
        c_input.push(1n);
        alphas.push(0n);
      } else {
        let alpha = randomBigInt(240);
        alphas.push(alpha);
        let aG = ecMul(G, alpha);
        c_input.push(aG[0]);
        c_input.push(aG[1]);
      }
    }

    let c = poseidon(c_input);

    //? ri = a - k + c
    let sig = [c];
    for (let i = 0; i < NUM_NOTES; i++) {
      if (i >= note_priv_keys.length) {
        sig.push(c);
      } else {
        let r = alphas[i] - note_priv_keys[i] + c;
        sig.push(r);
      }
    }

    return sig;
  }

  verifyPrivReturnAddressSig_deprecated(
    sig,
    Ko = null,
    tokenR = null,
    tokenRPrice = null
  ) {
    const c = sig[0];
    const r = sig[1];

    // using this as a Fiat-Shamir heuristic
    let hash;
    if (!tokenR || !tokenRPrice) {
      hash = this.hashPrivateInputs();
    } else {
      hash = poseidon([tokenR, tokenRPrice]);
    }

    if (!Ko) {
      Ko = generateOneTimeAddress(this.Kvi, this.Ksi, this.tx_r);
      console.log("Unsafe: Should provide your own Ko");
    }

    let c_trimed = trimHash(c, 240);

    // c = H(rG - K + cG)
    const c_input = ecSub(ecAdd(ecMul(G, r), ecMul(G, c_trimed)), Ko);

    const c_prime = poseidon([hash, c_input[0], c_input[1]]);

    if (c_prime !== c) {
      throw "return address signature verification failed";
    } else {
      console.log("return address signature verified");
    }
  }

  verifySignature_deprecated(signature) {
    // Currently only supports max 6 notes per transaction
    if (this.notesIn.length > NUM_NOTES) {
      throw "currently max NUM_NOTES notes per transaction allowed";
    }
    // if (this.notesIn.length !== signature.length - 1) {
    //   throw "key and signature lengths missmatch";
    // }

    let c = signature[0];
    let rs = signature.slice(1);

    let tx_hash = this.hashTransaction();
    let c_input = [tx_hash];

    //?  c = H(m, rG + K - c*G)

    for (let i = 0; i < NUM_NOTES; i++) {
      if (i >= this.notesIn.length) {
        c_input.push(0n);
        c_input.push(1n);
      } else {
        let rG = ecMul(G, rs[i]);
        let cG = ecMul(G, c);
        let rG_plus_K = ecAdd(rG, this.notesIn[i].address);
        let c_input_i = ecSub(rG_plus_K, cG);

        c_input.push(c_input_i[0]);
        c_input.push(c_input_i[1]);
      }
    }
    // console.log(c_input);

    let c_prime = poseidon(c_input);
    if (c_prime !== c) {
      throw "signature verification failed";
    } else {
      console.log("signature verified");
      // this.logVerifySignature(signature);
    }
  }

  //! DEPRECATED ===============================================================

  //* LOGGING ==================================================================
  logTransaction(retAddrSig, sig) {
    let indexes = [];
    let addresses_in = [];

    for (let i = 0; i < this.notesIn.length; i++) {
      const note = this.notesIn[i];

      indexes.push(note.index);
      addresses_in.push(note.address);
    }

    console.log('"indexes": ', indexes);
    console.log(',"token_spent": ', this.tokenSpent);
    console.log(',"token_spent_price": ', this.tokenSpentPrice);
    console.log(',"token_received": ', this.tokenReceived);
    console.log(',"token_received_price": ', this.tokenReceivedPrice);

    // ===============================================
    console.log(',"amounts_in": ', this.amountsIn);
    console.log(',"blindings_in": ', this.blindingsIn);
    console.log(
      ',"addresses_in": ',
      addresses_in.map((addr) => {
        addr = Secp256k1.JtoA(addr);
        return [split(addr[0]), split(addr[1])];
      })
    );

    //================================================

    let addresses_out = [];
    for (let i = 0; i < this.notesOut.length; i++) {
      const note = this.notesOut[i];
      addresses_out.push(note.address);
    }

    console.log(',"amounts_out": ', this.amountsOut);
    console.log(',"blindings_out": ', this.blindingsOut);
    console.log(
      ',"addresses_out": ',
      addresses_out.map((addr) => {
        addr = Secp256k1.JtoA(addr);
        return [split(addr[0]), split(addr[1])];
      })
    );
    // ======
    let Ko = generateOneTimeAddress(this.Kvi, this.Ksi, this.tx_r);
    Ko = Secp256k1.JtoA(Ko);
    console.log(',"return_address": ', [split(Ko[0]), split(Ko[1])]);
    console.log(',"ret_addr_sig": ', retAddrSig);
    console.log(',"signature": ', sig);
  }

  logVerifySignature(sig) {
    console.log(
      "K: ",
      this.notesIn.map((note) => note.address)
    );
    console.log(",m: ", this.hashTransaction());
    console.log(",c: ", sig[0]);
    console.log(",rs: ", sig.slice(1));
  }

  logHashTxInputs() {
    console.log(
      "notesIn: ",
      this.notesIn.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment,
      ])
    );
    console.log(
      ",notesOut: ",
      this.notesOut.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment,
      ])
    );
    console.log(",tokenSpent: ", this.tokenSpent);
    console.log(",tokenSpentPrice: ", this.tokenSpentPrice);
    console.log(",retSigR: ", this.return_sig_r);

    console.log("\n\nTx hash: ", this.hashTransaction());
  }
};
