// const Tree = require("../../src/merkle_trees/tree");
const AddressTree = require("../../src/merkle_trees/addressTree.js");
const treeUtils = require("../../src/merkle_trees/treeUtils.js");
const { Note } = require("../../src/notes/noteUtils.js");
const NoteTree = require("../../src/merkle_trees/notesTree.js");

const G = require("../../circomlib/src/babyjub.js").Generator;
const H = require("../../circomlib/src/babyjub.js").Base8;
const F = require("../../circomlib/src/babyjub.js").F;
const ecMul = require("../../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../../circomlib/src/babyjub.js").subPoint;

const BAL_DEPTH = 4;

function address_inputs() {
  let total_notes = 0;
  let K0_pub_keys = [];
  let notes_per_address = [];
  let amount_blindings_per_address = [];
  for (let i = 0; i < 5; i++) {
    let k0 = Math.floor(Math.random() * 10000);
    let K0 = ecMul(G, k0);

    K0_pub_keys.push(K0);

    let notes = [];
    let amount_blindings = [];
    for (let j = 0; j < 3; j++) {
      let amount = Math.floor(Math.random() * 10000);
      let blinding = Math.floor(Math.random() * 10000);
      let comm = ecAdd(ecMul(G, blinding), ecMul(H, amount));
      let note = new Note(K0, comm, 0, total_notes);
      total_notes++;
      notes.push(note);
      amount_blindings.push({ amount, blinding });
    }
    notes_per_address.push(notes);
    amount_blindings_per_address.push(amount_blindings);
  }

  return {
    // total_notes,
    K0_pub_keys,
    notes_per_address,
    // amount_blindings_per_address,
  };
}

function address_existence_inputs(params) {
  let address_inputs = module.exports.address_inputs();

  let K0_pub_keys = address_inputs.K0_pub_keys;
  let notes_per_address = address_inputs.notes_per_address;

  let addresses = [];
  for (let i = 0; i < 5; i++) {
    let notes = notes_per_address[i];
    let K0 = K0_pub_keys[i];
    let address = new Address(i, K0[0], K0[1], notes);
    addresses.push(address);
  }

  addresses = treeUtils.padArray(addresses, new Address());

  let address_tree = new AddressTree(addresses);

  // proof for the existence of address 0
  let proof = address_tree.getAddressProof(addresses[0]);

  // console.log(proof);
  // console.log(address_tree.leafNodes, "\n", address_tree.innerNodes);
  return {
    proof: proof,
    address_tree: address_tree,
  };
}

function note_inputs() {
  let total_notes = 0;
  let K0_pub_keys = [];
  let notes = [];
  let amount_blindings = [];
  for (let i = 0; i < 5; i++) {
    let k0 = Math.floor(Math.random() * 10000);
    let K0 = ecMul(G, k0);

    K0_pub_keys.push(K0);

    let amount = Math.floor(Math.random() * 10000);
    let blinding = Math.floor(Math.random() * 10000);

    let comm = ecAdd(ecMul(G, blinding), ecMul(H, amount));
    let note = new Note(K0, comm, 0, total_notes);

    total_notes++;
    notes.push(note);
    amount_blindings.push({ amount, blinding });
  }

  return {
    K0_pub_keys,
    notes,
    // amount_blindings,
  };
}

function note_existence_inputs() {
  let note_inputs = module.exports.note_inputs();

  let K0_pub_keys = note_inputs.K0_pub_keys;
  let notes = note_inputs.notes;

  notes = treeUtils.padArray(notes, 0);

  let notesTree = new NoteTree(notes);

  // proof for the existence of address 0
  let proof = notesTree.getNoteProof(notes[0]);

  // console.log(proof);
  // console.log(notesTree.leafNodes, "\n", notesTree.innerNodes);
  return {
    proof: proof,
    notesTree: notesTree,
  };
}

const noteLeafExistence = {
  leaf: 18177278953515442025788161520703298667889188757795520415573204978729834990980n,
  paths2rootPos: [0, 0, 0, 0],
  paths2root: [
    10273355596300638493722608107282301423124784809996299292394816839116420500351n,
    20041036139308968651444438163341685600289978985278711409118908125337315187246n,
    2318450124349034452777245978323544491182801375574062112028381069548470866301n,
    20563546380007770744863356569681027985646943101582852895273284561500813887978n,
  ],
  root: 19490922880692608968548048753155013447201087412814759536712515891022266443354n,
};

const noteExistenceInputs = {
  Ko: [
    1414463055584249975401255287664006444991531772864589842606436631324803797829n,
    3576190135707767864261393218654241707601949798812616969215456467228622391342n,
  ],
  token: 1,
  commitment: [
    8335733946071834698883013585698612085557666739823460394434079211486843042517n,
    15686892433797900135714327927078751280485706850387618477540162903172310491300n,
  ],
  paths2rootPos: [0, 0, 0, 0],
  paths2root: [
    1972593120533667380477339603313231606809289461898419477679735141070009144584n,
    17802860848016238072752536995294492509308816064986911350058301518204519712162n,
    14358118990698561928361151028794218706289651383147235847536627478683214615374n,
    20563546380007770744863356569681027985646943101582852895273284561500813887978n,
  ],
  root: 97460741997381518144094357247482405012556143140276657940098284992116076231n,
};

const multiNoteExistenceInputs = {
  Ko: [
    [
      1414463055584249975401255287664006444991531772864589842606436631324803797829n,
      3576190135707767864261393218654241707601949798812616969215456467228622391342n,
    ],
    [
      15209784076275577690492798579084650861398504112197495115930633671239875318197n,
      12043238146523117931194687866128966944139884122224639245545306927424578202035n,
    ],
    [
      727633070800549199660756625430025559445577491715417070994469407397335168934n,
      8969482073994745989646499483515924597924306463384181226983111910408124871594n,
    ],
    [
      4664522176072200182869991843466823882227951723133875615539504484163435564852n,
      17758111371773129660572234268461712141223098438209534612646069463410754767175n,
    ],
    [
      11380713548171564468083585056514611217084774002874478243001336223815285820088n,
      5193658344260070480120513469247693179147973846309511004901367741493380238389n,
    ],
    [
      13059816953500762311906312386357263494459804028442072112684460509253615624503n,
      2980552948779669295768356845520663242041194802558674379886444324930999498768n,
    ],
    [
      19948941772396920830735009672793826721851958479601793274597010407842378959295n,
      4644625726261722536200002303364545703390118746059560223409732776956647031376n,
    ],
    [
      5780086972777303064406682015983077473411237190980043183614516789642313928823n,
      15008753642966000675242632508493733494163883627036193060415188048149199473090n,
    ],
  ],
  token: [1, 2, 1, 1, 1, 2, 2, 2],
  commitment: [
    [
      8335733946071834698883013585698612085557666739823460394434079211486843042517n,
      15686892433797900135714327927078751280485706850387618477540162903172310491300n,
    ],
    [
      6613599449406241911258363441633060538450787013213439870785506297343246886458n,
      15430372423723055218521968719204415185878321780688335981550257989953866476309n,
    ],
    [
      6978042833519883794795793379220269140785503048432137034751203972879041243045n,
      6529617774211694273733074546057915712099593194258910702950618969401365828322n,
    ],
    [
      7091442067840263607596770844608492233037011048433323344940718114459206581724n,
      2281200571557234849128404440849489483617578232185288188375032721962454922680n,
    ],
    [
      962308794543494314864199809269689807189785440357909734984636811857631864281n,
      10310391762835266918004781281876458867333335602926754459197949413751430691165n,
    ],
    [
      3475567840084137823489877916482504934184140262050915242157473345828727470086n,
      17537910650530779671293551842938257925328003437702806978943114004945548945180n,
    ],
    [
      6987107177025645789146356153090793135012956378900910933686510541305825633132n,
      9911027758606836693895578787033823908571480737256182857418137505863341103195n,
    ],
    [
      10577208391205232351551538559771225762639623533295385089973788889844761252051n,
      10202601314128044636468565502970064981787407201057753484392368542520810434116n,
    ],
  ],
  paths2rootPos: [
    [0, 0, 0, 0],
    [1, 0, 0, 0],
    [0, 1, 0, 0],
    [1, 1, 0, 0],
    [0, 0, 1, 0],
    [1, 0, 1, 0],
    [0, 1, 1, 0],
    [1, 1, 1, 0],
  ],
  paths2root: [
    [
      2184430049986684924030370321279023140669478730331662544563083932683688945156n,
      3730389957023140212283960623707893164265945157446073347843478235147904549789n,
      12315830023001975660180903730564924860076098180864646841391793373079372158383n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      21325069001864614140817593639122334644340956563800398177327227372428792362907n,
      3730389957023140212283960623707893164265945157446073347843478235147904549789n,
      12315830023001975660180903730564924860076098180864646841391793373079372158383n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      13872085513231446981769830059090197500304468160860758031329427094016389704299n,
      19973708043041018034880145237961382348486258480760228126906542805408897775770n,
      12315830023001975660180903730564924860076098180864646841391793373079372158383n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      21573487923836415978212440066365701316127569110353466800941787704278043224305n,
      19973708043041018034880145237961382348486258480760228126906542805408897775770n,
      12315830023001975660180903730564924860076098180864646841391793373079372158383n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      13129776224009955804939409009515893373487128104761784266090302772795655282080n,
      12923550231271748127132369545230357025936099128302806227437386856243860337481n,
      18872404143985586427933363296147962088483330631742659606601093328707662755752n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      10322577260386634835360068932382007698201946693297411570187944893655286200642n,
      12923550231271748127132369545230357025936099128302806227437386856243860337481n,
      18872404143985586427933363296147962088483330631742659606601093328707662755752n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      678978791497618306741500405213075884812742911832265829508135149983381583904n,
      1704921996726800335430941764773486275594961624004681244506983845633860658778n,
      18872404143985586427933363296147962088483330631742659606601093328707662755752n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
    [
      18039417416885953009815506156211823369595597947716380808532347769193102881315n,
      1704921996726800335430941764773486275594961624004681244506983845633860658778n,
      18872404143985586427933363296147962088483330631742659606601093328707662755752n,
      11639279936732882067481942959776886328094524808167853630170211920973753368475n,
    ],
  ],
  root: 7402191034271911993588355768908770108513949228883000646003077745562945497900n,
};

const testRemoveInputs = {
  paths2root: [
    1972593120533667380477339603313231606809289461898419477679735141070009144584n,
    3730389957023140212283960623707893164265945157446073347843478235147904549789n,
    12315830023001975660180903730564924860076098180864646841391793373079372158383n,
    11639279936732882067481942959776886328094524808167853630170211920973753368475n,
  ],
  paths2rootPos: [1, 0, 0, 0],
  newRoot:
    11816613845297746713283243601483790035816247900375849730965662597950378909883n,
};

const multiUpdateNoteInputs = {
  Ko_in: [
    [
      1414463055584249975401255287664006444991531772864589842606436631324803797829n,
      3576190135707767864261393218654241707601949798812616969215456467228622391342n,
    ],
  ],
  token_in: [1],
  commitment_in: [
    7981335475664937316519500362527100412865917970581767624020042131014836227980n,
  ],
  Ko_out: [
    [
      727633070800549199660756625430025559445577491715417070994469407397335168934n,
      8969482073994745989646499483515924597924306463384181226983111910408124871594n,
    ],
    [
      4664522176072200182869991843466823882227951723133875615539504484163435564852n,
      17758111371773129660572234268461712141223098438209534612646069463410754767175n,
    ],
    [
      11380713548171564468083585056514611217084774002874478243001336223815285820088n,
      5193658344260070480120513469247693179147973846309511004901367741493380238389n,
    ],
  ],
  token_out: [1, 1, 1],
  commitment_out: [
    834003395566619460640716593016299012513773791579815133988641347664136840889n,
    7360371392286461288647308437408116161020919955410115205527958666453064068080n,
    17361258852028224145793842525301447058545688371330854373138672285919529923976n,
  ],
  intermidiateRoots: [
    12379533290404289777597289535344426162664245846632138160763839694502997394324n,
    7067951236182437404450852971235501554398135334256095932902492270994738845747n,
    10848737776935956726222230490358401116980543631798437283158779832035672687820n,
    9048567719505952168322308723453929436235177587327163037641784787925488426090n,
  ],
  paths2rootPos: [
    [0, 0, 0, 0],
    [0, 1, 0, 0],
    [1, 1, 0, 0],
  ],
  paths2root: [
    [
      6521254451937100140290258712169689858760087117839405054580719124041075352021n,
      6720259710669087831553846354631287113196125544132777832360700859399112740325n,
      14100726739369462886368459740864540836886914118842810705097104616524114430129n,
      112209499692908591232643365395517544644201095981324526811343712736997538292n,
    ],
    [
      3188939322973067328877758594842858906904921945741806511873286077735470116993n,
      9989307609821415694232395946790321594300165341257334443654074994812304112203n,
      14100726739369462886368459740864540836886914118842810705097104616524114430129n,
      112209499692908591232643365395517544644201095981324526811343712736997538292n,
    ],
    [
      13278842014379484325915673367923198422591093804178561384585856377356761071484n,
      9989307609821415694232395946790321594300165341257334443654074994812304112203n,
      14100726739369462886368459740864540836886914118842810705097104616524114430129n,
      112209499692908591232643365395517544644201095981324526811343712736997538292n,
    ],
  ],
};

function padMultiUpdateNoteInputs(n) {
  const newInputs = {};
  for (const [key, value] of Object.entries(multiUpdateNoteInputs)) {
    if (key == "Ko_in" || key == "Ko_out") {
      newInputs[key] = padArrayEnd(value, n, [0n, 1n]);
    } else if (
      key == "token_in" ||
      key == "commitment_in" ||
      key == "token_out" ||
      key == "commitment_out"
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

// ============================================================

module.exports = {
  address_inputs,
  address_existence_inputs,
  note_inputs,
  note_existence_inputs,
  noteLeafExistence,
  noteExistenceInputs,
  multiNoteExistenceInputs,
  testRemoveInputs,
  multiUpdateNoteInputs,
  padMultiUpdateNoteInputs,
};
