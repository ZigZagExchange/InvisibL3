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

from helpers.utils import Note
from helpers.verify_commitments import verify_commitments
from helpers.verify_sums import verify_sums
from signatures.return_signature import verify_ret_addr_sig
from transactions.tx_hash.tx_hash import hash_transaction
from signatures.signatures import verify_sig
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

func execute_private_transaction{
    output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(
    token_spent : felt,
    token_spent_price : felt,
    token_received : felt,
    token_received_price : felt,
    return_address : EcPoint,
    signature_len : felt,
    signature : felt*,
    ret_addr_sig_c : felt,
    ret_addr_sig_r : felt,
    amounts_in_len : felt,
    amounts_in : felt*,
    blindings_in_len : felt,
    blindings_in : felt*,
    addresses_in_len : felt,
    addresses_in : EcPoint*,
    amounts_out_len : felt,
    amounts_out : felt*,
    blindings_out_len : felt,
    blindings_out : felt*,
    addresses_out_len : felt,
    addresses_out : EcPoint*,
) -> (
    leaf_nodes_in_len : felt,
    leaf_nodes_in : felt*,
    leaf_nodes_out_len : felt,
    leaf_nodes_out : felt*,
):
    alloc_locals

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

    # TODO
    # tx_hash : felt,
    # public_keys_len : felt,
    # public_keys : felt*,
    # signatures_len : felt,
    # signatures : Signature*
    # verify_signatures(
    #     tx_hash, signature[0], signature_len - 1, &signature[1]
    # )

    verify_sums(amounts_in_len, amounts_in, amounts_out_len, amounts_out)

    %{ print("transaction verified" ) %}

    return (leaf_nodes_in_len, leaf_nodes_in, leaf_nodes_out_len, leaf_nodes_out)
end

# this two functions will be deprecated when replacing notes with (amounts, blindings, addresses, ...)
func notes_to_addresses{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_len : felt, notes : Note*, addresses_len : felt, addresses : EcPoint*
) -> (res_len : felt, res : EcPoint*):
    alloc_locals
    if notes_len == 0:
        return (addresses_len, addresses)
    end

    let note = notes[0]
    let addr : EcPoint = note.address

    assert addresses[addresses_len] = addr

    return notes_to_addresses(notes_len - 1, &notes[1], addresses_len + 1, addresses)
end

func notes_to_amounts{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_len : felt, notes : Note*, amounts_len : felt, amounts : felt*
) -> (res_len : felt, res : felt*):
    alloc_locals
    if notes_len == 0:
        return (amounts_len, amounts)
    end

    let note = notes[0]
    let amount = note.amount

    assert amounts[amounts_len] = amount

    return notes_to_amounts(notes_len - 1, &notes[1], amounts_len + 1, amounts)
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    prev_root : felt*,
    new_root : felt*,
    token_spent : felt*,
    token_spent_price : felt*,
    token_received : felt*,
    token_received_price : felt*,
    return_address : EcPoint*,
    signature_len : felt*,
    signature : felt**,
    ret_addr_sig_c : felt*,
    ret_addr_sig_r : felt*,
    indexes_len : felt*,
    indexes : felt**,
    amounts_in_len : felt*,
    amounts_in : felt**,
    blindings_in_len : felt*,
    blindings_in : felt**,
    addresses_in_len : felt*,
    addresses_in : EcPoint**,
    amounts_out_len : felt*,
    amounts_out : felt**,
    blindings_out_len : felt*,
    blindings_out : felt**,
    addresses_out_len : felt*,
    addresses_out : EcPoint**,
):
    %{
        # * STRUCT SIZES ==========================================================

        POINT_SIZE = ids.EcPoint.SIZE
        X_OFFSET = ids.EcPoint.x
        Y_OFFSET = ids.EcPoint.y

        BIG_INT_SIZE = ids.BigInt3.SIZE
        BIG_INT_0_OFFSET = ids.BigInt3.d0
        BIG_INT_1_OFFSET = ids.BigInt3.d1
        BIG_INT_2_OFFSET = ids.BigInt3.d2

        # * MERKLE TREE INPUTS =====================================================

        memory[ids.prev_root] = program_input["prev_root"]
        memory[ids.new_root] = program_input["new_root"]

        preimage = program_input["preimage"]
        preimage = {int(k):v for k,v in preimage.items()}

        # * TX_HASH INPUTS ==========================================================

        memory[ids.token_spent] = token_spent = program_input["token_spent"]
        memory[ids.token_spent_price] = program_input["token_spent_price"]
        memory[ids.token_received] = token_received = program_input["token_received"]
        memory[ids.token_received_price] = program_input["token_received_price"]

        ret_addr = program_input["return_address"]
        memory[ids.return_address.address_ + X_OFFSET + BIG_INT_0_OFFSET] = ret_addr[0][0]
        memory[ids.return_address.address_ + X_OFFSET + BIG_INT_1_OFFSET] = ret_addr[0][1]
        memory[ids.return_address.address_ + X_OFFSET + BIG_INT_2_OFFSET] = ret_addr[0][2]
        memory[ids.return_address.address_ + Y_OFFSET + BIG_INT_0_OFFSET] = ret_addr[1][0]
        memory[ids.return_address.address_ + Y_OFFSET + BIG_INT_1_OFFSET] = ret_addr[1][1]
        memory[ids.return_address.address_ + Y_OFFSET + BIG_INT_2_OFFSET] = ret_addr[1][2]

        # * SIGNATURE INPUTS ========================================================

        sig = program_input["signature"]
        memory[ids.signature_len] = len(sig)
        memory[ids.signature] = _signature_ = segments.add() 
        for i, val in enumerate(sig):
            memory[_signature_ + i] = val

        ret_sig = program_input["ret_addr_sig"]
        memory[ids.ret_addr_sig_c] = ret_sig[0]
        memory[ids.ret_addr_sig_r] = ret_sig[1]

        indexes__ = program_input["indexes"]
        memory[ids.indexes_len] = len(indexes__)
        memory[ids.indexes] = indexes = segments.add()
        for i, val in enumerate(indexes__):
            memory[indexes + i] = val


        initial_dict = {k: 0 for k in indexes__}

        ##* INPUT NOTES ==============================================================

        amounts_in__ = program_input["amounts_in"]
        memory[ids.amounts_in_len] = len(amounts_in__)
        memory[ids.amounts_in] = amounts_in = segments.add()
        for i, val in enumerate(amounts_in__):
            memory[amounts_in + i] = val



        blindings_in__ = program_input["blindings_in"]
        memory[ids.blindings_in_len] = len(blindings_in__)
        memory[ids.blindings_in] = blindings_in = segments.add()
        for i, val in enumerate(blindings_in__):
            memory[blindings_in + i] = val


        addresses_in__ = program_input["addresses_in"]
        memory[ids.addresses_in_len] = len(addresses_in__)
        memory[ids.addresses_in] = addresses_in = segments.add()
        for i in range(len(addresses_in__)):
            address_addr_x = addresses_in + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_in + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in__[i][1][2]

        assert len(amounts_in__) == len(blindings_in__) == len(addresses_in__)

        ##* OUTPUT NOTES =============================================================
        # TODO Copy inputs style to outputs

        amounts_out__ = program_input["amounts_out"]
        memory[ids.amounts_out_len] = len(amounts_out__)
        memory[ids.amounts_out] = amounts_out = segments.add()
        for i, val in enumerate(amounts_out__):
            memory[amounts_out + i] = val



        blindings_out__ = program_input["blindings_out"]
        memory[ids.blindings_out_len] = len(blindings_out__)
        memory[ids.blindings_out] = blindings_out = segments.add()
        for i, val in enumerate(blindings_out__):
            memory[blindings_out + i] = val


        addresses_out__ = program_input["addresses_out"]
        memory[ids.addresses_out_len] = len(addresses_out__)
        memory[ids.addresses_out] = addresses_out = segments.add()
        for i in range(len(addresses_out__)):
            address_addr_x = addresses_out + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_out + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_out__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_out__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_out__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_out__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_out__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_out__[i][1][2]

        assert len(amounts_out__) == len(blindings_out__) == len(addresses_out__)
    %}

    return ()
end
