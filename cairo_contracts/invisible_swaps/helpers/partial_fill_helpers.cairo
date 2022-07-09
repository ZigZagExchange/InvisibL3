from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.dict import dict_new, dict_write, dict_update, dict_squash, dict_read
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint
from starkware.cairo.common.merkle_multi_update import merkle_multi_update
from starkware.cairo.common.uint256 import Uint256
from starkware.cairo.common.math import unsigned_div_rem, assert_le
from starkware.cairo.common.math_cmp import is_le

func partial_fill_updates{partial_fill_dict : DictAccess*}(
    test_order_A : TestOrder,
    spend_amountA : felt,
    order_A_hash : felt,
    condition : felt,
    prev_fill_refund_note : Note,
) -> (pf_note : Note):
    alloc_locals

    # todo maybe we can remove this altogether and do it outside the function
    if condition == 0:
        return (prev_fill_refund_note)
    end

    let partial_fill_refund_amount = test_order_A.amount_spent - spend_amountA

    local new_fill_refund_note_idx : felt
    %{ ids.new_fill_refund_note_idx = order_indexes["partial_fill_idx"] %}

    let (__fp__, _) = get_fp_and_pc()
    # figure what address to send to
    let (local partial_fill_note : Note) = make_new_note(
        test_order_A.destination_address_pk,
        test_order_A.token_spent,
        partial_fill_refund_amount,
        test_order_A.blindings_seed,
        new_fill_refund_note_idx,
    )

    let (n_hash : felt) = hash_note(partial_fill_note)

    %{
        prev_fill_notes[ids.order_A_hash] = {
        "address_pk": ids.partial_fill_note.address_pk,
        "token": ids.partial_fill_note.token,
        "amount": ids.partial_fill_note.amount,
        "blinding_factor": ids.partial_fill_note.blinding_factor,
        "index": ids.partial_fill_note.index,
        }
    %}

    # todo replace the zero with prev_hash in case this is a third order fill
    store_prev_fill_note_hash(order_A_hash, 0, n_hash)

    return (partial_fill_note)
end

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

    # Todo: could provide an invalid address of a previous dict_access pointer,
    # Todo that still has a note that has already been spent

    ap += 1
    let dict_access : DictAccess* = cast([ap - 1], DictAccess*)

    assert dict_access.key = order_hash
    assert dict_access.prev_value = prev_hash
    assert dict_access.new_value = new_hash

    return (new_hash)
end

func update_note_dict{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : Note*, refund_note : Note, swap_note : Note
):
    if notes_in_len == 1:
        let note_in = notes_in[0]
        return update_one(note_in, refund_note, swap_note)
    end
    if notes_in_len == 2:
        let note_in1 = notes_in[0]
        let note_in2 = notes_in[1]
        return update_two(note_in1, note_in2, refund_note, swap_note)
    end

    return update_multi(notes_in_len, notes_in, refund_note, swap_note)
end

func update_one{note_dict : DictAccess*}(note_in : Note, refund_note : Note, swap_note : Note):
    # todo use hashes instead of amounts

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = refund_note.index
    assert note_dict_ptr.prev_value = note_in.amount
    assert note_dict_ptr.new_value = refund_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = swap_note.index
    assert note_dict_ptr.prev_value = 0  # Could be replaced with another zero value
    assert note_dict_ptr.new_value = swap_note.amount

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end

func update_two{note_dict : DictAccess*}(
    note_in1 : Note, note_in2 : Note, refund_note : Note, swap_note : Note
):
    let note_dict_ptr = note_dict
    note_dict_ptr.key = refund_note.index
    note_dict_ptr.prev_value = note_in1.amount
    note_dict_ptr.new_value = refund_note.amount

    let note_dict_ptr = note_dict + DictAccess.SIZE
    note_dict_ptr.key = swap_note.index
    note_dict_ptr.prev_value = note_in2.amount
    note_dict_ptr.new_value = swap_note.amount

    let note_dict = note_dict + 2 * DictAccess.SIZE

    return ()
end

func update_multi{note_dict : DictAccess*}(
    notes_in_len : felt, notes_in : Note*, refund_note : Note, swap_note : Note
):
    let note_in1 : Note = notes_in[0]
    let note_in2 : Note = notes_in[1]

    update_two(note_in1, note_in2, refund_note, swap_note)

    return _update_multi_inner(notes_in_len - 2, &notes_in[2])
end

func _update_multi_inner{note_dict : DictAccess*}(notes_in_len : felt, notes_in : Note*):
    if notes_in_len == 0:
        return ()
    end

    let note_in : Note = notes_in[0]

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = note_in.index
    assert note_dict_ptr.prev_value = note_in.amount
    assert note_dict_ptr.new_value = 0

    let note_dict = note_dict + DictAccess.SIZE

    return _update_multi_inner(notes_in_len - 1, &notes_in[1])
end
