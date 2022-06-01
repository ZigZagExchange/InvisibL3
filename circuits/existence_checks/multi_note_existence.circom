include "./note_leaf.circom";
include "./leaf_existence.circom";
include "../../circomlib/circuits/poseidon.circom";

template MultiNoteExistence(n, k){
    // n is the number of notes
    // k is depth of address tree

    // signal input index;
    signal input Ko[n][2];  // address
    signal input token[n];
    signal input commitment[n][2];

    signal input root;
    signal input paths2rootPos[n][k];
    signal input paths2root[n][k];

    component noteLeaf[n];
    component noteExistence[n];
    for  (var i=0; i<n; i++) {
        noteLeaf[i] = NoteLeaf();

        noteLeaf[i].Ko[0] <== Ko[i][0];
        noteLeaf[i].Ko[1] <== Ko[i][1];
        noteLeaf[i].token  <== token[i];
        noteLeaf[i].Cx <== commitment[i][0];
        noteLeaf[i].Cy <== commitment[i][1];

        // this component will throw an error if the merkle proof is invalid
        noteExistence[i] = LeafExistence(k);
        noteExistence[i].leaf <== noteLeaf[i].out;
        noteExistence[i].root <== root;

        for (var s = 0; s < k; s++) {
            noteExistence[i].paths2rootPos[s] <== paths2rootPos[i][s];
            noteExistence[i].paths2root[s] <== paths2root[i][s];
        }
    }


}

component main  = MultiNoteExistence(8,4);