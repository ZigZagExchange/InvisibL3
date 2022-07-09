%builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from invisible_swaps.swap.invisible_swap import verify_swap

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # GLOBAL VERIABLES
    %{
        swap_input_data = program_input["swaps"] 
        prev_filled_dict_manager = {}
        prev_fill_notes = {}
        prev_fill_note_hashes = {}
        fee_tracker_dict_manager = {}
    %}

    # INITIALIZE DICTIONARIES ===========================
    local note_dict : DictAccess*
    local partial_fill_dict : DictAccess*
    local fee_tracker_dict : DictAccess*
    %{
        ids.note_dict = segments.add()
        ids.partial_fill_dict = segments.add()
        ids.fee_tracker_dict = segments.add()
    %}
    let note_dict_start = note_dict
    let partial_fill_dict_start = partial_fill_dict
    let fee_tracker_dict_start = fee_tracker_dict

    # ================================================

    %{
        import time
        t1 = time.time()
    %}
    execute_multiswap{
        note_dict=note_dict, partial_fill_dict=partial_fill_dict, fee_tracker_dict=fee_tracker_dict
    }()
    %{
        t2 = time.time()
        print("multiswap time: ", t2-t1)
    %}

    # ================================================

    local squashed_note_dict : DictAccess*
    %{ ids.squashed_note_dict = segments.add() %}
    let (squashed_note_dict_end) = squash_dict(
        dict_accesses=note_dict_start, dict_accesses_end=note_dict, squashed_dict=squashed_note_dict
    )
    local squashed_note_dict_len = squashed_note_dict_end - squashed_note_dict

    # ================================================

    local squashed_fee_tracker_dict : DictAccess*
    %{ ids.squashed_fee_tracker_dict = segments.add() %}
    let (squashed_fee_tracker_dict_end) = squash_dict(
        dict_accesses=fee_tracker_dict_start,
        dict_accesses_end=fee_tracker_dict,
        squashed_dict=squashed_fee_tracker_dict,
    )
    local squashed_fee_tracker_dict_len = squashed_fee_tracker_dict_end - squashed_fee_tracker_dict

    # ================================================

    %{
        # print("note_dict")
        # l = int(ids.squashed_note_dict_len/ids.DictAccess.SIZE)
        # for i in range(l):
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +0])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +1])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +2])
        #     print("======")

        print("fee_tracker_dict")
        l2 = int(ids.squashed_fee_tracker_dict_len/ids.DictAccess.SIZE)
        for i in range(l2):
            print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +0])
            print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +1])
            print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +2])
            print("======")
    %}

    %{ print("all good") %}

    return ()
end

func execute_multiswap{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}():
    alloc_locals

    if nondet %{ len(swap_input_data) == 0 %} != 0:
        return ()
    end

    %{ current_swap = swap_input_data.pop(0) %}
    verify_swap{
        note_dict=note_dict, partial_fill_dict=partial_fill_dict, fee_tracker_dict=fee_tracker_dict
    }()

    return execute_multiswap()
end
