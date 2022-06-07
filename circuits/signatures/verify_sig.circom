include "../../circomlib/circuits/escalarmulany.circom";
include "../../circomlib/circuits/bitify.circom";
include "../../circomlib/circuits/babyjub.circom";
include "../../circomlib/circuits/poseidon.circom";

include "../signatures/c_input.circom";

template VerifySig(n) {
    signal input K[n][2];
    signal input m;  // tx_hash
    signal input c;  
    signal input rs[n];

    
    // Hash function
    component hash = Poseidon(2*n+1);
    //first input is m
    hash.inputs[0] <== m;

    component c_input[n];

    // loop for n times
    for (var i=0; i<n; i++) {

        c_input[i] = CInput();

        c_input[i].K[0] <== K[i][0];
        c_input[i].K[1] <== K[i][1];
        c_input[i].m <== m;
        c_input[i].c <== c;
        c_input[i].r <== rs[i];

        // hash input <== c_input.out 
        hash.inputs[2*i + 1] <== c_input[i].out[0];
        hash.inputs[2*i + 2] <== c_input[i].out[1];

    }

    // verify h.out == c
    hash.out === c;
}

// component main = VerifySig(3);

