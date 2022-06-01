const Note = require("../../src/notes/noteUtils").Note;

const txInputs = {
  notesIn: [
    [
      0,
      1414463055584249975401255287664006444991531772864589842606436631324803797829n,
      3576190135707767864261393218654241707601949798812616969215456467228622391342n,
      1,
      8335733946071834698883013585698612085557666739823460394434079211486843042517n,
      15686892433797900135714327927078751280485706850387618477540162903172310491300n,
    ],
  ],
  pseudoComms: [
    [
      12530196318792167978913396818257508533617123192144669546990626790194631060621n,
      6492952266178277534626528547938361300070434246823203094944912450171315838506n,
    ],
  ],
  pos: [1],
  notesOut: [
    [
      0,
      727633070800549199660756625430025559445577491715417070994469407397335168934n,
      8969482073994745989646499483515924597924306463384181226983111910408124871594n,
      1,
      6978042833519883794795793379220269140785503048432137034751203972879041243045n,
      6529617774211694273733074546057915712099593194258910702950618969401365828322n,
    ],
    [
      0,
      4664522176072200182869991843466823882227951723133875615539504484163435564852n,
      17758111371773129660572234268461712141223098438209534612646069463410754767175n,
      1,
      7091442067840263607596770844608492233037011048433323344940718114459206581724n,
      2281200571557234849128404440849489483617578232185288188375032721962454922680n,
    ],
    [
      0,
      11380713548171564468083585056514611217084774002874478243001336223815285820088n,
      5193658344260070480120513469247693179147973846309511004901367741493380238389n,
      1,
      962308794543494314864199809269689807189785440357909734984636811857631864281n,
      10310391762835266918004781281876458867333335602926754459197949413751430691165n,
    ],
  ],
  amountsIn: [422524000900n],
  amountsOut: [1534450000n, 15344500n, 420974206400n],
  blindingsIn: [113398076903969102566426825667700712n],
  blindingsOut: [
    1276607203306305937367492884618728566n,
    1000759621778768684955143009247101323n,
    1126903517287531754245723767531283545n,
  ],
  tokenSpent: 1,
  tokenSpentPrice: 2103540293n,
  tokenReceived: 2,
  tokenReceivedPrice: 30234045932n,
  Ko: [
    13059816953500762311906312386357263494459804028442072112684460509253615624503n,
    2980552948779669295768356845520663242041194802558674379886444324930999498768n,
  ],
  returnAddressSig: [
    16282152972143636502949459724228572627602551643182158978020045463939167206852n,
    17644536510680530177050617088048931087837303299087571358135903143447271715083n,
  ],
  signature: [
    3399910341544126396426927455067858696360205176821469681095093474870938700706n,
    6934176326063102626541049294395897097886132492281524176497559758353921127276n,
    0n,
    0n,
    0n,
    0n,
  ],
};

const returnAddressSigInputs = {
  c: txInputs.returnAddressSig[0],
  r: txInputs.returnAddressSig[1],
  tokenReceived: txInputs.tokenReceived,
  tokenReceivedPrice: txInputs.tokenReceivedPrice,
  Ko: txInputs.Ko,
};

const txHashInputs = {
  notesIn: [
    [
      0,
      1414463055584249975401255287664006444991531772864589842606436631324803797829n,
      3576190135707767864261393218654241707601949798812616969215456467228622391342n,
      1,
      8335733946071834698883013585698612085557666739823460394434079211486843042517n,
      15686892433797900135714327927078751280485706850387618477540162903172310491300n,
    ],
  ],
  notesOut: [
    [
      0,
      727633070800549199660756625430025559445577491715417070994469407397335168934n,
      8969482073994745989646499483515924597924306463384181226983111910408124871594n,
      1,
      6978042833519883794795793379220269140785503048432137034751203972879041243045n,
      6529617774211694273733074546057915712099593194258910702950618969401365828322n,
    ],
    [
      0,
      4664522176072200182869991843466823882227951723133875615539504484163435564852n,
      17758111371773129660572234268461712141223098438209534612646069463410754767175n,
      1,
      7091442067840263607596770844608492233037011048433323344940718114459206581724n,
      2281200571557234849128404440849489483617578232185288188375032721962454922680n,
    ],
    [
      0,
      11380713548171564468083585056514611217084774002874478243001336223815285820088n,
      5193658344260070480120513469247693179147973846309511004901367741493380238389n,
      1,
      962308794543494314864199809269689807189785440357909734984636811857631864281n,
      10310391762835266918004781281876458867333335602926754459197949413751430691165n,
    ],
  ],
  tokenSpent: 1,
  tokenSpentPrice: 2103540293n,
  retSigR:
    17644180327851530199811424285217838282587269771946665657919607767831841099379n,
};

const sumVerificationInputs = {
  amountsIn: txInputs.amountsIn,
  amountsOut: txInputs.amountsOut,
};

const verifySigInputs = {
  K: [
    [
      [
        1414463055584249975401255287664006444991531772864589842606436631324803797829n,
        3576190135707767864261393218654241707601949798812616969215456467228622391342n,
      ],
    ],
  ],
  C_prev: [
    [
      [
        8335733946071834698883013585698612085557666739823460394434079211486843042517n,
        15686892433797900135714327927078751280485706850387618477540162903172310491300n,
      ],
    ],
  ],
  C_new: [
    [
      12530196318792167978913396818257508533617123192144669546990626790194631060621n,
      6492952266178277534626528547938361300070434246823203094944912450171315838506n,
    ],
  ],
  pos: [1],
  m: 20773559451364977998936264254406444191192868464666259807316037295906105139442n,
  c: 9759930167667486979947896074742390134541981445449037546722501865556569684880n,
  rs: [
    7654183951290824749640095234125705314675663705931348413930307998327795619638n,
    0n,
    0n,
    0n,
    0n,
  ],
};

const verifyCommitmentInputs = {
  C: [
    [
      8335733946071834698883013585698612085557666739823460394434079211486843042517n,
      15686892433797900135714327927078751280485706850387618477540162903172310491300n,
    ],
  ],
  amounts: [422524000900n],
  blindings: [113398076903969102566426825667700712n],
};

function padCommitmentInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(verifyCommitmentInputs)) {
    if (key == "C") {
      newInputs[key] = padArrayEnd(value, n, [0, 1]);
    } else {
      newInputs[key] = padArrayEnd(value, n, 0);
    }
  }
  // console.log(newInputs);
  return newInputs;
}

function padSumVerificationInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(sumVerificationInputs)) {
    newInputs[key] = padArrayEnd(value, n, 0);
  }
  return newInputs;
}

function padSigVerificationInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(verifySigInputs)) {
    if (key == "K" || key == "C_prev" || key == "C_new") {
      newInputs[key] = padArrayEnd(value, n, [0n, 1n]);
    } else if (key == "pos") {
      newInputs[key] = padArrayEnd(value, n, 0);
    } else {
      newInputs[key] = value;
    }
  }
  return newInputs;
}

function padTxHashInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(txHashInputs)) {
    if (key == "notesIn" || key == "notesOut") {
      newInputs[key] = padArrayEnd(value, n, [0n, 0n, 1n, 0n, 0n, 1n]);
    } else {
      newInputs[key] = value;
    }
  }
  return newInputs;
}

function padTxInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(txInputs)) {
    if (key == "notesIn" || key == "notesOut") {
      newInputs[key] = padArrayEnd(value, n, [0n, 0n, 1n, 0n, 0n, 1n]);
    } else if (key == "pseudoComms") {
      newInputs[key] = padArrayEnd(value, n, [0n, 1n]);
    } else if (
      key == "amountsIn" ||
      key == "amountsOut" ||
      key == "blindingsIn" ||
      key == "blindingsOut" ||
      key == "pos"
    ) {
      newInputs[key] = padArrayEnd(value, n, 0);
    } else {
      newInputs[key] = value;
    }
  }
  return newInputs;
}

function padArrayEnd(arr, len, padding) {
  return arr.concat(Array(len - arr.length).fill(padding));
}

module.exports = {
  returnAddressSigInputs,
  sumVerificationInputs,
  txHashInputs,
  txInputs,
  verifySigInputs,
  padCommitmentInputs,
  padSumVerificationInputs,
  padSigVerificationInputs,
  padTxHashInputs,
  padTxInputs,
};
