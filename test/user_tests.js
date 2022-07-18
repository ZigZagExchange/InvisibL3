const chai = require("chai");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const User = require("../src/notes/Invisibl3User.js");
const { Note } = require("../src/notes/Notes");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");
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

let subPrivKeys = userB.subaddressPrivKeys(1);

describe("commitment test", function () {
  it("should check generating one time addresses", () => {
    let ko1 = userB.oneTimeAddressPrivKey(tx_r, 1);
    let Ko = userB.generateOneTimeAddress(tx_r, 1);

    assert(
      Ko.getX().toString(16) ==
        ec.g.mul(ko1.toString(16)).getX().toString(16) &&
        Ko.getY().toString(16) ==
          ec.g.mul(ko1.toString(16)).getY().toString(16),
      "One time address is not correct"
    );
  });

  it("should check hiding an revealing amounts and blindings", () => {
    // User A

    const amount = 100n;

    // hides values for the recipient yt and amount_t
    let hiddenValues = userA.hideValuesForRecipient(
      subaddressB.Kvi,
      amount,
      tx_r
    );

    let rG = ec.g.mul(tx_r.toString(16));

    let revealedValues = userB.revealHiddenValues(
      rG,
      hiddenValues.hiddentAmount,
      1
    );

    assert(revealedValues.amount === amount, "Amount missmatch");
    assert(revealedValues.yt, hiddenValues.yt, "blindings missmatch");
  });

  it("should check finding notes addressed to user", () => {
    // User A

    // Calculates the one time address from Subaddress and tx_r
    let Ko = userB.generateOneTimeAddress(tx_r, 1);

    const rKsi = subaddressB.Ksi.mul(tx_r.toString(16));

    // User B

    let res = userB.checkOwnership(rKsi, Ko, 1);

    assert(res, "check ownership not working");
  });

  // it("should check adding and removing notes", async () => {
  //   // console.log(userA.noteData);

  //   let token = 3n;

  //   let notes = [];
  //   for (let i = 0; i < 5; i++) {
  //     let note = new Note(5123123n, 1234n, token, i);
  //     notes.push(note);
  //   }

  //   userA.addNotes(
  //     notes,
  //     [1n, 2n, 3n, 4n, 5n],
  //     [5n, 6n, 7n, 8n, 9n],
  //     [1n, 2n, 3n, 4n, 5n]
  //   );

  //   // console.log(userA.noteData);
  //   assert(userA.noteData[token].length == 5, "notes not added");

  //   // userA.removeNotes([0, 2, 4]);
  //   // assert(userA.noteData[token].length == 2, "notes not removed");
  // });

  // it("should check constructing output notes", async () => {
  //   let prev_r = 111122223333444455556666777788889999n;
  //   const TOKEN = 1;

  //   let Ko = userB.generateOneTimeAddress(
  //     userA.pubViewKey.getPublic(),
  //     userA.pubSpendKey.getPublic(),
  //     prev_r
  //   );

  //   let notes = [];
  //   let amounts = [];
  //   let blindings = [];
  //   let kos = [];
  //   for (let i = 0; i < 10; i++) {
  //     let amount = randomBigInt(16) * 100n;
  //     let blinding = randomBigInt(240);

  //     let comm = pedersen([amount, blinding]);

  //     let addr = "0x".concat(Ko.encode("hex", true).slice(2));

  //     let note = new Note(addr, comm, TOKEN, i);

  //     notes.push(note);
  //     amounts.push(amount);
  //     blindings.push(blinding);
  //     kos.push(Ko);
  //   }

  //   userA.addNotes(notes, amounts, blindings, kos);

  //   const sum = amounts.reduce((partialSum, a) => partialSum + a, 0n);

  //   let swapAmount = (sum % 2n ** 251n) / 2n;

  //   let outData = userA.generateOutputNotes(
  //     swapAmount,
  //     TOKEN,
  //     subaddressB.Kvi,
  //     subaddressB.Ksi,
  //     tx_r
  //   );

  //   const rG = Secp256k1.mulG(Secp256k1.uint256(tx_r));
  //   let Ksi = Secp256k1.AtoJ(subaddressB.Ksi[0], subaddressB.Ksi[1]);
  //   const rKsi = Secp256k1.ecmul(Ksi, Secp256k1.uint256(tx_r));

  //   // User B

  //   let outNote1 = outData.notesOut[0];
  //   let hiddenOutAmount1 = outData.hiddenOutAmounts[0];
  //   let outBlinding1 = outData.blindingsOut[0];

  //   let ownership = userB.checkOwnership(rKsi, outNote1.address, 1);

  //   let revealedValues = userB.revealHiddenValues(rG, hiddenOutAmount1, 1, 1);

  //   assert(outBlinding1 === revealedValues.yt);
  //   assert(ownership);
  // }).timeout(10000);
});
