//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import "ens-contracts/registry/ENS.sol";
import "ens-contracts/ethregistrar/IBaseRegistrar.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "ens-contracts/wrapper/IMetadataService.sol";
import "ens-contracts/wrapper/INameWrapperUpgrade.sol";

// These are named fuses which can be set by name owners. 
uint32 constant CAN_DO_EVERYTHING = 0;
uint32 constant CANNOT_BURN_NAME = 1;
uint32 constant CANNOT_BURN_FUSES = 2;
uint32 constant CANNOT_TRANSFER = 4;
uint32 constant CANNOT_SET_RESOLVER = 8;
uint32 constant CANNOT_SET_TTL = 16;
uint32 constant CANNOT_CREATE_SUBDOMAIN = 32;
uint32 constant CANNOT_APPROVE = 64;

// These are named fuses which can be set by parent name owners on the name.
uint32 constant PARENT_CANNOT_CONTROL = 1 << 16;
uint32 constant CAN_EXTEND_EXPIRY = 1 << 17;

// This is a special fuse that is set for .eth names and only used internally. 
uint32 constant IS_DOT_ETH = 1 << 18;

// A filter for all the fuses that can be set by the parent name owner.
uint32 constant PARENT_CONTROLLED_FUSES = 0x00030000; // 0b00000000000000110000000000000000

// A filter for all fuses the fuses that can be set by name owners.
uint32 constant USER_SETTABLE_FUSES = 0x3007F; // 0b00000000000000110000000001111111 

interface IL2NameWrapper is IERC1155 {

    event NameWrapped(
        bytes32 indexed node,
        bytes name,
        address owner,
        uint32 fuses,
        uint64 expiry
    );

    event NameUnwrapped(bytes32 indexed node, address owner);

    event FusesSet(bytes32 indexed node, uint32 fuses);

    event ExpiryExtended(bytes32 indexed node, uint64 expiry);

    function ens() external view returns (ENS);

    function metadataService() external view returns (IMetadataService);

    function names(bytes32) external view returns (bytes memory);

    function upgradeContract() external view returns (INameWrapperUpgrade);

    function supportsInterface(bytes4 interfaceID) external view returns (bool);

    function upgrade(bytes calldata name, bytes calldata extraData) external;

    function registerAndWrapEth2LD(
        string calldata label,
        address wrappedOwner,
        address approved,
        uint256 duration,
        address resolver,
        uint16 ownerControlledFuses
    ) external returns (uint64 expiry);

    function renewEth2LD(
        bytes32 labelhash,
        uint256 duration
    ) external returns (uint64 expiry);

    function setFuses(
        bytes32 node,
        uint16 ownerControlledFuses
    ) external returns (uint32 newFuses);

    function setChildFuses(
        bytes32 parentNode,
        bytes32 labelhash,
        uint32 fuses,
        uint64 expiry
    ) external;

    function setSubnodeRecord(
        bytes32 parentNode,
        string calldata label,
        address owner,
        address approved,
        address resolver,
        uint64 ttl,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32 node);

    function setRecord(
        bytes32 node,
        address owner,
        address resolver,
        uint64 ttl
    ) external;

    function setSubnodeOwner(
        bytes32 parentNode,
        string calldata label,
        address owner,
        address approved,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32 node);

    function extendExpiry(
        bytes32 parentNode,
        bytes32 labelhash,
        uint64 expiry
    ) external returns (uint64);

    function canModifyName(
        bytes32 node,
        address addr
    ) external view returns (bool);

    function wrapTLD(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry
    ) external returns (bytes32 /* node */);

    function setResolver(bytes32 node, address resolver) external;

    function setTTL(bytes32 node, uint64 ttl) external;

    function ownerOf(uint256 id) external view returns (address owner);

    function approve(address to, uint256 tokenId) external;

    function getApproved(uint256 tokenId) external view returns (address);

    function getData(
        uint256 id
    ) external view returns (address, uint32, uint64);

    function setMetadataService(IMetadataService _metadataService) external;

    function uri(uint256 tokenId) external view returns (string memory);

    function setUpgradeContract(INameWrapperUpgrade _upgradeAddress) external;

    function allFusesBurned(
        bytes32 node,
        uint32 fuseMask
    ) external view returns (bool);

}
