const chai = require("chai");
const User = require("../src/notes/User.js");
const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../circomlib/src/babyjub.js").subPoint;
const F = require("../circomlib/src/babyjub.js").F;
const G = require("../circomlib/src/babyjub.js").Generator;
const H = require("../circomlib/src/babyjub.js").Base8;

const noteUtils = require("../src/notes/noteUtils");
const Note = require("../src/notes/noteUtils").Note;
const randomBigInt = require("random-bigint");

const assert = chai.assert;

const tx_r = 123344545462324n;

let userDataA = User.generateRandomUserData();
let userA = new User(
  userDataA.id,
  userDataA.privViewKey,
  userDataA.privSpendKey
);

let userDataB = User.generateRandomUserData();
let userB = new User(
  userDataB.id,
  userDataB.privViewKey,
  userDataB.privSpendKey
);

let subaddressB = userB.generateSubaddress(1);

describe("commitment test", function () {
  it("should check hiding an revealing amounts and blindings", async () => {
    // User A

    const amount = 100n;
    // hides values for the recipient yt and amount_t
    let hiddenValues = userA.hideValuesForRecipient(
      subaddressB.Kvi,
      amount,
      tx_r,
      1
    );
    const rG = ecMul(G, tx_r);

    // User B

    let revealedValues = userB.revealHiddenValues(
      rG,
      hiddenValues.hiddentAmount,
      1,
      1
    );

    assert(revealedValues.amount === amount, "Amount missmatch");
    assert(revealedValues.yt, hiddenValues.yt, "blindings missmatch");
  });

  it("should check finding notes addressed to user", async () => {
    // User A

    // Calculates the one time address from it and tx_r
    let Ko = noteUtils.generateOneTimeAddress(
      subaddressB.Kvi,
      subaddressB.Ksi,
      tx_r
    );

    const rKsi = ecMul(subaddressB.Ksi, tx_r);

    // User B

    let res = userB.checkOwnership(rKsi, Ko, 1);

    assert(res, "check ownership not working");
  });

  it("should check adding and removing notes", async () => {
    // console.log(userA.noteData);

    let notes = [];
    for (let i = 0; i < 5; i++) {
      let note = new noteUtils.Note([1n, 2n], [3n, 4n], 5, i);
      notes.push(note);
    }

    userA.addNotes(notes, [1, 2, 3, 4, 5], [5, 6, 7, 8, 9]);

    // console.log(userA.noteData);
    assert(userA.noteData.length == 5);

    userA.removeNotes([0, 2, 4]);

    // console.log("\n", userA.noteData);
    assert(userA.noteData.length == 2);
  });

  it("should check constructing output notes", async () => {
    let prev_r = 111122223333444455556666777788889999n;
    const TOKEN = 1;

    let Ko = noteUtils.generateOneTimeAddress(
      ecMul(G, userDataA.privViewKey),
      ecMul(G, userDataA.privSpendKey),
      prev_r
    );

    let notes = [];
    let amounts = [];
    let blindings = [];
    for (let i = 0; i < 10; i++) {
      let amount = randomBigInt(16) * 100n;
      let blinding = randomBigInt(240);

      let comm = noteUtils.newCommitment(amount, blinding);

      let note = new Note(Ko, comm, TOKEN);

      notes.push(note);
      amounts.push(amount);
      blindings.push(blinding);
    }

    userA.addNotes(notes, amounts, blindings);

    const sum = amounts.reduce((partialSum, a) => partialSum + a, 0n);

    let swapAmount = sum / 2n;

    let outData = userA.generateOutputNotes(
      swapAmount,
      TOKEN,
      subaddressB.Kvi,
      subaddressB.Ksi,
      tx_r
    );

    const rG = ecMul(G, tx_r);
    const rKsi = ecMul(subaddressB.Ksi, tx_r);

    // User B

    let outNote1 = outData.notesOut[0];
    let hiddenOutAmount1 = outData.hiddenOutAmounts[0];
    let outBlinding1 = outData.blindingsOut[0];

    let ownership = userB.checkOwnership(rKsi, outNote1.address, 1);

    let revealedValues = userB.revealHiddenValues(rG, hiddenOutAmount1, 1, 1);

    assert(outBlinding1 === revealedValues.yt);
    assert(ownership);
  });
});
