include "../helpers/commitment.circom";
include "../../circomlib/circuits/poseidon.circom";
// include "../../circomlib/circuits/comparators.circom";
// include "../../circomlib/circuits/switcher.circom";
// include "../../circomlib/circuits/gates.circom";

template VerifyCommitments(n){
    signal input C[n];
    signal input amounts[n];
    signal input blindings[n];


    component commitments[n];
    component lessThan[n];
    component equalIf[n];

    for (var i=0; i<n; i++) {

        // Verify amounts are in range (non negative)
        lessThan[i] = LessThan(68);
        lessThan[i].in[0] <== amounts[i];
        lessThan[i].in[1] <== 2 ** 67;

        lessThan[i].out === 1;


        commitments[i] = Poseidon(2);
        commitments[i].inputs[0] <== amounts[i];
        commitments[i].inputs[1] <== blindings[i];


        equalIf[i] = ForceEqualIfEnabled();
        equalIf[i].in[0] <== commitments[i].out;
        equalIf[i].in[1] <== C[i];
        equalIf[i].enabled <== C[i];

    }

}

// component main = VerifyCommitments(5);