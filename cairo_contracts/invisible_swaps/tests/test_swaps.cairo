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
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

# from invisible_swaps.helpers.verify_sums import sum_notes

struct TestOrder:
    member amount_spent : felt
    member amount_received : felt
    member blindings_seed : felt
    member destination_address_pk : felt
    member token_spent : felt
    member token_received : felt
end

struct Note:
    member address_pk : felt
    member token : felt
    member amount : felt
    member blinding_factor : felt
    member index : felt
end

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    verify_swap()

    %{ print("all good") %}

    return ()
end

func verify_swap{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local test_order_A : TestOrder
    local test_order_B : TestOrder

    local notes_in_A_len : felt
    local notes_in_A : Note*
    local refund_note_A : Note

    local notes_in_B_len : felt
    local notes_in_B : Note*
    local refund_note_B : Note

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &test_order_A,
        &test_order_B,
        &notes_in_A_len,
        &notes_in_A,
        &refund_note_A,
        &notes_in_B_len,
        &notes_in_B,
        &refund_note_B,
    )

    assert test_order_A.token_spent = test_order_B.token_received
    assert test_order_A.token_received = test_order_B.token_spent

    local spend_amountA : felt
    local spend_amountB : felt
    # local fee_takenA : felt
    # local fee_takenB : felt
    %{
        spend_amountA = ids.test_order_A.amount_spent #min(ids.test_order_A.amount_spent, ids.test_order_B.amount_received) 
        spend_amountB = ids.test_order_B.amount_spent #min(ids.test_order_A.amount_received, ids.test_order_B.amount_spent) 

        ids.spend_amountA = spend_amountA
        ids.spend_amountB = spend_amountB

        # ids.fee_takenA = current_swap["fee_A"]
        # ids.fee_takenB = current_swap["fee_B"]

        # assert spend_amountA/spend_amountB <= ids.test_order_A.amount_spent/ids.test_order_A.amount_received, "user A is getting the short end of the stick in this trade"
        # assert spend_amountB/spend_amountA <= ids.test_order_B.amount_spent/ids.test_order_B.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    let (sum_inputs_A : felt) = sum_notes(notes_in_A_len, notes_in_A, 0)
    let (sum_inputs_B : felt) = sum_notes(notes_in_B_len, notes_in_B, 0)

    assert sum_inputs_A - refund_note_A.amount = test_order_A.amount_spent
    assert sum_inputs_B - refund_note_B.amount = test_order_B.amount_spent

    # # Replace later
    assert_le(test_order_B.amount_received, test_order_A.amount_spent)
    assert_le(test_order_A.amount_received, test_order_B.amount_spent)

    let (swap_note_A : Note) = make_new_note(
        test_order_A.destination_address_pk,
        test_order_A.token_received,
        test_order_B.amount_spent,
        test_order_A.blindings_seed,
        1,
    )

    let (swap_note_B : Note) = make_new_note(
        test_order_B.destination_address_pk,
        test_order_B.token_received,
        test_order_A.amount_spent,
        test_order_B.blindings_seed,
        4,
    )

    %{
        # print(ids.new_note_A.address_pk)
        # print(ids.new_note_A.token)
        # print(ids.new_note_A.amount)
        # print(ids.new_note_A.blinding_factor)
        # print()
        # print(ids.new_note_B.address_pk)
        # print(ids.new_note_B.token)
        # print(ids.new_note_B.amount)
        # print(ids.new_note_B.blinding_factor)
    %}

    local zero_idx_A : felt
    local zero_idx_B : felt
    %{
        ids.zero_idx_A = order_A_input["zero_index"]
        ids.zero_idx_B = order_B_input["zero_index"]
    %}

    local note_dict : DictAccess*
    %{ ids.note_dict = segments.add() %}

    let note_dict_start = note_dict
    update_note_dict{note_dict=note_dict}(
        notes_in_A_len, notes_in_A, refund_note_A, swap_note_A, zero_idx_A
    )
    update_note_dict{note_dict=note_dict}(
        notes_in_B_len, notes_in_B, refund_note_B, swap_note_B, zero_idx_B
    )

    # Squash the order dict.
    local squashed_note_dict : DictAccess*
    %{ ids.squashed_note_dict = segments.add() %}
    let (squashed_note_dict_end) = squash_dict(
        dict_accesses=note_dict_start, dict_accesses_end=note_dict, squashed_dict=squashed_note_dict
    )
    local squashed_note_dict_len = squashed_note_dict_end - squashed_note_dict

    %{
        print("note_dict")
        l = int(ids.squashed_note_dict_len/ids.DictAccess.SIZE)
        for i in range(l):
            print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +0])
            print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +1])
            print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +2])
            print("======")
    %}

    return ()
end

func update_note_dict{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : Note*, refund_note : Note, swap_note : Note
):
    if notes_in_len == 1:
        let note_in = notes_in[0]
        return update_one(note_in, refund_note, swap_note)
    end
    if notes_in_len == 2:
        let note_in1 = notes_in[0]
        let note_in2 = notes_in[1]
        return update_two(note_in1, note_in2, refund_note, swap_note)
    end

    return update_multi(notes_in_len, notes_in, refund_note, swap_note)
end

func update_one{note_dict : DictAccess*}(note_in : Note, refund_note : Note, swap_note : Note):
    # todo use hashes instead of amounts

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = refund_note.index
    assert note_dict_ptr.prev_value = note_in.amount
    assert note_dict_ptr.new_value = refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = swap_note.index
    assert note_dict_ptr.prev_value = 0  # Could be replaced with another zero value
    assert note_dict_ptr.new_value = swap_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end

func update_two{note_dict : DictAccess*}(
    note_in1 : Note, note_in2 : Note, refund_note : Note, swap_note : Note
):
    let note_dict_ptr = note_dict
    note_dict_ptr.key = refund_note.index
    note_dict_ptr.prev_value = note_in1.amount
    note_dict_ptr.new_value = refund_note.amount

    let note_dict_ptr = note_dict + DictAccess.SIZE
    note_dict_ptr.key = swap_note.index
    note_dict_ptr.prev_value = note_in2.amount
    note_dict_ptr.new_value = swap_note.amount

    let note_dict = note_dict + 2 * DictAccess.SIZE

    return ()
end

func update_multi{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : Note*, refund_note : Note, swap_note : Note
):
    let note_in1 : Note = notes_in[0]
    let note_in2 : Note = notes_in[1]

    update_two(note_in1, note_in2, refund_note, swap_note)

    return _update_multi_inner(notes_in_len - 2, &notes_in[2])
end

func _update_multi_inner{note_dict : DictAccess*}(notes_in_len : felt, notes_in : Note*):
    if notes_in_len == 0:
        return ()
    end

    let note_in : Note = notes_in[0]

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = note_in.index
    assert note_dict_ptr.prev_value = note_in.amount
    assert note_dict_ptr.new_value = 0

    let note_dict = note_dict + DictAccess.SIZE

    return _update_multi_inner(notes_in_len - 1, &notes_in[1])
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    test_order_A : TestOrder*,
    test_order_B : TestOrder*,
    notes_in_A_len : felt*,
    notes_in_A : Note**,
    refund_note_A : Note*,
    notes_in_B_len : felt*,
    notes_in_B : Note**,
    refund_note_B : Note*,
):
    %{
        # * STRUCT SIZES ==========================================================

        NOTE_SIZE = ids.Note.SIZE
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index


        TEST_ORDER_SIZE = ids.TestOrder.SIZE
        TOKEN_SPENT_OFFSET = ids.TestOrder.token_spent
        TOKEN_RECEIVED_OFFSET = ids.TestOrder.token_received
        AMOUNT_SPENT_OFFSET = ids.TestOrder.amount_spent
        AMOUNT_RECEIVED_OFFSET = ids.TestOrder.amount_received
        BLINDING_SEED_OFFSET = ids.TestOrder.blindings_seed
        DEST_ADDRESS_PK_OFFSET = ids.TestOrder.destination_address_pk


        ##* ORDER A ==============================================================

        order_A_input = program_input["order_A"]

        memory[ids.test_order_A.address_ + TOKEN_SPENT_OFFSET] = order_A_input["token_spent"]
        memory[ids.test_order_A.address_ + TOKEN_RECEIVED_OFFSET] = order_A_input["token_received"]
        memory[ids.test_order_A.address_ + AMOUNT_SPENT_OFFSET] = order_A_input["amount_spent"]
        memory[ids.test_order_A.address_ + AMOUNT_RECEIVED_OFFSET] = order_A_input["amount_received"]
        memory[ids.test_order_A.address_ + BLINDING_SEED_OFFSET] = order_A_input["blindings_seed"]
        memory[ids.test_order_A.address_ + DEST_ADDRESS_PK_OFFSET] = order_A_input["dest_address_pk"]


        input_notes = order_A_input["notes_in"]

        memory[ids.notes_in_A_len] = len(input_notes)
        memory[ids.notes_in_A] = notes_ = segments.add()
        for i in range(len(input_notes)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = input_notes[i]["address_pk"]
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = input_notes[i]["token"]
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = input_notes[i]["amount"]
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = input_notes[i]["blinding"]
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = input_notes[i]["index"]

        refund_note__  = order_A_input["refund_note"]
        memory[ids.refund_note_A.address_ + ADDRESS_PK_OFFSET] = refund_note__["address_pk"]
        memory[ids.refund_note_A.address_ + TOKEN_OFFSET] = refund_note__["token"]
        memory[ids.refund_note_A.address_ + AMOUNT_OFFSET] = refund_note__["amount"]
        memory[ids.refund_note_A.address_ + BLINDING_FACTOR_OFFSET] = refund_note__["blinding"]
        memory[ids.refund_note_A.address_ + INDEX_OFFSET] = refund_note__["index"]


        ##* ORDER B =============================================================

        order_B_input = program_input["order_B"]

        memory[ids.test_order_B.address_ + TOKEN_SPENT_OFFSET] = order_B_input["token_spent"]
        memory[ids.test_order_B.address_ + TOKEN_RECEIVED_OFFSET] = order_B_input["token_received"]
        memory[ids.test_order_B.address_ + AMOUNT_SPENT_OFFSET] = order_B_input["amount_spent"]
        memory[ids.test_order_B.address_ + AMOUNT_RECEIVED_OFFSET] = order_B_input["amount_received"]
        memory[ids.test_order_B.address_ + BLINDING_SEED_OFFSET] = order_B_input["blindings_seed"]
        memory[ids.test_order_B.address_ + DEST_ADDRESS_PK_OFFSET] = order_B_input["dest_address_pk"]


        input_notes = order_B_input["notes_in"]

        memory[ids.notes_in_B_len] = len(input_notes)
        memory[ids.notes_in_B] = notes_ = segments.add()
        for i in range(len(input_notes)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = input_notes[i]["address_pk"]
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = input_notes[i]["token"]
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = input_notes[i]["amount"]
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = input_notes[i]["blinding"]
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = input_notes[i]["index"]

        refund_note__  = order_B_input["refund_note"]
        memory[ids.refund_note_B.address_ + ADDRESS_PK_OFFSET] = refund_note__["address_pk"]
        memory[ids.refund_note_B.address_ + TOKEN_OFFSET] = refund_note__["token"]
        memory[ids.refund_note_B.address_ + AMOUNT_OFFSET] = refund_note__["amount"]
        memory[ids.refund_note_B.address_ + BLINDING_FACTOR_OFFSET] = refund_note__["blinding"]
        memory[ids.refund_note_B.address_ + INDEX_OFFSET] = refund_note__["index"]
    %}

    return ()
end

func sum_notes(notes_len : felt, notes : Note*, sum : felt) -> (sum):
    alloc_locals

    if notes_len == 0:
        return (sum)
    end

    let note : Note = notes[0]
    let sum = sum + note.amount

    return sum_notes(notes_len - 1, &notes[1], sum)
end

func make_new_note(
    address_pk : felt, token : felt, amount : felt, blinding_factor : felt, index : felt
) -> (note : Note):
    alloc_locals

    let new_note : Note = Note(
        address_pk=address_pk,
        token=token,
        amount=amount,
        blinding_factor=blinding_factor,
        index=index,
    )

    return (new_note)
end
