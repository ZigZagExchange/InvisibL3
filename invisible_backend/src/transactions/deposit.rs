use std::cell::Cell;
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
//

pub struct Deposit {
    pub transaction_type: String,
    pub deposit_id: u128,
    pub deposit_token: u64,
    pub deposit_amount: u128,
    pub stark_key: BigUint,
    pub notes: Vec<Note>,
    pub signature: ([u8; 32], [u8; 32]),
}

impl Deposit {
    pub fn new(
        deposit_id: u128,
        deposit_token: u64,
        deposit_amount: u128,
        stark_key: BigUint,
        notes: Vec<Note>,
        signature: ([u8; 32], [u8; 32]),
    ) -> Deposit {
        Deposit {
            transaction_type: "deposit".to_string(),
            deposit_id,
            deposit_token,
            deposit_amount,
            stark_key,
            notes,
            signature,
        }
    }

    pub fn execute_deposit(
        &mut self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        let zero_idxs = tree.first_n_zero_idxs(self.notes.len());

        // ? Sum the notes and set the zero leaf indexes
        let mut amount_sum = 0u128;

        for i in 0..self.notes.len() {
            if self.notes[i].token != self.deposit_token {
                panic!("Notes do not match deposit token");
            }
            amount_sum += self.notes[i].amount;

            self.notes[i].index = zero_idxs[i];
        }

        if amount_sum != self.deposit_amount {
            panic!("Amount deposited and newly minted note amounts are inconsistent");
        }

        // ? verify Signature
        self.verify_deposit_signature();

        // ? Update the state
        //     this.updateStateAfterDeposit(
        //       batchInitTree,
        //       tree,
        //       preimage,
        //       updatedNoteHashes
        //     );
        //   }
    }

    // * UPDATE STATE * //

    fn update_state_after_deposit(
        &self,
        batch_init_tree: &Tree,
        tree: &mut Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
        updated_note_hashes: &mut HashMap<u64, (BigUint, Vec<BigUint>, Vec<i8>)>,
    ) {
        self.get_init_state_preimage_proofs(batch_init_tree, preimage);

        for note in self.notes.iter() {
            let (proof, proof_pos) = tree.get_proof(note.index);
            tree.update_node(&note.hash, note.index, &proof);
            updated_note_hashes.insert(note.index, (note.hash.clone(), proof, proof_pos));
        }
    }

    fn get_init_state_preimage_proofs(
        &self,
        batch_init_tree: &Tree,
        preimage: &mut HashMap<BigUint, [BigUint; 2]>,
    ) {
        for note in self.notes.iter() {
            let (proof, proof_pos) = batch_init_tree.get_proof(note.index);
            let mut multi_proof = batch_init_tree.get_multi_update_proof(
                &BigUint::from_i8(0).unwrap(),
                &proof,
                &proof_pos,
            );

            for (key, value) in multi_proof.drain().take(1) {
                preimage.insert(key, value);
            }
        }
    }

    // * HELPER FUNCTIONS * //

    fn verify_deposit_signature(&self) {
        let deposit_hash = self.hash_transaction();

        let valid = starknet::verify(
            &biguint_to_32vec(&self.stark_key),
            &biguint_to_32vec(&deposit_hash),
            &self.signature.0,
            &self.signature.1,
        );

        assert!(valid, "signature is not valid");
    }

    fn hash_transaction(&self) -> BigUint {
        let mut note_hashes: Vec<&BigUint> = self.notes.iter().map(|note| &note.hash).collect();
        let deposit_id_bn = BigUint::from_str(self.deposit_id.to_string().as_str()).unwrap();
        note_hashes.insert(0, &deposit_id_bn);

        return pedersen_on_vec(&note_hashes);
    }
}

fn make_deposit_signature(
    deposit_id: u128,
    notes: Vec<Note>,
    priv_key: BigUint,
) -> ([u8; 32], [u8; 32]) {
    let mut note_hashes: Vec<&BigUint> = notes.iter().map(|note| &note.hash).collect();
    let deposit_id_bn = BigUint::from_str(deposit_id.to_string().as_str()).unwrap();
    note_hashes.insert(0, &deposit_id_bn);

    let deposit_hash = pedersen_on_vec(&note_hashes);

    // priv_key coresponds to stark_key in the deposit transaction
    let signature = starknet::sign(
        &biguint_to_32vec(&priv_key),
        &biguint_to_32vec(&deposit_hash),
        &biguint_to_32vec(&priv_key), // k should be random
    )
    .unwrap();

    return (signature.r, signature.s);
}
