//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "optimism/wrapper/interfaces/IL2RenewalController.sol";

/** 
 * @title An interface for a renewal controller offering renewals at different prices depending on the length of the name in question
 * @author Unruggable Labs
 */ 

interface IPricePerCharRenewalController is IL2RenewalController {

    event CharPricesUpdated(uint256[] indexed charAmounts);
    event PriceForCharLengthUpdated(uint256 indexed index, uint256 indexed amount);

    function setPricingForAllLengths(
        uint256[] calldata _charAmounts
    ) external;

    function updatePriceForCharLength(
        uint16 charLength,
        uint256 charAmount
    ) external;

    function addNextPriceForCharLength(
        uint256 charAmount
    ) external;

    function getLastCharIndex() external view returns (uint256);
}