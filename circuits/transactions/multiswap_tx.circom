include "./swap_tx.circom";


template MultiSwapTransaction(numSwaps, n_A, m_A, n_B, m_B){


    //* Taker transaction (denoted by A) ==========================================
    signal input notesIn_A[numSwaps][n_A][6];   // note = [index, Kx, Ky, token, Cx, Cy]
    signal input pseudoComms_A[numSwaps][n_A][2];
    signal input pos_A[numSwaps][n_A];
    signal input notesOut_A[numSwaps][m_A][6];
    signal input amountsIn_A[numSwaps][n_A];
    signal input amountsOut_A[numSwaps][m_A];
    signal input blindingsIn_A[numSwaps][n_A];
    signal input blindingsOut_A[numSwaps][m_A];
    signal input tokenSpent_A[numSwaps];
    signal input tokenSpentPrice_A[numSwaps];
    signal input tokenReceived_A[numSwaps];
    signal input tokenReceivedPrice_A[numSwaps];
    signal input returnAddressSig_A[numSwaps][2];
    signal input signature_A[numSwaps][1 + n_A];  


    //* Maker transaction (denoted by B) ==========================================
    signal input notesIn_B[numSwaps][n_B][6];   // note = [index, Kx, Ky, token, Cx, Cy]
    signal input pseudoComms_B[numSwaps][n_B][2];
    signal input pos_B[numSwaps][n_B];
    signal input notesOut_B[numSwaps][m_B][6];
    signal input amountsIn_B[numSwaps][n_B];
    signal input amountsOut_B[numSwaps][m_B];
    signal input blindingsIn_B[numSwaps][n_B];
    signal input blindingsOut_B[numSwaps][m_B];
    signal input tokenSpent_B[numSwaps];
    signal input tokenSpentPrice_B[numSwaps];
    signal input tokenReceived_B[numSwaps];
    signal input tokenReceivedPrice_B[numSwaps];
    signal input returnAddressSig_B[numSwaps][2]; 
    signal input signature_B[numSwaps][1 + n_B];


    component swapTxs[numSwaps];
    for (var i=0; i<numSwaps; i++) {

        swapTxs[i] = SwapTransaction(n_A, m_A, n_B, m_B);
        //* Taker transaction (denoted by A) ==================
        // Loops over all input notes for the taker transaction
        for (var j=0; j<n_A; j++) {
            for (var k=0; k<6; k++) {
                swapTxs[i].notesIn_A[j][k] <== notesIn_A[i][j][k];
            }
            swapTxs[i].pseudoComms_A[j][0] <== pseudoComms_A[i][j][0];
            swapTxs[i].pseudoComms_A[j][1] <== pseudoComms_A[i][j][1];
            swapTxs[i].pos_A[j] <== pos_A[i][j];
            swapTxs[i].amountsIn_A[j] <== amountsIn_A[i][j];
            swapTxs[i].blindingsIn_A[j] <== blindingsIn_A[i][j];
        }

        // Loops over all output notes for the taker transcation
        for (var j=0; j<m_A; j++) {
            for (var k=0; k<6; k++) {
                swapTxs[i].notesOut_A[j][k] <== notesOut_A[i][j][k];
            }
            swapTxs[i].amountsOut_A[j] <== amountsOut_A[i][j];
            swapTxs[i].blindingsOut_A[j] <== blindingsOut_A[i][j];
        }


        swapTxs[i].tokenSpent_A <== tokenSpent_A[i];
        swapTxs[i].tokenSpentPrice_A <== tokenSpentPrice_A[i];
        swapTxs[i].tokenReceived_A <== tokenReceived_A[i];
        swapTxs[i].tokenReceivedPrice_A <== tokenReceivedPrice_A[i];
        swapTxs[i].returnAddressSig_A[0] <== returnAddressSig_A[i][0];
        swapTxs[i].returnAddressSig_A[1] <== returnAddressSig_A[i][1];

        swapTxs[i].signature_A[0] <== signature_A[i][0];
        for (var j=0; j<n_A; j++) {
            swapTxs[i].signature_A[j+1] <== signature_A[i][j+1];
        }
        

        //* Maker transaction (denoted by B) ==================
        // Loops over all input notes for the maker transaction
        for (var j=0; j<n_B; j++) {
            for (var k=0; k<6; k++) {
                swapTxs[i].notesIn_B[j][k] <== notesIn_B[i][j][k];
            }
            swapTxs[i].pseudoComms_B[j][0] <== pseudoComms_B[i][j][0];
            swapTxs[i].pseudoComms_B[j][1] <== pseudoComms_B[i][j][1];
            swapTxs[i].pos_B[j] <== pos_B[i][j];
            swapTxs[i].amountsIn_B[j] <== amountsIn_B[i][j];
            swapTxs[i].blindingsIn_B[j] <== blindingsIn_B[i][j];
        }

        // Loops over all output notes for the maker transcation
        for (var j=0; j<m_B; j++) {
            for (var k=0; k<6; k++) {
                swapTxs[i].notesOut_B[j][k] <== notesOut_B[i][j][k];
            }
            swapTxs[i].amountsOut_B[j] <== amountsOut_B[i][j];
            swapTxs[i].blindingsOut_B[j] <== blindingsOut_B[i][j];
        }


        swapTxs[i].tokenSpent_B <== tokenSpent_B[i];
        swapTxs[i].tokenSpentPrice_B <== tokenSpentPrice_B[i];
        swapTxs[i].tokenReceived_B <== tokenReceived_B[i];
        swapTxs[i].tokenReceivedPrice_B <== tokenReceivedPrice_B[i];
        swapTxs[i].returnAddressSig_B[0] <== returnAddressSig_B[i][0];
        swapTxs[i].returnAddressSig_B[1] <== returnAddressSig_B[i][1];

        swapTxs[i].signature_B[0] <== signature_B[i][0];
        for (var j=0; j<n_B; j++) {
            swapTxs[i].signature_B[j+1] <== signature_B[i][j+1];
        }

    }


}
component main = MultiSwapTransaction(3,5,5,5,5);