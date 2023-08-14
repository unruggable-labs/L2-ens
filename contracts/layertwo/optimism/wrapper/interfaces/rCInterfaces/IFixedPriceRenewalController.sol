//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "optimism/wrapper/interfaces/IRenewalController.sol";
import "optimism/wrapper/interfaces/IAggregatorInterface.sol";

/** 
 *  @title An interface for a renewal controller offering fixed price (USD) renewals
 *  @author Unruggable Labs
 *  @notice Allows the setting of a USD denominated renewal price and an Oracle for converting to Wei
 */ 
 
interface IFixedPriceRenewalController is IRenewalController {

    function setUSDPrice(uint256 _usdPrice) external;

    function updateOracle(IAggregatorInterface _usdOracle) external;
}