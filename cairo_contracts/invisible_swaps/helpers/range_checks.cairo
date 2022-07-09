from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.math import assert_le, assert_lt

from unshielded_swaps.constants import MAX_AMOUNT, MAX_NONCE, MAX_EXPIRATION_TIMESTAMP
from invisible_swaps.helpers.utils import Note, Invisibl3Order

func range_checks_{range_check_ptr}(
    invisibl3_order : Invisibl3Order, refund_note : Note, spend_amount : felt
):
    alloc_locals

    # Todo Maybe add some more checks if need be

    assert_lt(invisibl3_order.amount_spent, MAX_AMOUNT)
    assert_lt(invisibl3_order.amount_received, MAX_AMOUNT)

    # todo new_filled_amount = prev_filled_amount + spent_amount  (only in later fills)
    # todo assert_le(new_filled_amount, limit_order.amount_spent)

    assert_lt(invisibl3_order.nonce, MAX_NONCE)

    # todo let global_expiration_timestamp = ...?
    # todo assert_lt(global_expiration_timestamp, limit_order.expiration_timestamp)
    assert_lt(invisibl3_order.expiration_timestamp, MAX_EXPIRATION_TIMESTAMP)

    assert_le(0, refund_note.amount)
    assert_le(spend_amount, invisibl3_order.amount_spent)

    return ()
end
