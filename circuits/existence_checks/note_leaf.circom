include "../../circomlib/circuits/poseidon.circom";

template NoteLeaf() {

    // signal input index;
    signal input Ko[2];
    signal input token;
    signal input Comm;

    signal output out;

    component noteHash = Poseidon(4);
    // noteHash.inputs[0] <== index;
    noteHash.inputs[0] <== Ko[0];
    noteHash.inputs[1] <== Ko[1];
    noteHash.inputs[2] <== token;
    noteHash.inputs[3] <== Comm;

    out <== noteHash.out;
}


// component main = NoteLeaf();
