include "../../circomlib/circuits/babyjub.circom";

include "./sum_points.circom";


// Verifies the sum of input commitments (pseudo commitmnets*)
// is equal to the sum of output commitment
template VerifySums(n, m) { 
    signal input C_in[n][2];   // input note commitments
    signal input C_out[m][2];   // output note commitments

    // sum all the input note commitments
    component S1 = SumPoints(n);
    for (var i = 0; i < n; i++) {
        S1.C_in[i][0] <== C_in[i][0];
        S1.C_in[i][1] <== C_in[i][1];
        
    }

    // sum all the output note commitments
    component S2 = SumPoints(m);
    for (var i = 0; i < m; i++) {
        S2.C_in[i][0] <== C_out[i][0];
        S2.C_in[i][1] <== C_out[i][1];
    }

    S1.sum[0] === S2.sum[0];
    S1.sum[1] === S2.sum[1];
}

component main = VerifySums(5,5);
