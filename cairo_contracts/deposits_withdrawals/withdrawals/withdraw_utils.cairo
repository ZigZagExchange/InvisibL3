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

# & This is the public output sent on-chain
struct Withdrawal:
    member withdraw_id : felt  # (may or may not be needed)
    member token : felt
    member amount : felt
    member address_pk : felt  # This should be a stark key or a representation of an eth address
end

# & Gets the notes that the user wants to spend as the input
# & The notes should sum to at least the amount the user wants to withdraw
# & The rest is refunded back to him
func get_withdraw_and_refund_notes() -> (
    withdraw_notes_len : felt, withdraw_notes : Note*, refund_note : Note
):
    alloc_locals

    local withdraw_notes_len : felt
    local withdraw_notes : Note*
    local refund_note : Note

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(&withdraw_notes_len, &withdraw_notes, &refund_note)

    return (withdraw_notes_len, withdraw_notes, refund_note)
end

func verify_withdraw_notes{
    pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(withdraw_notes_len : felt, withdraw_notes : Note*, refund_note : Note, withdrawal : Withdrawal):
    alloc_locals

    # ? Sum the notes and verify that the amount is correct
    let (withdraw_notes_sum) = sum_notes(withdraw_notes_len, withdraw_notes, withdrawal.token, 0)
    assert withdraw_notes_sum = withdrawal.amount + refund_note.amount

    # ? Hash the withdraw notes to verify signature
    let (local empty_arr : felt*) = alloc()
    let (note_hashes_len : felt, note_hashes : felt*) = hash_notes_array(
        withdraw_notes_len, withdraw_notes, 0, empty_arr
    )
    let (refund_hash : felt) = hash_note(refund_note)

    let (withdraw_hash : felt) = withdraw_tx_hash(
        note_hashes_len, note_hashes, refund_hash, withdrawal
    )

    %{ signatures = current_withdrawal["signatures"] %}

    verify_signatures(withdraw_hash, withdraw_notes_len, withdraw_notes)

    return ()
end

func verify_signatures{ecdsa_ptr : SignatureBuiltin*}(
    tx_hash : felt, notes_len : felt, notes : Note*
):
    alloc_locals

    if notes_len == 0:
        return ()
    end

    local signature_r : felt
    local signature_s : felt
    %{
        sig = signatures.pop(0)
        ids.signature_r = int(sig[0])
        ids.signature_s = int(sig[1])
    %}

    verify_ecdsa_signature(
        message=tx_hash,
        public_key=notes[0].address_pk,
        signature_r=signature_r,
        signature_s=signature_s,
    )

    return verify_signatures(tx_hash, notes_len - 1, &notes[1])
end

func withdraw_tx_hash{pedersen_ptr : HashBuiltin*}(
    note_hashes_len : felt, note_hashes : felt*, refund_hash : felt, withdrawal : Withdrawal
) -> (res):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, withdrawal.withdraw_id)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, withdrawal.token)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, withdrawal.amount)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, withdrawal.address_pk)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, refund_hash)
        let (hash_state_ptr) = hash_update(hash_state_ptr, note_hashes, note_hashes_len)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func handle_inputs(notes_len : felt*, notes : Note**, refund_note : Note*):
    %{
        #TODO Should only be defined once globaly
        NOTE_SIZE = ids.Note.SIZE
        ADDRESS_PK_OFFSET = ids.Note.address_pk
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_FACTOR_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index
        HASH_OFFSET = ids.Note.hash

        withdraw_notes = current_withdrawal["notesIn"]

        memory[ids.notes_len] = len(withdraw_notes)
        memory[ids.notes] = notes = segments.add()
        for i, note in enumerate(withdraw_notes):
            memory[notes + i*NOTE_SIZE + ADDRESS_PK_OFFSET] = int(note["address_pk"])
            memory[notes + i*NOTE_SIZE + TOKEN_OFFSET] = int(on_chain_withdraw_info["token"])
            memory[notes + i*NOTE_SIZE + AMOUNT_OFFSET] = int(note["amount"])
            memory[notes + i*NOTE_SIZE + BLINDING_FACTOR_OFFSET] = int(note["blinding"])
            memory[notes + i*NOTE_SIZE + INDEX_OFFSET] = int(note["index"])
            memory[notes + i*NOTE_SIZE + HASH_OFFSET] = int(note["hash"])

        # REFUND NOTE ==============================

        refund_note__ = current_withdrawal["refund_note"]
        memory[ids.refund_note.address_ + ADDRESS_PK_OFFSET] = int(refund_note__["address_pk"])
        memory[ids.refund_note.address_ + TOKEN_OFFSET] = int(refund_note__["token"])
        memory[ids.refund_note.address_ + AMOUNT_OFFSET] = int(refund_note__["amount"])
        memory[ids.refund_note.address_ + BLINDING_FACTOR_OFFSET] = int(refund_note__["blinding"])
        memory[ids.refund_note.address_ + INDEX_OFFSET] = int(refund_note__["index"])
        memory[ids.refund_note.address_ + HASH_OFFSET] = int(refund_note__["hash"])
    %}

    return ()
end
