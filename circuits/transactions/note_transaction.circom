include "../../circomlib/circuits/poseidon.circom";

include "../signatures/verify_ret_addr_sig.circom";
include "../signatures/verify_sig.circom";
include "./transaction_hash.circom";
include "../helpers/verify_sums.circom";
include "../helpers/verify_commitments.circom";
include "../existence_checks/multi_note_update.circom";

include "../../circomlib/circuits/bitify.circom";


template noteTransaction(n, k) {
    // n is the number of notesIn, n is the number of notesOut
    // k is the depth of the tree

    signal input notesIn[n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input notesOut[n][5];
    signal input amountsIn[n];
    signal input amountsOut[n];
    signal input blindingsIn[n];
    signal input blindingsOut[n];
    signal input tokenSpent;
    signal input tokenSpentPrice;
    signal input tokenReceived;
    signal input tokenReceivedPrice;
    signal input Ko[2];  // one time address calculated as  Ko =  H(r * Kv, 0)G + Ks

    signal input returnAddressSig[2];   // [c,r]  -> c is private
    signal input signature[1 + n];    // [c, r]   // Might make all signatures private

    signal input initialRoot;
    signal input intermidiateRoots[n+1];
    signal input paths2rootPos[n][k];
    signal input paths2root[n][k];

    signal output updatedRoot;

    component c2bits = Num2Bits_strict();
    c2bits.in <== returnAddressSig[0];
    component r2bits = Num2Bits_strict();
    r2bits.in <== returnAddressSig[1];


    //* Verify the amounts and blindings actually match the commitments
    component verifyCommitmentsIn = VerifyCommitments(3);
    for (var i=0; i<n; i++) {
        verifyCommitmentsIn.C[i] <== notesIn[i][4];
        verifyCommitmentsIn.amounts[i] <== amountsIn[i];
        verifyCommitmentsIn.blindings[i] <== blindingsIn[i];    
    }
    component verifyCommitmentsOut = VerifyCommitments(3);
    for (var i=0; i<n; i++) {
        verifyCommitmentsOut.C[i] <== notesOut[i][4];
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
    component txHash = TxHash(n,n);
    for (var i=0; i<n; i++){
        txHash.notesIn[i][0] <== notesIn[i][0];
        txHash.notesIn[i][1] <== notesIn[i][1];
        txHash.notesIn[i][2] <== notesIn[i][2];
        txHash.notesIn[i][3] <== notesIn[i][3];
        txHash.notesIn[i][4] <== notesIn[i][4];
    }
    for (var i=0; i<n; i++){
        txHash.notesOut[i][0] <== notesOut[i][0];
        txHash.notesOut[i][1] <== notesOut[i][1];
        txHash.notesOut[i][2] <== notesOut[i][2];
        txHash.notesOut[i][3] <== notesOut[i][3];
        txHash.notesOut[i][4] <== notesOut[i][4];
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
        verifySig.rs[i] <== signature[i+1]; 
    }

    

    //* check that the input and output note sum is the same
    component verifySums = VerifySums(n, n);
    for (var i=0; i<n; i++){
        verifySums.amountsIn[i] <== amountsIn[i];
    }
    for (var i=0; i<n; i++){
        verifySums.amountsOut[i] <== amountsOut[i];
    }


    //* If everything passes update the state

    intermidiateRoots[0] === initialRoot;

    component updateState = MultiNoteUpdate(n,k);
    updateState.intermidiateRoots[0] <== intermidiateRoots[0];

    for (var s=0; s<n;s++){
        // Taker transaction input and output notes
        updateState.Ko_in[s][0] <== notesIn[s][1];
        updateState.Ko_in[s][1] <== notesIn[s][2];
        updateState.token_in[s] <== notesIn[s][3];
        updateState.commitment_in[s] <== notesIn[s][4];

        updateState.Ko_out[s][0] <== notesOut[s][1];
        updateState.Ko_out[s][1] <== notesOut[s][2];
        updateState.token_out[s] <== notesOut[s][3];
        updateState.commitment_out[s] <== notesOut[s][4];

        updateState.intermidiateRoots[s+1] <== intermidiateRoots[s+1];

        for (var j=0; j<k; j++){
            updateState.paths2rootPos[s][j] <== paths2rootPos[s][j];
            updateState.paths2root[s][j] <== paths2root[s][j];
        }
    }

    updatedRoot <== updateState.newComputedRoot;
}   

// component main = noteTransaction(3,4);