const randomBigInt = require("random-bigint");
const utils = require("../notes/noteUtils");
const Note = require("../notes/noteUtils").Note;
var bigInt = require("big-integer");

function generateRandomData(num_inputs) {
  let amounts = [];
  let blindings = [];
  let tokenTypes = [];
  for (let i = 0; i < num_inputs; i++) {
    let amount = randomBigInt(64);
    let blinding = randomBigInt(120);
    let tokenType = 1; //Math.floor(Math.random() * 10);

    amounts.push(amount);
    blindings.push(blinding);
    tokenTypes.push(tokenType);
  }

  return { amounts, blindings, tokenTypes };
}

function generateRandomKeys(num_inputs) {
  let privSpendKeys = [];
  let pubSpendKeys = [];
  let privViewKeys = [];
  let pubViewKeys = [];

  for (let i = 0; i < num_inputs; i++) {
    // 240 bit keys so that r fits inside bitify circuit
    let privSpendKey = randomBigInt(240);
    let pubSpendKey = utils.newCommitment(0, privSpendKey);

    let privViewKey = randomBigInt(240);
    let pubViewKey = utils.newCommitment(0, privViewKey);

    privSpendKeys.push(privSpendKey);
    pubSpendKeys.push(pubSpendKey);
    privViewKeys.push(privViewKey);
    pubViewKeys.push(pubViewKey);
  }

  return { privSpendKeys, pubSpendKeys, privViewKeys, pubViewKeys };
}

function getDummyNotes(nNotes = 5, sum = 0) {
  let input_data = module.exports.generateRandomData(nNotes);
  const amounts = sum ? getNewAmountsFromSum(sum, nNotes) : input_data.amounts;
  const blindings = input_data.blindings;
  const tokenTypes = input_data.tokenTypes;

  let inputKeys = module.exports.generateRandomKeys(nNotes);
  const privSpendKeys = inputKeys.privSpendKeys;
  const pubSpendKeys = inputKeys.pubSpendKeys;
  const privViewKeys = inputKeys.privViewKeys;
  const pubViewKeys = inputKeys.pubViewKeys;

  let Kos = [];
  let kos = [];
  let notes = [];

  for (let i = 0; i < amounts.length; i++) {
    const Ko = utils.generateOneTimeAddress(
      pubViewKeys[i],
      pubSpendKeys[i],
      123
    );
    const ko = utils.oneTimeAddressPrivKey(
      pubViewKeys[i],
      privSpendKeys[i],
      123
    );

    let comm = utils.newCommitment(amounts[i], blindings[i]);
    let note = new Note(Ko, comm, tokenTypes[i], i);

    notes.push(note);
    Kos.push(Ko);
    kos.push(ko);
  }

  return { notes, amounts, blindings, Kos, kos };
}

function getNoteByAmountAddress(amount, address) {
  const blinding = randomBigInt(120);
  const tokenType = 1;

  let comm = utils.newCommitment(amount, blinding);
  const note = new Note(address, comm, tokenType);

  return { note, amount, blinding, address };
}

module.exports = {
  generateRandomData,
  generateRandomKeys,
  getDummyNotes,
  getNoteByAmountAddress,
};

function getNewAmountsFromSum(sum, nNotes) {
  let part = bigInt(sum).divide(nNotes).value;
  let last = sum - bigInt(nNotes - 1).value * part;

  let arr = new Array(nNotes - 1).fill(part, 0, nNotes - 1);
  arr.push(last);
  return arr;
}
