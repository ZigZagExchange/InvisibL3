from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_lt

func verify_sums{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    amounts_in_len : felt, amounts_in : felt*, amounts_out_len : felt, amounts_out : felt*
):
    alloc_locals

    let (sum_in : felt) = sum_array(amounts_in_len, amounts_in, 0)
    let (sum_out : felt) = sum_array(amounts_out_len, amounts_out, 0)

    assert sum_in = sum_out

    return ()
end

func sum_array{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, sum : felt
) -> (sum):
    alloc_locals

    if arr_len == 0:
        return (sum)
    end

    let sum = sum + arr[0]

    return sum_array(arr_len - 1, &arr[1], sum)
end
