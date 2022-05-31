include "../../circomlib/circuits/poseidon.circom";

include "../signatures/verify_ret_addr_sig.circom";
include "../signatures/verify_sig.circom";
include "./transaction_hash.circom";
include "../helpers/verify_sums.circom";
include "./verify_commitments.circom";

include "../../circomlib/circuits/bitify.circom";


template noteTransaction(n, m) {
    // n is the number of notesIn, m is the number of notesOut
    signal input notesIn[n][6];   // note = [index, Kx, Ky, token, Cx, Cy]
    signal input pseudoComms[n][2];
    signal input pos[n];
    signal input notesOut[m][6];
    signal input amountsIn[n];
    signal input amountsOut[m];
    signal input blindingsIn[n];
    signal input blindingsOut[m];
    signal input tokenSpent;
    signal input tokenSpentPrice;
    signal input tokenReceived;
    signal input tokenReceivedPrice;
    signal input Ko[2];  // one time address calculated as  Ko =  H(r * Kv, 0)G + Ks

    signal input returnAddressSig[2];   // [c,r]  -> c is private
    signal input signature[1 + n];    // [c, r]   // Might make all signatures private

    component c2bits = Num2Bits_strict();
    c2bits.in <== returnAddressSig[0];
    component r2bits = Num2Bits_strict();
    r2bits.in <== returnAddressSig[1];


    //* Verify the amounts and blindings actually match the commitments
    component verifyCommitmentsIn = VerifyCommitments(5);
    for (var i=0; i<n; i++) {
        verifyCommitmentsIn.C[i][0] <== notesIn[i][4];
        verifyCommitmentsIn.C[i][1] <== notesIn[i][5];
        verifyCommitmentsIn.amounts[i] <== amountsIn[i];
        verifyCommitmentsIn.blindings[i] <== blindingsIn[i];    
    }
    component verifyCommitmentsOut = VerifyCommitments(5);
    for (var i=0; i<m; i++) {
        verifyCommitmentsOut.C[i][0] <== notesOut[i][4];
        verifyCommitmentsOut.C[i][1] <== notesOut[i][5];
        verifyCommitmentsOut.amounts[i] <== amountsOut[i];
        verifyCommitmentsOut.blindings[i] <== blindingsOut[i];    
    }

    //* Verify return address signature   (return notes sent to the right address)
    component verifyReturnAddressSig = VerifyRetAddrSig();
    verifyReturnAddressSig.c <== returnAddressSig[0];
    verifyReturnAddressSig.r <== returnAddressSig[1];
    verifyReturnAddressSig.tokenReceived <== tokenReceived;
    verifyReturnAddressSig.tokenReceivedPrice <== tokenReceivedPrice;
    verifyReturnAddressSig.Ko[0] <== Ko[0];
    verifyReturnAddressSig.Ko[1] <== Ko[1];


    //* Hash the transaction
    component txHash = TxHash(n,m);
    for (var i=0; i<n; i++){
        txHash.notesIn[i][0] <== notesIn[i][0];
        txHash.notesIn[i][1] <== notesIn[i][1];
        txHash.notesIn[i][2] <== notesIn[i][2];
        txHash.notesIn[i][3] <== notesIn[i][3];
        txHash.notesIn[i][4] <== notesIn[i][4];
        txHash.notesIn[i][5] <== notesIn[i][5];
    }
    for (var i=0; i<m; i++){
        txHash.notesOut[i][0] <== notesOut[i][0];
        txHash.notesOut[i][1] <== notesOut[i][1];
        txHash.notesOut[i][2] <== notesOut[i][2];
        txHash.notesOut[i][3] <== notesOut[i][3];
        txHash.notesOut[i][4] <== notesOut[i][4];
        txHash.notesOut[i][5] <== notesOut[i][5];
    }
    txHash.tokenSpent <== tokenSpent;
    txHash.tokenSpentPrice <== tokenSpentPrice;
    txHash.retSigR <== returnAddressSig[1];


    //* Verify the signature of the transaction - (private keys for addresses and commitments to zero)
    component verifySig = VerifySig(n);
    verifySig.m <== txHash.out;
    verifySig.c <== signature[0];
    for (var i=0; i<n; i++) {
        verifySig.K[i][0] <== notesIn[i][1];  // Kx
        verifySig.K[i][1] <== notesIn[i][2];  // Ky
        verifySig.C_prev[i][0] <== notesIn[i][4];   // Cx 
        verifySig.C_prev[i][1] <== notesIn[i][5];   // Cy
        verifySig.C_new[i][0] <== pseudoComms[i][0];  // pseudo Cx
        verifySig.C_new[i][1] <== pseudoComms[i][1];  // pseudo Cy
        verifySig.pos[i] <== pos[i];
        verifySig.rs[i] <== signature[i+1]; 
    }


    //* check that the input and output note sum is the same
    component verifySums = VerifySums(n, m);
    for (var i=0; i<n; i++){
        verifySums.amountsIn[i] <== amountsIn[i];
    }
    for (var i=0; i<m; i++){
        verifySums.amountsOut[i] <== amountsOut[i];
    }


    //* If everything passes the transaction itself is valid (maybe add some extra checks)
    

}

// component main = noteTransaction(5,5);