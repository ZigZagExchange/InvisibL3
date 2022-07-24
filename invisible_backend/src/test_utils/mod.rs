use std::cell::Cell;
use std::{fs, str::FromStr};

use num_bigint::BigUint;
use rustc_serialize::json::Json;

use crate::notes::Note;
use crate::transactions::deposit::{self, Deposit};
use crate::transactions::limit_order::LimitOrder;
use crate::transactions::swap::{self, Swap};
use crate::transactions::withdrawal::{self, Withdrawal};
use crate::users::biguint_to_32vec;

// pub fn

pub fn read_batch_json_inputs() -> (
    Vec<BigUint>,
    LimitOrder,
    LimitOrder,
    LimitOrder,
    Swap,
    Swap,
    Deposit,
    Deposit,
    Deposit,
    Withdrawal,
    Withdrawal,
    Withdrawal,
) {
    let data = fs::read_to_string("rust_input.json").expect("Unable to read file");

    let json = Json::from_str(&data).unwrap();

    let init_leaves: Vec<BigUint> = json["init_leaves"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| BigUint::from_str(x.as_string().unwrap()).unwrap())
        .collect();

    let order_a: LimitOrder = serialize_order(&json["swaps"][0]["orderA"]);
    let order_b: LimitOrder = serialize_order(&json["swaps"][0]["orderB"]);
    let order_c: LimitOrder = serialize_order(&json["swaps"][1]["orderB"]);

    let swap1: Swap = serialize_swap(&json["swaps"][0], order_a.order_id, order_b.order_id);
    let swap2: Swap = serialize_swap(&json["swaps"][1], order_a.order_id, order_c.order_id);

    let deposit1: Deposit = serialize_deposit(&json["deposits"][0]);
    let deposit2: Deposit = serialize_deposit(&json["deposits"][1]);
    let deposit3: Deposit = serialize_deposit(&json["deposits"][2]);

    let withdrawal1: Withdrawal = serialize_withdrawal(&json["withdrawals"][0]);
    let withdrawal2: Withdrawal = serialize_withdrawal(&json["withdrawals"][1]);
    let withdrawal3: Withdrawal = serialize_withdrawal(&json["withdrawals"][2]);

    return (
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
    );
}

fn serialize_swap(swap_json: &Json, order_a: LimitOrder, order_b: LimitOrder) -> Swap {
    // let order_a: LimitOrder = serialize_order(&swap_json["orderA"]);
    // let order_b: LimitOrder = serialize_order(&swap_json["orderB"]);

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

fn serialize_deposit(deposit_json: &Json) -> Deposit {
    let notes: Vec<Note> = deposit_json["notes"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_note(x))
        .collect();

    let signature = serialize_signature(&deposit_json["signature"]);

    return Deposit::new(
        u128::from_str(
            deposit_json["on_chain_deposit_info"]["deposit_id"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        deposit_json["on_chain_deposit_info"]["token"]
            .as_u64()
            .unwrap(),
        u128::from_str(
            deposit_json["on_chain_deposit_info"]["amount"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        BigUint::from_str(
            deposit_json["on_chain_deposit_info"]["stark_key"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        notes,
        signature,
    );
}

fn serialize_withdrawal(withdraw_json: &Json) -> Withdrawal {
    let notes_in: Vec<Note> = withdraw_json["notesIn"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_note(x))
        .collect();

    let signatures = withdraw_json["signatures"]
        .as_array()
        .unwrap()
        .iter()
        .map(|x| serialize_signature(x))
        .collect();

    Withdrawal::new(
        u128::from_str(
            withdraw_json["on_chain_withdraw_info"]["withdraw_id"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        withdraw_json["on_chain_withdraw_info"]["token"]
            .as_u64()
            .unwrap(),
        u128::from_str(
            withdraw_json["on_chain_withdraw_info"]["amount"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        BigUint::from_str(
            withdraw_json["on_chain_withdraw_info"]["stark_key"]
                .as_string()
                .unwrap(),
        )
        .unwrap(),
        notes_in,
        serialize_note(&withdraw_json["refund_note"]),
        signatures,
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
        Some(json["index"].as_u64().unwrap()),
        BigUint::from_str(json["address_pk"].as_string().unwrap()).unwrap(),
        json["token"].as_u64().unwrap(),
        u128::from_str(json["amount"].as_string().unwrap()).unwrap(),
        BigUint::from_str(json["blinding"].as_string().unwrap()).unwrap(),
    )
}
