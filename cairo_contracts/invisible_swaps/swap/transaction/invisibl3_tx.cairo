from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from invisible_swaps.helpers.range_checks import range_checks_
from invisible_swaps.helpers.verify_sums import validate_fee_taken, take_fee
from invisible_swaps.helpers.partial_fill_helpers import (
    partial_fill_updates,
    update_note_dict,
    get_prev_fill_note_hash,
)
from invisible_swaps.swap.tx_hash.tx_hash import hash_transaction
from invisible_swaps.helpers.utils import (
    Invisibl3Order,
    Note,
    construct_new_note,
    sum_notes,
    hash_note,
)

func execute_invisibl3_transaction{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(
    order_hash : felt,
    notes_in_len : felt,
    notes_in : Note*,
    refund_note : Note,
    invisibl3_order : Invisibl3Order,
    spend_amount : felt,
    receive_amount : felt,
    fee_taken : felt,
):
    alloc_locals

    # * ORDER A ============================================================
    # If this is not the first fill return the last partial fill note hash else return 0
    let (prev_fill_hash : felt) = get_prev_fill_note_hash(order_hash)
    # let (prev_fill_hash_B : felt) = get_prev_fill_note_hash(order_B_hash)

    if prev_fill_hash == 0:
        # ! if this is the first fill
        first_fill(
            notes_in_len,
            notes_in,
            refund_note,
            invisibl3_order,
            spend_amount,
            receive_amount,
            order_hash,
            fee_taken,
        )
    else:
        # ! if the order was filled partially befor this
        later_fills(order_hash, invisibl3_order, receive_amount, spend_amount, fee_taken)
    end

    return ()
end

# ==================================================================================

func first_fill{
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(
    notes_in_len : felt,
    notes_in : Note*,
    refund_note : Note,
    invisibl3_order : Invisibl3Order,
    spend_amount : felt,
    receive_amount : felt,
    order_hash : felt,
    fee_taken : felt,
):
    alloc_locals

    # ? verify the sums match the refund and spend amounts
    let (sum_inputs : felt) = sum_notes(notes_in_len, notes_in, 0)
    assert sum_inputs - refund_note.amount = invisibl3_order.amount_spent

    # ? Verify all values are in a certain range
    range_checks_(invisibl3_order, refund_note, spend_amount)

    # ? Verify consistency of amounts swaped
    assert_le(
        spend_amount * invisibl3_order.amount_received,
        receive_amount * invisibl3_order.amount_spent,
    )

    # ? Verify the fee taken is consistent with the order
    validate_fee_taken(
        fee_taken, invisibl3_order.fee_limit, receive_amount, invisibl3_order.amount_received
    )

    # ? take a fee
    take_fee(invisibl3_order.token_received, fee_taken)

    local swap_note_idx : felt
    %{
        ids.swap_note_idx = order_indexes["swap_note_idx"]
        if ids.notes_in_len > 1:
            note_in2_idx = memory[ids.notes_in.address_ + NOTE_SIZE + INDEX_OFFSET]
            assert ids.swap_note_idx == note_in2_idx, "something funky happening with the swap note index"
    %}

    # let swap_received_amount = amount - fee
    # ? This is the note receiveing the funds of this swap
    let (swap_note : Note) = construct_new_note(
        invisibl3_order.dest_received_address,
        invisibl3_order.token_received,
        receive_amount - fee_taken,
        invisibl3_order.blinding_seed,
        swap_note_idx,
    )

    # todo verify signature !!!!

    update_note_dict{note_dict=note_dict}(notes_in_len, notes_in, refund_note, swap_note)

    # ! Only executed  if the order was filled partialy not completely ------------------
    let (condition1 : felt) = is_le(receive_amount, invisibl3_order.amount_received - 1)
    if condition1 == 0:
        return ()
    end

    let (new_fill_refund_note : Note) = partial_fill_updates(
        invisibl3_order, invisibl3_order.amount_spent, spend_amount, order_hash
    )

    local new_fill_refund_note_idx : felt
    %{ ids.new_fill_refund_note_idx = order_indexes["partial_fill_idx"] %}

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = new_fill_refund_note_idx
    assert note_dict_ptr.prev_value = 0
    assert note_dict_ptr.new_value = new_fill_refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end

func later_fills{
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(
    order_hash : felt,
    invisibl3_order : Invisibl3Order,
    receive_amount : felt,
    spend_amount : felt,
    fee_taken : felt,
):
    alloc_locals

    # ? This is the note that was refunded (leftover) from the previous fill
    local prev_fill_refund_note : Note
    %{
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index

        note_data = prev_fill_notes[ids.order_hash]
        address_pk = note_data["address_pk"]
        token = note_data["token"]
        amount = note_data["amount"]
        blinding_factor = note_data["blinding_factor"]
        index = note_data["index"]

        addr_ = ids.prev_fill_refund_note.address_
        memory[addr_ + ADDRESS_PK_OFFSET] = address_pk
        memory[addr_ + TOKEN_OFFSET] = token
        memory[addr_ + AMOUNT_OFFSET] = amount
        memory[addr_ + BLINDING_FACTOR_OFFSET] = blinding_factor
        memory[addr_ + INDEX_OFFSET] = index
    %}

    # ? Assert that this note was previously refunded for this order
    let (n_hash : felt) = hash_note(prev_fill_refund_note)
    let (prev_filled_hash) = get_prev_fill_note_hash(order_hash)
    assert n_hash = prev_filled_hash

    # ? Verify consistency of amounts swaped
    assert_le(
        spend_amount * invisibl3_order.amount_received,
        receive_amount * invisibl3_order.amount_spent,
    )

    # ? Verify the fee taken is consistent with the order
    validate_fee_taken(
        fee_taken, invisibl3_order.fee_limit, receive_amount, invisibl3_order.amount_received
    )

    # ? take a fee
    take_fee(invisibl3_order.token_received, fee_taken)

    # ? prevent spending more than the previous refund note
    assert_le(spend_amount, prev_fill_refund_note.amount)

    local swap_note_idx : felt
    %{ ids.swap_note_idx = order_indexes["swap_note_idx"] %}

    # ? This is the note receiveing the funds of this swap
    let (swap_note : Note) = construct_new_note(
        invisibl3_order.dest_received_address,
        invisibl3_order.token_received,
        receive_amount - fee_taken,
        invisibl3_order.blinding_seed,
        swap_note_idx,
    )

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = prev_fill_refund_note.index
    assert note_dict_ptr.prev_value = prev_fill_refund_note.amount
    assert note_dict_ptr.new_value = swap_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    # ! if the order was filled partialy not completely ---------------------------
    let (condition : felt) = is_le(receive_amount, prev_fill_refund_note.amount - 1)
    if condition == 0:
        return ()
    end

    let (new_fill_refund_note : Note) = partial_fill_updates(
        invisibl3_order, prev_fill_refund_note.amount, spend_amount, order_hash
    )

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = new_fill_refund_note.index
    assert note_dict_ptr.prev_value = 0
    assert note_dict_ptr.new_value = new_fill_refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end
