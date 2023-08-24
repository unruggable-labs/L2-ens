//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ERC1155Fuse, IERC1155MetadataURI} from "ens-contracts/wrapper/ERC1155Fuse.sol";
import {Controllable} from "ens-contracts/wrapper/Controllable.sol";
import {IL2NameWrapper, CANNOT_BURN_NAME, CANNOT_BURN_FUSES, CANNOT_TRANSFER, CANNOT_SET_RESOLVER, CANNOT_SET_TTL, CANNOT_CREATE_SUBDOMAIN, CANNOT_APPROVE, PARENT_CANNOT_CONTROL, CAN_DO_EVERYTHING, IS_DOT_ETH, CAN_EXTEND_EXPIRY, PARENT_CONTROLLED_FUSES, USER_SETTABLE_FUSES} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapperUpgrade} from "ens-contracts/wrapper/INameWrapperUpgrade.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {ENS} from "ens-contracts/registry/ENS.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {ERC20Recoverable} from "ens-contracts/utils/ERC20Recoverable.sol";
//import foundry console logging.
import "forge-std/console.sol";

error Unauthorised(bytes32 node, address addr);
error IncompatibleParent();
error IncorrectTokenType();
error LabelMismatch(bytes32 labelHash, bytes32 expectedLabelhash);
error LabelTooShort();
error LabelTooLong(string label);
error IncorrectTargetOwner(address owner);
error CannotUpgrade();
error OperationProhibited(bytes32 node);
error NameIsNotWrapped();
error NameIsStillExpired();

contract L2NameWrapper is
    Ownable,
    ERC1155Fuse,
    IL2NameWrapper,
    Controllable,
    ERC20Recoverable
{
    
    // Use the BytesUtils library for bytes, e.g. name.namehash(0). 
    using BytesUtils for bytes;

    // The ENS registry
    ENS public immutable ens;

    // The metadata service used to get the metadata uri of each name. 
    IMetadataService public metadataService;

    //The L2NameWrapper is upgradable. If an upgrade contract is specified, name owners can choose to upgrade.
    INameWrapperUpgrade public upgradeContract;

    /** 
     * In the ENS registry only the namehash of each name is stored and not the actual name.
     * To make it easier to retrieve the human readable name, saved in bytes using the DNS format,
     * we store it here. 
     */

    mapping(bytes32 => bytes) public names;

    // Make a struct to hold node data. We need this to avoid a stack too deep error.
    struct NodeData {
        string label;
        address owner;
        address nodeOwner;
        uint32 nodeFuses;
        uint64 nodeExpiry;
        address parentOwner;
        uint32 parentFuses;
        uint64 parentExpiry;
    }

    /* Constants */

    uint64 private constant GRACE_PERIOD = 90 days;
    bytes32 private constant ETH_NODE = 0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_LABELHASH = 0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 private constant ROOT_NODE = 0x0000000000000000000000000000000000000000000000000000000000000000;
    uint64 private constant MAX_EXPIRY = type(uint64).max;

    constructor(
        ENS _ens,
        IMetadataService _metadataService
    ) {

        // Setup the registry and metadata service.
        ens = _ens;
        metadataService = _metadataService;

        // Burn PARENT_CANNOT_CONTROL and CANNOT_BURN_NAME fuses for ROOT_NODE and ETH_NODE and set expiry to max.
        _setData(
            uint256(ETH_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME),
            MAX_EXPIRY
        );
        _setData(
            uint256(ROOT_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME),
            MAX_EXPIRY
        );

        // Set the names of both the root and eth node.
        names[ROOT_NODE] = "\x00";
        names[ETH_NODE] = "\x03eth\x00";
    }

    /**
     * @notice Provides support for ERC-165, allowing checking for interfaces. 
     * @param interfaceId The interface id of the name.
     * @return The interface id. 
     */

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC1155Fuse, IL2NameWrapper) returns (bool) {
        return
            interfaceId == type(IL2NameWrapper).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /* ERC1155 Fuse */

    /**
     * @notice Gets the owner of a name
     * @param id Label as a string of the .eth domain to wrap
     * @return owner The owner of the name
     */

    function ownerOf(
        uint256 id
    ) public view override(ERC1155Fuse, IL2NameWrapper) returns (address owner) {
        return super.ownerOf(id);
    }

    /**
     * @notice Gets the owner of a name
     * @param id Namehash of the name
     * @return operator Approved operator of a name
     */

    function getApproved(
        uint256 id
    )
        public
        view
        override(ERC1155Fuse, IL2NameWrapper)
        returns (address operator)
    {
        address owner = ownerOf(id);

        // Check to see if the owner is the 0 address.
        if (owner == address(0)) {
            return address(0);
        }

        // Return the approved address.
        return super.getApproved(id);
    }

    /**
     * @notice Approves an address for a name
     * @dev Approved addresses are restricted to being able to renew the name or subnames of the name.
     *      This is particularly useful for creating renewal controllers, contracts tasked with renewing
     *      names for example for a fee.
     * @param to address to approve
     * @param tokenId name to approve
     */

    function approve(
        address to,
        uint256 tokenId
    ) public override(ERC1155Fuse, IL2NameWrapper) {

        // Get the data from the name. 
        (, uint32 fuses, ) = getData(tokenId);

        // Make sure CANNOT_APPROVE is not burned.
        if (fuses & CANNOT_APPROVE == CANNOT_APPROVE) {
            revert OperationProhibited(bytes32(tokenId));
        }

        // Approve the address.
        super.approve(to, tokenId);
    }

    /**
     * @notice Gets the data for a name
     * @dev If the name is expired, the fuses are set to 0. If the name is emancipated and 
     *      expired, both the fuses and the owner are set to 0.
     * @param id Namehash of the name
     * @return owner The owner of the name.
     * @return fuses The fuses of the name.
     * @return expiry The expiry of the name. 
     */

    function getData(
        uint256 id
    )
        public
        view
        override(ERC1155Fuse, IL2NameWrapper)
        returns (address owner, uint32 fuses, uint64 expiry)
    {

        // Get the data from the name.
        (owner, fuses, expiry) = super.getData(id);

        // Check to see if the name is expired.
        if (expiry < block.timestamp) {

            /** 
             * If the name is emancipated, set the owner to 0.
             * This is necessary so that expired emanciapted names cannot be transferred,
             * which could include selling an expired name in a marketplace.
             */

            if (fuses & PARENT_CANNOT_CONTROL == PARENT_CANNOT_CONTROL) {
                owner = address(0);
            }

            // The name is expired, so set the fuses to 0.
            fuses = 0;
        }
    }

    /* Metadata Service */

    /**
     * @notice Set the metadata service. Only the owner can do this
     * @param _metadataService The new metadata service
     */

    function setMetadataService(
        IMetadataService _metadataService
    ) public onlyOwner {
        metadataService = _metadataService;
    }

    /**
     * @notice Get the metadata uri
     * @param tokenId The id of the token
     * @return string uri of the metadata service
     */

    function uri(
        uint256 tokenId
    )
        public
        view
        override(IL2NameWrapper, IERC1155MetadataURI)
        returns (string memory)
    {
        return metadataService.uri(tokenId);
    }

    /* Name Wrapper */

    /**
     * @notice Set the address of the upgradeContract of the contract. only admin can do this
     * @dev The default value of upgradeContract is the 0 address. Use the 0 address at any time
     * to make the contract not upgradable.
     * @param _upgradeAddress address of an upgraded contract
     */

    function setUpgradeContract(
        INameWrapperUpgrade _upgradeAddress
    ) public onlyOwner {
        upgradeContract = _upgradeAddress;
    }

    /**
     * @notice Checks if msg.sender is the owner or operator of the owner of a name.
     * @param node The namehash of the name to check.
     */

    modifier onlyTokenOwner(bytes32 node) {
        if (!canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        _;
    }

    /**
     * @notice Checks if the address is the owner or operator of the name.
     * @param node The namehash of the name to check.
     * @param addr The address to check for permissions.
     * @return Whether or not the address is the owner or an operator of the name.
     */

    function canModifyName(
        bytes32 node,
        address addr
    ) public view returns (bool) {

        // Get the data from the node.
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));

        return
            // Check if the address is the owner or an approved-for-all address.
            (owner == addr || isApprovedForAll(owner, addr)) &&

            // Also if the name is a .eth 2LD, e.g, vitalik.eth, make sure that it is not in the grace period.
            !_isETH2LDInGracePeriod(fuses, expiry);
    }

    /**
     * @dev Registers a new .eth second-level domain and wraps it.
     *      Only callable by authorised controllers.
     * @param label The label to register (Eg, 'foo' for 'foo.eth').
     * @param wrappedOwner The owner of the wrapped name.
     * @param approved The address to approve for the name.
     * @param duration The duration, in seconds, to register the name for.
     * @param resolver The resolver address to set on the ENS registry (optional).
     * @param ownerControlledFuses Initial owner-controlled fuses to set
     * @return expiry The expiry date of the new name, in seconds since the Unix epoch.
     */

    function registerAndWrapEth2LD(
        string calldata label,
        address wrappedOwner,
        address approved,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external onlyController returns (uint64 expiry) {

        // Create a labelhash from the label.
        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(ETH_NODE, labelhash);

        // Make sure the .eth 2LD is available for registration.
        if (ownerOf(uint256(node)) != address(0)) {
            revert OperationProhibited(node);
        }

        // Save the subname in the registry.
        ens.setSubnodeRecord(ETH_NODE, labelhash, address(this), address(0), 0);

        // Set the expiry to the duration plus the current time plus the grace period.
        expiry = uint64(block.timestamp) + uint64(duration) + GRACE_PERIOD;

        // Wrap the name.
        _wrapETH2LD(
            label,
            wrappedOwner,
            approved,
            ownerControlledFuses,
            expiry,
            resolver
        );
    }

    /**
     * @notice Renews a .eth second-level domain.
     * @dev Only callable by authorised controllers.
     * @param labelhash The hash of the label to register (eg, `keccak256('foo')`, for 'foo.eth').
     * @param duration The number of seconds to renew the name for.
     * @return expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function renewEth2LD(
        bytes32 labelhash,
        uint256 duration
    ) external onlyController returns (uint64 expiry) {

        // Make the node from the labelhash.
        bytes32 node = _makeNode(ETH_NODE, labelhash);

        // Make sure the name is wrapped before renewing it.
        if (ownerOf(uint256(node)) == address(0)) {
            revert NameIsNotWrapped();
        }

        // Get the owner fuses and expiry of the node.
        (address owner, uint32 fuses, uint64 oldExpiry) = getData(uint256(node));

        // Set expiry in Wrapper
        expiry = uint64(oldExpiry + duration);

        // Set the data in the wrapper.
        _setData(node, owner, fuses, expiry);

        return expiry;
    }
    
    /**
     * @notice Sets fuses of a name
     * @param node Namehash of the name
     * @param ownerControlledFuses Owner-controlled fuses to burn
     * @return Old fuses
     */

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    )
        public
        onlyTokenOwner(node)
        operationAllowed(node, CANNOT_BURN_FUSES)
        returns (uint32)
    {
        // Get the data from the node.
        (address owner, uint32 oldFuses, uint64 expiry) = getData(uint256(node));

        // Burn the new fuses into the old fuses. Keep the owner and expiry the same. 
        _setFuses(node, owner, ownerControlledFuses | oldFuses, expiry, expiry);

        return oldFuses;
    }

    /**
     * @notice A function to extend the expiry of a name.
     * @param parentNode The parrent namehash of the name, e.g. vitalik.xyz would be namehash('xyz').
     * @param labelhash The labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik').
     * @param expiry The time when the name will expire in seconds since the Unix epoch.
     * @return The new expiry.
     */

    function extendExpiry(
        bytes32 parentNode,
        bytes32 labelhash,
        uint64 expiry
    ) public returns (uint64) {
        bytes32 node = _makeNode(parentNode, labelhash);

        // Make sure the name is wrapped.
        if (ownerOf(uint256(node)) == address(0)) {
            revert NameIsNotWrapped();
        }

        // Get the data from the node and parent node. 
        (address owner, uint32 fuses, uint64 oldExpiry) = getData(uint256(node));
        (address parentOwner, uint32 parentFuses, uint64 parentExpiry) = getData(uint256(parentNode));

        /**
         * Only allow the owner of the parent name, owner of the name with CAN_EXTEND_EXPIRY,
         * or the approved contract on the node to extend the expiry of the name. 
         */

        // If the caller is the parent name make sure it has the permissions to extend the expiry.
        if (!_canModifyName_WithData(msg.sender, parentOwner, parentFuses, parentExpiry) && 

            /** 
             * If the caller is the approved address of the parent name, allow it to extend the expiry.   
             * This allows for parent level renewal controllers to be assigned to renew names on bahalf
             * of parent name owners. Parent level renewal controllers can be used in combination with 
             * a registrar to create a system for renting subnames. A single parent level renewal controller
             * can be for situations where the policies for subname rentals are mostly uniform, for exmaple in
             * the case of a domain registration system where subnames are all subnames can be renwed for a 
             * flat fee, such as $5 per year. Also we check to make sure the parent level name is not in the
             * in the grace period. 
             */

            !(msg.sender == getApproved(uint256(parentNode)) && !_isETH2LDInGracePeriod(parentFuses, parentExpiry)) &&

            // If the caller is the owner of the name make sure CAN_EXTEND_EXPIRY has been burned.
            !(_canModifyName_WithData(msg.sender, owner, fuses, oldExpiry) && fuses & CAN_EXTEND_EXPIRY != 0) &&

            /** 
             * If the caller is the approved address of the name, allow it to extend the expiry.
             * This ability was introduced into this contract in order to allow for subname level
             * renewall controllers. Previously it was only possible to allow for parent level renewal
             * controllers. Subname level renewal controllers are more flexible, allowing a different 
             * renewal controller to be used for each subname. Another significan advantage is that
             * it is not necessary to buren CANNOT_APPROVE on the parent level name, and instead
             * CANNOT_APPROVE can be burned on the subname level name. This is important because 
             * burning a permanent fuse on the parent level name cannot be undone, and is likely to
             * reduce the utilty and value of the parent level name, as well as potentially lock the
             * parent level name into a particular technology, which can't be upgraded in the future.  
             */

            !(msg.sender == getApproved(uint256(node)))) {

            //If the caller is none of these then revert.
            revert Unauthorised(node, msg.sender);
        }

        // The max expiry is set to the expiry of the parent.
        (, , uint64 maxExpiry) = getData(uint256(parentNode));

        // Make sure the expiry is between the old expiry and the parent expiry.
        expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);

        // Set the owner, fues and expiry of the name.
        _setData(node, owner, fuses, expiry);

        emit ExpiryExtended(node, expiry);

        // Return the new expiry.
        return expiry;
    }

    /**
     * @notice Upgrades a domain of any kind. Could be a .eth name vitalik.eth, 
     *         a DNSSEC name vitalik.xyz, or a subdomain.
     * @dev Can be called by the owner or an authorised caller
     * @param name The name to upgrade, in DNS format
     * @param extraData Extra data to pass to the upgrade contract
     */

    function upgrade(bytes calldata name, bytes calldata extraData) public {

        // Make the node from the name.
        bytes32 node = name.namehash(0);

        // Get the data from the node. 
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));

        // Make sure the upgrade contract is set.
        if (address(upgradeContract) == address(0)) {
            revert CannotUpgrade();
        }

        /**
         * Make sure the caller is the owner or an authorised caller, 
         * and not a 2LD, e.g. vitalik.eth., in the grace period.
         */

        if (!_canModifyName_WithData(msg.sender, owner, fuses, expiry)){
            revert Unauthorised(node, msg.sender);
        }

        // Get the approved address.
        address approved = getApproved(uint256(node));

        // Change the owner in the registry to the upgrade contract.
        ens.setOwner(node, address(upgradeContract));

        // Burn the name in the wrapper.
        _burn(uint256(node));

        // Call the upgrade contract to wrap the name.
        upgradeContract.wrapFromUpgrade(
            name,
            owner,
            fuses,
            expiry,
            approved,
            extraData
        );
    }

    /** 
    /* @notice Sets fuses of a name that you own the parent of
     * @param parentNode Parent namehash of the name e.g. vitalik.xyz would be namehash('xyz')
     * @param labelhash Labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik')
     * @param fuses Fuses to burn
     * @param expiry When the name will expire in seconds since the Unix epoch
     */

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) public {
        bytes32 node = _makeNode(parentNode, labelhash);

        // Make sure the fuses being set do NOT include IS_DOT_ETH.
        _fusesAreSettable(node, fuses);

        // Get the data from the node.
        (address nodeOwner, uint32 nodeFuses, uint64 nodeExpiry) = getData(uint256(node));

        // Get the data from the parent node.
        (address parentOwner, uint32 parentFuses, uint64 parentExpiry) = getData(uint256(parentNode));

        // Make sure the name is wrapped.
        if (ownerOf(uint256(node)) == address(0)) {
            revert NameIsNotWrapped();
        }

        // If setting fuses on a TLD, e.g. xyz, make sure the caller is the owner or an authorised caller.
        if (parentNode == ROOT_NODE) {
            if (!_canModifyName_WithData(msg.sender, nodeOwner, nodeFuses, nodeExpiry)) {
                revert Unauthorised(node, msg.sender);
            }
        } else {

            /** 
             * If setting fuses on a subdomain, make sure the caller is the 
             * owner or an authorised caller of the parent.
             */

            if (!_canModifyName_WithData(msg.sender, parentOwner, parentFuses, parentExpiry)) {
                revert Unauthorised(parentNode, msg.sender);
            }
        }

        // Make sure the expiry is between the old expiry and the parent expiry.
        expiry = _normaliseExpiry(expiry, nodeExpiry, parentExpiry);

        // If we are setting fuses on the name make sure PARENT_CANNOT_CONTROL has not been burned.
        if (fuses != 0 && nodeFuses & PARENT_CANNOT_CONTROL != 0) {

            revert OperationProhibited(node);
        }

        // Burn the new fuses into the old fuses. Keep the owner and expiry the same.
        fuses |= nodeFuses;

        // Set the fuses. 
        _setFuses(node, nodeOwner, fuses, nodeExpiry, expiry);

    }

    /**
     * @notice Sets the subdomain owner in the registry and then wraps the subdomain
     * @param parentNode Parent namehash of the subdomain
     * @param label Label of the subdomain as a string
     * @param owner New owner in the wrapper
     * @param approved Address to approve for the name
     * @param fuses Initial fuses for the wrapped subdomain
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return node Namehash of the subdomain
     */

    function setSubnodeOwner(
        bytes32 parentNode,
        string calldata label,
        address owner,
        address approved,
        uint32 fuses,
        uint64 expiry
    ) public onlyTokenOwner(parentNode) returns (bytes32 node) {

        // Make the node from the label.
        bytes32 labelhash = keccak256(bytes(label));
        node = _makeNode(parentNode, labelhash);

        // Make an instance of the struct to hold the data of the node and parent node.
        NodeData memory nodeData;

        // Store the input parameters in the struct, we do this to solve a stack too deep issue. 
        nodeData.label = label;
        nodeData.owner = owner;

        // Get the node and parent node data. 
        (nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry) = getData(uint256(node));
        (, nodeData.parentFuses, nodeData.parentExpiry) = getData(uint256(parentNode));

        // Cecks the parent to make sure it has the persmissions it needs to create or update a subdomain. 
        _canCallSetSubnode_WithData(nodeData.parentFuses, node, nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry);

        // Make sure the expiry is between the old expiry and the parent expiry.
        expiry = _normaliseExpiry(expiry, nodeData.nodeExpiry, nodeData.parentExpiry);

        // Checks to make sure the IS_DOT_ETH fuse is not burnt in the fuses. 
        _fusesAreSettable(node, fuses);

        // If the name has not been set before, save the label.
        bytes memory name = _saveLabel(parentNode, node, label);

        // Check to see if the name is wrapped.
         if (ownerOf(uint256(node)) == address(0)) {

            // The name is NOT wrapped.

            // Set the subnode owner in the registry.
            ens.setSubnodeOwner(parentNode, labelhash, address(this));

            // Wrap the name in the wrapper.
            _wrap(node, name, owner, fuses, expiry);

        } else {

            // The name is wrapped, so update it.
            _updateName(parentNode, node, nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry, nodeData.label, nodeData.owner, fuses, expiry);
        }

        // Add an approved address
        if (approved != address(0)) {
            super._approve(approved, uint256(node));
        }
    }

    /**
     * @notice Sets the subdomain owner in the registry with records and then wraps the subdomain
     * @param parentNode parent namehash of the subdomain
     * @param label label of the subdomain as a string
     * @param owner new owner in the wrapper
     * @param approved address to approve for the name
     * @param resolver resolver contract in the registry
     * @param ttl ttl in the registry
     * @param fuses initial fuses for the wrapped subdomain
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return node Namehash of the subdomain
     */

    function setSubnodeRecord(
        bytes32 parentNode,
        string memory label,
        address owner,
        address approved,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) public onlyTokenOwner(parentNode) returns (bytes32 node) {
        bytes32 labelhash = keccak256(bytes(label));
        node = _makeNode(parentNode, labelhash);

        // Make an instance of the struct to hold the data of the node and parent node.
        NodeData memory nodeData;

        // Store the input parameters in the struct, we do this to solve a stack too deep issue. 
        nodeData.label = label;
        nodeData.owner = owner;

        // Get the data from the node and the parent node and save it in the struct. 
        (nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry) = getData(uint256(node));
        (nodeData.parentOwner, nodeData.parentFuses, nodeData.parentExpiry) = getData(uint256(parentNode));

        // Cecks the parent to make sure it has the persmissions it needs to create or update a subdomain. 
        _canCallSetSubnode_WithData(nodeData.parentFuses, node, nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry);

        // Make sure the expiry is between the old expiry and the parent expiry.
        expiry = _normaliseExpiry(expiry, nodeData.nodeExpiry, nodeData.parentExpiry);

        // Checks to make sure the IS_DOT_ETH fuse is not burnt in the fuses. 
        _fusesAreSettable(node, fuses);

        // If the name has not been set before, save the label.
        bytes memory name = _saveLabel(parentNode, node, label);

        // Check to see if the name is wrapped.
        if (ownerOf(uint256(node)) == address(0)) {
            
            // The name is NOT wrappped. 

            // Set the subnode record in the registry.
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );

            // Wrap the name in the wrapper.
            _wrap(node, name, owner, fuses, expiry);

        } else {

            // The name is wrapped. 
            
            //Update the name in the registry.
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );

            // Update the name in the wrapper.
            _updateName(parentNode, node, nodeData.nodeOwner, nodeData.nodeFuses, nodeData.nodeExpiry, nodeData.label, nodeData.owner, fuses, expiry);
        }

        // Check if there is an approved address and if so add it.
        if (approved != address(0)) {
            super._approve(approved, uint256(node));
        }
    }

    /**
     * @notice Sets records for the name in the ENS Registry
     * @param node Namehash of the name to set a record for
     * @param owner New owner in the registry
     * @param resolver Resolver contract
     * @param ttl Time to live in the registry
     */

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    )
        public
        onlyTokenOwner(node)
        operationAllowed(
            node,
            CANNOT_TRANSFER | CANNOT_SET_RESOLVER | CANNOT_SET_TTL
        )
    {
        // Set the record in the registry.
        ens.setRecord(node, address(this), resolver, ttl);

        // Check to see if the owner is being set to the 0 address, i.e. is being burned. 
        if (owner == address(0)) {

            // Get the data of the name.
            (, uint32 fuses, ) = getData(uint256(node));

            // Check to make sure the name is NOT a .eth 2LD, e.g. vitalik.eth.
            if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
                revert IncorrectTargetOwner(owner);
            }

            // Burn the name both in the wrapper and the registry.
            _burnAll(node);

        } else {

            // The name is NOT being set to the 0 address.

            // Get the current owner of the name. 
            address oldOwner = ownerOf(uint256(node));

            // Transfer the name to the new owner.
            _transfer(oldOwner, owner, uint256(node), 1, "");
        }
    }

    /**
     * @notice Sets resolver contract in the registry
     * @param node namehash of the name
     * @param resolver the resolver contract
     */

    function setResolver(
        bytes32 node,
        address resolver
    ) public onlyTokenOwner(node) operationAllowed(node, CANNOT_SET_RESOLVER) {
        ens.setResolver(node, resolver);
    }

    /**
     * @notice Sets TTL in the registry
     * @param node Namehash of the name
     * @param ttl TTL in the registry
     */

    function setTTL(
        bytes32 node,
        uint64 ttl
    ) public onlyTokenOwner(node) operationAllowed(node, CANNOT_SET_TTL) {
        ens.setTTL(node, ttl);
    }

    /**
     * @dev Checks to see if any of the fuses are burned, and if so, reverts.
     * @param node The namehash of the name to check fuses on.
     * @param fuseMask A bitmask of fuses that must not be burned.
     */

    modifier operationAllowed(bytes32 node, uint32 fuseMask) {
        (, uint32 fuses, ) = getData(uint256(node));

        // Check to see if any of the fuses are burned specified by the fuseMask.
        if (fuses & fuseMask != 0) {
            revert OperationProhibited(node);
        }

        _;
    }

    /**
     * @notice Check whether a name can call setSubnodeOwner/setSubnodeRecord
     * @dev Checks both CANNOT_CREATE_SUBDOMAIN and PARENT_CANNOT_CONTROL and whether not they have been burnt
     *      and checks whether the owner of the subdomain is 0x0 for creating or already exists for
     *      replacing a subdomain. If either conditions are true, then it is possible to call
     *      setSubnodeOwner
     * @param parentNode Namehash of the parent name to check
     * @param node Namehash of the subname to check
     */

    function _canCallSetSubnode(
        bytes32 parentNode,
        bytes32 node
    ) internal view {
        (
            address nodeOwner,
            uint32 nodeFuses,
            uint64 nodeExpiry
        ) = getData(uint256(node));

        // Check if the name is expired and the owner is the 0 address. 
        if ((nodeExpiry < block.timestamp) && (nodeOwner == address(0) || ens.owner(node) == address(0))) {
            
            // The name is expired.

            (, uint32 parentFuses, ) = getData(uint256(parentNode));

            // Check to see if the parent has CANNOT_CREATE_SUBDOMAIN burnt.
            if (parentFuses & CANNOT_CREATE_SUBDOMAIN != 0) {
                revert OperationProhibited(node);
            }
        } else {

            // The name is NOT expired.  

            // Check if the node has PARENT_CANNOT_CONTROL set.
            if (nodeFuses & PARENT_CANNOT_CONTROL != 0) {
                revert OperationProhibited(node);
            }
        }
    }

    /**
     * @notice Check whether a name can call setSubnodeOwner/setSubnodeRecord. A version of _canCallSetSubnode
     *        where the data is also passed, avoiding extra getData calls.
     * @dev Checks both CANNOT_CREATE_SUBDOMAIN and PARENT_CANNOT_CONTROL and whether not they have been burnt
     *      and checks whether the owner of the subdomain is 0x0 for creating or already exists for
     *      replacing a subdomain. If either conditions are true, then it is possible to call
     *      setSubnodeOwner
     * @param parentFuses The fuses of the parent name.
     * @param node The namehash of the subname to check.
     */

    function _canCallSetSubnode_WithData(
        uint32 parentFuses,
        bytes32 node,
        address nodeOwner,
        uint32 nodeFuses,
        uint64 nodeExpiry
    ) internal view {

        // Check if the name is expired and the owner is the 0 address. 
        if ((nodeExpiry < block.timestamp) && (nodeOwner == address(0) || ens.owner(node) == address(0))) {
            
            // The name is expired.

            // Check to see if the parent has CANNOT_CREATE_SUBDOMAIN burnt.
            if (parentFuses & CANNOT_CREATE_SUBDOMAIN != 0) {
                revert OperationProhibited(node);
            }
        } else {

            // The name is NOT expired.  

            // Check if the node has PARENT_CANNOT_CONTROL set.
            if (nodeFuses & PARENT_CANNOT_CONTROL != 0) {
                revert OperationProhibited(node);
            }
        }
    }

    /**
     * @notice Checks all Fuses in the mask are burned for the node
     * @param node Namehash of the name
     * @param fuseMask The fuses you want to check
     * @return Boolean of whether or not all the selected fuses are burned
     */

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) public view returns (bool) {

        (, uint32 fuses, ) = getData(uint256(node));

        // Check to see if all the fuses are burned as specified by the fuseMask.
        return fuses & fuseMask == fuseMask;
    }

    /* Internal Functions */

    /**
     * @notice Checks if the address is the owner or operator of the name. This function 
     * is a version of the canModifyName function, where the data is also passed, avoiding an extra getData call.
     * @param addr The address to check for permissions.
     * @param owner The owner of the name.
     * @param fuses The fuses of the name.
     * @param expiry The expiry of the name.
     * @return Whether or not the address is the owner or an operator of the name.
     */

    function _canModifyName_WithData(
        address addr,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal view returns (bool) {

        return
            // Check if the address is the owner or an approved-for-all address.
            (owner == addr || isApprovedForAll(owner, addr)) &&

            // Also if the name is a .eth 2LD, e.g, vitalik.eth, make sure that it is not in the grace period.
            !_isETH2LDInGracePeriod(fuses, expiry);
    }

    /**
     * @notice This function is called by the ERC1155 contract when a token is transferred. 
     * @dev It has a number of checks including checking to see if the name is transferable.
     * @param id The id of the token being transferred.
     * @param fuses The fuses of the token being transferred.
     * @param expiry The expiry of the token being transferred.
    */

    function _beforeTransfer(
        uint256 id,
        uint32 fuses,
        uint64 expiry
    ) internal override {
        // For this check, treat .eth 2LDs as expiring at the start of the grace period.
        if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
            expiry -= GRACE_PERIOD;
        }

        // Check to see if the name is expired.
        if (expiry < block.timestamp) {

            // The name is expired.

            // Check to see if the name is emancipated. If it is, then it is NOT transferable.            
            if (fuses & PARENT_CANNOT_CONTROL != 0) {
                revert("ERC1155: insufficient balance for transfer");
            }
        } else {

            // The name is NOT expired.

            // Check to see if the name is transferable.
            if (fuses & CANNOT_TRANSFER != 0) {
                revert OperationProhibited(bytes32(id));
            }
        }

        // Check to see if CANNOT_APPROVE is burned, if not then delete the approval.
        if (fuses & CANNOT_APPROVE == 0) {
            delete _tokenApprovals[id];
        }
    }

    // Currently this is a dummy function. It needs to also be removed from ERC1155Fuse to remove it. 
    function _clearOwnerAndFuses(
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal pure override returns (address, uint32) {
    }

    /**
     * @notice This function creates a namehash from a parent node and a labelhash
     *         according to the ENS namehash specification.
     * @param parentNode The parent node.
     * @param labelhash The labelhash of the label.
     */

    function _makeNode(
        bytes32 parentNode,
        bytes32 labelhash
    ) private pure returns (bytes32) {

        // Create the namehash.
        return keccak256(abi.encodePacked(parentNode, labelhash));
    }

    /**
     * @notice This function prepends a label to a name using the DNS encoding format.
     * @param label The label to prepend.
     * @param name The name to prepend the label to.
     */

    function _addLabel(
        string memory label,
        bytes memory name
    ) internal pure returns (bytes memory ret) {

        // Make sure the label is not empty.
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }

        // Make sure the label is not too long.
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }

        // Prepend the label to the name using the DNS encoding format.
        return abi.encodePacked(uint8(bytes(label).length), label, name);
    }


    /**
     * @notice Mint the name as an ERC1155 token.
     * @param node The namehash of the name.
     * @param owner The owner of the name.
     * @param fuses The fuses to set on the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function _mint(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal override {

        /** 
         * Check to make sure if an fuses are being burned,
         * also PARENT_CANNOT_CONTROL is being burned.
         */

        _canFusesBeBurned(node, fuses);

        // Get the data from the node.
        (address oldOwner, , ) = super.getData(uint256(node));

        // Check to see if the name was previously owned. 
        if (oldOwner != address(0)) {

            // burn the token. 
            _burn(uint256(node));

            emit NameUnwrapped(node, address(0));
        }

        // Mint the token.
        super._mint(node, owner, fuses, expiry);
    }

    /**
     * @notice This is a helper function that mints the name as well as
     *         emits the NameWrapped event.
     * @param node The namehash of the name.
     * @param name The name in DNS format.
     * @param wrappedOwner The owner of the wrapped name.
     * @param fuses The fuses to set on the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function _wrap(
        bytes32 node,
        bytes memory name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry
    ) internal {

        // Mint the token.
        _mint(node, wrappedOwner, fuses, expiry);

        // This function is needed to emit the NameWrapped event.
        emit NameWrapped(node, name, wrappedOwner, fuses, expiry);
    }


    /**
     * @notice This function saves the label of a name if it has not already been set.
     * @param parentNode The parent node of the name.
     * @param node The namehash of the name.
     * @param label The label of the name.
     */

    function _saveLabel(
        bytes32 parentNode,
        bytes32 node,
        string memory label
    ) internal returns (bytes memory) {

        // If the name has not been set then set it. 
        if (names[node].length == 0) {

            // Prepend the label to the parent name.
            bytes memory name = _addLabel(label, names[parentNode]);

            // Save the name.
            names[node] = name;
            
            return name;
        }

        // If the name is already set then just return it. 
        return names[node];
    }


    /**
     * @notice This function updates a name.
     * @param parentNode The parent node of the name.
     * @param node The namehash of the name.
     * @param label The label of the name.
     * @param owner The owner of the name.
     * @param fuses The fuses to set on the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function _updateName(
        bytes32 parentNode,
        bytes32 node,
        address nodeOwner,
        uint32 nodeFuses,
        uint64 nodeExpiry,
        string memory label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {

        // If the name is not set, set it.
        _saveLabel(parentNode, node, label);

        // Set the data of the name. 
        _setFuses(node, nodeOwner, nodeFuses | fuses, nodeExpiry, expiry);

        // Check to see if the owner is being set to the 0 address, i.e. is being burned.
        if (owner == address(0)) {

            // burn the name in both the wrapper and the registry.
            _burnAll(node);

        } else {

            // The owner is not address(0), so transfer the owner of the name to the new owner. 
            _transfer(nodeOwner, owner, uint256(node), 1, "");
        }
    }

    /**
     * @notice This function normalises the expiry of a name, setting the expiry
     *         between the old expiry and the max expiry.
     * @param expiry The expiry of the name.
     * @param oldExpiry The old expiry of the name.
     * @param maxExpiry The maximum expiry of the name.
     */

    function _normaliseExpiry(
        uint64 expiry,
        uint64 oldExpiry,
        uint64 maxExpiry
    ) private pure returns (uint64) {

        // The expiry cannot be more than maximum. 
        if (expiry > maxExpiry) {
            expiry = maxExpiry;
        }
        // The expiry cannot be less than the old expiry.
        if (expiry < oldExpiry) {
            expiry = oldExpiry;
        }

        return expiry;
    }

    /**
     * @notice This function wraps a .eth 2LD, i.e., vitalik.eth.
     * @param label The label of the name.
     * @param wrappedOwner The owner of the wrapped name.
     * @param approved The approved address of the name.
     * @param fuses The fuses to set on the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     * @param resolver The resolver contract of the name.
     */

    function _wrapETH2LD(
        string memory label,
        address wrappedOwner,
        address approved, 
        uint32 fuses,
        uint64 expiry,
        address resolver
    ) private {

        // Create the node from the label.
        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(ETH_NODE, labelhash);

        // Hardcode the DNS encoded "eth" string for gas savings.
        bytes memory name = _addLabel(label, "\x03eth\x00");

        // Save the name.
        names[node] = name;

        // Wrap the .eth 2LD name in the wrapper, and burn CANNOT_BURN_NAME , PARENT_CANNOT_CONTROL and IS_DOT_ETH.
        _wrap(
            node,
            name,
            wrappedOwner,
            fuses | CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | IS_DOT_ETH,
            expiry
        );

        // Add an approved address.
        if (approved != address(0)) {
            super._approve(approved, uint256(node));
        }

        // Check to make sure the resolver address is not the 0 address, if not then set the resolver.
        if (resolver != address(0)) {
            ens.setResolver(node, resolver);
        }
    }

    /**
     * @notice This function burns the token and sets the address to 0 in the registry. 
     * @param node The namehash of the name.
     */

    function _burnAll(bytes32 node) private {

        // Check to see if CANNOT_BURN_NAME is burned.
        if (allFusesBurned(node, CANNOT_BURN_NAME)) {
            revert OperationProhibited(node);
        }

        // Burn token and fuse data
        _burn(uint256(node));

        // Set the owner in the registry.
        ens.setOwner(node, address(0));

        emit NameUnwrapped(node, address(0));
    }

    /**
     * @notice This function sets the fuses of a name.
     * @param node The namehash of the name.
     * @param owner The owner of the name.
     * @param fuses The fuses to set on the name.
     * @param oldExpiry The old expiry of the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function _setFuses(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 oldExpiry,
        uint64 expiry
    ) internal {

        _setData(node, owner, fuses, expiry);

        emit FusesSet(node, fuses);

        // Check to see if the expiry has been extended.
        if (expiry > oldExpiry) {
            emit ExpiryExtended(node, expiry);
        }
    }

    /**
     * @notice This function sets the data of a name.
     * @param node The namehash of the name.
     * @param owner The owner of the name.
     * @param fuses The fuses to set on the name.
     * @param expiry The expiry date of the name, in seconds since the Unix epoch.
     */

    function _setData(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {

        /** 
         * Check to make sure if an owner controlled fuse is being burned,
         * also PARENT_CANNOT_CONTROL and CANNOT_BURN_NAME are being burned.
         */

        _canFusesBeBurned(node, fuses);

        super._setData(uint256(node), owner, fuses, expiry);
    }

    /**
     * @notice Checks to see if fuses are being burned, and if so,
     *         checks to see if PARENT_CANNOT_CONTROL is also being burned.
     * @param node The namehash of the name.
     * @param fuses The fuses of the name.
     */
    
    function _canFusesBeBurned(bytes32 node, uint32 fuses) internal pure {

        if (
            
            // Checks to see if any fuses are being burned.
            fuses != 0 &&  

            // Check to see if PARENT_CANNOT_CONTROL is being burned.
            fuses & PARENT_CANNOT_CONTROL != PARENT_CANNOT_CONTROL
        ) {
            revert OperationProhibited(node);
        }
    }

    /**
     * @notice Check to make sure the special fuse, IS_DOT_ETH is not being burned.
     * @param node The namehash of the name.
     * @param fuses The fuses of the name.
     */

    function _fusesAreSettable(bytes32 node, uint32 fuses) internal pure {

        // Check to make sure that only allowable fuses are being burned, i.e. not IS_DOT_ETH.
        if (fuses | USER_SETTABLE_FUSES != USER_SETTABLE_FUSES) {
            revert OperationProhibited(node);
        }
    }

    /**
     * @notice Checks to see if the name is a .eth 2LD in the grace period.
     * @param fuses The fuses of the name.
     * @param expiry The expiry of the name.
     */

    function _isETH2LDInGracePeriod(
        uint32 fuses,
        uint64 expiry
    ) internal view returns (bool) {

        return

            // Check to see if the name is a .eth 2LD.
            fuses & IS_DOT_ETH == IS_DOT_ETH &&

            // Check to see if the name is in the grace period.
            expiry - GRACE_PERIOD < block.timestamp;
    }
}
