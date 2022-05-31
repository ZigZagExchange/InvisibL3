const eddsa = require("../circomlib/src/eddsa.js");
const Tree = require("../src/tree");
const Address = require("../src/address.js");
const AddressTree = require("../src/addressTree.js");
const treeUtils = require("../src/treeUtils.js");
const { Note } = require("../src/notes/noteUtils.js");
const NoteTree = require("../src/notesTree.js");

const G = require("../circomlib/src/babyjub.js").Generator;
const H = require("../circomlib/src/babyjub.js").Base8;
const F = require("../circomlib/src/babyjub.js").F;
const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../circomlib/src/babyjub.js").subPoint;

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

// ============================================================
function generatePrvkey(i) {
  prvkey = Buffer.from(i.toString().padStart(64, "0"), "hex");
  return prvkey;
}

function generatePubkey(prvkey) {
  pubkey = eddsa.prv2pub(prvkey);
  return pubkey;
}
// ============================================================

module.exports = {
  address_inputs,
  address_existence_inputs,
  note_inputs,
  note_existence_inputs,
};
