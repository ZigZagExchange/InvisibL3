%builtins output pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash
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

from helpers.utils import Note, Invisibl3Order
from helpers.verify_commitments import verify_commitments
from helpers.verify_sums import verify_sums, take_fee, update_order_dict
from signatures.return_signature import verify_ret_addr_sig
from transactions.tx_hash.tx_hash import hash_transaction
from signatures.signatures import verify_sig
from signatures.signature_new import verify_signatures
from merkle_updates.merkle_updates import validate_merkle_updates

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # * Merkle roots ==========
    local prev_root : felt
    local new_root : felt

    # * Tx hash inputs ========
    local token_spent : felt
    local token_spent_price : felt
    local token_received : felt
    local token_received_price : felt
    local return_address : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_len : felt
    local signature : felt*
    local ret_addr_sig_c : felt
    local ret_addr_sig_r : felt

    # * Notes =================
    # indexes in the merkle tree
    local indexes_len : felt
    local indexes : felt*
    # Input notes
    local amounts_in_len : felt
    local amounts_in : felt*
    local blindings_in_len : felt
    local blindings_in : felt*
    local addresses_in_len : felt
    local addresses_in : EcPoint*

    # output notes
    local amounts_out_len : felt
    local amounts_out : felt*
    local blindings_out_len : felt
    local blindings_out : felt*
    local addresses_out_len : felt
    local addresses_out : EcPoint*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &prev_root,
        &new_root,
        &token_spent,
        &token_spent_price,
        &token_received,
        &token_received_price,
        &return_address,
        &signature_len,
        &signature,
        &ret_addr_sig_c,
        &ret_addr_sig_r,
        &indexes_len,
        &indexes,
        &amounts_in_len,
        &amounts_in,
        &blindings_in_len,
        &blindings_in,
        &addresses_in_len,
        &addresses_in,
        &amounts_out_len,
        &amounts_out,
        &blindings_out_len,
        &blindings_out,
        &addresses_out_len,
        &addresses_out,
    )

    let amount_in = amounts_in[0]
    let blinding_in = blindings_in[0]
    let address_in : EcPoint = addresses_in[0]

    let amount_out = amounts_out[0]
    let blinding_out = blindings_out[0]
    let address_out : EcPoint = addresses_out[0]

    # # verify_commitments()

    let (ret_tx_hash : felt) = hash2{hash_ptr=pedersen_ptr}(token_received, token_received_price)
    verify_ret_addr_sig(return_address, ret_tx_hash, ret_addr_sig_c, ret_addr_sig_r)

    let (
        tx_hash : felt,
        leaf_nodes_in_len : felt,
        leaf_nodes_in : felt*,
        leaf_nodes_out_len : felt,
        leaf_nodes_out : felt*,
    ) = hash_transaction(
        amounts_in_len,
        amounts_in,
        blindings_in_len,
        blindings_in,
        addresses_in_len,
        addresses_in,
        amounts_out_len,
        amounts_out,
        blindings_out_len,
        blindings_out,
        addresses_out_len,
        addresses_out,
        token_spent,
        token_spent_price,
        ret_addr_sig_r,
    )

    verify_sums(amounts_in_len, amounts_in, amounts_out_len, amounts_out)

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

    %{ print("all good" ) %}

    return ()
end

func execute_invisibl3_transaction{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    order_dict : DictAccess*,
    note_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}(
    invisibl3_order : Invisibl3Order,
    notes_in_len : felt,
    notes_in : Note*,
    notes_out_len : felt,
    notes_out : Note*,
    spent_amount : felt,
    received_amount : felt,
    fee_taken : felt,
):
    alloc_locals

    let (
        tx_hash : felt,
        hashed_notes_in_len : felt,
        hashed_notes_in : felt*,
        hashed_notes_out_len : felt,
        hashed_notes_out : felt*,
    ) = hash_transaction(invisibl3_order, notes_in_len, notes_in, notes_out_len, notes_out)

    # local prev_filled_amount : felt
    # local new_filled_amount : felt
    # %{
    #     #TODO should use a dict to remove hashing the same order twice
    #     try:
    #         ids.prev_filled_amount = fills[ids.tx_hash]
    #     except:
    #         ids.prev_filled_amount = 0
    # %}

    # new_filled_amount = prev_filled_amount + spent_amount
    # assert_le(new_filled_amount, invisibl3_order.amount_spent)

    # let (fee_taken : felt) = verify_sums(
    #     amounts_in_len, amounts_in, amounts_out_len, amounts_out, expected_fee, ids.fee_limit
    # )

    # Checks the actual ratio is at least as good as the requested(signed) ratio
    assert_le(
        spent_amount * invisibl3_order.amount_received,
        received_amount * invisibl3_order.amount_spent,
    )

    # %{ fills[ids.order_hash] = ids.new_filled_amount %} Partial feels

    validate_fee_taken(
        fee_taken, invisibl3_order.fee_limit, received_amount, invisibl3_order.amount_received
    )

    take_fee{fee_tracker_dict=fee_tracker_dict}(fee_taken)

    # update_order_dict{order_dict=order_dict}(tx_hash, prev_filled_amount, new_filled_amount)

    update_note_dict{note_dict=note_dict}(notes_in_len, notes_in, notes_out_len, notes_out)

    verify_signatures(tx_hash, notes_in_len, notes_in)

    %{ print("transaction verified" ) %}

    return (leaf_nodes_in_len, leaf_nodes_in, leaf_nodes_out_len, leaf_nodes_out)
end
