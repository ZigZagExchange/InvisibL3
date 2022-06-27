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
from starkware.cairo.common.math import unsigned_div_rem
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)

from merkle_updates.merkle_updates import validate_merkle_updates
from transactions.note_transaction import verify_transaction
from helpers.utils import concat_arrays

func main{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
    alloc_locals

    # * Merkle roots ==========
    local prev_root : felt
    local new_root : felt

    # ! TAKER TRANSACTION ==================================================
    # * Tx hash inputs ========
    local token_spent_A : felt
    local token_spent_price_A : felt
    local token_received_A : felt
    local token_received_price_A : felt
    local return_address_A : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_A_len : felt
    local signature_A : felt*
    local ret_addr_sig_c_A : felt
    local ret_addr_sig_r_A : felt

    # * Notes =================
    # Input notes
    local amounts_in_A_len : felt
    local amounts_in_A : felt*
    local blindings_in_A_len : felt
    local blindings_in_A : felt*
    local addresses_in_A_len : felt
    local addresses_in_A : EcPoint*

    # output notes
    local amounts_out_A_len : felt
    local amounts_out_A : felt*
    local blindings_out_A_len : felt
    local blindings_out_A : felt*
    local addresses_out_A_len : felt
    local addresses_out_A : EcPoint*

    # ! MAKER TRANSACTION ==================================================

    # indexes in the merkle tree
    local indexes_len : felt
    local indexes : felt*

    # * Tx hash inputs ========
    local token_spent_B : felt
    local token_spent_price_B : felt
    local token_received_B : felt
    local token_received_price_B : felt
    local return_address_B : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_B_len : felt
    local signature_B : felt*
    local ret_addr_sig_c_B : felt
    local ret_addr_sig_r_B : felt

    # * Notes =================

    # notes in
    local amounts_in_B_len : felt
    local amounts_in_B : felt*
    local blindings_in_B_len : felt
    local blindings_in_B : felt*
    local addresses_in_B_len : felt
    local addresses_in_B : EcPoint*
    # notes out
    local amounts_out_B_len : felt
    local amounts_out_B : felt*
    local blindings_out_B_len : felt
    local blindings_out_B : felt*
    local addresses_out_B_len : felt
    local addresses_out_B : EcPoint*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        &prev_root,
        &new_root,
        &token_spent_A,
        &token_spent_price_A,
        &token_received_A,
        &token_received_price_A,
        &return_address_A,
        &signature_A_len,
        &signature_A,
        &ret_addr_sig_c_A,
        &ret_addr_sig_r_A,
        &amounts_in_A_len,
        &amounts_in_A,
        &blindings_in_A_len,
        &blindings_in_A,
        &addresses_in_A_len,
        &addresses_in_A,
        &amounts_out_A_len,
        &amounts_out_A,
        &blindings_out_A_len,
        &blindings_out_A,
        &addresses_out_A_len,
        &addresses_out_A,
        &token_spent_B,
        &token_spent_price_B,
        &token_received_B,
        &token_received_price_B,
        &return_address_B,
        &signature_B_len,
        &signature_B,
        &ret_addr_sig_c_B,
        &ret_addr_sig_r_B,
        &amounts_in_B_len,
        &amounts_in_B,
        &blindings_in_B_len,
        &blindings_in_B,
        &addresses_in_B_len,
        &addresses_in_B,
        &amounts_out_B_len,
        &amounts_out_B,
        &blindings_out_B_len,
        &blindings_out_B,
        &addresses_out_B_len,
        &addresses_out_B,
        &indexes_len,
        &indexes,
    )

    # * Validate taker transaction =======

    let (
        leaf_nodes_in_A_len : felt,
        leaf_nodes_in_A : felt*,
        leaf_nodes_out_A_len : felt,
        leaf_nodes_out_A : felt*,
    ) = verify_transaction(
        token_spent_A,
        token_spent_price_A,
        token_received_A,
        token_received_price_A,
        return_address_A,
        signature_A_len,
        signature_A,
        ret_addr_sig_c_A,
        ret_addr_sig_r_A,
        amounts_in_A_len,
        amounts_in_A,
        blindings_in_A_len,
        blindings_in_A,
        addresses_in_A_len,
        addresses_in_A,
        amounts_out_A_len,
        amounts_out_A,
        blindings_out_A_len,
        blindings_out_A,
        addresses_out_A_len,
        addresses_out_A,
    )

    # * Validate maker transaction =======

    let (
        leaf_nodes_in_B_len : felt,
        leaf_nodes_in_B : felt*,
        leaf_nodes_out_B_len : felt,
        leaf_nodes_out_B : felt*,
    ) = verify_transaction(
        token_spent_B,
        token_spent_price_B,
        token_received_B,
        token_received_price_B,
        return_address_B,
        signature_B_len,
        signature_B,
        ret_addr_sig_c_B,
        ret_addr_sig_r_B,
        amounts_in_B_len,
        amounts_in_B,
        blindings_in_B_len,
        blindings_in_B,
        addresses_in_B_len,
        addresses_in_B,
        amounts_out_B_len,
        amounts_out_B,
        blindings_out_B_len,
        blindings_out_B,
        addresses_out_B_len,
        addresses_out_B,
    )

    let (leaf_nodes_in_len : felt, leaf_nodes_in : felt*) = concat_arrays(
        leaf_nodes_in_A_len, leaf_nodes_in_A, leaf_nodes_in_B_len, leaf_nodes_in_B
    )
    let (leaf_nodes_out_len : felt, leaf_nodes_out : felt*) = concat_arrays(
        leaf_nodes_out_A_len, leaf_nodes_out_A, leaf_nodes_out_B_len, leaf_nodes_out_B
    )

    # Check merkle root updates
    validate_merkle_updates(
        prev_root,
        new_root,
        indexes_len,
        indexes,
        leaf_nodes_in_len,
        leaf_nodes_in,
        leaf_nodes_out_len,
        leaf_nodes_out,
    )

    verify_swap_quotes(
        amounts_out_A[0], token_spent_price_A, amounts_out_B[0], token_received_price_A
    )

    %{ print("all good") %}

    return ()
end

func verify_swap{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(ith : felt):
    alloc_locals

    # * Merkle roots ==========
    local prev_root : felt
    local new_root : felt

    # ! TAKER TRANSACTION ==================================================
    # * Tx hash inputs ========
    local token_spent_A : felt
    local token_spent_price_A : felt
    local token_received_A : felt
    local token_received_price_A : felt
    local return_address_A : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_A_len : felt
    local signature_A : felt*
    local ret_addr_sig_c_A : felt
    local ret_addr_sig_r_A : felt

    # * Notes =================
    # Input notes
    local amounts_in_A_len : felt
    local amounts_in_A : felt*
    local blindings_in_A_len : felt
    local blindings_in_A : felt*
    local addresses_in_A_len : felt
    local addresses_in_A : EcPoint*

    # output notes
    local amounts_out_A_len : felt
    local amounts_out_A : felt*
    local blindings_out_A_len : felt
    local blindings_out_A : felt*
    local addresses_out_A_len : felt
    local addresses_out_A : EcPoint*

    # ! MAKER TRANSACTION ==================================================

    # indexes in the merkle tree
    local indexes_len : felt
    local indexes : felt*

    # * Tx hash inputs ========
    local token_spent_B : felt
    local token_spent_price_B : felt
    local token_received_B : felt
    local token_received_price_B : felt
    local return_address_B : EcPoint  # This will be replaced with makers/takers first output

    # * Signatures ============
    local signature_B_len : felt
    local signature_B : felt*
    local ret_addr_sig_c_B : felt
    local ret_addr_sig_r_B : felt

    # * Notes =================

    # notes in
    local amounts_in_B_len : felt
    local amounts_in_B : felt*
    local blindings_in_B_len : felt
    local blindings_in_B : felt*
    local addresses_in_B_len : felt
    local addresses_in_B : EcPoint*
    # notes out
    local amounts_out_B_len : felt
    local amounts_out_B : felt*
    local blindings_out_B_len : felt
    local blindings_out_B : felt*
    local addresses_out_B_len : felt
    local addresses_out_B : EcPoint*

    let (__fp__, _) = get_fp_and_pc()
    handle_inputs(
        ith,
        &prev_root,
        &new_root,
        &token_spent_A,
        &token_spent_price_A,
        &token_received_A,
        &token_received_price_A,
        &return_address_A,
        &signature_A_len,
        &signature_A,
        &ret_addr_sig_c_A,
        &ret_addr_sig_r_A,
        &amounts_in_A_len,
        &amounts_in_A,
        &blindings_in_A_len,
        &blindings_in_A,
        &addresses_in_A_len,
        &addresses_in_A,
        &amounts_out_A_len,
        &amounts_out_A,
        &blindings_out_A_len,
        &blindings_out_A,
        &addresses_out_A_len,
        &addresses_out_A,
        &token_spent_B,
        &token_spent_price_B,
        &token_received_B,
        &token_received_price_B,
        &return_address_B,
        &signature_B_len,
        &signature_B,
        &ret_addr_sig_c_B,
        &ret_addr_sig_r_B,
        &amounts_in_B_len,
        &amounts_in_B,
        &blindings_in_B_len,
        &blindings_in_B,
        &addresses_in_B_len,
        &addresses_in_B,
        &amounts_out_B_len,
        &amounts_out_B,
        &blindings_out_B_len,
        &blindings_out_B,
        &addresses_out_B_len,
        &addresses_out_B,
        &indexes_len,
        &indexes,
    )

    # * Validate taker transaction =======

    let (
        leaf_nodes_in_A_len : felt,
        leaf_nodes_in_A : felt*,
        leaf_nodes_out_A_len : felt,
        leaf_nodes_out_A : felt*,
    ) = verify_transaction(
        token_spent_A,
        token_spent_price_A,
        token_received_A,
        token_received_price_A,
        return_address_A,
        signature_A_len,
        signature_A,
        ret_addr_sig_c_A,
        ret_addr_sig_r_A,
        amounts_in_A_len,
        amounts_in_A,
        blindings_in_A_len,
        blindings_in_A,
        addresses_in_A_len,
        addresses_in_A,
        amounts_out_A_len,
        amounts_out_A,
        blindings_out_A_len,
        blindings_out_A,
        addresses_out_A_len,
        addresses_out_A,
    )

    # * Validate maker transaction =======

    let (
        leaf_nodes_in_B_len : felt,
        leaf_nodes_in_B : felt*,
        leaf_nodes_out_B_len : felt,
        leaf_nodes_out_B : felt*,
    ) = verify_transaction(
        token_spent_B,
        token_spent_price_B,
        token_received_B,
        token_received_price_B,
        return_address_B,
        signature_B_len,
        signature_B,
        ret_addr_sig_c_B,
        ret_addr_sig_r_B,
        amounts_in_B_len,
        amounts_in_B,
        blindings_in_B_len,
        blindings_in_B,
        addresses_in_B_len,
        addresses_in_B,
        amounts_out_B_len,
        amounts_out_B,
        blindings_out_B_len,
        blindings_out_B,
        addresses_out_B_len,
        addresses_out_B,
    )

    let (leaf_nodes_in_len : felt, leaf_nodes_in : felt*) = concat_arrays(
        leaf_nodes_in_A_len, leaf_nodes_in_A, leaf_nodes_in_B_len, leaf_nodes_in_B
    )
    let (leaf_nodes_out_len : felt, leaf_nodes_out : felt*) = concat_arrays(
        leaf_nodes_out_A_len, leaf_nodes_out_A, leaf_nodes_out_B_len, leaf_nodes_out_B
    )

    # Check merkle root updates
    validate_merkle_updates(
        prev_root,
        new_root,
        indexes_len,
        indexes,
        leaf_nodes_in_len,
        leaf_nodes_in,
        leaf_nodes_out_len,
        leaf_nodes_out,
    )

    verify_swap_quotes(
        amounts_out_A[0], token_spent_price_A, amounts_out_B[0], token_received_price_A
    )

    %{ print("all good") %}

    return ()
end

func verify_swap_quotes{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
    token_spent_amount : felt,
    token_spent_price : felt,
    token_received_amount : felt,
    token_received_price : felt,
):
    alloc_locals

    tempvar xPx = token_spent_amount * token_spent_price
    tempvar yPy = token_received_amount * token_received_price

    tempvar diff = xPx - yPy

    tempvar diff = diff * 10 ** 8
    let (diff : felt, _) = unsigned_div_rem(diff, xPx)

    with_attr error_message("Swap quotes are not valid"):
        assert diff = 0
    end

    return ()
end

func handle_inputs{pedersen_ptr : HashBuiltin*}(
    ith : felt,
    prev_root : felt*,
    new_root : felt*,
    token_spent_A : felt*,
    token_spent_price_A : felt*,
    token_received_A : felt*,
    token_received_price_A : felt*,
    return_address_A : EcPoint*,
    signature_A_len : felt*,
    signature_A : felt**,
    ret_addr_sig_c_A : felt*,
    ret_addr_sig_r_A : felt*,
    amounts_in_A_len : felt*,
    amounts_in_A : felt**,
    blindings_in_A_len : felt*,
    blindings_in_A : felt**,
    addresses_in_A_len : felt*,
    addresses_in_A : EcPoint**,
    amounts_out_A_len : felt*,
    amounts_out_A : felt**,
    blindings_out_A_len : felt*,
    blindings_out_A : felt**,
    addresses_out_A_len : felt*,
    addresses_out_A : EcPoint**,
    token_spent_B : felt*,
    token_spent_price_B : felt*,
    token_received_B : felt*,
    token_received_price_B : felt*,
    return_address_B : EcPoint*,
    signature_B_len : felt*,
    signature_B : felt**,
    ret_addr_sig_c_B : felt*,
    ret_addr_sig_r_B : felt*,
    amounts_in_B_len : felt*,
    amounts_in_B : felt**,
    blindings_in_B_len : felt*,
    blindings_in_B : felt**,
    addresses_in_B_len : felt*,
    addresses_in_B : EcPoint**,
    amounts_out_B_len : felt*,
    amounts_out_B : felt**,
    blindings_out_B_len : felt*,
    blindings_out_B : felt**,
    addresses_out_B_len : felt*,
    addresses_out_B : EcPoint**,
    indexes_len : felt*,
    indexes : felt**,
):
    %{
        ith_swap_inputs = program_input[str(ids.ith)]

        # ! STRUCT SIZES ==========================================================

        POINT_SIZE = ids.EcPoint.SIZE
        X_OFFSET = ids.EcPoint.x
        Y_OFFSET = ids.EcPoint.y

        BIG_INT_SIZE = ids.BigInt3.SIZE
        BIG_INT_0_OFFSET = ids.BigInt3.d0
        BIG_INT_1_OFFSET = ids.BigInt3.d1
        BIG_INT_2_OFFSET = ids.BigInt3.d2

        # ! MERKLE TREE INPUTS =====================================================

        memory[ids.prev_root] = ith_swap_inputs["prev_root"]
        memory[ids.new_root] = ith_swap_inputs["new_root"]

        preimage = ith_swap_inputs["preimage"]
        preimage = {int(k):v for k,v in preimage.items()}

        indexes__ = ith_swap_inputs["indexes"]
        memory[ids.indexes_len] = len(indexes__)
        memory[ids.indexes] = indexes = segments.add()
        initial_dict = {}
        for i, val in enumerate(indexes__):
            memory[indexes + i] = val
            initial_dict[val] = 0




        # ! TAKER TRANSACTION =======================================================

        # * Tx_hash inputs ------------------------------------------

        memory[ids.token_spent_A] = token_spent_A = ith_swap_inputs["token_spent_A"]
        memory[ids.token_spent_price_A] = ith_swap_inputs["token_spent_price_A"]
        memory[ids.token_received_A] = token_received_A = ith_swap_inputs["token_received_A"]
        memory[ids.token_received_price_A] = ith_swap_inputs["token_received_price_A"]

        ret_addr = ith_swap_inputs["return_address_A"]
        memory[ids.return_address_A.address_ + X_OFFSET + BIG_INT_0_OFFSET] = ret_addr[0][0]
        memory[ids.return_address_A.address_ + X_OFFSET + BIG_INT_1_OFFSET] = ret_addr[0][1]
        memory[ids.return_address_A.address_ + X_OFFSET + BIG_INT_2_OFFSET] = ret_addr[0][2]
        memory[ids.return_address_A.address_ + Y_OFFSET + BIG_INT_0_OFFSET] = ret_addr[1][0]
        memory[ids.return_address_A.address_ + Y_OFFSET + BIG_INT_1_OFFSET] = ret_addr[1][1]
        memory[ids.return_address_A.address_ + Y_OFFSET + BIG_INT_2_OFFSET] = ret_addr[1][2]

        # * Signatures inputs ------------------------------------------

        sig = ith_swap_inputs["signature_A"]
        memory[ids.signature_A_len] = len(sig)
        memory[ids.signature_A] = _signature__A = segments.add() 
        for i, val in enumerate(sig):
            memory[_signature__A + i] = val

        ret_sig = ith_swap_inputs["ret_addr_sig_A"]
        memory[ids.ret_addr_sig_c_A] = ret_sig[0]
        memory[ids.ret_addr_sig_r_A] = ret_sig[1]



        # * input notes ------------------------------------------

        amounts_in__ = ith_swap_inputs["amounts_in_A"]
        memory[ids.amounts_in_A_len] = len(amounts_in__)
        memory[ids.amounts_in_A] = amounts_in_A = segments.add()
        for i, val in enumerate(amounts_in__):
            memory[amounts_in_A + i] = val



        blindings_in__ = ith_swap_inputs["blindings_in_A"]
        memory[ids.blindings_in_A_len] = len(blindings_in__)
        memory[ids.blindings_in_A] = blindings_in_A = segments.add()
        for i, val in enumerate(blindings_in__):
            memory[blindings_in_A + i] = val


        addresses_in__ = ith_swap_inputs["addresses_in_A"]
        memory[ids.addresses_in_A_len] = len(addresses_in__)
        memory[ids.addresses_in_A] = addresses_in_A = segments.add()
        for i in range(len(addresses_in__)):
            address_addr_x = addresses_in_A + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_in_A + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in__[i][1][2]

        assert len(amounts_in__) == len(blindings_in__) == len(addresses_in__)

        # * Tx_hash inputs ------------------------------------------

        amounts_out__ = ith_swap_inputs["amounts_out_A"]
        memory[ids.amounts_out_A_len] = len(amounts_out__)
        memory[ids.amounts_out_A] = amounts_out_A = segments.add()
        for i, val in enumerate(amounts_out__):
            memory[amounts_out_A + i] = val



        blindings_out__ = ith_swap_inputs["blindings_out_A"]
        memory[ids.blindings_out_A_len] = len(blindings_out__)
        memory[ids.blindings_out_A] = blindings_out_A = segments.add()
        for i, val in enumerate(blindings_out__):
            memory[blindings_out_A + i] = val


        addresses_out__ = ith_swap_inputs["addresses_out_A"]
        memory[ids.addresses_out_A_len] = len(addresses_out__)
        memory[ids.addresses_out_A] = addresses_out_A = segments.add()
        for i in range(len(addresses_out__)):
            address_addr_x = addresses_out_A + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_out_A + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_out__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_out__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_out__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_out__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_out__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_out__[i][1][2]

        assert len(amounts_out__) == len(blindings_out__) == len(addresses_out__)



        # ! MAKER TRANSACTION =======================================================

        # * Tx_hash inputs ------------------------------------------

        memory[ids.token_spent_B] = token_spent_B = ith_swap_inputs["token_spent_B"]
        memory[ids.token_spent_price_B] = ith_swap_inputs["token_spent_price_B"]
        memory[ids.token_received_B] = token_received_B = ith_swap_inputs["token_received_B"]
        memory[ids.token_received_price_B] = ith_swap_inputs["token_received_price_B"]

        ret_addr = ith_swap_inputs["return_address_B"]
        memory[ids.return_address_B.address_ + X_OFFSET + BIG_INT_0_OFFSET] = ret_addr[0][0]
        memory[ids.return_address_B.address_ + X_OFFSET + BIG_INT_1_OFFSET] = ret_addr[0][1]
        memory[ids.return_address_B.address_ + X_OFFSET + BIG_INT_2_OFFSET] = ret_addr[0][2]
        memory[ids.return_address_B.address_ + Y_OFFSET + BIG_INT_0_OFFSET] = ret_addr[1][0]
        memory[ids.return_address_B.address_ + Y_OFFSET + BIG_INT_1_OFFSET] = ret_addr[1][1]
        memory[ids.return_address_B.address_ + Y_OFFSET + BIG_INT_2_OFFSET] = ret_addr[1][2]

        # * Signature inputs ------------------------------------------

        sig = ith_swap_inputs["signature_B"]
        memory[ids.signature_B_len] = len(sig)
        memory[ids.signature_B] = _signature__B = segments.add() 
        for i, val in enumerate(sig):
            memory[_signature__B + i] = val

        ret_sig = ith_swap_inputs["ret_addr_sig_B"]
        memory[ids.ret_addr_sig_c_B] = ret_sig[0]
        memory[ids.ret_addr_sig_r_B] = ret_sig[1]



        ##* Input notes ------------------------------------------------

        amounts_in__ = ith_swap_inputs["amounts_in_B"]
        memory[ids.amounts_in_B_len] = len(amounts_in__)
        memory[ids.amounts_in_B] = amounts_in_B = segments.add()
        for i, val in enumerate(amounts_in__):
            memory[amounts_in_B + i] = val



        blindings_in__ = ith_swap_inputs["blindings_in_B"]
        memory[ids.blindings_in_B_len] = len(blindings_in__)
        memory[ids.blindings_in_B] = blindings_in_B = segments.add()
        for i, val in enumerate(blindings_in__):
            memory[blindings_in_B + i] = val


        addresses_in__ = ith_swap_inputs["addresses_in_B"]
        memory[ids.addresses_in_B_len] = len(addresses_in__)
        memory[ids.addresses_in_B] = addresses_in_B = segments.add()
        for i in range(len(addresses_in__)):
            address_addr_x = addresses_in_B + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_in_B + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_in__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_in__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_in__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_in__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_in__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_in__[i][1][2]

        assert len(amounts_in__) == len(blindings_in__) == len(addresses_in__)

        ##* Output notes -----------------------------------------------

        amounts_out__ = ith_swap_inputs["amounts_out_B"]
        memory[ids.amounts_out_B_len] = len(amounts_out__)
        memory[ids.amounts_out_B] = amounts_out_B = segments.add()
        for i, val in enumerate(amounts_out__):
            memory[amounts_out_B + i] = val



        blindings_out__ = ith_swap_inputs["blindings_out_B"]
        memory[ids.blindings_out_B_len] = len(blindings_out__)
        memory[ids.blindings_out_B] = blindings_out_B = segments.add()
        for i, val in enumerate(blindings_out__):
            memory[blindings_out_B + i] = val


        addresses_out__ = ith_swap_inputs["addresses_out_B"]
        memory[ids.addresses_out_B_len] = len(addresses_out__)
        memory[ids.addresses_out_B] = addresses_out_B = segments.add()
        for i in range(len(addresses_out__)):
            address_addr_x = addresses_out_B + i * POINT_SIZE + X_OFFSET
            address_addr_y = addresses_out_B + i * POINT_SIZE + Y_OFFSET

            memory[address_addr_x + BIG_INT_0_OFFSET] = addresses_out__[i][0][0]
            memory[address_addr_x + BIG_INT_1_OFFSET] = addresses_out__[i][0][1]
            memory[address_addr_x + BIG_INT_2_OFFSET] = addresses_out__[i][0][2]

            memory[address_addr_y + BIG_INT_0_OFFSET] = addresses_out__[i][1][0]
            memory[address_addr_y + BIG_INT_1_OFFSET] = addresses_out__[i][1][1]
            memory[address_addr_y + BIG_INT_2_OFFSET] = addresses_out__[i][1][2]

        assert len(amounts_out__) == len(blindings_out__) == len(addresses_out__)
    %}

    return ()
end
