from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le

from invisible_swaps.helpers.range_checks import range_checks_
from invisible_swaps.helpers.verify_sums import validate_fee_taken
from invisible_swaps.helpers.utils import (
    Invisibl3Order,
    Note,
    construct_new_note,
    sum_notes,
    hash_note,
)

func partial_fill_updates{pedersen_ptr : HashBuiltin*, partial_fill_dict : DictAccess*}(
    invisible_order : Invisibl3Order,
    total_amount_to_spend : felt,
    spend_amount : felt,
    order_hash : felt,
) -> (pf_note : Note):
    alloc_locals

    let partial_fill_refund_amount = total_amount_to_spend - spend_amount

    local new_fill_refund_note_idx : felt
    %{ ids.new_fill_refund_note_idx = order_indexes["partial_fill_idx"] %}

    # ? This is the refund note of the leftover amount that wasn't spent in the swap
    let (partial_fill_note : Note) = construct_new_note(
        invisible_order.dest_spent_address,
        invisible_order.token_spent,
        partial_fill_refund_amount,
        invisible_order.blinding_seed,
        new_fill_refund_note_idx,
    )

    let (n_hash : felt) = hash_note(partial_fill_note)
    local prev_hash : felt
    %{
        prev_fill_notes[ids.order_hash] = {
        "address_pk": ids.partial_fill_note.address_pk,
        "token": ids.partial_fill_note.token,
        "amount": ids.partial_fill_note.amount,
        "blinding_factor": ids.partial_fill_note.blinding_factor,
        "index": ids.partial_fill_note.index,
        }

        try:
            ids.prev_hash = prev_fill_note_hashes[ids.order_hash]
        except:
            ids.prev_hash = 0

        prev_fill_note_hashes[ids.order_hash] = ids.n_hash
    %}

    store_prev_fill_note_hash(order_hash, prev_hash, n_hash)

    return (partial_fill_note)
end

# ========================================================================================

func store_prev_fill_note_hash{partial_fill_dict : DictAccess*}(
    order_hash : felt, prev_hash : felt, new_hash : felt
) -> ():
    %{ prev_filled_dict_manager[ids.order_hash] =  (ids.partial_fill_dict.address_, ids.prev_hash, ids.new_hash) %}

    let partial_fill_dict_ptr = partial_fill_dict
    assert partial_fill_dict_ptr.key = order_hash
    assert partial_fill_dict_ptr.prev_value = prev_hash
    assert partial_fill_dict_ptr.new_value = new_hash

    let partial_fill_dict = partial_fill_dict + DictAccess.SIZE

    return ()
end

func get_prev_fill_note_hash(order_hash : felt) -> (res):
    # TODO: This could be used with another dictAccess so figure it out
    # todo      -maybe use the start of prev_filled_dict and stroe the offset
    alloc_locals

    local prev_hash : felt
    local new_hash : felt
    %{
        try:
            addr_, prev_hash, new_hash = prev_filled_dict_manager[ids.order_hash] 
            ids.prev_hash = prev_hash
            ids.new_hash = new_hash

            memory[ap] = addr_
        except:
            ids.prev_hash = 0
            ids.new_hash = 0
    %}

    if new_hash == 0:
        return (0)
    end

    # Todo: could provide an invalid address of a different dict_access pointer,
    # Todo                  that still has a note that has already been spent

    ap += 1
    let dict_access : DictAccess* = cast([ap - 1], DictAccess*)

    assert dict_access.key = order_hash
    assert dict_access.prev_value = prev_hash
    assert dict_access.new_value = new_hash

    return (new_hash)
end
