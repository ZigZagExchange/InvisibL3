%builtins output pedersen range_check ecdsa bitwise

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

from invisible_swaps.swap.invisible_swap import verify_swap
from deposits_withdrawals.deposits.deposit import verify_deposit
from deposits_withdrawals.withdrawals.withdrawal import verify_withdrawal

from rollup.output_structs import (
    GlobalDexState,
    NoteDiffOutput,
    WithdrawalTransactionOutput,
    DepositTransactionOutput,
)

const TREE_DEPTH = 5

func main{
    output_ptr,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
}():
    alloc_locals

    # GLOBAL VERIABLES
    %{
        transaction_input_data = program_input["transactions"] 
        prev_filled_dict_manager = {}
        prev_fill_notes = {}
        prev_fill_note_hashes = {}
        fee_tracker_dict_manager = {}
    %}

    # * INITIALIZE DICTIONARIES ******************************************************
    local note_dict : DictAccess*
    local partial_fill_dict : DictAccess*
    local fee_tracker_dict : DictAccess*
    %{
        ids.note_dict = segments.add()
        ids.partial_fill_dict = segments.add()
        ids.fee_tracker_dict = segments.add()
    %}
    let note_dict_start = note_dict
    let partial_fill_dict_start = partial_fill_dict
    let fee_tracker_dict_start = fee_tracker_dict

    # * SPLIT OUTPUT SECTIONS ******************************************************
    local dex_state_ptr : GlobalDexState* = cast(output_ptr, GlobalDexState*)
    local deposit_output_ptr : DepositTransactionOutput*
    local withdraw_output_ptr : WithdrawalTransactionOutput*
    local note_output_ptr : NoteDiffOutput*
    %{
        global_dex_state = program_input["global_dex_state"]
        ids.dex_state_ptr.global_config_code = int(global_dex_state["global_config_code"])
        ids.dex_state_ptr.init_state_root = int(global_dex_state["init_state_root"])
        ids.dex_state_ptr.final_state_root = int(global_dex_state["final_state_root"])
        ids.dex_state_ptr.tree_depth = int(global_dex_state["tree_depth"])
        ids.dex_state_ptr.global_expiration_timestamp = int(global_dex_state["global_expiration_timestamp"])
        ids.dex_state_ptr.n_swaps = int(global_dex_state["n_swaps"])
        ids.dex_state_ptr.n_deposits = int(global_dex_state["n_deposits"])
        ids.dex_state_ptr.n_withdrawals = int(global_dex_state["n_withdrawals"])


        ids.deposit_output_ptr = ids.dex_state_ptr.address_ + ids.GlobalDexState.SIZE
        ids.withdraw_output_ptr = ids.deposit_output_ptr.address_ + int(global_dex_state["n_deposits"]) * ids.DepositTransactionOutput.SIZE
        ids.note_output_ptr = ids.withdraw_output_ptr.address_ + int(global_dex_state["n_withdrawals"]) * ids.WithdrawalTransactionOutput.SIZE
    %}

    # * EXECUTE TRANSACTION BATCH ================================================

    %{
        import time
        t1_start = time.time()
    %}
    execute_transactions{
        deposit_output_ptr=deposit_output_ptr,
        withdraw_output_ptr=withdraw_output_ptr,
        note_output_ptr=note_output_ptr,
        note_dict=note_dict,
        partial_fill_dict=partial_fill_dict,
        fee_tracker_dict=fee_tracker_dict,
    }()
    %{
        t2_end = time.time()
        print("batch execution time total: ", t2_end-t1_start)
    %}

    # update the output ptr to point to the end of the program output
    let output_ptr : felt = cast(note_output_ptr, felt)

    # * ===========================================================================

    local squashed_note_dict : DictAccess*
    %{ ids.squashed_note_dict = segments.add() %}
    let (squashed_note_dict_end) = squash_dict(
        dict_accesses=note_dict_start, dict_accesses_end=note_dict, squashed_dict=squashed_note_dict
    )
    local squashed_note_dict_len = squashed_note_dict_end - squashed_note_dict

    # ================================================

    local squashed_fee_tracker_dict : DictAccess*
    %{ ids.squashed_fee_tracker_dict = segments.add() %}
    let (squashed_fee_tracker_dict_end) = squash_dict(
        dict_accesses=fee_tracker_dict_start,
        dict_accesses_end=fee_tracker_dict,
        squashed_dict=squashed_fee_tracker_dict,
    )
    local squashed_fee_tracker_dict_len = squashed_fee_tracker_dict_end - squashed_fee_tracker_dict

    # * VERIFY MERKLE TREE UPDATES ******************************************************

    %{ t1_merkle = time.time() %}
    local prev_root : felt
    local new_root : felt
    %{
        ids.prev_root = int(program_input["prev_root"])  # Public input (from on-chain)
        ids.new_root = int(program_input["new_root"])  # Public input (from on-chain)

        preimage = program_input["preimage"]
        preimage = {int(k):[int(x) for x in v] for k,v in preimage.items()}
    %}

    # merkle_multi_update{hash_ptr=pedersen_ptr}(
    #     squashed_note_dict,
    #     squashed_note_dict_len / DictAccess.SIZE,
    #     TREE_DEPTH,
    #     prev_root,
    #     new_root,
    # )

    %{
        t2_merkle = time.time()
        print("merkle update time: ", t2_merkle - t1_merkle)
    %}

    %{
        # print("note_dict")
        # l = int(ids.squashed_note_dict_len/ids.DictAccess.SIZE)
        # for i in range(l):
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +0])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +1])
        #     print(memory[ids.squashed_note_dict.address_ + i*ids.DictAccess.SIZE +2])
        #     print("======")

        # print("fee_tracker_dict")
        # l2 = int(ids.squashed_fee_tracker_dict_len/ids.DictAccess.SIZE)
        # for i in range(l2):
        #     print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +0])
        #     print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +1])
        #     print(memory[ids.squashed_fee_tracker_dict.address_ + i*ids.DictAccess.SIZE +2])
        #     print("======")
    %}

    %{ print("all good") %}

    return ()
end

func execute_transactions{
    deposit_output_ptr : DepositTransactionOutput*,
    withdraw_output_ptr : WithdrawalTransactionOutput*,
    note_output_ptr : NoteDiffOutput*,
    pedersen_ptr : HashBuiltin*,
    range_check_ptr,
    ecdsa_ptr : SignatureBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
    note_dict : DictAccess*,
    partial_fill_dict : DictAccess*,
    fee_tracker_dict : DictAccess*,
}():
    alloc_locals

    if nondet %{ len(transaction_input_data) == 0 %} != 0:
        return ()
    end

    %{
        current_transaction = transaction_input_data.pop(0) 
        txType = None
        try:
            txType = current_transaction["transactionType"]
        except:
            pass
    %}

    if nondet %{ txType == "swap" %} != 0:
        %{ current_swap = current_transaction %}

        verify_swap{
            note_dict=note_dict,
            partial_fill_dict=partial_fill_dict,
            fee_tracker_dict=fee_tracker_dict,
        }()

        return execute_transactions()
    end

    if nondet %{ txType == "deposit" %} != 0:
        %{ current_deposit = current_transaction %}

        verify_deposit{note_dict=note_dict}()

        return execute_transactions()
    end

    if nondet %{ txType == "withdrawal" %} != 0:
        %{ current_withdrawal = current_transaction %}

        verify_withdrawal{note_dict=note_dict}()

        return execute_transactions()
    else:
        %{ print("unknown transaction type: ", current_transaction) %}
        return execute_transactions()
    end
end
