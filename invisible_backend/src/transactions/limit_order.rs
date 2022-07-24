use std::cell::Cell;
use std::str::FromStr;

use crate::starkware_crypto as starknet;
use crate::users::biguint_to_32vec;

use crate::pedersen::{pedersen, pedersen_on_vec};
use num_bigint::BigUint;
use num_traits::FromPrimitive;

//
use crate::notes::Note;
//

pub struct LimitOrder {
    pub order_id: u128,
    pub expiration_timestamp: u32,
    pub token_spent: u64,
    pub token_received: u64,
    pub amount_spent: u128,
    pub amount_received: u128,
    pub fee_limit: u128,
    pub dest_spent_address: BigUint,
    pub dest_received_address: BigUint,
    pub blinding_seed: BigUint,
    //
    pub notes_in: Vec<Note>,
    pub refund_note: Note,
    //
    // index of the partial refund note of this order
    pub partial_refund_note_idx: Cell<Option<u64>>,
    pub amount_filled: Cell<u128>,
}

impl LimitOrder {
    pub fn new(
        order_id: u128,
        expiration_timestamp: u32,
        token_spent: u64,
        token_received: u64,
        amount_spent: u128,
        amount_received: u128,
        fee_limit: u128,
        dest_spent_address: BigUint,
        dest_received_address: BigUint,
        blinding_seed: BigUint,
        notes_in: Vec<Note>,
        refund_note: Note,
    ) -> LimitOrder {
        LimitOrder {
            order_id,
            expiration_timestamp,
            token_spent,
            token_received,
            amount_spent,
            amount_received,
            fee_limit,
            dest_spent_address,
            dest_received_address,
            blinding_seed,
            notes_in,
            refund_note,
            partial_refund_note_idx: Cell::new(None),
            amount_filled: Cell::new(0),
        }
    }

    fn hash_order(&self) -> BigUint {
        let note_hashes: Vec<&BigUint> = self
            .notes_in
            .iter()
            .map(|note| &note.hash)
            .collect::<Vec<&BigUint>>();

        let refund_hash = &self.refund_note.hash;

        let mut hash_inputs: Vec<&BigUint> = Vec::new();
        for n_hash in note_hashes {
            hash_inputs.push(n_hash);
        }

        hash_inputs.push(refund_hash);
        let order_id = BigUint::from_u128(self.order_id).unwrap();
        hash_inputs.push(&order_id);
        let expiration_timestamp = BigUint::from_u32(self.expiration_timestamp).unwrap();
        hash_inputs.push(&expiration_timestamp);
        let token_spent = BigUint::from_u64(self.token_spent).unwrap();
        hash_inputs.push(&token_spent);
        let token_received = BigUint::from_u64(self.token_received).unwrap();
        hash_inputs.push(&token_received);
        let amount_spent = BigUint::from_u128(self.amount_spent).unwrap();
        hash_inputs.push(&amount_spent);
        let amount_received = BigUint::from_u128(self.amount_received).unwrap();
        hash_inputs.push(&amount_received);
        let fee_limit = BigUint::from_u128(self.fee_limit).unwrap();
        hash_inputs.push(&fee_limit);
        hash_inputs.push(&self.dest_spent_address);
        hash_inputs.push(&self.dest_received_address);
        hash_inputs.push(&self.blinding_seed);

        let order_hash = pedersen_on_vec(&hash_inputs);

        return order_hash;
    }

    pub fn sign_order(&self, private_keys: Vec<&BigUint>) -> Vec<([u8; 32], [u8; 32])> {
        let mut signatures: Vec<([u8; 32], [u8; 32])> = Vec::new();

        let order_hash = self.hash_order();
        let msg_hash = biguint_to_32vec(&order_hash);

        for pk in private_keys.iter() {
            let priv_key: [u8; 32] = biguint_to_32vec(pk);
            let k: [u8; 32] = biguint_to_32vec(pk); // todo should be random

            let signature = starknet::sign(&priv_key, &msg_hash, &k).unwrap();

            // let sig_r = BigUint::from_bytes_le(&signature.r);
            // let sig_s = BigUint::from_bytes_le(&signature.s);

            signatures.push((signature.r, signature.s));
        }

        return signatures;
    }

    pub fn verify_order_signatures(&self, signatures: &Vec<([u8; 32], [u8; 32])>) {
        let order_hash = self.hash_order();
        let msg_hash = biguint_to_32vec(&order_hash);

        for i in 0..self.notes_in.len() {
            let pub_key: [u8; 32] = biguint_to_32vec(&self.notes_in[i].public_key);
            let sig_r: [u8; 32] = signatures[i].0;
            let sig_s: [u8; 32] = signatures[i].1;

            let valid = starknet::verify(&pub_key, &msg_hash, &sig_r, &sig_s);

            if !valid {
                println!(
                    "sig{:?}, \nmsg_hash {:?},  \npub_key {:?}",
                    (
                        BigUint::from_bytes_le(&sig_r),
                        BigUint::from_bytes_le(&sig_s)
                    ),
                    BigUint::from_bytes_le(&msg_hash),
                    BigUint::from_bytes_le(&pub_key)
                );
            }

            assert!(valid, "signature is not valid");
        }
    }
}

// pub extern "C" fn new_order(
//     order_id: String,
//     expiration_timestamp: u32,
//     token_spent: u64,
//     token_received: u64,
//     amount_spent: String,
//     amount_received: String,
//     fee_limit: String,
//     dest_spent_address: String,
//     dest_received_address: String,
//     blinding_seed: String,
//     notes_in: Vec<Note>,
//     refund_note: Note,
// ) -> *mut LimitOrder {
//     let order_id = u128::from_str(&order_id).unwrap();
//     let amount_spent = u128::from_str(&amount_spent).unwrap();
//     let amount_received = u128::from_str(&amount_received).unwrap();
//     let fee_limit = u128::from_str(&fee_limit).unwrap();

//     let dest_spent_address = BigUint::from_str(&dest_spent_address).unwrap();
//     let dest_received_address = BigUint::from_str(&dest_received_address).unwrap();
//     let blinding_seed = BigUint::from_str(&blinding_seed).unwrap();

//     Box::into_raw(Box::new(LimitOrder::new(
//         order_id,
//         expiration_timestamp,
//         token_spent,
//         token_received,
//         amount_spent,
//         amount_received,
//         fee_limit,
//         dest_spent_address,
//         dest_received_address,
//         blinding_seed,
//         notes_in,
//         refund_note,
//     )))
// }

// #[no_mangle]
// pub extern "C" fn free_order_ptr(ptr: *mut LimitOrder) {
//     if ptr.is_null() {
//         return;
//     }
//     unsafe {
//         Box::from_raw(ptr);
//     }
// }
