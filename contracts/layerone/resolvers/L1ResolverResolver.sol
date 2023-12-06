// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EVMFetcher} from 'evmgateway/evm-verifier/contracts/EVMFetcher.sol';
import {EVMFetchTarget} from 'evmgateway/evm-verifier/contracts/EVMFetchTarget.sol';
import {IEVMVerifier} from 'evmgateway/evm-verifier/contracts/IEVMVerifier.sol';

contract L1ResolverResolver is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    IEVMVerifier immutable verifier;
    address immutable target;
    uint256 constant RECORDS_SLOT = 0;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }

    /**
     * Returns the resolver associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function resolver(bytes32 node) public view returns (address) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(RECORDS_SLOT)
              .element(node)
              .element(string("resolver"))
            .fetch(this.resolverCallback.selector, '');
    }

    function resolverCallback(
        bytes[] memory values,
        bytes memory
    ) public pure returns (address) {
        return address(bytes20(values[1]));
    }
}
