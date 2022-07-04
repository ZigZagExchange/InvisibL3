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

from merkle_updates.merkle_updates import check_merkle_tree_updates
from unshielded_swaps.constants import MAX_AMOUNT
from unshielded_swaps.account_state import AccountSpace, LimitOrder, account_space_hash
from unshielded_swaps.unshielded_tx import execute_transaction

# func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
#     ):
#     alloc_locals

# local prev_root : felt
#     local new_root : felt

# local account_dict : DictAccess*
#     local order_dict : DictAccess*
#     # ! fee tracker dict should be initialized with zeros!
#     local fee_tracker_dict : DictAccess*

# local limit_orderA : LimitOrder
#     local limit_orderB : LimitOrder

# local limit_orderA2 : LimitOrder
#     local limit_orderB2 : LimitOrder

# let (__fp__, _) = get_fp_and_pc()
#     handle_inputs(
#         &prev_root,
#         &new_root,
#         &account_dict,
#         &order_dict,
#         &fee_tracker_dict,
#         &limit_orderA,
#         &limit_orderB,
#         &limit_orderA2,
#         &limit_orderB2,
#     )

# let acc_dict_start : DictAccess* = account_dict
#     let order_dict_start : DictAccess* = order_dict
#     let fee_tracker_dict_start : DictAccess* = fee_tracker_dict

# # todo temp delete this
#     %{ i = 0 %}
#     verify_swap{
#         account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
#     }(limit_orderA, limit_orderB)

# verify_swap{
#         account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
#     }(limit_orderA2, limit_orderB2)

# # =============================================================
#     # Squash the order dict.
#     local squashed_order_dict : DictAccess*
#     %{ ids.squashed_order_dict = segments.add() %}
#     let (squashed_order_dict_end) = squash_dict(
#         dict_accesses=order_dict_start,
#         dict_accesses_end=order_dict,
#         squashed_dict=squashed_order_dict,
#     )
#     local squashed_order_dict_len = squashed_order_dict_end - squashed_order_dict

# # Squash the account dict
#     local squashed_account_dict : DictAccess*
#     %{ ids.squashed_account_dict = segments.add() %}
#     let (squashed_account_dict_end) = squash_dict(
#         dict_accesses=acc_dict_start,
#         dict_accesses_end=account_dict,
#         squashed_dict=squashed_account_dict,
#     )
#     local squashed_account_dict_len = squashed_account_dict_end - squashed_account_dict

# # Squash the fee tracker dict
#     local squashed_fee_tracker_dict : DictAccess*
#     %{ ids.squashed_fee_tracker_dict = segments.add() %}
#     let (squashed_fee_tracker_dict_end) = squash_dict(
#         dict_accesses=fee_tracker_dict_start,
#         dict_accesses_end=fee_tracker_dict,
#         squashed_dict=squashed_fee_tracker_dict,
#     )
#     local squashed_fee_tracker_dict_len = squashed_fee_tracker_dict_end - squashed_fee_tracker_dict

# # %{
#     #     print("account_dict")
#     #     l2 = int(ids.squashed_account_dict_len/ids.DictAccess.SIZE)
#     #     for i in range(l2):
#     #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +0])
#     #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +1])
#     #         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +2])
#     #         print("======")
#     # %}

# %{ assert ids.squashed_account_dict_len % 3 == 0 %}
#     let num_updates = squashed_account_dict_len / 3
#     check_merkle_tree_updates(prev_root, new_root, squashed_account_dict, num_updates)

# %{ print("Swap and merkle updates are valid") %}

# return ()
# end

func verify_swap{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    ecdsa_ptr : SignatureBuiltin*,
    range_check_ptr,
    account_dict : DictAccess*,
    order_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}():
    alloc_locals

    local limit_orderA : LimitOrder
    local limit_orderB : LimitOrder

    let (__fp__, _) = get_fp_and_pc()
    handle_current_swap_inputs(&limit_orderA, &limit_orderB)

    assert limit_orderA.token_spent = limit_orderB.token_received
    assert limit_orderA.token_received = limit_orderB.token_spent

    local spend_amountA : felt
    local spend_amountB : felt
    local fee_takenA : felt
    local fee_takenB : felt

    %{
        spend_amountA = min(ids.limit_orderA.amount_spent, ids.limit_orderB.amount_received) 
        spend_amountB = min(ids.limit_orderA.amount_received, ids.limit_orderB.amount_spent) 

        ids.spend_amountA = spend_amountA
        ids.spend_amountB = spend_amountB

        ids.fee_takenA = current_swap["fee_A"]
        ids.fee_takenB = current_swap["fee_B"]

        assert spend_amountA/spend_amountB <= ids.limit_orderA.amount_spent/ids.limit_orderA.amount_received, "user A is getting the short end of the stick in this trade"
        assert spend_amountB/spend_amountA <= ids.limit_orderB.amount_spent/ids.limit_orderB.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    assert_le(spend_amountA, MAX_AMOUNT)
    assert_le(spend_amountB, MAX_AMOUNT)

    execute_transaction{
        account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
    }(limit_orderA, spend_amountA, spend_amountB, fee_takenA)

    execute_transaction{
        account_dict=account_dict, order_dict=order_dict, fee_tracker_dict=fee_tracker_dict
    }(limit_orderB, spend_amountB, spend_amountA, fee_takenB)

    %{ print("swap executed successfully") %}

    return ()
end

func handle_current_swap_inputs{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    limit_orderA : LimitOrder*, limit_orderB : LimitOrder*
):
    alloc_locals

    %{
        LIMIT_ORDER_SIZE = ids.LimitOrder.SIZE
        LIMIT_ORDER_NONCE_OFFSET = ids.LimitOrder.nonce
        LIMIT_ORDER_PUBLIC_KEY_OFFSET = ids.LimitOrder.public_key
        LIMIT_ORDER_EXPIRATION_TIMESTAMP_OFFSET = ids.LimitOrder.expiration_timestamp
        LIMIT_ORDER_SIGNATURE_R_OFFSET = ids.LimitOrder.signature_r
        LIMIT_ORDER_SIGNATURE_S_OFFSET = ids.LimitOrder.signature_s
        LIMIT_ORDER_TOKEN_SPENT_OFFSET = ids.LimitOrder.token_spent
        LIMIT_ORDER_TOKEN_RECEIVED_OFFSET = ids.LimitOrder.token_received
        LIMIT_ORDER_AMOUNT_SPENT_OFFSET = ids.LimitOrder.amount_spent
        LIMIT_ORDER_AMOUNT_RECEIVED_OFFSET = ids.LimitOrder.amount_received
        LIMIT_ORDER_SPENDER_ACCOUNT_OFFSET = ids.LimitOrder.spender_account_index
        LIMIT_ORDER_RECEIVER_ACCOUNT_OFFSET = ids.LimitOrder.receiver_account_index
        LIMIT_ORDER_FEE_LIMIT_OFFSET = ids.LimitOrder.fee_limit

        #? LIMIT ORDERS ------------------------------------------------------

        orderA = current_swap["limit_order_A"]
        orderB = current_swap["limit_order_B"]

         # LIMIT ORDER A
        lim_orderA_addr = ids.limit_orderA.address_
        memory[lim_orderA_addr + LIMIT_ORDER_NONCE_OFFSET] = int(orderA["nonce"])
        memory[lim_orderA_addr + LIMIT_ORDER_PUBLIC_KEY_OFFSET] = int(orderA["public_key"])
        memory[lim_orderA_addr + LIMIT_ORDER_EXPIRATION_TIMESTAMP_OFFSET] = int(orderA["expiration_timestamp"])
        memory[lim_orderA_addr + LIMIT_ORDER_SIGNATURE_R_OFFSET] = int(orderA["signature"][0])
        memory[lim_orderA_addr + LIMIT_ORDER_SIGNATURE_S_OFFSET] = int(orderA["signature"][1])
        memory[lim_orderA_addr + LIMIT_ORDER_TOKEN_SPENT_OFFSET] = int(orderA["token_spent"])
        memory[lim_orderA_addr + LIMIT_ORDER_TOKEN_RECEIVED_OFFSET] = int(orderA["token_received"])
        memory[lim_orderA_addr + LIMIT_ORDER_AMOUNT_SPENT_OFFSET] = int(orderA["amount_spent"])
        memory[lim_orderA_addr + LIMIT_ORDER_AMOUNT_RECEIVED_OFFSET] = int(orderA["amount_received"])
        memory[lim_orderA_addr + LIMIT_ORDER_SPENDER_ACCOUNT_OFFSET] = int(orderA["spender_account_idx"])
        memory[lim_orderA_addr + LIMIT_ORDER_RECEIVER_ACCOUNT_OFFSET] = int(orderA["receiver_account_idx"])
        memory[lim_orderA_addr + LIMIT_ORDER_FEE_LIMIT_OFFSET] = int(orderA["fee_limit"])

        # LIMIT ORDER B
        lim_orderB_addr = ids.limit_orderB.address_
        memory[lim_orderB_addr + LIMIT_ORDER_NONCE_OFFSET] = int(orderB["nonce"])
        memory[lim_orderB_addr + LIMIT_ORDER_PUBLIC_KEY_OFFSET] = int(orderB["public_key"])
        memory[lim_orderB_addr + LIMIT_ORDER_EXPIRATION_TIMESTAMP_OFFSET] = int(orderB["expiration_timestamp"])
        memory[lim_orderB_addr + LIMIT_ORDER_SIGNATURE_R_OFFSET] = int(orderB["signature"][0])
        memory[lim_orderB_addr + LIMIT_ORDER_SIGNATURE_S_OFFSET] = int(orderB["signature"][1])
        memory[lim_orderB_addr + LIMIT_ORDER_TOKEN_SPENT_OFFSET] = int(orderB["token_spent"])
        memory[lim_orderB_addr + LIMIT_ORDER_TOKEN_RECEIVED_OFFSET] = int(orderB["token_received"])
        memory[lim_orderB_addr + LIMIT_ORDER_AMOUNT_SPENT_OFFSET] = int(orderB["amount_spent"])
        memory[lim_orderB_addr + LIMIT_ORDER_AMOUNT_RECEIVED_OFFSET] = int(orderB["amount_received"])
        memory[lim_orderB_addr + LIMIT_ORDER_SPENDER_ACCOUNT_OFFSET] = int(orderB["spender_account_idx"])
        memory[lim_orderB_addr + LIMIT_ORDER_RECEIVER_ACCOUNT_OFFSET] = int(orderB["receiver_account_idx"])
        memory[lim_orderB_addr + LIMIT_ORDER_FEE_LIMIT_OFFSET] = int(orderB["fee_limit"])
    %}

    return ()
end

# %{
#     print("order_dict")
#     l1 = int(ids.squashed_order_dict_len/ids.DictAccess.SIZE)
#     for i in range(l1):
#         print(memory[ids.squashed_order_dict.address_ + i*ids.DictAccess.SIZE +0])
#         print(memory[ids.squashed_order_dict.address_ + i*ids.DictAccess.SIZE +1])
#         print(memory[ids.squashed_order_dict.address_ + i*ids.DictAccess.SIZE +2])
#         print("======")
# print("account_dict")
#     l2 = int(ids.squashed_account_dict_len/ids.DictAccess.SIZE)
#     for i in range(l2):
#         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +0])
#         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +1])
#         print(memory[ids.squashed_account_dict.address_ + i*ids.DictAccess.SIZE +2])
#         print("======")
# print("fee_tracker_dict")
#     l3 = int(ids.squashed_fee_tracker_dict_len/ids.DictAccess.SIZE)
#     for i in range(l3):
#         print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +0])
#         print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +1])
#         print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +2])
#         print("======")
# %}
