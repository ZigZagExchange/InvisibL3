# %builtins output pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin, BitwiseBuiltin
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
from deposits_withdrawals.deposits.deposit_utils import (
    Deposit,
    get_deposit_notes,
    verify_deposit_notes,
)
from invisible_swaps.helpers.dict_updates import deposit_note_dict_updates
from rollup.output_structs import (
    NoteDiffOutput,
    DepositTransactionOutput,
    write_deposit_info_to_output,
)

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
    ):
    alloc_locals

    # ! GLOBAL CONFIGURATIONS
    %{ deposits = program_input["deposit_data"] %}

    local note_dict : DictAccess*
    %{ ids.note_dict = segments.add() %}
    local note_dict_start : DictAccess* = note_dict

    %{
        import time
        t1 = time.time()
    %}
    verify_deposit{note_dict=note_dict}()
    %{
        t2 = time.time()
        print("deposit time: ", t2-t1)
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

func verify_deposit{
    note_output_ptr : NoteDiffOutput*,
    deposit_output_ptr : DepositTransactionOutput*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
    note_dict : DictAccess*,
}():
    alloc_locals

    # & This is the public on_chain deposit information
    local deposit : Deposit
    %{
        # current_deposit = deposits.pop(0)
           
        on_chain_deposit_info = current_deposit["on_chain_deposit_info"]

        DEPOSIT_SIZE = ids.Deposit.SIZE
        DEPOSIT_ID_OFFSET = ids.Deposit.deposit_id
        TOKEN_OFFSET = ids.Deposit.token
        AMOUNT_OFFSET = ids.Deposit.amount
        ADDRESS_PK_OFFSET = ids.Deposit.address_pk

        memory[ids.deposit.address_ + DEPOSIT_ID_OFFSET] = int(on_chain_deposit_info["deposit_id"])
        memory[ids.deposit.address_ + TOKEN_OFFSET] = int(on_chain_deposit_info["token"])
        memory[ids.deposit.address_ + AMOUNT_OFFSET] = int(on_chain_deposit_info["amount"])
        memory[ids.deposit.address_ + ADDRESS_PK_OFFSET] = int(on_chain_deposit_info["stark_key"])
    %}

    let (deposit_notes_len : felt, deposit_notes : Note*) = get_deposit_notes()

    # & Verify the newly minted deposit notes have the same amount and token as the on-chain deposit
    # & Also verify that the deposit was signed by the owner of the deposit address
    verify_deposit_notes(deposit_notes_len, deposit_notes, deposit)

    # Update the note dict
    deposit_note_dict_updates(deposit_notes_len, deposit_notes)

    # Write the deposit info to the output
    write_deposit_info_to_output(deposit)

    return ()
end
