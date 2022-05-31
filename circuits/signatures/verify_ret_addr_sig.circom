include "../../circomlib/circuits/escalarmulany.circom";
include "../../circomlib/circuits/babyjub.circom";
include "../../circomlib/circuits/poseidon.circom";

include "./ret_addr_cInput.circom";

template VerifyRetAddrSig() {
    signal input c;
    signal input r;
    signal input tokenReceived;
    signal input tokenReceivedPrice;
    signal input Ko[2];  // return address -> should match the address of the first output note

    // G Point
    var GENERATOR[2] = [
        995203441582195749578291179787384436505546430278305826713579947235728471134,
        5472060717959818805561601436314318772137091100104008585924551046643952123905
        ];

    
    component inputsHash = Poseidon(2);
    inputsHash.inputs[0] <== tokenReceived;
    inputsHash.inputs[1] <== tokenReceivedPrice;


    component cInput = RetAddrCInput();

    // cInput = rG - Ko - cG
    cInput.K[0] <== Ko[0];
    cInput.K[1] <== Ko[1];
    cInput.m <== inputsHash.out;
    cInput.c <== c;
    cInput.r <== r;

    // c_prime = H(tx_hash, cInput)
    component hash = Poseidon(3);
    hash.inputs[0] <== inputsHash.out;
    hash.inputs[1] <== cInput.out[0];
    hash.inputs[2] <== cInput.out[1];

    // c_prime === c 
    hash.out === c;

}

// component main { public [ c, r ] } = VerifyRetAddrSig();

