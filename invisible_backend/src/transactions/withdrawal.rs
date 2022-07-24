use std::collections::HashMap;
use std::str::FromStr;

use crate::starkware_crypto as starknet;
use crate::trees::Tree;
use crate::users::biguint_to_32vec;

use crate::pedersen::{pedersen, pedersen_on_vec};
use num_bigint::BigUint;
use num_traits::FromPrimitive;

//
use crate::notes::Note;

use super::limit_order::LimitOrder;
use super::swap::Transaction;
//

pub struct Withdrawal {
    pub transaction_type: String,
    pub withdrawal_id: u128,
    pub withdrawal_token: u64,
    pub withdrawal_amount: u128,
    pub stark_key: BigUint,
    pub notes_in: Vec<Note>,
    pub refund_note: Note,
    pub signatures: Vec<([u8; 32], [u8; 32])>,
}

impl Withdrawal {
    pub fn new(
        withdrawal_id: u128, //todo could be combination of note indexes or something
        withdrawal_token: u64,
        withdrawal_amount: u128,
        stark_key: BigUint,
        notes_in: Vec<Note>,
        refund_note: Note,
        signatures: Vec<([u8; 32], [u8; 32])>,
    ) -> Withdrawal {
        Withdrawal {
            transaction_type: "withdrawal".to_string(),
            withdrawal_id,
            withdrawal_token,
            withdrawal_amount,
            stark_key,
            notes_in,
            refund_note,
            signatures,
        }
    }

    pub fn execute_withdrawal(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        let amount_sum = self.notes_in.iter().fold(0u128, |acc, note| {
            if note.token != self.withdrawal_token {
                panic!("Notes do not match withdrawal token");
            }
            return acc + note.amount;
        });

        if amount_sum != self.withdrawal_amount + self.refund_note.amount {
            panic!("Notes do not match withdrawal and refund amount");
        }

        // ? Verify signature
        self.verify_withdrawal_signatures();

        // ? Update state
        self.update_state_after_withdrawal(batch_init_tree, tree, preimage, updated_note_hashes);
    }

    // * UPDATE STATE * //

    fn update_state_after_withdrawal(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        self.get_init_state_preimage_proofs(batch_init_tree, preimage);

        // println!("{:#?}", tree.leaf_nodes);
        let refund_idx = self.refund_note.index.get().unwrap();
        if tree.get_leaf_by_index(refund_idx) != self.notes_in[0].hash {
            panic!("note spent does not exist in the state");
        }

        let (proof, proof_pos) = tree.get_proof(refund_idx);
        tree.update_node(&self.refund_note.hash, refund_idx, &proof);
        updated_note_hashes.insert(
            refund_idx,
            (self.refund_note.hash.clone(), proof, proof_pos),
        );

        for note in self.notes_in.iter().skip(1) {
            let idx = note.index.get().unwrap_or(0);

            // ?assert notes exist in the tree
            if tree.get_leaf_by_index(idx) != note.hash {
                println!("idx {}", idx);
                println!("{:?}", tree.get_leaf_by_index(idx));
                println!("{:?}", note.hash);
                panic!("note does not exist in the tree")
            }

            let (proof, proof_pos) = tree.get_proof(idx);
            tree.update_node(&BigUint::from_i8(0).unwrap(), idx, &proof);
            updated_note_hashes.insert(idx, (BigUint::from_i8(0).unwrap(), proof, proof_pos));
        }
    }

    fn get_init_state_preimage_proofs(
        &self,
        batch_init_tree: &Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
    ) {
        for note in self.notes_in.iter() {
            let idx = note.index.get().unwrap_or(0);
            let (proof, proof_pos) = batch_init_tree.get_proof(idx);
            let mut multi_proof =
                batch_init_tree.get_multi_update_proof(&note.hash, &proof, &proof_pos);

            for (key, value) in multi_proof.drain() {
                preimage.insert(key, value);
            }
        }
    }

    // * HELPER FUNCTIONS * //

    fn verify_withdrawal_signatures(&self) {
        let withdrawal_hash = self.hash_transaction();

        for i in 0..self.notes_in.len() {
            let sig = &self.signatures[i];
            let note = &self.notes_in[i];

            let valid = starknet::verify(
                &biguint_to_32vec(&note.public_key),
                &biguint_to_32vec(&withdrawal_hash),
                &sig.0,
                &sig.1,
            );

            assert!(valid, "signature is not valid");
        }
    }

    fn hash_transaction(&self) -> BigUint {
        let note_hashes: Vec<&BigUint> = self.notes_in.iter().map(|note| &note.hash).collect();
        let refund_note_hash = &self.refund_note.hash;

        let id = BigUint::from_str(&format!("{}", self.withdrawal_id)).unwrap();
        let token = BigUint::from_str(&format!("{}", self.withdrawal_token)).unwrap();
        let amount = BigUint::from_str(&format!("{}", self.withdrawal_amount)).unwrap();
        let hash_input: Vec<&BigUint> =
            vec![&id, &token, &amount, &self.stark_key, refund_note_hash];

        let hash_input = vec![hash_input, note_hashes].concat();

        return pedersen_on_vec(&hash_input);
    }
}

// * Transaction Trait * //
impl Transaction for Withdrawal {
    fn transaction_type(&self) -> &str {
        return self.transaction_type.as_str();
    }

    fn execute_transaction(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
        orders_map: &mut HashMap<u128, LimitOrder>,
    ) {
        self.execute_withdrawal(batch_init_tree, tree, preimage, updated_note_hashes)
    }
}

// * MAKE A DEPOSIT SIGNATURE BEFORE CREATING A WITHDRAWAL * //
fn make_withdrawal_signature(
    withdrawal_id: u128,
    withdrawal_token: u64,
    withdrawal_amount: u128,
    stark_key: &BigUint,
    notes_in: &Vec<Note>,
    refund_note: &Note,
    priv_keys: &Vec<BigUint>,
) -> Vec<([u8; 32], [u8; 32])> {
    let note_hashes: Vec<&BigUint> = notes_in.iter().map(|note| &note.hash).collect();
    let refund_note_hash = &refund_note.hash;

    let id = BigUint::from_str(&format!("{}", withdrawal_id)).unwrap();
    let token = BigUint::from_str(&format!("{}", withdrawal_token)).unwrap();
    let amount = BigUint::from_str(&format!("{}", withdrawal_amount)).unwrap();
    let hash_input: Vec<&BigUint> = vec![&id, &token, &amount, stark_key, refund_note_hash];

    let hash_input = vec![hash_input, note_hashes].concat();

    let withdrawal_hash = pedersen_on_vec(&hash_input);
    let withdrawal_hash = biguint_to_32vec(&withdrawal_hash);

    let mut signatures: Vec<([u8; 32], [u8; 32])> = Vec::new();
    for i in 0..notes_in.len() {
        let priv_key: [u8; 32] = biguint_to_32vec(&priv_keys[i]);
        let k = priv_key.clone(); // Todo: should be random

        let sig = starknet::sign(&priv_key, &withdrawal_hash, &k).unwrap();

        signatures.push((sig.r, sig.s));
    }

    return signatures;
}
