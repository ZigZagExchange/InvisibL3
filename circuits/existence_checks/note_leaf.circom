include "../../circomlib/circuits/poseidon.circom";

template NoteLeaf() {

    signal input index;
    signal input Ko[2];
    signal input token;
    signal input Cx;
    signal input Cy;

    signal output out;

    component noteHash = Poseidon(6);
    noteHash.inputs[0] <== index;
    noteHash.inputs[1] <== Ko[0];
    noteHash.inputs[2] <== Ko[1];
    noteHash.inputs[3] <== token;
    noteHash.inputs[4] <== Cx;
    noteHash.inputs[5] <== Cy;

    out <== noteHash.out;
}


// component main { public [ index ] } = NoteLeaf();
