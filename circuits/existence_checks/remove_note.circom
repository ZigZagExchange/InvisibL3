include "./note_leaf.circom";
include "./leaf_existence.circom";
include "../../circomlib/circuits/poseidon.circom";

template RemoveNoteLeaf(k){
    // k is depth of address tree

    const ZERO_HASH = 1972593120533667380477339603313231606809289461898419477679735141070009144584;
    signal input paths2root[k];
    signal input paths2rootPos[k];

    signal output intermidiateRoot;

    // hash of first two entries in tx Merkle proof
    component merkleRoot[k];
    merkleRoot[0] = Poseidon(2);
    merkleRoot[0].inputs[0] <== leaf - paths2rootPos[0]* (leaf - paths2root[0]);
    merkleRoot[0].inputs[1] <== paths2root[0] - paths2rootPos[0]* (paths2root[0] - leaf);

    // hash of all other entries in tx Merkle proof
    for (var v = 1; v < k; v++){
        merkleRoot[v] = Poseidon(2);
        merkleRoot[v].inputs[0] <== merkleRoot[v-1].out - paths2rootPos[v]* (merkleRoot[v-1].out - paths2root[v]);
        merkleRoot[v].inputs[1] <== paths2root[v] - paths2rootPos[v]* (paths2root[v] - merkleRoot[v-1].out);
    }

    // output computed Merkle root
    intermidiateRoot <== merkleRoot[k-1].out;

}

component main = RemoveNoteLeaf(4);