use std::{
    collections::HashMap,
    fmt::{Debug, Formatter, Result},
    str::FromStr,
};

use num_bigint::BigUint;

use crate::pedersen::pedersen;

pub mod tree_utils;

pub struct Tree {
    leaf_nodes: Vec<BigUint>,
    inner_nodes: Vec<Vec<BigUint>>,
    pub depth: usize,
    pub root: BigUint,
    count: u64,
    zero_idxs: Vec<u64>,
}

// TODO The poseidon hash function is way too slow.
impl Tree {
    pub fn new(leaf_nodes: Vec<BigUint>, depth: usize) -> Tree {
        let leaf_nodes = pad_leaf_nodes(&leaf_nodes, depth, BigUint::from_str("0").unwrap());

        let inner_nodes: Vec<Vec<BigUint>> = inner_from_leaf_nodes(depth, &leaf_nodes);

        let root = inner_nodes[depth - 1][0].clone();

        // todo: This is only for test purposes
        let mut count: u64 = 0;
        let mut zero_idxs: Vec<u64> = Vec::new();
        for i in 0..leaf_nodes.len() {
            if leaf_nodes[i] != BigUint::from_str("0").unwrap() {
                count = i as u64;
            } else {
                zero_idxs.push(i as u64);
            }
        }

        return Tree {
            leaf_nodes,
            inner_nodes,
            depth,
            root,
            count,
            zero_idxs,
        };
    }

    pub fn clone(&self) -> Tree {
        return Tree {
            leaf_nodes: self.leaf_nodes.clone(),
            inner_nodes: self.inner_nodes.clone(),
            depth: self.depth,
            root: self.root.clone(),
            count: self.count,
            zero_idxs: self.zero_idxs.clone(),
        };
    }

    pub fn update_node(&mut self, leaf_hash: &BigUint, idx: u64, merkle_path: &Vec<BigUint>) {
        if leaf_hash.ne(&BigUint::from_str("0").unwrap()) {
            if idx > self.count {
                panic!("update previous empty leaves first");
            } else if idx == self.count {
                self.count += 1;
            } else {
                self.zero_idxs = self
                    .zero_idxs
                    .iter()
                    .filter(|&x| *x != idx)
                    .map(|&x| x)
                    .collect::<Vec<u64>>();
            }
        } else {
            self.zero_idxs.push(idx);
        }

        self.update_inner_nodes(&leaf_hash, idx, &merkle_path);
        self.update_leaf_nodes(&leaf_hash, idx);
    }

    fn update_inner_nodes(&mut self, leaf_hash: &BigUint, idx: u64, merkle_path: &Vec<BigUint>) {
        let depth = merkle_path.len();
        let proof_pos = tree_utils::proof_pos(idx, depth);
        let affected_pos = tree_utils::get_affected_pos(proof_pos);

        let affected_inner_nodes =
            tree_utils::inner_nodes_from_leaf_and_path(&leaf_hash, idx, &merkle_path);

        // for (var i = 1; i < depth + 1; i++) {
        //     this.innerNodes[depth - i][affectedPos[i - 1]] =
        //       affectedInnerNodes[i - 1];
        //   }

        for i in 1..depth + 1 {
            self.inner_nodes[self.depth - i][affected_pos[i - 1] as usize] =
                affected_inner_nodes[i - 1].clone();
        }

        self.root = self.inner_nodes[0][0].clone();
    }

    fn update_leaf_nodes(&mut self, leaf_hash: &BigUint, idx: u64) {
        self.leaf_nodes[idx as usize] = leaf_hash.clone();
    }

    // * PROOFS * //
    pub fn get_proof(&self, leaf_idx: u64) -> (Vec<BigUint>, Vec<i8>) {
        let proof_binary_pos = tree_utils::idx_to_binary_pos(leaf_idx, self.depth);
        let proof_pos = tree_utils::proof_pos(leaf_idx, self.depth);

        let mut proof: Vec<BigUint> = Vec::new();
        proof.push(self.leaf_nodes[proof_pos[0] as usize].clone());

        for i in 1..self.depth {
            proof.push(self.inner_nodes[self.depth - i][proof_pos[i] as usize].clone());
        }

        return (proof, proof_binary_pos);
    }

    pub fn get_multi_update_proof(
        &self,
        leaf_hash: &BigUint,
        proof: &Vec<BigUint>,
        proof_binary_pos: &Vec<i8>,
    ) -> HashMap<BigUint, [BigUint; 2]> {
        let mut preimage: HashMap<BigUint, [BigUint; 2]> = HashMap::new();
        let mut hashes: Vec<BigUint> = Vec::new();

        let left: BigUint;
        let right: BigUint;
        if proof_binary_pos[0] == 0 {
            left = leaf_hash.clone();
            right = proof[0].clone();
        } else {
            left = proof[0].clone();
            right = leaf_hash.clone();
        };

        hashes.push(pedersen(&left, &right));
        preimage.insert(hashes[0].clone(), [left, right]);

        for i in 1..proof.len() {
            let left: BigUint;
            let right: BigUint;
            if proof_binary_pos[i] == 0 {
                left = hashes[i - 1].clone();
                right = proof[i].clone();
            } else {
                left = proof[i].clone();
                right = hashes[i - 1].clone();
            };

            hashes.push(pedersen(&left, &right));
            preimage.insert(hashes[i].clone(), [left, right]);
        }

        return preimage;
    }

    pub fn verify_proof(&self, leaf_hash: &BigUint, idx: u64, proof: &Vec<BigUint>) -> bool {
        let computed_root = tree_utils::inner_nodes_from_leaf_and_path(leaf_hash, idx, proof);
        return self.root == computed_root[self.depth - 1];
    }

    // * GETTERS * //
    pub fn first_n_zero_idxs(&self, n: usize) -> Vec<u64> {
        if n == 0 {
            return vec![];
        }

        let mut idxs: Vec<u64> = Vec::new();
        if n <= self.zero_idxs.len() {
            for i in 0..n {
                idxs.push(self.zero_idxs[i]);
            }
        } else {
            for i in 0..self.zero_idxs.len() {
                idxs.push(self.zero_idxs[i]);
            }

            for i in 0..n - self.zero_idxs.len() {
                idxs.push(self.count + i as u64);
            }
        }

        return idxs;
    }

    pub fn get_leaf_by_index(&self, index: u64) -> BigUint {
        return self.leaf_nodes[index as usize].clone();
    }
}

fn inner_from_leaf_nodes(depth: usize, leaf_nodes: &Vec<BigUint>) -> Vec<Vec<BigUint>> {
    let mut tree: Vec<Vec<BigUint>> = Vec::new();

    let mut hashes: Vec<BigUint> = tree_utils::pairwise_hash(&leaf_nodes);
    tree.push(hashes.clone());

    for _ in 0..depth - 1 {
        hashes = tree_utils::pairwise_hash(&hashes);
        tree.push(hashes.clone());
    }

    tree.reverse();
    return tree;
}

impl Debug for Tree {
    fn fmt(&self, f: &mut Formatter) -> Result {
        return write!(
            f,
            "leaf_nodes: {:?}
                \n
                inner_nodes: {:?}
                \n
                root: {:?}
                \n
                count: {:?}
                \n
                zero_idxs: {:?}
                \n
                depth: {:?}",
            self.leaf_nodes, self.inner_nodes, self.root, self.count, self.zero_idxs, self.depth
        );
    }
}

fn pad_leaf_nodes(arr: &Vec<BigUint>, depth: usize, pad_value: BigUint) -> Vec<BigUint> {
    let total_len = 2_usize.pow(depth as u32);
    let mut new_arr: Vec<BigUint> = arr.clone();
    for i in 0..total_len - arr.len() {
        new_arr.push(pad_value.clone());
    }

    return new_arr;
}
