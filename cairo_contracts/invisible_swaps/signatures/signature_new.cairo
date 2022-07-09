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

from helpers.utils import Note

func verify_signatures{ecdsa_ptr : SignatureBuiltin*}(
    tx_hash : felt, notes_len : felt, notes : Note*
):
    alloc_locals

    let note : Note = notes[0]

    if public_keys_len != signatures_len:
        return ()
    end

    let pub_key = note.address_pk
    let sig_r = note.signature_r
    let sig_s = note.signature_s

    verify_ecdsa_signature(
        message=tx_hash,
        public_key=pub_key,
        signature_r=limit_order.sig.r,
        signature_s=limit_order.sig.s,
    )

    return verify_signatures(tx_hash, notes_len - 1, &notes[1])
end
