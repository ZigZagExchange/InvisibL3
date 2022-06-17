const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const bigInt = require("big-integer");

let a = 123456n;
let b = 654321n;
let c = 111111n;
let d = 999999n;

// let res = pedersen([a, b]);

// let res = computeHashOnElements([
//   a,b,c,d
// ]);

let res = pedersen([
  123456789n,
  1000200030004000500060007000800090000000000000000000n,
]);

console.log("res:", BigInt(res, 16));

// let res = computeHashOnElements([a, b, c, d]);

// console.time("hash");
// for (let i = 0; i < 1000; i++) {
//   let res = pedersen([a, b]);
// }
// console.timeEnd("hash");

// console.log(BigInt(res, 16));
