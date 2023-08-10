//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {INameWrapperUpgrade} from "ens-contracts/wrapper/INameWrapperUpgrade.sol";
import {StringUtils} from "ens-contracts/ethregistrar/StringUtils.sol";
import {ISubnameWrapper} from "contracts/subwrapper/interfaces/ISubnameWrapper.sol";
import {ISubnameWrapperUpgrade} from "contracts/subwrapper/interfaces/ISubnameWrapperUpgrade.sol";
import {Balances} from "./Balances.sol";
import {BytesUtilsSub} from "./BytesUtilsSub.sol";
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {IRenewalController} from "contracts/subwrapper/interfaces/IRenewalController.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20Recoverable} from "ens-contracts/utils/ERC20Recoverable.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

error InsufficientValue();
error UnauthorizedAddress(bytes32 node);

abstract contract RenewalControllerBase is 
    IRenewalController,
    ERC165,
    Ownable,
    Balances,
    ERC20Recoverable
    {

    using Address for address payable;

    event NameWrapperVersionUpdated();
    event SubnameWrapperVersionUpdated();

    using StringUtils for *;
    using BytesUtilsSub for bytes;

    // The NameWrapper and SubnameWrapper can be upgraded. 
    address[] public nameWrappers = new address[](1);
    address[] public subnameWrappers = new address[](1);

    constructor(
        INameWrapper _nameWrapper,
        ISubnameWrapper _subnameWrapper
    ) {

        nameWrappers[0] = address(_nameWrapper);

        // The contract that wraps the subnames.
        subnameWrappers[0] = address(_subnameWrapper);
    }

    /**
     * @notice If the NameWrapper smart contract is upgraded, add the new version.
     * @param _nameWrapper The next version of the NameWrapper
     */

    function addNextNameWrapperVersion(
        INameWrapperUpgrade _nameWrapper
    ) public onlyOwner {

        nameWrappers.push(address(_nameWrapper));

        emit NameWrapperVersionUpdated();
    }

    /**
     * @notice If the NameWrapper smart contract is upgraded, add the new version.
     * @param _subnameWrapper The next version of the NameWrapper
     */

    function addNextSubnameWrapperVersion(
        ISubnameWrapperUpgrade _subnameWrapper
    ) public onlyOwner {

        subnameWrappers.push(address(_subnameWrapper));
        
        emit SubnameWrapperVersionUpdated();
    }

    /**
    * @dev Function to renew a name for a specified duration. 
    * @param name The name to be renewed in DNS format.
    * @param duration The duration for which the name should be renewed in years.
    */

    function renew(bytes calldata name, address referrer, uint256 duration)
        external
        payable
    {        

        // Renew with the latest version of the NameWrapper and SubnameWrapper contracts.
        renewWithVersions(
            nameWrappers.length-1,    
            subnameWrappers.length-1,
            name,
            referrer,
            duration);
    }

    /**
    * @notice Function to renew a name for a specified duration. 
    * @dev This function is allows for the upgradeing of the NameWrapper and SubnameWrapper contracts.
    * It is not possible to know what the interface of the upgarded contracts will be, so we assume that
    * they will be compatible with the current version of the contracts.
    * @param nameWrapperV The version of the NameWrapper.
    * @param subnameWrapperV The version of the SubnameWrapper. 
    * @param name The name to be renewed in DNS format.
    * @param duration The duration for which the name should be renewed in years.
    */

    function renewWithVersions(
        uint256 nameWrapperV,
        uint256 subnameWrapperV, 
        bytes calldata name, 
        address referrer, 
        uint256 duration
        )
        public
        payable
    {        
        
        bytes32 parentNode;
        bytes32 node;
        bytes32 labelhash;

        // Create a block to solve a stack too deep error.
        { 
            uint256 offset;
            (labelhash, offset) = name.readLabel(0);
            parentNode = name.namehash(offset);
            node = _makeNode(parentNode, labelhash);
        }

        // Get the owners of the name and the parent name.
        address parentOwner = INameWrapper(nameWrappers[nameWrapperV]).ownerOf(uint256(parentNode));
        address nodeOwner = ISubnameWrapper(subnameWrappers[subnameWrapperV]).ownerOf(uint256(node));

        // Check to make sure the caller (msg.sender) is authorised to renew the name.
        if( msg.sender != nodeOwner && !ISubnameWrapper(subnameWrappers[subnameWrapperV]).isApprovedForAll(nodeOwner, msg.sender)){
            revert UnauthorizedAddress(node);
        }

        uint64 expiry;

        // Create a block to solve a stack too deep error.
        {
            // Get the previous expiry. 
            (,, uint64 nodeExpiry) = INameWrapper(nameWrappers[nameWrapperV]).getData(uint256(node));

            // Check to see if the duration is too long and
            // if it is set the duration.
            (,, uint64 parentExpiry) = INameWrapper(nameWrappers[nameWrapperV]).getData(uint256(parentNode));
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

            // Calculate the amount to be given to the owner of the contract. 
            // We don't need a balance for the owner of the contract because the owner
            // can withdraw any funds in the contract minus total balances. 
            uint256 ownerAmount = priceEth * ownerCut / 10000;


            // Increase the owner of the parent name's balance minus the
            // referrer amount and the owner amount.
            balances[parentOwner] += priceEth - referrerAmount - ownerAmount;

            // Increase the total balances
            totalBalance += priceEth - ownerAmount;
        }

        ISubnameWrapper(subnameWrappers[subnameWrapperV]).extendExpiry(
            parentNode,
            labelhash,
            expiry
        );

        emit NameRenewed(name, priceEth, expiry);

        // If the caller paid too much refund the amount overpaid. 
        if (msg.value > priceEth) {
            payable(msg.sender).sendValue(msg.value - priceEth);
        }

    }

    /**
    * @notice Returns the price to rent a subdomain for a given duration.
    * @param name The name of the subdomain.
    * @param duration The duration of the rental. 
    */ 

    function rentPrice(bytes calldata name, uint256 duration)
        public
        view
        virtual
        returns (uint256, uint256);

    /**
    * @param interfaceId The interface identifier, as specified in ERC-165.
    * @return `true` if the contract implements `interfaceID`
    */ 

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IRenewalController).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns the node for a namehash and labelhash.
     * @param parentNode The namehash of the parent node.
     * @param labelhash The labelhash of the label.
     * @return The node for the namehash and labelhash.
     */
    function _makeNode(bytes32 parentNode, bytes32 labelhash)
        private
        pure
        returns (bytes32)
    {
        return keccak256(abi.encodePacked(parentNode, labelhash));
    }
}