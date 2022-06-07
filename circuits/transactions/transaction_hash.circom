include "../../circomlib/circuits/poseidon.circom";

include "../existence_checks/note_leaf.circom";

template TxHash(n, m){
    // n is the number of notesIn, m is the number of notesOut
    signal input notesIn[n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input notesOut[m][5];
    signal input tokenSpent;
    signal input tokenSpentPrice;
    signal input retSigR;

    signal output out;


    component notesInHash = Poseidon(n);
    component noteInLeaf[n];
    for(var i=0; i<n; i++){
        noteInLeaf[i] = NoteLeaf();  // note hash
        // noteInLeaf[i].index <== notesIn[i][0];
        noteInLeaf[i].Ko[0] <== notesIn[i][1];
        noteInLeaf[i].Ko[1] <== notesIn[i][2];
        noteInLeaf[i].token <== notesIn[i][3];
        noteInLeaf[i].Comm <== notesIn[i][4];

        notesInHash.inputs[i] <== noteInLeaf[i].out;
    }

    component notesOutHash = Poseidon(m);
    component noteOutLeaf[m];
    for(var i=0; i<m; i++){
        noteOutLeaf[i] = NoteLeaf();  // note hash
        // noteOutLeaf[i].index <== notesOut[i][0];
        noteOutLeaf[i].Ko[0] <== notesOut[i][1];
        noteOutLeaf[i].Ko[1] <== notesOut[i][2];
        noteOutLeaf[i].token <== notesOut[i][3];
        noteOutLeaf[i].Comm <== notesOut[i][4];

        notesOutHash.inputs[i] <== noteOutLeaf[i].out;
    }

    // log(notesInHash.out);
    // log(notesOutHash.out);

    component txHash = Poseidon(5);
    txHash.inputs[0] <== notesInHash.out;
    txHash.inputs[1] <== notesOutHash.out;
    txHash.inputs[2] <== tokenSpent;
    txHash.inputs[3] <== tokenSpentPrice;
    txHash.inputs[4] <== retSigR;


    out <== txHash.out;
}


// component main  = TxHash(3,3);

