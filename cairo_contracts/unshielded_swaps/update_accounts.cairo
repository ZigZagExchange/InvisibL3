from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.math import assert_lt, assert_le

from unshielded_swaps.constants import MAX_AMOUNT, ZERO_LEAF
from unshielded_swaps.account_state import (
    LimitOrder,
    AccountSpace,
    account_space_hash,
    new_account_space,
)

func update_accounts{
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    account_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(amount_spent : felt, amount_received : felt, limit_order : LimitOrder, fee_taken : felt):
    alloc_locals

    # take the fee from the received token
    validate_fee_taken(
        fee_taken, limit_order.fee_limit, amount_received, limit_order.amount_received
    )

    local spender_account_space : AccountSpace
    local receiver_account_space : AccountSpace
    %{
        spender_idx_ = str(ids.limit_order.spender_account_index)
        receiver_idx_ = str(ids.limit_order.receiver_account_index)
        spender_account = account_spaces[spender_idx_]
        receiver_account = account_spaces[receiver_idx_]

        ACCOUNT_STATE_SIZE = ids.AccountSpace.SIZE
        ACCOUNT_STATE_PUBLIC_KEY_OFFSET = ids.AccountSpace.public_key
        ACCOUNT_STATE_TOKEN_ID_OFFSET = ids.AccountSpace.token_id
        ACCOUNT_STATE_BALANCE_OFFSET = ids.AccountSpace.balance

        spender_acc = ids.spender_account_space
        memory[spender_acc.address_ + ACCOUNT_STATE_PUBLIC_KEY_OFFSET] = spender_account[0]
        memory[spender_acc.address_ + ACCOUNT_STATE_TOKEN_ID_OFFSET] = spender_account[1]
        memory[spender_acc.address_ + ACCOUNT_STATE_BALANCE_OFFSET] = spender_account[2]

        receiver_acc = ids.receiver_account_space
        memory[receiver_acc.address_ + ACCOUNT_STATE_PUBLIC_KEY_OFFSET] = receiver_account[0]
        memory[receiver_acc.address_ + ACCOUNT_STATE_TOKEN_ID_OFFSET] = receiver_account[1]
        memory[receiver_acc.address_ + ACCOUNT_STATE_BALANCE_OFFSET] = receiver_account[2]
    %}

    # TAKE A FEE
    local prev_fee_sum : felt
    %{
        try:
            ids.prev_fee_sum = fee_sums[ids.limit_order.token_received]
            fee_sums[ids.limit_order.token_received] += ids.fee_taken
        except:
            ids.prev_fee_sum = 0
            fee_sums[ids.limit_order.token_received] = ids.fee_taken
    %}

    let fee_tracker_dict_ptr : DictAccess* = fee_tracker_dict
    assert fee_tracker_dict_ptr.key = limit_order.token_received
    assert fee_tracker_dict_ptr.prev_value = prev_fee_sum
    assert fee_tracker_dict_ptr.new_value = prev_fee_sum + fee_taken

    let fee_tracker_dict = fee_tracker_dict + DictAccess.SIZE

    update_account_space(spender_account_space, -amount_spent, limit_order.spender_account_index)

    let account_dict = account_dict + DictAccess.SIZE

    update_account_space(
        receiver_account_space, amount_received - fee_taken, limit_order.receiver_account_index
    )
    let account_dict = account_dict + DictAccess.SIZE

    %{
        spender_account[2] -= ids.amount_spent
        account_spaces[spender_idx_] = spender_account

        receiver_account[2] += ids.amount_received-ids.fee_taken
        account_spaces[receiver_idx_] = receiver_account

        del spender_idx_, receiver_idx_
    %}

    return ()
end

func update_account_space{range_check_ptr, pedersen_ptr : HashBuiltin*, account_dict : DictAccess*}(
    spender_acc : AccountSpace, diff : felt, account_idx : felt
):
    alloc_locals

    local prev_acc_hash : felt
    local balance_after : felt
    if spender_acc.balance == 0:
        return _update_account_dict(
            spender_acc.public_key, spender_acc.token_id, diff, ZERO_LEAF, account_idx
        )
    end

    let balance_after = spender_acc.balance + diff
    assert_lt(balance_after, MAX_AMOUNT)

    let (prev_acc_hash : felt) = account_space_hash(spender_acc)

    return _update_account_dict(
        spender_acc.public_key, spender_acc.token_id, balance_after, prev_acc_hash, account_idx
    )
end

func _update_account_dict{range_check_ptr, pedersen_ptr : HashBuiltin*, account_dict : DictAccess*}(
    pub_key : felt, token_id : felt, balance_after, prev_acc_hash : felt, account_idx : felt
):
    let updated_spender_acc : AccountSpace = new_account_space(pub_key, token_id, balance_after)

    let (new_acc_hash : felt) = account_space_hash(updated_spender_acc)

    let dict_ptr : DictAccess* = account_dict
    assert dict_ptr.key = account_idx
    assert dict_ptr.prev_value = prev_acc_hash
    assert dict_ptr.new_value = new_acc_hash

    %{
        pk = ids.updated_spender_acc.public_key
        t = ids.updated_spender_acc.token_id
        bal = ids.updated_spender_acc.balance
        account_spaces[ids.account_idx] = [pk, t, bal]
    %}

    return ()
end

func validate_fee_taken{pedersen_ptr : HashBuiltin*, range_check_ptr, account_dict : DictAccess*}(
    fee_taken : felt, fee_limit : felt, actual_received_amount : felt, order_received_amount : felt
):
    tempvar x = fee_taken * order_received_amount
    tempvar y = fee_limit * actual_received_amount
    assert_le(x, y)
    return ()
end
