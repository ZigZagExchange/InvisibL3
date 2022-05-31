const babyJubJub = require("../circomlib/src/babyjub.js");
const ecMul = require("../circomlib/src/babyjub.js").mulPointEscalar;
const ecAdd = require("../circomlib/src/babyjub.js").addPoint;
const ecSub = require("../circomlib/src/babyjub.js").subPoint;
const F = require("../circomlib/src/babyjub.js").F;
// const poseidon = require("../../circomlib/src/poseidon.js");

const Transaction = require("../src/notes/noteUtils").Transaction;
const Note = require("../src/notes/noteUtils").Note;
const utils = require("../src/notes/noteUtils");
const dummyData = require("../src/dummy/dummyData");

let G = babyJubJub.Generator;

function main() {
  let input_data = dummyData.generate_random_data(5);
  const amounts = input_data.amounts;
  const blindings = input_data.blindings;
  const tokenTypes = input_data.tokenTypes;
  const addresses = input_data.addresses;

  let input_keys = dummyData.generate_random_keys(5);
  const note_priv_keys = input_keys.priv_keys;
  const note_pub_keys = input_keys.pub_keys;

  let notes_in = [];
  let notes_out = [];
  let note_reveals = [];
  for (let i = 0; i < amounts.length; i++) {
    let comm = utils.new_commitment(amounts[i], blindings[i]);
    let note_in = new Note(addresses[i], comm, tokenTypes[i]);
    let note_out = new Note(addresses[i], comm, tokenTypes[i]);
    notes_in.push(note_in);
    notes_out.push(note_out);
    let note_reveal = {
      note: note_in,
      amount: amounts[i],
      blinding: blindings[i],
    };
    note_reveals.push(note_reveal);
  }
  let tx = new Transaction(notes_in, notes_out, 929384);

  let cmtz_data = utils.cmtz_priv_keys(note_reveals);
  let new_notes_in = utils.new_commitment_notes(
    addresses,
    tokenTypes,
    amounts,
    cmtz_data.new_blindings
  );
  let Zs = utils.cmtz_pub_keys(notes_in, new_notes_in, cmtz_data.pos);

  let sig = tx.sign(note_priv_keys, cmtz_data.priv_keys_z);

  console.log('"K": ', note_pub_keys[0]);
  console.log('"C_prev": ', notes_in[0].commitment);
  console.log('"C_new": ', new_notes_in[0].commitment);
  console.log('"pos": ', cmtz_data.pos[0]);
  console.log('"m": ', tx.hash_transaction());
  console.log('"c": ', sig[0]);
  console.log('"rs": ', sig[1]);

  console.log("Z: ", Zs[0]);

  tx.verify_signature(note_pub_keys, Zs, sig);
}

main();
