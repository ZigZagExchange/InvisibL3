include "./note_leaf.circom";
include "./leaf_existence.circom";
include "../../circomlib/circuits/poseidon.circom";

template NoteExistence(k){
    // k is depth of address tree

    // signal input index;
    signal input Ko[2];  // address
    signal input token;
    signal input commitment[2];


    signal input root;
    signal input paths2rootPos[k];
    signal input paths2root[k];


    component noteLeaf = NoteLeaf();
    // noteLeaf.index <== index;
    noteLeaf.Ko[0] <== Ko[0];
    noteLeaf.Ko[1] <== Ko[1];
    noteLeaf.token  <== token;
    noteLeaf.Cx <== commitment[0];
    noteLeaf.Cy <== commitment[1];

    // this component will throw an error if the merkle proof is invalid
    component noteExistence = LeafExistence(k);
    noteExistence.leaf <== noteLeaf.out;
    noteExistence.root <== root;

    for (var s = 0; s < k; s++){
        noteExistence.paths2rootPos[s] <== paths2rootPos[s];
        noteExistence.paths2root[s] <== paths2root[s];
    }

}

// component main  = NoteExistence(4);

