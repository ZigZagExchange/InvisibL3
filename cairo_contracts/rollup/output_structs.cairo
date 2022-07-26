from starkware.cairo.common.cairo_builtins import HashBuiltin, BitwiseBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.bitwise import bitwise_xor, bitwise_and
from invisible_swaps.helpers.utils import Note
from deposits_withdrawals.deposits.deposit_utils import Deposit
from deposits_withdrawals.withdrawals.withdraw_utils import Withdrawal
from unshielded_swaps.constants import ZERO_LEAF, BIT_64_AMOUNT

struct GlobalDexState:
    member global_config_code : felt  # why do we need this? (rename)
    member init_state_root : felt
    member final_state_root : felt
    member tree_depth : felt
    member global_expiration_timestamp : felt
    member n_swaps : felt
    member n_deposits : felt
    member n_withdrawals : felt
end

# Represents the struct of data written to the program output for each Note Modifictaion.
struct NoteDiffOutput:
    # & batched_note_info format: | idx (64 bits) | token (64 bits) | hidden amount (64 bits) |
    member batched_note_info : felt
    member address : felt
    member commitment : felt
end

# Represents the struct of data written to the program output for each Deposit.
struct DepositTransactionOutput:
    # & batched_note_info format: | deposit_id (64 bits) | token (64 bits) | amount (64 bits) |
    member batched_deposit_info : felt
    member stark_key : felt
end

# Represents the struct of data written to the program output for each Withdrawal.
struct WithdrawalTransactionOutput:
    # & batched_note_info format: | withdraw_id (64 bits) | token (64 bits) | amount (64 bits) |
    member batched_withdraw_info : felt
    member stark_key : felt  # This should be a stark key or a representation of an eth address
end

func write_new_note_to_output{
    note_output_ptr : NoteDiffOutput*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*
}(note : Note):
    alloc_locals

    let output : NoteDiffOutput* = note_output_ptr

    let (trimed_blinding : felt) = bitwise_and(note.blinding_factor, BIT_64_AMOUNT)
    let (hidden_amount : felt) = bitwise_xor(note.amount, trimed_blinding)
    assert output.batched_note_info = ((note.index * 2 ** 128) + note.token) * 2 ** 64 + hidden_amount
    let (comm : felt) = hash2{hash_ptr=pedersen_ptr}(note.amount, note.blinding_factor)
    assert output.commitment = comm
    assert output.address = note.address_pk

    let note_output_ptr = note_output_ptr + NoteDiffOutput.SIZE

    return ()
end

func write_zero_note_to_output{
    note_output_ptr : NoteDiffOutput*, pedersen_ptr : HashBuiltin*, bitwise_ptr : BitwiseBuiltin*
}(index : felt):
    alloc_locals

    let output : NoteDiffOutput* = note_output_ptr

    assert output.batched_note_info = index * 2 ** 128
    assert output.commitment = 0
    assert output.address = 0

    let note_output_ptr = note_output_ptr + NoteDiffOutput.SIZE

    return ()
end

func write_deposit_info_to_output{
    deposit_output_ptr : DepositTransactionOutput*,
    pedersen_ptr : HashBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
}(deposit : Deposit):
    alloc_locals

    let output : DepositTransactionOutput* = deposit_output_ptr

    assert output.batched_deposit_info = ((deposit.deposit_id * 2 ** 128) + deposit.token) * 2 ** 64 + deposit.amount
    assert output.stark_key = deposit.address_pk

    let deposit_output_ptr = deposit_output_ptr + DepositTransactionOutput.SIZE

    return ()
end

func write_withdrawal_info_to_output{
    withdraw_output_ptr : WithdrawalTransactionOutput*,
    pedersen_ptr : HashBuiltin*,
    bitwise_ptr : BitwiseBuiltin*,
}(withdrawal : Withdrawal):
    alloc_locals

    let output : WithdrawalTransactionOutput* = withdraw_output_ptr

    assert output.batched_withdraw_info = ((withdrawal.withdraw_id * 2 ** 128) + withdrawal.token) * 2 ** 64 + withdrawal.amount
    assert output.stark_key = withdrawal.address_pk

    let withdraw_output_ptr = withdraw_output_ptr + WithdrawalTransactionOutput.SIZE

    return ()
end
