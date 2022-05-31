include "../../circomlib/circuits/poseidon.circom";

include "./note_leaf.circom";

template AddressLeaf(n_notes) {

    assert(n_notes <= 11);

    signal input index;
    signal input pubkeyX;
    signal input pubkeyY;
    signal input note_idxs[n_notes]; 
    signal input note_tokens[n_notes];
    signal input note_comms[n_notes][2];

    signal output out;

    component addressLeaf = Poseidon(3 + n_notes);

    addressLeaf.inputs[0] <== index;
    addressLeaf.inputs[1] <== pubkeyX;
    addressLeaf.inputs[2] <== pubkeyY;

    component noteHashes[n_notes];
    for (var i=0; i<n_notes; i++) {

        noteHashes[i] = NoteLeaf();

        noteHashes[i].index <== note_idxs[i];
        noteHashes[i].token <== note_tokens[i];
        noteHashes[i].Cx <== note_comms[i][0];
        noteHashes[i].Cy <== note_comms[i][1];


        addressLeaf.inputs[i + 3] <== noteHashes[i].out;
    }


    out <== addressLeaf.out;
}

// component main { public [ index, pubkeyX, pubkeyY, note_comms ] } = AddressLeaf(3);
