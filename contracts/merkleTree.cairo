%lang starknet
%builtins pedersen range_check

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import get_block_number, get_block_timestamp
from starkware.starknet.common.syscalls import get_caller_address
from starkware.cairo.common.registers import get_fp_and_pc
from starkware.cairo.common.alloc import alloc
from starkware.cairo.common.math import assert_not_zero, assert_le, assert_lt, unsigned_div_rem
from starkware.cairo.common.pow import pow
from starkware.cairo.common.hash import hash2

# ================================================================
# EVENTS

# ================================================================
# STORAGE VARS

# const FIELD_SIZE = 21888242871839275222246405745257275088548364400416034343698204186575808495617
# const ZERO_VALUE = 2089986280348253421170679821480865132823066470938446095505822317253594081284

# const depth = ??
@storage_var
func s_depth() -> (res : felt):
end

@storage_var
func s_root() -> (res : felt):
end

@storage_var
func s_filled_subtrees(idx : felt) -> (res : felt):
end

@storage_var
func s_index() -> (res : felt):
end

# ================================================================
# CONSTRUCTOR

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(depth : felt):
    alloc_locals

    assert_lt(depth, 32)
    assert_lt(0, depth)
    s_depth.write(depth)

    construct_zero_tree(0, depth)

    let (root : felt) = zeros(depth)
    s_root.write(root)

    s_index.write(0)

    return ()
end

@external
func insert{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(leaf : felt) -> (
        res : felt):
    alloc_locals

    let (index) = s_index.read()
    let (d) = s_depth.read()

    let (max_leaves : felt) = pow(2, d)
    assert_lt(index, max_leaves)

    let current_hash = leaf

    let (new_root : felt) = _update_tree(0, d, current_hash, index)

    s_root.write(new_root)
    s_index.write(index + 1)

    return (index)
end

func _update_tree{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        i : felt, depth : felt, current_hash : felt, current_index : felt) -> (hash : felt):
    alloc_locals
    if i == depth:
        return (current_hash)
    end

    let (new_index, rem : felt) = unsigned_div_rem(current_index, 2)
    if rem == 0:
        s_filled_subtrees.write(idx=i, value=current_hash)
        let (zero_value : felt) = zeros(i)
        let (current_hash : felt) = hash2{hash_ptr=pedersen_ptr}(current_hash, zero_value)
        return _update_tree(i + 1, depth, current_hash, new_index)
    else:
        let (v : felt) = s_filled_subtrees.read(idx=i)
        let (current_hash : felt) = hash2{hash_ptr=pedersen_ptr}(v, current_hash)
        return _update_tree(i + 1, depth, current_hash, new_index)
    end
end

func construct_zero_tree{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        i : felt, depth : felt):
    if i == depth:
        return ()
    end

    let (zero_value : felt) = zeros(i)
    s_filled_subtrees.write(idx=i, value=zero_value)

    return construct_zero_tree(i + 1, depth)
end

@view
func read_tree{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(i : felt) -> (
        res : felt):
    let (v : felt) = s_filled_subtrees.read(idx=i)

    return (v)
end

@view
func get_root{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (res : felt):
    let (v : felt) = s_root.read()

    return (v)
end

func zeros{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(i : felt) -> (
        res : felt):
    if i == 0:
        return (2089986280348253421170679821480865132823066470938446095505822317253594081284)
    end
    if i == 1:
        return (3267327133124836230856387917991726181822805365921261798230069956387125461421)
    end
    if i == 2:
        return (2818596543910544989677096212363154504206592528215241558801212434004582873304)
    end
    if i == 3:
        return (3252406550621480144832393888242428698826555249458964388979161634367367394033)
    end
    if i == 4:
        return (1635768333676608069660613850829092590846210258418869114851517485873236499907)
    end
    if i == 5:
        return (2721396407041296208720983187974126691034270683888816859746964904693195033362)
    end
    if i == 6:
        return (2619379402909897584696469155779578014075235021460283858855911012729801132764)
    end
    if i == 7:
        return (2359066737031468664251749829451068028452000527842968478562060308418886534810)
    end
    if i == 8:
        return (426749937921909092809154184612528768561167212729570691907202697896174161709)
    end
    if i == 9:
        return (450097865745829192588372623130765312520677124131476998147278675429203660419)
    end
    if i == 10:
        return (167534735528736586402321613613678506419519338135203425984730620457888562296)
    end
    return (0)
end
