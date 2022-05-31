template PointSwitcher() {
    signal input sel;
    signal input Lx;
    signal input Ly;
    signal input Rx;
    signal input Ry;
    signal output outLx;
    signal output outLy;
    signal output outRx;
    signal output outRy;

    signal aux1;
    signal aux2;

    //TODO: Might be possible with just one multiplication 
    aux1 <== (Rx-Lx)*sel;    
    outLx <==  aux1 + Lx;
    outRx <== -aux1 + Rx;
    
    aux2 <== (Ry-Ly)*sel;
    outLy <==  aux2 + Ly;
    outRy <== -aux2 + Ry;

}