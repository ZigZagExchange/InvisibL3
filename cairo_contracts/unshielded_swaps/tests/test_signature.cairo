%builtins output pedersen range_check ecdsa

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.signature import verify_ecdsa_signature

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr, ecdsa_ptr : SignatureBuiltin*}(
    ):
    alloc_locals

    let message_hash = 123456789
    let signature_r = 3196657444817187243573233786312977610206286094500582652606332431225828149187
    let signature_s = 2797723669105387659350630260337555718207875803099154840419227705240231641637
    let public_key = 1628448741648245036800002906075225705100596136133912895015035902954123957052

    verify_ecdsa_signature(
        message=message_hash,
        public_key=public_key,
        signature_r=signature_r,
        signature_s=signature_s,
    )

    %{ print("all good") %}

    return ()
end
