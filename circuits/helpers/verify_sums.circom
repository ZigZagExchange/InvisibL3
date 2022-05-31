include "../../circomlib/circuits/babyjub.circom";

include "./commitment.circom";

// Verifies the sum of input commitments (pseudo commitmnets*)
// is equal to the sum of output commitment
template VerifySums(n, m) { 
    signal input amountsIn[n];
    signal input amountsOut[m];

    var sumIn = 0;
    for (var i =0; i<n; i++){
        sumIn += amountsIn[i];
    }

    var sumOut = 0;
    for (var i =0; i<m; i++){
        sumOut += amountsOut[i];
    }

    sumIn === sumOut;
}

// component main = VerifySums(5,5);
