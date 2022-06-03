template AddNoteBranch(k, l){
    // k is depth of address tree
    // l is depth of new notes tree branch (2 ** l)
    // the number of notes in the new branch is 2 ** l

    var LEVEL_l_ZERO_HASH = 11639279936732882067481942959776886328094524808167853630170211920973753368475;

    signal input Ko[n][2]; 
    signal input token[n];
    signal input commitment[n][2];


    signal input root;  // the root 
    signal input paths2rootPos[l];
    signal input paths2root[l];


    //Prove the existence of LEVEL_l_ZERO_HASH on level l
    component noteExistence = LeafExistence(l);
    noteExistence.leaf <== noteLeaf.out;
    noteExistence.root <== root;

    for (var s = 0; s < l; s++){
        noteExistence.paths2rootPos[s] <== paths2rootPos[s];
        noteExistence.paths2root[s] <== paths2root[s];
    }

}

// component main  = NoteExistence(4);

