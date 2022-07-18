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
from unshielded_swaps.constants import ZERO_LEAF

# ! NOTE DICT UPDATES FOR SWAPS =====================================================

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
    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = refund_note.index
    assert note_dict_ptr.prev_value = note_in.hash
    assert note_dict_ptr.new_value = refund_note.hash

    let note_dict = note_dict + DictAccess.SIZE

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = swap_note.index
    assert note_dict_ptr.prev_value = ZERO_LEAF
    assert note_dict_ptr.new_value = swap_note.hash

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end

func update_two{note_dict : DictAccess*}(
    note_in1 : Note, note_in2 : Note, refund_note : Note, swap_note : Note
):
    let note_dict_ptr = note_dict
    note_dict_ptr.key = refund_note.index
    note_dict_ptr.prev_value = note_in1.hash
    note_dict_ptr.new_value = refund_note.hash

    let note_dict_ptr = note_dict + DictAccess.SIZE
    note_dict_ptr.key = swap_note.index
    note_dict_ptr.prev_value = note_in2.hash
    note_dict_ptr.new_value = swap_note.hash

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
    assert note_dict_ptr.prev_value = note_in.hash
    assert note_dict_ptr.new_value = ZERO_LEAF

    let note_dict = note_dict + DictAccess.SIZE

    return _update_multi_inner(notes_in_len - 1, &notes_in[1])
end

# ! NOTE DICT UPDATES FOR SWAPS =====================================================0

func deposit_note_dict_updates{note_dict : DictAccess*}(
    deposit_notes_len : felt, deposit_notes : Note*
):
    if deposit_notes_len == 0:
        return ()
    end

    let deposit_note : Note = deposit_notes[0]

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = deposit_note.index
    assert note_dict_ptr.prev_value = 0
    assert note_dict_ptr.new_value = deposit_note.hash

    let note_dict = note_dict + DictAccess.SIZE

    return deposit_note_dict_updates(deposit_notes_len - 1, &deposit_notes[1])
end

func withdraw_note_dict_updates{note_dict : DictAccess*}(
    withdraw_notes_len : felt, withdraw_notes : Note*, refund_note : Note
):
    if withdraw_notes_len == 0:
        return ()
    end

    _update_one_withdraw(withdraw_notes[0], refund_note)
    return _update_multi_inner_withdraw(withdraw_notes_len - 1, &withdraw_notes[1])
end

func _update_one_withdraw{note_dict : DictAccess*}(note_in : Note, refund_note : Note):
    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = note_in.index
    assert note_dict_ptr.prev_value = note_in.hash
    assert note_dict_ptr.new_value = refund_note.hash

    let note_dict = note_dict + DictAccess.SIZE

    return ()
end

func _update_multi_inner_withdraw{note_dict : DictAccess*}(notes_in_len : felt, notes_in : Note*):
    if notes_in_len == 0:
        return ()
    end

    let note_in : Note = notes_in[0]

    let note_dict_ptr = note_dict
    assert note_dict_ptr.key = note_in.index
    assert note_dict_ptr.prev_value = note_in.hash
    assert note_dict_ptr.new_value = 0

    let note_dict = note_dict + DictAccess.SIZE

    return _update_multi_inner(notes_in_len - 1, &notes_in[1])
end
