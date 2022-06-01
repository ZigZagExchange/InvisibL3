const treeUtils = require("./treeUtils.js");

module.exports = class Tree {
  constructor(_leafNodes) {
    this.leafNodes = _leafNodes;
    this.depth = treeUtils.getBase2Log(_leafNodes.length);
    this.innerNodes = this.treeFromLeafNodes();
    this.root = this.innerNodes[0][0];
  }

  updateInnerNodes(leaf, idx, merkle_path) {
    // get position of affected inner nodes
    const depth = merkle_path.length;
    const proofPos = treeUtils.proofPos(idx, depth);
    const affectedPos = treeUtils.getAffectedPos(proofPos);
    // get new values of affected inner nodes and update them
    const affectedInnerNodes = treeUtils.innerNodesFromLeafAndPath(
      leaf,
      idx,
      merkle_path
    );

    // update affected inner nodes
    for (var i = 1; i < depth + 1; i++) {
      this.innerNodes[depth - i][affectedPos[i - 1]] =
        affectedInnerNodes[i - 1];
    }

    this.root = this.innerNodes[0][0];
  }

  updateLeafNodes(leafHash, idx) {
    this.leafNodes[idx] = leafHash;
  }

  updateNode(leafHash, idx, proof) {
    this.updateInnerNodes(leafHash, idx, proof);
    this.updateLeafNodes(leafHash, idx);
  }

  treeFromLeafNodes() {
    var tree = Array(this.depth);
    tree[this.depth - 1] = treeUtils.pairwiseHash(this.leafNodes);

    for (var j = this.depth - 2; j >= 0; j--) {
      tree[j] = treeUtils.pairwiseHash(tree[j + 1]);
    }
    return tree;
  }

  getProof(leafIdx, depth = this.depth) {
    const proofBinaryPos = treeUtils.idxToBinaryPos(leafIdx, depth);
    const proofPos = treeUtils.proofPos(leafIdx, depth);
    var proof = new Array(depth);
    proof[0] = this.leafNodes[proofPos[0]];
    for (var i = 1; i < depth; i++) {
      proof[i] = this.innerNodes[depth - i][proofPos[i]];
    }
    return {
      proof: proof,
      proofPos: proofBinaryPos,
    };
  }

  verifyProof(leafHash, idx, proof) {
    const computed_root = treeUtils.rootFromLeafAndPath(leafHash, idx, proof);
    return this.root == computed_root;
  }

  verifyRoot() {
    let treeTemp = this.treeFromLeafNodes();
    return this.root == treeTemp[0][0];
  }
};
