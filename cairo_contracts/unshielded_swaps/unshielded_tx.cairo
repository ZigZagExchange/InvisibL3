# %builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_lt, assert_le
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
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
from starkware.cairo.common.signature import verify_ecdsa_signature

# from unshielded_swaps.update_accounts import update_accounts
from unshielded_swaps.constants import MAX_AMOUNT, MAX_NONCE, MAX_EXPIRATION_TIMESTAMP
from unshielded_swaps.account_state import (
    AccountSpace,
    LimitOrder,
    limit_order_hash,
    new_account_space,
)
from unshielded_swaps.update_accounts import update_accounts

# Add order dict to account state
func execute_transaction{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    account_dict : DictAccess*,
    order_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(limit_order : LimitOrder, spent_amount : felt, received_amount : felt, fee_taken : felt):
    alloc_locals

    local prev_filled_amount : felt
    local new_filled_amount : felt

    let (order_hash : felt) = limit_order_hash(limit_order)
    %{
        try:
            ids.prev_filled_amount = fills[ids.order_hash]
        except:
            ids.prev_filled_amount = 0
    %}

    assert_lt(limit_order.amount_spent, MAX_AMOUNT)
    assert_lt(limit_order.amount_received, MAX_AMOUNT)

    new_filled_amount = prev_filled_amount + spent_amount
    assert_le(new_filled_amount, limit_order.amount_spent)

    assert_lt(limit_order.nonce, MAX_NONCE)

    # let global_expiration_timestamp = ...?
    # assert_lt(global_expiration_timestamp, limit_order.expiration_timestamp)
    assert_lt(limit_order.expiration_timestamp, MAX_EXPIRATION_TIMESTAMP)

    # Checks the actual ratio is at least as good as the requested(signed) ratio
    assert_le(
        spent_amount * limit_order.amount_received, received_amount * limit_order.amount_spent
    )

    %{ fills[ids.order_hash] = ids.new_filled_amount %}

    let order_dict_ptr : DictAccess* = order_dict
    assert order_dict_ptr.key = order_hash
    assert order_dict_ptr.prev_value = prev_filled_amount
    assert order_dict_ptr.new_value = new_filled_amount

    let order_dict = order_dict + DictAccess.SIZE

    update_accounts(spent_amount, received_amount, limit_order, fee_taken)

    verify_ecdsa_signature(
        message=order_hash,
        public_key=limit_order.public_key,
        signature_r=limit_order.signature_r,
        signature_s=limit_order.signature_s,
    )

    # %{ print("transaction verified") %}

    # todo verify limit order signature
    # todo if partial order only update by that amount
    # todo take a fee depending on the amount of the order
    # todo update the account balances in account_dict

    return ()
end
