const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");

const User = require("../../src/notes/Invisibl3User.js");
const Tree = require("../../src/merkle_trees/Tree.js");
const InvisibleSwap = require("../../src/transactions/InvisibleSwap");

const {
  Note,
  generateOneTimeAddress,
  oneTimeAddressPrivKey,
  split,
  parseAddressPk,
} = require("../../src/notes/Notes");
const {
  noteDataToJSON,
  storeNewUser,
  fetchStoredUser,
  fetchUserIds,
  fetchAllTokens,
  getNextNoteIdx,
  addNoteToTree,
  updateNote,
  initZeroTree,
  addInnerNodes,
} = require("../../src/firebase/storeUserData");

var fs = require("fs");

async function test_withdrawal() {
  const ids = await fetchUserIds();

  const userA = await fetchStoredUser(ids["0"]);

  let notesArray = userA.noteData[0].notes;
  notesArray = notesArray.map((note) => note.hash);
  let batchInitTree = new Tree(notesArray, 3);

  let tree = batchInitTree.clone();
  let preimage = {};
  let updatedNoteHashes = {};

  // Onchain public withdraw data (sent to the blockchain)
  let amountWithdrawn = 100_000n;
  let tokenWithdrawn = 0;
  let stark_key = getKeyPair("0x643ef7a997cc83ba897ef8932cac930dd").getPublic();

  let withdrawal = userA.makeWithdrawalOrder(
    amountWithdrawn,
    tokenWithdrawn,
    stark_key
  );

  // withdrawal.verifySignatures();

  withdrawal.executeWithdrawal(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes
  );

  let finalizedPremimage = getFinalizedPreimages(tree, updatedNoteHashes);

  preimage = { ...preimage, ...finalizedPremimage };

  let inputWithdrawal = [
    withdrawal.toinputObject(),
    withdrawal.toinputObject(),
    withdrawal.toinputObject(),
  ];

  let withdrawInput = {
    withdraw_data: inputWithdrawal,
    preimage: preimage,
    prev_root: batchInitTree.root,
    new_root: tree.root,
  };

  let JSON_Output = JSON.stringify(withdrawInput, (key, value) => {
    return typeof value === "bigint" ? value.toString() : value;
  });

  fs.writeFile("withdrawInputs.json", JSON_Output, () => {});
}
test_withdrawal().catch(console.log);

function getFinalizedPreimages(tree, updatedNoteHashes) {
  let finalizedPreimages = {};
  for (const [key, value] of Object.entries(updatedNoteHashes)) {
    let multiUpdateProof = tree.getMultiUpdateProof(
      value.leafHash,
      value.proof.proof,
      value.proof.proofPos
    );

    multiUpdateProof.forEach((value, key) => {
      finalizedPreimages[key] = value;
    });
  }

  return finalizedPreimages;
}
