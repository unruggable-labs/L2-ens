// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EVMFetcher} from 'evmgateway/evm-verifier/contracts/EVMFetcher.sol';
import {EVMFetchTarget} from 'evmgateway/evm-verifier/contracts/EVMFetchTarget.sol';
import {IEVMVerifier} from 'evmgateway/evm-verifier/contracts/IEVMVerifier.sol';
import {UnruggableBytesUtils} from './UnruggableBytesUtils.sol';
import {IExtendedResolver} from "./IExtendedResolver.sol";

contract L1UnruggableResolver is IExtendedResolver, EVMFetchTarget {

    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    using UnruggableBytesUtils for bytes;

    IEVMVerifier immutable verifier;
    address immutable target;
    uint256 constant COIN_TYPE_ETH = 60;
    uint256 constant RECORD_VERSIONS_SLOT = 0;
    uint256 constant VERSIONABLE_ADDRESSES_SLOT = 2;

    bytes UNRUGGABLE_TLD = "\x0aunruggable\x00";

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }

    /**
     * Resolves arbitrary data for a particular name, as specified by ENSIP 10.
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(bytes calldata name, bytes calldata data) external view override returns (bytes memory) {

        bytes4 functionSelector = bytes4(data[:4]);

        //Replace the TLD with .unruggable
        bytes memory replacedName = UnruggableBytesUtils.replaceTLD(name, UNRUGGABLE_TLD);

        bytes4 addrSig = bytes4(keccak256("addr(bytes32)"));

        if (functionSelector == addrSig) {

            (bytes32 node) = abi.decode(data[4:],(bytes32));

            bytes32 replacedNode = replacedName.namehash(0);

            this.addr(replacedNode);
        }
    }

    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(bytes32 node) public view returns (bytes memory) {
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
    ) public pure returns (bytes memory) {
        return values[1];
    }


    function supportsInterface(
        bytes4 interfaceID
    )
        public
        view
        virtual
        returns (bool)
    {
        return
            interfaceID == type(IExtendedResolver).interfaceId;
    }
}
