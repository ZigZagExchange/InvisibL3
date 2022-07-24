use num_bigint::BigUint;
use num_traits::FromPrimitive;
use std::collections::HashMap;
use std::str::FromStr;
use std::sync::Arc;

use crate::pedersen::{pedersen, pedersen_on_vec};
use crate::starkware_crypto as starknet;
use crate::trees::Tree;
use crate::users::biguint_to_32vec;

//
use crate::notes::Note;

use super::deposit::Deposit;
use super::limit_order::LimitOrder;

pub trait Transaction {
    fn transaction_type(&self) -> &str;

    fn execute_transaction(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
        orders_map: &mut HashMap<u128, LimitOrder>,
    );
}

pub struct TransactionBatch {
    pub batch_init_tree: Tree, // Should be immutable
    pub current_state_tree: Tree,
    pub partial_fill_tracker: HashMap<u128, Note>,
    pub preimage: HashMap<BigUint, [BigUint; 2]>,
    pub updated_note_hashes: HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    pub orders_map: HashMap<u128, LimitOrder>,
}

impl TransactionBatch {
    pub fn new(batch_init_tree: Tree) -> TransactionBatch {
        // Todo: Might need no make these mutable
        let current_state_tree: Tree = batch_init_tree.clone();
        let partial_fill_tracker: HashMap<u128, Note> = HashMap::new();
        let preimage: HashMap<BigUint, [BigUint; 2]> = HashMap::new();
        let updated_note_hashes: HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)> = HashMap::new();
        let orders_map: HashMap<u128, LimitOrder> = HashMap::new();

        return TransactionBatch {
            batch_init_tree,
            current_state_tree,
            partial_fill_tracker,
            preimage,
            updated_note_hashes,
            orders_map,
        };
    }

    pub fn execute_transaction<T: Transaction>(&mut self, transaction: T) {
        //

        transaction.execute_transaction(
            &self.batch_init_tree,
            &mut self.current_state_tree,
            &mut self.partial_fill_tracker,
            &mut self.preimage,
            &mut self.updated_note_hashes,
            &mut self.orders_map,
        );

        match transaction.transaction_type() {
            "swap" => {
                println!("swap succesfull");
            }
            "deposit" => {
                println!("deposit succesfull");
            }
            "withdrawal" => {
                println!("withdrawal succesfull");
            }
            _ => panic!("Invalid transaction type"),
        }

        //todo: count num swaps, deposits, withdrawals ...
    }

    pub fn finalize_batch(&mut self) {
        for (index, (leaf_hash, proof, proof_pos)) in self.updated_note_hashes.drain() {
            let mut multiproof = self
                .current_state_tree
                .get_multi_update_proof(&leaf_hash, &proof, &proof_pos);

            for (key, value) in multiproof.drain() {
                self.preimage.insert(key, value);
            }
        }
    }

    pub fn add_new_order(&mut self, order: LimitOrder) {
        if self.orders_map.contains_key(&order.order_id) {
            return ();
        }
        self.orders_map.insert(order.order_id, order);
    }
}
