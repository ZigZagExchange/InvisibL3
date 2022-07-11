%builtins output pedersen

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.hash_state import (
    hash_init, hash_finalize, hash_update, hash_update_single)

struct Point:
    member x : felt
    member y : felt
end

func main{output_ptr, pedersen_ptr : HashBuiltin*}():
    alloc_locals

    local amount : felt
    local blinding : felt
    local address : Point
    local token : felt
    local auth_paths_pos_len : felt
    local auth_paths_pos : felt*
    local auth_paths_len : felt
    local auth_paths : felt*
    local root : felt
    %{
        ids.amount = program_input["amount"]
        ids.blinding = program_input["blinding_factor"]
        address = program_input["address"]
        ids.address.x = address[0]
        ids.address.y = address[1]
        ids.token = program_input["token"]

        ids.root = program_input["root"]
        proof_pos = program_input["proof_pos"]
        ids.auth_paths_pos_len = len(proof_pos)
        ids.auth_paths_pos = pos = segments.add()
        for i, val in enumerate(proof_pos):
            memory[pos + i] = val

        proof = program_input["proof"]
        ids.auth_paths_len = len(proof)
        ids.auth_paths = proofs = segments.add()
        for i, val in enumerate(proof):
            memory[proofs + i] = val

        assert len(proof) == len(proof_pos)
    %}

    let (comm : felt) = get_commitment(amount, blinding)
    let (leaf : felt) = note_leaf(address, token, comm)

    let (comp_root) = get_root(leaf, auth_paths_pos_len, auth_paths_pos, auth_paths_len, auth_paths)

    check_note_existence(
        address, token, comm, root, auth_paths_pos_len, auth_paths_pos, auth_paths_len, auth_paths)

    %{ print( "All done") %}
    return ()
end

func get_commitment{pedersen_ptr : HashBuiltin*}(amount : felt, blinding_factor : felt) -> (res):
    let (hash : felt) = hash2{hash_ptr=pedersen_ptr}(amount, blinding_factor)

    return (hash)
end

func note_leaf{pedersen_ptr : HashBuiltin*}(address : Point, token : felt, commitment : felt) -> (
        res):
    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, address.x)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, address.y)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, token)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, commitment)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func check_note_existence{pedersen_ptr : HashBuiltin*}(
        address : Point, token : felt, commitment : felt, root : felt, auth_paths_pos_len : felt,
        auth_paths_pos : felt*, auth_paths_len : felt, auth_paths : felt*):
    let (leaf : felt) = note_leaf(address, token, commitment)

    return check_leaf_existence(
        leaf, root, auth_paths_pos_len, auth_paths_pos, auth_paths_len, auth_paths)
end

func check_leaf_existence{pedersen_ptr : HashBuiltin*}(
        leaf : felt, root : felt, auth_paths_pos_len : felt, auth_paths_pos : felt*,
        auth_paths_len : felt, auth_paths : felt*):
    let (computed_root : felt) = get_root(
        leaf, auth_paths_pos_len, auth_paths_pos, auth_paths_len, auth_paths)

    assert root = computed_root
    return ()
end

func get_root{pedersen_ptr : HashBuiltin*}(
        leaf : felt, auth_paths_pos_len : felt, auth_paths_pos : felt*, auth_paths_len : felt,
        auth_paths : felt*) -> (res):
    tempvar diff = leaf - auth_paths[0]

    tempvar left = leaf - auth_paths_pos[0] * diff
    tempvar right = auth_paths[0] + auth_paths_pos[0] * diff

    let (h1 : felt) = hash2{hash_ptr=pedersen_ptr}(left, right)

    return get_root_inner(
        h1, auth_paths_pos_len - 1, &auth_paths_pos[1], auth_paths_len - 1, &auth_paths[1])
end

func get_root_inner{pedersen_ptr : HashBuiltin*}(
        hash : felt, auth_paths_pos_len : felt, auth_paths_pos : felt*, auth_paths_len : felt,
        auth_paths : felt*) -> (res):
    if auth_paths_len == 0:
        return (hash)
    end

    tempvar diff = hash - auth_paths[0]

    tempvar left = hash - auth_paths_pos[0] * diff
    tempvar right = auth_paths[0] + auth_paths_pos[0] * diff

    let (h1 : felt) = hash2{hash_ptr=pedersen_ptr}(left, right)

    return get_root_inner(
        h1, auth_paths_pos_len - 1, &auth_paths_pos[1], auth_paths_len - 1, &auth_paths[1])
end
