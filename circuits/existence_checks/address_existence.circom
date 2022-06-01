include "./address_leaf.circom";
include "./leaf_existence.circom";
include "../../circomlib/circuits/poseidon.circom";

template AddressExistence(k, n_notes){
// k is depth of address tree
// n_notes is number of notes

    signal input index;
    signal input pubkeyX;
    signal input pubkeyY;
    signal input note_idxs[n_notes]; 
    signal input note_tokens[n_notes];
    signal input note_comms[n_notes][2];

    signal input addressRoot;
    signal input paths2rootPos[k];
    signal input paths2root[k];


    component addressLeaf = AddressLeaf(n_notes);
    addressLeaf.index <== index;
    addressLeaf.pubkeyX <== pubkeyX;
    addressLeaf.pubkeyY <== pubkeyY;
    for (var i = 0; i < n_notes; i++){
        addressLeaf.note_idxs[i] <== note_idxs[i];
        addressLeaf.note_tokens[i] <== note_tokens[i];
        addressLeaf.note_comms[i][0] <== note_comms[i][0];
        addressLeaf.note_comms[i][1] <== note_comms[i][1];
    }

    // this component will throw an error if the merkle proof is invalid
    component addressExistence = LeafExistence(k);
    addressExistence.leaf <== addressLeaf.out;
    addressExistence.root <== addressRoot;

    for (var s = 0; s < k; s++){
        addressExistence.paths2rootPos[s] <== paths2rootPos[s];
        addressExistence.paths2root[s] <== paths2root[s];
    }


}

component main { public [ index, pubkeyX, pubkeyY, note_comms ] } = AddressExistence(3, 3);

