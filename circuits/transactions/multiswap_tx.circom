include "./swap_tx.circom";
include "../existence_checks/multi_note_update.circom";

template MultiSwapTransaction(numSwaps, n, k){
    // numSwaps is the number of swaps to be performed
    // n is the number of notes per transaction
    // k is the depth of the note tree

    //* State update Inputs
    signal input initialRoot[numSwaps];
    signal input intermidiateRoots_A[numSwaps][n+1];
    signal input paths2rootPos_A[numSwaps][n][k];
    signal input paths2root_A[numSwaps][n][k];

    signal input intermidiateRoots_B[numSwaps][n+1];
    signal input paths2rootPos_B[numSwaps][n][k];
    signal input paths2root_B[numSwaps][n][k];

    //* Taker transaction (denoted by A) ==========================================
    signal input notesIn_A[numSwaps][n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input notesOut_A[numSwaps][n][5];
    signal input amountsIn_A[numSwaps][n];
    signal input amountsOut_A[numSwaps][n];
    signal input blindingsIn_A[numSwaps][n];
    signal input blindingsOut_A[numSwaps][n];
    signal input tokenSpent_A[numSwaps];
    signal input tokenSpentPrice_A[numSwaps];
    signal input tokenReceived_A[numSwaps];
    signal input tokenReceivedPrice_A[numSwaps];
    signal input returnAddressSig_A[numSwaps][2];
    signal input signature_A[numSwaps][1 + n];  


    //* Maker transaction (denoted by B) ==========================================
    signal input notesIn_B[numSwaps][n][5];   // note = [index, Kx, Ky, token, Comm]
    signal input notesOut_B[numSwaps][n][5];
    signal input amountsIn_B[numSwaps][n];
    signal input amountsOut_B[numSwaps][n];
    signal input blindingsIn_B[numSwaps][n];
    signal input blindingsOut_B[numSwaps][n];
    signal input tokenSpent_B[numSwaps];
    signal input tokenSpentPrice_B[numSwaps];
    signal input tokenReceived_B[numSwaps];
    signal input tokenReceivedPrice_B[numSwaps];
    signal input returnAddressSig_B[numSwaps][2]; 
    signal input signature_B[numSwaps][1 + n];

    
    signal output newRoot;


    component swapTxs[numSwaps];
    component updateState[numSwaps];
    for (var i=0; i<numSwaps; i++) {

        swapTxs[i] = SwapTransaction(n, k);
        //* Taker transaction (denoted by A) ==================
        // Loops over all input notes for the taker transaction
        for (var j=0; j<n; j++) {
            for (var k=0; k<5; k++) {
                swapTxs[i].notesIn_A[j][k] <== notesIn_A[i][j][k];
            }
            swapTxs[i].amountsIn_A[j] <== amountsIn_A[i][j];
            swapTxs[i].blindingsIn_A[j] <== blindingsIn_A[i][j];
        }

        // Loops over all output notes for the taker transcation
        for (var j=0; j<n; j++) {
            for (var k=0; k<5; k++) {
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
        for (var j=0; j<n; j++) {
            swapTxs[i].signature_A[j+1] <== signature_A[i][j+1];
        }
        

        //* Maker transaction (denoted by B) ==================
        // Loops over all input notes for the maker transaction
        for (var j=0; j<n; j++) {
            for (var k=0; k<5; k++) {
                swapTxs[i].notesIn_B[j][k] <== notesIn_B[i][j][k];
            }
            swapTxs[i].amountsIn_B[j] <== amountsIn_B[i][j];
            swapTxs[i].blindingsIn_B[j] <== blindingsIn_B[i][j];
        }

        // Loops over all output notes for the maker transcation
        for (var j=0; j<n; j++) {
            for (var k=0; k<5; k++) {
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
        for (var j=0; j<n; j++) {
            swapTxs[i].signature_B[j+1] <== signature_B[i][j+1];
        }

        //* State update inputs (merkle tree paths) ==================

        swapTxs[i].initialRoot <== initialRoot[i];
        swapTxs[i].intermidiateRoots_A[0] <== intermidiateRoots_A[i][0];
        for (var j=0; j<n; j++) {
            swapTxs[i].intermidiateRoots_A[j+1] <== intermidiateRoots_A[i][j+1];
            for (var s=0; s<k; s++) {
                swapTxs[i].paths2rootPos_A[j][s] <== paths2rootPos_A[i][j][s];
                swapTxs[i].paths2root_A[j][s] <== paths2root_A[i][j][s];
            }
        }

        swapTxs[i].intermidiateRoots_B[0] <== intermidiateRoots_B[i][0];
        for (var j=0; j<n; j++) {
            swapTxs[i].intermidiateRoots_B[j+1] <== intermidiateRoots_B[i][j+1];
            for (var s=0; s<k; s++) {
                swapTxs[i].paths2rootPos_B[j][s] <== paths2rootPos_B[i][j][s];
                swapTxs[i].paths2root_B[j][s] <== paths2root_B[i][j][s];
            }
        }

    }

}
component main = MultiSwapTransaction(1,3, 4);