include "../../circomlib/circuits/babyjub.circom";

template SumPoints(n) {
    signal input C_in[n][2];  

    signal output sum[2];  // the sum point

    component addIn[n];

    addIn[0] = BabyAdd();
    addIn[0].x1 <== C_in[0][0];
    addIn[0].y1 <== C_in[0][1];
    addIn[0].x2 <== C_in[1][0];  // - if sub + if add
    addIn[0].y2 <== C_in[1][1];

    for (var i = 1; i < n-1; i++) {

        addIn[i] = BabyAdd();
        
        addIn[i].x1 <== addIn[i-1].xout;
        addIn[i].y1 <== addIn[i-1].yout;
        addIn[i].x2 <== C_in[i+1][0];
        addIn[i].y2 <== C_in[i+1][1];
    }

    sum[0] <== addIn[n-2].xout;
    sum[1] <== addIn[n-2].yout;
    
}


