//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";
import {IAggregatorInterface} from "optimism/wrapper/interfaces/IAggregatorInterface.sol";
import {BytesUtilsSub} from "optimism/wrapper/BytesUtilsSub.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";
import {IPricePerCharRenewalController} from "optimism/wrapper/interfaces/rCInterfaces/IPricePerCharRenewalController.sol";
import {L2RenewalControllerBase} from "optimism/wrapper/L2RenewalControllerBase.sol";

error CannotSetNewCharLengthAmount();

contract L2PricePerCharRenewalController is 
    L2RenewalControllerBase,
    IPricePerCharRenewalController
    {

    using StringUtils for *;
    using BytesUtilsSub for bytes;

    // The pricing data used for renewing subnames.
    uint256[] public charAmounts;

    // Chainlink oracle address
    IAggregatorInterface public usdOracle; //@audit - is there any way to update the oracle? 

    constructor(
        INameWrapper _nameWrapper,
        IAggregatorInterface _usdOracle
    ) L2RenewalControllerBase(_nameWrapper){

        // Set the oracle address.
        usdOracle = _usdOracle;

        // Set charAmounts to a new array with a length of 1.
        charAmounts = new uint256[](1);
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
    * @notice Set the pricing for subname lengths.
    * @param _charAmounts An array of amounst for each characer length.
    */  

     function setPricingForAllLengths(
        uint256[] calldata _charAmounts
    ) public onlyOwner {

        delete charAmounts;
        charAmounts = _charAmounts;

        emit CharPricesUpdated(_charAmounts);
    }

    /**
     * @notice Set a price for a single character length, e.g. three characters.
     * @param charLength The character length, e.g. 3 would be for three characters. Use 0 for the default amount.
     * @param charAmount The amount in USD/year for a character count, e.g. amount for three characters.
     */
    function updatePriceForCharLength(
        uint16 charLength,
        uint256 charAmount
    ) public onlyOwner {

        // Check that the charLength is not greater than the last index of the charAmounts array.
        if (charLength > charAmounts.length-1){
            revert CannotSetNewCharLengthAmount();
        }
        charAmounts[charLength] = charAmount;

        emit PriceForCharLengthUpdated(charLength, charAmount);
    }


    /**
     * @notice Adds a price for the next character length, e.g. three characters.
     * @param amount The amount in USD/sec. (with 18 digits of precision) 
     * for a character count, e.g. amount for three characters.
     */
    function addNextPriceForCharLength(
        uint256 amount
    ) public onlyOwner {

        charAmounts.push(amount);

        emit PriceForCharLengthUpdated(charAmounts.length-1, amount);
    }

    /**
     * @notice Get the last length for a character length that has a price (can be 0), e.g. three characters.
     * @return The length of the last character length that was set.
     */
    function getLastCharIndex() public view returns (uint256) {
        return charAmounts.length - 1;
    }

     /**
     * @notice Gets the total cost of rent in wei, from the unitPrice, i.e. USD, and duration.
     * @param name The name in DNS format, e.g. vault.vitalik.eth
     * @param duration The amount of time the name will be rented for/extended in years. 
     * @return The rent price for the duration in Wei, and USD. 
     */

    function rentPrice(bytes calldata name, uint256 duration)
        public
        view
        override (IRenewalController, L2RenewalControllerBase)
        returns (uint256, uint256)
    {

        ( , uint256 labelLength) = name.getFirstLabel();

        // Get the length of the charAmounts array.
        uint256 charAmountsLength = charAmounts.length;

        // The price of the length of the label in USD/sec. (with 18 digits of precision).
        uint256 unitPrice;
        
        if (charAmountsLength > 0) {
            // Check to make sure the price for labelLength exists.
            // If not use the default price charAmounts[0].
            if(labelLength < charAmountsLength){

                // Get the unit price, i.e. the price in USD/sec, for the length of
                // the label. If there is not a price set then use the defualt amount.  
                unitPrice = charAmounts[labelLength];

                // If the unit price is 0 then use the default amount.
                if (unitPrice == 0){ 
                    unitPrice = charAmounts[0];
                } 

            } else {

                // Get the unit price, i.e. the price in USD/sec using the defualt amount.  
                unitPrice = charAmounts[0];

            }

            // Convert the unit price from USD to Wei.
            return (usdToWei(unitPrice * duration), unitPrice * duration);

        } else {
            //If there is no pricing data return 0, i.e. FREE.
            return (0,0);
        }

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
            interfaceId == type(IPricePerCharRenewalController).interfaceId ||
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