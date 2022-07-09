from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc

from unshielded_swaps.constants import MAX_AMOUNT, MAX_NONCE, MAX_EXPIRATION_TIMESTAMP
from helpers.utils import Note, Invisibl3Order

func range_checks_{range_check_ptr}(
    invisibl3_order : Invisibl3Order,
    notes_in_len : felt,
    notes_in : Note*,
    refund_note : Note,
    fee : felt,
):
    alloc_locals

    assert_lt(invisibl3_order.amount_spent, MAX_AMOUNT)
    assert_lt(invisibl3_order.amount_received, MAX_AMOUNT)

    # new_filled_amount = prev_filled_amount + spent_amount
    # assert_le(new_filled_amount, limit_order.amount_spent)

    assert_lt(invisibl3_order.nonce, MAX_NONCE)

    # let global_expiration_timestamp = ...?
    # assert_lt(global_expiration_timestamp, limit_order.expiration_timestamp)
    assert_lt(limit_order.expiration_timestamp, MAX_EXPIRATION_TIMESTAMP)

    return ()
end
