include "../../circomlib/circuits/escalarmulany.circom";
include "../../circomlib/circuits/bitify.circom";
include "../../circomlib/circuits/babyjub.circom";

template Commitment() {
    signal input amount;
    signal input blinding;

    signal output Cx;
    signal output Cy;

    // H Point
    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
        ];
    // G Point
    var GENERATOR[2] = [
        995203441582195749578291179787384436505546430278305826713579947235728471134,
        5472060717959818805561601436314318772137091100104008585924551046643952123905
        ];


    component a2bits = Num2Bits_strict();
    a2bits.in <== amount;

    component x2bits = Num2Bits_strict();
    x2bits.in <== blinding;

    // H * a
    component mulHa = EscalarMulAny(254);
    for (var i=0; i<254; i++) {
        mulHa.e[i] <== a2bits.out[i];
    }
    mulHa.p[0] <== BASE8[0];
    mulHa.p[1] <== BASE8[1];

    // G * x
    component mulGx = EscalarMulAny(254);
    for (var i=0; i<254; i++) {
        mulGx.e[i] <== x2bits.out[i];
    }
    mulGx.p[0] <== GENERATOR[0];
    mulGx.p[1] <== GENERATOR[1];

    component ecAdd = BabyAdd();

    ecAdd.x1 <== mulHa.out[0];
    ecAdd.y1 <== mulHa.out[1];
    ecAdd.x2 <== mulGx.out[0];  // - if sub + if add
    ecAdd.y2 <== mulGx.out[1];

    Cx <== ecAdd.xout;
    Cy <== ecAdd.yout;

}

// component main { public [ a ] } = Commitment();
