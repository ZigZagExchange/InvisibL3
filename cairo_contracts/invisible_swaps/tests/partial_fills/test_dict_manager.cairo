%builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
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
from starkware.cairo.common.squash_dict import squash_dict
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    local test_dict : DictAccess*
    %{ ids.test_dict = segments.add() %}
    let test_dict_start = test_dict

    let test_dict_ptr = test_dict
    assert test_dict_ptr.key = 123
    assert test_dict_ptr.prev_value = 222
    assert test_dict_ptr.new_value = 222

    let test_dict_ptr = test_dict + DictAccess.SIZE

    assert test_dict_ptr.key = 456
    assert test_dict_ptr.prev_value = 444
    assert test_dict_ptr.new_value = 444

    let test_dict = test_dict + 2 * DictAccess.SIZE

    %{
        dict_manager = {
        123: ids.test_dict_start.address_,
        456: ids.test_dict_ptr.address_
        }
    %}

    dummy_test{test_dict=test_dict}(123, 222)

    %{ print("all good") %}

    return ()
end

func dummy_test{test_dict : DictAccess*}(key, value):
    alloc_locals

    %{
        addr_ = dict_manager[ids.key]

        memory[ap] = addr_
    %}
    ap += 1
    let dict_access : DictAccess* = cast([ap - 1], DictAccess*)

    %{
        print(ids.dict_access.key)
        print(ids.dict_access.prev_value)
        print(ids.dict_access.new_value)
    %}

    dict_access.key = key
    dict_access.prev_value = value
    dict_access.new_value = value

    return ()
end
