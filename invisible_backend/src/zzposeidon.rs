use ff::Field;
use ff::*;
use poseidon_rs::Fr;
// extern crate rustc_serialize;
// use rustc_serialize::json::Json;
// use std::fs::File;
// use std::io::Read;

use num_bigint::BigUint;

use constants::*;

pub mod constants;

const N_ROUNDS_F: u16 = 8;
const N_ROUNDS_P: [u16; 16] = [
    56, 57, 56, 60, 60, 63, 64, 63, 60, 66, 60, 65, 70, 60, 64, 68,
];

// const opt = unstringifyBigInts(require("./poseidon_constants_opt.json"));

pub struct Poseidon {
    // constants: Vec<>,
}

pub fn zzposeidon(inputs: Vec<BigUint>) {
    assert!(inputs.len() > 0);
    assert!(inputs.len() < N_ROUNDS_P.len() - 1);

    let t: u16 = (inputs.len() + 1) as u16;
    let n_rounds_P = N_ROUNDS_P[(t - 2) as usize];
    // const nRoundsF = N_ROUNDS_F;
    // const nRoundsP = N_ROUNDS_P[t - 2];

    let C = constants::ith_C(t - 2);
    let M = constants::ith_M(t - 2);
    let P = constants::ith_P(t - 2);
    let S = constants::ith_S(t - 2);

    use std::time::Instant;
    let now = Instant::now();

    let mut state: Vec<Fr> = Vec::new();

    state.push(Fr::zero());
    for inp in inputs {
        state.push(Fr::from_str(inp.to_string().as_str()).unwrap());
    }

    state = state
        .iter()
        .enumerate()
        .map(|(i, a)| -> Fr {
            let mut a_clone = a.clone();
            a_clone.add_assign(&mut Fr::from_str(C[i]).unwrap());
            return a_clone;
        })
        .collect::<Vec<Fr>>();

    // let mut state_clone: Vec<Fr> = Vec::new();
    for r in 0..N_ROUNDS_F / 2 - 1 {
        state = state.iter().map(|x| pow5(x)).collect();
        state = state
            .iter()
            .enumerate()
            .map(|(i, a)| -> Fr {
                let mut a_clone = a.clone();
                a_clone
                    .add_assign(&mut Fr::from_str(C[((r + 1) * t + i as u16) as usize]).unwrap());
                return a_clone;
            })
            .collect::<Vec<Fr>>();

        let state_clone: Vec<Fr> = state.clone();
        for i in 0..state_clone.len() {
            let mut acc = Fr::zero();
            for (j, x) in state_clone.iter().enumerate() {
                let mut x_clone = x.clone();
                x_clone.mul_assign(&Fr::from_str(M[j][i]).unwrap());
                acc.add_assign(&x_clone);
            }
            state[i] = acc;
        }
    }

    state = state.iter().map(|x| pow5(x)).collect();
    state = state
        .iter()
        .enumerate()
        .map(|(i, a)| {
            let mut a_clone = a.clone();
            a_clone.add_assign(
                &Fr::from_str(C[((N_ROUNDS_F / 2 - 1 + 1) * t + i as u16) as usize]).unwrap(),
            );
            return a_clone;
        })
        .collect::<Vec<Fr>>();

    let state_clone: Vec<Fr> = state.clone();
    for i in 0..state_clone.len() {
        let mut acc = Fr::zero();
        for (j, x) in state_clone.iter().enumerate() {
            let mut x_clone = x.clone();
            x_clone.mul_assign(&Fr::from_str(P[j][i]).unwrap());
            acc.add_assign(&x_clone);
        }
        state[i] = acc;
    }

    // const s0 = state.reduce((acc, a, j) => {
    //   return F.add(acc, F.mul(S[(t * 2 - 1) * r + j], a));
    // }, F.zero);

    for r in 0..n_rounds_P {
        state[0] = pow5(&state[0]);
        state[0].add_assign(&Fr::from_str(C[((N_ROUNDS_F / 2 + 1) * t + r) as usize]).unwrap());

        let mut s0 = Fr::zero();
        for (j, x) in state.iter().enumerate() {
            let mut x_clone = x.clone();
            x_clone.mul_assign(&Fr::from_str(S[((t * 2 - 1) * r + j as u16) as usize]).unwrap());
            s0.add_assign(&x_clone);
        }

        for k in 1..t {
            let mut s0_clone = state[0].clone();
            s0_clone.mul_assign(
                &Fr::from_str(S[((t * 2 - 1) * r + t + k - 1 as u16) as usize]).unwrap(),
            );
            state[k as usize].add_assign(&s0_clone);
        }

        state[0] = s0;
    }

    let elapsed = now.elapsed();
    println!("main: {:.2?}", elapsed);

    // println!("{:?}", state);
}

fn pow5(a: &Fr) -> Fr {
    let a1 = a.clone();
    let mut a2 = a.clone();
    a2.square();
    a2.square();
    a2.mul_assign(&a1);

    return a2;
}
