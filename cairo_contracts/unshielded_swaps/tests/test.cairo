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

# from unshielded_swaps.update_accounts import update_accounts
from unshielded_swaps.account_state import AccountSpace, LimitOrder, account_space_hash

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    let a = 100
    let b = 300

    let c = 50
    let c_neg = -c

    let d = a - c
    let d2 = a + c_neg

    %{
        print("c_neg: ", ids.c_neg)
        print("d: ", ids.d)
        print("d2: ", ids.d2)
    %}

    return ()
end

# func test_accounts_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
#     alloc_locals

# local accounts_len : felt
#     local accounts : AccountState*

# # Todo: Account indexes could just be used in the hints and removed as arguments here.
#     local indexes_len : felt
#     local indexes : felt*
#     # local account_dict : DictAccess*

# %{
#         # STRUCT SIZES ===================================================

# ACCOUNT_STATE_SIZE = ids.AccountState.SIZE
#         ACCOUNT_STATE_PUBLIC_KEY_OFFSET = ids.AccountState.public_key
#         ACCOUNT_STATE_TOKEN_ID_OFFSET = ids.AccountState.token_id
#         ACCOUNT_STATE_BALANCE_OFFSET = ids.AccountState.balance

# LIMIT_ORDER_SIZE = ids.LimitOrder.SIZE
#         LIMIT_ORDER_NONCE_OFFSET = ids.LimitOrder.nonce
#         LIMIT_ORDER_PUBLIC_KEY_OFFSET = ids.LimitOrder.public_key
#         LIMIT_ORDER_EXPIRATION_TIMESTAMP_OFFSET = ids.LimitOrder.expiration_timestamp
#         LIMIT_ORDER_SIGNATURE_R_OFFSET = ids.LimitOrder.signature_r
#         LIMIT_ORDER_SIGNATURE_S_OFFSET = ids.LimitOrder.signature_s
#         LIMIT_ORDER_TOKEN_SPENT_OFFSET = ids.LimitOrder.token_spent
#         LIMIT_ORDER_TOKEN_RECEIVED_OFFSET = ids.LimitOrder.token_received
#         LIMIT_ORDER_AMOUNT_SPENT_OFFSET = ids.LimitOrder.amount_spent
#         LIMIT_ORDER_AMOUNT_RECEIVED_OFFSET = ids.LimitOrder.amount_received
#         LIMIT_ORDER_SPENDER_ACCOUNT_OFFSET = ids.LimitOrder.spender_account
#         LIMIT_ORDER_RECEIVER_ACCOUNT_OFFSET = ids.LimitOrder.receiver_account

# # INITIALIZATION ==================================================
#         # Initialize the accounts
#         accounts = program_input["accounts"]
#         ids.accounts_len = len(accounts)

# ids.accounts = accs_addr = segments.add()
#         for i, acc in enumerate(accounts):
#             memory[accs_addr + i * ACCOUNT_STATE_SIZE + ACCOUNT_STATE_PUBLIC_KEY_OFFSET] = acc["public_key"]
#             memory[accs_addr + i * ACCOUNT_STATE_SIZE + ACCOUNT_STATE_TOKEN_ID_OFFSET] = acc["token_id"]
#             memory[accs_addr + i * ACCOUNT_STATE_SIZE + ACCOUNT_STATE_BALANCE_OFFSET] = acc["balance"]

# indexes = program_input["indexes"]
#         ids.indexes_len = len(indexes)
#         ids.indexes = indexes_addr = segments.add()
#         for i, idx in enumerate(indexes):
#             memory[indexes_addr + i] = idx

# # Initialize the account dict
#         # ids.account_dict = segments.add()
#     %}

# %{ initial_dict = {k:0 for k in indexes} %}

# let (account_dict : DictAccess*) = dict_new()

# let (account_dict : DictAccess*) = _array_hash_write_to_dict(
#         account_dict, indexes_len, indexes, accounts_len, accounts
#     )

# let dict_start : DictAccess* = account_dict
#     let (account_dict : DictAccess*) = _array_hash_and_update_dict(
#         account_dict, indexes_len, indexes, accounts_len, accounts, accounts_len, accounts
#     )

# let (finalized_dict_start, finalized_dict_end) = dict_squash(dict_start, account_dict)

# let x = finalized_dict_start[0]
#     let y = finalized_dict_start[1]
#     let z = finalized_dict_start[2]

# %{
#         print("key:", ids.x.key)
#         print("prev:", ids.x.prev_value)
#         print("new:", ids.x.new_value)
#         print("key:", ids.y.key)
#         print("prev:", ids.y.prev_value)
#         print("new:", ids.y.new_value)
#         print("key:", ids.z.key)
#         print("prev:", ids.z.prev_value)
#         print("new:", ids.z.new_value)
#     %}

# return ()
# end

# func _array_hash_and_update_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     dict_ptr : DictAccess*,
#     indexes_len : felt,
#     indexes : felt*,
#     prev_arr_len : felt,
#     prev_arr : AccountState*,
#     new_arr_len : felt,
#     new_arr : AccountState*,
# ) -> (dict_ptr : DictAccess*):
#     alloc_locals

# if new_arr_len == 0:
#         return (dict_ptr)
#     end

# let index : felt = indexes[0]

# let prev_ : AccountState = prev_arr[0]
#     let new_ : AccountState = new_arr[0]

# let (prev_acc_hash : felt) = account_state_hash(&prev_)
#     let (new_acc_hash : felt) = account_state_hash(&new_)

# dict_update{dict_ptr=dict_ptr}(index, prev_acc_hash, new_acc_hash)

# return _array_hash_and_update_dict(
#         dict_ptr,
#         indexes_len - 1,
#         &indexes[1],
#         prev_arr_len - 1,
#         &prev_arr[1],
#         new_arr_len - 1,
#         &new_arr[1],
#     )
# end

# func _array_hash_write_to_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     dict_ptr : DictAccess*,
#     indexes_len : felt,
#     indexes : felt*,
#     prev_arr_len : felt,
#     prev_arr : AccountState*,
# ) -> (dict_ptr : DictAccess*):
#     alloc_locals

# if prev_arr_len == 0:
#         return (dict_ptr)
#     end

# let index : felt = indexes[0]

# let prev_ : AccountState = prev_arr[0]

# let (prev_acc_hash : felt) = account_state_hash(&prev_)

# dict_write{dict_ptr=dict_ptr}(index, prev_acc_hash)

# return _array_hash_write_to_dict(
#         dict_ptr, indexes_len - 1, &indexes[1], prev_arr_len - 1, &prev_arr[1]
#     )
# end
