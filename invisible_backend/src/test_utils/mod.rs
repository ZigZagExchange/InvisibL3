use std::{fs, str::FromStr};

use num_bigint::BigUint;
use rustc_serialize::json::Json;
use serde::{Deserialize, Serialize};

use crate::notes::Note;
use crate::transactions::limit_order::LimitOrder;
use crate::transactions::swap::{self, Swap};
use crate::users::biguint_to_32vec;

#[derive(Serialize, Deserialize, Debug)]
struct Point {
    x: i32,
    y: i32,
}

pub fn test_serde() {
    let point = Point { x: 1, y: 2 };

    // Convert the Point to a JSON string.
    let serialized = serde_json::to_string(&point).unwrap();

    // Prints serialized = {"x":1,"y":2}
    println!("serialized = {}", serialized);

    // Convert the JSON string back to a Point.
    let deserialized: Point = serde_json::from_str(&serialized).unwrap();

    // Prints deserialized = Point { x: 1, y: 2 }
    println!("deserialized = {:?}", deserialized);
}

// pub fn

pub fn read_batch_json_inputs() -> (Vec<BigUint>, Swap, Swap) {
    let data = fs::read_to_string("rust_input.json").expect("Unable to read file");

    let json = Json::from_str(&data).unwrap();

    let init_leaves: Vec<BigUint> = json["init_leaves"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| BigUint::from_str(x.as_string().unwrap()).unwrap())
        .collect();

    let swap1: Swap = serialize_swap(&json["swaps"][0]);
    let swap2: Swap = serialize_swap(&json["swaps"][1]);

    return (init_leaves, swap1, swap2);
}

fn serialize_swap(swap_json: &Json) -> Swap {
    let order_a: LimitOrder = serialize_order(&swap_json["orderA"]);
    let order_b: LimitOrder = serialize_order(&swap_json["orderB"]);

    let signatures_a = swap_json["orderA"]["signatures"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_signature(x))
        .collect();
    let signatures_b = swap_json["orderB"]["signatures"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_signature(x))
        .collect();

    let spent_amount_a = u128::from_str(swap_json["spend_amountA"].as_string().unwrap()).unwrap();
    let spent_amount_b = u128::from_str(swap_json["spend_amountB"].as_string().unwrap()).unwrap();
    let fee_taken_a = u128::from_str(swap_json["fee_takenA"].as_string().unwrap()).unwrap();
    let fee_taken_b = u128::from_str(swap_json["fee_takenB"].as_string().unwrap()).unwrap();

    Swap::new(
        order_a,
        order_b,
        signatures_a,
        signatures_b,
        spent_amount_a,
        spent_amount_b,
        fee_taken_a,
        fee_taken_b,
    )
}

fn serialize_signature(json: &Json) -> ([u8; 32], [u8; 32]) {
    let sig_r: BigUint = BigUint::from_str(json[0].as_string().unwrap()).unwrap();
    let sig_s: BigUint = BigUint::from_str(json[1].as_string().unwrap()).unwrap();

    return (biguint_to_32vec(&sig_r), biguint_to_32vec(&sig_s));
}

fn serialize_order(json: &Json) -> LimitOrder {
    let notes_in: Vec<Note> = json["notes_in"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_note(x))
        .collect();

    return LimitOrder::new(
        u128::from_str(json["orderId"].as_string().unwrap()).unwrap(),
        json["expiration_timestamp"].as_u64().unwrap() as u32,
        json["token_spent"].as_u64().unwrap(),
        json["token_received"].as_u64().unwrap(),
        u128::from_str(json["amount_spent"].as_string().unwrap()).unwrap(),
        u128::from_str(json["amount_received"].as_string().unwrap()).unwrap(),
        u128::from_str(json["fee_limit"].as_string().unwrap()).unwrap(),
        BigUint::from_str(json["dest_spent_address"].as_string().unwrap()).unwrap(),
        BigUint::from_str(json["dest_received_address"].as_string().unwrap()).unwrap(),
        BigUint::from_str(json["blinding_seed"].as_string().unwrap()).unwrap(),
        notes_in,
        serialize_note(&json["refund_note"]),
    );
}

fn serialize_note(json: &Json) -> Note {
    // println!("{}",);
    Note::new(
        json["index"].as_u64().unwrap(),
        BigUint::from_str(json["address_pk"].as_string().unwrap()).unwrap(),
        json["token"].as_u64().unwrap(),
        u128::from_str(json["amount"].as_string().unwrap()).unwrap(),
        BigUint::from_str(json["blinding"].as_string().unwrap()).unwrap(),
    )
}
