//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";
import {ISubnameRegistrar} from "optimism/wrapper/interfaces/ISubnameRegistrar.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {IL2NameWrapper, CANNOT_BURN_NAME, PARENT_CANNOT_CONTROL, CAN_EXTEND_EXPIRY} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {ERC20Recoverable} from "ens-contracts/utils/ERC20Recoverable.sol";
import {BytesUtilsSub} from "optimism/wrapper/BytesUtilsSub.sol";
import {IAggregatorInterface} from "optimism/wrapper/interfaces/IAggregatorInterface.sol";
import {Balances} from "optimism/wrapper/Balances.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";

//import foundry console logging.
import "forge-std/console.sol";

error CommitmentTooNew(bytes32 commitment);
error CommitmentTooOld(bytes32 commitment);
error NameNotAvailable(bytes name);
error UnexpiredCommitmentExists(bytes32 commitment);
error InsufficientValue();
error UnauthorizedAddress(bytes32 node);
error MaxCommitmentAgeTooLow();
error MaxCommitmentAgeTooHigh();
error WrongNumberOfChars(string label);
error CannotSetNewCharLengthAmounts();
error InvalidDuration(uint256 duration);
error RandomNameNotFound();
error WrongNumberOfCharsForRandomName(uint256 numChars);
error InvalidReferrerCut(uint256 referrerCut);
error InvalidAddress(address addr);

/**
 * @dev A registrar controller for registering and renewing names at fixed cost.
 */
contract L2SubnameRegistrar is
    Ownable,
    ISubnameRegistrar,
    ERC165,
    ERC20Recoverable,
    Balances
{
    using StringUtils for *;

    using Address for address payable;
    using BytesUtilsSub for bytes;

    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant UNRUGGABLE_TLD_NODE = 
        0xc951937fc733cfe92dd3ea5d53048d4f39082c7e84dfc0501b03d5e2dd672d5d;
    uint64 private constant MAX_EXPIRY = type(uint64).max;
    uint256 public immutable minCommitmentAge;
    uint256 public immutable maxCommitmentAge;
    IL2NameWrapper public immutable nameWrapper;
    ENS public immutable ens;

    // Chainlink oracle address
    IAggregatorInterface public immutable usdOracle;

    // A struct holding the pricing for renewals.
    // This allows for different pricing for different lengths names. 
    struct Pricing {
        bool offerSubnames; 
        IRenewalController renewalController;
        uint64 minRegistrationDuration;
        uint64 maxRegistrationDuration;
        uint16 minChars;
        uint16 maxChars;
        uint16 referrerCut;
        uint256[] charAmounts;
    }
    
    mapping(bytes32 => uint256) public commitments;

    // The pricing data for each parent node.
    mapping(bytes32=>Pricing) public pricingData;

    // An allow list of parent nodes that can register subnames.
    mapping(bytes32 => bool) public allowList;

    // Permanently disable the allow list.
    bool public allowListDisabled; 

    // A nonce to use for registering .unruggable names.
    uint256 public nonce;

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

        // Default cut is 2% (200/10000).
        ownerCut = 200;  

        // Set the oracle address.
        usdOracle = _usdOracle;

    }

    /**
     * @notice Gets the total cost of rent in wei, from the unitPrice, i.e. USD, and duration.
     * @param name The name in DNS format, e.g. vault.vitalik.eth
     * @param duration The amount of time the name will be rented for/extended in years. 
     * @return weiPrice The rent price for the duration in Wei 
     * @return usdPrice The rent price for the duration in USD 
     */

    function rentPrice(bytes calldata name, uint256 duration)
        public
        view
        returns (uint256 weiPrice, uint256 usdPrice) 
    {

        ( , uint256 labelLength) = name.getFirstLabel();
        bytes32 parentNode = name.namehash(labelLength+1);

        // Get the length of the charAmounts array.
        uint256 charAmountsLength = pricingData[parentNode].charAmounts.length;

        // The price of the length of the label in USD/sec. (with 18 digits of precision).
        uint256 unitPrice; 
        
        // If the charAmounts array has a length greater than 0 then use it, if not unitPrice will be 0.
        if (charAmountsLength > 0) {
            // Check to make sure the price for labelLength exists.
            // If not use the default price charAmounts[0].
            if(labelLength < charAmountsLength){

                // Get the unit price, i.e. the price in USD/sec, for the length of
                // the label. If there is not a price set then use the defualt amount.  
                unitPrice = pricingData[parentNode].charAmounts[labelLength];

                // If the unit price is 0 then use the default amount.
                if (unitPrice == 0){ 
                    unitPrice = pricingData[parentNode].charAmounts[0];
                } 

            } else {

                // Get the unit price, i.e. the price in USD/sec using the defualt amount.  
                unitPrice = pricingData[parentNode].charAmounts[0];

            }
        } 

        // Convert the unit price from USD to Wei.
        return (_usdToWei(unitPrice * duration), unitPrice * duration);
    }

    /**
     * @notice Add a name to the allow list.
     * @param _name The name in DNS format, e.g. vitalik.eth
     * @param _allow A bool indicating if the name is allowed to be listed.
     */

    function allowName(bytes calldata _name, bool _allow) public onlyOwner {

        // Get the namehash of the label.
        bytes32 node = _name.namehash(0);

        // Add the name to the allow list.
        allowList[node] = _allow;
    } 

    /**
     * @notice Disable the allow list permanenty.
     */

    function disableAllowList() public onlyOwner {
        allowListDisabled = true;
    }

    /**
     * @notice checkes to see if the length of the name is greater than the min. and less than the max.
     * @param node Namehash of the name
     * @param label Label as a string, e.g. "vault" or vault.vitalik.eth.
     */

    function validLength(bytes32 node, string memory label) internal view returns (bool /* valid */){

        //@audit - Make sure to check what happens when string label is missing or zero length

        /**
         * The name is valid if the number of characters of the label is greater than the 
         * minimum and the less than the maximum or the maximum is 0, return true.  
         */

        if (label.strlen() >= pricingData[node].minChars){

            // If the maximum characters is set then check to make sure the label is shorter or equal to it.  
            if (pricingData[node].maxChars != 0 && label.strlen() > pricingData[node].maxChars){
                return false; 
            } else {
                return true;
            }
        } // @audit - else the default return value is false? Just make sure this is not an issue. 
    }

    /**
     * @notice Set the pricing for subnames of the parent name.
     * @param name The DNS encoded name we want to offer subnames of.
     * @param _offerSubnames A bool indicating the parent name owner is offering subnames.
     * @param _renewalController The address of the renewal controller.
     * @param _minRegistrationDuration The minimum duration a name can be registered for.
     * @param _maxRegistrationDuration The maximum duration a name can be registered for.
     * @param _minChars The minimum length a name can be.
     * @param _maxChars The maximum length a name can be.
     * @param _referrerCut The percentage of the registration fee that will be given to the referrer.
     */
     
     function setParams(
        bytes memory name,
        bool _offerSubnames,
        IRenewalController _renewalController,
        uint64 _minRegistrationDuration, 
        uint64 _maxRegistrationDuration,
        uint16 _minChars,
        uint16 _maxChars,
        uint16 _referrerCut
    ) public{

        (string memory label , uint256 labelLength) = name.getFirstLabel();
        bytes32 parentNode = name.namehash(0);
        address parentOwner = nameWrapper.ownerOf(uint256(parentNode));

        // If the allow list is being used then check to make sure the caller is on the allow list.
        if (!allowListDisabled && !allowList[parentNode]){
            revert UnauthorizedAddress(parentNode);
        }

        /**
         * Check to make sure the caller is authorised and the parentNode is wrapped in the 
         * Name Wrapper contract and the CANNOT_BURN_NAME and PARENT_CANNOT_CONTROL fuses are burned. 
         */
        if (parentOwner == address(0)) {

            registerUnruggable(
                label,
                msg.sender
            );
        }

        if (!nameWrapper.canModifyName(parentNode, msg.sender) ||
            !nameWrapper.allFusesBurned(parentNode, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL)){
            revert UnauthorizedAddress(parentNode);
        }

        // Set the pricing for subnames of the parent node.
        pricingData[parentNode].offerSubnames = _offerSubnames;
        pricingData[parentNode].renewalController = _renewalController;
        pricingData[parentNode].minRegistrationDuration = _minRegistrationDuration;
        pricingData[parentNode].maxRegistrationDuration = _maxRegistrationDuration;
        pricingData[parentNode].minChars = _minChars;
        pricingData[parentNode].maxChars = _maxChars;

        // The referrer cut can be a max of 50% (i.e. 5000)
        if (_referrerCut > 5000) {
            revert InvalidReferrerCut(_referrerCut);
        }

        pricingData[parentNode].referrerCut = _referrerCut;

    }

    /**
    * @notice Set the pricing for subname lengths.
    * @param parentNode The namehash of the parent name.
    * @param _charAmounts An array of amounst for each characer length.
    */  

     function setPricingForAllLengths(
        bytes32 parentNode,
        uint256[] calldata _charAmounts
    ) public {

        /**
         * Check to make sure the caller is authorised and the parentNode is wrapped in the 
         * Name Wrapper contract and the CANNOT_BURN_NAME and PARENT_CANNOT_CONTROL fuses are burned. 
         */

        if (!nameWrapper.canModifyName(parentNode, msg.sender) ||
            !nameWrapper.allFusesBurned(parentNode, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL)){
            revert UnauthorizedAddress(parentNode);
        }

        // Clear the old dynamic array out
        delete pricingData[parentNode].charAmounts;

        // Set the pricing for subnames of the parent node.
        pricingData[parentNode].charAmounts = _charAmounts;
        
    }

    /**
     * @notice Get the price for a single character length, e.g. three characters.
     * @param parentNode The namehash of the parent name.
     * @param charLength The character length, e.g. 3 would be for three characters. Use 0 for the default amount.
     */

    function getPriceDataForLength(bytes32 parentNode, uint256 charLength) public view returns (uint256){
        return pricingData[parentNode].charAmounts[charLength];
    }

    /**
     * @notice Set a price for a single character length, e.g. three characters.
     * @param parentNode The namehash of the parent name.
     * @param charLength The character length, e.g. 3 would be for three characters. Use 0 for the default amount.
     * @param charAmount The amount in USD/year for a character count, e.g. amount for three characters.
     */

    function updatePriceForCharLength(
        bytes32 parentNode,
        uint16 charLength,
        uint256 charAmount
    ) public {

        /**
         * Check to make sure the caller is authorised and the parentNode is wrapped in the 
         * Name Wrapper contract and the CANNOT_BURN_NAME and PARENT_CANNOT_CONTROL fuses are burned. 
         */

        if (!nameWrapper.canModifyName(parentNode, msg.sender) ||
            !nameWrapper.allFusesBurned(parentNode, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL)){
            revert UnauthorizedAddress(parentNode);
        }

        // Check that the charLength is not greater than the last index of the charAmounts array.
        if (charLength > pricingData[parentNode].charAmounts.length-1){
            revert CannotSetNewCharLengthAmounts();
        }
        pricingData[parentNode].charAmounts[charLength] = charAmount;
    }


    /**
     * @notice Adds a price for the next character length, e.g. three characters.
     * @param parentNode The namehash of the parent name.
     * @param charAmount The amount in USD/sec. (with 18 digits of precision) 
     * for a character count, e.g. amount for three characters.
     */

    function addNextPriceForCharLength(
        bytes32 parentNode,
        uint256 charAmount
    ) public {

        // Name Wrapper contract and the CANNOT_BURN_NAME and PARENT_CANNOT_CONTROL fuses are burned. 
        if (!nameWrapper.canModifyName(parentNode, msg.sender) ||
            !nameWrapper.allFusesBurned(parentNode, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL)){
            revert UnauthorizedAddress(parentNode);
        }

        pricingData[parentNode].charAmounts.push(charAmount);
    }

    /**
     * @notice Get the last length for a character length that has a price (can be 0), e.g. three characters.
     * @return The length of the last character length that was set.
     */

    function getLastCharIndex(bytes32 parentNode) public view returns (uint256) {
        return pricingData[parentNode].charAmounts.length - 1;
    }

    /**
     * @notice Allows for chaning the offer status of subnames to true or false.
     * @param parentNode The namehash of the parent name.
     * @param _offerSubnames A bool indicating the parent name owner is offering subnames.
     */

    function setOfferSubnames(
        bytes32 parentNode,
        bool _offerSubnames
    ) public {

        // Check to make sure the caller is authorised and the parentNode is wrapped in the 
        // Name Wrapper contract and the CANNOT_BURN_NAME and PARENT_CANNOT_CONTROL fuses are burned. 
        if (!nameWrapper.canModifyName(parentNode, msg.sender) ||
            !nameWrapper.allFusesBurned(parentNode, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL)){
            revert UnauthorizedAddress(parentNode);
        }

        pricingData[parentNode].offerSubnames = _offerSubnames;
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

        // The name is presumed to be available if it has not been registered
        // in the ENS registry and the parent is offering subnames. If the parent owner revokes
        // the authorization of this contract, then this function will still return true, but
        // registration will not be possible. 

        return validLength(parentNode, label) && 
            ens.owner(node) == address(0) &&
            pricingData[parentNode].offerSubnames;

    }

    /**
     * @notice Check to see if the name is available for registration. 
     * @param name The full name, in DNS format wherein the length precedes each label
     * and is terminted with a 0x0 byte, e.g. "cb.id" => [0x02,0x63,0x62,0x02,0x69,0x64,0x00].
     * @param owner The address that will own the name.
     * @param secret The secret to be used for the commitment.
     */
    function makeCommitment(
        bytes memory name,
        address owner,
        bytes32 secret
    ) public pure returns (bytes32) {

        return
            keccak256(
                abi.encode(
                    name,
                    owner,
                    secret
                )
            );
    }


    /**
     * @notice Registers a commitment hash for a name.
     * @param commitment The hash to register. 
     */

    function commit(bytes32 commitment) public {
        if (commitments[commitment] + maxCommitmentAge >= block.timestamp) {
            revert UnexpiredCommitmentExists(commitment);
        }
        commitments[commitment] = block.timestamp;
    }

    /**
     * @notice Register a name.
     * @param name The full name, in DNS format.
     * @param owner The address that will own the name.
     * @param referrer The address that referred the owner to the registrar.
     * @param duration The duration in seconds of the registration.
     * @param secret The secret to be used for the commitment.
     * @param resolver The address of the resolver to use.
     * @param fuses The fuses to be set on the name.
     */

    function register(
        bytes calldata name,
        address owner,
        address referrer,
        uint256 duration,
        bytes32 secret,
        address resolver,
        uint32 fuses
    ) public payable {

        bytes32 parentNode;
        bytes32 node;

        // Create a block to solve a stack too deep error.
        {
            (bytes32 labelhash, uint256 offset) = name.readLabel(0);
            parentNode = name.namehash(offset);
            node = _makeNode(parentNode, labelhash);
        }

        // Check to make sure the duration is between the min and max. 
        if (duration < pricingData[parentNode].minRegistrationDuration ||
            duration > pricingData[parentNode].maxRegistrationDuration){
            revert InvalidDuration(duration); 
        }


        // Create a block to solve a stack too deep error.
        {
            // Get the label from the _name. 
            (string memory label, ) = name.getFirstLabel();

            // Check to make sure the label is a valid length.
            if(!validLength(parentNode, label)){
                revert WrongNumberOfChars(label);
            }
        }

        // Check to make sure the owner is offering names.
        if (!pricingData[parentNode].offerSubnames){
            revert NameNotAvailable(name);
        }

        uint64 expiry =  uint64(block.timestamp + duration);

        // Create a block to solve a stack too deep error.
        {
            // Get the expiry of the parent. 
            (,, uint64 maxExpiry) = nameWrapper.getData(uint256(parentNode));

            // Set the expiry to the max expiry if the duration is too long.
            if (expiry > maxExpiry) {
                duration = maxExpiry - block.timestamp;
                expiry = maxExpiry;
            }
        }

        // Get the price for the duration.
        (uint256 price,) = rentPrice(name, duration);

        // Check to make sure the caller sent enough Eth.
        if (msg.value < price) {
            revert InsufficientValue();
        }

        // Create a block to solve a stack too deep error.
        {

            address parentOwner = nameWrapper.ownerOf(uint256(parentNode));

            // Calculate the amount to be given to the owner of the contract. 
            // We don't need a balance for the owner of the contract because the owner
            // can withdraw any funds in the contract minus total balances. 
            uint256 ownerAmount = price * ownerCut / 10000;

            uint256 referrerAmount;

            // If a referrer and referrer cut is specified then calculate the amount to be given to the referrer.
            if (referrer != address(0) && pricingData[parentNode].referrerCut > 0) {

                // Calculate the amount to be given to the referrer.
                referrerAmount = price * pricingData[parentNode].referrerCut / 10000;

                //Increase the referrer's balance.
                balances[referrer] += referrerAmount;
            }

            // Increase the owner of the parent name's balance minus the
            // referrer amount and the owner amount.
            balances[parentOwner] += price - referrerAmount - ownerAmount;

            //increment the total balances
            totalBalance += price - ownerAmount;        
        }

        _burnCommitment(
            duration,
            makeCommitment(
                name,
                owner,
                secret
            )
        );

        {
            // Get the label from the _name. 
            (string memory label, ) = name.getFirstLabel();

            // Create the subname in the L2 Name Wrapper.
            nameWrapper.setSubnodeRecord(
                parentNode,
                label,
                owner,
                address(pricingData[parentNode].renewalController), 
                resolver,
                0, // TTL
                fuses | CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL,
                expiry
            );
        }
        emit SubnameRegistered(
            name,
            node,
            owner,
            price,
            expiry
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
     * @notice Register a random number .unruggable name.
     * @param owner The address that will own the name.
     */ 
    function registerRandomUnruggable(
        address owner,
        uint256 maxLoops,
        uint8 numChars,
        uint256 salt
    ) public returns(bytes32 /* node */){

        // Make sure the owner is not the zero address.
        if (owner == address(0)){
            revert InvalidAddress(owner);
        }

        // increnmet the nonce to use for the name.
        unchecked {
            ++nonce;
        }

        // Get a label from the nonce, i.e. "1", "2", "3", etc.
        string memory label = Strings.toString(nonce);

        // Register the .unruggable name using the NameWrapper setSubnodeRecord function.
        bytes32 node = nameWrapper.setSubnodeRecord(
            UNRUGGABLE_TLD_NODE,
            label,
            owner,
            address(0), // We don't have an approved address.  
            address(0), // We don't have a renewal controller.
            0, // TTL
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL,
            MAX_EXPIRY
        );

        emit UnruggableRegistered(string(label));

        return node;
    }


    function registerUnruggable(
        string memory label,
        address owner
    ) public returns(bytes32 /* node */){

        // Register the .unruggable name using the NameWrapper setSubnodeRecord function.
        bytes32 node = nameWrapper.setSubnodeRecord(
            UNRUGGABLE_TLD_NODE,
            label,
            owner,
            address(0), // We don't have an approved address.  
            address(0), // We don't have a renewal controller.
            0, // TTL
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL,
            MAX_EXPIRY
        );

        emit UnruggableRegistered(label);

        return node;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return
            interfaceId == type(ISubnameRegistrar).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* Internal functions */

    /**
    * @dev Converts USD to Wei. 
    * @param amount The amount of USD to be converted to Wei.
    * @return The amount of Wei.
    */
    function _usdToWei(uint256 amount) internal view returns (uint256) {

        // Get the price of ETH in USD (with 8 digits of precision) from the oracle.
        uint256 ethPrice = uint256(usdOracle.latestAnswer());

        // Convert the amount of USD (with 18 digits of precision) to Wei.
        return (amount * 1e8) / ethPrice;
    }

    /**
     * @notice Checks to see if the commitment is valid and burns it.
     * @param duration The duration of the registration.
     * @param commitment The commitment to be checked.
     */

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
    }

    function _makeNode(bytes32 node, bytes32 labelhash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(node, labelhash));
    }
}