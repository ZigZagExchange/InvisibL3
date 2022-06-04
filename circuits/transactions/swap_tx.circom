include "./note_transaction.circom";
include "../helpers/verify_swap_quotes.circom";

template SwapTransaction(n, k){
    // n is the number of notes to be swapped
    // all 4 should be the same change it later

    signal input notesOut_A[n][6];
    signal input notesOut_B[n][6];

    //* Taker transaction (denoted by A) ==========================================
    signal input notesIn_A[n][6];   // note = [index, Kx, Ky, token, Cx, Cy]
    signal input pseudoComms_A[n][2];
    signal input pos_A[n];
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
    takerTranscation.Ko[0] <== notesOut_B[0][1];
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
        takerTranscation.notesIn[i][5] <== notesIn_A[i][5];

        takerTranscation.pseudoComms[i][0] <== pseudoComms_A[i][0];
        takerTranscation.pseudoComms[i][1] <== pseudoComms_A[i][1];
        
        takerTranscation.pos[i] <== pos_A[i];
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
        takerTranscation.notesOut[i][5] <== notesOut_A[i][5];

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
    signal input notesIn_B[n][6];   // note = [index, Kx, Ky, token, Cx, Cy]
    signal input pseudoComms_B[n][2];
    signal input pos_B[n];
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

    component makerTransaction = noteTransaction(n, k);
    makerTransaction.tokenSpent <== tokenSpent_B;
    makerTransaction.tokenSpentPrice <== tokenSpentPrice_B;
    makerTransaction.tokenReceived <== tokenReceived_B;
    makerTransaction.tokenReceivedPrice <== tokenReceivedPrice_B;
    makerTransaction.Ko[0] <== notesOut_A[0][1];
    makerTransaction.Ko[1] <== notesOut_A[0][2];
    makerTransaction.returnAddressSig[0] <== returnAddressSig_B[0];
    makerTransaction.returnAddressSig[1] <== returnAddressSig_B[1];
    makerTransaction.signature[0] <== signature_B[0];


    for (var i=0; i<n; i++) {
        makerTransaction.notesIn[i][0] <== notesIn_B[i][0];
        makerTransaction.notesIn[i][1] <== notesIn_B[i][1];
        makerTransaction.notesIn[i][2] <== notesIn_B[i][2];
        makerTransaction.notesIn[i][3] <== notesIn_B[i][3];
        makerTransaction.notesIn[i][4] <== notesIn_B[i][4];
        makerTransaction.notesIn[i][5] <== notesIn_B[i][5];

        makerTransaction.pseudoComms[i][0] <== pseudoComms_B[i][0];
        makerTransaction.pseudoComms[i][1] <== pseudoComms_B[i][1];
        
        makerTransaction.pos[i] <== pos_B[i];
        makerTransaction.amountsIn[i] <== amountsIn_B[i];
        makerTransaction.blindingsIn[i] <== blindingsIn_B[i];
        makerTransaction.signature[i+1] <== signature_B[i+1];
    }

    for (var i=0; i<n; i++) {
        makerTransaction.notesOut[i][0] <== notesOut_B[i][0];
        makerTransaction.notesOut[i][1] <== notesOut_B[i][1];
        makerTransaction.notesOut[i][2] <== notesOut_B[i][2];
        makerTransaction.notesOut[i][3] <== notesOut_B[i][3];
        makerTransaction.notesOut[i][4] <== notesOut_B[i][4];
        makerTransaction.notesOut[i][5] <== notesOut_B[i][5];

        makerTransaction.amountsOut[i] <== amountsOut_B[i];
        makerTransaction.blindingsOut[i] <== blindingsOut_B[i];
    }


    // makerTranscation.initialRoot <== takerTranscation.updatedRoot;
    // makerTranscation.intermidiateRoots[0] <== intermidiateRoots_B[0];
    // for (var i=0; i<n; i++) {
    //     makerTranscation.intermidiateRoots[i+1] <== intermidiateRoots_B[i+1];
    //     for (var j=0; j<k; j++) {
    //         makerTranscation.paths2root[i][j] <== paths2root_B[i][j];
    //         makerTranscation.paths2rootPos[i][j] <== paths2rootPos_B[i][j];
    //     }
    // }
    

    //* Verify swap quotes ========================================================
    
    component verifySwap = VerifySwapQuotes();
    verifySwap.amountX <== amountsOut_A[0];
    verifySwap.amountY <== amountsOut_B[0];
    verifySwap.XPrice <== tokenSpentPrice_A;
    verifySwap.YPrice <== tokenReceivedPrice_A;

    
}


component main = SwapTransaction(5,4);








