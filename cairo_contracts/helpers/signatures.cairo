%builtins output pedersen

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.cairo_secp.bigint import BigInt3
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_double

func main{output_ptr, pedersen_ptr : HashBuiltin*}():
    alloc_locals

    let a = 0;
    let b = 1;
    

    return ()
end
