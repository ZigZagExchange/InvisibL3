# %builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
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

from invisible_swaps.swap.tx_hash.tx_hash import hash_transaction
from invisible_swaps.swap.transaction.invisibl3_tx import execute_invisibl3_transaction
from invisible_swaps.helpers.utils import Invisibl3Order, Note

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
    ):
    alloc_locals

    # GLOBAL VERIABLES
    %{
        swap_input_data = program_input["swaps"] 
        prev_filled_dict_manager = {}
        prev_fill_notes = {}
        prev_fill_note_hashes = {}
        fee_tracker_dict_manager = {}
    %}

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

    # %{
    #     import time
    #     t1 = time.time()
    # %}
    %{ current_swap = swap_input_data.pop(0) %}
    verify_swap{
        note_dict=note_dict, partial_fill_dict=partial_fill_dict, fee_tracker_dict=fee_tracker_dict
    }()
    # %{
    #     t2 = time.time()
    #     print("time: ", t2-t1)
    # %}

    %{ current_swap = swap_input_data.pop(0) %}
    verify_swap{
        note_dict=note_dict, partial_fill_dict=partial_fill_dict, fee_tracker_dict=fee_tracker_dict
    }()

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

func verify_swap{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}():
    alloc_locals

    local invisibl3_order_A : Invisibl3Order
    local invisibl3_order_B : Invisibl3Order

    local notes_in_A_len : felt
    local notes_in_A : Note*
    local refund_note_A : Note

    local notes_in_B_len : felt
    local notes_in_B : Note*
    local refund_note_B : Note

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &invisibl3_order_A,
        &invisibl3_order_B,
        &notes_in_A_len,
        &notes_in_A,
        &refund_note_A,
        &notes_in_B_len,
        &notes_in_B,
        &refund_note_B,
    )

    assert invisibl3_order_A.token_spent = invisibl3_order_B.token_received
    assert invisibl3_order_A.token_received = invisibl3_order_B.token_spent

    local spend_amountA : felt
    local spend_amountB : felt
    local fee_takenA : felt
    local fee_takenB : felt

    %{
        spend_amountA = int(current_swap["spend_amountA"]) 
        spend_amountB = int(current_swap["spend_amountB"])

        ids.spend_amountA = spend_amountA
        ids.spend_amountB = spend_amountB

        ids.fee_takenA = int(current_swap["fee_takenA"])
        ids.fee_takenB = int(current_swap["fee_takenB"])

        assert spend_amountA/spend_amountB <= ids.invisibl3_order_A.amount_spent/ids.invisibl3_order_A.amount_received, "user A is getting the short end of the stick in this trade"
        assert spend_amountB/spend_amountA <= ids.invisibl3_order_B.amount_spent/ids.invisibl3_order_B.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    let (order_hash_A : felt) = hash_transaction(
        invisibl3_order_A, notes_in_A_len, notes_in_A, refund_note_A
    )

    let (order_hash_B : felt) = hash_transaction(
        invisibl3_order_B, notes_in_B_len, notes_in_B, refund_note_B
    )

    %{
        order_indexes = index_data["order_A"]
        current_order = current_swap["orderA"]
    %}
    execute_invisibl3_transaction(
        order_hash_A,
        notes_in_A_len,
        notes_in_A,
        refund_note_A,
        invisibl3_order_A,
        spend_amountA,
        spend_amountB,
        fee_takenA,
    )
    %{
        order_indexes = index_data["order_B"] 
        current_order = current_swap["orderB"]
    %}
    execute_invisibl3_transaction(
        order_hash_B,
        notes_in_B_len,
        notes_in_B,
        refund_note_B,
        invisibl3_order_B,
        spend_amountB,
        spend_amountA,
        fee_takenB,
    )

    return ()
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    invisibl3_order_A : Invisibl3Order*,
    invisibl3_order_B : Invisibl3Order*,
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
        HASH_OFFSET = ids.Note.hash


        INVISIBLE_ORDER_SIZE = ids.Invisibl3Order.SIZE
        NONCE_OFFSET = ids.Invisibl3Order.nonce
        EXPIRATION_TIMESTAMP_OFFSET = ids.Invisibl3Order.expiration_timestamp
        TOKEN_SPENT_OFFSET = ids.Invisibl3Order.token_spent
        TOKEN_RECEIVED_OFFSET = ids.Invisibl3Order.token_received
        AMOUNT_SPENT_OFFSET = ids.Invisibl3Order.amount_spent
        AMOUNT_RECEIVED_OFFSET = ids.Invisibl3Order.amount_received
        FEE_LIMIT_OFFSET = ids.Invisibl3Order.fee_limit
        DEST_SPENT_ADDR_OFFSET = ids.Invisibl3Order.dest_spent_address
        DEST_RECEIVED_ADDR_OFFSET = ids.Invisibl3Order.dest_received_address
        BLINDING_SEED_OFFSET = ids.Invisibl3Order.blinding_seed


        ##* ORDER A =============================================================

        order_A_input = current_swap["orderA"]

        order_A_addr = ids.invisibl3_order_A.address_

        memory[order_A_addr + NONCE_OFFSET] = int(order_A_input["nonce"])
        memory[order_A_addr + EXPIRATION_TIMESTAMP_OFFSET] = int(order_A_input["expiration_timestamp"])
        memory[order_A_addr + TOKEN_SPENT_OFFSET] = int(order_A_input["token_spent"])
        memory[order_A_addr + TOKEN_RECEIVED_OFFSET] = int(order_A_input["token_received"])
        memory[order_A_addr + AMOUNT_SPENT_OFFSET] = int(order_A_input["amount_spent"])
        memory[order_A_addr + AMOUNT_RECEIVED_OFFSET] = int(order_A_input["amount_received"])
        memory[order_A_addr + DEST_SPENT_ADDR_OFFSET] = int(order_A_input["dest_spent_address"])
        memory[order_A_addr + DEST_RECEIVED_ADDR_OFFSET] = int(order_A_input["dest_received_address"])
        memory[order_A_addr + BLINDING_SEED_OFFSET] = int(order_A_input["blinding_seed"])
        memory[order_A_addr + FEE_LIMIT_OFFSET] = int(order_A_input["fee_limit"])

        input_notes = order_A_input["notes_in"]

        memory[ids.notes_in_A_len] = len(input_notes)
        memory[ids.notes_in_A] = notes_ = segments.add()
        for i in range(len(input_notes)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = int(input_notes[i]["address_pk"])
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = int(input_notes[i]["token"])
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = int(input_notes[i]["amount"])
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = int(input_notes[i]["blinding"])
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = int(input_notes[i]["index"])
            memory[notes_ + i* NOTE_SIZE + HASH_OFFSET] = int(input_notes[i]["hash"])

        refund_note__  = order_A_input["refund_note"]
        memory[ids.refund_note_A.address_ + ADDRESS_PK_OFFSET] = int(refund_note__["address_pk"])
        memory[ids.refund_note_A.address_ + TOKEN_OFFSET] = int(refund_note__["token"])
        memory[ids.refund_note_A.address_ + AMOUNT_OFFSET] = int(refund_note__["amount"])
        memory[ids.refund_note_A.address_ + BLINDING_FACTOR_OFFSET] = int(refund_note__["blinding"])
        memory[ids.refund_note_A.address_ + INDEX_OFFSET] = int(refund_note__["index"])
        memory[ids.refund_note_A.address_ + HASH_OFFSET] = int(refund_note__["hash"])


        ##* ORDER B =============================================================

        order_B_input = current_swap["orderB"]

        order_B_addr = ids.invisibl3_order_B.address_

        memory[order_B_addr + NONCE_OFFSET] = int(order_B_input["nonce"])
        memory[order_B_addr + EXPIRATION_TIMESTAMP_OFFSET] = int(order_B_input["expiration_timestamp"])
        memory[order_B_addr + TOKEN_SPENT_OFFSET] = int(order_B_input["token_spent"])
        memory[order_B_addr + TOKEN_RECEIVED_OFFSET] = int(order_B_input["token_received"])
        memory[order_B_addr + AMOUNT_SPENT_OFFSET] = int(order_B_input["amount_spent"])
        memory[order_B_addr + AMOUNT_RECEIVED_OFFSET] = int(order_B_input["amount_received"])
        memory[order_B_addr + DEST_SPENT_ADDR_OFFSET] = int(order_B_input["dest_spent_address"])
        memory[order_B_addr + DEST_RECEIVED_ADDR_OFFSET] = int(order_B_input["dest_received_address"])
        memory[order_B_addr + BLINDING_SEED_OFFSET] = int(order_B_input["blinding_seed"])
        memory[order_B_addr + FEE_LIMIT_OFFSET] = int(order_B_input["fee_limit"])

        input_notes = order_B_input["notes_in"]

        memory[ids.notes_in_B_len] = len(input_notes)
        memory[ids.notes_in_B] = notes_ = segments.add()
        for i in range(len(input_notes)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = int(input_notes[i]["address_pk"])
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = int(input_notes[i]["token"])
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = int(input_notes[i]["amount"])
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = int(input_notes[i]["blinding"])
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = int(input_notes[i]["index"])
            memory[notes_ + i* NOTE_SIZE + HASH_OFFSET] = int(input_notes[i]["hash"])

        refund_note__  = order_B_input["refund_note"]
        memory[ids.refund_note_B.address_ + ADDRESS_PK_OFFSET] = int(refund_note__["address_pk"])
        memory[ids.refund_note_B.address_ + TOKEN_OFFSET] = int(refund_note__["token"])
        memory[ids.refund_note_B.address_ + AMOUNT_OFFSET] = int(refund_note__["amount"])
        memory[ids.refund_note_B.address_ + BLINDING_FACTOR_OFFSET] = int(refund_note__["blinding"])
        memory[ids.refund_note_B.address_ + INDEX_OFFSET] = int(refund_note__["index"])
        memory[ids.refund_note_B.address_ + HASH_OFFSET] = int(refund_note__["hash"])


        ##* OTHER =============================================================

        index_data = current_swap["indexes"]
    %}

    return ()
end
