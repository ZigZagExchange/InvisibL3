const randomBigInt = require("random-bigint");
const bigInt = require("big-integer");
const fs = require("fs");
const {
  getKeyPair,
  getStarkKey,
  getKeyPairFromPublicKey,
  sign,
  verify,
  ec,
} = require("starknet/utils/ellipticCurve");

const User = require("../../src/notes/Invisibl3User");
const Tree = require("../../src/merkle_trees/Tree.js");
const {
  Note,
  generateOneTimeAddress,
  oneTimeAddressPrivKey,
  split,
  parseAddressPk,
} = require("../../src/notes/Notes");
const InvisibleDeposit = require("../../src/transactions/InvisibleDeposit");

function test_deposits() {
  const tx_r = 127584134623894718924n;

  let kv = 12807548236904712894623847409281430927569283443252n;
  let ks = 73526904812402357328749329048238956327432893275235n;

  let user1 = new User(126583n, kv, ks);

  // & This is the address the deposit is linked to and can sign the new deposit notes
  let ko1 = user1.oneTimeAddressPrivKey(tx_r, 1);
  let Ko = user1.generateOneTimeAddress(tx_r, 1);

  let batchInitTree = new Tree([], 3);

  let tree = batchInitTree.clone();
  let preimage = {};
  let updatedNoteHashes = {};

  // Onchain public deposit data (from the blockchain)
  let depositId = 126583n;
  let amountDepsoited = 1_000_000n;
  let tokenDeposited = 0;
  let stark_key = Ko;

  let deposit = new InvisibleDeposit(
    depositId,
    tokenDeposited,
    amountDepsoited,
    stark_key
  );

  // * N note inputs
  let randAmounts = InvisibleDeposit.getRandomAmounts(amountDepsoited, 3);
  // todo: blindings and addresses should be generated programaticaly by some kind of blueprint
  let randBlindings = [
    16254127462132964698328532743249831n,
    819346324791208322235297502395325234n,
    863295749891238427238562839572343243n,
  ];
  let kos = [152787124n, 812341234n, 27347238483n];
  let randAddresses = kos.map((ko) => getKeyPair(ko).getPublic());

  deposit.generateNewNotes(
    batchInitTree,
    tree,
    preimage,
    updatedNoteHashes,
    randAmounts,
    randBlindings,
    randAddresses
  );

  deposit.signDeposit(ko1);

  deposit.verifyDepositSignature();

  let finalizedPremimage = getFinalizedPreimages(tree, updatedNoteHashes);

  preimage = { ...preimage, ...finalizedPremimage };

  let inputDeposits = [
    deposit.toinputObject(),
    deposit.toinputObject(),
    deposit.toinputObject(),
  ];

  let depositInput = {
    deposit_data: inputDeposits,
    // preimage: preimage,
    // prev_root: batchInitTree.root,
    // new_root: tree.root,
  };

  let JSON_Output = JSON.stringify(depositInput, (key, value) => {
    return typeof value === "bigint" ? value.toString() : value;
  });

  fs.writeFile("depositInputs.json", JSON_Output, () => {});
}
// test_deposits();

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
