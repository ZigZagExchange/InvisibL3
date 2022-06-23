from copyreg import constructor
import math
import pytest
import asyncio
import json

from starkware.starknet.testing.starknet import Starknet
from starkware.crypto.signature.signature import (
    pedersen_hash, private_to_stark_key, sign, get_random_private_key)


@pytest.fixture(scope='module')
def event_loop():
    return asyncio.new_event_loop()


@pytest.fixture(scope='module')
async def contract_factory():
    starknet = await Starknet.empty()

    contract = await starknet.deploy(
        "../merkleTree.cairo",
        constructor_calldata=[3]
    )

    # owner_acc = await starknet.deploy(
    #     acc_path,
    #     constructor_calldata=[owner.public_key]
    # )

    return starknet, contract


@pytest.mark.asyncio
async def test_main_logic(contract_factory):
    starknet, contract = contract_factory

    res1 = await contract.get_root().call()

    leaf_hash = pedersen_hash(1, 1)
    await contract.insert(leaf_hash).invoke()

    res2 = await contract.get_root().call()

    print(res2.result.res)

    hashes = []
    zero_hash = pedersen_hash(0, 0)
    hashes.append("Start")
    hashes.append(leaf_hash)
    for i in range(3):
        leaf_hash = pedersen_hash(leaf_hash, zero_hash)
        zero_hash = pedersen_hash(zero_hash, zero_hash)
        hashes.append(leaf_hash)

    print(hashes[-1])

    # hashes = []
    # h = pedersen_hash(0, 0)
    # hashes.append("Start")
    # hashes.append(h)
    # for i in range(3):
    #     h = pedersen_hash(h, h)
    #     hashes.append(h)


# @pytest.mark.asyncio
# async def test_get_tx_info(contract_factory):
#     starknet, contract, owner_acc = contract_factory

#     res = await owner.send_transaction(
#         account=owner_acc,
#         to=contract.contract_address,
#         selector_name='test_get_tx_info',
#         calldata=[])

#     # res = await contract.test_get_tx_info().call()

#     print(res.result)
