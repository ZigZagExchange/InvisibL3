const noteUtils = require("../src/notes/noteUtils");
const dummyData = require("../src/dummy/dummyData");
const Transaction = require("../src/transactions/noteTransaction.js");
const Swap = require("../src/transactions/swapTransaction.js");
const randomBigInt = require("random-bigint");

//TODO Temporary randomness for one time address
const RAND_SEED = 123456789;

const TOKEN_X = 1; // Token user sends to the market maker
const TOKEN_X_PRICE = 2000n;
const TOKEN_X_AMOUNT = 1000n * 10n ** 15n;

// A*AP = B*BP  => B = A*AP/BP
const TOKEN_Y = 1; // Token user receives from the market maker
const TOKEN_Y_PRICE = 32000n;
const TOKEN_Y_AMOUNT = (TOKEN_X_PRICE * TOKEN_X_AMOUNT) / TOKEN_Y_PRICE;

//* GENERATE ADDRESS: ========================================================
let keys = dummyData.generateRandomKeys(2);

let taker_Ko = noteUtils.generateOneTimeAddress(
  keys.pubViewKeys[0],
  keys.pubSpendKeys[0],
  RAND_SEED
);
let taker_ko = noteUtils.oneTimeAddressPrivKey(
  keys.pubViewKeys[0],
  keys.privSpendKeys[0],
  RAND_SEED
);

let maker_Ko = noteUtils.generateOneTimeAddress(
  keys.pubViewKeys[1],
  keys.pubSpendKeys[1],
  RAND_SEED
);
let maker_ko = noteUtils.oneTimeAddressPrivKey(
  keys.pubViewKeys[1],
  keys.privSpendKeys[1],
  RAND_SEED
);

//* TAKER TRANSACTION: ========================================================

let inputNoteData = dummyData.getDummyNotes();

const sum = inputNoteData.amounts.reduce((partialSum, a) => partialSum + a, 0n);

let takerNote1 = dummyData.getNoteByAmountAddress(TOKEN_X_AMOUNT, maker_Ko);
let outputNoteData = dummyData.getDummyNotes(4, sum - TOKEN_X_AMOUNT);

outputNoteData = {
  notes: [takerNote1.note].concat(outputNoteData.notes),
  amounts: [takerNote1.amount].concat(outputNoteData.amounts),
  blindings: [takerNote1.blinding].concat(outputNoteData.blindings),
  Kos: [maker_Ko].concat(outputNoteData.Kos),
};

let cmtzData = noteUtils.cmtzPrivKeys(
  inputNoteData.notes,
  inputNoteData.amounts,
  inputNoteData.blindings,
  outputNoteData.blindings
);

let pseudoCommitments = noteUtils.newCommitments(
  inputNoteData.amounts,
  cmtzData.new_blindings
);

let tx = new Transaction(
  inputNoteData.notes,
  pseudoCommitments,
  cmtzData.pos,
  outputNoteData.notes,
  inputNoteData.amounts,
  outputNoteData.amounts,
  inputNoteData.blindings,
  outputNoteData.blindings,
  TOKEN_X,
  TOKEN_X_PRICE,
  TOKEN_Y,
  TOKEN_Y_PRICE,
  keys.pubSpendKeys[0],
  keys.pubViewKeys[0]
);

// console.log(
//   "notesIn: ",
//   inputNoteData.notes.map((note) => [
//     note.index,
//     note.address[0],
//     note.address[1],
//     note.token,
//     note.commitment[0],
//     note.commitment[1],
//   ])
// );
// console.log(",pseudo_comms: ", pseudoCommitments);
// console.log(",pos: ", cmtzData.pos);
// console.log(
//   ",notesOut: ",
//   outputNoteData.notes.map((note) => [
//     note.index,
//     note.address[0],
//     note.address[1],
//     note.token,
//     note.commitment[0],
//     note.commitment[1],
//   ])
// );
// console.log(",amountsIn: ", inputNoteData.amounts);
// console.log(",amountsOut: ", outputNoteData.amounts);
// console.log(",blindingsIn: ", inputNoteData.blindings);
// console.log(",blindingsOut: ", outputNoteData.blindings);
// console.log(",tokenSpent: ", TOKEN_X);
// console.log(",tokenSpentPrice: ", TOKEN_X_PRICE);
// console.log(",tokenReceived: ", TOKEN_Y);
// console.log(",tokenReceivedPrice: ", TOKEN_Y_PRICE);
// console.log(
//   ",Ko: ",
//   noteUtils.generateOneTimeAddress(
//     keys.pubViewKeys[0],
//     keys.pubSpendKeys[0],
//     RAND_SEED
//   )
// );

// SIGNING

let retAddrSig = tx.signPrivateReturnAddress(keys.privSpendKeys[0]);
let sig = tx.signTransaction(inputNoteData.kos, cmtzData.priv_keys_z);

// console.log(",retAddrSig: ", retAddrSig);
// console.log(",sig: ", sig);

// VERIFYING

let Zs = noteUtils.cmtzPubKeys(
  inputNoteData.notes,
  pseudoCommitments,
  cmtzData.pos
);

// tx.verifyPrivReturnAddressSig(retAddrSig);
// tx.verifySignature(sig);
// tx.verifySums(pseudoCommitments, outputNoteData.notes);

//* MAKER TRANSACTION: ========================================================

let inputNoteData2 = dummyData.getDummyNotes(5);

const sum2 = inputNoteData2.amounts.reduce(
  (partialSum, a) => partialSum + a,
  0n
);

let makerNote1 = dummyData.getNoteByAmountAddress(TOKEN_Y_AMOUNT, taker_Ko);
let outputNoteData2 = dummyData.getDummyNotes(4, sum2 - makerNote1.amount);
outputNoteData2 = {
  notes: [makerNote1.note].concat(outputNoteData2.notes),
  amounts: [makerNote1.amount].concat(outputNoteData2.amounts),
  blindings: [makerNote1.blinding].concat(outputNoteData2.blindings),
  Kos: [taker_Ko].concat(outputNoteData2.Kos),
};

let cmtzData2 = noteUtils.cmtzPrivKeys(
  inputNoteData2.notes,
  inputNoteData2.amounts,
  inputNoteData2.blindings,
  outputNoteData2.blindings
);

let pseudoCommitments2 = noteUtils.newCommitments(
  inputNoteData2.amounts,
  cmtzData2.new_blindings
);

let tx2 = new Transaction(
  inputNoteData2.notes,
  pseudoCommitments2,
  cmtzData2.pos,
  outputNoteData2.notes,
  inputNoteData2.amounts,
  outputNoteData2.amounts,
  inputNoteData2.blindings,
  outputNoteData2.blindings,
  TOKEN_Y,
  TOKEN_Y_PRICE,
  TOKEN_X,
  TOKEN_X_PRICE,
  keys.pubSpendKeys[1],
  keys.pubViewKeys[1]
);

// SIGNING
let retAddrSig2 = tx2.signPrivateReturnAddress(keys.privSpendKeys[1]);
let sig2 = tx2.signTransaction(inputNoteData2.kos, cmtzData2.priv_keys_z);

// VERIFYING
let Zs2 = noteUtils.cmtzPubKeys(
  inputNoteData2.notes,
  pseudoCommitments2,
  cmtzData2.pos
);

// tx2.verifyPrivReturnAddressSig(retAddrSig2);
// tx2.verifySignature(sig2);
// tx2.verifySums(pseudoCommitments2, outputNoteData2.notes);

//* SWAP TRANSACTION: ========================================================

const swap = new Swap(tx, tx2);

// let swapQuoteSig = swap.signCorrectSwapQuotes(
//   TOKEN_X_AMOUNT,
//   TOKEN_Y_AMOUNT,
//   takerNote1.blinding,
//   makerNote1.blinding,
//   TOKEN_X_PRICE,
//   TOKEN_Y_PRICE
// );

// swap.verifyCorrectSwapQuotes(
//   TOKEN_X_PRICE,
//   TOKEN_Y_PRICE,
//   swapQuoteSig.pos,
//   swapQuoteSig.sig
// );

swap.verify(
  retAddrSig,
  sig,
  retAddrSig2,
  sig2,
  TOKEN_X,
  TOKEN_X_PRICE,
  TOKEN_Y,
  TOKEN_Y_PRICE
  // swapQuoteSig.pos,
  // swapQuoteSig.sig
);
