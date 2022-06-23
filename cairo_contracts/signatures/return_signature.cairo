%builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_double, ec_add, ec_mul, ec_negate
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from helpers.utils import generator

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    let (local G : EcPoint) = generator()

    local address : EcPoint
    local tx_hash : felt
    local c : felt
    local r : felt
    %{
        ids.tx_hash = program_input["ret_hash"]
        sig = program_input["ret_sig"]
        ids.c = sig[0]
        ids.r = sig[1]

        ret_addr = program_input["ret_addr"]
        address = ids.address.address_

        POINT_SIZE = ids.EcPoint.SIZE
        X_OFFSET = ids.EcPoint.x
        Y_OFFSET = ids.EcPoint.y

        BIG_INT_SIZE = ids.BigInt3.SIZE
        BIG_INT_0_OFFSET = ids.BigInt3.d0
        BIG_INT_1_OFFSET = ids.BigInt3.d1
        BIG_INT_2_OFFSET = ids.BigInt3.d2

        # addr = [x:[d0,d1,d2], y:[d0,d1,d2]]
        addr_x = address + X_OFFSET
        addr_y = address + Y_OFFSET

        memory[addr_x + BIG_INT_0_OFFSET] = ret_addr[0][0]
        memory[addr_x + BIG_INT_1_OFFSET] = ret_addr[0][1]
        memory[addr_x + BIG_INT_2_OFFSET] = ret_addr[0][2]

        memory[addr_y + BIG_INT_0_OFFSET] = ret_addr[1][0]
        memory[addr_y + BIG_INT_1_OFFSET] = ret_addr[1][1]
        memory[addr_y + BIG_INT_2_OFFSET] = ret_addr[1][2]
    %}

    verify_ret_addr_sig(address, tx_hash, c, r)

    %{ print("All good") %}

    return ()
end

func verify_ret_addr_sig{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : EcPoint, tx_hash : felt, c : felt, r : felt
):
    alloc_locals

    let (local empty_arr : felt*) = alloc()

    let (c_input : EcPoint) = get_c_input(address, c, r)

    let (cx : Uint256) = bigint_to_uint256(c_input.x)

    let (c_hash : felt) = hash2{hash_ptr=pedersen_ptr}(cx.high, cx.low)

    let (c_prime : felt) = hash2{hash_ptr=pedersen_ptr}(tx_hash, c_hash)

    with_attr error_message("!====== (c_prime and c don't match verify_sig) ======!"):
        assert c_prime = c
    end

    return ()
end

func get_c_input{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : EcPoint, c_ : felt, r_ : felt
) -> (res : EcPoint):
    alloc_locals
    let (local G : EcPoint) = generator()

    let (c_high : felt, c_low : felt) = split_felt(c_)
    let c_trimmed : felt = c_high + c_low

    let (high, low) = split_felt(c_trimmed)
    let _c : Uint256 = Uint256(low=low, high=high)
    let (c : BigInt3) = uint256_to_bigint(_c)

    let (high, low) = split_felt(r_)
    let _r : Uint256 = Uint256(low=low, high=high)
    let (r : BigInt3) = uint256_to_bigint(_r)

    # c_input = rG - K + c*G
    let (rG : EcPoint) = ec_mul(G, r)
    let (cG : EcPoint) = ec_mul(G, c)

    let (K_neg : EcPoint) = ec_negate(address)

    let (rG_minus_K : EcPoint) = ec_add(rG, K_neg)

    let (c_input : EcPoint) = ec_add(rG_minus_K, cG)

    return (c_input)
end
