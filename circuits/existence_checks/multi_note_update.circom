include "./note_leaf.circom";
include "./leaf_existence.circom";
include "./get_merkle_root.circom";
include "../../circomlib/circuits/poseidon.circom";

// Checks the existence of input notes and replaces them with the output notes
template MultiNoteUpdate(n, k){
    // n is the number of notes
    // k is depth of address tree

    signal input Ko_in[n][2]; 
    signal input token_in[n];
    signal input commitment_in[n];

    signal input Ko_out[n][2]; 
    signal input token_out[n];
    signal input commitment_out[n];

    signal input intermidiateRoots[n + 1];
    signal input paths2rootPos[n][k];
    signal input paths2root[n][k];


    signal output newComputedRoot;


    component noteLeaf_in[n];
    component noteLeaf_out[n];
    component noteExistence[n];
    component updatedRoot[n];

    for (var i=0; i<n; i++) {
        noteLeaf_in[i] = NoteLeaf();

        noteLeaf_in[i].Ko[0] <== Ko_in[i][0];
        noteLeaf_in[i].Ko[1] <== Ko_in[i][1];
        noteLeaf_in[i].token  <== token_in[i];
        noteLeaf_in[i].Comm <== commitment_in[i];

        
        // this component will throw an error if the merkle proof is invalid
        noteExistence[i] = LeafExistence(k);
        noteExistence[i].leaf <== noteLeaf_in[i].out;
        noteExistence[i].root <== intermidiateRoots[i];

        // Add the output notes to the merkle tree

        noteLeaf_out[i] = NoteLeaf();

        noteLeaf_out[i].Ko[0] <== Ko_out[i][0];
        noteLeaf_out[i].Ko[1] <== Ko_out[i][1];
        noteLeaf_out[i].token  <== token_out[i];
        noteLeaf_out[i].Comm <== commitment_out[i];

        updatedRoot[i] = GetMerkleRoot(k);
        updatedRoot[i].leaf <== noteLeaf_out[i].out;
        for (var s = 0; s < k; s++) {
            noteExistence[i].paths2rootPos[s] <== paths2rootPos[i][s];
            noteExistence[i].paths2root[s] <== paths2root[i][s];

            updatedRoot[i].paths2rootPos[s] <== paths2rootPos[i][s];
            updatedRoot[i].paths2root[s] <== paths2root[i][s];
        }

        updatedRoot[i].out === intermidiateRoots[i+1];

    }

    newComputedRoot <== intermidiateRoots[n];
}

// component main  = MultiNoteUpdate(3,4);