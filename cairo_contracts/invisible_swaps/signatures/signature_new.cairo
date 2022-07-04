from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_double, ec_add, ec_mul, ec_negate
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from helpers.utils import Signature

func verify_signatures{
    output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*
}(
    tx_hash : felt,
    public_keys_len : felt,
    public_keys : felt*,
    signatures_len : felt,
    signatures : Signature*,
):
    alloc_locals

    if public_keys_len != signatures_len:
        return ()
    end

    let pub_key = public_keys_len[0]
    let sig : Signature = signatures_len[0]

    verify_ecdsa_signature(
        message=tx_hash,
        public_key=pub_key,
        signature_r=limit_order.sig.r,
        signature_s=limit_order.sig.s,
    )

    return verify_signatures(
        tx_hash, public_keys_len - 1, &public_keys[1], signatures_len - 1, &signatures[1]
    )
end
