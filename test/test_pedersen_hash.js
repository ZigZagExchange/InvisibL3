const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const bigInt = require("big-integer");
const Tree = require("../src/merkle_trees/tree");

// let a = 123456n;
// let b = 654321n;
// let c = 111111n;
// let d = 999999n;

// let res = pedersen([
//   123456789n,
//   1000200030004000500060007000800090000000000000000000n,
// ]);
// console.log("res:", BigInt(res, 16));

const amount = bigInt("1000000000000000000").value;
const blinding = bigInt("123456789987654321").value;
const address = [1111222233334444n, 5555666677778888n];
const token = 0;

// return poseidon([
//   // this.index,
//   this.address[0],
//   this.address[1],
//   this.token,
//   this.commitment,
// ]);

let noteLeaf = computeHashOnElements([
  address[0],
  address[1],
  token,
  pedersen([amount, blinding]),
]);

console.log(BigInt(noteLeaf, 16).toString());

let arr = new Array(8).fill(0);

arr[0] = BigInt(noteLeaf, 16);

let tree = new Tree(arr);

let proof = tree.getProof(0);

console.log(proof);
console.log(tree.root);
