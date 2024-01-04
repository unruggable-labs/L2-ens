// SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {EVMFetcher} from 'evmgateway/evm-verifier/contracts/EVMFetcher.sol';
import {EVMFetchTarget} from 'evmgateway/evm-verifier/contracts/EVMFetchTarget.sol';
import {IEVMVerifier} from 'evmgateway/evm-verifier/contracts/IEVMVerifier.sol';

contract L1Resolver is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    IEVMVerifier immutable verifier;
    address immutable target;
    uint256 constant COIN_TYPE_ETH = 60;
    uint256 constant RECORD_VERSIONS_SLOT = 0;
    uint256 constant VERSIONABLE_ADDRESSES_SLOT = 3;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }


    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) public view returns (address) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(RECORD_VERSIONS_SLOT)
              .element(node)
            .getDynamic(VERSIONABLE_ADDRESSES_SLOT)
              .ref(0)
              .element(node)
              .element(COIN_TYPE_ETH)
            .fetch(this.addrCallback.selector, ''); // recordVersions
    }

    function addrCallback(
        bytes[] memory values,
        bytes memory
    ) public pure returns (address) {
        return address(bytes20(values[1]));
    }
}
