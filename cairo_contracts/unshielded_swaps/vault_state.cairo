from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.cairo.common.dict_access import DictAccess
from starkware.cairo.dex.dex_constants import BALANCE_BOUND, ZERO_VAULT_HASH

struct AccountState:
    member public_key : felt
    member token_id : felt
    member balance : felt
end

struct LimitOrder:
    member public_key : felt
    member token_id : felt
    member balance : felt
end
