//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IL2RenewalController} from "optimism/wrapper/interfaces/IL2RenewalController.sol";

/**
 * @title Interface for a registrar for registering subnames.
 * @author Unruggable Labs
 */

interface IL2EthRegistrar {

    event Eth2LDRegistered(
        string indexed label,
        bytes32 indexed node,
        address indexed owner,
        uint256 price,
        uint256 expires
    );

    event EthNameRenewed(
        string indexed label,
        uint256 indexed price,
        uint256 indexed duration
    );

    function rentPrice(
        bytes calldata name,
        uint256 duration
    )
        external
        view
        returns (uint256 weiPrice, uint256 usdPrice);

    function setParams(
        uint64 _minRegistrationDuration,
        uint64 _maxRegistrationDuration,
        uint16 _minChars,
        uint16 _maxChars,
        uint16 _referrerCut 
    ) external;

    function setPricingForAllLengths(
        uint256[] calldata _charAmounts
    ) external;

    function getPriceDataForLength(
        uint16 charLength
    ) external view returns (uint256);

    function updatePriceForCharLength(
        uint16 charLength,
        uint256 charAmount
    ) external;

    function addNextPriceForCharLength(
        uint256 charAmount
    ) external;

    function getLastCharIndex() external view returns (uint256);

    function available(bytes memory name) external returns (bool);

    function makeCommitment(
        string memory label,
        address owner,
        bytes32 secret
    ) external pure returns (bytes32);

    function commit(bytes32 commitment) external;

    function register(
        string calldata label,
        address owner,
        address referrer,
        uint256 duration,
        bytes32 secret,
        address resolver,
        uint16 fuses
    ) external payable;
}