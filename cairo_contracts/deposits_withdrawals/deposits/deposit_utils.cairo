from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.signature import verify_ecdsa_signature
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from invisible_swaps.helpers.utils import Note, hash_note, sum_notes
from invisible_swaps.swap.tx_hash.tx_hash import hash_notes_array

# & This is the public input retrieved from on-chain
struct Deposit:
    member deposit_id : felt  # (may or may not be needed)
    member token : felt
    member amount : felt
    member address_pk : felt
end

# & Creats new notes from the public deposit information and private user input
# & The user can input arbitrary number of notes and the function will return the
# & corresponding notes that must sum to the amount he deposited.
func get_deposit_notes() -> (deposit_notes_len : felt, deposit_notes : Note*):
    alloc_locals

    local deposit_notes_len : felt
    local deposit_notes : Note*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(&deposit_notes_len, &deposit_notes)

    return (deposit_notes_len, deposit_notes)
end

func verify_deposit_notes{
    pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(deposit_notes_len : felt, deposit_notes : Note*, deposit : Deposit):
    alloc_locals

    # ? Sum the notes and verify that the sum is correct
    let (deposit_sum) = sum_notes(deposit_notes_len, deposit_notes, deposit.token, 0)
    assert deposit_sum = deposit.amount

    # ? Hash the deposit notes to verify signature
    let (local empty_arr : felt*) = alloc()
    let (note_hashes_len : felt, note_hashes : felt*) = hash_notes_array(
        deposit_notes_len, deposit_notes, 0, empty_arr
    )

    let (deposit_hash : felt) = deposit_tx_hash(note_hashes_len, note_hashes, deposit.deposit_id)

    local signature_r : felt
    local signature_s : felt
    %{
        sig = current_deposit["signature"]
        ids.signature_r = int(sig[0])
        ids.signature_s = int(sig[1])
    %}

    verify_ecdsa_signature(
        message=deposit_hash,
        public_key=deposit.address_pk,
        signature_r=signature_r,
        signature_s=signature_s,
    )

    return ()
end

func deposit_tx_hash{pedersen_ptr : HashBuiltin*}(
    note_hashes_len : felt, note_hashes : felt*, deposit_id : felt
) -> (res):
    alloc_locals

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, deposit_id)
        let (hash_state_ptr) = hash_update(hash_state_ptr, note_hashes, note_hashes_len)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func handle_inputs(notes_len : felt*, notes : Note**):
    %{
        #TODO Should only be defined once globaly
        NOTE_SIZE = ids.Note.SIZE
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index
        HASH_OFFSET = ids.Note.hash

        on_chain_deposit_info = current_deposit["on_chain_deposit_info"]

        notes = current_deposit["notes"]

        memory[ids.notes_len] = len(notes)
        memory[ids.notes] = notes_addr = segments.add()
        for i in range(len(notes)):
            memory[notes_addr + i*NOTE_SIZE + ADDRESS_PK_OFFSET] = int(notes[i]["address_pk"])
            memory[notes_addr + i*NOTE_SIZE + TOKEN_OFFSET] = int(on_chain_deposit_info["token"])
            memory[notes_addr + i*NOTE_SIZE + AMOUNT_OFFSET] = int(notes[i]["amount"])
            memory[notes_addr + i*NOTE_SIZE + BLINDING_FACTOR_OFFSET] = int(notes[i]["blinding"])
            memory[notes_addr + i*NOTE_SIZE + INDEX_OFFSET] = int(notes[i]["index"])
            memory[notes_addr + i*NOTE_SIZE + HASH_OFFSET] = int(notes[i]["hash"])
    %}

    return ()
end
