use std::io::Read;
use std::{collections::HashMap, ops::Mul, str::FromStr};

use invisible_backend::notes::Note;
use invisible_backend::pedersen::pedersen;
use invisible_backend::starkware_crypto as starknet;
use invisible_backend::test_utils::read_batch_json_inputs;
use invisible_backend::transactions::transaction_batch::TransactionBatch;
use invisible_backend::trees::Tree;
use invisible_backend::users::biguint_to_32vec;
use num_bigint::{BigUint, ToBigUint};
use num_traits::FromPrimitive;

pub fn main() {
    println!("\n\n");

    let (init_leaves, swap1, swap2) = read_batch_json_inputs();

    let batch_init_tree = Tree::new(init_leaves, 5);

    let mut batch = TransactionBatch::new(batch_init_tree);

    let start = std::time::Instant::now();

    batch.execute_swap(swap1);
    batch.execute_swap(swap2);

    let end = std::time::Instant::now();
    let elapsed = end.duration_since(start);
    println!("execute_swap took: {:?}", elapsed);

    // verify_sig();

    println!("\n\n");
}

fn verify_sig() {
    let sig = [
        BigUint::from_str(
            "200371425482467161309511306941739161877435606849165630059345742382388133479",
        )
        .unwrap(),
        BigUint::from_str(
            "2949088587850987568031785770717773369016080107487511179754559706270700024087",
        )
        .unwrap(),
    ];

    let msg_hash = BigUint::from_str("3333333333").unwrap();
    let stark_key = BigUint::from_str(
        "1914994814569112824410079350007058899395275284164752394101283237526758145619",
    )
    .unwrap();

    let res = starknet::verify(
        &biguint_to_32vec(&stark_key),
        &biguint_to_32vec(&msg_hash),
        &biguint_to_32vec(&sig[0]),
        &biguint_to_32vec(&sig[1]),
    );

    println!("{}", res);
}
