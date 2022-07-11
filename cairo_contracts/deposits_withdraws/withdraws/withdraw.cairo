%builtins output pedersen range_check ecdsa

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

from invisible_swaps.helpers.utils import Note
from deposits_withdraws.withdraws.withdraw_utils import (
    Withdrawal,
    get_withdraw_and_refund_notes,
    verify_withdraw_notes,
)
from invisible_swaps.helpers.dict_updates import withdraw_note_dict_updates

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
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    execute_withdraw_transaction{note_dict=note_dict}()
    %{
        t2 = time.time()
        print("withdraw time: ", t2-t1)
    %}

    local note_dict_len = note_dict - note_dict_start

    %{
        print("note_dict")
        l = int(ids.note_dict_len/ids.DictAccess.SIZE)
        for i in range(l):
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +0])
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +1])
            print(memory[ids.note_dict_start.address_ + i*ids.DictAccess.SIZE +2])
            print("======")
    %}

    %{ print("all good") %}

    return ()
end

func execute_withdraw_transaction{
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    note_dict : DictAccess*,
}():
    alloc_locals

    # & This is the public on_chain withdraw information
    local withdrawal : Withdrawal
    %{
        current_withdrawal = withdrawals.pop(0)

        on_chain_withdraw_info = current_withdrawal["on_chain_withdraw_info"]

        WITHDRAWAL_SIZE = ids.Withdrawal.SIZE
        TOKEN_OFFSET = ids.Withdrawal.token
        AMOUNT_OFFSET = ids.Withdrawal.amount
        ADDRESS_PK_OFFSET = ids.Withdrawal.address_pk

        memory[ids.withdrawal.address_ + TOKEN_OFFSET] = on_chain_withdraw_info["token"]
        memory[ids.withdrawal.address_ + AMOUNT_OFFSET] = on_chain_withdraw_info["amount"]
        memory[ids.withdrawal.address_ + ADDRESS_PK_OFFSET] = on_chain_withdraw_info["stark_key"]
    %}

    let (
        withdraw_notes_len : felt, withdraw_notes : Note*, refund_note : Note
    ) = get_withdraw_and_refund_notes()

    # & Verify the amount to be withdrawn is less or equal the sum of notes spent
    # & also verify all the notes were signed correctly
    verify_withdraw_notes(withdraw_notes_len, withdraw_notes, refund_note, withdrawal)

    withdraw_note_dict_updates(withdraw_notes_len, withdraw_notes, refund_note)

    return ()
end
