from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature

from invisible_swaps.helpers.utils import Note

# todo||   check if starknet signatures can be distributive so that the signature
# todo||   verifiction can be done in a single step, rather than seperately for each note
# todo||   E.g. Address1 + address2 + address3 = (pk1 + pk2 + pk3) * G

func verify_signatures{ecdsa_ptr : SignatureBuiltin*}(
    tx_hash : felt, notes_len : felt, notes : Note*
):
    alloc_locals

    if notes_len == 0:
        return ()
    end

    let note : Note = notes[0]

    let pub_key = note.address_pk
    local sig_r : felt
    local sig_s : felt
    %{
        sig = signatures.pop()
        ids.sig_r = int(sig[0])
        ids.sig_s = int(sig[1])
    %}

    verify_ecdsa_signature(
        message=tx_hash, public_key=pub_key, signature_r=sig_r, signature_s=sig_s
    )

    return verify_signatures(tx_hash, notes_len - 1, &notes[1])
end
