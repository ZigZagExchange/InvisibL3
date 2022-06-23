%builtins output pedersen range_check

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
    let (my_dict : DictAccess*) = array_write_to_dict(
        my_dict, indexes_len, indexes, laef_nodes_in_len, laef_nodes_in
    )
    let dict_start = my_dict

    let (my_dict : DictAccess*) = array_update_dict(
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

func array_write_to_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    my_dict : DictAccess*, indexes_len : felt, indexes : felt*, arr_len : felt, arr : felt*
) -> (my_dict : DictAccess*):
    alloc_locals

    if arr_len == 0:
        return (my_dict)
    end

    let index : felt = indexes[0]
    let value : felt = arr[0]

    dict_write{dict_ptr=my_dict}(index, value)

    return array_write_to_dict(my_dict, indexes_len - 1, &indexes[1], arr_len - 1, &arr[1])
end

func array_update_dict{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
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

    return array_update_dict(
        my_dict,
        indexes_len - 1,
        &indexes[1],
        prev_arr_len - 1,
        &prev_arr[1],
        new_arr_len - 1,
        &new_arr[1],
    )
end

func check_merkle_tree_updates{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # let (comm : felt) = get_commitment(amount, blinding_factor)
    # let (leaf_hash : felt) = note_leaf(address, token, comm)

    # %{ print("note leaf: ", ids.leaf_hash) %}

    return ()
end

# notes_in_len : felt*, notes_in : Note*, notes_out_len : felt*, notes_out : Note*
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

func get_commitment{pedersen_ptr : HashBuiltin*}(amount : felt, blinding_factor : felt) -> (res):
    let (hash : felt) = hash2{hash_ptr=pedersen_ptr}(amount, blinding_factor)

    return (hash)
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

# # TESTS ======================================================================================

func mrkl_test{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    prev_root : felt, new_root : felt
):
    alloc_locals

    const new_leaf = 3164323627516594121377279009776584742545140296216692733963317135789580090177

    %{ initial_dict = {1:0} %}
    let my_dict : DictAccess* = dict_new()
    dict_write{dict_ptr=my_dict}(1, 0)
    let dict_start = my_dict

    dict_update{dict_ptr=my_dict}(1, 0, new_leaf)

    let (finalized_dict_start, finalized_dict_end) = dict_squash{range_check_ptr=range_check_ptr}(
        dict_start, my_dict
    )

    merkle_multi_update{hash_ptr=pedersen_ptr}(finalized_dict_start, 1, 3, prev_root, new_root)

    return ()
end

func dict_test{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    %{ initial_dict = {12:0, 1:0, 4:0} %}
    let my_dict : DictAccess* = dict_new()
    dict_write{dict_ptr=my_dict}(12, 1)
    dict_write{dict_ptr=my_dict}(1, 123)
    dict_write{dict_ptr=my_dict}(4, 2020)
    let dict_start = my_dict

    dict_update{dict_ptr=my_dict}(12, 1, 2)
    dict_update{dict_ptr=my_dict}(1, 123, 456)
    dict_update{dict_ptr=my_dict}(4, 2020, 2022)

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

func handle_inputs_test{pedersen_ptr : HashBuiltin*}(x : felt*):
    %{
        ids.prev_root = program_input["prev_root"]
        ids.new_root = program_input["new_root"]

        preimage = program_input["preimage"]
        preimage = {int(k):v for k,v in preimage.items()}


        tokens = program_input["tokens"]
        rs_ = sig[1:]
        ids.rs_len = len(rs_)
        ids.rs = rs = segments.add()
        for i, val in enumerate(rs_):
            memory[rs + i] = val  


        ids.amounts = program_input["amount"]
        ids.blinding_factors = program_input["blinding_factor"]

        addresses = program_input["address"]
        # ids.addresses_len = len(addresses_)
        # ids.addresses = addresses = segments.add()

        POINT_SIZE = ids.EcPoint.SIZE
        X_OFFSET = ids.EcPoint.x
        Y_OFFSET = ids.EcPoint.y

        BIG_INT_SIZE = ids.BigInt3.SIZE
        BIG_INT_0_OFFSET = ids.BigInt3.d0
        BIG_INT_1_OFFSET = ids.BigInt3.d1
        BIG_INT_2_OFFSET = ids.BigInt3.d2

        addr_x = ids.address.address_  + X_OFFSET
        addr_y = ids.address.address_  + Y_OFFSET

        memory[addr_x + BIG_INT_0_OFFSET] = addr[0][0]
        memory[addr_x + BIG_INT_1_OFFSET] = addr[0][1]
        memory[addr_x + BIG_INT_2_OFFSET] = addr[0][2]

        memory[addr_y + BIG_INT_0_OFFSET] = addr[1][0]
        memory[addr_y + BIG_INT_1_OFFSET] = addr[1][1]
        memory[addr_y + BIG_INT_2_OFFSET] = addr[1][2]
    %}

    return ()
end
