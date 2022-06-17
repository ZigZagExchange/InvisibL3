%builtins output pedersen

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single)

func main{output_ptr, pedersen_ptr : HashBuiltin*}():
    alloc_locals

    local secret : felt
    %{ ids.secret = program_input['secret'] %}

    let (hash : felt) = multi_hash()

    assert hash = [output_ptr]

    let output_ptr = output_ptr + 1

    return ()
end

func simple_hash{pedersen_ptr : HashBuiltin*}() -> (res):
    let a = 123456
    let b = 654321

    let (hash : felt) = hash2{hash_ptr=pedersen_ptr}(a, b)

    return (hash)
end

func multi_hash{pedersen_ptr : HashBuiltin*}() -> (res):
    let a = 123456
    let b = 654321
    let c = 111111
    let d = 999999

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, a)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, b)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, c)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, d)
        # let (hash_state_ptr) = hash_update(hash_state_ptr, _transmitters, _transmitters_len)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

# func handle_inputs{output_ptr : felt*, range_check_ptr}():
#     alloc_locals

# # Declare two variables that will point to the two lists and
#     # another variable that will contain the number of steps.
#     local loc_list : Location*
#     local tile_list : felt*
#     local n_steps

# %{
#         # The verifier doesn't care where those lists are
#         # allocated or what values they contain, so we use a hint
#         # to populate them.
#         locations = program_input['loc_list']
#         tiles = program_input['tile_list']

# ids.loc_list = loc_list = segments.add()
#         for i, val in enumerate(locations):
#             memory[loc_list + i] = val

# ids.tile_list = tile_list = segments.add()
#         for i, val in enumerate(tiles):
#             memory[tile_list + i] = val

# ids.n_steps = len(tiles)

# # Sanity check (only the prover runs this check).
#         assert len(locations) == 2 * (len(tiles) + 1)
#     %}

# check_solution(
#         loc_list=loc_list, tile_list=tile_list, n_steps=n_steps
#     )
#     return ()
# end
