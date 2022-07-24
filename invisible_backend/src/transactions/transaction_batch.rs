use num_bigint::BigUint;
use num_traits::FromPrimitive;
use std::collections::HashMap;
use std::str::FromStr;

use crate::pedersen::{pedersen, pedersen_on_vec};
use crate::starkware_crypto as starknet;
use crate::trees::Tree;
use crate::users::biguint_to_32vec;

//
use crate::notes::Note;

pub trait Transaction {
    fn transaction_type(&self) -> &str;

    fn execute_transaction(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    );
}

pub struct TransactionBatch {
    batch_init_tree: Tree, // Should be immutable
    current_state_tree: Tree,
    partial_fill_tracker: HashMap<u128, Note>,
    preimage: HashMap<BigUint, [BigUint; 2]>,
    updated_note_hashes: HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
}

impl TransactionBatch {
    pub fn new(batch_init_tree: Tree) -> TransactionBatch {
        // Todo: Might need no make these mutable
        let current_state_tree: Tree = batch_init_tree.clone();
        let partial_fill_tracker: HashMap<u128, Note> = HashMap::new();
        let preimage: HashMap<BigUint, [BigUint; 2]> = HashMap::new();
        let updated_note_hashes: HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)> = HashMap::new();

        return TransactionBatch {
            batch_init_tree,
            current_state_tree,
            partial_fill_tracker,
            preimage,
            updated_note_hashes,
        };
    }

    pub fn execute_swap<T: Transaction>(&mut self, transaction: T) {
        //

        transaction.execute_transaction(
            &self.batch_init_tree,
            &mut self.current_state_tree,
            &mut self.partial_fill_tracker,
            &mut self.preimage,
            &mut self.updated_note_hashes,
        );

        match transaction.transaction_type() {
            "swap" => {}
            _ => panic!("Invalid transaction type"),
        }

        //todo: count num swaps, deposits, withdrawals ...
    }

    pub fn finalize_batch(&mut self) {
        //

        for (index, (leaf_hash, proof, proof_pos)) in self.updated_note_hashes.drain().take(1) {
            let mut multiproof = self
                .current_state_tree
                .get_multi_update_proof(&leaf_hash, &proof, &proof_pos);

            for (key, value) in multiproof.drain().take(1) {
                self.preimage.insert(key, value);
            }
        }
    }
}
