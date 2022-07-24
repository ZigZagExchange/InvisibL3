use std::collections::HashMap;
use std::hash::Hash;
use std::str::FromStr;

use num_bigint::BigUint;
use num_traits::FromPrimitive;

//
use super::limit_order::LimitOrder;
pub use super::transaction_batch::Transaction;
use crate::notes::Note;
use crate::pedersen::{pedersen, pedersen_on_vec};
use crate::trees::Tree;
//

const MAX_AMOUNT: u128 = 2_u128.pow(90);
const MAX_ORDER_ID: u128 = 2_u128.pow(32);
const MAX_EXPIRATION_TIMESTAMP: u32 = 2_u32.pow(31);

pub struct Swap {
    pub transaction_type: String,
    // pub order_a: LimitOrder,
    // pub order_b: LimitOrder,
    pub order_a_id: u128,
    pub order_b_id: u128,
    pub signatures_a: Vec<([u8; 32], [u8; 32])>,
    pub signatures_b: Vec<([u8; 32], [u8; 32])>,
    pub spent_amount_a: u128,
    pub spent_amount_b: u128,
    pub fee_taken_a: u128,
    pub fee_taken_b: u128,
}

impl Swap {
    pub fn new(
        // order_a: LimitOrder,
        // order_b: LimitOrder,
        order_a_id: u128,
        order_b_id: u128,
        signatures_a: Vec<([u8; 32], [u8; 32])>,
        signatures_b: Vec<([u8; 32], [u8; 32])>,
        spent_amount_a: u128,
        spent_amount_b: u128,
        fee_taken_a: u128,
        fee_taken_b: u128,
    ) -> Swap {
        Swap {
            transaction_type: "swap".to_string(),
            order_a_id,
            order_b_id,
            signatures_a,
            signatures_b,
            spent_amount_a,
            spent_amount_b,
            fee_taken_a,
            fee_taken_b,
        }
    }

    // & batch_init_tree is the state tree at the beginning of the batch
    // & tree is the current state tree
    // & partial_fill_tracker is a map of indexes to partial fill refund notes
    // & preimage is a map of {hash: [left, righ]}
    // & updatedNoteHashes is a map of {index: (leaf_hash, proof, proofPos)}
    fn execute_swap(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        orders_map: &mut HashMap<u128, LimitOrder>,
    ) {
        let order_a: &LimitOrder = orders_map.get(&self.order_a_id).unwrap();
        let order_b: &LimitOrder = orders_map.get(&self.order_b_id).unwrap();

        self._consistency_checks(order_a, order_b);

        self._range_checks(order_a, order_b);

        let is_first_fill_a = order_a.amount_filled.get() == 0;
        let is_first_fill_b = order_b.amount_filled.get() == 0;

        println!("{:?}", is_first_fill_a);

        // ? Check the sum of notes in matches refund and output amounts
        if is_first_fill_a {
            // ? if this is the first fill
            self._check_note_sums(&order_a);
            if order_a.notes_in[0].index != order_a.refund_note.index {
                panic!("refund note index is not the same as the first note index");
            }
        } else {
            // ? if order was partially filled befor
            self._check_prev_fill_consistencies(
                partial_fill_tracker,
                &order_a,
                self.spent_amount_a,
            );
        }

        if is_first_fill_b {
            // ? if this is the first fill
            self._check_note_sums(&order_b);
            if order_b.notes_in[0].index != order_b.refund_note.index {
                panic!("refund note index is not the same as the first note index");
            }
        } else {
            // ? if order was partially filled befor
            self._check_prev_fill_consistencies(
                partial_fill_tracker,
                &order_b,
                self.spent_amount_b,
            );
        }

        // Todo: could also just be done the first fill
        // ? Verify that the order were signed correctly

        order_a.verify_order_signatures(&self.signatures_a);
        order_b.verify_order_signatures(&self.signatures_b);

        // ? Get indexes and create new swap notes
        let zero_idxs = tree.first_n_zero_idxs(4);

        // ? Generate new swap notes ============================
        // Swap note a
        let swap_note_a_idx: u64;
        if is_first_fill_a {
            if order_a.notes_in.len() > 1 {
                swap_note_a_idx = order_a.notes_in[1].index.get().unwrap();
            } else {
                swap_note_a_idx = zero_idxs[0]
            }
        } else {
            swap_note_a_idx = order_a.partial_refund_note_idx.get().unwrap();
        };

        let swap_note_a = Note::new(
            Some(swap_note_a_idx),
            order_a.dest_received_address.clone(),
            order_a.token_received,
            self.spent_amount_b - self.fee_taken_a,
            order_a.blinding_seed.clone(),
        );

        // Swap note b
        let swap_note_b_idx: u64;
        if is_first_fill_b {
            if order_b.notes_in.len() > 1 {
                swap_note_b_idx = order_b.notes_in[1].index.get().unwrap();
            } else {
                swap_note_b_idx = zero_idxs[1]
            }
        } else {
            swap_note_b_idx = order_b.partial_refund_note_idx.get().unwrap();
        };

        let swap_note_b = Note::new(
            Some(swap_note_b_idx),
            order_b.dest_received_address.clone(),
            order_b.token_received,
            self.spent_amount_a - self.fee_taken_b,
            order_b.blinding_seed.clone(),
        );

        // ? Update previous and new partial fills ==========================
        // Order a
        let prev_amount_filled_a = order_a.amount_filled.get();
        order_a
            .amount_filled
            .set(prev_amount_filled_a + self.spent_amount_b);

        println!("{:?}", order_a.amount_filled.get());

        let prev_partial_fill_refund_note_a: Option<Note> =
            partial_fill_tracker.remove(&order_a.order_id);
        let new_partial_refund_note_a: Option<Note>;

        let is_partially_filled_a =
            prev_amount_filled_a + self.spent_amount_b < order_a.amount_received;
        if is_partially_filled_a {
            //? Order A was partially filled, we must refund the rest

            let partial_refund_idx: u64 = if order_a.notes_in.len() > 2 && is_first_fill_a {
                order_a.notes_in[2].index.get().unwrap()
            } else {
                zero_idxs[2]
            };

            new_partial_refund_note_a = self.refund_partial_fill(
                partial_fill_tracker,
                &order_a,
                is_first_fill_a,
                self.spent_amount_a,
                partial_refund_idx,
            );
        } else {
            new_partial_refund_note_a = None;
        }

        // Order b
        let prev_amount_filled_b = order_b.amount_filled.get();
        order_b
            .amount_filled
            .set(prev_amount_filled_b + self.spent_amount_a);

        let prev_partial_fill_refund_note_b: Option<Note> =
            partial_fill_tracker.remove(&order_b.order_id);
        let new_partial_refund_note_b: Option<Note>;

        let is_partially_filled_b =
            prev_amount_filled_b + self.spent_amount_a < order_b.amount_received;
        if is_partially_filled_b {
            //? Order A was partially filled, we must refund the rest

            let partial_refund_idx: u64 = if order_b.notes_in.len() > 2 && is_first_fill_b {
                order_b.notes_in[2].index.get().unwrap()
            } else {
                zero_idxs[3]
            };

            new_partial_refund_note_b = self.refund_partial_fill(
                partial_fill_tracker,
                &order_b,
                is_first_fill_b,
                self.spent_amount_b,
                partial_refund_idx,
            );
        } else {
            new_partial_refund_note_b = None;
        }

        // ? UPDATE STATE AFTER SWAP =======================================

        // ? Update the state for order a
        if is_first_fill_a {
            self.update_state_after_swap_first_fill(
                batch_init_tree,
                tree,
                preimage,
                updated_note_hashes,
                &order_a.notes_in,
                &order_a.refund_note,
                &swap_note_a,
                new_partial_refund_note_a,
            )
        } else {
            self.update_state_after_swap_later_fills(
                batch_init_tree,
                tree,
                preimage,
                updated_note_hashes,
                prev_partial_fill_refund_note_a.unwrap(),
                &swap_note_a,
                new_partial_refund_note_a,
            );
        }

        // ? Update the state for order b
        if is_first_fill_b {
            self.update_state_after_swap_first_fill(
                batch_init_tree,
                tree,
                preimage,
                updated_note_hashes,
                &order_b.notes_in,
                &order_b.refund_note,
                &swap_note_b,
                new_partial_refund_note_b,
            )
        } else {
            self.update_state_after_swap_later_fills(
                batch_init_tree,
                tree,
                preimage,
                updated_note_hashes,
                prev_partial_fill_refund_note_b.unwrap(),
                &swap_note_b,
                new_partial_refund_note_b,
            );
        }

        if !is_partially_filled_a {
            orders_map.remove(&self.order_a_id);
        }
        if !is_partially_filled_b {
            orders_map.remove(&self.order_b_id);
        }

        // return {
        //     swap_note_a,
        //     swap_note_b,
        //     new_partial_refund_note_a,
        //     new_partial_refund_note_b,
        //   };
    }

    // * UPDATE STATE FUNCTION * ========================================================
    // ! FIRST FILL ! // ==================
    fn update_state_after_swap_first_fill(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
        notes_in: &Vec<Note>,
        refund_note: &Note,
        swap_note: &Note,
        partial_fill_refund_note: Option<Note>,
    ) {
        // ? get the merkle paths for initial state tree at the beginning of the batch
        self.get_init_state_preimage_proofs_first_fill(
            batch_init_tree,
            preimage,
            notes_in,
            swap_note.index.get().unwrap(),
            partial_fill_refund_note.as_ref(),
        );

        // ? assert notes exist in the tree
        for note in notes_in.iter() {
            if batch_init_tree.get_leaf_by_index(note.index.get().unwrap()) != note.hash {
                panic!("note spent for swap does not exist in the state")
            }
        }

        // ? Update the state tree
        let refund_idx = refund_note.index.get().unwrap();
        let (first_proof, first_proof_pos) = tree.get_proof(refund_idx);
        tree.update_node(&refund_note.hash, refund_idx, &first_proof);
        updated_note_hashes.insert(
            refund_idx,
            (refund_note.hash.clone(), first_proof, first_proof_pos),
        );

        let swap_idx = swap_note.index.get().unwrap();
        let (second_proof, second_proof_pos) = tree.get_proof(swap_idx);
        tree.update_node(&swap_note.hash, swap_idx, &second_proof);
        updated_note_hashes.insert(
            swap_idx,
            (swap_note.hash.clone(), second_proof, second_proof_pos),
        );

        if partial_fill_refund_note.is_some() {
            //
            let note = partial_fill_refund_note.unwrap();
            let idx: u64 = note.index.get().unwrap();
            let (proof, proof_pos) = tree.get_proof(idx);
            tree.update_node(&note.hash, idx, &proof);
            updated_note_hashes.insert(idx, (note.hash.clone(), proof, proof_pos));
            //
        } else if notes_in.len() > 2 {
            //
            let idx = notes_in[2].index.get().unwrap();
            let (proof, proof_pos) = tree.get_proof(idx);
            tree.update_node(&BigUint::from_i8(0).unwrap(), idx, &proof);
            updated_note_hashes.insert(idx, (BigUint::from_i8(0).unwrap(), proof, proof_pos));
            //
        }

        for i in 3..notes_in.len() {
            let idx = notes_in[i].index.get().unwrap();
            let (proof, proof_pos) = tree.get_proof(idx);
            tree.update_node(&BigUint::from_i8(0).unwrap(), idx, &proof);
            updated_note_hashes.insert(idx, (BigUint::from_i8(0).unwrap(), proof, proof_pos));
        }

        //
    }

    fn get_init_state_preimage_proofs_first_fill(
        &self,
        batch_init_tree: &Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        notes_in: &Vec<Note>,
        swap_note_idx: u64,
        partial_fill_refund_note: Option<&Note>,
    ) {
        for i in 0..notes_in.len() {
            //
            let (proof, proof_pos) = batch_init_tree.get_proof(notes_in[i].index.get().unwrap());
            let mut multiproof =
                batch_init_tree.get_multi_update_proof(&notes_in[i].hash, &proof, &proof_pos);
            for (key, value) in multiproof.drain() {
                preimage.insert(key, value);
            }
            //
        }

        if notes_in.len() < 3 && partial_fill_refund_note.is_some() {
            let note = partial_fill_refund_note.as_ref().unwrap();
            let (proof, proof_pos) = batch_init_tree.get_proof(note.index.get().unwrap());
            let mut multiproof = batch_init_tree.get_multi_update_proof(
                &BigUint::from_i8(0).unwrap(),
                &proof,
                &proof_pos,
            );
            for (key, value) in multiproof.drain() {
                preimage.insert(key, value);
            }
        }
        if notes_in.len() < 2 {
            let (proof, proof_pos) = batch_init_tree.get_proof(swap_note_idx);
            let mut multiproof = batch_init_tree.get_multi_update_proof(
                &BigUint::from_i8(0).unwrap(),
                &proof,
                &proof_pos,
            );
            for (key, value) in multiproof.drain() {
                preimage.insert(key, value);
            }
        }
    }

    // ! LATER FILLS ! // =================

    fn update_state_after_swap_later_fills(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
        prev_partial_fill_refund_note: Note,
        swap_note: &Note,
        new_partial_fill_refund_note: Option<Note>,
    ) {
        if new_partial_fill_refund_note.is_some() {
            self.get_init_state_preimage_proof_later_fills(
                batch_init_tree,
                preimage,
                new_partial_fill_refund_note.as_ref().unwrap(),
            );
        }

        // ? assert note exist in the tree
        if tree.get_leaf_by_index(prev_partial_fill_refund_note.index.get().unwrap())
            != prev_partial_fill_refund_note.hash
        {
            panic!("prev partial refund note used in swap does not exist in the state");
        }

        // ? Update the state tree
        let swap_idx = swap_note.index.get().unwrap();
        let (first_proof, first_proof_pos) = tree.get_proof(swap_idx);
        tree.update_node(&swap_note.hash, swap_idx, &first_proof);
        updated_note_hashes.insert(
            swap_idx,
            (swap_note.hash.clone(), first_proof, first_proof_pos),
        );

        if new_partial_fill_refund_note.is_some() {
            let pfr_note: &Note = new_partial_fill_refund_note.as_ref().unwrap();
            let pfr_idx = pfr_note.index.get().unwrap();
            let (proof, proof_pos) = tree.get_proof(pfr_idx);
            tree.update_node(&pfr_note.hash, pfr_idx, &proof);
            updated_note_hashes.insert(pfr_idx, (pfr_note.hash.clone(), proof, proof_pos));
        }

        //

        //
    }

    fn get_init_state_preimage_proof_later_fills(
        &self,
        batch_init_tree: &Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        partial_fill_refund_note: &Note,
    ) {
        let (proof, proof_pos) =
            batch_init_tree.get_proof(partial_fill_refund_note.index.get().unwrap());
        let mut multiproof = batch_init_tree.get_multi_update_proof(
            &BigUint::from_i8(0).unwrap(),
            &proof,
            &proof_pos,
        );
        for (key, value) in multiproof.drain() {
            preimage.insert(key, value);
        }
    }

    // * HELPER FUNCTIONS ================================================================

    fn refund_partial_fill(
        &self,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        order: &LimitOrder,
        is_first_fill: bool,
        spent_amount_x: u128,
        idx: u64,
    ) -> Option<Note> {
        // let prev_pfr_note_idx = order.partial_refund_note_idx.get().unwrap();

        let new_partial_refund_amount = if is_first_fill {
            order.amount_spent - spent_amount_x
        } else {
            let prev_partial_refund_note = partial_fill_tracker.get(&order.order_id).unwrap();
            prev_partial_refund_note.amount - spent_amount_x
        };

        let new_partial_refund_note: Note = Note::new(
            Some(idx),
            order.dest_spent_address.clone(),
            order.token_spent,
            new_partial_refund_amount,
            order.blinding_seed.clone(),
        );

        partial_fill_tracker.insert(order.order_id, new_partial_refund_note.clone());

        order.partial_refund_note_idx.set(Some(idx));

        return Some(new_partial_refund_note);
    }

    // * CONSISTENCY CHECKS * //

    fn _check_note_sums(&self, order: &LimitOrder) {
        let mut sum_notes: u128 = 0;
        for note in order.notes_in.iter() {
            assert!(note.token == order.token_spent, "token missmatch");
            sum_notes += note.amount
        }

        if sum_notes < order.refund_note.amount + order.amount_spent {
            panic!("sum of inputs is to small for this order")
        }
    }

    fn _check_prev_fill_consistencies(
        &self,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        order: &LimitOrder,
        spend_amount_x: u128,
    ) {
        // let partial_refund_note_idx: u64 = order.partial_refund_note_idx.get().unwrap();
        let partial_refund_note = partial_fill_tracker.get(&order.order_id).unwrap();

        if partial_refund_note.token != order.token_spent {
            panic!("spending wrong token")
        }

        if partial_refund_note.amount < spend_amount_x {
            panic!("refund note amount is to small for this swap")
        }
    }

    fn _consistency_checks(&self, order_a: &LimitOrder, order_b: &LimitOrder) {
        // ? Check that the tokens swapped match
        if order_a.token_spent != order_b.token_received
            || order_a.token_received != order_b.token_spent
        {
            panic!("Tokens swapped do not match");
        }

        // ? Check that the amounts swapped dont exceed the order amounts
        if order_a.amount_spent < self.spent_amount_a || order_b.amount_spent < self.spent_amount_b
        {
            panic!("Amounts swapped exceed order amounts");
        }

        // ? Check that the fees taken dont exceed the order fees
        if self.fee_taken_a * order_a.amount_received > order_a.fee_limit * self.spent_amount_b
            || self.fee_taken_b * order_b.amount_received > order_b.fee_limit * self.spent_amount_a
        {
            panic!("Fees taken exceed order fees");
        }

        // ? Verify consistency of amounts swaped
        if self.spent_amount_a * order_a.amount_received
            > self.spent_amount_b * order_a.amount_spent
            || self.spent_amount_b * order_b.amount_received
                > self.spent_amount_a * order_b.amount_spent
        {
            panic!("Amount swapped ratios are inconsistent");
        }
    }

    fn _range_checks(&self, order_a: &LimitOrder, order_b: &LimitOrder) {
        if self.spent_amount_a > MAX_AMOUNT
            || self.spent_amount_b > MAX_AMOUNT
            || order_a.order_id > MAX_ORDER_ID
            || order_b.order_id > MAX_ORDER_ID
            || order_a.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
            || order_b.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
        {
            panic!("Range checks failed");
        }
    }
}

impl Transaction for Swap {
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
        self.execute_swap(
            batch_init_tree,
            tree,
            preimage,
            updated_note_hashes,
            partial_fill_tracker,
            orders_map,
        );
    }
}
