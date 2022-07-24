use std::{
    cell::Cell,
    collections::HashMap,
    fmt::{Debug, Formatter, Result},
    str::FromStr,
};

use num_bigint::BigUint;
use num_traits::FromPrimitive;

use crate::starkware_crypto::get_public_key;

use crate::pedersen::{pedersen, pedersen_on_vec};
use crate::users::biguint_to_32vec;

pub struct Note {
    pub index: Cell<Option<u64>>,
    pub public_key: BigUint, //address_pk
    pub token: u64,
    pub amount: u128,
    pub blinding: BigUint,
    pub hash: BigUint,
}

impl Note {
    pub fn new(
        index: Option<u64>,
        public_key: BigUint, //address_pk
        token: u64,
        amount: u128,
        blinding: BigUint,
    ) -> Note {
        let note_hash = hash_note(amount, &blinding, token, &public_key);

        Note {
            index: Cell::new(index),
            public_key, //address_pk
            token,
            amount,
            blinding,
            hash: note_hash,
        }
    }

    pub fn clone(&self) -> Note {
        Note {
            index: self.index.clone(),
            public_key: self.public_key.clone(), //address_pk
            token: self.token,
            amount: self.amount,
            blinding: self.blinding.clone(),
            hash: self.hash.clone(),
        }
    }
}

fn hash_note(amount: u128, blinding: &BigUint, token: u64, public_key: &BigUint) -> BigUint {
    let commitment = pedersen(&BigUint::from_u128(amount).unwrap(), blinding);

    let token = BigUint::from_u64(token).unwrap();
    let hash_input = vec![public_key, &token, &commitment];

    let note_hash = pedersen_on_vec(&hash_input);

    return note_hash;
}

impl Debug for Note {
    fn fmt(&self, f: &mut Formatter) -> Result {
        return write!(
            f,
            "index: {:?} \npublic_key: {:?} \ntoken: {:?} \namount: {:?} \nblinding: {:?} \nhash: {:?}",
            self.index, self.public_key, self.token, self.amount, self.blinding, self.hash
        );
    }
}

// #[no_mangle]
// pub extern "C" fn new_note(
//     index: u64,
//     public_key: String, //address_pk
//     token: u64,
//     amount: u128,
//     blinding: String,
// ) -> *mut Note {
//     let public_key = BigUint::from_str(&public_key).unwrap();
//     let blinding = BigUint::from_str(&blinding).unwrap();
//     Box::into_raw(Box::new(Note::new(
//         index, public_key, //address_pk
//         token, amount, blinding,
//     )))
// }
// #[no_mangle]
// pub extern "C" fn free_note_ptr(ptr: *mut Note) {
//     if ptr.is_null() {
//         return;
//     }
//     unsafe {
//         Box::from_raw(ptr);
//     }
// }
// #[no_mangle]
// pub extern "C" fn priv_to_pub_key(priv_key: String) -> String {
//     let priv_key = BigUint::from_str(&priv_key).unwrap();
//     let priv_key = biguint_to_32vec(&priv_key);
//     return BigUint::from_bytes_le(&get_public_key(&priv_key).unwrap()).to_string();
// }
