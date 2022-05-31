include "../helpers/commitment.circom";

template VerifyCommitments(n){
    signal input C[n][2];
    signal input amounts[n];
    signal input blindings[n];

    component commitments[n];
    component forceEqual[2*n]; 

    for (var i=0; i<n; i++) {

        commitments[i] = Commitment();

        commitments[i].amount <== amounts[i];
        commitments[i].blinding <== blindings[i];

        commitments[i].Cx === C[i][0];
        commitments[i].Cy === C[i][1];

        // forceEqual[i] = ForceEqualIfEnabled();
        // forceEqual[n + i] = ForceEqualIfEnabled();

        // forceEqual[i].enabled <== amounts[i];
        // forceEqual[i].in[0] <== commitments[i].Cx;
        // forceEqual[i].in[1] <== C[i][0];
        
        // forceEqual[n+i].enabled <== amounts[i];
        // forceEqual[n+i].in[0] <== commitments[i].Cy;
        // forceEqual[n+i].in[1] <== C[i][1];
        
    }

}

// component main = VerifyCommitments(5);