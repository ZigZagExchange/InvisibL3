const poseidon = require("../../circomlib/src/poseidon.js");
const { BigNumber: BN } = require("ethers");

module.exports = {
  rootFromLeafAndPath(leaf, idx, merkle_path) {
    if (merkle_path.length > 0) {
      const depth = merkle_path.length;
      const merkle_path_pos = module.exports.idxToBinaryPos(idx, depth);
      var root = new Array(depth);
      let left =
        BN.from(leaf).toBigInt() -
        BN.from(merkle_path_pos[0]).toBigInt() *
          (BN.from(leaf).toBigInt() - BN.from(merkle_path[0]).toBigInt());
      let right =
        BN.from(merkle_path[0]).toBigInt() -
        BN.from(merkle_path_pos[0]).toBigInt() *
          (BN.from(merkle_path[0]).toBigInt() - BN.from(leaf).toBigInt());
      root[0] = poseidon([left, right]);
      for (var i = 1; i < depth; i++) {
        left =
          BN.from(root[i - 1]).toBigInt() -
          BN.from(merkle_path_pos[i]).toBigInt() *
            (root[i - 1] - BN.from(merkle_path[i]).toBigInt());
        right =
          BN.from(merkle_path[i]).toBigInt() -
          BN.from(merkle_path_pos[i]).toBigInt() *
            (BN.from(merkle_path[i]).toBigInt() - root[i - 1]);
        root[i] = poseidon([left, right]);
      }
      return root[depth - 1];
    } else {
      return leaf;
    }
  },

  innerNodesFromLeafAndPath(leaf, idx, merkle_path) {
    if (merkle_path.length > 0) {
      const depth = merkle_path.length;
      const merkle_path_pos = module.exports.idxToBinaryPos(idx, depth);
      var innerNodes = new Array(depth);

      let left =
        BN.from(leaf).toBigInt() -
        BN.from(merkle_path_pos[0]).toBigInt() *
          (BN.from(leaf).toBigInt() - BN.from(merkle_path[0]).toBigInt());

      let right =
        BN.from(merkle_path[0]).toBigInt() -
        BN.from(merkle_path_pos[0]).toBigInt() *
          (BN.from(merkle_path[0]).toBigInt() - BN.from(leaf).toBigInt());
      innerNodes[0] = poseidon([left, right]);
      for (var i = 1; i < depth; i++) {
        left =
          innerNodes[i - 1] -
          BN.from(merkle_path_pos[i]).toBigInt() *
            (innerNodes[i - 1] - BN.from(merkle_path[i]).toBigInt());
        right =
          BN.from(merkle_path[i]).toBigInt() -
          BN.from(merkle_path_pos[i]).toBigInt() *
            (BN.from(merkle_path[i]).toBigInt() - innerNodes[i - 1]);
        innerNodes[i] = poseidon([left, right]);
      }
      return innerNodes;
    } else {
      return leaf;
    }
  },

  proofPos: function (leafIdx, treeDepth) {
    let proofPos = new Array(treeDepth);
    let proofBinaryPos = module.exports.idxToBinaryPos(leafIdx, treeDepth);

    if (leafIdx % 2 == 0) {
      proofPos[0] = leafIdx + 1;
    } else {
      proofPos[0] = leafIdx - 1;
    }

    for (var i = 1; i < treeDepth; i++) {
      if (proofBinaryPos[i] == 1) {
        proofPos[i] = Math.floor(proofPos[i - 1] / 2) - 1;
      } else {
        proofPos[i] = Math.floor(proofPos[i - 1] / 2) + 1;
      }
    }

    return proofPos;
  },

  getAffectedPos: function (proofPos) {
    var affectedPos = new Array(proofPos.length);

    // skip the first node in the proof since it is not affected
    for (var i = 1; i < proofPos.length; i++) {
      // if proof node has odd index (i.e. is the right sibling)
      if (proofPos[i] & 1) {
        affectedPos[i - 1] = proofPos[i] - 1; // affected node is left sibling
        // if proof node has even index (i.e. is the left sibling)
      } else {
        affectedPos[i - 1] = proofPos[i] + 1; // affected node is right sibling
      }
    }

    affectedPos[proofPos.length - 1] = 0; // the root

    return affectedPos;
  },

  binaryPosToIdx: function (binaryPos) {
    var idx = 0;
    for (i = 0; i < binaryPos.length; i++) {
      idx = idx + binaryPos[i] * 2 ** i;
    }
    return idx;
  },

  idxToBinaryPos: function (idx, binLength) {
    let binString = idx.toString(2);
    let binPos = Array(binLength).fill(0);
    for (var j = 0; j < binString.length; j++) {
      binPos[j] = Number(binString.charAt(binString.length - j - 1));
    }
    return binPos;
  },

  pairwiseHash: function (array) {
    if (array.length % 2 == 0) {
      let arrayHash = [];
      for (var i = 0; i < array.length; i = i + 2) {
        arrayHash.push(
          poseidon([array[i].toString(), array[i + 1].toString()])
        );
      }
      return arrayHash;
    } else {
      console.log("array must have even number of elements");
    }
  },

  getBase2Log: function (y) {
    return Math.log(y) / Math.log(2);
  },

  // fill an array with a fillerLength copies of a value
  padArray: function (leafArray, padValue) {
    if (Array.isArray(leafArray)) {
      var arrayClone = leafArray.slice(0);
      const nearestPowerOfTwo = Math.ceil(
        module.exports.getBase2Log(leafArray.length)
      );
      const diff = 2 ** nearestPowerOfTwo - leafArray.length;
      for (var i = 0; i < diff; i++) {
        arrayClone.push(padValue);
      }
      return arrayClone;
    } else {
      console.log("please enter an array");
    }
  },
};
