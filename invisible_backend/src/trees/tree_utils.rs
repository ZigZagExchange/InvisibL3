use num_bigint::BigUint;
use std::{fmt::Binary, str::FromStr};

use crate::pedersen::pedersen;

pub fn pairwise_hash(array: &Vec<BigUint>) -> Vec<BigUint> {
    if array.len() % 2 != 0 {
        panic!("Array length must be even");
    }

    let mut hashes: Vec<BigUint> = Vec::new();
    for i in (0..array.len()).step_by(2) {
        let hash: BigUint = pedersen(&array[i], &array[i + 1]);
        hashes.push(hash);
    }

    return hashes;
}

pub fn idx_to_binary_pos(idx: u64, bin_length: usize) -> Vec<i8> {
    // bin_length = depth

    let bin_chars = format!("{idx:b}");

    assert!(
        bin_chars.len() <= bin_length,
        "index is to big to fit on the tree"
    );

    let mut bin_pos: Vec<i8> = Vec::new();

    for ch in bin_chars.chars() {
        // println!("{:?}", ch);
        bin_pos.push(ch.to_digit(10).unwrap() as i8)
    }

    for _ in 0..bin_length - bin_chars.len() {
        bin_pos.insert(0, 0);
    }

    bin_pos.reverse();

    return bin_pos;
}

pub fn proof_pos(leaf_idx: u64, depth: usize) -> Vec<u64> {
    let mut proof_pos: Vec<u64> = Vec::new();
    let proof_binary_pos = idx_to_binary_pos(leaf_idx, depth);

    if leaf_idx % 2 == 0 {
        proof_pos.push(leaf_idx + 1);
    } else {
        proof_pos.push(leaf_idx - 1);
    }

    for i in 1..depth {
        if proof_binary_pos[i] == 1 {
            let pos_i = proof_pos[i - 1] / 2 - 1;
            proof_pos.push(pos_i);
        } else {
            let pos_i = proof_pos[i - 1] / 2 + 1;
            proof_pos.push(pos_i);
        }
    }

    return proof_pos;
}

pub fn get_affected_pos(proof_pos: Vec<u64>) -> Vec<u64> {
    let mut affected_pos: Vec<u64> = Vec::new();

    for i in 1..proof_pos.len() {
        if proof_pos[i] % 2 == 1 {
            affected_pos.push(proof_pos[i] - 1);
        } else {
            affected_pos.push(proof_pos[i] + 1);
        }
    }

    affected_pos.push(0);

    return affected_pos;
}

pub fn inner_nodes_from_leaf_and_path(
    leaf_hash: &BigUint,
    leaf_idx: u64,
    merkle_path: &Vec<BigUint>,
) -> Vec<BigUint> {
    let depth = merkle_path.len();
    let merkle_path_pos = idx_to_binary_pos(leaf_idx, depth);

    let mut inner_nodes: Vec<BigUint> = Vec::new();

    // Left
    let left: BigUint;
    let right: BigUint;
    if merkle_path_pos[0] == 0 {
        left = leaf_hash.clone();
        right = merkle_path[0].clone();
    } else {
        left = merkle_path[0].clone();
        right = leaf_hash.clone();
    };

    inner_nodes.push(pedersen(&left, &right));

    for i in 1..depth {
        // Left
        let left: BigUint;
        let right: BigUint;
        if merkle_path_pos[i] == 0 {
            left = inner_nodes[i - 1].clone();
            right = merkle_path[i].clone();
        } else {
            left = merkle_path[i].clone();
            right = inner_nodes[i - 1].clone();
        };

        let hash: BigUint = pedersen(&left, &right);
        inner_nodes.push(hash);
    }

    return inner_nodes;
}
