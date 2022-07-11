from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

struct Note:
    member address_pk : felt
    member token : felt
    member amount : felt
    member blinding_factor : felt
    member index : felt
end

struct Signature:
    member signature_r : felt
    member signature_s : felt
end

struct Invisibl3Order:
    member nonce : felt
    member expiration_timestamp : felt
    member token_spent : felt
    member token_received : felt
    member amount_spent : felt
    member amount_received : felt
    member fee_limit : felt
    member dest_spent_address : felt
    member dest_received_address : felt
    member blinding_seed : felt
end

func hash_note{pedersen_ptr : HashBuiltin*}(note : Note) -> (hash : felt):
    alloc_locals

    let (commitment : felt) = hash2{hash_ptr=pedersen_ptr}(note.amount, note.blinding_factor)

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, note.address_pk)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, note.token)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, commitment)

        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (hash=res)
    end
end

func sum_notes(notes_len : felt, notes : Note*, token : felt, sum : felt) -> (sum):
    alloc_locals

    if notes_len == 0:
        return (sum)
    end

    let note : Note = notes[0]
    assert note.token = token

    let sum = sum + note.amount

    return sum_notes(notes_len - 1, &notes[1], token, sum)
end

func construct_new_note(
    address_pk : felt, token : felt, amount : felt, blinding_factor : felt, index : felt
) -> (note : Note):
    alloc_locals

    let new_note : Note = Note(
        address_pk=address_pk,
        token=token,
        amount=amount,
        blinding_factor=blinding_factor,
        index=index,
    )

    return (new_note)
end

func concat_arrays{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr1_len : felt, arr1 : felt*, arr2_len : felt, arr2 : felt*
) -> (arr_len : felt, arr : felt*):
    alloc_locals
    if arr2_len == 0:
        return (arr1_len, arr1)
    end

    assert arr1[arr1_len] = arr2[0]

    return concat_arrays(arr1_len + 1, arr1, arr2_len - 1, &arr2[1])
end

#

#

##

# func generator{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : EcPoint):
#     alloc_locals

# local Gx : BigInt3 = BigInt3(
#         d0=17117865558768631194064792, d1=12501176021340589225372855, d2=9198697782662356105779718
#         )
#     local Gy : BigInt3 = BigInt3(
#         d0=6441780312434748884571320, d1=57953919405111227542741658, d2=5457536640262350763842127
#         )

# return (res=EcPoint(x=Gx, y=Gy))
# end
