template VerifySwapQuotes(){
    signal input amountX;
    signal input amountY;
    signal input XPrice;
    signal input YPrice;

    signal xPx <== amountX * XPrice;
    signal yPy <== amountY * YPrice;
    
    signal diff <== xPx - yPy;

    signal rem <-- diff * 10**8 \ xPx;

    rem === 0;

}