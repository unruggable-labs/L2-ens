//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IL2RenewalController} from "./IL2RenewalController.sol";

/**
 * @title Interface for a registrar for registering subnames.
 * @author Unruggable Labs
 */

interface IL2SubnameRegistrar {

    event SubnameRegistered(
        bytes name,
        bytes32 indexed node,
        address indexed owner,
        uint256 price,
        uint256 expires
    );

    event NameRenewed(
        bytes indexed name,
        uint256 cost,
        uint256 expires
    );

    function rentPrice(
        bytes memory name, 
        uint256 duration
    )
        external
        view
        returns (uint256 weiPrice, uint256 usdPrice);

    function setParams(
        bytes32 parentNode,
        bool _offerSubnames,
        IL2RenewalController _renewalController,
        uint64 _minRegistrationDuration,
        uint64 _maxRegistrationDuration,
        uint16 _minChars,
        uint16 _maxChars,
        uint16 _referrerCut
    ) external;

    function setPricingForAllLengths(
        bytes32 parentNode,
        uint256[] calldata _charAmounts
    ) external;

    function getPriceDataForLength(
        bytes32 parentNode, 
        uint256 charLength
    ) external view returns (uint256);

    function updatePriceForCharLength(
        bytes32 parentNode,
        uint16 charLength,
        uint256 charAmount
    ) external;

    function addNextPriceForCharLength(
        bytes32 parentNode,
        uint256 charAmount
    ) external;

    function getLastCharIndex(bytes32 parentNode) external view returns (uint256);

    function setOfferSubnames(
        bytes32 parentNode,
        bool _offerSubnames
    ) external;

    function available(bytes memory name) external returns (bool);

    function makeCommitment(
        bytes memory name,
        address owner,
        bytes32 secret
    ) external pure returns (bytes32);

    function commit(bytes32 commitment) external;

    function register(
        bytes calldata name,
        address owner,
        address referrer,
        uint256 duration,
        bytes32 secret,
        address resolver,
        uint32 fuses
    ) external payable;
}