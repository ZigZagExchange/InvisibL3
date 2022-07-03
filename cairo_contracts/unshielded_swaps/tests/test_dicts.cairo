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

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local my_dict : DictAccess*

    %{ ids.my_dict = segments.add() %}

    let my_dict_ptr : DictAccess* = my_dict
    assert my_dict_ptr.key = 1
    assert my_dict_ptr.prev_value = 2
    assert my_dict_ptr.new_value = 3

    let len = my_dict_ptr - my_dict
    %{
        print("len: ", ids.len)
        print("my_dict_ptr.key: ", ids.my_dict_ptr.key)
        print("my_dict_ptr.prev_value: ", ids.my_dict_ptr.prev_value)
        print("my_dict_ptr.new_value: ", ids.my_dict_ptr.new_value)
    %}

    return ()
end

# let order_dict_access : DictAccess* = order_dict
#     order_id = order_dict_access.key
#     prev_fulfilled_amount = order_dict_access.prev_value
#     new_fulfilled_amount = order_dict_access.new_value
