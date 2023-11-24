// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {EVMFetcher} from 'evmgateway/evm-verifier/contracts/EVMFetcher.sol';
import {EVMFetchTarget} from 'evmgateway/evm-verifier/contracts/EVMFetchTarget.sol';
import {IEVMVerifier} from 'evmgateway/evm-verifier/contracts/IEVMVerifier.sol';

contract BasicDemo is EVMFetchTarget {
    using EVMFetcher for EVMFetcher.EVMFetchRequest;

    IEVMVerifier verifier;                  // Slot 0
    address target;

    constructor(IEVMVerifier _verifier, address _target) {
        verifier = _verifier;
        target = _target;
    }

    function getLatest() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .fetch(this.getLatestCallback.selector, "");
    }

    function getLatestCallback(bytes[] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[0], (uint256));
    }

    function getName() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .fetch(this.getNameCallback.selector, "");
    }

    function getNameCallback(bytes[] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0]);
    }

    function getHighscorer(uint256 idx) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(3)
                .element(idx)
            .fetch(this.getHighscorerCallback.selector, "");
    }

    function getHighscorerCallback(bytes[] memory values, bytes memory) public pure returns(string memory) {
        return string(values[0]);
    }

    function getLatestHighscore() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .getStatic(2)
                .ref(0)
            .fetch(this.getLatestHighscoreCallback.selector, "");
    }

    function getLatestHighscoreCallback(bytes[] memory values, bytes memory) public pure returns(uint256) {
        return abi.decode(values[1], (uint256));
    }

    function getLatestHighscorer() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(0)
            .getDynamic(3)
                .ref(0)
            .fetch(this.getLatestHighscorerCallback.selector, "");
    }

    function getLatestHighscorerCallback(bytes[] memory values, bytes memory) public pure returns(string memory) {
        return string(values[1]);
    }

    function getNickname(string memory _name) public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(4)
                .element(_name)
            .fetch(this.getNicknameCallback.selector, "");
    }

    function getNicknameCallback(bytes[] memory values, bytes memory) public pure returns (string memory) {
        return string(values[0]);
    }

    function getPrimaryNickname() public view returns(string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(1)
            .getDynamic(4)
                .ref(0)
            .fetch(this.getPrimaryNicknameCallback.selector, "");
    }

    function getPrimaryNicknameCallback(bytes[] memory values, bytes memory) public pure returns (string memory) {
        return string(values[1]);
    }

    function getZero() public view returns(uint256) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getStatic(5)
            .fetch(this.getZeroCallback.selector, "");
    }

    function getZeroCallback(bytes[] memory values, bytes memory) public pure returns (uint256) {
        return abi.decode(values[0], (uint256));
    }


    function testr(
        uint256 latest, 
        bytes32 node
    ) public view returns (string memory) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(6)
              .element(latest) //version
              .element(node)
            .fetch(this.testrCallback.selector, ''); // recordVersions
    }



    function testrCallback(
        bytes[] memory values,
        bytes memory
    ) public pure returns (string memory) {
        return string(values[0]);
    }


    /**
     * Returns the address associated with an ENS node.
     * @param node The ENS node to query.
     * @return The associated address.
     */
    function addr(
        uint64 version, 
        address context, 
        bytes32 node
    ) public view returns (address) {
        EVMFetcher.newFetchRequest(verifier, target)
            .getDynamic(7)
              .element(version) //version
              .element(addressToBytes(context))
              .element(node)
              .element(60) //coin type
            .fetch(this.addrCallback.selector, ''); // recordVersions
    }



    function addrCallback(
        bytes[] memory values,
        bytes memory
    ) public pure returns (address) {
        return address(bytes20(values[0]));
    }


    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}