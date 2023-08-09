// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {L2SubnameRegistrar, UnauthorizedAddress} from "optimism/wrapper/L2SubnameRegistrar.sol";
import {ISubnameRegistrar} from "contracts/subwrapper/interfaces/ISubnameRegistrar.sol";
import {L2NameWrapper} from "optimism/wrapper/L2NameWrapper.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {L2PublicResolver} from "optimism/resolvers/L2PublicResolver.sol";
import {IL2NameWrapper, CANNOT_UNWRAP} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {USDOracleMock} from "contracts/subwrapper/mocks/USDOracleMock.sol";
import {IRenewalController} from "contracts/subwrapper/interfaces/IRenewalController.sol";

import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {GasHelpers} from "./GasHelpers.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

error UnexpiredCommitmentExists(bytes32 commitment);
error ZeroLengthLabel();
error InvalidDuration(uint256 duration);

contract SubnameRegistrarTest is Test, GasHelpers {

    uint64 private constant GRACE_PERIOD = 90 days;
    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_LABELHASH =
        0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 private constant ROOT_NODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    string MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/_YutYRi0sYLsh44jlBvM7QgDOcK-JhtY";
    uint64 twoYears = 63072000; // aprox. 2 years
    uint64 oneYear = 31536000; // A year in seconds.
    uint64 oneMonth = 2592000; // A month in seconds.
    uint64 oneDay = 86400; // A day in seconds.
    address account = 0x0000000000000000000000000000000000003511;
    address account2 = 0x0000000000000000000000000000000000004612;
    address accountReferrer = 0x0000000000000000000000000000000000005627;

    // Set a dummy address for the renewal controller.
    IRenewalController renewalController = IRenewalController(address(0x0000000000000000000000000000000000000007));

    // Set a dummy address for the custom resolver.
    address customResolver = 0x0000000000000000000000000000000000000007;

    ENSRegistry ens; 
    StaticMetadataService staticMetadataService;
    L2NameWrapper nameWrapper;
    L2PublicResolver publicResolver;
    L2SubnameRegistrar subnameRegistrar;
    USDOracleMock usdOracle;

    uint256 testNumber;

    using BytesUtils for bytes;

    function setUp() public {

        vm.roll(16560244);
        vm.warp(1675571853);

        vm.startPrank(account);
        vm.deal(account, 340282366920938463463374607431768211456);

        // Deploy the ENS registry.
        ens = new ENSRegistry(); 

        // Deploy a metadata service.
        staticMetadataService = new StaticMetadataService("testURI");

        usdOracle = new USDOracleMock();

        // Deploy the name wrapper. 
        nameWrapper = new L2NameWrapper(
            ens, 
            IMetadataService(address(staticMetadataService))
        );

        // Set up .eth in the ENS registry.
        ens.setSubnodeOwner(ROOT_NODE, ETH_LABELHASH, address(nameWrapper));
        assertEq(ens.owner(ETH_NODE), address(nameWrapper));

        // Approve the name wrapper as a controller of the ENS registry.
        // ens.setApprovalForAll(address(nameWrapper), true); // @audit - this is not needed.

        // Deploy the public resolver.
        //@audit - for some reason this doesn't work when I removed the reverse registrar.
        publicResolver = new L2PublicResolver(ens, nameWrapper, address(0));

        // Deploy the Subname Registrar.
        subnameRegistrar = new L2SubnameRegistrar(
            60, //one minute
            604800, //one week
            ens,
            nameWrapper,
            usdOracle
        );

        // Allow the "account" to register names in the name wrapper.
        nameWrapper.setController(account, true);

        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "abc", 
            account,
            address(0), //no approved contract
            twoYears,
            address(publicResolver),
            uint16(CANNOT_UNWRAP)
        );

        // Revoke the approval for "account".
        nameWrapper.setController(account, false);

        // In order to register subnames using the L2 subname wrapper, the owner of the 
        // parent name "account" needs to approve all for the subname wrapper in the name wrapper.  
        nameWrapper.setApprovalForAll(address(subnameRegistrar), true);
    }

    function registerAndWrap(address _account) internal returns (bytes32){

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        (bytes32 labelhash, ) = bytes("\x03abc\x03eth\x00").readLabel(0);

        // Add the parentNode to the allow list.
        subnameRegistrar.allowName(bytes("\x03abc\x03eth\x00"), true);

        // Set the registration parameters for subnames of the parent name.
        subnameRegistrar.setParams(
            parentNode, 
            true, 
            IRenewalController(address(subnameRegistrar)), 
            3600, 
            type(uint64).max,
            1, 
            255 
        );

        // Set the pricing for the subname registrar. 
        // Not that there are 4 elements, but only the fist three have been defined. 
        // This has been done to make sure that nothing breaks even if one is not defined. 
        uint256[] memory charAmounts = new uint256[](4);
        charAmounts[0] = 158548959918; // (≈$5/year) calculated as $/sec with 18 decimals.
        charAmounts[1] = 158548959918;
        charAmounts[2] = 0;

        subnameRegistrar.setPricingForAllLengths(
            parentNode, 
            charAmounts
        );

        // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(_account);
        vm.deal(_account, 10000000000000000000);

        bytes32 commitment = subnameRegistrar.makeCommitment(
            "\x03xyz\x03abc\x03eth\x00", 
            _account, 
            bytes32(uint256(0x4453))
        );

        subnameRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x03xyz\x03abc\x03eth\x00",
            _account,
            account, //referrer
            oneYear,
            bytes32(uint256(0x4453)), 
            address(publicResolver), 
            0 /* fuses */
        );

        vm.stopPrank();
        vm.startPrank(account);

        return bytes("\x03xyz\x03abc\x03eth\x00").namehash(0);

    }
    // Create a Subheading using an empty function.
    function test1000_________________________________________________________________________() public {}
    function test2000_______________________L2_SUBNAME_REGISTRAR_FUNCTIONS____________________() public {}
    function test3000_________________________________________________________________________() public {}

    //Check to make sure the subname wrapper contract supports interface detection. 
    function test_001____supportsInterface___________SupportsCorrectInterfaces() public {

        // Check for the ISubnameWrapper interface.  
        assertEq(subnameRegistrar.supportsInterface(type(ISubnameRegistrar).interfaceId), true);

        // Check for the IERC165 interface.  
        assertEq(subnameRegistrar.supportsInterface(type(IERC165).interfaceId), true);
    }

    function test_002____rentPrice___________________RentPriceWasSetCorrectly() public{


        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        // Check to make sure the subname was wrapped and account2 is the owner. 
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);

        // Check to make sure the renewal controller is set up. 
        address _renewalController = nameWrapper.getApproved(uint256(node));
        assertEq(_renewalController, address(subnameRegistrar));

        // Get the price for renewing the domain for a year. 
        (uint256 weiAmount,) = subnameRegistrar.rentPrice(
            bytes("\x03xyz\x03abc\x03eth\x00"), 
            oneYear 
        );

        // USD price of Eth from the oracle.
        int256 ethPrice = usdOracle.latestPrice();
        // Check to make sure the price is around $5/year.
        uint256 expectedPrice = 5 * 10**26/uint256(ethPrice);

        // make sure the price is close to the expected price.
        assertTrue(weiAmount/10**10 == expectedPrice/10**10);
    }

    function test_003____allowName___________________ANameCanBeAddedAndRemovedFromTheAllowList() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        // Expect to revert if the name is not allowed with a custom error UnauthorizedAddress
        vm.expectRevert( abi.encodeWithSelector(UnauthorizedAddress.selector, parentNode));

        subnameRegistrar.setParams(
            parentNode, 
            false, 
            renewalController, 
            3601, 
            type(uint64).max,
            2, 
            254
        );

        subnameRegistrar.allowName(bytes("\x03abc\x03eth\x00"),true);

        assertEq(subnameRegistrar.allowList(parentNode), true);

        subnameRegistrar.setParams(
            parentNode, 
            false, 
            renewalController, 
            3601, 
            type(uint64).max,
            2, 
            254
        );

        // Check to make sure the params have been set correctly. 
        (   bool _offerSubames, 
            IRenewalController _renewalController, 
            uint64 _minRegistrationDuration, 
            uint64 _maxRegistrationDuration,
            uint16 _minChars, 
            uint16 _maxChars
        ) = subnameRegistrar.pricingData(parentNode);

        assertEq(_offerSubames, false);
        assertEq(address(_renewalController), address(renewalController));
        assertEq(_minRegistrationDuration, 3601);
        assertEq(_maxRegistrationDuration, type(uint64).max);
        assertEq(_minChars, 2);
        assertEq(_maxChars, 254);

    }

    function test_004____disableAllowList____________AllowListCanBeDisabled() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);

        subnameRegistrar.allowName(bytes("\x03abc\x03eth\x00"), false);

        //expect to revert if the name is not allowed with a custom error UnauthorizedAddress
        vm.expectRevert( abi.encodeWithSelector(UnauthorizedAddress.selector, parentNode));

        subnameRegistrar.setParams(
            parentNode, 
            false, 
            renewalController, 
            3601, 
            type(uint64).max,
            2, 
            254
        );

        subnameRegistrar.disableAllowList();

        subnameRegistrar.setParams(
            parentNode, 
            false, 
            renewalController, 
            3601, 
            type(uint64).max,
            2, 
            254
        );

        // Check to make sure the params have been set correctly. 
        (   bool _offerSubames, 
            IRenewalController _renewalController, 
            uint64 _minRegistrationDuration, 
            uint64 _maxRegistrationDuration,
            uint16 _minChars, 
            uint16 _maxChars
        ) = subnameRegistrar.pricingData(parentNode);

        assertEq(_offerSubames, false);
        assertEq(address(_renewalController), address(renewalController));
        assertEq(_minRegistrationDuration, 3601);
        assertEq(_maxRegistrationDuration, type(uint64).max);
        assertEq(_minChars, 2);
        assertEq(_maxChars, 254);

    }

    function test_005____setParams___________________SetTheRegistrationParametersForSubnames() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        subnameRegistrar.setParams(
            parentNode, 
            false, 
            renewalController, 
            3601, 
            type(uint64).max,
            2, 
            254 
        );

        // Check to make sure the params have been set correctly. 
        (   bool _offerSubames, 
            IRenewalController _renewalController, 
            uint64 _minRegistrationDuration, 
            uint64 _maxRegistrationDuration,
            uint16 _minChars, 
            uint16 _maxChars
        ) = subnameRegistrar.pricingData(parentNode);

        assertEq(_offerSubames, false);
        assertEq(address(_renewalController), address(renewalController));
        assertEq(_minRegistrationDuration, 3601);
        assertEq(_maxRegistrationDuration, type(uint64).max);
        assertEq(_minChars, 2);
        assertEq(_maxChars, 254);
    }

    function test_006____setPricingForAllLengths_____SetThePriceForAllLengthsOfNamesAtOneTime() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        // Set the pricing for the subname registrar. 
        // Not that there are 4 elements, but only the fist three have been defined. 
        // This has been done to make sure that nothing breaks even if one is not defined. 
        uint256[] memory charAmounts = new uint256[](4);
        charAmounts[0] = 158548959918; // (≈$5/year) calculated as $/sec with 18 decimals.
        charAmounts[1] = 158548959918;
        charAmounts[2] = 1;

        subnameRegistrar.setPricingForAllLengths(
            parentNode, 
            charAmounts
        );
        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, 0), 158548959918);
        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, 1), 158548959918);
        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, 2), 1);
        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, 3), 0);

    }

    function test_007____getPriceDataForLength_______TheAmontForAnySetLengthOfName() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        // Add a price for the next character (4th character).
        subnameRegistrar.addNextPriceForCharLength(parentNode, 317097919836);
        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, uint16(4)), 317097919836);

    }

    function test_008____updatePriceForCharLength____UpdateThePriceOfANameLength() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        subnameRegistrar.updatePriceForCharLength(parentNode, 3, 317097919836);

        assertEq(subnameRegistrar.getPriceDataForLength(parentNode, 
        uint16(subnameRegistrar.getLastCharIndex(parentNode))), 317097919836);

    }

    function test_009____getLastCharIndex____________ReturnsTheLastIndexOfCharAmounts() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        // Add a price for the next character (4th character).
        subnameRegistrar.addNextPriceForCharLength(parentNode, 317097919836);
        assertEq(subnameRegistrar.getLastCharIndex(parentNode), 4);
    }

    function test_010____setOfferSubnames____________SetOfferSubnamesToFalse() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        // Set the offer subnames to false.
        subnameRegistrar.setOfferSubnames(parentNode, false);

        // Check to make sure the params have been set correctly. 
        (   bool _offerSubames, 
            /*IRenewalController _renewalController*/, 
            /*uint16 _minRegistrarionDuration*/, 
            /*uint64 _maxRegistrationDuration*/,
            /*uint16 _minChars*/, 
            /*uint16 _maxChars*/
        ) = subnameRegistrar.pricingData(parentNode);

        assertEq(_offerSubames, false);

    }

    function test_011____available___________________AvailableToRegister() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        assertEq(subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00")), false);
        assertEq(subnameRegistrar.available(bytes("\x05eeeee\x03abc\x03eth\x00")), true);

        // check if a 32 character name is available.
        assertEq(subnameRegistrar.available(bytes("\x20123456745678asftgesnytfwsdftgnrw\x03abc\x03eth\x00")), true);

        // add an extra null byte to the end of the name.
        vm.expectRevert(bytes("namehash: Junk at end of name"));
        subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00\x00"));

        // Names with spaces are OK.
        assertEq(subnameRegistrar.available(bytes("\x04x yz\x03abc\x03eth\x00")), true);

        // Names with the wrong length of the label in the DNS encoding.
        vm.expectRevert(bytes(""));
        subnameRegistrar.available(bytes("\x05xyz\x03abc\x03eth\x00"));

        // Names with the a zero length of the label in the DNS encoding.
        vm.expectRevert(bytes(""));
        subnameRegistrar.available(bytes("\x00\x03abc\x03eth\x00"));


    }

    function test_012____makeCommitment______________CommitAndRegisterAName() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        assertEq(subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00")), false);
        assertEq(subnameRegistrar.available(bytes("\x08coolname\x03abc\x03eth\x00")), true);

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = subnameRegistrar.makeCommitment(
            "\x08coolname\x03abc\x03eth\x00", 
            account2, 
            bytes32(uint256(0x7878))
        );

        //Check to make sure the commitment is correct.
        bytes32 checkCommitment = keccak256(
                abi.encode(
                    "\x08coolname\x03abc\x03eth\x00", 
                    account2, 
                    bytes32(uint256(0x7878)) 
                )
            );

        assertEq(commitment, checkCommitment);

        subnameRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_013____commit______________________CommitCantBeUsedTwice() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        assertEq(subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00")), false);
        assertEq(subnameRegistrar.available(bytes("\x08coolname\x03abc\x03eth\x00")), true);

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = subnameRegistrar.makeCommitment(
            "\x08coolname\x03abc\x03eth\x00", 
            account2, 
            bytes32(uint256(0x7878))
        );

        subnameRegistrar.commit(commitment);

        // Expect this to revert becuase the commitment has already been used.
        vm.expectRevert( abi.encodeWithSelector(UnexpiredCommitmentExists.selector, commitment));
        subnameRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_014____register____________________RegistersAndWrapsAName() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        assertEq(subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00")), false);
        assertEq(subnameRegistrar.available(bytes("\x08coolname\x03abc\x03eth\x00")), true);

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                subnameRegistrar.register.selector,
                "\x08coolname\x03abc\x03eth\x00",
                account2,
                accountReferrer, //referrer
                oneYear,
                bytes32(uint256(0x7878)), 
                address(publicResolver), 
                new bytes[](0),
                0 /* fuses */
            )
        );

        startMeasuringGas("Gas usage for making the commitment function: ");

        bytes32 commitment = subnameRegistrar.makeCommitment(
            "\x08coolname\x03abc\x03eth\x00", 
            account2, 
            bytes32(uint256(0x7878))
        );

        stopMeasuringGas();

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                subnameRegistrar.commit.selector,
                commitment
            )
        );
        startMeasuringGas("Gas usage for the commit function: ");

        subnameRegistrar.commit(commitment);

        stopMeasuringGas();

        // Expect this to revert becuase the commitment has already been used.
        //vm.expectRevert( abi.encodeWithSelector(UnexpiredCommitmentExists.selector, commitment));
        //subnameRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                subnameRegistrar.register.selector,
                "\x08coolname\x03abc\x03eth\x00",
                account2,
                accountReferrer, //referrer
                oneYear,
                bytes32(uint256(0x7878)), 
                address(publicResolver), 
                new bytes[](0),
                0 /* fuses */
            )
        );
        startMeasuringGas("Gas usage for the register function: ");

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        stopMeasuringGas();

        // Check to make sure the subname is owned account2 in the Name Wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);
        
        vm.stopPrank();
        vm.startPrank(account);

    }
    function test_015____register____________________RegistringForTooShortOrLongFails() public{

        bytes32 parentNode = bytes("\x03abc\x03eth\x00").namehash(0);
        bytes32 node = registerAndWrap(account2);

        assertEq(subnameRegistrar.available(bytes("\x03xyz\x03abc\x03eth\x00")), false);
        assertEq(subnameRegistrar.available(bytes("\x08coolname\x03abc\x03eth\x00")), true);

        // Change the params duration to be one year minimum and one year maximum.
        subnameRegistrar.setParams(
            parentNode, 
            true, 
            renewalController, 
            oneYear, 
            oneYear,
            2, 
            254
        );

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = subnameRegistrar.makeCommitment(
            "\x08coolname\x03abc\x03eth\x00", 
            account2, 
            bytes32(uint256(0x7878))
        );

        subnameRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Expect to revert if the duration is too long with a custom error InvalidDuration
        vm.expectRevert( abi.encodeWithSelector(InvalidDuration.selector, oneYear+1));

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear+1,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Expect to revert if the duration is too short with a custom error InvalidDuration
        vm.expectRevert( abi.encodeWithSelector(InvalidDuration.selector, oneYear-1));

        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear-1,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Go ahead and register the name for a year.  
        // Register the subname, and overpay with 1 ETH.
        subnameRegistrar.register{value: 1000000000000000000}(
            "\x08coolname\x03abc\x03eth\x00",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Check to make sure the subname is owned account2 in the Name Wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);
        

        vm.stopPrank();
        vm.startPrank(account);

    }

}
