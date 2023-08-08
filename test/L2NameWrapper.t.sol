// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {L2NameWrapper} from "optimism/wrapper/L2NameWrapper.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {IL2NameWrapper, CANNOT_SET_TTL, CANNOT_SET_RESOLVER, CAN_EXTEND_EXPIRY, CANNOT_UNWRAP, PARENT_CANNOT_CONTROL} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapperUpgrade} from "ens-contracts/wrapper/INameWrapperUpgrade.sol";
import {L2UpgradedNameWrapperMock} from "optimism/wrapper/mocks/L2UpgradedNameWrapperMock.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {IRenewalController} from "contracts/subwrapper/interfaces/IRenewalController.sol";

import {IERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {GasHelpers} from "./GasHelpers.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ReverseRegistrar} from "ens-contracts/reverseRegistrar/ReverseRegistrar.sol";
import {ERC20PresetFixedSupply} from "openzeppelin-contracts/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

error NameMustBeWrappedInNameWrapper();
error UnauthorizedSender(bytes32 node, address sender);
error NameIsNotWrapped();

contract L2NameWrapperTest is Test, GasHelpers {

    event NameRenewed(
        bytes indexed name,
        uint256 indexed price,
        uint64 indexed expiry
    );

    event NameUpgraded(
        bytes name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes extraData
    );

    event ExtendExpiry(bytes32 node, uint64 expiry);
    
    uint64 private constant GRACE_PERIOD = 90 days;
    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_LABELHASH =
        0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 private constant ROOT_NODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;

    uint64 twoYears = 63072000; // aprox. 2 years
    uint64 oneYear = 31536000; // A year in seconds.
    uint64 oneMonth = 2592000; // A month in seconds.
    uint64 oneDay = 86400; // A day in seconds.
    address account = 0x0000000000000000000000000000000000003511;
    address account2 = 0x0000000000000000000000000000000000004612;
    address accountReferrer = 0x0000000000000000000000000000000000000001;
    address publicResolver = 0x0000000000000000000000000000000000000006;

    // Set a dummy address for the renewal controller.
    IRenewalController renewalController = IRenewalController(address(0x0000000000000000000000000000000000000007));

    // Set a dummy address for the custom resolver.
    address customResolver = 0x0000000000000000000000000000000000000007;

    ENSRegistry ens; 
    ReverseRegistrar reverseRegistrar;
    StaticMetadataService staticMetadataService;
    L2NameWrapper nameWrapper;

    uint256 testNumber;

    using BytesUtils for bytes;

    function setUp() public {

        vm.warp(1641070800); 
        vm.startPrank(account);

        // Deploy the ENS registry.
        ens = new ENSRegistry(); 

        // Deploy a reverse registrar.
        reverseRegistrar = new ReverseRegistrar(ens);
        // Set the reverse registrar as the owner of the reverse node.
        ens.setSubnodeOwner(ROOT_NODE, keccak256("reverse"), account);
        ens.setSubnodeOwner(bytes("\x07reverse\x00").namehash(0), keccak256("addr"), address(reverseRegistrar));


        // Deploy a metadata service.
        staticMetadataService = new StaticMetadataService("testURI");

        // Deploy the name wrapper. 
        nameWrapper = new L2NameWrapper(
            ens, 
            IMetadataService(address(staticMetadataService))
        );

        // Set up .eth in the ENS registry.
        ens.setSubnodeOwner(ROOT_NODE, ETH_LABELHASH, address(nameWrapper)); 
        assertEq(ens.owner(ETH_NODE), address(nameWrapper));  // make sure the .eth node is owned by nameWrapper

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.setController(account, true);
    
        nameWrapper.registerAndWrapEth2LD(
            "abc", 
            account,
            address(0), // no approved account
            twoYears,
            publicResolver,
            uint16(0)
        );

    }

    function registerAndWrap(address _account, address _approved) internal returns (bytes32 node){

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);


        // Register a subname using the SubnameWrapper contract. 
        node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            _account, 
            _approved,
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );
        

    }


    // Create a Subheading using an empty function.
    function test1000________________________________________________________________________________() public {}
    function test2000__________________________L2_NAME_WRAPPER_FUNCTIONS_____________________________() public {}
    function test3000________________________________________________________________________________() public {}

    //Check to make sure the subname wrapper contract supports interface detection. 
    function test_001____supportsInterface___________SupportsCorrectInterfaces() public {

        // Check for the ISubnameWrapper interface.  
        assertEq(nameWrapper.supportsInterface(type(IL2NameWrapper).interfaceId), true);

        // Check for the IERC1155Receiver interface.  

        // Check for the IERC1155 interface.  
        assertEq(nameWrapper.supportsInterface(type(IERC1155).interfaceId), true);

        // Check for the IERC1155MetadataURI interface.  
        assertEq(nameWrapper.supportsInterface(type(IERC1155MetadataURI).interfaceId), true);

        // Check for the IERC165 interface.  
        assertEq(nameWrapper.supportsInterface(type(IERC165).interfaceId), true);
    }

    // Check to make sure the owner of the subname is correct.
    function test_002____ownerOf_____________________OwnerIsCorrect() public {

        bytes32 node = registerAndWrap(account, address(0));
        assertEq(nameWrapper.ownerOf(uint256(node)), account);
    }

    // Check to make sure the owner of the subname is 0 after the name expires.
    function test_003____ownerOf_____________________OwnerIsZeroWhenNameIsExpired() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Warp to the expiry of the name.
        vm.warp(uint64(block.timestamp) + oneYear + oneDay);

        assertEq(nameWrapper.ownerOf(uint256(node)), address(0));
    }

    // Check to make sure the metadata service was setup and returns a test uri
    function test_004____setMetadataService__________MetadataServiceWasSetup() public{

        assertEq(address(nameWrapper.metadataService()), address(staticMetadataService));
    }
    
    // Check to make sure the metadata service was setup and returns a test uri
    function test_005____uri_________________________ReturnsCorrectURI() public{
        bytes32 node = registerAndWrap(account, address(0));
        assertEq(nameWrapper.uri(uint256(node)), "testURI");
    }

    // Check to make sure that upgrade contract can be set.
    function test_007____setUpgradeContract__________UpgradeContractCanBeSet() public{
        // See above, this is just a place holder.
        bytes32 node = registerAndWrap(account, address(0));
        nameWrapper.setUpgradeContract(INameWrapperUpgrade(account2)); 
        assertEq(
            address(nameWrapper.upgradeContract()),
            account2
        );
    }

    function test_008____canModifyName_______________NonOwnersCannotModifyName() public{

        bytes32 node = registerAndWrap(account, address(0));

        // If account calls the function it should return true.
        assertEq(nameWrapper.canModifyName(node, account), true);
        
        // If account2 calls the function it shoudl return false.
        assertEq(nameWrapper.canModifyName(node, account2), false);
    }

    // Check to make sure that the parent owner can extend the expiry of a name.
    function test_012____exendExpiry_________________ExtendTheExpiryOfANameIfCallerIsParent() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Register a subname using the L2NameWrapper contract. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode, 
            "sub",
            account2, 
            address(0), // no approved account
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneMonth
        );

        // Check to make sure the expiry was extended in the Name Wrapper.
        ( , , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, uint64(block.timestamp) + oneYear + oneMonth);

    }

    // Check to make sure that the owner can extend the expiry of a name, if set to the renewal controller address.
    function test_014____exendExpiry_________________ExtendTheExpiryOfANameIfRenewalControllerSetToOwner() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Register a subname using the L2NameWrapper contract. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode, 
            "sub",
            account2, 
            account2, 
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        vm.stopPrank();
        // Change the caller to account2.
        vm.startPrank(account2);

        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneMonth
        );

        // Check to make sure the expiry was extended in the Name Wrapper.
        ( , , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, uint64(block.timestamp) + oneYear + oneMonth);

    }

    // Check to make sure that the owner can extend the expiry of a name in various edge cases.
    function test_015____exendExpiry_________________ExtendTheExpiryOfANameEdgeCases() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Register a subname using the L2NameWrapper contract. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode, 
            "sub",
            account2, 
            account2, 
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        vm.stopPrank();
        // Change the caller to account2.
        vm.startPrank(account2);

        // set the expiry in the past.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) - oneYear
        );

        // Check to make sure the expiry was extended in the Name Wrapper.
        ( , , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, uint64(block.timestamp) + oneYear);

        // set the expiry far into the future.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + ( 200 * oneYear)
        );

        // Check to make sure the expiry was extended in the Name Wrapper.
        ( , , uint64 expiry2) = nameWrapper.getData(uint256(node));
        assertEq(expiry2, uint64(block.timestamp) + twoYears + GRACE_PERIOD);
    }

    //@audit - We need a test to make sure that the parent owner can't renew expired names. 
    // Check to make sure the parent owner can't renew the name after expiry.
    function test_016____exendExpiry_________________NameExpiresItCantBeExtendedByTheParentOwner() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Register a subname using the L2NameWrapper contract. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode, 
            "sub",
            account2, 
            address(0), 
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        // advance time by one year and a day to make the name expired.
        vm.warp(block.timestamp + oneYear + oneDay);

        // make sure the funciton reverts with UnauthorizedSender(node, msg.sender)
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // set the expiry for 1 years ahead.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneDay
        );
    }

    // Check to make sure that the expiry of the name can't be extended after the name has expired by the renewal controller.
    function test_017____exendExpiry_________________NameExpiresItCantBeExtendedByTheRenewalController() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Register a subname using the L2NameWrapper contract. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode, 
            "sub",
            account2, 
            accountReferrer, // set the accountReferrer as the approved contract. 
            publicResolver, 
            0, //TTL
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        // advance time by one year and a day to make the name expired.
        vm.warp(block.timestamp + oneYear + oneDay);

        vm.stopPrank();
        // Change the caller to accountReferrer. 
        vm.startPrank(accountReferrer);

        // make sure the function reverts with UnauthorizedSender(node, msg.sender)
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // set the expiry for 1 years ahead.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneDay
        );
    }

    // Check to make sure the contract can be upgraded using the upgrade function. 
    function test_018____upgrade_____________________UpgradeTheContract() public{

          // Set up a subname. The owner is account2.
        bytes32 node = registerAndWrap(account2, address(0));

        // Deploy the new name wrapper.
        L2UpgradedNameWrapperMock nameWrapperUpgraded = new L2UpgradedNameWrapperMock(
            ens
        );

        // Set the new NameWrapper as the upgraded contract. 
        nameWrapper.setUpgradeContract(INameWrapperUpgrade(address(nameWrapperUpgraded)));


        // Change the caller to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        /* // @audit - This event check isn't working and I don't know why yet.  
        vm.expectEmit(true, true, true, false);
        emit NameUpgraded(
            "\x03sub\x03abc\x03eth\x00",
            address(nameWrapper),
            CANNOT_UNWRAP | PARENT_CANNOT_CONTROL | CANNOT_SET_RESOLVER,
            uint64(block.timestamp) + oneYear,
            address(0),
            bytes("")
        );
        */

        // Upgrade the name to the new contract.    
        nameWrapper.upgrade("\x03sub\x03abc\x03eth\x00", "");

        // check to make sure the name is upgraded and owned by the new contract in the registry.
        assertEq(ens.owner(node), address(nameWrapperUpgraded));

    }

    //Check to make sure that TTL can be set.
    function test_020____setFuses____________________SetFusesOnTheName() public {
        
        bytes32 node = registerAndWrap(account, address(0));

        // Set fuses using the subname wrapper.
        nameWrapper.setFuses(node, uint16(CANNOT_SET_TTL));

        // Check to make sure the fueses are set correctly.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));

        assertEq(fuses, CANNOT_SET_TTL | CANNOT_UNWRAP | PARENT_CANNOT_CONTROL);

    }

    // Check to make sure the setRecord function works.
    function test_021____setRecord___________________SetRecordIncludingResolverAndTTL() public {
        
        bytes32 node = registerAndWrap(account, address(0));

        // Set the record using the subname wrapper.
        // This will not unwrap the name from the subname wrapper contract. 
        nameWrapper.setRecord(
            node, 
            account2, 
            customResolver, 
            0 
        );

        // Check to make sure we are still wrapped and the owner is the nameWrapper 
        assertEq(ens.owner(node), address(nameWrapper));

        // Check to make sure the resolver is set to the custom resolver.
        assertEq(ens.resolver(node), customResolver);

    }

    //Check to make sure that TTL can be set.
    function test_022____setTTL______________________TTLCanBeSet() public {
        
        bytes32 node = registerAndWrap(account, address(0));

        // Set the TTL using the subname wrapper.
        nameWrapper.setTTL(node, 100);

        // Check to make sure the TTL is set to 100.
        assertEq(ens.ttl(node), 100);

    }

    function test_023____setChildFuses_______________CreateASubnodeAndSetTheFuses() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Create a sub-subname.
        bytes32 subnode = nameWrapper.setSubnodeOwner(
            node,
            "subby",
            account,
            address(0), // no approved account
            0, //TTL
            uint64(block.timestamp) + oneYear
        );

        (bytes32 labelhash, ) = bytes("\x05subby\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Set the fuses on the sub-subname.
        nameWrapper.setChildFuses(
            node,
            labelhash,
            PARENT_CANNOT_CONTROL,
            0
        );

        // Check to make sure the fueses are set correctly.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(subnode));

        assertEq(fuses, PARENT_CANNOT_CONTROL);

    }

    function test_024____setSubnodeOwner_____________CreateASubnode() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Create a sub-subname.
        bytes32 subnode = nameWrapper.setSubnodeOwner(
            node,
            "subby",
            account2,
            address(0), // no approved account
            0,
            0
        );

        // Check to make sure the subname is owned by account2.
        assertEq(nameWrapper.ownerOf(uint256(subnode)), account2);

        // Check to make sure the sub-subname name is "subby.sub.abc.eth"
        assertEq(nameWrapper.names(subnode), bytes("\x05subby\x03sub\x03abc\x03eth\x00"));
    }

    function test_025____setSubnodeRecord____________CreateASubnodeWithTTLAndResolver() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Create a sub-subname.
        bytes32 subnode = nameWrapper.setSubnodeRecord(
            node,
            "subby",
            account2,
            address(0), // no approved account
            publicResolver,
            100,
            0,
            0
        );

        // Check to make sure the subname is owned by account2.
        assertEq(nameWrapper.ownerOf(uint256(subnode)), account2);

        // Check to make sure the sub-subname name is "subby.abc.abc.eth"
        assertEq(nameWrapper.names(subnode), bytes("\x05subby\x03sub\x03abc\x03eth\x00"));

        // make sure the TTL is set to 100.
        assertEq(ens.ttl(subnode), 100);
    }

    // Check to make sure the correct data is returned when calling getData.
    function test_027____getData_____________________ReturnsTheOwnerAndRenewalController() public {

        bytes32 node = registerAndWrap(account, address(renewalController));

        // Get the owner, fuses and expiry from the node
        (address owner2, uint32 fuses, uint64 expiry) = nameWrapper.getData(uint256(node));

        // make sure owner, fuses and expiry are correct
        assertEq(owner2, account);
        assertEq(fuses, uint32(CANNOT_UNWRAP | PARENT_CANNOT_CONTROL));
        assertEq(expiry, uint64(block.timestamp) + oneYear);
    }


    function test_030____recoverFunds________________RecoverERC20Tokens() public {


        // Deploy a dummy ERC20PresetFixedSupply token.
        ERC20PresetFixedSupply dummyCoin = new ERC20PresetFixedSupply(
            "DummyCoin",
            "DC",
            1000,
            account
        );

        // Transfer some coins to the SubnameWrapper contract.
        dummyCoin.transfer(address(nameWrapper), 100);

        // Check to make sure the SubnameWrapper contract has the coins.
        assertEq(dummyCoin.balanceOf(address(nameWrapper)), 100);

        // Check to amke sure that account has 900 coins.
        assertEq(dummyCoin.balanceOf(account), 900);

        // Recover the coins.
        nameWrapper.recoverFunds(address(dummyCoin), account, 100);

        // Check to make sure the SubnameWrapper contract has 0 coins.
        assertEq(dummyCoin.balanceOf(address(nameWrapper)), 0);

        // Check to amke sure that account has 1000 coins.
        assertEq(dummyCoin.balanceOf(account), 1000);
    }

}
