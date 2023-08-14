//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {Address} from "openzeppelin-contracts/contracts/utils/Address.sol";

abstract contract Balances is Ownable {

    using Address for address payable;

    event OwnerCutSet(uint256 indexed ownerCut);
    event ReferrerCutSet(uint256 indexed referrerCut);
    event AddressWithdrew(address indexed _address, uint256 indexed amount);

    // A mapping to store the balance of each referrer.
    mapping (address => uint256) public balances;

    // A mapping to store the referrer cut percentage for each referrer.
    mapping (address => uint256) public referrerCuts;

    // A variable to store the total balance of all referrers.
    uint256 public totalBalance;

    // The cut taken by the owner of the contract.
    uint256 public ownerCut;

    constructor() {
        // Default cut is 2% (200/10000).
        ownerCut = 200;  
    }
        
    /**
     * @notice A function to allow referrers, name owners, or the contract owner to withdraw.
     */

    function withdraw() public {

        //get the address of the sender
        address payable sender = payable(msg.sender);
        
        // Withdraw the owner's balance if the sender is the contract owner.
        if(sender == owner()) { 

            // Calculate the amount that can be withdrawn.
            uint256 ownerAmount = address(this).balance - totalBalance;

            require(ownerAmount > 0, "Owner balance is 0");
            
            emit AddressWithdrew(sender, ownerAmount);

            // Send the amount to the contract owner's address.
            sender.sendValue(ownerAmount);

        } else { 

            // Require that the senders balance is greater than 0.
            require(balances[sender] > 0, "Address's balance is 0");

            // Calculate the amount that the sender can withdraw
            uint256 amount = balances[sender];

            // Set the sender balance to 0.
            balances[sender] = 0;

            // Decrease the total referrer balance.
            totalBalance -= amount;

            emit AddressWithdrew(sender, amount);

            // Send the amount to the address.
            sender.sendValue(amount);
        }
    }

    /**
    * @notice A function to set the cut for the owner of the contract.
    * @param _ownerCut The cut for the owner of the contract.
    */

    function setOwnerCut(uint256 _ownerCut) public {
        require(msg.sender == owner(), "Only the owner can set the cut");
        require(_ownerCut <= 500, "Owner cut cannot be more than 5%");
        ownerCut = _ownerCut;
        emit OwnerCutSet(_ownerCut);
    }

    /**
     * @notice A function to set the referrer cut percentage for a specific referrer.
     * @param _referrerCut The percentage cut given to the referrer (0-10%).
     */

    function setReferrerCut(uint _referrerCut) public {
        require(_referrerCut <= 1000, "Referrer cut cannot be more than 10%");
        referrerCuts[msg.sender] = _referrerCut;
        emit ReferrerCutSet(_referrerCut);
    } 
}