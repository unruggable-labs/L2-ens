// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IExtendedResolver} from "ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {EVMFetchTarget} from "evmgateway/evm-verifier/contracts/EVMFetchTarget.sol";
import {EVMFetcher} from "evmgateway/evm-verifier/contracts/EVMFetcher.sol";
import {IEVMVerifier} from "evmgateway/evm-verifier/contracts/IEVMVerifier.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";

// This is only used to create a function selector. 
interface IResolverService {
    function resolve(bytes calldata name, bytes calldata data) external view returns(bytes memory result, uint64 expires, bytes memory sig);
}

contract OpOffchainResolver is IExtendedResolver, EVMFetchTarget, ERC165 {

    using EVMFetcher for EVMFetcher.EVMFetchRequest;
    using BytesUtils for bytes;

    error OffchainLookup(address sender, string[] urls, bytes callData, bytes4 callbackFunction, bytes extraData);


    IEVMVerifier public opVerifier;
    ENS public ens;
    address public l2resolver;
    Resolver public l1PublicResolver;


    constructor(
        IEVMVerifier _evmVerifier, 
        ENS _ens, 
        address _l2Resolver, 
        Resolver _l1PublicResolver
    ) {
        opVerifier = _evmVerifier;
        ens = _ens;
        l2resolver = _l2Resolver;
        l1PublicResolver = _l1PublicResolver;
    }

    /**
     * Resolves a name, as specified by ENSIP 10.
     * @param name The DNS-encoded name to resolve.
     * @param data The ABI encoded data for the underlying resolution function (Eg, addr(bytes32), text(bytes32,string), etc).
     * @return The return data, ABI encoded identically to the underlying function.
     */
    function resolve(bytes calldata name, bytes calldata data) external override view returns(bytes memory) {

        /* In the future we will need to parse "data" to 
         * determine which function to call. Currently, we
         * only supporting address resolution, using 
         * 
         * addr(bytes32 node) or addr(bytes32 node, uint256 coinType)
         * 
         * We also need to generate the node from the name, changing the TLD to .unruggable.
         */
    
       // Do we want to replace the 2LD here to ID.unruggable? 
        
       uint256 node = uint256(name.namehash(0));
       resolveAddress(node, 60); 

    }

    function resolveAddress(uint256 node, uint256 coinType) private view {

        EVMFetcher.newFetchRequest(opVerifier, l2resolver)
            .getDynamic(0) // This is the base slot of the version number of the public resolver contract.
                .element(node) 
            .getDynamic(4) // This is the base slot of the versionable_addresses mapping.
                .ref(0)
                .element(node)
            .fetch(this.resolveAddressCallback.selector, "");
    }


    /**
     * A callback function which is called after the L2 data has been proven
     */

    function resolveAddressCallback(bytes[] memory values, bytes memory) public pure returns(address) {
        return abi.decode(values[1], (address)); // The second value 'values[1]' is the address.
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override 
        returns (bool)
    {
        return
            interfaceId == type(IExtendedResolver).interfaceId; 
    }
    
}
