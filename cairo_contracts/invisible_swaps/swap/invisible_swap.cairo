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

from invisibl3_swaps.transaction.tx_hash.tx_hash import hash_transaction
from invisibl3_swaps.swap.transaction.invisibl3_tx import execute_invisibl3_transaction

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

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
        &test_order_A,
        &test_order_B,
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
        spend_amountA = current_swap["spend_amountA"] 
        spend_amountB = current_swap["spend_amountB"]

        ids.spend_amountA = spend_amountA
        ids.spend_amountB = spend_amountB

        ids.fee_takenA = current_swap["fee_A"]
        ids.fee_takenB = current_swap["fee_B"]

        assert spend_amountA/spend_amountB <= ids.invisibl3_order_A.amount_spent/ids.invisibl3_order_A.amount_received, "user A is getting the short end of the stick in this trade"
        assert spend_amountB/spend_amountA <= ids.invisibl3_order_B.amount_spent/ids.invisibl3_order_B.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    let (order_hash_A : felt) = hash_transaction(
        invisibl3_order_A, notes_in_A_len, notes_in_A, refund_note_A
    )
    let (order_hash_B : felt) = hash_transaction(
        invisibl3_order_B, notes_in_B_len, notes_in_B, refund_note_B
    )

    %{ order_indexes = index_data["order_A"] %}
    execute_invisibl3_transaction()

    %{ order_indexes = index_data["order_B"] %}
    execute_invisibl3_transaction()

    return ()
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    invisibl3_order_A : Invisibl3Order*,
    invisibl3_order_B : Invisibl3Order*,
    notes_in_A_len,
    notes_in_A,
    refund_note_A,
    notes_in_B_len,
    notes_in_B,
    refund_note_B,
):
    %{
        # * STRUCT SIZES ==========================================================

        NOTE_SIZE = ids.Note.SIZE
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index


        INVISIBLE_ORDER_SIZE = ids.InvisibleOrder.SIZE
        NONCE_OFFSET = ids.InvisibleOrder.nonce
        EXPIRATION_TIMESTAMP_OFFSET = ids.InvisibleOrder.expiration_timestamp
        SIGNATURE_R_OFFSET = ids.InvisibleOrder.signature_r
        SIGNATURE_S_OFFSET = ids.InvisibleOrder.signature_s
        TOKEN_SPENT_OFFSET = ids.InvisibleOrder.token_spent
        TOKEN_RECEIVED_OFFSET = ids.InvisibleOrder.token_received
        AMOUNT_SPENT_OFFSET = ids.InvisibleOrder.amount_spent
        AMOUNT_RECEIVED_OFFSET = ids.InvisibleOrder.amount_received
        FEE_LIMIT_OFFSET = ids.InvisibleOrder.fee_limit
        DEST_SPENT_ADDR_OFFSET = ids.InvisibleOrder.dest_spent_address
        DEST_RECEIVED_ADDR_OFFSET = ids.InvisibleOrder.dest_received_address
        BLINDING_SEED_OFFSET = ids.InvisibleOrder.blinding_seed


        ##* ORDER A =============================================================

        order_A_input = current_swap["order_A"]

        order_A_addr = memory[ids.invisibl3_order_A].address_

        memory[order_A_addr + NONCE_OFFSET] = order_A_input["nonce"]
        memory[order_A_addr + EXPIRATION_TIMESTAMP_OFFSET] = order_A_input["expiration_timestamp"]
        memory[order_A_addr + SIGNATURE_R_OFFSET] = order_A_input["signature"][0]
        memory[order_A_addr + SIGNATURE_S_OFFSET] = order_A_input["signature"][1]
        memory[order_A_addr + TOKEN_SPENT_OFFSET] = order_A_input["token_spent"]
        memory[order_A_addr + TOKEN_RECEIVED_OFFSET] = order_A_input["token_received"]
        memory[order_A_addr + AMOUNT_SPENT_OFFSET] = order_A_input["amount_spent"]
        memory[order_A_addr + AMOUNT_RECEIVED_OFFSET] = order_A_input["amount_received"]
        memory[order_A_addr + DEST_SPENT_ADDR_OFFSET] = order_A_input["dest_spent_address"]
        memory[order_A_addr + DEST_RECEIVED_ADDR_OFFSET] = order_A_input["dest_received_address"]
        memory[order_A_addr + BLINDING_SEED_OFFSET] = order_A_input["blinding_seed"]
        memory[order_A_addr + FEE_LIMIT_OFFSET] = order_A_input["fee_limit"]

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

        order_B_addr = memory[ids.invisibl3_order_B].address_

        memory[order_B_addr + NONCE_OFFSET] = order_B_input["nonce"]
        memory[order_B_addr + EXPIRATION_TIMESTAMP_OFFSET] = order_B_input["expiration_timestamp"]
        memory[order_B_addr + SIGNATURE_R_OFFSET] = order_B_input["signature"][0]
        memory[order_B_addr + SIGNATURE_S_OFFSET] = order_B_input["signature"][1]
        memory[order_B_addr + TOKEN_SPENT_OFFSET] = order_B_input["token_spent"]
        memory[order_B_addr + TOKEN_RECEIVED_OFFSET] = order_B_input["token_received"]
        memory[order_B_addr + AMOUNT_SPENT_OFFSET] = order_B_input["amount_spent"]
        memory[order_B_addr + AMOUNT_RECEIVED_OFFSET] = order_B_input["amount_received"]
        memory[order_B_addr + DEST_SPENT_ADDR_OFFSET] = order_B_input["dest_spent_address"]
        memory[order_B_addr + DEST_RECEIVED_ADDR_OFFSET] = order_B_input["dest_received_address"]
        memory[order_B_addr + BLINDING_SEED_OFFSET] = order_B_input["blinding_seed"]
        memory[order_B_addr + FEE_LIMIT_OFFSET] = order_B_input["fee_limit"]

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


        ##* OTHER =============================================================

        index_data = current_swap["indexes"]
    %}

    return ()
end
