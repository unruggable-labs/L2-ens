// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IExtendedResolver} from "ens-contracts/resolvers/profiles/IExtendedResolver.sol";
import {IEVMVerifier} from "evmgateway/evm-verifier/contracts/IEVMVerifier.sol";

contract OpOffchainResolver is IExtendedResolver {

    IEVMVerifier public opVerifier;

    constructor(IEVMVerifier _evmVerifier) {
        opVerifier = _evmVerifier;
    }

    function resolve(
        bytes memory name,
        bytes memory data
    ) external view override returns (bytes memory) {
        return name;
    }
    
}
