//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IL2NameWrapper} from "../interfaces/IL2NameWrapper.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";
import {IAggregatorInterface} from "../interfaces/IAggregatorInterface.sol";
import {BytesUtilsSub} from "../BytesUtilsSub.sol";
import {IRenewalController} from "../interfaces/IRenewalController.sol";
import {IFixedPriceRenewalController} from "../interfaces/rCInterfaces/IFixedPriceRenewalController.sol";
import {L2RenewalControllerBase} from "../L2RenewalControllerBase.sol";


contract L2FixedPriceRenewalController is
    L2RenewalControllerBase,
    IFixedPriceRenewalController
    {

    using StringUtils for *;
    using BytesUtilsSub for bytes;

    uint256 public usdPrice;

    // Chainlink oracle address
    IAggregatorInterface public usdOracle;

    constructor(
        IL2NameWrapper _nameWrapper,
        IAggregatorInterface _usdOracle,
        uint256 _usdPrice
    ) L2RenewalControllerBase(_nameWrapper){

        // Set the oracle address.
        usdOracle = _usdOracle;
        // Set the price of the renewal in USD.
        usdPrice = _usdPrice;
    }

    /**
     * @notice Sets the price of the renewal in USD/sec with 18 digits of precision.
     * @param _usdPrice The price of the renewal in USD.
     */

    function setUSDPrice(uint256 _usdPrice) public onlyOwner {

        // Set the price of the renewal in USD.
        usdPrice = _usdPrice;
    }
    
    /**
     * @notice Sets the oracle address.
     * @param _usdOracle The oracle address.
     */

    function updateOracle(IAggregatorInterface _usdOracle) public onlyOwner {

        // Set the oracle address.
        usdOracle = _usdOracle;
    }

    /**
     * @notice Gets the total cost of rent in wei, from the unitPrice, i.e. USD, and duration.
     * @param duration The amount of time the name will be rented for/extended in years. 
     * @return The rent price for the duration in Wei, and USD. 
     */

    function rentPrice(bytes calldata, uint256 duration)
        public
        view
        override (IRenewalController, L2RenewalControllerBase)
        returns (uint256, uint256)
    {

        // Convert the unit price from USD to Wei.
        return (usdToWei(usdPrice * duration), usdPrice * duration);
    }

    /**
    * @param interfaceId The interface identifier, as specified in ERC-165.
    * @return `true` if the contract implements `interfaceID`
    */ 

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == type(IFixedPriceRenewalController).interfaceId ||
            interfaceId == type(IRenewalController).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
    * @dev Converts USD to Wei. 
    * @param amount The amount of USD to be converted to Wei.
    * @return The amount of Wei.
    */
    function usdToWei(uint256 amount) internal view returns (uint256) {

        // Get the price of ETH in USD (with 8 digits of precision) from the oracle.
        uint256 ethPrice = uint256(usdOracle.latestAnswer());

        // Convert the amount of USD (with 18 digits of precision) to Wei. 
        return (amount * 1e8) / ethPrice;
    }

}

