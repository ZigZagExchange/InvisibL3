from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_lt, assert_nn, assert_le
from starkware.cairo.common.dict_access import DictAccess

from invisible_swaps.helpers.utils import Note

func verify_sums{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_in_len : felt,
    notes_in : Note*,
    notes_out_len : felt,
    notes_out : Note*,
    expected_fee : felt,
    fee_limit : felt,
) -> (res):
    alloc_locals

    let (sum_in : felt) = sum_notes(notes_in_len, notes_in, 0)
    let (sum_out : felt) = sum_notes(notes_out_len, notes_out, 0)

    let fee = sum_in - sum_out
    assert_nn(fee)
    assert_le(expected_fee, fee)
    assert_le(fee, fee_limit)

    return (fee)
end

func sum_notes{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_len : felt, notes : Note*, sum : felt
) -> (sum):
    alloc_locals

    if arr_len == 0:
        return (sum)
    end

    let note : Note = notes[0]
    let sum = sum + note.amount

    return sum_notes(notes_len - 1, &notes[1], sum)
end

func take_fee{fee_tracker_dict : DictAccess*}(fee : felt):
    let fee_tracker_dict_ptr : DictAccess* = fee_tracker_dict
    assert fee_tracker_dict_ptr.key = limit_order.token_received
    assert fee_tracker_dict_ptr.prev_value = prev_fee_sum
    assert fee_tracker_dict_ptr.new_value = prev_fee_sum + fee_taken

    let fee_tracker_dict = fee_tracker_dict + DictAccess.SIZE

    return ()
end

func update_order_dict{order_dict : DictAccess*}(
    order_hash : felt, prev_filled_amount : felt, new_filled_amount : felt
):
    let order_dict_ptr : DictAccess* = order_dict
    assert order_dict_ptr.key = order_hash
    assert order_dict_ptr.prev_value = prev_filled_amount
    assert order_dict_ptr.new_value = new_filled_amount

    let order_dict = order_dict + DictAccess.SIZE

    return ()
end

func update_note_dict{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : Note*, notes_out_len : felt, notes_out : Note*
):
    alloc_locals

    local max_len : felt
    %{ ids.max_len = max(notes_in_len, notes_out_len) %}

    return ()
end

func _update_note_dict_inner{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : felt*, notes_out_len : felt, notes_out : felt*
):
    # if nondet %{ len(transactions) == 0 %} != 0:

    let order_dict_ptr : DictAccess* = order_dict
    assert order_dict_ptr.key = order_hash
    assert order_dict_ptr.prev_value = prev_filled_amount
    assert order_dict_ptr.new_value = new_filled_amount

    let order_dict = order_dict + DictAccess.SIZE

    return _update_note_dict_inner()
end

func validate_fee_taken{pedersen_ptr : HashBuiltin*, range_check_ptr, account_dict : DictAccess*}(
    fee_taken : felt, fee_limit : felt, actual_received_amount : felt, order_received_amount : felt
):
    # Maybe remove fee_limit and just use fee_taken signed by user
    tempvar x = fee_taken * order_received_amount
    tempvar y = fee_limit * actual_received_amount
    assert_le(x, y)
    return ()
end
