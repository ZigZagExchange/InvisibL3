use std::str::FromStr;

use num_bigint::BigUint;
use num_traits::FromPrimitive;
use starkware_crypto_sys::hash as pedersen_hash;

pub fn pedersen(a: &BigUint, b: &BigUint) -> BigUint {
    let mut a_bytes = a.to_bytes_le();
    let mut b_bytes = b.to_bytes_le();

    a_bytes.append(&mut vec![0; 32 - a_bytes.len()]);
    b_bytes.append(&mut vec![0; 32 - b_bytes.len()]);

    let left: &[u8; 32] = &(a_bytes).try_into().unwrap();
    let right: &[u8; 32] = &(b_bytes).try_into().unwrap();
    let res = pedersen_hash(left, right).unwrap();
    let hash = BigUint::from_bytes_le(&res);

    // for merkle trees would make sense to return res directly
    return hash;
}

pub fn pedersen_on_vec(arr: &Vec<&BigUint>) -> BigUint {
    let mut res = pedersen(&BigUint::from_i8(0).unwrap(), arr[0]); // second to last element

    for el in arr.iter().skip(1) {
        res = pedersen(&res, el);
    }

    res = pedersen(&res, &BigUint::from_u16(arr.len() as u16).unwrap()); // last element

    return res;
}
