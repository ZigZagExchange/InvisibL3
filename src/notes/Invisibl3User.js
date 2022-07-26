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
  _generateSubaddress,
  _subaddressPrivKeys,
  _generateOneTimeAddress,
  _oneTimeAddressPrivKey,
  _hideValuesForRecipient,
  _revealHiddenValues,
  _checkOwnership,
} = require("./Invisibl3UserUtils");
const InvisibleOrder = require("../transactions/InvisibleOrder");
const InvisibleWithdrawal = require("../transactions/InvisibleWithdrawal");

const {
  trimHash,
  Note,
  newCommitment,
  split,
  splitUint256,
} = require("./Notes.js");
const InvisibleDeposit = require("../transactions/InvisibleDeposit");

const COMMITMENT_MASK = 112233445566778899n;
const AMOUNT_MASK = 998877665544332112n;

module.exports = class User {
  // Each user has a class where he stores all his information (should never be shared with anyone)
  // private keys should be 240 bits
  constructor(id, _privViewKey, _privSpendKey) {
    this.id = id;
    this.privViewKey = _privViewKey; //kv
    this.privSpendKey = _privSpendKey; //ks

    this.pubViewKey = getKeyPair(_privViewKey);
    this.pubSpendKey = getKeyPair(_privSpendKey);

    // TODO: Look at the comments
    this.noteData = {}; // token -> [{note, ko}] ==> change to [{note}] and use address2ko for kos
    this.address2ko = {}; // mapping of addresses to private keys

    this.activeOrders = []; // All limit orders that are active
    this.partialFills = []; // All limit orders that have been partially filled

    this.activeDeposits = {}; // All deposits that are active  id: {deposit,notes}
    this.activeWithdrawals = []; // All withdrawals that are active {withdrawal, notes}

    this.orderHistory = []; // All orders this user has made
  }

  //* GENERATE ORDERS  ==========================================================

  makeLimitOrder(
    nonce,
    expiration_timestamp,
    token_spent,
    token_received,
    amount_spent,
    amount_received,
    fee_limit,
    // Todo: below three should be calculated by some formula
    dest_spent_address,
    dest_received_address,
    blinding_seed
  ) {
    let sum = 0n;
    let notesIn = [];
    let signingKeys = [];
    while (sum < amount_spent) {
      let note = this.noteData[token_spent].pop(0);
      let ko = this.address2ko[note.address_pk()];
      notesIn.push(note);
      signingKeys.push(getKeyPair(ko));
      sum += note.amount;
    }

    let refundNote;
    let refundAmount = sum - amount_spent;
    if (refundAmount < 0n) {
      throw new Error("Not enough notes to make such a withdrawal");
    }
    // if
    // if (refundAmount > 0n) {
    // // TODO: What to do if refund amount is zero???
    let blinding = randomBigInt(250);
    let ko = randomBigInt(250);
    let addr = ec.g.mul(ko.toString(16));
    refundNote = new Note(
      addr,
      token_spent,
      refundAmount,
      blinding,
      notesIn[0].index
    );

    this.noteData[token_spent].push(refundNote);
    this.address2ko[refundNote.address_pk()] = ko;
    // }

    const order = new InvisibleOrder(
      nonce,
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
      refundNote
    );

    let signatures = order.sign_order(signingKeys);

    return order;
  }

  makeWithdrawalOrder(withdrawAmount, withdrawToken, withdrawStarkKey) {
    let sum = 0n;
    let notesIn = [];
    let privKeys = [];
    while (sum < withdrawAmount) {
      let note = this.noteData[withdrawToken].pop(0);
      if (!note) {
        throw new Error("Not enough notes to make such a withdrawal");
      }
      let ko = this.address2ko[note.address_pk()];
      notesIn.push(note);
      privKeys.push(ko);
      sum += note.amount;
    }

    let refundNote;
    let refundAmount = sum - withdrawAmount;
    if (refundAmount < 0n) {
      throw new Error("Not enough notes to make such a withdrawal");
    }
    // if (refundAmount > 0n) {
    //  // Todo || What to do if refund amount is zero???
    //  // Todo || (return empty refund note => make notes with 0 amount hash to zero leaves)
    //  // Todo this should again be calculated by some formula
    let blinding = randomBigInt(250);
    let ko = randomBigInt(250);
    let addr = ec.g.mul(ko.toString(16));
    refundNote = new Note(
      addr,
      withdrawToken,
      refundAmount,
      blinding,
      notesIn[0].index
    );

    this.noteData[withdrawToken].push(refundNote);
    this.address2ko[refundNote.address_pk()] = ko;
    // }

    let withdrawId = notesIn.reduce((acc, note) => {
      return acc + note.amount / 10n;
    }, 0n);
    // withdrawId = pedersen([withdrawId, 0]);  // todo

    const withdrawal = new InvisibleWithdrawal(
      withdrawId,
      withdrawToken,
      withdrawAmount,
      withdrawStarkKey,
      notesIn,
      refundNote
    );

    withdrawal.signwithdrawTransaction(privKeys);

    return withdrawal;
  }

  makeDepositOrder(depositId, depositAmount, depositToken, depositStarkKey) {
    let depositAmounts = this._getRandomAmounts(depositAmount, 3);
    // todo: generate below values by some formula (add kos to this.address2ko)
    let kos = [152787124n, 812341234n, 27347238483n];
    let addresses = kos.map((ko) => getKeyPair(ko).getPublic());
    let blindings = [67523128912n, 2385764329844n, 7823646239432n];
    //TODO: Below address should be retrieved from the blockchain
    let privKey = 2165481273712648921734n;
    depositStarkKey = getKeyPair(privKey).getPublic();

    let depositNotes = this._generateNewNotes(
      depositAmounts,
      blindings,
      addresses,
      depositToken
    );

    let deposit = new InvisibleDeposit(
      depositId,
      depositToken,
      depositAmount,
      depositStarkKey,
      depositNotes
    );

    deposit.signDeposit(privKey);

    for (let i = 0; i < depositNotes.length; i++) {
      this.addNote(depositNotes[i], kos[i]);
    }

    return deposit;
  }

  //* ON COMPLETED ORDERS ==========================================================
  // TODO =================
  onLimitOrderFilled(order, swapNote, newPartialFillRefundNote) {
    if (newPartialFillRefundNote) {
      this.noteData[newPartialFillRefundNote.token].push(
        newPartialFillRefundNote
      );
      // priv key should have already been added to this.address2ko when order was made
    }

    this.noteData[swapNote.token].push(swapNote);
    // priv key should have already been added to this.address2ko when order was made

    if (order.amountFilled == order.amount_received) {
      this.activeOrders.filter((o) => o.orderId === order.orderId);
    }
  }

  onDepositAccepted(deposit) {
    for (let i = 0; i < deposit.notes.length; i++) {
      this.noteData[deposit.depositToken].push(deposit.notes[i]);
      // priv key should have already been added to this.address2ko when order was made
    }

    this.activeDeposits.filter((d) => d.deposit_id == deposit.deposit_id);
  }

  onWithdrawalAccepted(withdrawal) {
    this.noteData[withdrawal.withdraw_token].push(withdrawal.refundNote);
  }

  // * GENERATING NEW NOTES =====================================================
  _generateNewNotes(amounts, blindings, address_pks, depositToken) {
    let notes = [];
    for (let i = 0; i < amounts.length; i++) {
      let note = new Note(
        address_pks[i],
        depositToken,
        amounts[i],
        blindings[i],
        0 // the real index is set in executeDeposit()
      );
      notes.push(note);
    }

    return notes;
  }

  // TODO: This function should make as many generic amounts (1000, 5000, 20000, etc) as possible to better hide
  _getRandomAmounts(amount, numNotes) {
    let amounts = [];

    let currentSum = 0n;
    for (let i = 0; i < numNotes - 1; i++) {
      let randAmount = bigInt(amount).divide(numNotes).subtract(123n).value;
      amounts.push(randAmount);
      currentSum += randAmount;
    }

    amounts.push(amount - currentSum);

    return amounts;
  }

  // * DEPRECATED ==========================================================
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
    let Ko1 = this.generateOneTimeAddress(Kv, Ks, r);

    // let comm1 = newCommitment(amount, hiddenValues1.yt);
    let comm1 = pedersen([amount, hiddenValues1.yt]);
    let addr = "0x".concat(Ko1.encode("hex", true).slice(2));
    let note1 = new Note(addr, comm1, token);

    notesOut.push(note1);
    amountsOut.push(amount);
    blindingsOut.push(hiddenValues1.yt);

    //? Add the exchange fee note ===========================
    let dummyKey = ec.g.mul(amount); // TODO update this
    let hiddenValues2 = this.hideValuesForRecipient(dummyKey, feeAmount, r);
    let Ko2 = this.generateOneTimeAddress(dummyKey, Ks, r);

    // let comm2 = newCommitment(feeAmount, hiddenValues2.yt);
    let comm2 = pedersen([feeAmount, hiddenValues2.yt]);
    let addr2 = "0x".concat(Ko2.encode("hex", true).slice(2));
    let note2 = new Note(addr2, comm2, token);

    notesOut.push(note2);
    amountsOut.push(feeAmount);
    blindingsOut.push(hiddenValues2.yt);

    //? Add the refund note
    // User send himself a refund note with the leftover funds
    let hiddenValues3 = this.hideValuesForRecipient(
      this.pubViewKey.getPublic(),
      inputSum - amount - feeAmount,
      r
    );
    let Ko3 = this.generateOneTimeAddress(this.pubViewKey, this.pubSpendKey, r);

    // let comm3 = newCommitment(inputSum - amount - feeAmount, hiddenValues3.yt);
    let comm3 = pedersen([inputSum - amount - feeAmount, hiddenValues3.yt]);
    let addr3 = "0x".concat(addr3.encode("hex", true).slice(2));
    let note3 = new Note(addr3, comm3, token);

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

  addNote(note, privKey) {
    if (!note || !privKey) {
      return;
    }

    if (!this.noteData[note.token]) {
      this.noteData[note.token] = [];
    }
    this.noteData[note.token].push(note);
    this.address2ko[note.address_pk()] = privKey;
  }

  //* HELPERS ===========================================================================

  generateSubaddress(i) {
    return _generateSubaddress(this.privSpendKey, this.privViewKey, i);
  }

  subaddressPrivKeys(i) {
    return _subaddressPrivKeys(this.privSpendKey, this.privViewKey, i);
  }

  generateOneTimeAddress(r, ith = 1) {
    let { Kvi, Ksi } = this.generateSubaddress(ith);

    return _generateOneTimeAddress(Kvi, Ksi, r);
  }

  oneTimeAddressPrivKey(r, ith = 1) {
    let { Kvi, Ksi } = this.generateSubaddress(ith);
    let { ksi, kvi } = this.subaddressPrivKeys(ith);

    return _oneTimeAddressPrivKey(Kvi, ksi, r);
  }

  // Hides the values for the recipient
  hideValuesForRecipient(recipient_Kv, amount, r) {
    return _hideValuesForRecipient(recipient_Kv, amount, r);
  }

  // Used to reveal the blindings and amounts of the notes addressed to this user's ith subaddress
  revealHiddenValues(rG, hiddenAmount, ith = 1) {
    return _revealHiddenValues(
      rG,
      hiddenAmount,
      this.privSpendKey,
      this.privViewKey,
      ith
    );
  }

  // Checks if the transaction is addressed to this user's its subaddress
  checkOwnership(rKsi, Ko, ith = 1) {
    return _checkOwnership(rKsi, Ko, this.privSpendKey, this.privViewKey, ith);
  }

  //* TESTS =======================================================

  static generateRandomUserData() {
    const id = randomBigInt(200);
    const privViewKey = randomBigInt(250);
    const privSpendKey = randomBigInt(250);
    return { id, privViewKey, privSpendKey };
  }
};
