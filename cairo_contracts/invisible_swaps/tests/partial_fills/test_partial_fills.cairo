# %builtins output pedersen range_check

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

from invisible_swaps.tests.test_swaps import (
    sum_notes,
    make_new_note,
    update_note_dict,
    TestOrder,
    Note,
)

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # GLOBAL VERIABLES
    %{
        swap_input_data = program_input["swaps"] 
        prev_filled_dict_manager = {}
        prev_fill_notes = {}
    %}

    local note_dict : DictAccess*
    local partial_fill_dict : DictAccess*
    %{
        ids.note_dict = segments.add()
        ids.partial_fill_dict = segments.add()
    %}
    let note_dict_start = note_dict
    let partial_fill_dict_start = partial_fill_dict

    %{ current_swap = swap_input_data.pop(0) %}

    verify_swap{note_dict=note_dict, partial_fill_dict=partial_fill_dict}()

    %{ current_swap = swap_input_data.pop(0) %}

    verify_swap{note_dict=note_dict, partial_fill_dict=partial_fill_dict}()

    # local squashed_note_dict : DictAccess*
    # %{ ids.squashed_note_dict = segments.add() %}
    # let (squashed_note_dict_end) = squash_dict(
    #     dict_accesses=note_dict_start, dict_accesses_end=note_dict, squashed_dict=squashed_note_dict
    # )
    # local squashed_note_dict_len = squashed_note_dict_end - squashed_note_dict

    local note_dict_len = note_dict - note_dict_start

    %{
        print("note_dict")
        l = int(ids.note_dict_len/ids.DictAccess.SIZE)
        for i in range(l):
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +0])
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +1])
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +2])
            print("======")
    %}

    %{ print("all good") %}

    return ()
end

func verify_swap{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
}():
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

    # Verify they are swaping the correct tokens
    assert test_order_A.token_spent = test_order_B.token_received
    assert test_order_A.token_received = test_order_B.token_spent

    # The actual amount being swapped (ratios should be at least as good as the order amounts)
    local spend_amountA : felt
    local spend_amountB : felt
    %{
        ids.spend_amountA = current_swap["spend_amountA"] 
        ids.spend_amountB = current_swap["spend_amountB"]

        # ids.fee_takenA = current_swap["fee_A"]
        # ids.fee_takenB = current_swap["fee_B"]

        #todo verify below outside of hints
        assert ids.spend_amountA/ids.spend_amountB <= ids.test_order_A.amount_spent/ids.test_order_A.amount_received, "user A is getting the short end of the stick in this trade"
        assert ids.spend_amountB/ids.spend_amountA <= ids.test_order_B.amount_spent/ids.test_order_B.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    local order_A_hash : felt
    local order_B_hash : felt
    %{
        # TODO Replace with order hashing
        ids.order_A_hash = current_swap["dummy_hash_A"]
        ids.order_B_hash = current_swap["dummy_hash_B"]
    %}

    # local range_check_ptr = range_check_ptr
    # * ORDER A ============================================================
    # If this is not the first fill return the last partial fill note hash else return 0
    let (prev_fill_hash_A : felt) = get_prev_fill_note_hash(order_A_hash)
    let (prev_fill_hash_B : felt) = get_prev_fill_note_hash(order_B_hash)

    %{ order_indexes = index_data["order_A"] %}
    if prev_fill_hash_A == 0:
        %{ print("First fill A") %}
        # ! if this is the first fill
        first_fill(
            notes_in_A_len,
            notes_in_A,
            refund_note_A,
            test_order_A,
            spend_amountB,
            spend_amountA,
            order_A_hash,
        )
    else:
        %{ print("Later fill A") %}
        # ! if the order was filled partially befor this
        later_fills(order_A_hash, test_order_A, spend_amountB, spend_amountA)
    end

    # # * ORDER B =================================================================================

    %{ order_indexes = index_data["order_B"] %}
    if prev_fill_hash_B == 0:
        %{ print("First fill B") %}
        # ! if this is the first fill
        first_fill(
            notes_in_B_len,
            notes_in_B,
            refund_note_B,
            test_order_B,
            spend_amountA,
            spend_amountB,
            order_B_hash,
        )
    else:
        %{ print("Later fill B") %}
        # ! if the order was filled partially befor this
        later_fills(order_B_hash, test_order_B, spend_amountA, spend_amountB)
    end

    return ()
end

# !============================================================================================

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

    %{ print(order_indexes["partial_fill_idx"]) %}

    let (new_fill_refund_note : Note) = partial_fill_updates(
        test_order_A, spend_amountA, order_A_hash, condition1, prev_fill_refund_note
    )

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = new_fill_refund_note.index
    assert note_dict_ptr.prev_value = 0
    assert note_dict_ptr.new_value = new_fill_refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    # todo update_state() ->  get a zero idx in the tree for the swap_note
    # todo  and replace the prev_fill_refund_note with the new one

    # update_note_dict{note_dict=note_dict}(notes_in_A_len, notes_in_A, refund_note_A, swap_note_A)

    return ()
end

# !============================================================================================
func partial_fill_updates{partial_fill_dict : DictAccess*}(
    test_order_A : TestOrder,
    spend_amountA : felt,
    order_A_hash : felt,
    condition : felt,
    prev_fill_refund_note : Note,
) -> (pf_note : Note):
    alloc_locals

    # todo maybe we can remove this altogether and do it outside the function
    if condition == 0:
        return (prev_fill_refund_note)
    end

    let partial_fill_refund_amount = test_order_A.amount_spent - spend_amountA

    local new_fill_refund_note_idx : felt
    %{ ids.new_fill_refund_note_idx = order_indexes["partial_fill_idx"] %}

    let (__fp__, _) = get_fp_and_pc()
    # figure what address to send to
    let (local partial_fill_note : Note) = make_new_note(
        test_order_A.destination_address_pk,
        test_order_A.token_spent,
        partial_fill_refund_amount,
        test_order_A.blindings_seed,
        new_fill_refund_note_idx,
    )

    let (n_hash : felt) = hash_note(partial_fill_note)

    %{
        prev_fill_notes[ids.order_A_hash] = {
        "address_pk": ids.partial_fill_note.address_pk,
        "token": ids.partial_fill_note.token,
        "amount": ids.partial_fill_note.amount,
        "blinding_factor": ids.partial_fill_note.blinding_factor,
        "index": ids.partial_fill_note.index,
        }
    %}

    # todo replace the zero with prev_hash in case this is a third order fill
    store_prev_fill_note_hash(order_A_hash, 0, n_hash)

    return (partial_fill_note)
end
# !============================================================================================

func handle_inputs(
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


        order_A_input = current_swap["order_A"]

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

        order_B_input = current_swap["order_B"]

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

        #* OTHER ==========================================================
        index_data = current_swap["indexes"]
    %}

    return ()
end

func store_prev_fill_note_hash{partial_fill_dict : DictAccess*}(
    order_hash : felt, prev_hash : felt, new_hash : felt
) -> ():
    %{ prev_filled_dict_manager[ids.order_hash] =  (ids.partial_fill_dict.address_, ids.prev_hash, ids.new_hash) %}

    let partial_fill_dict_ptr = partial_fill_dict
    assert partial_fill_dict_ptr.key = order_hash
    assert partial_fill_dict_ptr.prev_value = prev_hash
    assert partial_fill_dict_ptr.new_value = new_hash

    let partial_fill_dict = partial_fill_dict + DictAccess.SIZE

    return ()
end

func get_prev_fill_note_hash(order_hash : felt) -> (res):
    # TODO: This could be used with another dictAccess so figure it out
    alloc_locals

    local prev_hash : felt
    local new_hash : felt
    %{
        try:
            addr_, prev_hash, new_hash = prev_filled_dict_manager[ids.order_hash] 
            ids.prev_hash = prev_hash
            ids.new_hash = new_hash

            memory[ap] = addr_
        except:
            ids.prev_hash = 0
            ids.new_hash = 0
    %}

    if new_hash == 0:
        return (0)
    end

    # Todo: could provide an invalid address of a previous dict_access pointer,
    # Todo that still has a note that has already been spent

    ap += 1
    let dict_access : DictAccess* = cast([ap - 1], DictAccess*)

    assert dict_access.key = order_hash
    assert dict_access.prev_value = prev_hash
    assert dict_access.new_value = new_hash

    return (new_hash)
end

func hash_note(note : Note) -> (hash):
    let hash = note.amount + note.address_pk + note.token + note.index + note.blinding_factor

    return (hash)
end
