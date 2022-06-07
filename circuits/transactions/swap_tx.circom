include "./note_transaction.circom";
include "../helpers/verify_swap_quotes.circom";

template SwapTransaction(n, k){
    // n is the number of notes to be swapped
    // all 4 should be the same change it later

    signal input notesOut_A[n][5];
    signal input notesOut_B[n][5];

    //* Taker transaction (denoted by A) ==========================================
    signal input notesIn_A[n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input amountsIn_A[n];
    signal input amountsOut_A[n];
    signal input blindingsIn_A[n];
    signal input blindingsOut_A[n];
    signal input tokenSpent_A;
    signal input tokenSpentPrice_A;
    signal input tokenReceived_A;
    signal input tokenReceivedPrice_A;

    signal input returnAddressSig_A[2];   // [c,r]  
    signal input signature_A[1 + n];    // [c, r]  

    signal input initialRoot;
    signal input intermidiateRoots_A[n+1];
    signal input paths2rootPos_A[n][k];
    signal input paths2root_A[n][k];


    component takerTranscation = noteTransaction(n, k);
    takerTranscation.tokenSpent <== tokenSpent_A;
    takerTranscation.tokenSpentPrice <== tokenSpentPrice_A;
    takerTranscation.tokenReceived <== tokenReceived_A;
    takerTranscation.tokenReceivedPrice <== tokenReceivedPrice_A;
    takerTranscation.Ko[0] <== notesOut_B[0][1];  // This is the address of maker tx notesOut[0]
    takerTranscation.Ko[1] <== notesOut_B[0][2];
    takerTranscation.returnAddressSig[0] <== returnAddressSig_A[0];
    takerTranscation.returnAddressSig[1] <== returnAddressSig_A[1];
    takerTranscation.signature[0] <== signature_A[0];

    for (var i=0; i<n; i++) {
        takerTranscation.notesIn[i][0] <== notesIn_A[i][0];
        takerTranscation.notesIn[i][1] <== notesIn_A[i][1];
        takerTranscation.notesIn[i][2] <== notesIn_A[i][2];
        takerTranscation.notesIn[i][3] <== notesIn_A[i][3];
        takerTranscation.notesIn[i][4] <== notesIn_A[i][4];

        takerTranscation.amountsIn[i] <== amountsIn_A[i];
        takerTranscation.blindingsIn[i] <== blindingsIn_A[i];
        takerTranscation.signature[i+1] <== signature_A[i+1];
    }

    for (var i=0; i<n; i++) {
        takerTranscation.notesOut[i][0] <== notesOut_A[i][0];
        takerTranscation.notesOut[i][1] <== notesOut_A[i][1];
        takerTranscation.notesOut[i][2] <== notesOut_A[i][2];
        takerTranscation.notesOut[i][3] <== notesOut_A[i][3];
        takerTranscation.notesOut[i][4] <== notesOut_A[i][4];

        takerTranscation.amountsOut[i] <== amountsOut_A[i];
        takerTranscation.blindingsOut[i] <== blindingsOut_A[i];
    }

    takerTranscation.initialRoot <== initialRoot;
    takerTranscation.intermidiateRoots[0] <== intermidiateRoots_A[0];
    for (var i=0; i<n; i++) {
        takerTranscation.intermidiateRoots[i+1] <== intermidiateRoots_A[i+1];
        for (var j=0; j<k; j++) {
            takerTranscation.paths2root[i][j] <== paths2root_A[i][j];
            takerTranscation.paths2rootPos[i][j] <== paths2rootPos_A[i][j];
        }
    }



    //* Maker transaction (denoted by B) ==========================================
    signal input notesIn_B[n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input amountsIn_B[n];
    signal input amountsOut_B[n];
    signal input blindingsIn_B[n];
    signal input blindingsOut_B[n];
    signal input tokenSpent_B;
    signal input tokenSpentPrice_B;
    signal input tokenReceived_B;
    signal input tokenReceivedPrice_B;

    signal input returnAddressSig_B[2];   // [c,r]  
    signal input signature_B[1 + n];    // [c, r]  

    signal input intermidiateRoots_B[n+1];
    signal input paths2rootPos_B[n][k];
    signal input paths2root_B[n][k];

    component makerTranscation = noteTransaction(n, k);
    makerTranscation.tokenSpent <== tokenSpent_B;
    makerTranscation.tokenSpentPrice <== tokenSpentPrice_B;
    makerTranscation.tokenReceived <== tokenReceived_B;
    makerTranscation.tokenReceivedPrice <== tokenReceivedPrice_B;
    makerTranscation.Ko[0] <== notesOut_A[0][1];   // This is the address of taker tx notesOut[0]
    makerTranscation.Ko[1] <== notesOut_A[0][2];
    makerTranscation.returnAddressSig[0] <== returnAddressSig_B[0];
    makerTranscation.returnAddressSig[1] <== returnAddressSig_B[1];
    makerTranscation.signature[0] <== signature_B[0];

    for (var i=0; i<n; i++) {
        makerTranscation.notesIn[i][0] <== notesIn_B[i][0];
        makerTranscation.notesIn[i][1] <== notesIn_B[i][1];
        makerTranscation.notesIn[i][2] <== notesIn_B[i][2];
        makerTranscation.notesIn[i][3] <== notesIn_B[i][3];
        makerTranscation.notesIn[i][4] <== notesIn_B[i][4];

        makerTranscation.amountsIn[i] <== amountsIn_B[i];
        makerTranscation.blindingsIn[i] <== blindingsIn_B[i];
        makerTranscation.signature[i+1] <== signature_B[i+1];
    }

    for (var i=0; i<n; i++) {
        makerTranscation.notesOut[i][0] <== notesOut_B[i][0];
        makerTranscation.notesOut[i][1] <== notesOut_B[i][1];
        makerTranscation.notesOut[i][2] <== notesOut_B[i][2];
        makerTranscation.notesOut[i][3] <== notesOut_B[i][3];
        makerTranscation.notesOut[i][4] <== notesOut_B[i][4];

        makerTranscation.amountsOut[i] <== amountsOut_B[i];
        makerTranscation.blindingsOut[i] <== blindingsOut_B[i];
    }

    makerTranscation.initialRoot <== takerTranscation.updatedRoot;
    makerTranscation.intermidiateRoots[0] <== intermidiateRoots_B[0];
    for (var i=0; i<n; i++) {
        makerTranscation.intermidiateRoots[i+1] <== intermidiateRoots_B[i+1];
        for (var j=0; j<k; j++) {
            makerTranscation.paths2root[i][j] <== paths2root_B[i][j];
            makerTranscation.paths2rootPos[i][j] <== paths2rootPos_B[i][j];
        }
    }

    

    //* Verify swap quotes ========================================================
    
    component verifySwap = VerifySwapQuotes();
    verifySwap.amountX <== amountsOut_A[0];
    verifySwap.amountY <== amountsOut_B[0];
    verifySwap.XPrice <== tokenSpentPrice_A;
    verifySwap.YPrice <== tokenReceivedPrice_A;
 
}


// component main = SwapTransaction(3,4);








