# %builtins output pedersen

from starkware.cairo.common.cairo_builtins import HashBuiltin, SignatureBuiltin
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.hash import hash2
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.hash_state import (
    hash_init,
    hash_finalize,
    hash_update,
    hash_update_single,
)
from starkware.cairo.common.math import split_felt, unsigned_div_rem
from starkware.cairo.common.cairo_secp.bigint import BigInt3, bigint_to_uint256, uint256_to_bigint
from starkware.cairo.common.cairo_secp.ec import EcPoint, ec_double, ec_add, ec_mul, ec_negate

# func main{output_ptr, pedersen_ptr : HashBuiltin*}():
#     alloc_locals

# # local secret : felt
#     # %{ ids.secret = program_input['secret'] %}

# # assert hash = [output_ptr]

# # let output_ptr = output_ptr + 1

# return ()
# end

# func secp256k1_tests{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
#     alloc_locals

# local Gx : BigInt3 = BigInt3(
#         d0=17117865558768631194064792, d1=12501176021340589225372855, d2=9198697782662356105779718
#         )
#     local Gy : BigInt3 = BigInt3(
#         d0=6441780312434748884571320, d1=57953919405111227542741658, d2=5457536640262350763842127
#         )

# local G : EcPoint = EcPoint(Gx, Gy)

# let G2 : EcPoint = ec_double(G)

# let tripleG : EcPoint = ec_add(G, G2)

# let multiplier = BigInt3(d0=12345, d1=0, d2=0)

# let mulG : EcPoint = ec_mul(G, multiplier)

# %{
#         print("mulG: ", ids.mulG.x.d0)
#         print("mulG: ", ids.mulG.x.d1)
#         print("mulG: ", ids.mulG.x.d2)
#         print("mulG: ", ids.mulG.y.d0)
#         print("mulG: ", ids.mulG.y.d1)
#         print("mulG: ", ids.mulG.y.d2)
#     %}

# return ()
# end

# func mrkl_test{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}(
#     prev_root : felt, new_root : felt
# ):
#     alloc_locals

# const new_leaf = 3164323627516594121377279009776584742545140296216692733963317135789580090177

# %{ initial_dict = {1:0} %}
#     let my_dict : DictAccess* = dict_new()
#     dict_write{dict_ptr=my_dict}(1, 0)
#     let dict_start = my_dict

# dict_update{dict_ptr=my_dict}(1, 0, new_leaf)

# let (finalized_dict_start, finalized_dict_end) = dict_squash{range_check_ptr=range_check_ptr}(
#         dict_start, my_dict
#     )

# merkle_multi_update{hash_ptr=pedersen_ptr}(finalized_dict_start, 1, 3, prev_root, new_root)

# return ()
# end

# func dict_test{output_ptr, pedersen_ptr : HashBuiltin*, range_check_ptr}():
#     alloc_locals

# %{ initial_dict = {12:0, 1:0, 4:0} %}
#     let my_dict : DictAccess* = dict_new()
#     dict_write{dict_ptr=my_dict}(12, 1)
#     dict_write{dict_ptr=my_dict}(1, 123)
#     dict_write{dict_ptr=my_dict}(4, 2020)
#     let dict_start = my_dict

# dict_update{dict_ptr=my_dict}(12, 1, 2)
#     dict_update{dict_ptr=my_dict}(1, 123, 456)
#     dict_update{dict_ptr=my_dict}(4, 2020, 2022)

# let (finalized_dict_start, finalized_dict_end) = dict_squash{range_check_ptr=range_check_ptr}(
#         dict_start, my_dict
#     )

# let x : DictAccess = finalized_dict_start[0]
#     let y : DictAccess = finalized_dict_start[1]
#     let z : DictAccess = finalized_dict_start[2]

# %{
#         print("key:", ids.x.key)
#         print("prev:", ids.x.prev_value)
#         print("new:", ids.x.new_value)
#         print("key:", ids.y.key)
#         print("prev:", ids.y.prev_value)
#         print("new:", ids.y.new_value)
#         print("key:", ids.z.key)
#         print("prev:", ids.z.prev_value)
#         print("new:", ids.z.new_value)
#     %}

# return ()
# end

# func handle_inputs_test{pedersen_ptr : HashBuiltin*}(x : felt*):
#     %{
#         ids.prev_root = program_input["prev_root"]
#         ids.new_root = program_input["new_root"]

# preimage = program_input["preimage"]
#         preimage = {int(k):v for k,v in preimage.items()}

# tokens = program_input["tokens"]
#         rs_ = sig[1:]
#         ids.rs_len = len(rs_)
#         ids.rs = rs = segments.add()
#         for i, val in enumerate(rs_):
#             memory[rs + i] = val

# ids.amounts = program_input["amount"]
#         ids.blinding_factors = program_input["blinding_factor"]

# addresses = program_input["address"]
#         # ids.addresses_len = len(addresses_)
#         # ids.addresses = addresses = segments.add()

# POINT_SIZE = ids.EcPoint.SIZE
#         X_OFFSET = ids.EcPoint.x
#         Y_OFFSET = ids.EcPoint.y

# BIG_INT_SIZE = ids.BigInt3.SIZE
#         BIG_INT_0_OFFSET = ids.BigInt3.d0
#         BIG_INT_1_OFFSET = ids.BigInt3.d1
#         BIG_INT_2_OFFSET = ids.BigInt3.d2

# addr_x = ids.address.address_  + X_OFFSET
#         addr_y = ids.address.address_  + Y_OFFSET

# memory[addr_x + BIG_INT_0_OFFSET] = addr[0][0]
#         memory[addr_x + BIG_INT_1_OFFSET] = addr[0][1]
#         memory[addr_x + BIG_INT_2_OFFSET] = addr[0][2]

# memory[addr_y + BIG_INT_0_OFFSET] = addr[1][0]
#         memory[addr_y + BIG_INT_1_OFFSET] = addr[1][1]
#         memory[addr_y + BIG_INT_2_OFFSET] = addr[1][2]
#     %}

# return ()
# end

func test_log_array{pedersen_ptr : HashBuiltin*}(arr_len : felt, arr : felt*):
    if arr_len == 0:
        return ()
    end

    let el = arr[0]
    %{ print("el: ", ids.el) %}

    return test_log_array(arr_len - 1, &arr[1])
end
