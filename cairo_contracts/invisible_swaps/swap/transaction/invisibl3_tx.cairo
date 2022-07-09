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

from invisibl3_swaps.helpers.utils import Invisibl3Order, Note, make_new_note, sum_notes
from invisibl3_swaps.helpers.partial_fill_helpers import partial_fill_updates, update_note_dict
from invisibl3_swaps.transaction.tx_hash.tx_hash import hash_transaction

func execute_invisibl3_transaction{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    order_A_hash : felt,
    notes_in_A_len : felt,
    notes_in_A : Note*,
    refund_note_A : Note,
    invisibl3_order_A : Invisibl3Order,
    spend_amountA : felt,
    spend_amountB : felt,
):
    alloc_locals

    # * ORDER A ============================================================
    # If this is not the first fill return the last partial fill note hash else return 0
    let (prev_fill_hash_A : felt) = get_prev_fill_note_hash(order_A_hash)
    # let (prev_fill_hash_B : felt) = get_prev_fill_note_hash(order_B_hash)

    if prev_fill_hash_A == 0:
        %{ print("First fill A") %}
        # ! if this is the first fill
        first_fill(
            notes_in_A_len,
            notes_in_A,
            refund_note_A,
            invisibl3_order_A,
            spend_amountB,
            spend_amountA,
            order_A_hash,
        )
    else:
        # ! if the order was filled partially befor this
        later_fills(order_A_hash, invisibl3_order_A, spend_amountB, spend_amountA)
    end

    return ()
end

# ==================================================================================

func first_fill{range_check_ptr, note_dict : DictAccess*, partial_fill_dict : DictAccess*}(
    notes_in_A_len : felt,
    notes_in_A : Note*,
    refund_note_A : Note,
    test_order_A : TestOrder,
    spend_amountB : felt,
    spend_amountA : felt,
    order_A_hash : felt,
):
    alloc_locals

    # sum the input notes to get the total amount being sent
    let (sum_inputs_A : felt) = sum_notes(notes_in_A_len, notes_in_A, 0)

    # verify the sums match the refund and spend amounts
    assert sum_inputs_A - refund_note_A.amount = test_order_A.amount_spent

    assert_le(0, refund_note_A.amount)
    assert_le(spend_amountA, test_order_A.amount_spent)
    # todo check some other consistencies (e.g. all nums are positive)

    local swap_note_idx : felt
    %{ ids.swap_note_idx = order_indexes["swap_note_idx"] %}

    # This is the note receiveing the funds of this swap
    let (swap_note_A : Note) = make_new_note(
        test_order_A.destination_address_pk,
        test_order_A.token_received,
        spend_amountB,
        test_order_A.blindings_seed,
        swap_note_idx,
    )

    # todo verify signature (add notes in indexes and refund note hash to the signature)

    update_note_dict{note_dict=note_dict}(notes_in_A_len, notes_in_A, refund_note_A, swap_note_A)

    # ! if the order was filled partialy not completely
    let (condition1 : felt) = is_le(spend_amountB, test_order_A.amount_received - 1)
    if condition1 == 0:
        return ()
    end

    %{ print(order_indexes["partial_fill_idx"]) %}

    let (new_fill_refund_note : Note) = partial_fill_updates(
        test_order_A, spend_amountA, order_A_hash, condition1, swap_note_A
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

func later_fills{range_check_ptr, note_dict : DictAccess*, partial_fill_dict : DictAccess*}(
    order_A_hash : felt, test_order_A : TestOrder, spend_amountB : felt, spend_amountA : felt
):
    alloc_locals

    local prev_fill_refund_note : Note

    %{
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index

        note_data = prev_fill_notes[ids.order_A_hash]
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

    let (n_hash : felt) = hash_note(prev_fill_refund_note)

    let (prev_filled_hash) = get_prev_fill_note_hash(order_A_hash)

    assert n_hash = prev_filled_hash

    # todo where this is sent and how to signal the amounts so the user can always retreive them
    let (swap_note_A : Note) = make_new_note(
        test_order_A.destination_address_pk,
        test_order_A.token_received,
        spend_amountB,
        test_order_A.blindings_seed,
        1,
    )

    # prevent spending more than the previous refund note
    assert_le(spend_amountA, prev_fill_refund_note.amount)

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = prev_fill_refund_note.index
    assert note_dict_ptr.prev_value = prev_fill_refund_note.amount
    assert note_dict_ptr.new_value = swap_note_A.amount

    let note_dict = note_dict + DictAccess.SIZE

    # ! if the order was filled partialy not completely ---------------------------
    let (condition1 : felt) = is_le(spend_amountB, prev_fill_refund_note.amount - 1)
    if condition1 == 0:
        return ()
    end

    let (new_fill_refund_note : Note) = partial_fill_updates(
        test_order_A, spend_amountA, order_A_hash, condition1, prev_fill_refund_note
    )

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = new_fill_refund_note.index
    assert note_dict_ptr.prev_value = 0
    assert note_dict_ptr.new_value = new_fill_refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end
