const Secp256k1 = require("@enumatech/secp256k1-js");
const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");

const {
  trimHash,
  Note,
  generateOneTimeAddress,
  newCommitment,
  split,
  splitUint256,
} = require("./noteUtils.js");
const randomBigInt = require("random-bigint");
const poseidon = require("../../circomlib/src/poseidon.js");

const COMMITMENT_MASK = 112233445566778899n;
const AMOUNT_MASK = 998877665544332112n;

module.exports = class User {
  // Each user has a class where he stores all his information (should never be shared with anyone)
  // private keys should be 240 bits
  constructor(id, _privViewKey, _privSpendKey) {
    this.id = id;
    this.privViewKey = _privViewKey; //kv
    this.privSpendKey = _privSpendKey; //ks

    this.pubViewKey = Secp256k1.mulG(Secp256k1.uint256(_privViewKey));
    this.pubSpendKey = Secp256k1.mulG(Secp256k1.uint256(_privSpendKey));

    this.noteData = {};
  }

  generateOutputNotes(amount, token, Kv, Ks, r) {
    if (!this.noteData[token]) {
      console.log("No notes to spend");
      return [];
    }

    //* Sum the input notes till the desired swap amount is reached
    // calculate a more accurate fee
    let fee = 0.01;
    let feeAmount = amount / bigInt(Math.floor(1 / fee)).value;

    let notesIn = [];
    let amountsIn = [];
    let blindingsIn = [];
    let kosIn = [];
    let inputSum = 0n;
    while (inputSum < amount + feeAmount) {
      if (!this.noteData[token].length) {
        throw "Dont have enogh notes to handle this amount for this token";
      }

      let nData = this.noteData[token].pop();
      if (nData.note.token !== token) {
        throw "token missmatch in generate output notes";
      }

      let newNote = new Note(
        nData.note.address,
        pedersen([nData.amount, nData.blinding]),
        token,
        nData.note.index
      );
      inputSum += nData.amount;
      notesIn.push(newNote);
      amountsIn.push(nData.amount);
      blindingsIn.push(nData.blinding);
      kosIn.push(nData.ko);
    }

    //* make output notes =================================================
    let notesOut = [];
    let amountsOut = [];
    let blindingsOut = [];

    //? Add the market maker note (later possibly multiple and for different market makers)
    let hiddenValues1 = this.hideValuesForRecipient(Kv, amount, r);
    let Ko1 = generateOneTimeAddress(Kv, Ks, r);

    // let comm1 = newCommitment(amount, hiddenValues1.yt);
    let comm1 = pedersen([amount, hiddenValues1.yt]);
    let note1 = new Note(Ko1, comm1, token);

    notesOut.push(note1);
    amountsOut.push(amount);
    blindingsOut.push(hiddenValues1.yt);

    //? Add the exchange fee note ===========================
    let dummyKey = [1n, 0n];
    let hiddenValues2 = this.hideValuesForRecipient(dummyKey, feeAmount, r);
    let Ko2 = generateOneTimeAddress(dummyKey, Ks, r);

    // let comm2 = newCommitment(feeAmount, hiddenValues2.yt);
    let comm2 = pedersen([feeAmount, hiddenValues2.yt]);
    let note2 = new Note(Ko2, comm2, token);

    notesOut.push(note2);
    amountsOut.push(feeAmount);
    blindingsOut.push(hiddenValues2.yt);

    //? Add the refund note
    // User send himself a refund note with the leftover funds
    let hiddenValues3 = this.hideValuesForRecipient(
      this.pubViewKey,
      inputSum - amount - feeAmount,
      r
    );
    let Ko3 = generateOneTimeAddress(this.pubViewKey, this.pubSpendKey, r);

    // let comm3 = newCommitment(inputSum - amount - feeAmount, hiddenValues3.yt);
    let comm3 = pedersen([inputSum - amount - feeAmount, hiddenValues3.yt]);
    let note3 = new Note(Ko3, comm3, token);

    notesOut.push(note3);
    amountsOut.push(inputSum - amount - feeAmount);
    blindingsOut.push(hiddenValues3.yt);

    let hiddenOutAmounts = [
      hiddenValues1.hiddentAmount,
      hiddenValues2.hiddentAmount,
      hiddenValues3.hiddentAmount,
    ];

    return {
      notesIn,
      amountsIn,
      blindingsIn,
      kosIn,
      notesOut,
      amountsOut,
      blindingsOut,
      hiddenOutAmounts,
    };
  }

  //* ===========================================================================

  addNotes(notes, amounts, blindings, kos) {
    if (!notes.length) {
      return;
    }

    for (let i = 0; i < notes.length; i++) {
      const note = notes[i];
      const amount = amounts[i];
      const blinding = blindings[i];
      const ko = kos[i];
      if (!this.noteData[note.token]) {
        this.noteData[note.token] = [];
      }
      this.noteData[note.token].push({ note, amount, blinding, ko });
    }
  }

  // todo figure out how remove notes should work
  removeNotes(notes) {}

  //* HELPERS =======================================================

  generateSubaddress(i) {
    // Ksi = Ks + H(kv, i)*G   == (ks + H(kv, i))* G
    // Kvi = kv*Ksi         == kv*(ks + H(kv, i))* G

    let ksi = this.privSpendKey + pedersen([this.privViewKey, i]);
    let Ksi = Secp256k1.mulG(Secp256k1.uint256(ksi));
    Ksi = Secp256k1.AtoJ(Ksi[0], Ksi[1]);
    const Kvi = Secp256k1.ecmul(Ksi, Secp256k1.uint256(this.privViewKey));
    return { Kvi: Secp256k1.JtoA(Kvi), Ksi: Secp256k1.JtoA(Ksi) };
  }

  subaddressPrivKeys(i) {
    // ksi = ks + H(kv, i)
    // kvi = kv*ksi

    const ksi = this.privSpendKey + pedersen([this.privViewKey, i]);
    const kvi = this.privViewKey * ksi;

    return { ksi, kvi };
  }

  generateOneTimeAddress(pub_view_key, pub_spend_key, r) {
    // Ko =  H(r * Kv)G + Ks

    let rKv = ecMul(pub_view_key, r);
    rKv.push(0);
    let h = pedersen(rKv);

    return ecAdd(ecMul(G, h), pub_spend_key);
  }

  oneTimeAddressPrivKey(pub_view_key, priv_spend_key, r) {
    // ko = H(r * Kv) + ks
    let rKv = ecMul(pub_view_key, r);
    rKv.push(0);
    let h = pedersen(rKv);
    return h + priv_spend_key;
  }

  // Amounts are multiplied by the amplification rate (1 ETH = 10**9)
  // Prices are multiplied by the number of decimals (10 ** (decimals))
  calculateAmounts(inputAmount, tokenInPrice, tokenOutPrice, accuracy = 9) {
    // the calculation is accurate to 2*accuracy -1 digits

    // let priceRatio =
    //   (tokenInPrice * 10n ** (2n * bigInt(accuracy).value)) / tokenOutPrice;
    let priceRatio =
      (tokenOutPrice * 10n ** (2n * bigInt(accuracy).value)) / tokenInPrice;

    // let outputAmount =
    //   (inputAmount * priceRatio) / 10n ** (2n * bigInt(accuracy).value) + 1n;
    let outputAmount =
      (inputAmount * 10n ** (2n * bigInt(accuracy).value)) / priceRatio;

    const diff = outputAmount * tokenOutPrice - inputAmount * tokenInPrice;

    return { outputAmount, diff };
  }

  pedersenToPoseidon() {
    let converted = {};
    for (const [key, value] of Object.entries(this.noteData)) {
      let notes = value.map((noteData) => {
        return {
          note: new Note(
            noteData.note.address,
            pedersen([noteData.amount, noteData.blinding]),
            noteData.note.token,
            noteData.note.index
          ),
          amount: noteData.amount,
          blinding: noteData.blinding,
          ko: noteData.ko,
        };
      });

      converted[key] = notes;
    }

    this.noteData = converted;
  }

  //* RETRIEVAL FUNCTIONS =======================================================

  // Each output of a transaction should have this hiding
  hideValuesForRecipient(recipient_Kv, amount, r) {
    // TODO: Add something so that the blindind is always different
    // r is the transaction priv key (randomly generated)
    // yt = H("comm_mask", H(rKv, t))  (NOTE: t is used to make the values unique and we are omitting it for now)
    // amount_t = bt XOR8 H("amount_mask", H(rKv, t))  -> (where bt is the 64 bit amount of the note)

    recipient_Kv = Secp256k1.AtoJ(recipient_Kv[0], recipient_Kv[1]);
    let rKv = Secp256k1.ecmul(recipient_Kv, Secp256k1.uint256(r));
    rKv = Secp256k1.JtoA(rKv);

    let hash8 = trimHash(poseidon([AMOUNT_MASK, poseidon(rKv)]), 64);

    let yt = poseidon([COMMITMENT_MASK, poseidon(rKv)]); // this is the blinding used in the commitment
    yt = trimHash(yt, 250);
    let hiddentAmount = bigInt(amount).xor(hash8).value;

    return { yt, hiddentAmount };
  }

  // Used to reveal the blindings and amounts of the notes addressed to this user's ith subaddress
  revealHiddenValues(rG, hiddenAmount, ith = 1) {
    // yt = H("comm_mask", H(rG*kv, t))
    // amount_t = bt XOR8 H("amount_mask", H(rG*kv, t))

    const privKeys = this.subaddressPrivKeys(ith);

    rG = Secp256k1.AtoJ(rG[0], rG[1]);

    let rKv = Secp256k1.ecmul(rG, Secp256k1.uint256(privKeys.kvi));
    rKv = Secp256k1.JtoA(rKv);

    let yt = poseidon([COMMITMENT_MASK, poseidon(rKv)]); // this is the blinding used in the commitment
    yt = trimHash(yt, 250);

    let hash8 = trimHash(poseidon([AMOUNT_MASK, poseidon(rKv)]), 64);

    let amount = bigInt(hiddenAmount).xor(hash8).value;

    return { yt, amount };
  }

  // Checks if the transaction is addressed to this user's its subaddress
  checkOwnership(rKsi, Ko, ith = 1) {
    // Ko is defined as H(rKvi)G + Ksi
    // kv*rKsi = rKvi
    // Ks' = Ko - H(rKvi,0)G
    // If Ks' === Ksi (calculated Ks' equals his subbadress Ksi) than its addressed to him

    if (Ko.length == 2) {
      Ko = Secp256k1.AtoJ(Ko[0], Ko[1]);
    }
    if (rKsi.length == 2) {
      rKsi = Secp256k1.AtoJ(rKsi[0], rKsi[1]);
    }

    const subaddress = this.generateSubaddress(ith);

    let rKvi = Secp256k1.ecmul(rKsi, Secp256k1.uint256(this.privViewKey));
    rKvi = Secp256k1.JtoA(rKvi);

    let h = trimHash(poseidon(rKvi), 250);
    let rGKvi = Secp256k1.mulG(Secp256k1.uint256(h));
    let rGKvi_neg = Secp256k1.negPoint(rGKvi);
    rGKvi_neg = Secp256k1.AtoJ(rGKvi_neg[0], rGKvi_neg[1]);

    let Ks_prime = Secp256k1.ecadd(Ko, rGKvi_neg);
    Ks_prime = Secp256k1.JtoA(Ks_prime);

    // console.log(bigInt(Ks_prime[0].toString()).value);
    // console.log(bigInt(subaddress.Ksi[0].toString()));
    return !!(
      bigInt(Ks_prime[0].toString()).value ===
        bigInt(subaddress.Ksi[0].toString()).value &&
      bigInt(Ks_prime[1].toString()).value ===
        bigInt(subaddress.Ksi[1].toString()).value
    );
  }

  //* TESTS =======================================================

  static generateRandomUserData() {
    const id = randomBigInt(200);
    const privViewKey = randomBigInt(250);
    const privSpendKey = randomBigInt(250);
    return { id, privViewKey, privSpendKey };
  }
};
