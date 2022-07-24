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
    pub order_a: LimitOrder,
    pub order_b: LimitOrder,
    pub signatures_a: Vec<([u8; 32], [u8; 32])>,
    pub signatures_b: Vec<([u8; 32], [u8; 32])>,
    pub spent_amount_a: u128,
    pub spent_amount_b: u128,
    pub fee_taken_a: u128,
    pub fee_taken_b: u128,
}

impl Swap {
    pub fn new<'a>(
        order_a: LimitOrder,
        order_b: LimitOrder,
        signatures_a: Vec<([u8; 32], [u8; 32])>,
        signatures_b: Vec<([u8; 32], [u8; 32])>,
        spent_amount_a: u128,
        spent_amount_b: u128,
        fee_taken_a: u128,
        fee_taken_b: u128,
    ) -> Swap {
        Swap {
            transaction_type: "swap".to_string(),
            order_a,
            order_b,
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
        partial_fill_tracker: &mut HashMap<u128, Note>,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        self._consistency_checks();

        self._range_checks();

        let is_first_fill_a = self.order_a.amount_filled.get() == 0;
        let is_first_fill_b = self.order_b.amount_filled.get() == 0;

        // ? Check the sum of notes in matches refund and output amounts
        if is_first_fill_a {
            // ? if this is the first fill
            self._check_note_sums(&self.order_a);
            if self.order_a.notes_in[0].index != self.order_a.refund_note.index {
                panic!("refund note index is not the same as the first note index");
            }
        } else {
            // ? if order was partially filled befor
            self._check_prev_fill_consistencies(
                partial_fill_tracker,
                &self.order_a,
                self.spent_amount_a,
            );
        }

        if is_first_fill_b {
            // ? if this is the first fill
            self._check_note_sums(&self.order_b);
            if self.order_b.notes_in[0].index != self.order_b.refund_note.index {
                panic!("refund note index is not the same as the first note index");
            }
        } else {
            // ? if order was partially filled befor
            self._check_prev_fill_consistencies(
                partial_fill_tracker,
                &self.order_b,
                self.spent_amount_b,
            );
        }

        // Todo: could also just be done the first fill
        // ? Verify that the order were signed correctly

        self.order_a.verify_order_signatures(&self.signatures_a);
        self.order_b.verify_order_signatures(&self.signatures_b);

        // ? Get indexes and create new swap notes
        let zero_idxs = tree.first_n_zero_idxs(4);

        // ? Generate new swap notes ============================
        // Swap note a
        let swap_note_a_idx: u64;
        if is_first_fill_a {
            if self.order_a.notes_in.len() > 1 {
                swap_note_a_idx = self.order_a.notes_in[1].index
            } else {
                swap_note_a_idx = zero_idxs[0]
            }
        } else {
            swap_note_a_idx = self.order_a.partial_refund_note_idx.get().unwrap();
        };

        let swap_note_a = Note::new(
            swap_note_a_idx,
            self.order_a.dest_received_address.clone(),
            self.order_a.token_received,
            self.spent_amount_b - self.fee_taken_a,
            self.order_a.blinding_seed.clone(),
        );

        // Swap note b
        let swap_note_b_idx: u64;
        if is_first_fill_b {
            if self.order_b.notes_in.len() > 1 {
                swap_note_b_idx = self.order_b.notes_in[1].index
            } else {
                swap_note_b_idx = zero_idxs[1]
            }
        } else {
            swap_note_b_idx = self.order_b.partial_refund_note_idx.get().unwrap();
        };

        let swap_note_b = Note::new(
            swap_note_b_idx,
            self.order_b.dest_received_address.clone(),
            self.order_b.token_received,
            self.spent_amount_a - self.fee_taken_b,
            self.order_b.blinding_seed.clone(),
        );

        // ? Update previous and new partial fills ==========================
        // Order a
        let prev_amount_filled_a = self.order_a.amount_filled.get();
        self.order_a
            .amount_filled
            .set(prev_amount_filled_a + self.spent_amount_b);

        let prev_partial_fill_refund_note_a: Option<Note> =
            partial_fill_tracker.remove(&self.order_a.order_id);
        let new_partial_refund_note_a: Option<Note>;
        if prev_amount_filled_a + self.spent_amount_b < self.order_a.amount_received {
            //? Order A was partially filled, we must refund the rest

            let partial_refund_idx = if self.order_a.notes_in.len() > 2 && is_first_fill_a {
                self.order_a.notes_in[2].index
            } else {
                zero_idxs[2]
            };

            new_partial_refund_note_a = self.refund_partial_fill(
                partial_fill_tracker,
                &self.order_a,
                is_first_fill_a,
                self.spent_amount_a,
                partial_refund_idx,
            );
        } else {
            new_partial_refund_note_a = None;
        }

        // Order b
        let prev_amount_filled_b = self.order_b.amount_filled.get();
        self.order_b
            .amount_filled
            .set(prev_amount_filled_b + self.spent_amount_a);

        let prev_partial_fill_refund_note_b: Option<Note> =
            partial_fill_tracker.remove(&self.order_b.order_id);
        let new_partial_refund_note_b: Option<Note>;
        if prev_amount_filled_b + self.spent_amount_a < self.order_b.amount_received {
            //? Order A was partially filled, we must refund the rest

            let partial_refund_idx = if self.order_b.notes_in.len() > 2 && is_first_fill_b {
                self.order_b.notes_in[2].index
            } else {
                zero_idxs[3]
            };

            new_partial_refund_note_b = self.refund_partial_fill(
                partial_fill_tracker,
                &self.order_b,
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
                &self.order_a.notes_in,
                &self.order_a.refund_note,
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
                &self.order_b.notes_in,
                &self.order_b.refund_note,
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
            swap_note.index,
            partial_fill_refund_note.as_ref(),
        );

        // ? assert notes exist in the tree
        for note in notes_in.iter() {
            if batch_init_tree.get_leaf_by_index(note.index) != note.hash {
                panic!("note spent for swap does not exist in the state")
            }
        }

        // ? Update the state tree
        let (first_proof, first_proof_pos) = tree.get_proof(refund_note.index);
        tree.update_node(&refund_note.hash, refund_note.index, &first_proof);
        updated_note_hashes.insert(
            refund_note.index,
            (refund_note.hash.clone(), first_proof, first_proof_pos),
        );

        let (second_proof, second_proof_pos) = tree.get_proof(swap_note.index);
        tree.update_node(&swap_note.hash, swap_note.index, &second_proof);
        updated_note_hashes.insert(
            refund_note.index,
            (swap_note.hash.clone(), second_proof, second_proof_pos),
        );

        if partial_fill_refund_note.is_some() {
            let note = partial_fill_refund_note.unwrap();
            let (proof, proof_pos) = tree.get_proof(note.index);
            tree.update_node(&note.hash, note.index, &proof);
            updated_note_hashes.insert(note.index, (note.hash.clone(), proof, proof_pos));
        } else if notes_in.len() > 2 {
            let (proof, proof_pos) = tree.get_proof(notes_in[2].index);
            tree.update_node(&BigUint::from_i8(0).unwrap(), notes_in[2].index, &proof);
            updated_note_hashes.insert(
                notes_in[2].index,
                (BigUint::from_i8(0).unwrap(), proof, proof_pos),
            );
        }

        for i in 3..notes_in.len() {
            let (proof, proof_pos) = tree.get_proof(notes_in[i].index);
            tree.update_node(&BigUint::from_i8(0).unwrap(), notes_in[i].index, &proof);
            updated_note_hashes.insert(
                notes_in[i].index,
                (BigUint::from_i8(0).unwrap(), proof, proof_pos),
            );
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
            let (proof, proof_pos) = batch_init_tree.get_proof(notes_in[i].index);
            let mut multiproof =
                batch_init_tree.get_multi_update_proof(&notes_in[i].hash, &proof, &proof_pos);
            for (key, value) in multiproof.drain().take(1) {
                preimage.insert(key, value);
            }
        }

        if notes_in.len() < 3 && partial_fill_refund_note.is_some() {
            let note = partial_fill_refund_note.as_ref().unwrap();
            let (proof, proof_pos) = batch_init_tree.get_proof(note.index);
            let mut multiproof = batch_init_tree.get_multi_update_proof(
                &BigUint::from_i8(0).unwrap(),
                &proof,
                &proof_pos,
            );
            for (key, value) in multiproof.drain().take(1) {
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
            for (key, value) in multiproof.drain().take(1) {
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
        if tree.get_leaf_by_index(prev_partial_fill_refund_note.index)
            != prev_partial_fill_refund_note.hash
        {
            panic!("prev partial refund note used in swap does not exist in the state");
        }

        // ? Update the state tree
        let (first_proof, first_proof_pos) = tree.get_proof(swap_note.index);
        tree.update_node(&swap_note.hash, swap_note.index, &first_proof);
        updated_note_hashes.insert(
            swap_note.index,
            (swap_note.hash.clone(), first_proof, first_proof_pos),
        );

        if new_partial_fill_refund_note.is_some() {
            let pfr_note: &Note = new_partial_fill_refund_note.as_ref().unwrap();
            let (proof, proof_pos) = tree.get_proof(pfr_note.index);
            tree.update_node(&pfr_note.hash, pfr_note.index, &proof);
            updated_note_hashes.insert(pfr_note.index, (pfr_note.hash.clone(), proof, proof_pos));
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
        let (proof, proof_pos) = batch_init_tree.get_proof(partial_fill_refund_note.index);
        let mut multiproof = batch_init_tree.get_multi_update_proof(
            &BigUint::from_i8(0).unwrap(),
            &proof,
            &proof_pos,
        );
        for (key, value) in multiproof.drain().take(1) {
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
            idx,
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

    fn _consistency_checks(&self) {
        // ? Check that the tokens swapped match
        if self.order_a.token_spent != self.order_b.token_received
            || self.order_a.token_received != self.order_b.token_spent
        {
            panic!("Tokens swapped do not match");
        }

        // ? Check that the amounts swapped dont exceed the order amounts
        if self.order_a.amount_spent < self.spent_amount_a
            || self.order_b.amount_spent < self.spent_amount_b
        {
            panic!("Amounts swapped exceed order amounts");
        }

        // ? Check that the fees taken dont exceed the order fees
        if self.fee_taken_a * self.order_a.amount_received
            > self.order_a.fee_limit * self.spent_amount_b
            || self.fee_taken_b * self.order_b.amount_received
                > self.order_b.fee_limit * self.spent_amount_a
        {
            panic!("Fees taken exceed order fees");
        }

        // ? Verify consistency of amounts swaped
        if self.spent_amount_a * self.order_a.amount_received
            > self.spent_amount_b * self.order_a.amount_spent
            || self.spent_amount_b * self.order_b.amount_received
                > self.spent_amount_a * self.order_b.amount_spent
        {
            panic!("Amount swapped ratios are inconsistent");
        }
    }

    fn _range_checks(&self) {
        if self.spent_amount_a > MAX_AMOUNT
            || self.spent_amount_b > MAX_AMOUNT
            || self.order_a.order_id > MAX_ORDER_ID
            || self.order_b.order_id > MAX_ORDER_ID
            || self.order_a.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
            || self.order_b.expiration_timestamp > MAX_EXPIRATION_TIMESTAMP
        {
            panic!("Range checks failed");
        }
    }
}

impl Transaction for Swap {
    fn transaction_type(&self) -> &str {
        return "swap";
    }

    fn execute_transaction(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        partial_fill_tracker: &mut HashMap<u128, Note>,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        self.execute_swap(
            batch_init_tree,
            tree,
            partial_fill_tracker,
            preimage,
            updated_note_hashes,
        )
    }
}
