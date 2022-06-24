from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.cairo_secp.bigint import BigInt3
from starkware.cairo.common.cairo_secp.ec import EcPoint

func generator{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : EcPoint):
    alloc_locals

    local Gx : BigInt3 = BigInt3(
        d0=17117865558768631194064792, d1=12501176021340589225372855, d2=9198697782662356105779718
        )
    local Gy : BigInt3 = BigInt3(
        d0=6441780312434748884571320, d1=57953919405111227542741658, d2=5457536640262350763842127
        )

    return (res=EcPoint(x=Gx, y=Gy))
end

struct Note:
    member address : EcPoint
    member token : felt
    member amount : felt
    member blinding_factor : felt
    member index : felt
end