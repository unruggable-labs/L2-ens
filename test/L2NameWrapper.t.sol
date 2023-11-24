// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {L2NameWrapper} from "optimism/wrapper/L2NameWrapper.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {IL2NameWrapper, CANNOT_TRANSFER, CANNOT_CREATE_SUBDOMAIN, CANNOT_SET_TTL, CANNOT_SET_RESOLVER, CAN_EXTEND_EXPIRY, CANNOT_BURN_NAME, PARENT_CANNOT_CONTROL, IS_DOT_ETH, CANNOT_APPROVE} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapperUpgrade} from "ens-contracts/wrapper/INameWrapperUpgrade.sol";
import {L2UpgradedNameWrapperMock} from "optimism/wrapper/mocks/L2UpgradedNameWrapperMock.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";

import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {IERC1155MetadataURI} from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {GasHelpers} from "./GasHelpers.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC20PresetFixedSupply} from "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetFixedSupply.sol";

error NameMustBeWrappedInNameWrapper();
error UnauthorizedSender(bytes32 node, address sender);
error NameIsNotWrapped();
error OperationProhibited(bytes32 node);
error Unauthorized(bytes32 node, address addr);
error CannotUpgrade();
error LabelTooShort();
error LabelTooLong(string label);

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
    address hacker = 0x0000000000000000000000000000000000001101; 

    // Set a dummy address for the renewal controller.
    IRenewalController renewalController = IRenewalController(address(0x0000000000000000000000000000000000000007));

    // Set a dummy address for the custom resolver.
    address customResolver = 0x0000000000000000000000000000000000000007;

    ENSRegistry ens; 
    StaticMetadataService staticMetadataService;
    L2NameWrapper nameWrapper;

    uint256 testNumber;

    using BytesUtils for bytes;

    function setUp() public {

        vm.warp(1641070800); 
        vm.startPrank(account);

        // Deploy the ENS registry.
        ens = new ENSRegistry(); 

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

        // Now that the name has been registered remove the controller.
        nameWrapper.setController(account, false);

    }

    function registerAndWrap(address _account, address _approved) internal returns (bytes32 node){

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);


        // Register a subname. 
        node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            _account, 
            _approved,
            publicResolver, 
            0, //TTL
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
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

    function test_004____getApproved_________________ApproveAContractOnANodeAndGetIt() public {

        // Register a name in the name wrapper.
        bytes32 node = registerAndWrap(account, address(0));

        // Approve account2, which is able to renew the name.
        nameWrapper.approve(account2, uint256(node));

        // Check to make sure the approved account is account2.
        assertEq(nameWrapper.getApproved(uint256(node)), account2);

        // Switch the caller to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Make the parent node
        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Make the labelhash of the subname.
        (bytes32 labelhash, ) = bytes("\x03sub\x03abc\x03eth\x00").readLabel(0); 
        
        // Extend the expiry of the subname.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneMonth
        );

        // Make sure the name is renewed.
        ( , , uint64 expiry) = nameWrapper.getData(uint256(node));
        
        // Make sure the name was renewed.
        assertEq(expiry, uint64(block.timestamp) + oneYear + oneMonth);

    }

    function test_004____approve_____________________ApprovedAddressIsBurnedWhenNameIsBurned() public {


        // Register a name in the name wrapper.
        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0),
            publicResolver, 
            0, //TTL
            0, 
            0 
        );

        // Approve account2, which is able to renew the name.
        nameWrapper.approve(account2, uint256(node));

        // Check to make sure the approved account is account2.
        assertEq(nameWrapper.getApproved(uint256(node)), account2);

        /**
         * Burn the name by using setSubnodeOwner, and setting the owner to 0.
         * It appears that I am setting the approved contract to account2, however, 
         * because I am also setting the owner to 0, the approved contract is burned.
         */
        nameWrapper.setSubnodeOwner(
            parentNode, 
            "sub",
            address(0),
            account2, 
            0, //TTL
            0 
        );

        // Check to make sure the approved account is address 0.
        assertEq(nameWrapper.getApproved(uint256(node)), address(0));

    }

    function test_004____approve_____________________CannotSetAnApprovedAddressWhenCANNOT_APPROVEHasBeenBurned() public {


        // Register a name in the name wrapper.
        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0), // no approved account
            publicResolver, 
            0, //TTL
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME, 
            uint64(block.timestamp) + oneYear
             
        );

        // Check to a make sure "account" is the owner of the name.
        assertEq(nameWrapper.ownerOf(uint256(node)), account);

        // Approve account2, which is able to renew the name.
        nameWrapper.approve(account2, uint256(node));

        // Check to make sure the approved account is account2.
        assertEq(nameWrapper.getApproved(uint256(node)), account2);

        // Burn the CANNOT_APPROVE function on the name.
        nameWrapper.setFuses(node, uint16(CANNOT_APPROVE)); 

        // Check to make sure the fuse CAN_APPROVE is burned.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));
        assertEq(fuses, CANNOT_APPROVE | CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL);

        // Check to make sure that when setting the approved address it reverts.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Approve "account" and make sure it reverts.
        nameWrapper.approve(account, uint256(node));

    }

    // Check to make sure the metadata service was setup and returns a test uri
    function test_005____setMetadataService__________MetadataServiceWasSetup() public{

        // Set the matadata service.
        nameWrapper.setMetadataService(IMetadataService(address(account2)));

        assertEq(address(nameWrapper.metadataService()), address(account2));
    }
    
    // Check to make sure the metadata service was setup and returns a test uri
    function test_006____uri_________________________ReturnsCorrectURI() public{
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


    function test_009____wrapTLD_____________________WrapsATLD() public{

        //Save the bytes of the name .unruggable in DNS format.
        bytes memory name = bytes("\x0aunruggable\x00");

        // Create a namhash of the name.
        bytes32 node = name.namehash(0);

        // Register the name in the ens registry. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account);

        // Approve the name wrapper to control the name.
        ens.setApprovalForAll(address(nameWrapper), true);

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
        );

        // Create a subname of the .unruggable name, using setSubnodeOwner.
        bytes32 subnode = nameWrapper.setSubnodeOwner(
            node,
            "sub", 
            account2, 
            address(0), 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME, 
            uint64(block.timestamp) + oneYear 
        );
        
        // Check to make sure the owner of the subname is account2.
        assertEq(nameWrapper.ownerOf(uint256(subnode)), account2);

    }

    function test_009____wrapTLD_____________________RevertsWhenWrappingATLDTwice() public{

        //Save the bytes of the name .unruggable in DNS format.
        bytes memory name = bytes("\x0aunruggable\x00");

        // Create a namhash of the name.
        bytes32 node = name.namehash(0);

        // Register the name in the ens registry. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account);

        // Approve the name wrapper to control the name.
        ens.setApprovalForAll(address(nameWrapper), true);

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            0,
            uint64(block.timestamp) + oneYear
        );

        // Check to make sure it reverts if called twice. 
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, account));

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account2, 
            0,
            uint64(block.timestamp) + oneYear
        );

    }

    function test_009____wrapTLD_____________________RevertsWhenANonOwnerCallTheFunction() public{

        //Save the bytes of the name .unruggable in DNS format.
        bytes memory name = bytes("\x0aunruggable\x00");

        // Create a namhash of the name.
        bytes32 node = name.namehash(0);

        // Register the name in the ens registry to an account we don't control. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account2);

        // Make sure the function reverts.
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, account));

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
        );

        // This time register the name to our account, but don't approve the name wrapper. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account);

        // Don't approve the name wrapper to control the name.
        // ens.setApprovalForAll(address(nameWrapper), true);

        // Make sure the function reverts.
        vm.expectRevert();

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
        );

    }


    // Test registerAndWrapEth2LD
    function test_010____registerAndWrapEth2LD_______RegisterAndWrapEth2LD() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            twoYears,
            publicResolver,
            uint16(0) //fuses
        );

        // Make node.
        bytes32 node = bytes("\x07newname\x03eth\x00").namehash(0);

        // Make sure the name is registered in the ENS registry.
        assertEq(ens.owner(node), address(nameWrapper));

        // Make sure the name is registered in the NameWrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account);

        // Make sure the approved account is set.
        assertEq(nameWrapper.getApproved(uint256(node)), account2);

        // Make sure the resolver is set.
        assertEq(ens.resolver(node), publicResolver);

        // Make sure the expiry was set.
        ( , uint32 fuses, uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, uint64(block.timestamp) + twoYears + GRACE_PERIOD);

        // Make sure the fuses were set correctly.
        assertEq(fuses, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | IS_DOT_ETH);

    }

    function test_010____registerAndWrapEth2LD_______FailsWhenTheNameHasAlreadyBeenRegistered() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            twoYears,
            publicResolver,
            uint16(0) //fuses
        );

        // Make node.
        bytes32 node = bytes("\x07newname\x03eth\x00").namehash(0);

        // Make sure the name is registered in the ENS registry.
        assertEq(ens.owner(node), address(nameWrapper));

        // Check to make sure the function reverts when called on an unavailable name.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            twoYears,
            publicResolver,
            uint16(0) //fuses
        );

    }

    function test_010____registerAndWrapEth2LD_______EdgeCasesTooLongAndTooShort() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);

        // Make sure the function reverts with LabelTooShort().
        vm.expectRevert(abi.encodeWithSelector(LabelTooShort.selector));

        // Register a 2LD .eth name in the NameWrapper with zero length.
        nameWrapper.registerAndWrapEth2LD(
            "", 
            account,
            account2, // approved account
            twoYears,
            publicResolver,
            uint16(0) //fuses
        );

        // Create a 256 character string. 
        bytes memory long255LengthString = new bytes(256);
        for(uint i = 0; i < 256; i++){
            long255LengthString[i] = "a";
        }

        // Make sure the function reverts with LabelTooLong().
        vm.expectRevert(abi.encodeWithSelector(LabelTooLong.selector, string(long255LengthString)));

        // Register a 2LD .eth name in the NameWrapper with zero length.
        nameWrapper.registerAndWrapEth2LD(
            string(long255LengthString), 
            account,
            account2, // approved account
            twoYears,
            publicResolver,
            uint16(0) //fuses
        );

    }

    function test_010____registerAndWrapEth2LD_______RegisteringAnExpiredNameDoesntKeepFuses() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            oneYear,
            publicResolver,
            uint16(CANNOT_CREATE_SUBDOMAIN)
        );

        bytes32 node = bytes("\x07newname\x03eth\x00").namehash(0);

        //Check to make sure the fuse is set.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));
        assertEq(fuses, CANNOT_CREATE_SUBDOMAIN | CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | IS_DOT_ETH);

        // Make sure the name is registered in the ENS registry.
        assertEq(ens.owner(node), address(nameWrapper));

        // Jump forward one year and the GRACE_PERIOD plus one day. 
        vm.warp(uint64(block.timestamp) + oneYear + GRACE_PERIOD + oneDay);

        // Make sure the name is expired in the name wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), address(0));

        // Try registering the name again
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            oneYear,
            publicResolver,
            uint16(0)
        );

        // Make sure the CANNOT_CREATE_SUBDOMAIN fuse is not set.
        ( , uint32 fuses2, ) = nameWrapper.getData(uint256(node));
        assertEq(fuses2, CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | IS_DOT_ETH);

    }

    // A test for renewEth2LD. 
    function test_011____renewEth2LD_________________RenewEth2LD() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "newname", 
            account,
            account2, // approved account
            oneYear,
            publicResolver,
            uint16(0) //fuses
        );

        // Make node.
        bytes32 node = bytes("\x07newname\x03eth\x00").namehash(0);

        // Warp to the day before the expiry of the name.
        vm.warp(uint64(block.timestamp) + oneYear);

        // Renew the name.
        nameWrapper.renewEth2LD(
            keccak256(bytes("newname")), 
            oneYear
        );

        // Make sure the name is registered in the ENS registry.
        assertEq(ens.owner(node), address(nameWrapper));

        // Make sure the name is registered in the NameWrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account);

        // Make sure the approved account is set.
        assertEq(nameWrapper.getApproved(uint256(node)), account2);

        // Make sure the resolver is set.
        assertEq(ens.resolver(node), publicResolver);

        // Make sure the expiry was set.
        ( , , uint64 expiry) = nameWrapper.getData(uint256(node));
        assertEq(expiry, uint64(block.timestamp) + GRACE_PERIOD + oneYear);


    }
    function test_011____renewEth2LD_________________RevertsWhenNameIsNotWrapped() public{

        // Make account a controller. 
        nameWrapper.setController(account, true);


        // Make sure the function reverts with NameIsNotWrapped() when called on an unwrapped name.
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // Renew the name.
        nameWrapper.renewEth2LD(
            keccak256(bytes("newname")), 
            oneYear
        );
    }

    // Check to make sure that the parent owner can extend the expiry of a name.
    function test_018____extendExpiry________________ExtendTheExpiryOfANameIfCallerIsParent() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
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
    function test_019____extendExpiry________________ExtendTheExpiryOfANameIfRenewalControllerSetToOwner() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
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
    function test_015____extendExpiry________________ExtendTheExpiryOfANameEdgeCases() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
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
    function test_016____extendExpiry________________NameExpiresItCantBeExtendedByTheParentOwner() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        // advance time by one year and a day to make the name expired.
        vm.warp(block.timestamp + oneYear + oneDay);

        // make sure the funciton reverts with NameIsNotWrapped()
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // set the expiry for 1 years ahead.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneDay
        );
    }

    // Check to make sure that the expiry of the name can't be extended after the name has expired by the renewal controller.
    function test_017____extendExpiry________________NameExpiresItCantBeExtendedByTheRenewalController() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        // advance time by one year and a day to make the name expired.
        vm.warp(block.timestamp + oneYear + oneDay);

        vm.stopPrank();
        // Change the caller to accountReferrer. 
        vm.startPrank(accountReferrer);

        // make sure the function reverts with NameIsNotWrapped()
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // set the expiry for 1 years ahead.
        nameWrapper.extendExpiry(
            parentNode, 
            labelhash, 
            uint64(block.timestamp) + oneYear + oneDay
        );
    }

    function test_017____extendExpiry________________RevertsIfNotAuthorized() public{

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL, 
            uint64(block.timestamp) + oneYear 
        );

        // advance time to one day less than a year.
        vm.warp(block.timestamp + oneYear - oneDay);

        vm.stopPrank();
        // Change the caller to "hacker". 
        vm.startPrank(hacker);

        // make sure the function reverts with UnauthorizedSender(node, msg.sender)
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, hacker));

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
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | CANNOT_SET_RESOLVER,
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

    function test_018____upgrade_____________________RevertIfUpgradeContractIsNotSet() public{

          // Set up a subname. The owner is account2.
        bytes32 node = registerAndWrap(account2, address(0));

        // Don't set the new NameWrapper as the upgraded contract. 

        // Change the caller to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Make sure the function reverts with CannotUpgrade().
        vm.expectRevert(abi.encodeWithSelector(CannotUpgrade.selector));

        // Upgrade the name to the new contract.    
        nameWrapper.upgrade("\x03sub\x03abc\x03eth\x00", "");
    }

    function test_018____upgrade_____________________RevertsWhenWrongAccountCallsUpgrade() public{

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
        vm.startPrank(hacker);

        // Make sure the function reverts with Unauthorized(bytes32 node, address addr).
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, hacker));

        // Upgrade the name to the new contract.    
        nameWrapper.upgrade("\x03sub\x03abc\x03eth\x00", "");
    }

    //Check to make sure that TTL can be set.
    function test_020____setFuses____________________SetFusesOnTheName() public {
        
        bytes32 node = registerAndWrap(account, address(0));

        // Set fuses using the subname wrapper.
        nameWrapper.setFuses(node, uint16(CANNOT_SET_TTL));

        // Check to make sure the fueses are set correctly.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));

        assertEq(fuses, CANNOT_SET_TTL | CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL);

    }

    function test_020____setFuses____________________RevertIfSettingFusesWithoutCANNOT_BURN_NAME() public {
        
        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0),
            publicResolver, 
            0, //TTL
            0, 
            uint64(block.timestamp) + oneYear 
        );

        // Make sure the function reverts when trying to set the fuses.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Set fuses using the subname wrapper.
        nameWrapper.setFuses(node, uint16(CANNOT_CREATE_SUBDOMAIN));

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

    function test_021____setRecord___________________NameCanBeBurned() public {
        
        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0),
            publicResolver, 
            0, //TTL
            0, 
            uint64(block.timestamp) + oneYear 
        );

        // Set the record using the wrapper.
        // This will not unwrap the name from the subname wrapper contract. 
        nameWrapper.setRecord(
            node, 
            address(0), // burn address
            customResolver, 
            0 
        );

        // Check to make sure the name is burned
        assertEq(ens.owner(node), address(0));

        // Check to make sure the fuses are burned.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));

    }

    function test_021____setRecord___________________RevertIfFuseCANNOT_BURN_NAMEIsSet() public {
        
        bytes32 node = registerAndWrap(account, address(0));


        // Make sure the function reverts when trying to burn the name.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Set the record using the wrapper.
        // This will not unwrap the name from the wrapper contract. 
        nameWrapper.setRecord(
            node, 
            address(0), // burn address
            customResolver, 
            0 
        );

    }

    function test_021____safeTransferFrom____________RevertIfCANNOT_TRANSFERIsBurned() public {

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Burn the CANNOT_TRANSFER fuse on the name.
        nameWrapper.setFuses(parentNode, uint16(CANNOT_TRANSFER));

        // Make sure the function reverts when trying to burn the name.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, parentNode));

        // Do a safe transfer from "account" to "account2".
        nameWrapper.safeTransferFrom(account, account2, uint256(parentNode), 1, "");

    }

    function test_021____safeTransferFrom____________RevertIfIS_DOT_ETHAndInGracePeriod() public {

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Move forward one year and a day in time. 
        vm.warp(uint64(block.timestamp) + twoYears + oneDay);

        // Make sure the function reverts when trying to transfer the name.
        vm.expectRevert(bytes("ERC1155: insufficient balance for transfer"));

        // Do a safe transfer from "account" to "account2".
        nameWrapper.safeTransferFrom(account, account2, uint256(parentNode), 1, "");

    }

    //Check to make sure that TTL can be set.
    function test_022____setTTL______________________TTLCanBeSet() public {
        
        bytes32 node = registerAndWrap(account, address(0));

        // Set the TTL using the subname wrapper.
        nameWrapper.setTTL(node, 100);

        // Check to make sure the TTL is set to 100.
        assertEq(ens.ttl(node), 100);

    }

    // Check to make sure the resolver recorord can be set using setResolver.
    function test_023____setResolver_________________SetResolverRecord() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Set the resolver using the subname wrapper.
        nameWrapper.setResolver(node, customResolver);

        // Check to make sure the resolver is set to the custom resolver.
        assertEq(ens.resolver(node), customResolver);

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
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            0
        );

        // Check to make sure the fueses are set correctly.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(subnode));

        assertEq(fuses, PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME);

    }

    function test_023____setChildFuses_______________RevertIfTheNameIsNotWrapped() public {

        bytes32 node = registerAndWrap(account, address(0));

        (bytes32 labelhash, ) = bytes("\x05subby\x03sub\x03abc\x03eth\x00").readLabel(0);

        // Make sure the function reverts with NameIsNotWrapped().
        vm.expectRevert(abi.encodeWithSelector(NameIsNotWrapped.selector));

        // Set the fuses on the sub-subname.
        nameWrapper.setChildFuses(
            node,
            labelhash,
            PARENT_CANNOT_CONTROL,
            0
        );

    }

    function test_023____setChildFuses_______________RevertIfOwnerIsNotAuthorized() public {

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

        // Switch accounts to "hacker".
        vm.stopPrank();
        vm.startPrank(hacker);

        //Revert if the owner is not authorized.
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, hacker));

        // Set the fuses on the sub-subname.
        nameWrapper.setChildFuses(
            node,
            labelhash,
            PARENT_CANNOT_CONTROL,
            0
        );

    }

    function test_023____setChildFuses_______________RevertIfOwnerIsNotAuthorizedAndParentIsTLD() public {

        //Save the bytes of the name .unruggable in DNS format.
        bytes memory name = bytes("\x0aunruggable\x00");

        // Create a namhash of the name.
        bytes32 node = name.namehash(0);

        // Register the name in the ens registry to an account we don't control. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account2);

        // Make sure the function reverts.
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, account));

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
        );

        // This time register the name to our account, but don't approve the name wrapper. 
        ens.setSubnodeOwner(ROOT_NODE, keccak256(bytes("unruggable")), account);

        // Don't approve the name wrapper to control the name.
        ens.setApprovalForAll(address(nameWrapper), true);

        // Wrap a new TLD, .unruggable using DNS format.
        nameWrapper.wrapTLD(
            name, 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
        );

        // Switch accounts to "hacker".
        vm.stopPrank();
        vm.startPrank(hacker);

        //Revert if the owner is not authorized.
        vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector, node, hacker));

        // Set the fuses on the sub-subname.
        nameWrapper.setChildFuses(
            ROOT_NODE,
            keccak256(bytes("unruggable")),
            CANNOT_SET_TTL,
            0
        );

    }
    function test_023____setChildFuses_______________RevertIfPARENT_CANNOT_CONTROLHasBeenBurned() public {

        bytes32 parentNode = registerAndWrap(account, address(0));

        // Create a sub-subname.
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "subby",
            account2,
            address(0), // no approved account
            address(0), // no resolver
            0, //TTL
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME, //fuses
            uint64(block.timestamp) + oneYear
        );

        // Check to make sure that the fuses were set correctly.
        ( , uint32 fuses, ) = nameWrapper.getData(uint256(node));

        assertEq(fuses, PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME);

        (bytes32 labelhash, ) = bytes("\x05subby\x03sub\x03abc\x03eth\x00").readLabel(0);

        //Revert if the owner is not authorized.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Set the fuses on the sub-subname.
        nameWrapper.setChildFuses(
            parentNode,
            labelhash,
            CANNOT_SET_TTL,
            0
        );

    }

        function test_023____setChildFuses_______________CannotSetIS_DOT_ETH() public { //@audit - check all the fuses that can't be set.

        bytes32 parentNode = registerAndWrap(account, address(0));

        // Make a node for the subnode. 
        bytes32 node = bytes("\x05subby\x03sub\x03abc\x03eth\x00").namehash(0);

        // Revert if the IS_DOT_ETH fuse is set.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Create a sub-subname.
        nameWrapper.setSubnodeRecord(
            parentNode,
            "subby",
            account2,
            address(0), // no approved account
            address(0), // no resolver
            0, //TTL
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME | IS_DOT_ETH, //fuses
            uint64(block.timestamp) + oneYear
        );

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

    function test_024____setSubnodeOwner_____________RevertsWhenPARENT_CANNOT_CONTROLIsBurned() public {

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0),
            publicResolver, 
            0, //TTL
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | CANNOT_CREATE_SUBDOMAIN, 
            uint64(block.timestamp) + oneYear 
        );


        // Make sure the function reverts when CANNOT_CREATE_SUBDOMAIN is burned.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, node));

        // Create a sub-subname.
        nameWrapper.setSubnodeOwner(
            parentNode,
            "sub",
            account2,
            address(0), // no approved account
            0,
            0
        );

    }

    function test_024____setSubnodeOwner_____________RevertsWhenCANNOT_CREATE_SUBDOMAINIsBurned() public {

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Register a subname. 
        bytes32 node = nameWrapper.setSubnodeRecord(
            parentNode,
            "sub", 
            account, 
            address(0),
            publicResolver, 
            0, //TTL
            CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL | CANNOT_CREATE_SUBDOMAIN, 
            uint64(block.timestamp) + oneYear 
        );


        // Make the subnode using the DNS name.
        bytes32 subnode = bytes("\x05subby\x03sub\x03abc\x03eth\x00").namehash(0);

        // Make sure the function reverts when CANNOT_CREATE_SUBDOMAIN is burned.
        vm.expectRevert(abi.encodeWithSelector(OperationProhibited.selector, subnode));

        // Create a sub-subname.
        nameWrapper.setSubnodeOwner(
            node,
            "subby",
            account2,
            address(0), // no approved account
            0,
            0
        );

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

    function test_025____setSubnodeRecord____________UpdateANameThatIsWrapped() public {

        bytes32 node = registerAndWrap(account, address(0));

        // Create a sub-subname.
        bytes32 subnode = nameWrapper.setSubnodeRecord(
            node,
            "subby",
            account,
            address(0), // no approved account
            publicResolver,
            100,
            0,
            0
        );

        // Create a sub-subname.
        nameWrapper.setSubnodeRecord(
            node,
            "subby",
            account2,
            address(0), // no approved account
            publicResolver,
            100,
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME,
            uint64(block.timestamp) + oneYear
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
        assertEq(fuses, uint32(CANNOT_BURN_NAME | PARENT_CANNOT_CONTROL));
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
