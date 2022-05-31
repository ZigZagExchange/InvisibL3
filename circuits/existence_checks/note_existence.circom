include "./note_leaf.circom";
include "../helpers/leaf_existence.circom";
include "../../circomlib/circuits/poseidon.circom";

template NoteExistence(k){
// k is depth of address tree

    signal input index;
    signal input K0[2];  // address
    signal input token;
    signal input commitment[2];


    signal input notesRoot;
    signal input paths2rootPos[k];
    signal input paths2root[k];


    component noteLeaf = NoteLeaf();
    noteLeaf.index <== index;
    noteLeaf.K0[0] <== K0[0];
    noteLeaf.K0[1] <== K0[1];
    noteLeaf.token  <== token;
    noteLeaf.Cx <== commitment[0];
    noteLeaf.Cy <== commitment[1];

    // this component will throw an error if the merkle proof is invalid
    component noteExistence = LeafExistence(k);
    noteExistence.leaf <== noteLeaf.out;
    noteExistence.root <== notesRoot;

    for (var s = 0; s < k; s++){
        noteExistence.paths2rootPos[s] <== paths2rootPos[s];
        noteExistence.paths2root[s] <== paths2root[s];
    }


}

component main { public [ index ] } = NoteExistence(3);

