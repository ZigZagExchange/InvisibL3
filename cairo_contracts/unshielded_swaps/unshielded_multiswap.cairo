# %builtins output pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

# from unshielded_swaps.unshielded_swap import

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
    ):
    alloc_locals

    local prev_root : felt
    local new_root : felt

    local account_dict : DictAccess*
    local order_dict : DictAccess*
    # ! fee tracker dict should be initialized with zeros!
    local fee_tracker_dict : DictAccess*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(&prev_root, &new_root, &account_dict, &order_dict, &fee_tracker_dict)

    let acc_dict_start : DictAccess* = account_dict
    let order_dict_start : DictAccess* = order_dict
    let fee_tracker_dict_start : DictAccess* = fee_tracker_dict

    # todo temp delete this
    %{ i = 0 %}
    # Replace with multiswap loop
    verify_swap{
        account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
    }(limit_orderA, limit_orderB)

    verify_swap{
        account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
    }(limit_orderA2, limit_orderB2)

    # =============================================================
    # Squash the order dict.
    local squashed_order_dict : DictAccess*
    %{ ids.squashed_order_dict = segments.add() %}
    let (squashed_order_dict_end) = squash_dict(
        dict_accesses=order_dict_start,
        dict_accesses_end=order_dict,
        squashed_dict=squashed_order_dict,
    )
    local squashed_order_dict_len = squashed_order_dict_end - squashed_order_dict

    # Squash the account dict
    local squashed_account_dict : DictAccess*
    %{ ids.squashed_account_dict = segments.add() %}
    let (squashed_account_dict_end) = squash_dict(
        dict_accesses=acc_dict_start,
        dict_accesses_end=account_dict,
        squashed_dict=squashed_account_dict,
    )
    local squashed_account_dict_len = squashed_account_dict_end - squashed_account_dict

    # Squash the fee tracker dict
    local squashed_fee_tracker_dict : DictAccess*
    %{ ids.squashed_fee_tracker_dict = segments.add() %}
    let (squashed_fee_tracker_dict_end) = squash_dict(
        dict_accesses=fee_tracker_dict_start,
        dict_accesses_end=fee_tracker_dict,
        squashed_dict=squashed_fee_tracker_dict,
    )
    local squashed_fee_tracker_dict_len = squashed_fee_tracker_dict_end - squashed_fee_tracker_dict

    # %{
    #     print("account_dict")
    #     l2 = int(ids.squashed_account_dict_len/ids.DictAccess.SIZE)
    #     for i in range(l2):
    #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +0])
    #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +1])
    #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +2])
    #         print("======")
    # %}

    %{ assert ids.squashed_account_dict_len % 3 == 0 %}
    let num_updates = squashed_account_dict_len / 3
    check_merkle_tree_updates(prev_root, new_root, squashed_account_dict, num_updates)

    %{ print("Swap and merkle updates are valid") %}

    return ()
end

func handle_inputs{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_root : felt*,
    new_root : felt*,
    account_dict : DictAccess**,
    order_dict : DictAccess**,
    fee_tracker_dict : DictAccess**,
):
    alloc_locals

    return ()
end
