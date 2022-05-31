include "../../circomlib/circuits/escalarmulany.circom";
include "../../circomlib/circuits/bitify.circom";
include "../../circomlib/circuits/babyjub.circom";
include "../../circomlib/circuits/poseidon.circom";

include "../helpers/PointSwitcher.circom";

template CInput() {
    signal input K[2];
    signal input C_prev[2];
    signal input C_new[2];
    signal input pos;
    signal input m;  // tx_hash
    signal input c;   
    signal input rs;

    signal output out[2];

    var GENERATOR[2] = [
        995203441582195749578291179787384436505546430278305826713579947235728471134,
        5472060717959818805561601436314318772137091100104008585924551046643952123905
        ];

    // convert c and r to bits
    component c2bits = Num2Bits_strict();
    c2bits.in <== c;
    component r2bits = Num2Bits_strict();
    r2bits.in <== rs;


    // Z from C_prev and C_new and pos
    component switcher = PointSwitcher();
    switcher.sel <== pos;
    switcher.Lx <== C_prev[0];
    switcher.Ly <== C_prev[1];
    switcher.Rx <== C_new[0];
    switcher.Ry <== C_new[1];

    component ecAddZ = BabyAdd();
    ecAddZ.x1 <== switcher.outLx;
    ecAddZ.y1 <== switcher.outLy;
    ecAddZ.x2 <== -switcher.outRx;  
    ecAddZ.y2 <== switcher.outRy;

    // escalarmul ri*G
    component mulGri = EscalarMulAny(254);
    for (var i=0; i<254; i++) {
        mulGri.e[i] <== r2bits.out[i];
    }
    mulGri.p[0] <== GENERATOR[0];
    mulGri.p[1] <== GENERATOR[1];

    // escalarmul c*Z, just the first 128 bits of c and ith Z
    component mulZc = EscalarMulAny(128);
    for (var i=0; i<128; i++) {
        mulZc.e[i] <== c2bits.out[i];
    }
    mulZc.p[0] <== ecAddZ.xout;
    mulZc.p[1] <== ecAddZ.yout;

    // c_input =  riG - K - cZ 
    component ecAdd1 = BabyAdd();
    component ecAdd2 = BabyAdd();

    // riG - Ki
    ecAdd1.x1 <== mulGri.out[0];
    ecAdd1.y1 <== mulGri.out[1];
    ecAdd1.x2 <== -K[0];  // - if sub + if add
    ecAdd1.y2 <== K[1];

    // (riG-Ki) - cZ
    ecAdd2.x1 <== ecAdd1.xout;
    ecAdd2.y1 <== ecAdd1.yout;
    ecAdd2.x2 <== -mulZc.out[0];  // - if sub + if add
    ecAdd2.y2 <== mulZc.out[1];

    out[0] <== ecAdd2.xout;
    out[1] <== ecAdd2.yout;

}


// component main { public [ K, C_prev, C_new, pos, m, c, rs ] } = CInput();

//TODO try inputing c as bits to reduce num of gates 
