const Secp256k1 = require("@enumatech/secp256k1-js");
const bigInt = require("big-integer");
const { pedersen, computeHashOnElements } = require("starknet/utils/hash");
const { Note, split, splitUint256 } = require("../src/notes/noteUtils");
// const randomBigInt = require("random-bigint");

function randomBigInt(x) {
  return 1233287532659238423085732589324032498632532523896536248n;
}

const P = 2n ** 251n + 2n ** 192n + 1n;

//* =====================================================================

function test_signing() {
  let k1 = randomBigInt(250);
  let k2 = randomBigInt(250);
  let k3 = randomBigInt(250);

  let K1 = Secp256k1.mulG(Secp256k1.uint256(k1));
  let K2 = Secp256k1.mulG(Secp256k1.uint256(k2));
  let K3 = Secp256k1.mulG(Secp256k1.uint256(k3));

  let k0s = [k1, k2, k3];
  let addresses = [K1, K2, K3];

  let tx_hash = bigInt(
    "12340932757325909348239752395238403920583980284032842"
  ).value;

  let sig = signTx(k0s, tx_hash);

  verifySig(sig, addresses, tx_hash);

  //

  console.log(
    ' "addresses": ',
    addresses.map((X) => [split(X[0]), split(X[1])])
  );
  console.log(',"tx_hash": ', tx_hash);
  console.log(',"signature": ', sig);
}

function test_ret_addr_sig() {
  let hash2 = bigInt(
    "2375236583914823857326579304028357926532908423958324683543204"
  ).value;

  let ret_ko = randomBigInt(250);
  let ret_K0 = Secp256k1.mulG(Secp256k1.uint256(ret_ko));

  let retAddrSig = signReturnAddressSig(ret_ko, hash2);
  verifyRetAddrSig(retAddrSig, ret_K0, hash2);

  console.log(' "ret_addr": ', [split(ret_K0[0]), split(ret_K0[1])]);
  console.log(',"ret_hash": ', hash2);
  console.log(',"ret_sig": ', retAddrSig);
}

//

function test_tx_hashing() {
  let comms_in = [
    1111111111111111111111111111111n,
    22222222222222222222222222222222n,
    3333333333333333333333333333333n,
  ];
  let addresses_in = [
    7346184981427238947983274983268329329856239857324029374325n,
    89263457942380597239856909483290320953728583290324823959032n,
    109480101934702738162097432868092478230956919402573280750923n,
  ];
  let tokens_in = [0, 0, 0];

  let comm_out = [
    555555555555555555555555555555555555555555n,
    666666666666666666666666666666666666666666666n,
    7777777777777777777777777777777777777777777n,
  ];
  let addresses_out = [
    [
      734618498142723894734635757476832932985623985257572645266264n,
      734618498142723894734635757476832932985623985257572645266264n,
    ],
    [
      4256463463454253453434546909483290320953728583290324823959032n,
      734618498142723894734635757476832932985623985257572645266264n,
    ],
    [
      10948010198932686432759837298533725328958329532892573280750923n,
      734618498142723894734635757476832932985623985257572645266264n,
    ],
  ];
  let token = 0;
  let tokenPrice = 2500;

  let notes_in = [];
  let notes_out = [];
  for (let i = 0; i < 3; i++) {
    let noteIn = new Note(addresses_in[i], comms_in[i], token);
    let noteOut = new Note(addresses_out[i], comm_out[i], token);

    notes_in.push(noteIn);
    notes_out.push(noteOut);
  }

  let dummy_ret_sig_r = 217461287469187249698412740184296372490128498634723409n;

  let tx_hash = hashTransaction(
    notes_in,
    notes_out,
    token,
    tokenPrice,
    dummy_ret_sig_r
  );

  console.log("tx_hash: ", tx_hash);
}

test_tx_hashing();

//

//

//

//

//

//

//

function signTx(priv_keys, tx_hash) {
  let alphas = [];
  let c_input = [tx_hash];
  //?  c = H(tx_hash, -aG)
  for (let i = 0; i < priv_keys.length; i++) {
    // Could reveal something about the private key if alpha is to small*
    const alpha = randomBigInt(250);
    const aG = Secp256k1.mulG(Secp256k1.uint256(alpha));

    // console.log("c_input_i", aG.toString());
    let aGx = splitUint256(aG[0].toString());
    const c_input_i = pedersen([aGx.high, aGx.low]);

    c_input.push(c_input_i);
    alphas.push(alpha);
  }

  let c = BigInt(computeHashOnElements(c_input));
  let rs = [c];

  let c_split = splitUint256(c);
  let c_trimmed = c_split.high + c_split.low;

  //? ri = a + k - c  (where c is trimmed)
  for (let i = 0; i < alphas.length; i++) {
    let ri = bigInt(alphas[i]).add(priv_keys[i]).subtract(c_trimmed).value;

    if (ri >= P || ri < 0) {
      console.log("WRONG ri", ri);
      return signTx(tx_hash);
    }

    rs.push(ri);
  }

  return rs;
}

function verifySig(signature, addresses, tx_hash) {
  let c = signature[0];
  let rs = signature.slice(1);

  let c_input = [tx_hash];

  let c_split = splitUint256(c);
  let c_trimmed = c_split.high + c_split.low;
  let cG = Secp256k1.mulG(Secp256k1.uint256(c_trimmed));
  cG = Secp256k1.AtoJ(cG[0], cG[1]);

  //?  c = H(m, rG - K + c*G)     (where c is trimmed)
  for (let i = 0; i < rs.length; i++) {
    let riG = Secp256k1.mulG(Secp256k1.uint256(rs[i]));
    riG = Secp256k1.AtoJ(riG[0], riG[1]);
    let riG_plus_cG = Secp256k1.ecadd(riG, cG);
    let Ki_neg = Secp256k1.negPoint(addresses[i]);
    Ki_neg = Secp256k1.AtoJ(Ki_neg[0], Ki_neg[1]);
    let c_input_i = Secp256k1.ecadd(riG_plus_cG, Ki_neg);
    c_input_i = Secp256k1.JtoA(c_input_i);

    let highLow = splitUint256(c_input_i[0].toString());
    c_input.push(pedersen([highLow.high, highLow.low]));
  }

  let c_prime = BigInt(computeHashOnElements(c_input), 16);

  if (c_prime !== c) {
    throw "signature verification failed";
  } else {
    console.log("signature verified");
  }
}

function signReturnAddressSig(priv_key, hash) {
  const alpha = randomBigInt(250);
  const aG = Secp256k1.mulG(Secp256k1.uint256(alpha));

  let aGx = splitUint256(aG[0].toString());
  const c_input = pedersen([aGx.high, aGx.low]);

  const c = BigInt(pedersen([hash, c_input]), 16);

  let c_split = splitUint256(c);
  let c_trimmed = c_split.high + c_split.low;

  let sig = [c];

  const r = bigInt(alpha).add(priv_key).subtract(c_trimmed).value;

  if (r >= P || r < 0) {
    return signTx(priv_key, hash);
  }

  sig.push(r);

  return sig;
}

function verifyRetAddrSig(signature, address, hash) {
  let c = signature[0];
  let r = signature[1];

  let c_split = splitUint256(c);
  let c_trimmed = c_split.high + c_split.low;

  let cG = Secp256k1.mulG(Secp256k1.uint256(c_trimmed));
  cG = Secp256k1.AtoJ(cG[0], cG[1]);

  //?  c = H(m, rG - K + c*G)     (where c is trimmed)
  let rG = Secp256k1.mulG(Secp256k1.uint256(r));
  rG = Secp256k1.AtoJ(rG[0], rG[1]);
  let rG_plus_cG = Secp256k1.ecadd(rG, cG);
  let K_neg = Secp256k1.negPoint(address);
  K_neg = Secp256k1.AtoJ(K_neg[0], K_neg[1]);
  let c_input = Secp256k1.ecadd(rG_plus_cG, K_neg);
  c_input = Secp256k1.JtoA(c_input);

  let highLow = splitUint256(c_input[0].toString());
  let c_hash = BigInt(pedersen([highLow.high, highLow.low]), 16);

  let c_prime = BigInt(pedersen([hash, c_hash]), 16);

  if (c_prime !== c) {
    throw "signature verification failed";
  } else {
    console.log("signature verified");
  }
}

function hashPrivInputs(tokenReceived, tokenReceivedPrice) {
  return pedersen([tokenReceived, tokenReceivedPrice]);
}

function hashTransaction(
  notesIn,
  notesOut,
  tokenSpent,
  tokenSpentPrice,
  return_sig_r
) {
  let hashes_in = [];
  for (let i = 0; i < notesIn.length; i++) {
    const hash = notesIn[i].hash;

    if (notesIn[i].token !== tokenSpent) {
      throw "token missmatch";
    }
    hashes_in.push(hash);
  }

  // let in_notes_hash = BigInt(computeHashOnElements(hashes_in), 16);

  // ===================================================
  let hashes_out = [];
  for (let i = 0; i < notesOut.length; i++) {
    const hash = notesOut[i].hash;

    if (notesOut[i].token !== tokenSpent) {
      throw "token missmatch";
    }

    hashes_out.push(hash);
  }
  // let out_notes_hash = BigInt(computeHashOnElements(hashes_out), 16);
  // ===================================================

  let hash_input = hashes_in
    .concat(hashes_out)
    .concat([tokenSpent, tokenSpentPrice, return_sig_r]);

  return BigInt(computeHashOnElements(hash_input), 16);
}

module.exports = {
  hashTransaction,
};
