# %builtins output pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from helpers.utils import Note
from dummy.tests import test_log_array

const TREE_DEPTH = 3

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # get the input note details and indexes
    # convert them to leaf hashes

    # get the output note details and indexes
    # convert them to leaf hashes

    # initialize the dict list with input leaf hashes and update them to the output leaf hashes
    # Use that to verify merkle tree updates

    local prev_root : felt
    local new_root : felt

    local indexes_len : felt
    local indexes : felt*
    # #* Input notes
    local notes_in_len : felt
    local notes_in : Note*

    # #* Output notes
    local notes_out_len : felt
    local notes_out : Note*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &prev_root,
        &new_root,
        &indexes_len,
        &indexes,
        &notes_in_len,
        &notes_in,
        &notes_out_len,
        &notes_out,
    )

    let (local empty_arr : felt*) = alloc()
    let (laef_nodes_in_len : felt, laef_nodes_in : felt*) = build_leaf_nodes_array(
        notes_in_len, notes_in, 0, empty_arr, notes_in_len
    )

    let (local empty_arr : felt*) = alloc()
    let (laef_nodes_out_len : felt, laef_nodes_out : felt*) = build_leaf_nodes_array(
        notes_out_len, notes_out, 0, empty_arr, notes_out_len
    )

    %{ initial_dict = {k: 0 for k in indexes__} %}
    let my_dict : DictAccess* = dict_new()
    let (my_dict : DictAccess*) = _array_write_to_dict(
        my_dict, indexes_len, indexes, laef_nodes_in_len, laef_nodes_in
    )
    let dict_start = my_dict

    let (my_dict : DictAccess*) = _array_update_dict(
        my_dict,
        indexes_len,
        indexes,
        laef_nodes_in_len,
        laef_nodes_in,
        laef_nodes_out_len,
        laef_nodes_out,
    )

    let (finalized_dict_start, finalized_dict_end) = dict_squash{range_check_ptr=range_check_ptr}(
        dict_start, my_dict
    )

    let x : DictAccess = finalized_dict_start[0]
    let y : DictAccess = finalized_dict_start[1]
    let z : DictAccess = finalized_dict_start[2]

    %{
        print("key:", ids.x.key)
        print("prev:", ids.x.prev_value)
        print("new:", ids.x.new_value)
        print("key:", ids.y.key)
        print("prev:", ids.y.prev_value)
        print("new:", ids.y.new_value)
        print("key:", ids.z.key)
        print("prev:", ids.z.prev_value)
        print("new:", ids.z.new_value)
    %}

    return ()
end

func validate_merkle_updates{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_root : felt,
    new_root : felt,
    indexes_len : felt,
    indexes : felt*,
    leaf_nodes_in_len : felt,
    leaf_nodes_in : felt*,
    leaf_nodes_out_len : felt,
    leaf_nodes_out : felt*,
):
    alloc_locals

    # Pad input leaf nodes with zeros with if there are more output leaf nodes and vise-versa
    # more inp notes <=> zero out some leaf nodes;  more out notes <=>  appending new notes

    let (leaf_nodes_in_len : felt, leaf_nodes_in : felt*) = pad_array(
        leaf_nodes_in_len, leaf_nodes_in, indexes_len, 0
    )
    let (leaf_nodes_out_len : felt, leaf_nodes_out : felt*) = pad_array(
        leaf_nodes_out_len, leaf_nodes_out, indexes_len, 0
    )

    # initialize dict
    let tree_update_dict : DictAccess* = dict_new()

    # write the initial values to dict
    let (tree_update_dict : DictAccess*) = _array_write_to_dict(
        tree_update_dict, indexes_len, indexes, leaf_nodes_in_len, leaf_nodes_in
    )
    let dict_start = tree_update_dict

    # update the input leaf nodes with the output leaf nodes
    let (tree_update_dict : DictAccess*) = _array_update_dict(
        tree_update_dict,
        indexes_len,
        indexes,
        leaf_nodes_in_len,
        leaf_nodes_in,
        leaf_nodes_out_len,
        leaf_nodes_out,
    )

    # finalize the dict
    let (finalized_dict_start, finalized_dict_end) = dict_squash{range_check_ptr=range_check_ptr}(
        dict_start, tree_update_dict
    )

    _check_merkle_tree_updates_internal(prev_root, new_root, finalized_dict_start, indexes_len)

    return ()
end

func _check_merkle_tree_updates_internal{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_root : felt, new_root : felt, finalized_dict_start : DictAccess*, num_updates : felt
):
    alloc_locals

    merkle_multi_update{hash_ptr=pedersen_ptr}(
        finalized_dict_start, num_updates, TREE_DEPTH, prev_root, new_root
    )

    %{ print("merkle tree update is valid") %}

    return ()
end

func update_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    update_dict : DictAccess*,
    indexes_len : felt,
    indexes : felt*,
    prev_arr_len : felt,
    prev_arr : felt*,
    new_arr_len : felt,
    new_arr : felt*,
) -> (dict_start : DictAccess*, update_dict : DictAccess*):
    let (prev_arr_len : felt, prev_arr : felt*) = pad_array(prev_arr_len, prev_arr, indexes_len, 0)
    let (leaf_nodes_out_len : felt, leaf_nodes_out : felt*) = pad_array(
        leaf_nodes_out_len, leaf_nodes_out, indexes_len, 0
    )

    let (update_dict : DictAccess*) = _array_write_to_dict(
        update_dict, indexes_len, indexes, prev_arr_len, prev_arr
    )

    let dict_start = update_dict

    let (update_dict : DictAccess*) = _array_update_dict(
        update_dict, indexes_len, indexes, prev_arr_len, prev_arr, new_arr_len, new_arr
    )

    return (dict_start, update_dict)
end

func _array_write_to_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    my_dict : DictAccess*, indexes_len : felt, indexes : felt*, arr_len : felt, arr : felt*
) -> (my_dict : DictAccess*):
    alloc_locals

    if arr_len == 0:
        return (my_dict)
    end

    let index : felt = indexes[0]
    let value : felt = arr[0]

    dict_write{dict_ptr=my_dict}(index, value)

    return _array_write_to_dict(my_dict, indexes_len - 1, &indexes[1], arr_len - 1, &arr[1])
end

func _array_update_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    my_dict : DictAccess*,
    indexes_len : felt,
    indexes : felt*,
    prev_arr_len : felt,
    prev_arr : felt*,
    new_arr_len : felt,
    new_arr : felt*,
) -> (my_dict : DictAccess*):
    alloc_locals

    if prev_arr_len == 0:
        return (my_dict)
    end

    let index : felt = indexes[0]
    let prev_v : felt = prev_arr[0]
    let new_v : felt = new_arr[0]

    dict_update{dict_ptr=my_dict}(index, prev_v, new_v)

    return _array_update_dict(
        my_dict,
        indexes_len - 1,
        &indexes[1],
        prev_arr_len - 1,
        &prev_arr[1],
        new_arr_len - 1,
        &new_arr[1],
    )
end

func pad_array{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    arr_len : felt, arr : felt*, total_len : felt, pad_value : felt
) -> (arr_len : felt, arr : felt*):
    if arr_len == total_len:
        return (arr_len, arr)
    end

    assert arr[arr_len] = pad_value

    return pad_array(arr_len + 1, arr, total_len, pad_value)
end

# # ====================================================
func handle_inputs{pedersen_ptr : HashBuiltin*}(
    prev_root : felt*,
    new_root : felt*,
    indexes_len : felt*,
    indexes : felt**,
    notes_in_len : felt*,
    notes_in : Note**,
    notes_out_len : felt*,
    notes_out : Note**,
):
    %{
        memory[ids.prev_root] = program_input["prev_root"]
        memory[ids.new_root] = program_input["new_root"]

        preimage = program_input["preimage"]
        preimage = {int(k):v for k,v in preimage.items()}

        NOTE_SIZE = ids.Note.SIZE
        TOKEN_OFFSET = ids.Note.token
        AMOUNT_OFFSET = ids.Note.amount
        BLINDING_OFFSET = ids.Note.blinding_factor
        INDEX_OFFSET = ids.Note.index
        ADDRESS_OFFSET = ids.Note.address

        POINT_SIZE = ids.EcPoint.SIZE
        X_OFFSET = ids.EcPoint.x
        Y_OFFSET = ids.EcPoint.y

        BIG_INT_SIZE = ids.BigInt3.SIZE
        BIG_INT_0_OFFSET = ids.BigInt3.d0
        BIG_INT_1_OFFSET = ids.BigInt3.d1
        BIG_INT_2_OFFSET = ids.BigInt3.d2


        ##* INPUT NOTES ======================================================

        indexes__ = program_input["indexes"]
        memory[ids.indexes_len] = len(indexes__)
        memory[ids.indexes] = indexes = segments.add()
        for i, val in enumerate(indexes__):
            memory[indexes + i] = val

        data_in = program_input["data_in"]

        tokens_in = data_in["tokens"]
        amounts_in = data_in["amounts"]
        blindings_in = data_in["blindings"]
        addresses_in = data_in["addresses"]

        assert len(tokens_in) == len(amounts_in) == len(blindings_in) == len(indexes__) == len(addresses_in)

        memory[ids.notes_in_len] = len(tokens_in)
        memory[ids.notes_in] = notes_in = segments.add()
        for i in range(len(tokens_in)):
            token_addr = notes_in + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_in + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_in + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_in + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_in + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = tokens_in[i]
            memory[amount_addr] = amounts_in[i]
            memory[blinding_addr] = blindings_in[i]
            memory[index_addr] = indexes__[i]

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in[i][1][2]

        ##* OUTPUT NOTES ======================================================
        data_out = program_input["data_out"]

        tokens_out = data_out["tokens"]
        amounts_out = data_out["amounts"]
        blindings_out = data_out["blindings"]
        addresses_out = data_out["addresses"]

        assert len(tokens_out) == len(amounts_out) == len(blindings_out) == len(indexes__) == len(addresses_out)

        memory[ids.notes_out_len] = len(tokens_out)
        memory[ids.notes_out] = notes_out = segments.add()
        for i in range(len(tokens_out)):
            token_addr = notes_out + i * NOTE_SIZE + TOKEN_OFFSET
            amount_addr = notes_out + i * NOTE_SIZE + AMOUNT_OFFSET
            blinding_addr = notes_out + i * NOTE_SIZE + BLINDING_OFFSET
            index_addr = notes_out + i * NOTE_SIZE + INDEX_OFFSET
            address_addr_x = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + X_OFFSET
            address_addr_y = notes_out + i * NOTE_SIZE + ADDRESS_OFFSET + Y_OFFSET

            memory[token_addr] = tokens_out[i]
            memory[amount_addr] = amounts_out[i]
            memory[blinding_addr] = blindings_out[i]
            memory[index_addr] = indexes__[i]

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_out[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_out[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_out[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_out[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_out[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_out[i][1][2]
    %}

    return ()
end

func build_leaf_nodes_array{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    notes_len : felt, notes : Note*, arr_len : felt, arr : felt*, total_len : felt
) -> (arr_len : felt, arr : felt*):
    alloc_locals

    if arr_len == total_len:
        return (arr_len, arr)
    end

    let amount : felt = notes[0].amount
    let blinding_factor : felt = notes[0].blinding_factor
    let token : felt = notes[0].token
    let address : EcPoint = notes[0].address

    let (comm : felt) = get_commitment(amount, blinding_factor)
    let (leaf_hash : felt) = note_leaf(address, token, comm)

    assert arr[arr_len] = leaf_hash

    return build_leaf_nodes_array(notes_len - 1, &notes[1], arr_len + 1, arr, total_len)
end

func note_leaf{pedersen_ptr : HashBuiltin*, range_check_ptr}(
    address : EcPoint, token : felt, commitment : felt
) -> (res):
    let (px : Uint256) = bigint_to_uint256(address.x)
    let (x_hash : felt) = hash2{hash_ptr=pedersen_ptr}(px.high, px.low)

    let (py : Uint256) = bigint_to_uint256(address.y)
    let (y_hash : felt) = hash2{hash_ptr=pedersen_ptr}(py.high, py.low)

    let hash_ptr = pedersen_ptr
    with hash_ptr:
        let (hash_state_ptr) = hash_init()
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, x_hash)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, y_hash)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, token)
        let (hash_state_ptr) = hash_update_single(hash_state_ptr, commitment)
        let (res) = hash_finalize(hash_state_ptr)
        let pedersen_ptr = hash_ptr
        return (res=res)
    end
end

func get_commitment{pedersen_ptr : HashBuiltin*}(amount : felt, blinding_factor : felt) -> (res):
    let (hash : felt) = hash2{hash_ptr=pedersen_ptr}(amount, blinding_factor)

    return (hash)
end
