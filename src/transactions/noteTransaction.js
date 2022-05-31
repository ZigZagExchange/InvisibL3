const poseidon = require("../../circomlib/src/poseidon.js");
const ecMul = require("../../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../../circomlib/src/babyjub.js").subPoint;
const G = require("../../circomlib/src/babyjub.js").Generator;
const H = require("../../circomlib/src/babyjub.js").Base8;

const randomBigInt = require("random-bigint");

const Note = require("../notes/noteUtils.js").Note;
const noteUtils = require("../notes/noteUtils.js");

//TODO Temporary randomness for one time address
const RAND_SEED = 123456789;

module.exports = class NoteTransaction {
  constructor(
    notesIn,
    pseudo_comms,
    pos,
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
    this.pseudo_comms = pseudo_comms;
    this.pos = pos;
    this.return_sig_r = null; //used to make sure the user recived the trade to the right address
    this.tokenSpent = tokenSpent;
    this.tokenSpentPrice = tokenSpentPrice;

    //PRIVATE INPUTS:  (still shared with exchange or market maker)

    this.tokenReceived = tokenReceived;
    this.tokenReceivedPrice = tokenReceivedPrice;
    this.amountsIn = amountsIn;
    this.amountsOut = amountsOut;
    this.blindingsIn = blindingsIn;
    this.blindingsOut = blindingsOut;
    this.return_sig_c = null; //used to make sure the user recived the trade to the right address
    this.Ksi = Ksi; // the ith subbaddress spend key
    this.Kvi = Kvi; // the ith subbaddress view key
    this.tx_r = tx_r;
  }

  // PRIVATE FUNCTIONS: ========================================================

  signPrivateReturnAddress(privSpendKey) {
    // using this as a Fiat-Shamir heuristic
    let hash = this.hashPrivateInputs();

    const ko = noteUtils.oneTimeAddressPrivKey(
      this.Kvi,
      privSpendKey,
      this.tx_r
    );

    let alpha = randomBigInt(240);
    let aG = ecMul(G, alpha);

    let c = poseidon([hash, aG[0], aG[1]]);

    let c_trimed = noteUtils.trimHash(c, 240);

    const r = alpha + ko - c_trimed;

    this.return_sig_r = r;

    return [c, r];
  }

  // signTransaction(note_priv_keys, cmtz_priv_keys) {
  //   // Currently only supports max 6 notes per transaction (14 inputs, one is the msg_hash)
  //   if (note_priv_keys.length > 6) {
  //     throw "currently max 6 notes per transaction allowed";
  //   }
  //   if (note_priv_keys.length !== cmtz_priv_keys.length) {
  //     throw "key lengths missmatch";
  //   }

  //   let tx_hash = this.hashTransaction();
  //   let alphas = [];
  //   let c_input = [tx_hash];

  //   //?  c = H(tx_hash, aG)
  //   for (let i = 0; i < note_priv_keys.length; i++) {
  //     let alpha = randomBigInt(240);
  //     alphas.push(alpha);

  //     let aG = ecMul(G, alpha);
  //     c_input.push(aG[0]);
  //     c_input.push(aG[1]);
  //   }

  //   let c = poseidon(c_input);

  //   //? ri = a + k + c*z,  where c is trimmed to 16 bytes
  //   let sig = [c];
  //   let c_trimed = noteUtils.trimHash(c);
  //   for (let i = 0; i < note_priv_keys.length; i++) {
  //     let r = alphas[i] + note_priv_keys[i] + c_trimed * cmtz_priv_keys[i];
  //     sig.push(r);
  //   }

  //   return sig;
  // }

  signTransaction_new(note_priv_keys, cmtz_priv_keys) {
    // Currently only supports max 6 notes per transaction (14 inputs, one is the msg_hash)
    if (note_priv_keys.length > 6) {
      throw "currently max 6 notes per transaction allowed";
    }
    if (note_priv_keys.length !== cmtz_priv_keys.length) {
      throw "key lengths missmatch";
    }

    let tx_hash = this.hashTransaction();
    let alphas = [];
    let c_input = [tx_hash];

    //?  c = H(tx_hash, aG)
    for (let i = 0; i < 5; i++) {
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

    //? ri = a + k + c*z,  where c is trimmed to 16 bytes
    let sig = [c];
    let c_trimed = noteUtils.trimHash(c);
    for (let i = 0; i < 5; i++) {
      if (i >= note_priv_keys.length) {
        sig.push(0n);
      } else {
        let r = alphas[i] + note_priv_keys[i] + c_trimed * cmtz_priv_keys[i];
        sig.push(r);
      }
    }

    return sig;
  }

  // PUBLIC FUNCTIONS: ========================================================

  verifyPrivReturnAddressSig(
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
      Ko = noteUtils.generateOneTimeAddress(this.Kvi, this.Ksi, this.tx_r);
      console.log("Unsafe: Should provide your own Ko");
    }

    let c_trimed = noteUtils.trimHash(c, 240);

    // c = H(rG - K + cG)
    const c_input = ecSub(ecAdd(ecMul(G, r), ecMul(G, c_trimed)), Ko);

    const c_prime = poseidon([hash, c_input[0], c_input[1]]);

    if (c_prime !== c) {
      throw "return address signature verification failed";
    } else {
      console.log("return address signature verified");
    }
  }

  // verifySignature(signature) {
  //   const cmtz_pub_keys = noteUtils.cmtzPubKeys(
  //     this.notesIn,
  //     this.pseudo_comms,
  //     this.pos
  //   );

  //   // Currently only supports max 6 notes per transaction
  //   if (this.notesIn.length > 5) {
  //     throw "currently max 6 notes per transaction allowed";
  //   }
  //   if (this.notesIn.length !== signature.length - 1) {
  //     throw "key and signature lengths missmatch";
  //   }

  //   let c = signature[0];
  //   let rs = signature.slice(1);

  //   let tx_hash = this.hashTransaction();
  //   let c_input = [tx_hash];

  //   //?  c = H(m, rG - K - c*Z)

  //   for (let i = 0; i < this.notesIn.length; i++) {
  //     let rG = ecMul(G, rs[i]);
  //     let cZ = ecMul(cmtz_pub_keys[i], noteUtils.trimHash(c));
  //     let rG_minus_K = ecSub(rG, this.notesIn[i].address);
  //     let c_input_i = ecSub(rG_minus_K, cZ);

  //     c_input.push(c_input_i[0]);
  //     c_input.push(c_input_i[1]);
  //   }

  //   let c_prime = poseidon(c_input);
  //   if (c_prime !== c) {
  //     throw "signature verification failed";
  //   } else {
  //     console.log("signature verified");
  //   }
  // }

  verifySignature_new(signature) {
    const cmtz_pub_keys = noteUtils.cmtzPubKeys(
      this.notesIn,
      this.pseudo_comms,
      this.pos
    );

    // Currently only supports max 6 notes per transaction
    if (this.notesIn.length > 5) {
      throw "currently max 6 notes per transaction allowed";
    }
    // if (this.notesIn.length !== signature.length - 1) {
    //   throw "key and signature lengths missmatch";
    // }

    let c = signature[0];
    let rs = signature.slice(1);

    let tx_hash = this.hashTransaction();
    let c_input = [tx_hash];

    //?  c = H(m, rG - K - c*Z)

    for (let i = 0; i < 5; i++) {
      if (i >= this.notesIn.length) {
        c_input.push(0n);
        c_input.push(1n);
      } else {
        let rG = ecMul(G, rs[i]);
        let cZ = ecMul(cmtz_pub_keys[i], noteUtils.trimHash(c));
        let rG_minus_K = ecSub(rG, this.notesIn[i].address);
        let c_input_i = ecSub(rG_minus_K, cZ);

        c_input.push(c_input_i[0]);
        c_input.push(c_input_i[1]);
      }
    }

    let c_prime = poseidon(c_input);
    if (c_prime !== c) {
      throw "signature verification failed";
    } else {
      console.log("signature verified");
      // this.logVerifySignature(signature);
    }
  }

  verifySums() {
    let inputSum = 0n;
    let outputSum = 0n;

    for (let i = 0; i < this.notesIn.length; i++) {
      const note = this.notesIn[i];

      let C = ecAdd(ecMul(G, this.blindingsIn[i]), ecMul(H, this.amountsIn[i]));

      if (note.commitment[0] !== C[0] || note.commitment[1] !== C[1]) {
        throw "amount or blinding missmatch in input notes";
      }

      inputSum += this.amountsIn[i];
    }

    for (let i = 0; i < this.notesOut.length; i++) {
      const note = this.notesOut[i];

      let C = ecAdd(
        ecMul(G, this.blindingsOut[i]),
        ecMul(H, this.amountsOut[i])
      );

      if (note.commitment[0] !== C[0] || note.commitment[1] !== C[1]) {
        throw "amount or blinding missmatch in output notes";
      }

      outputSum += this.amountsOut[i];
    }

    if (inputSum != outputSum) {
      throw "outputs sum is not equal to the inputs sum";
    }
  }

  // might deprecate this function
  verifySumsCmtz() {
    let sum_in = this.pseudo_comms[0];
    let sum_out = this.notesOut[0].commitment;

    for (let i = 1; i < this.pseudo_comms.length; i++) {
      sum_in = ecAdd(sum_in, this.pseudo_comms[i]);
    }

    for (let i = 1; i < this.notesOut.length; i++) {
      sum_out = ecAdd(sum_out, this.notesOut[i].commitment);
    }

    if (sum_in[0] !== sum_out[0] || sum_in[1] !== sum_out[1]) {
      throw "sums do not match";
    }
  }

  //  HELPERS ==================================================================

  hashTransaction() {
    const ZERO_HASH =
      18186447106104122485063459425619848727822300266366701424845346221645122918962n;

    let in_notes_hash;
    if (this.notesIn.length > 5 || this.notesOut.length > 5) {
      throw "currently max 5 notes per transaction allowed";
    }

    let hashes_in = [];
    for (let i = 0; i < 5; i++) {
      if (i >= this.notesIn.length) {
        hashes_in.push(ZERO_HASH);
      } else {
        const hash = this.notesIn[i].hash;
        if (this.notesIn[i].token !== this.tokenSpent) {
          throw "token missmatch";
        }
        hashes_in.push(hash);
      }
    }
    in_notes_hash = poseidon(hashes_in);

    // ===================================================
    let out_notes_hash;
    let hashes_out = [];
    for (let i = 0; i < 5; i++) {
      if (i >= this.notesOut.length) {
        hashes_out.push(ZERO_HASH);
      } else {
        const hash = this.notesOut[i].hash;
        if (this.notesOut[i].token !== this.tokenSpent) {
          throw "token missmatch";
        }
        hashes_out.push(hash);
      }
    }
    out_notes_hash = poseidon(hashes_out);
    // ===================================================

    return poseidon([
      in_notes_hash,
      out_notes_hash,
      this.tokenSpent,
      this.tokenSpentPrice,
      this.return_sig_r,
    ]);
  }

  // TODO:  should figure out the inputs to this that make sense
  hashPrivateInputs() {
    return poseidon([this.tokenReceived, this.tokenReceivedPrice]);
  }

  // LOGGING ==================================================================
  logTransaction(retAddrSig, sig) {
    console.log(
      "notesIn: ",
      this.notesIn.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(",pseudoComms: ", this.pseudo_comms);
    console.log(",pos: ", this.pos);
    console.log(
      ",notesOut: ",
      this.notesOut.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(",amountsIn: ", this.amountsIn);
    console.log(",amountsOut: ", this.amountsOut);
    console.log(",blindingsIn: ", this.blindingsIn);
    console.log(",blindingsOut: ", this.blindingsOut);
    console.log(",tokenSpent: ", this.tokenSpent);
    console.log(",tokenSpentPrice: ", this.tokenSpentPrice);
    console.log(",tokenReceived: ", this.tokenReceived);
    console.log(",tokenReceivedPrice: ", this.tokenReceivedPrice);
    let Ko = noteUtils.generateOneTimeAddress(this.Kvi, this.Ksi, this.tx_r);
    console.log(",Ko: ", Ko);
    console.log(",returnAddressSig: ", retAddrSig);
    console.log(",signature: ", sig);
  }

  logVerifySignature(sig) {
    console.log(
      "K: ",
      this.notesIn.map((note) => [note.address])
    );
    console.log(
      ",C_prev: ",
      this.notesIn.map((note) => [note.commitment])
    );
    console.log(",C_new: ", this.pseudo_comms);
    console.log(",pos: ", this.pos);
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
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(
      ",notesOut: ",
      this.notesOut.map((note) => [
        note.index,
        note.address[0],
        note.address[1],
        note.token,
        note.commitment[0],
        note.commitment[1],
      ])
    );
    console.log(",tokenSpent: ", this.tokenSpent);
    console.log(",tokenSpentPrice: ", this.tokenSpentPrice);
    console.log(",retSigR: ", this.return_sig_r);

    console.log("\n\nTx hash: ", this.hashTransaction());
  }
};
