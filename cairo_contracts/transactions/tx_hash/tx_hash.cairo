%builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_double, ec_add, ec_mul, ec_negate
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

    local indexes_len : felt
    local indexes : felt*
    local notes_in_len : felt
    local notes_in : Note*
    local notes_out_len : felt
    local notes_out : Note*
    local token : felt
    local token_price : felt
    local ret_sig_r : felt

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &indexes_len,
        &indexes,
        &notes_in_len,
        &notes_in,
        &notes_out_len,
        &notes_out,
        &token,
        &token_price,
        &ret_sig_r,
    )

    let (local empty_arr) = alloc()
    let (hashed_notes_in_len : felt, hashed_notes_in : felt*) = hash_notes_array(
        notes_in_len, notes_in, 0, empty_arr, notes_in_len
    )

    let (local empty_arr) = alloc()
    let (hashed_notes_out_len : felt, hashed_notes_out : felt*) = hash_notes_array(
        notes_out_len, notes_out, 0, empty_arr, notes_out_len
    )

    let (tx_hash : felt) = hash_transaction(
        hashed_notes_in_len,
        hashed_notes_in,
        hashed_notes_out_len,
        hashed_notes_out,
        token,
        token_price,
        ret_sig_r,
    )

    %{ print("tx_hash: ", ids.tx_hash) %}

    return ()
end

func handle_inputs{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    indexes_len : felt*,
    indexes : felt**,
    notes_in_len : felt*,
    notes_in : Note**,
    notes_out_len : felt*,
    notes_out : Note**,
    token : felt*,
    token_price : felt*,
    ret_sig_r : felt*,
):
    alloc_locals

    %{
        memory[ids.token] = token = program_input["token"]
        memory[ids.token_price] = program_input["token_price"]
        memory[ids.ret_sig_r] = program_input["ret_sig_r"]

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


        ##* INPUT NOTES ======================================================

        indexes__ = program_input["indexes"]
        memory[ids.indexes_len] = len(indexes__)
        memory[ids.indexes] = indexes = segments.add()
        for i, val in enumerate(indexes__):
            memory[indexes + i] = val

        data_in = program_input["data_in"]

        amounts_in = data_in["amounts"]
        blindings_in = data_in["blindings"]
        addresses_in = data_in["addresses"]

        assert len(amounts_in) == len(blindings_in) == len(indexes__) == len(addresses_in)

        memory[ids.notes_in_len] = len(amounts_in)
        memory[ids.notes_in] = notes_in = segments.add()
        for i in range(len(amounts_in)):
            token_addr = notes_in + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_in + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_in + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_in + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = token
            memory[amount_addr] = amounts_in[i]
            memory[blinding_addr] = blindings_in[i]
            memory[index_addr] = indexes__[i]

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in[i][1][2]

        ##* OUTPUT NOTES ======================================================
        data_out = program_input["data_out"]

        amounts_out = data_out["amounts"]
        blindings_out = data_out["blindings"]
        addresses_out = data_out["addresses"]

        assert len(amounts_out) == len(blindings_out) == len(indexes__) == len(addresses_out)

        memory[ids.notes_out_len] = len(amounts_out)
        memory[ids.notes_out] = notes_out = segments.add()
        for i in range(len(amounts_out)):
            token_addr = notes_out + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_out + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_out + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_out + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = token
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

func hash_notes_array{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_len : felt, notes : Note*, arr_len : felt, arr : felt*, total_len : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    if arr_len == total_len:
        return (arr_len, arr)
    end

    let (note_hash : felt) = hash_note(notes[0])

    assert arr[arr_len] = note_hash

    return hash_notes_array(notes_len - 1, &notes[1], arr_len + 1, arr, total_len)
end

func hash_note{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(note : Note) -> (
    res : felt
):
    alloc_locals

    let (px : Uint256) = bigint_to_uint256(note.address.x)
    let (py : Uint256) = bigint_to_uint256(note.address.y)

    let (hash_x : felt) = hash2{hash_ptr=pedersen_ptr}(px.high, px.low)
    let (hash_y : felt) = hash2{hash_ptr=pedersen_ptr}(py.high, py.low)

    let (commitment : felt) = hash2{hash_ptr=pedersen_ptr}(note.amount, note.blinding_factor)

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, hash_x)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, hash_y)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, note.token)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, commitment)

        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func hash_transaction{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    hashes_in_len : felt,
    hashes_in : felt*,
    hashes_out_len : felt,
    hashes_out : felt*,
    token_spent : felt,
    token_spent_price : felt,
    return_sig_r : felt,
) -> (res):
    alloc_locals

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update(hash_state_ptr, hashes_in, hashes_in_len)
        let (hash_state_ptr) = hash_update(hash_state_ptr, hashes_out, hashes_out_len)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, token_spent)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, token_spent_price)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, return_sig_r)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

# #############################################################################
# #############################################################################

func hash_priv_inputs{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_received : felt, token_received_price : felt
) -> (res):
    alloc_locals

    let (hash : felt) = hash2{hash_ptr=pedersen_ptr}(token_received, token_received_price)

    return (hash)
end
