use std::str::FromStr;

use crate::starkware_crypto as starknet;
use num_bigint::BigUint;

pub struct User {
    pub id: u128,
    pub priv_view_key: BigUint,
    pub priv_spend_key: BigUint,
    pub pub_view_key: BigUint,
    pub pub_spend_key: BigUint,
}

impl User {
    pub fn new(id: u128, priv_view_key: BigUint, priv_spend_key: BigUint) -> User {
        let priv_v_key = biguint_to_32vec(&priv_view_key);
        let pub_v_key = starknet::get_public_key(&priv_v_key).unwrap();

        let priv_s_key = biguint_to_32vec(&priv_spend_key);
        let pub_s_key = starknet::get_public_key(&priv_s_key).unwrap();

        let pub_view_key = BigUint::from_bytes_le(&pub_v_key);
        let pub_spend_key = BigUint::from_bytes_le(&pub_s_key);

        User {
            id,
            priv_view_key,
            priv_spend_key,
            pub_view_key,
            pub_spend_key,
        }
    }
}

pub fn biguint_to_32vec(a: &BigUint) -> [u8; 32] {
    let mut a_bytes = a.to_bytes_le();

    a_bytes.append(&mut vec![0; 32 - a_bytes.len()]);

    let a_vec: [u8; 32] = a_bytes.try_into().unwrap();

    return a_vec;
}

// #[no_mangle]
// pub extern "C" fn new_user(id: u128, priv_view_key: String, priv_spend_key: String) -> *mut User {
//     let priv_view_key = BigUint::from_str(&priv_view_key).unwrap();
//     let priv_spend_key = BigUint::from_str(&priv_spend_key).unwrap();

//     Box::into_raw(Box::new(User::new(id, priv_view_key, priv_spend_key)))
// }

// #[no_mangle]
// pub extern "C" fn free_user_ptr(ptr: *mut User) {
//     if ptr.is_null() {
//         return;
//     }
//     unsafe {
//         Box::from_raw(ptr);
//     }
// }
