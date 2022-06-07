include "../../circomlib/circuits/poseidon.circom";

template Commitment() {
    signal input amount;
    signal input blinding;

    signal output Comm;

    component hash = Poseidon(2);
    hash.inputs[0] <== amount;
    hash.inputs[1] <== blinding;

    Comm <== hash.out;
}

// component main { public [ a ] } = Commitment();
