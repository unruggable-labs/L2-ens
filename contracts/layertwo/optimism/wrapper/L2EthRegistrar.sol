//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";
import {IL2EthRegistrar} from "optimism/wrapper/interfaces/IL2EthRegistrar.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {IL2NameWrapper, CANNOT_UNWRAP, PARENT_CANNOT_CONTROL, CAN_EXTEND_EXPIRY} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {ERC20Recoverable} from "ens-contracts/utils/ERC20Recoverable.sol";
import {BytesUtilsSub} from "optimism/wrapper/BytesUtilsSub.sol";
import {IAggregatorInterface} from "optimism/wrapper/interfaces/IAggregatorInterface.sol";
import {Balances} from "optimism/wrapper/Balances.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";

error CommitmentTooNew(bytes32 commitment);
error CommitmentTooOld(bytes32 commitment);
error NameNotAvailable(bytes name);
error DurationTooShort(uint256 duration);
error ResolverRequiredWhenDataSupplied();
error UnexpiredCommitmentExists(bytes32 commitment);
error InsufficientValue();
error UnauthorizedAddress(bytes32 node);
error MaxCommitmentAgeTooLow();
error MaxCommitmentAgeTooHigh();
error WrongNumberOfChars(string label);
error NoPricingData();
error CannotSetNewCharLengthAmounts();
error InvalidDuration(uint256 duration);
error LabelTooShort();
error LabelTooLong();

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract L2EthRegistrar is
    Ownable,
    IL2EthRegistrar,
    ERC165,
    ERC20Recoverable,
    Balances
{
    using StringUtils for *;

    using Address for address payable;
    using BytesUtilsSub for bytes;

    uint64 private constant GRACE_PERIOD = 90 days;
    uint256 public constant MIN_REGISTRATION_DURATION = 28 days;
    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    uint64 private constant MAX_EXPIRY = type(uint64).max;
    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;
    IL2NameWrapper public immutable nameWrapper;
    ENS public immutable ens;

    // Chainlink oracle address
    IAggregatorInterface public immutable usdOracle;


    // The pricing and character requirements for .eth 2LDs, e.g. vitalik.eth.
    uint64 public minRegistrationDuration;
    uint64 public maxRegistrationDuration;
    uint16 public minChars;
    uint16 public maxChars;
    uint256[] public charAmounts;

    
    mapping(bytes32 => uint256) public commitments;

    constructor(
        uint256 _minCommitmentAge,
        uint256 _maxCommitmentAge,
        ENS _ens,
        IL2NameWrapper _nameWrapper,
        IAggregatorInterface _usdOracle
    ) {
        if (_maxCommitmentAge <= _minCommitmentAge) {
            revert MaxCommitmentAgeTooLow();
        }

        if (_maxCommitmentAge > block.timestamp) {
            revert MaxCommitmentAgeTooHigh();
        }

        minCommitmentAge = _minCommitmentAge;
        maxCommitmentAge = _maxCommitmentAge;
        ens = _ens;
        nameWrapper = _nameWrapper;

        // Set the oracle address.
        usdOracle = _usdOracle;

    }

    /**
     * @notice Gets the total cost of rent in wei, from the unitPrice, i.e. USD, and duration.
     * @param duration The amount of time the name will be rented for/extended in years. 
     * @return The rent price for the duration in Wei and USD. 
     */

    function rentPrice(bytes memory name, uint256 duration)
        public
        view
        returns (uint256, uint256) // (uint256 weiPrice, uint256 usdPrice) 
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
        } else {
            //If there is no pricing data, set the price to 0.
            unitPrice = 0;
        }

        // Convert the unit price from USD to Wei.
        return (usdToWei(unitPrice * duration), unitPrice * duration);
    }

    /**
     * @notice checkes to see if the length of the name is greater than the min. and less than the max.
     * @param label Label as a string, e.g. "vault" or vault.vitalik.eth.
     */

    function validLength(string memory label) internal view returns (bool){

        //@audit : Make sure to check what happens when string label is missing or zero length

        // The name is valid if the number of characters of the label is greater than the 
        // minimum and the less than the maximum or the maximum is 0, return true.  
        if (label.strlen() >= minChars){

            // If the maximum characters is set then check to make sure the label is 
            // shorter or equal to it.  
            if (maxChars != 0 && label.strlen() > maxChars){
                return false; 
            } else {
                return true;
            }
        } else {
            return false; 
        }
    }

    /**
     * @notice Set the pricing for subnames of the parent name.
     * @param _minRegistrationDuration The minimum duration a name can be registered for.
     * @param _maxRegistrationDuration The maximum duration a name can be registered for.
     * @param _minChars The minimum length a name can be.
     * @param _maxChars The maximum length a name can be.
     */
     
     function setParams(
        uint64 _minRegistrationDuration, 
        uint64 _maxRegistrationDuration,
        uint16 _minChars,
        uint16 _maxChars
    ) public onlyOwner {

        // Set the pricing for subnames of the parent node.
        minRegistrationDuration = _minRegistrationDuration;
        maxRegistrationDuration = _maxRegistrationDuration;
        minChars = _minChars;
        maxChars = _maxChars;
    }

    /**
    * @notice Set the pricing for subname lengths.
    * @param _charAmounts An array of amounst for each characer length.
    */  

     function setPricingForAllLengths(
        uint256[] calldata _charAmounts
    ) public onlyOwner {

        // Clear the old dynamic array out
        delete charAmounts;

        // Set the pricing for subnames of the parent node.
        charAmounts = _charAmounts;
        
    }

    /**
     * @notice Get the price for a single character length, e.g. three characters.
     * @param charLength The character length, e.g. 3 would be for three characters. Use 0 for the default amount.
     */
    function getPriceDataForLength(uint16 charLength) public view returns (uint256){
        return charAmounts[charLength];
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
            revert CannotSetNewCharLengthAmounts();
        }
        charAmounts[charLength] = charAmount;
    }


    /**
     * @notice Adds a price for the next character length, e.g. three characters.
     * @param charAmount The amount in USD/sec. (with 18 digits of precision) 
     * for a character count, e.g. amount for three characters.
     */
    function addNextPriceForCharLength(
        uint256 charAmount
    ) public onlyOwner {

        charAmounts.push(charAmount);
    }

    /**
     * @notice Get the last length for a character length that has a price (can be 0), e.g. three characters.
     * @return The length of the last character length that was set.
     */
    function getLastCharIndex() public view returns (uint256) {
        return charAmounts.length - 1;
    }

    /**
     * @notice Check to see if the name is available for registration. 
     * @param name The full name, in DNS format wherein the length precedes each label
     * and is terminted with a 0x0 byte, e.g. "cb.id" => [0x02,0x63,0x62,0x02,0x69,0x64,0x00].
     */

    function available(bytes memory name) public view returns (bool) {

        (bytes32 labelhash, uint256 offset) = name.readLabel(0);
        bytes32 parentNode = name.namehash(offset);
        bytes32 node = _makeNode(parentNode, labelhash);

        // Get the label from the _name. 
        (string memory label, ) = name.getFirstLabel();

        // The name is presumed to be available if it has not been registered and it is a valid length.
        // If the parent owner revokes the authorization of this contract, then this function will still return true, but
        // registration will not be possible. 

        return validLength(label) && 
            ens.owner(node) == address(0);

    }

    /**
     * @notice Check to see if the name is available for registration. 
     * @param label The label in bytes, "vitalik" for vitalik.eth.
     * and is terminted with a 0x0 byte, e.g. "cb.id" => [0x02,0x63,0x62,0x02,0x69,0x64,0x00].
     */
    function makeCommitment(
        string memory label,
        address owner,
        bytes32 secret
    ) public pure returns (bytes32) {

        return
            keccak256(
                abi.encode(
                    label,
                    owner,
                    secret
                )
            );
    }

    function commit(bytes32 commitment) public {
        if (commitments[commitment] + maxCommitmentAge >= block.timestamp) {
            revert UnexpiredCommitmentExists(commitment);
        }
        commitments[commitment] = block.timestamp;
    }

    /**
     * @notice Register a name.
     * @param label The full name, in DNS format.
     * @param owner The address that will own the name.
     * @param referrer The address that referred the owner to the registrar.
     * @param duration The duration in seconds of the registration.
     * @param secret The secret to be used for the commitment.
     * @param resolver The address of the resolver to use.
     * @param fuses The fuses to be set on the name.
     */

    function register(
        string calldata label,
        address owner,
        address referrer,
        uint256 duration,
        bytes32 secret,
        address resolver,
        uint16 fuses
    ) public payable {

        bytes32 node = _makeNode(ETH_NODE, keccak256(bytes(label)));

        // Create the name of the .eth 2LD, using addlabel
        bytes memory name = _addLabel(label, "\x03eth\x00");

        // Check to make sure the duration is between the min and max. 
        if (duration < minRegistrationDuration ||
            duration > maxRegistrationDuration){
            revert InvalidDuration(duration); 
        }

        address parentOwner = nameWrapper.ownerOf(uint256(ETH_NODE));

        // Check to make sure the label is a valid length.
        if(!validLength(label)){
            revert WrongNumberOfChars(label);
        }

        // add the grace period to the duration.
        uint64 expires =  uint64(block.timestamp + duration + GRACE_PERIOD);

        // Get the price for the duration.
        (uint256 price,) = rentPrice(name, duration);

        // Check to make sure the caller sent enough Eth.
        if (msg.value < price) {
            revert InsufficientValue();
        }

        // Create a block to solve a stack too deep error.
        {

            uint256 referrerAmount;

            // If a referrer is specified then calculate the amount to be given to the referrer.
            if (referrer != address(0)) {

                // Calculate the amount to be given to the referrer.
                referrerAmount = price * referrerCuts[referrer] / 10000;

                //Increase the referrer's balance.
                balances[referrer] += referrerAmount;
            }

            //increase the total balances of the referrers.
            totalBalance += referrerAmount;        
        }

        _burnCommitment(
            duration,
            makeCommitment(
                label,
                owner,
                secret
            )
        );

        nameWrapper.registerAndWrapEth2LD(
            label, 
            owner,
            address(0), // no approved account
            expires,
            resolver,
            fuses
        );

        emit Eth2LDRegistered(
            label,
            node,
            owner,
            price,
            expires
        );

        // Because the oracle can return a slightly different value then what was estimated
        // we overestimate the price and then return any difference. 
        if (msg.value > price) {
            payable(msg.sender).sendValue(
                msg.value - price
            );
        }
    }

    /**
    * @notice Function to renew a name for a specified duration. 
    * @param label The name to be renewed in DNS format.
    * @param duration The duration for which the name should be renewed in years.
    */

    function renew(
        string calldata label, 
        address referrer, 
        uint256 duration
        )
        public
        payable
    {        
        
        // the labelhash of the label.
        bytes32 labelhash = keccak256(bytes(label));
        // Create the parent node.
        bytes32 parentNode = bytes("\x03eth\x00").namehash(0);
        bytes32 node = _makeNode(ETH_NODE, labelhash);

        // Create the name of the .eth 2LD, using addlabel
        bytes memory name = _addLabel(label, "\x03eth\x00");

        // Get the owners of the name and the parent name.
        address parentOwner = nameWrapper.ownerOf(uint256(ETH_NODE));
        address nodeOwner = nameWrapper.ownerOf(uint256(node));

        // remove the access control check, because anyone can renew a .eth 2LD name. 
        if( msg.sender != nodeOwner && nameWrapper.isApprovedForAll(nodeOwner, msg.sender)){
            revert UnauthorizedAddress(node);
        }

        uint64 expiry;

        // Create a block to solve a stack too deep error.
        {
            // Get the previous expiry. 
            (,, uint64 nodeExpiry) = nameWrapper.getData(uint256(node));

            // Check to see if the duration is too long and
            // if it is set the duration.
            (,, uint64 parentExpiry) = nameWrapper.getData(uint256(parentNode));
            if (nodeExpiry + duration > parentExpiry) {
                duration = parentExpiry - nodeExpiry;
            }

            // Set the expiry
            expiry =  uint64(nodeExpiry + duration);
        }

        // Get the price for the duration.
        (uint256 priceEth,) = rentPrice(name, duration);
        if (msg.value < priceEth) {
            revert InsufficientValue();
        }

        // Create a block to solve a stack too deep error.
        {
            uint256 referrerAmount;

            // If a referrer is specified then calculate the amount to be given to the referrer.
            if (referrer != address(0)) {

                // Calculate the amount to be given to the referrer.
                referrerAmount = priceEth * referrerCuts[referrer] / 10000;

                // Increase the referrer's balance
                balances[referrer] += referrerAmount;
            }

            // Increase the total balances
            totalBalance += referrerAmount;
        }

        nameWrapper.extendExpiry(
            ETH_NODE,
            labelhash,
            expiry
        );

        emit NameRenewed(label, priceEth, expiry);

        // If the caller paid too much refund the amount overpaid. 
        if (msg.value > priceEth) {
            payable(msg.sender).sendValue(msg.value - priceEth);
        }

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

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == type(IL2EthRegistrar).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* Internal functions */

    function _addLabel(
        string memory label,
        bytes memory name
    ) internal pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong();
        }
        return abi.encodePacked(uint8(bytes(label).length), label, name);
    }

    function _burnCommitment(
        uint256 duration,
        bytes32 commitment
    ) internal {

        // Require an old enough commitment.
        if (commitments[commitment] + minCommitmentAge > block.timestamp) {
            revert CommitmentTooNew(commitment);
        }

        // If the commitment is too old, or the name is registered, stop
        if (commitments[commitment] + maxCommitmentAge <= block.timestamp) {
            revert CommitmentTooOld(commitment);
        }

        delete (commitments[commitment]);

        if (duration < MIN_REGISTRATION_DURATION) {
            revert DurationTooShort(duration);
        }
    }

    function _makeNode(bytes32 node, bytes32 labelhash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(node, labelhash));
    }
}