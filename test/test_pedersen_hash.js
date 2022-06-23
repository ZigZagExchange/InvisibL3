const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const bigInt = require("big-integer");
const Tree = require("../src/merkle_trees/tree");
const { split, splitUint256, Note } = require("../src/notes/noteUtils");
const { hashTransaction } = require("./test_secp256k1");

// * INPUTS ============================================================================
const indexes = [0, 2, 3];
const token = 1;
const tokenPrice = 2500;
const dummy_ret_sig_r =
  128964326580914270312568230948289462309515862350923523532859325n;

const amounts_in = [
  bigInt("11111100000000000000").value,
  bigInt("11111110000000000000").value,
  bigInt("11111111000000000000").value,
];
const blindings_in = [
  bigInt("11111111111111111111111111111111111").value,
  bigInt("22222222222222222222222222222222222").value,
  bigInt("33333333333333333333333333333333333").value,
];
const addresses_in = [];
for (let i = 1n; i <= 3n; i++) {
  const x =
    1111111111111111111111111111222222222222222222222222222222222222n * i;
  const y =
    2222222222222222222222222222222222223333333333333333333333333333n * i;

  let addr = [x, y];
  addresses_in.push(addr);
}

const amounts_out = [
  bigInt("44444444440000000000").value,
  bigInt("55555555555000000000").value,
  bigInt("66666666666000000000").value,
];
const blindings_out = [
  bigInt("44444444444444445555555555555555555").value,
  bigInt("55555555555555556666666666666666666").value,
  bigInt("66666666666666666677777777777777777").value,
];
const addresses_out = [];
for (let i = 1n; i <= 3n; i++) {
  const x =
    33333333333333333333333333333333444444444444444444444444444444444n * i;
  const y =
    44444444444444444444444444444444455555555555555555555555555555555n * i;

  let addr = [x, y];
  addresses_out.push(addr);
}

function log_inputs() {
  console.log('"indexes": ', indexes);
  console.log(',"token": ', token);
  console.log(',"tokenPrice": ', tokenPrice);
  console.log(',"ret_sig_r": ', dummy_ret_sig_r);

  console.log(
    '========================\n"data_in": {},\n========================'
  );
  console.log(',"amounts": ', amounts_in);
  console.log(',"blindings": ', blindings_in);
  console.log(
    ',"addresses": ',
    addresses_in.map((addr) => [split(addr[0]), split(addr[1])])
  );

  console.log(
    '========================\n"data_out": {},\n========================'
  );
  console.log(',"amounts": ', amounts_out);
  console.log(',"blindings": ', blindings_out);
  console.log(
    ',"addresses": ',
    addresses_out.map((addr) => [split(addr[0]), split(addr[1])])
  );

  console.log("\n================================================");
}
log_inputs();

//* HASH NOTES ===========================================================================

let notes_in = [];
let notes_out = [];
let leaf_hashes_in = [];
let leaf_hashes_out = [];

function hash_notes() {
  for (let i = 0; i < addresses_in.length; i++) {
    let comm_in = BigInt(pedersen([amounts_in[i], blindings_in[i]]), 16);
    let note_in = new Note(addresses_in[i], comm_in, token);
    notes_in.push(note_in);
    leaf_hashes_in.push(note_in.hash);

    let comm_out = BigInt(pedersen([amounts_out[i], blindings_out[i]]), 16);
    let note_out = new Note(addresses_out[i], comm_out, token);
    notes_out.push(note_out);
    leaf_hashes_out.push(note_out.hash);
  }
}

hash_notes();

console.log("leaf_hashes_in: ", leaf_hashes_in);
console.log("leaf_hashes_out: ", leaf_hashes_out);

// console.log("leaf nodes out: ", leaf_hashes_out);

//* BUILD THE TREE =========================================================================
// replace the input notes in the tree with the output notes

function tree_update_tests() {
  // notes in are at indexes 0, 2, 3
  let arr = new Array(8).fill(0);
  arr[indexes[0]] = leaf_hashes_in[0];
  arr[indexes[1]] = leaf_hashes_in[1];
  arr[indexes[2]] = leaf_hashes_in[2];

  let tree = new Tree(arr);

  console.log(',"prev_root": ', tree.root);

  let proofs_in = [];
  let preimages_in = [];
  for (let i = 0; i < indexes.length; i++) {
    let proof = tree.getProof(indexes[i]);
    let multiUpdateProof = tree.getMultiUpdateProof(
      leaf_hashes_in[i],
      proof.proof,
      proof.proofPos
    );
    proofs_in.push(proof.proof);
    preimages_in.push(multiUpdateProof);
  }

  for (let i = 0; i < tokens_out.length; i++) {
    tree.updateNode(leaf_hashes_out[i], indexes[i], proofs_in[i]);
  }

  let proofs_out = [];
  let preimages_out = [];
  for (let i = 0; i < tokens_out.length; i++) {
    let proof = tree.getProof(indexes[i]);
    let multiUpdateProof2 = tree.getMultiUpdateProof(
      leaf_hashes_out[i],
      proof.proof,
      proof.proofPos
    );

    proofs_out.push(proof.proof);
    preimages_out.push(multiUpdateProof2);
  }

  // console.log("preimages_in: ", preimages_in);
  // console.log("\n\npreimages_out: ", preimages_out);

  let preimage = {};
  for (let i = 0; i < preimages_in.length; i++) {
    preimages_in[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }
  for (let i = 0; i < preimages_out.length; i++) {
    preimages_out[i].forEach((value, key) => {
      preimage[key] = value;
    });
  }

  console.log(',"preimage": ', preimage);

  console.log(',"new_root": ', tree.root);
}

function tx_hash_test() {
  let hash = hashTransaction(
    notes_in,
    notes_out,
    token,
    tokenPrice,
    dummy_ret_sig_r
  );

  console.log("hash: ", hash);
}

tx_hash_test();
