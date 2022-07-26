# %builtins output pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from invisible_swaps.helpers.utils import Note
from deposits_withdrawals.withdrawals.withdraw_utils import (
    Withdrawal,
    get_withdraw_and_refund_notes,
    verify_withdraw_notes,
)
from invisible_swaps.helpers.dict_updates import withdraw_note_dict_updates
from rollup.output_structs import (
    NoteDiffOutput,
    WithdrawalTransactionOutput,
    write_withdrawal_info_to_output,
)

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
    ):
    alloc_locals

    # ! GLOBAL CONFIGURATIONS
    %{ withdrawals = program_input["withdraw_data"] %}

    local note_dict : DictAccess*
    %{ ids.note_dict = segments.add() %}
    local note_dict_start : DictAccess* = note_dict

    %{
        import time 
        t1 = time.time()
    %}
    verify_withdrawal{note_dict=note_dict}()
    %{
        t2 = time.time()
        print("withdraw time: ", t2-t1)
    %}

    # ======================================================
    local squashed_note_dict : DictAccess*
    %{ ids.squashed_note_dict = segments.add() %}
    let (squashed_note_dict_end) = squash_dict(
        dict_accesses=note_dict_start, dict_accesses_end=note_dict, squashed_dict=squashed_note_dict
    )
    local squashed_note_dict_len = squashed_note_dict_end - squashed_note_dict
    # ======================================================

    %{
        # print("note_dict")
        # l = int(ids.squashed_note_dict_len/ids.DictAccess.SIZE)
        # for i in range(l):
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +0])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +1])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +2])
        #     print("======")
    %}

    local prev_root : felt
    local new_root : felt
    %{
        ids.prev_root = int(program_input["prev_root"])
        ids.new_root = int(program_input["new_root"])

        preimage = program_input["preimage"]
        preimage = {int(k):[int(x) for x in v] for k,v in preimage.items()}
    %}

    merkle_multi_update{hash_ptr=pedersen_ptr}(
        squashed_note_dict, squashed_note_dict_len / DictAccess.SIZE, 3, prev_root, new_root
    )

    %{ print("all good") %}

    return ()
end

func verify_withdrawal{
    note_output_ptr : NoteDiffOutput*,
    withdraw_output_ptr : WithdrawalTransactionOutput*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
    note_dict : DictAccess*,
}():
    alloc_locals

    # & This is the public on_chain withdraw information
    local withdrawal : Withdrawal
    %{
        # current_withdrawal = withdrawals.pop(0)

        on_chain_withdraw_info = current_withdrawal["on_chain_withdraw_info"]

        WITHDRAWAL_SIZE = ids.Withdrawal.SIZE
        WITHDRAW_ID_OFFSET = ids.Withdrawal.withdraw_id
        TOKEN_OFFSET = ids.Withdrawal.token
        AMOUNT_OFFSET = ids.Withdrawal.amount
        ADDRESS_PK_OFFSET = ids.Withdrawal.address_pk

        memory[ids.withdrawal.address_ + WITHDRAW_ID_OFFSET] = int(on_chain_withdraw_info["withdraw_id"])
        memory[ids.withdrawal.address_ + TOKEN_OFFSET] = int(on_chain_withdraw_info["token"])
        memory[ids.withdrawal.address_ + AMOUNT_OFFSET] = int(on_chain_withdraw_info["amount"])
        memory[ids.withdrawal.address_ + ADDRESS_PK_OFFSET] = int(on_chain_withdraw_info["stark_key"])
    %}

    let (
        withdraw_notes_len : felt, withdraw_notes : Note*, refund_note : Note
    ) = get_withdraw_and_refund_notes()

    # & Verify the amount to be withdrawn is less or equal the sum of notes spent
    # & also verify all the notes were signed correctly
    verify_withdraw_notes(withdraw_notes_len, withdraw_notes, refund_note, withdrawal)

    # Update the note dict
    withdraw_note_dict_updates(withdraw_notes_len, withdraw_notes, refund_note)

    # write withdrawal info to the output
    write_withdrawal_info_to_output(withdrawal)

    return ()
end
