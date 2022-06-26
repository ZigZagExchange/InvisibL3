# %builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_lt

func verify_commitments{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    commitments_len : felt,
    commitments : felt*,
    amounts_len : felt,
    amounts : felt*,
    blindings_len : felt,
    blindings : felt*,
):
    alloc_locals

    assert commitments_len = amounts_len
    assert amounts_len = blindings_len

    verify_commitments(commitments_len, commitments, amounts_len, amounts, blindings_len, blindings)

    return ()
end

func _verify_commitments_inner{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    commitments_len : felt,
    commitments : felt*,
    amounts_len : felt,
    amounts : felt*,
    blindings_len : felt,
    blindings : felt*,
):
    if commitments_len == 0:
        return ()
    end

    let comm = commitments[0]
    let amount = amounts[0]
    let blinding = blindings[0]

    _verify_commitment(comm, amount, blinding)

    return _verify_commitments_inner(
        commitments_len - 1,
        &commitments[1],
        amounts_len - 1,
        &amounts[1],
        blindings_len - 1,
        &blindings[1],
    )
end

func _verify_commitment{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    commitment : felt, amount : felt, blinding_factor : felt
):
    alloc_locals

    let (comm : felt) = hash2{hash_ptr=pedersen_ptr}(amount, blinding_factor)

    with_attr error_message("amount and blinding dont match commitment"):
        assert comm = commitment
    end

    with_attr error_message("amount should be in range [0, 2**128) "):
        assert_lt(amount, 2 ** 128)
    end

    return ()
end
