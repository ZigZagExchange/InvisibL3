%builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_lt

func verify_commitment{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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

# template VerifyCommitments(n){
#     signal input C[n];
#     signal input amounts[n];
#     signal input blindings[n];

# component commitments[n];
#     component lessThan[n];
#     component equalIf[n];

# for (var i=0; i<n; i++) {

# // Verify amounts are in range (non negative)
#         lessThan[i] = LessThan(68);
#         lessThan[i].in[0] <== amounts[i];
#         lessThan[i].in[1] <== 2 ** 67;

# lessThan[i].out === 1;

# commitments[i] = Poseidon(2);
#         commitments[i].inputs[0] <== amounts[i];
#         commitments[i].inputs[1] <== blindings[i];

# equalIf[i] = ForceEqualIfEnabled();
#         equalIf[i].in[0] <== commitments[i].out;
#         equalIf[i].in[1] <== C[i];
#         equalIf[i].enabled <== C[i];

# }
