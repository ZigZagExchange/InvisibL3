# %builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from merkle_updates.merkle_updates import validate_merkle_updates
from transactions.note_transaction import execute_invisibl3_transaction
from helpers.utils import concat_arrays

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # * Merkle roots ==========
    local prev_root : felt
    local new_root : felt

    # ! TAKER TRANSACTION ==================================================
    # * Tx hash inputs ========
    local token_spent_A : felt
    local token_spent_price_A : felt
    local token_received_A : felt
    local token_received_price_A : felt
    local return_address_A : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_A_len : felt
    local signature_A : felt*
    local ret_addr_sig_c_A : felt
    local ret_addr_sig_r_A : felt

    # * Notes =================
    # Input notes
    local amounts_in_A_len : felt
    local amounts_in_A : felt*
    local blindings_in_A_len : felt
    local blindings_in_A : felt*
    local addresses_in_A_len : felt
    local addresses_in_A : EcPoint*

    # output notes
    local amounts_out_A_len : felt
    local amounts_out_A : felt*
    local blindings_out_A_len : felt
    local blindings_out_A : felt*
    local addresses_out_A_len : felt
    local addresses_out_A : EcPoint*

    # ! MAKER TRANSACTION ==================================================

    # indexes in the merkle tree
    local indexes_len : felt
    local indexes : felt*

    # * Tx hash inputs ========
    local token_spent_B : felt
    local token_spent_price_B : felt
    local token_received_B : felt
    local token_received_price_B : felt
    local return_address_B : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_B_len : felt
    local signature_B : felt*
    local ret_addr_sig_c_B : felt
    local ret_addr_sig_r_B : felt

    # * Notes =================

    # notes in
    local amounts_in_B_len : felt
    local amounts_in_B : felt*
    local blindings_in_B_len : felt
    local blindings_in_B : felt*
    local addresses_in_B_len : felt
    local addresses_in_B : EcPoint*
    # notes out
    local amounts_out_B_len : felt
    local amounts_out_B : felt*
    local blindings_out_B_len : felt
    local blindings_out_B : felt*
    local addresses_out_B_len : felt
    local addresses_out_B : EcPoint*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &prev_root,
        &new_root,
        &token_spent_A,
        &token_spent_price_A,
        &token_received_A,
        &token_received_price_A,
        &return_address_A,
        &signature_A_len,
        &signature_A,
        &ret_addr_sig_c_A,
        &ret_addr_sig_r_A,
        &amounts_in_A_len,
        &amounts_in_A,
        &blindings_in_A_len,
        &blindings_in_A,
        &addresses_in_A_len,
        &addresses_in_A,
        &amounts_out_A_len,
        &amounts_out_A,
        &blindings_out_A_len,
        &blindings_out_A,
        &addresses_out_A_len,
        &addresses_out_A,
        &token_spent_B,
        &token_spent_price_B,
        &token_received_B,
        &token_received_price_B,
        &return_address_B,
        &signature_B_len,
        &signature_B,
        &ret_addr_sig_c_B,
        &ret_addr_sig_r_B,
        &amounts_in_B_len,
        &amounts_in_B,
        &blindings_in_B_len,
        &blindings_in_B,
        &addresses_in_B_len,
        &addresses_in_B,
        &amounts_out_B_len,
        &amounts_out_B,
        &blindings_out_B_len,
        &blindings_out_B,
        &addresses_out_B_len,
        &addresses_out_B,
        &indexes_len,
        &indexes,
    )

    # * Validate taker transaction =======

    let (
        leaf_nodes_in_A_len : felt,
        leaf_nodes_in_A : felt*,
        leaf_nodes_out_A_len : felt,
        leaf_nodes_out_A : felt*,
    ) = verify_transaction(
        token_spent_A,
        token_spent_price_A,
        token_received_A,
        token_received_price_A,
        return_address_A,
        signature_A_len,
        signature_A,
        ret_addr_sig_c_A,
        ret_addr_sig_r_A,
        amounts_in_A_len,
        amounts_in_A,
        blindings_in_A_len,
        blindings_in_A,
        addresses_in_A_len,
        addresses_in_A,
        amounts_out_A_len,
        amounts_out_A,
        blindings_out_A_len,
        blindings_out_A,
        addresses_out_A_len,
        addresses_out_A,
    )

    # * Validate maker transaction =======

    let (
        leaf_nodes_in_B_len : felt,
        leaf_nodes_in_B : felt*,
        leaf_nodes_out_B_len : felt,
        leaf_nodes_out_B : felt*,
    ) = verify_transaction(
        token_spent_B,
        token_spent_price_B,
        token_received_B,
        token_received_price_B,
        return_address_B,
        signature_B_len,
        signature_B,
        ret_addr_sig_c_B,
        ret_addr_sig_r_B,
        amounts_in_B_len,
        amounts_in_B,
        blindings_in_B_len,
        blindings_in_B,
        addresses_in_B_len,
        addresses_in_B,
        amounts_out_B_len,
        amounts_out_B,
        blindings_out_B_len,
        blindings_out_B,
        addresses_out_B_len,
        addresses_out_B,
    )

    let (leaf_nodes_in_len : felt, leaf_nodes_in : felt*) = concat_arrays(
        leaf_nodes_in_A_len, leaf_nodes_in_A, leaf_nodes_in_B_len, leaf_nodes_in_B
    )
    let (leaf_nodes_out_len : felt, leaf_nodes_out : felt*) = concat_arrays(
        leaf_nodes_out_A_len, leaf_nodes_out_A, leaf_nodes_out_B_len, leaf_nodes_out_B
    )

    # Check merkle root updates
    validate_merkle_updates(
        prev_root,
        new_root,
        indexes_len,
        indexes,
        leaf_nodes_in_len,
        leaf_nodes_in,
        leaf_nodes_out_len,
        leaf_nodes_out,
    )

    verify_swap_quotes(
        amounts_out_A[0], token_spent_price_A, amounts_out_B[0], token_received_price_A
    )

    %{ print("all good") %}

    return ()
end

func verify_swap{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(ith : felt):
    alloc_locals

    local invisibl3_order_A : Invisibl3Order
    local invisibl3_order_B : Invisibl3Order

    local notes_in_A_len : felt
    local notes_in_A : Note*
    local notes_out_A_len : felt
    local notes_out_A : Note*

    local notes_in_B_len : felt
    local notes_in_B : Note*
    local notes_out_B_len : felt
    local notes_out_B : Note*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &invisibl3_order_A,
        &invisibl3_order_B,
        &notes_in_A_len,
        &notes_in_A,
        &notes_out_A_len,
        &notes_out_A,
        &notes_in_B_len,
        &notes_in_B,
        &notes_out_B_len,
        &notes_out_B,
    )

    assert invisibl3_order_A.token_spent = invisibl3_order_B.token_received
    assert invisibl3_order_A.token_received = invisibl3_order_B.token_spent

    local spend_amountA : felt
    local spend_amountB : felt
    local fee_takenA : felt
    local fee_takenB : felt

    %{
        spend_amountA = min(ids.invisibl3_order_A.amount_spent, ids.invisibl3_order_B.amount_received) 
        spend_amountB = min(ids.invisibl3_order_A.amount_received, ids.invisibl3_order_B.amount_spent) 

        ids.spend_amountA = spend_amountA
        ids.spend_amountB = spend_amountB

        ids.fee_takenA = current_swap["fee_A"]
        ids.fee_takenB = current_swap["fee_B"]

        assert spend_amountA/spend_amountB <= ids.invisibl3_order_A.amount_spent/ids.invisibl3_order_A.amount_received, "user A is getting the short end of the stick in this trade"
        assert spend_amountB/spend_amountA <= ids.invisibl3_order_B.amount_spent/ids.invisibl3_order_B.amount_received, "user B is getting the short end of the stick in this trade"
    %}

    # * Validate taker transaction =======

    execute_invisibl3_transaction(
        invisibl3_order_A,
        notes_in_A_len,
        notes_in_A,
        notes_out_A_len,
        notes_out_A,
        spend_amountA,
        spend_amountB,
        fee_takenA,
    )

    # * Validate maker transaction =======

    execute_invisibl3_transaction(
        invisibl3_order_B,
        notes_in_B_len,
        notes_in_B,
        notes_out_B_len,
        notes_out_B,
        spend_amountB,
        spend_amountA,
        fee_takenB,
    )

    # Check merkle root updates
    validate_merkle_updates(
        prev_root,
        new_root,
        indexes_len,
        indexes,
        leaf_nodes_in_len,
        leaf_nodes_in,
        leaf_nodes_out_len,
        leaf_nodes_out,
    )

    verify_swap_quotes(
        amounts_out_A[0], token_spent_price_A, amounts_out_B[0], token_received_price_A
    )

    %{ print("all good") %}

    return ()
end

func verify_swap_quotes{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_spent_amount : felt,
    token_spent_price : felt,
    token_received_amount : felt,
    token_received_price : felt,
):
    alloc_locals

    tempvar xPx = token_spent_amount * token_spent_price
    tempvar yPy = token_received_amount * token_received_price

    tempvar diff = xPx - yPy

    tempvar diff = diff * 10 ** 8
    let (diff : felt, _) = unsigned_div_rem(diff, xPx)

    with_attr error_message("Swap quotes are not valid"):
        assert diff = 0
    end

    return ()
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    invisibl3_order_A : Invisibl3Order*,
    invisibl3_order_B : Invisibl3Order*,
    notes_in_len : felt*,
    notes_in : Note**,
    notes_out_len : felt*,
    notes_out : Note**,
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


        ##* INPUT NOTES ==============================================================

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
        memory[order_A_addr + FEE_LIMIT_OFFSET] = order_A_input["fee_limit"]


        amounts = order_A_input["amounts"]
        blindings = order_A_input["blindings"]
        tokens = order_A_input["tokens"]
        address_pks = order_A_input["address_pubkeys"]
        indexes = order_A_input["indexes"]
        signatures = order_A_input["signatures"]

        memory[ids.notes_in_len] = len(amounts)
        memory[ids.notes_in] = notes_ = segments.add()
        for i in range(len(amounts)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = address_pks[i]
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = tokens[i]
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = amounts[i]
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = blindings[i]
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = indexes[i]



        ##* OUTPUT NOTES =============================================================

        order_B_input = current_swap["order_A"]

        order_B_addr = memory[ids.invisibl3_order_B].address_

        memory[order_B_addr + NONCE_OFFSET] = order_B_input["nonce"]
        memory[order_B_addr + EXPIRATION_TIMESTAMP_OFFSET] = order_B_input["expiration_timestamp"]
        memory[order_B_addr + SIGNATURE_R_OFFSET] = order_B_input["signature"][0]
        memory[order_B_addr + SIGNATURE_S_OFFSET] = order_B_input["signature"][1]
        memory[order_B_addr + TOKEN_SPENT_OFFSET] = order_B_input["token_spent"]
        memory[order_B_addr + TOKEN_RECEIVED_OFFSET] = order_B_input["token_received"]
        memory[order_B_addr + AMOUNT_SPENT_OFFSET] = order_B_input["amount_spent"]
        memory[order_B_addr + AMOUNT_RECEIVED_OFFSET] = order_B_input["amount_received"]
        memory[order_B_addr + FEE_LIMIT_OFFSET] = order_B_input["fee_limit"]


        amounts = order_B_input["amounts"]
        blindings = order_B_input["blindings"]
        tokens = order_B_input["tokens"]
        address_pks = order_B_input["address_pubkeys"]
        indexes = order_B_input["indexes"]
        signatures = order_B_input["signatures"]

        memory[ids.notes_in_len] = len(amounts)
        memory[ids.notes_in] = notes_ = segments.add()
        for i in range(len(amounts)):
            memory[notes_ + i* NOTE_SIZE + ADDRESS_PK_OFFSET] = address_pks[i]
            memory[notes_ + i* NOTE_SIZE + TOKEN_OFFSET] = tokens[i]
            memory[notes_ + i* NOTE_SIZE + AMOUNT_OFFSET] = amounts[i]
            memory[notes_ + i* NOTE_SIZE + BLINDING_FACTOR_OFFSET] = blindings[i]
            memory[notes_ + i* NOTE_SIZE + INDEX_OFFSET] = indexes[i]
    %}

    return ()
end
