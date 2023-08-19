//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {ERC1155Fuse, IERC1155MetadataURI} from "ens-contracts/wrapper/ERC1155Fuse.sol";
import {Controllable} from "ens-contracts/wrapper/Controllable.sol";
import {IL2NameWrapper, CANNOT_UNWRAP, CANNOT_BURN_FUSES, CANNOT_TRANSFER, CANNOT_SET_RESOLVER, CANNOT_SET_TTL, CANNOT_CREATE_SUBDOMAIN, CANNOT_APPROVE, PARENT_CANNOT_CONTROL, CAN_DO_EVERYTHING, IS_DOT_ETH, CAN_EXTEND_EXPIRY, PARENT_CONTROLLED_FUSES, USER_SETTABLE_FUSES} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
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
    using BytesUtils for bytes;

    ENS public immutable ens;
    IMetadataService public metadataService;
    mapping(bytes32 => bytes) public names;

    uint64 private constant GRACE_PERIOD = 90 days;
    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_LABELHASH =
        0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 private constant ROOT_NODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    INameWrapperUpgrade public upgradeContract;
    uint64 private constant MAX_EXPIRY = type(uint64).max;

    constructor(
        ENS _ens,
        IMetadataService _metadataService
    ) {
        ens = _ens;
        metadataService = _metadataService;

        /* Burn PARENT_CANNOT_CONTROL and CANNOT_UNWRAP fuses for ROOT_NODE and ETH_NODE and set expiry to max */

        _setData(
            uint256(ETH_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_UNWRAP),
            MAX_EXPIRY
        );
        _setData(
            uint256(ROOT_NODE),
            address(0),
            uint32(PARENT_CANNOT_CONTROL | CANNOT_UNWRAP),
            MAX_EXPIRY
        );
        names[ROOT_NODE] = "\x00";
        names[ETH_NODE] = "\x03eth\x00";
    }

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
        if (owner == address(0)) {
            return address(0);
        }
        return super.getApproved(id);
    }

    /**
     * @notice Approves an address for a name
     * @param to address to approve
     * @param tokenId name to approve
     */

    function approve(
        address to,
        uint256 tokenId
    ) public override(ERC1155Fuse, IL2NameWrapper) {
        (, uint32 fuses, ) = getData(tokenId);
        if (fuses & CANNOT_APPROVE == CANNOT_APPROVE) {
            revert OperationProhibited(bytes32(tokenId));
        }
        super.approve(to, tokenId);
    }

    /**
     * @notice Gets the data for a name
     * @param id Namehash of the name
     * @return owner Owner of the name
     * @return fuses Fuses of the name
     * @return expiry Expiry of the name
     */

    function getData(
        uint256 id
    )
        public
        view
        override(ERC1155Fuse, IL2NameWrapper)
        returns (address owner, uint32 fuses, uint64 expiry)
    {
        (owner, fuses, expiry) = super.getData(id);

        (owner, fuses) = _clearOwnerAndFuses(owner, fuses, expiry);
    }

    /* Metadata service */

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
     * @notice Checks if msg.sender is the owner or operator of the owner of a name
     * @param node namehash of the name to check
     */

    modifier onlyTokenOwner(bytes32 node) {
        if (!canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        _;
    }

    /**
     * @notice Checks if owner or operator of the owner
     * @param node namehash of the name to check
     * @param addr which address to check permissions for
     * @return whether or not is owner or operator
     */

    function canModifyName(
        bytes32 node,
        address addr
    ) public view returns (bool) {
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));
        return
            (owner == addr || isApprovedForAll(owner, addr)) &&
            !_isETH2LDInGracePeriod(fuses, expiry);
    }

    /**
     * @notice Checks if owner/operator or approved by owner
     * @param node namehash of the name to check
     * @param addr which address to check permissions for
     * @return whether or not is owner/operator or approved
     */

    function canExtendSubnames(
        bytes32 node,
        address addr
    ) public view returns (bool) {
        (address owner, uint32 fuses, uint64 expiry) = getData(uint256(node));
        return
            (owner == addr ||
                isApprovedForAll(owner, addr) ||
                getApproved(uint256(node)) == addr) &&
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
        // Save the subname in the registry.

        ens.setSubnodeRecord(ETH_NODE, labelhash, address(this), address(0), 0);

        expiry = uint64(block.timestamp) + uint64(duration) + GRACE_PERIOD;

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
        bytes32 node = _makeNode(ETH_NODE, labelhash);

        if (!_isWrapped(node)) {
            revert NameIsNotWrapped();
        }

        // get the owner fuses and expiry of the node
        (address owner, uint32 fuses, uint64 oldExpiry) = getData(uint256(node));

        // Set expiry in Wrapper
        expiry = uint64(oldExpiry + duration);

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
        // owner protected by onlyTokenOwner
        (address owner, uint32 oldFuses, uint64 expiry) = getData(
            uint256(node)
        );
        _setFuses(node, owner, ownerControlledFuses | oldFuses, expiry, expiry);
        return oldFuses;
    }

    /**
     * @notice Extends expiry for a name
     * @param parentNode Parent namehash of the name e.g. vitalik.xyz would be namehash('xyz')
     * @param labelhash Labelhash of the name, e.g. vitalik.xyz would be keccak256('vitalik')
     * @param expiry When the name will expire in seconds since the Unix epoch
     * @return New expiry
     */

    function extendExpiry(
        bytes32 parentNode,
        bytes32 labelhash,
        uint64 expiry
    ) public returns (uint64) {
        bytes32 node = _makeNode(parentNode, labelhash);

        if (!_isWrapped(node)) {
            revert NameIsNotWrapped();
        }

        (address owner, uint32 fuses, uint64 oldExpiry) = getData(
            uint256(node)
        );

        // get the approved contract address
        address approved = getApproved(uint256(node));

        // Only allow the owner of the parent name, owner of the name with CAN_EXTEND_EXPIRY,
        // or the approved contract on the node to extend the expiry of the name. 
        if (!canExtendSubnames(parentNode, msg.sender) && 
            !(canModifyName(node, msg.sender) && fuses & CAN_EXTEND_EXPIRY != 0) &&
            !(msg.sender == approved)) {
            revert Unauthorised(node, msg.sender);
        }

        // Max expiry is set to the expiry of the parent
        (, , uint64 maxExpiry) = getData(uint256(parentNode));
        expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);

        _setData(node, owner, fuses, expiry);
        emit ExpiryExtended(node, expiry);
        return expiry;
    }

    /**
     * @notice Upgrades a domain of any kind. Could be a .eth name vitalik.eth, a DNSSEC name vitalik.xyz, or a subdomain
     * @dev Can be called by the owner or an authorised caller
     * @param name The name to upgrade, in DNS format
     * @param extraData Extra data to pass to the upgrade contract
     */

    function upgrade(bytes calldata name, bytes calldata extraData) public {
        bytes32 node = name.namehash(0);

        if (address(upgradeContract) == address(0)) {
            revert CannotUpgrade();
        }

        if (!canModifyName(node, msg.sender)) {
            revert Unauthorised(node, msg.sender);
        }

        (address currentOwner, uint32 fuses, uint64 expiry) = getData(
            uint256(node)
        );

        // Get labelhash from the name
        (bytes32 labelhash, ) = name.readLabel(0);

        address approved = getApproved(uint256(node));

        // Change the owner in the registry to the upgrade contract.
        ens.setOwner(node, address(upgradeContract));

        _burn(uint256(node));

        upgradeContract.wrapFromUpgrade(
            name,
            currentOwner,
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
        _fusesAreSettable(node, fuses);
        (address owner, uint32 oldFuses, uint64 oldExpiry) = getData(
            uint256(node)
        );
        if (owner == address(0) || ens.owner(node) != address(this)) {
            revert NameIsNotWrapped();
        }
        // max expiry is set to the expiry of the parent
        (, uint32 parentFuses, uint64 maxExpiry) = getData(uint256(parentNode));
        if (parentNode == ROOT_NODE) {
            if (!canModifyName(node, msg.sender)) {
                revert Unauthorised(node, msg.sender);
            }
        } else {
            if (!canModifyName(parentNode, msg.sender)) {
                revert Unauthorised(parentNode, msg.sender);
            }
        }

        _checkParentFuses(node, fuses, parentFuses);

        expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);

        // if PARENT_CANNOT_CONTROL has been burned and fuses have changed
        if (
            oldFuses & PARENT_CANNOT_CONTROL != 0 &&
            oldFuses | fuses != oldFuses
        ) {
            revert OperationProhibited(node);
        }
        fuses |= oldFuses;
        _setFuses(node, owner, fuses, oldExpiry, expiry);
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
        bytes32 labelhash = keccak256(bytes(label));
        node = _makeNode(parentNode, labelhash);

        // Cecks the parent to make sure it has the persmissions it needs to create or update a subdomain. 
        _canCallSetSubnode(parentNode, node);

        // Checks to make sure the IS_DOT_ETH fuse is not burnt in the fuses. 
        _fusesAreSettable(node, fuses);

        // If the name has not been set before, save the label.
        bytes memory name = _saveLabel(parentNode, node, label);

        // Use a block to avoid stack too deep error.
        {
            (, , uint64 oldExpiry) = getData(uint256(node));
            (, uint32 parentFuses, uint64 maxExpiry) = getData(uint256(parentNode));

            // If we are burning parent controlled fuses make sure the parent has burned CANNOT_UNWRAP.
            _checkParentFuses(node, fuses, parentFuses);

            // Make sure the expiry is between the old expiry and the parent expiry.
            expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);
        }

        // If the name is NOT wrapped, wrap it.
         if (!_isWrapped(node)) {
            ens.setSubnodeOwner(parentNode, labelhash, address(this));
            _wrap(node, name, owner, fuses, expiry);
        } else {

            // The name is wrapped, so update it.
            _updateName(parentNode, node, label, owner, fuses, expiry);
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

        // Cecks the parent to make sure it has the persmissions it needs to create or update a subdomain. 
        _canCallSetSubnode(parentNode, node);

        // Checks to make sure the IS_DOT_ETH fuse is not burnt in the fuses. 
        _fusesAreSettable(node, fuses);

        // If the name has not been set before, save the label.
        bytes memory name = _saveLabel(parentNode, node, label);

        // Use a block to avoid stack too deep error.
        {
            (, , uint64 oldExpiry) = getData(uint256(node));
            (, uint32 parentFuses, uint64 maxExpiry) = getData(uint256(parentNode));

            // If we are burning parent controlled fuses make sure the parent has burned CANNOT_UNWRAP.
            _checkParentFuses(node, fuses, parentFuses);

            // Make sure the expiry is between the old expiry and the parent expiry.
            expiry = _normaliseExpiry(expiry, oldExpiry, maxExpiry);
        }

        // If the name is NOT wrapped, wrap it.
        if (!_isWrapped(node)) {
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );
            _wrap(node, name, owner, fuses, expiry);
        } else {

            // The name is wrapped, so update it.
            ens.setSubnodeRecord(
                parentNode,
                labelhash,
                address(this),
                resolver,
                ttl
            );
            _updateName(parentNode, node, label, owner, fuses, expiry);
        }

        // Add an approved address
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
        ens.setRecord(node, address(this), resolver, ttl);
        if (owner == address(0)) {
            (, uint32 fuses, ) = getData(uint256(node));
            if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
                revert IncorrectTargetOwner(owner);
            }
            _unwrap(node, address(0));
        } else {
            address oldOwner = ownerOf(uint256(node));
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
     * @dev Allows an operation only if none of the specified fuses are burned.
     * @param node The namehash of the name to check fuses on.
     * @param fuseMask A bitmask of fuses that must not be burned.
     */

    modifier operationAllowed(bytes32 node, uint32 fuseMask) {
        (, uint32 fuses, ) = getData(uint256(node));
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

        bool expired = nodeExpiry < block.timestamp;

        // Check if the name is expired and the owner is 0. 

        if (
            expired && (nodeOwner == address(0) || ens.owner(node) == address(0))
        ) {

            // The name is expired, so check if the parent has CANNOT_CREATE_SUBDOMAIN set.

            (, uint32 parentFuses, ) = getData(uint256(parentNode));
            if (parentFuses & CANNOT_CREATE_SUBDOMAIN != 0) {
                revert OperationProhibited(node);
            }
        } else {

            // The name is NOT expired, so check if the node has PARENT_CANNOT_CONTROL set. 

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
        return fuses & fuseMask == fuseMask;
    }


// just deleting this temporarily



    /***** Internal functions */

    function _beforeTransfer(
        uint256 id,
        uint32 fuses,
        uint64 expiry
    ) internal override {
        // For this check, treat .eth 2LDs as expiring at the start of the grace period.
        if (fuses & IS_DOT_ETH == IS_DOT_ETH) {
            expiry -= GRACE_PERIOD;
        }

        if (expiry < block.timestamp) {
            // Transferable if the name was not emancipated
            if (fuses & PARENT_CANNOT_CONTROL != 0) {
                revert("ERC1155: insufficient balance for transfer");
            }
        } else {
            // Transferable if CANNOT_TRANSFER is unburned
            if (fuses & CANNOT_TRANSFER != 0) {
                revert OperationProhibited(bytes32(id));
            }
        }

        // delete token approval if CANNOT_APPROVE has not been burnt
        if (fuses & CANNOT_APPROVE == 0) {
            delete _tokenApprovals[id];
        }
    }

    function _clearOwnerAndFuses(
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal view override returns (address, uint32) {
        if (expiry < block.timestamp) {
            if (fuses & PARENT_CANNOT_CONTROL == PARENT_CANNOT_CONTROL) {
                owner = address(0);
            }
            fuses = 0;
        }

        return (owner, fuses);
    }

    function _makeNode(
        bytes32 node,
        bytes32 labelhash
    ) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(node, labelhash));
    }

    function _addLabel(
        string memory label,
        bytes memory name
    ) internal pure returns (bytes memory ret) {
        if (bytes(label).length < 1) {
            revert LabelTooShort();
        }
        if (bytes(label).length > 255) {
            revert LabelTooLong(label);
        }
        return abi.encodePacked(uint8(bytes(label).length), label, name);
    }

    function _mint(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal override {
        _canFusesBeBurned(node, fuses);
        (address oldOwner, , ) = super.getData(uint256(node));
        if (oldOwner != address(0)) {
            // burn and unwrap old token of old owner
            _burn(uint256(node));
            emit NameUnwrapped(node, address(0));
        }
        super._mint(node, owner, fuses, expiry);
    }

    function _wrap(
        bytes32 node,
        bytes memory name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        _mint(node, wrappedOwner, fuses, expiry);
        emit NameWrapped(node, name, wrappedOwner, fuses, expiry);
    }

    function _saveLabel(
        bytes32 parentNode,
        bytes32 node,
        string memory label
    ) internal returns (bytes memory) {

        // If the name has not been set then set it. 
        if (names[node].length == 0) {
            bytes memory name = _addLabel(label, names[parentNode]);
            names[node] = name;
            
            return name;
        }

        // If the name is already set then just return it. 
        return names[node];
    }

    function _updateName(
        bytes32 parentNode,
        bytes32 node,
        string memory label,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        (address oldOwner, uint32 oldFuses, uint64 oldExpiry) = getData(
            uint256(node)
        );

        if (names[node].length == 0) {
            bytes memory name = _addLabel(label, names[parentNode]);
            names[node] = name;
        }
        _setFuses(node, oldOwner, oldFuses | fuses, oldExpiry, expiry);
        if (owner == address(0)) {
            _unwrap(node, address(0));
        } else {
            _transfer(oldOwner, owner, uint256(node), 1, "");
        }
    }

    function _checkParentFuses(
        bytes32 node,
        uint32 fuses,
        uint32 parentFuses
    ) internal pure {

        // If we are burning parent controlled fuses
        if (fuses & PARENT_CONTROLLED_FUSES != 0 && 
            // and the parent has not burned CANNOT_UNWRAP
            parentFuses & CANNOT_UNWRAP == 0) {

            revert OperationProhibited(node);
        }
    }

    function _normaliseExpiry(
        uint64 expiry,
        uint64 oldExpiry,
        uint64 maxExpiry
    ) private pure returns (uint64) {
        // Expiry cannot be more than maximum allowed
        // .eth names will check registrar, non .eth check parent
        if (expiry > maxExpiry) {
            expiry = maxExpiry;
        }
        // Expiry cannot be less than old expiry
        if (expiry < oldExpiry) {
            expiry = oldExpiry;
        }

        return expiry;
    }

    function _wrapETH2LD(
        string memory label,
        address wrappedOwner,
        address approved, 
        uint32 fuses,
        uint64 expiry,
        address resolver
    ) private {
        bytes32 labelhash = keccak256(bytes(label));
        bytes32 node = _makeNode(ETH_NODE, labelhash);
        // hardcode dns-encoded eth string for gas savings
        bytes memory name = _addLabel(label, "\x03eth\x00");
        names[node] = name;

        _wrap(
            node,
            name,
            wrappedOwner,
            fuses | CANNOT_UNWRAP | PARENT_CANNOT_CONTROL | IS_DOT_ETH,
            expiry
        );

        // Add an approved address
        if (approved != address(0)) {
            super._approve(approved, uint256(node));
        }

        if (resolver != address(0)) {
            ens.setResolver(node, resolver);
        }
    }

    function _unwrap(bytes32 node, address owner) private {
        if (allFusesBurned(node, CANNOT_UNWRAP)) {
            revert OperationProhibited(node);
        }

        // Burn token and fuse data
        _burn(uint256(node));
        ens.setOwner(node, owner);

        emit NameUnwrapped(node, owner);
    }

    function _setFuses(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 oldExpiry,
        uint64 expiry
    ) internal {
        _setData(node, owner, fuses, expiry);
        emit FusesSet(node, fuses);
        if (expiry > oldExpiry) {
            emit ExpiryExtended(node, expiry);
        }
    }

    function _setData(
        bytes32 node,
        address owner,
        uint32 fuses,
        uint64 expiry
    ) internal {
        _canFusesBeBurned(node, fuses);
        super._setData(uint256(node), owner, fuses, expiry);
    }

    function _canFusesBeBurned(bytes32 node, uint32 fuses) internal pure {

        if (
            // If an owner controlled fuse is burned,
            fuses & ~PARENT_CONTROLLED_FUSES != 0 &&
            // revert if PARENT_CANNOT_CONTROL and CANNOT_UNWRAP are not burned.
            fuses & (PARENT_CANNOT_CONTROL | CANNOT_UNWRAP) != (PARENT_CANNOT_CONTROL | CANNOT_UNWRAP)
        ) {
            revert OperationProhibited(node);
        }
    }

    function _fusesAreSettable(bytes32 node, uint32 fuses) internal pure {
        if (fuses | USER_SETTABLE_FUSES != USER_SETTABLE_FUSES) {
            // Cannot directly burn other non-user settable fuses
            revert OperationProhibited(node);
        }
    }

    function _isWrapped(bytes32 node) internal view returns (bool) {
        return
            ownerOf(uint256(node)) != address(0); //&& @audit - removed checking the registry since names are always wrapped.  
            //ens.owner(node) == address(this);
    }

    function _isETH2LDInGracePeriod(
        uint32 fuses,
        uint64 expiry
    ) internal view returns (bool) {
        return
            fuses & IS_DOT_ETH == IS_DOT_ETH &&
            expiry - GRACE_PERIOD < block.timestamp;
    }
}
