// use std::io::Read;
// use std::{collections::HashMap, ops::Mul, str::FromStr};

use std::fmt::Debug;

// use invisible_backend::notes::Note;
// use invisible_backend::pedersen::pedersen;
// use invisible_backend::starkware_crypto as starknet;
use invisible_backend::test_utils::read_batch_json_inputs;
use invisible_backend::transactions::transaction_batch::TransactionBatch;
use invisible_backend::trees::Tree;

pub fn main() {
    println!("\n\n");

    // execute_transaction_batch_tests();

    println!("\n\n");
}

fn execute_transaction_batch_tests() {
    let (
        init_leaves,
        order_a,
        order_b,
        order_c,
        swap1,
        swap2,
        deposit1,
        deposit2,
        deposit3,
        withdrawal1,
        withdrawal2,
        withdrawal3,
    ) = read_batch_json_inputs();

    let batch_init_tree = Tree::new(init_leaves, 5);

    let mut batch = TransactionBatch::new(batch_init_tree);

    batch.add_new_order(order_a);
    batch.add_new_order(order_b);
    batch.add_new_order(order_c);

    let start = std::time::Instant::now();

    batch.execute_transaction(swap1);
    batch.execute_transaction(swap2);
    // println!("{:#?}", batch.current_state_tree.leaf_nodes);
    // println!("{:#?}", batch.current_state_tree.get_leaf_by_index(3));
    batch.execute_transaction(withdrawal1);
    batch.execute_transaction(deposit1);
    batch.execute_transaction(withdrawal2);
    batch.execute_transaction(deposit2);
    batch.execute_transaction(withdrawal3);
    batch.execute_transaction(deposit3);

    let mid = std::time::Instant::now();

    batch.finalize_batch();
    let end = std::time::Instant::now();

    let elapsed1 = mid.duration_since(start);
    let elapsed2 = end.duration_since(mid);

    println!("{:#?}", batch.current_state_tree.leaf_nodes);

    println!("transaction batch execution took: {:?}", elapsed1);
    println!("transaction batch finalization took: {:?}", elapsed2);
}
