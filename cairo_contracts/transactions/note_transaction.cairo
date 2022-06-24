%builtins output pedersen range_check

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
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from helpers.utils import Note

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
    local return_address : EcPoint

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
    local notes_in_len : felt
    local notes_in : Note*
    # output notes
    local notes_out_len : felt
    local notes_out : Note*

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
        &notes_in_len,
        &notes_in,
        &notes_out_len,
        &notes_out,
    )

    %{ print("All good") %}

    return ()
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
    notes_in_len : felt*,
    notes_in : Note**,
    notes_out_len : felt*,
    notes_out : Note**,
):
    %{
        # * STRUCT SIZES ==========================================================

        NOTE_SIZE = ids.Note.SIZE
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index
        ADDRESS_OFFSET = ids.Note.address

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

        memory[ids.token_spent] = program_input["token_spent"]
        memory[ids.token_spent_price] = program_input["token_spent_price"]
        memory[ids.token_received] = program_input["token_received"]
        memory[ids.token_received_price] = program_input["token_received_price"]

        ret_addr = program_input["return_address"]
        memory[ids.return_address + X_OFFSET + BIG_INT_0_OFFSET] = ret_addr[0][0]
        memory[ids.return_address + X_OFFSET + BIG_INT_1_OFFSET] = ret_addr[0][1]
        memory[ids.return_address + X_OFFSET + BIG_INT_2_OFFSET] = ret_addr[0][2]
        memory[ids.return_address + Y_OFFSET + BIG_INT_0_OFFSET] = ret_addr[1][0]
        memory[ids.return_address + Y_OFFSET + BIG_INT_1_OFFSET] = ret_addr[1][1]
        memory[ids.return_address + Y_OFFSET + BIG_INT_2_OFFSET] = ret_addr[1][2]

        # * SIGNATURE INPUTS ========================================================

        sig = program_input["signature"]
        memory[ids.signature_len] = len(sig)
        memory[ids.signature] = _signature_ = segments.add() 
        for i, val in enumerate(sig):
            memory[_signature_ + i] = val

        ret_sig = program_input["ret_addr_sig"]
        memory[ids.ret_addr_sig_c] = ret_sig[0]
        memory[ids.ret_addr_sig_r] = ret_sig[1]

        ##* INPUT NOTES ==============================================================

        indexes__ = program_input["indexes"]
        memory[ids.indexes_len] = len(indexes__)
        memory[ids.indexes] = indexes = segments.add()
        for i, val in enumerate(indexes__):
            memory[indexes + i] = val


        amounts_in = program_input["amounts_in"]
        blindings_in = program_input["blindings_in"]
        addresses_in = program_input["addresses_in"]

        assert len(tokens_in) == len(amounts_in) == len(blindings_in) == len(indexes__) == len(addresses_in)

        memory[ids.notes_in_len] = len(tokens_in)
        memory[ids.notes_in] = notes_in = segments.add()
        for i in range(len(tokens_in)):
            token_addr = notes_in + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_in + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_in + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_in + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = tokens_in[i]
            memory[amount_addr] = amounts_in[i]
            memory[blinding_addr] = blindings_in[i]
            memory[index_addr] = indexes__[i]

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in[i][1][2]

        ##* OUTPUT NOTES =============================================================

        amounts_out = program_input["amounts_out"]
        blindings_out = program_input["blindings_out"]
        addresses_out = program_input["addresses_out"]

        assert len(tokens_out) == len(amounts_out) == len(blindings_out) == len(indexes__) == len(addresses_out)

        memory[ids.notes_out_len] = len(tokens_out)
        memory[ids.notes_out] = notes_out = segments.add()
        for i in range(len(tokens_out)):
            token_addr = notes_out + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_out + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_out + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_out + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = tokens_out[i]
            memory[amount_addr] = amounts_out[i]
            memory[blinding_addr] = blindings_out[i]
            memory[index_addr] = indexes__[i]

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_out[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_out[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_out[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_out[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_out[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_out[i][1][2]
    %}

    return ()
end
