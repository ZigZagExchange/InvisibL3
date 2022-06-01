include "./get_merkle_root.circom";

// checks for existence of leaf in tree of depth k

template LeafExistence(k){
// k is depth of tree

    signal input leaf; 
    signal input root;
    signal input paths2rootPos[k];
    signal input paths2root[k];

    component computedRoot = GetMerkleRoot(k);
    computedRoot.leaf <== leaf;

    for (var i = 0; i < k; i++){
        computedRoot.paths2root[i] <== paths2root[i];
        computedRoot.paths2rootPos[i] <== paths2rootPos[i];
    }

    // equality constraint: input tx root === computed tx root 
    root === computedRoot.out;
}

// component main = LeafExistence(4);

