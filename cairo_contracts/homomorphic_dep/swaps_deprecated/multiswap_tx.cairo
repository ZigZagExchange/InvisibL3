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
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from swap_transaction import verify_swap

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    verify_swap(0)
    verify_swap(1)

    %{ print("multiswap ok") %}

    return ()
end
