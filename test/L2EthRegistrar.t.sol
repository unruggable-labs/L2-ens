// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {
    
    L2EthRegistrar, 
    UnauthorizedAddress, 
    WrongNumberOfChars, 
    CannotSetNewCharLengthAmounts, 
    InsufficientValue,
    LabelTooShort,
    LabelTooLong,
    CommitmentTooNew,
    CommitmentTooOld,
    DurationTooShort

} from "optimism/wrapper/L2EthRegistrar.sol";
import {IL2EthRegistrar} from "optimism/wrapper/interfaces/IL2EthRegistrar.sol";
import {L2NameWrapper} from "optimism/wrapper/L2NameWrapper.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {L2PublicResolver} from "optimism/resolvers/L2PublicResolver.sol";
import {IL2NameWrapper} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {USDOracleMock} from "optimism/wrapper/mocks/USDOracleMock.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";

import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {GasHelpers} from "./GasHelpers.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";

error UnexpiredCommitmentExists(bytes32 commitment);
error ZeroLengthLabel();
error InvalidDuration(uint256 duration);

contract L2EthRegistrarTest is Test, GasHelpers {

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
    L2EthRegistrar ethRegistrar;
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

        // Deploy the L2 name wrapper. 
        nameWrapper = new L2NameWrapper(
            ens, 
            IMetadataService(address(staticMetadataService))
        );

        // Set up .eth in the ENS registry.
        ens.setSubnodeOwner(ROOT_NODE, ETH_LABELHASH, address(nameWrapper));
        assertEq(ens.owner(ETH_NODE), address(nameWrapper));

        // Approve the name wrapper as a controller of the ENS registry.
        //ens.setApprovalForAll(address(nameWrapper), true); // @audit - I don't think this is necessary

        // Deploy the public resolver.
        // @audit - for some reason this doesn't work, but we don't need it here. 
        publicResolver = new L2PublicResolver(ens, nameWrapper, address(0));

        // Deploy the L2 Eth Registrar.
        ethRegistrar = new L2EthRegistrar(
            60, //one minute
            604800, //one week
            ens,
            nameWrapper,
            usdOracle
        );

        // Set params for the L2 Eth Registrar.
        ethRegistrar.setParams(
            oneMonth, 
            type(uint64).max, //no maximum length of time. 
            3, // min three characters 
            255 // max 255 characters
        );

        // Set the pricing for the name registrar. 
        // Not that there are 4 elements, but only the fist three have been defined. 
        // This has been done to make sure that nothing breaks even if one is not defined. 
        uint256[] memory charAmounts = new uint256[](4);
        charAmounts[0] = 158548959918; // (≈$5/year) calculated as $/sec with 18 decimals.
        charAmounts[1] = 158548959918;
        charAmounts[2] = 0;

        ethRegistrar.setPricingForAllLengths(
            charAmounts
        );

        // Set the L2 Eth Registrar as the controller of the name so we can use it to register names. 
        nameWrapper.setController(address(ethRegistrar), true);
    }

    function registerAndWrap(address _account) internal returns (bytes32){

        // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(_account);
        vm.deal(_account, 10000000000000000000);

        bytes32 commitment = ethRegistrar.makeCommitment(
            "abc", 
            _account, 
            bytes32(uint256(0x4453))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "abc",
            _account,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x4453)), 
            address(publicResolver), 
            0 /* fuses */
        );

        vm.stopPrank();
        vm.startPrank(account);

        return bytes("\x03abc\x03eth\x00").namehash(0);

    }
    // Create a Subheading using an empty function.
    function test1000_________________________________________________________________________() public {}
    function test2000__________________________L2_ETH_REGISTRAR_FUNCTIONS_____________________() public {}
    function test3000_________________________________________________________________________() public {}

    //Check to make sure the name wrapper contract supports interface detection. 
    function test_001____supportsInterface___________SupportsCorrectInterfaces() public {

        // Check for the IL2NameWrapper interface.  
        assertEq(ethRegistrar.supportsInterface(type(IL2EthRegistrar).interfaceId), true);

        // Check for the IERC165 interface.  
        assertEq(ethRegistrar.supportsInterface(type(IERC165).interfaceId), true);
    }

    function test_002____rentPrice___________________RentPriceWasSetCorrectly() public{

        bytes32 node = registerAndWrap(account2);

        // Check to make sure the name was created and account2 is the owner. 
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);

        // Get the price for renewing the domain for a year. 
        (uint256 weiAmount,) = ethRegistrar.rentPrice(
            bytes("\x03abc\x03eth\x00"), 
            oneYear 
        );

        // USD price of Eth from the oracle.
        int256 ethPrice = usdOracle.latestPrice();
        // Check to make sure the price is around $5/year.
        uint256 expectedPrice = 5 * 10**26/uint256(ethPrice);

        // make sure the price is close to the expected price.
        assertTrue(weiAmount/10**10 == expectedPrice/10**10);
    }

    function test_002____rentPrice___________________DefaultPriceIsZero() public{

        // Set the pricing for the name registrar. 
        // Not that there are 4 elements, but only the fist three have been defined. 
        // This has been done to make sure that nothing breaks even if one is not defined. 
        uint256[] memory charAmountsNull = new uint256[](0);

        ethRegistrar.setPricingForAllLengths(
            charAmountsNull
        );

        // Make sure the price is zero.
        (uint256 weiAmount, uint256 usdAmount) = ethRegistrar.rentPrice(
            bytes("\x03abc\x03eth\x00"), 
            oneYear 
        );

        // Check to make sure the price is zero.
        assertEq(weiAmount, 0);
        assertEq(usdAmount, 0);

    }

    function test_005____setParams___________________SetTheRegistrationParameters() public{

        ethRegistrar.setParams(
            3601, 
            type(uint64).max,
            2, 
            254 
        );

        assertEq(ethRegistrar.minRegistrationDuration(), 3601);
        assertEq(ethRegistrar.maxRegistrationDuration(), type(uint64).max);
        assertEq(ethRegistrar.minChars(), 2);
        assertEq(ethRegistrar.maxChars(), 254);
    }

    function test_006____setPricingForAllLengths_____SetThePriceForAllLengthsOfNamesAtOneTime() public{

        bytes32 node = registerAndWrap(account2);

        // Set the pricing for the name registrar. 
        // Not that there are 4 elements, but only the fist three have been defined. 
        // This has been done to make sure that nothing breaks even if one is not defined. 
        uint256[] memory charAmounts = new uint256[](4);
        charAmounts[0] = 158548959918; // (≈$5/year) calculated as $/sec with 18 decimals.
        charAmounts[1] = 158548959918;
        charAmounts[2] = 1;

        ethRegistrar.setPricingForAllLengths(
            charAmounts
        );
        assertEq(ethRegistrar.getPriceDataForLength(0), 158548959918);
        assertEq(ethRegistrar.getPriceDataForLength(1), 158548959918);
        assertEq(ethRegistrar.getPriceDataForLength(2), 1);
        assertEq(ethRegistrar.getPriceDataForLength(3), 0);

    }

    function test_007____getPriceDataForLength_______TheAmontForAnySetLengthOfName() public{

        bytes32 node = registerAndWrap(account2);

        // Add a price for the next character (4th character).
        ethRegistrar.addNextPriceForCharLength(317097919836);
        assertEq(ethRegistrar.getPriceDataForLength(uint16(4)), 317097919836);

    }

    function test_008____updatePriceForCharLength____UpdateThePriceOfANameLength() public{

        bytes32 node = registerAndWrap(account2);

        ethRegistrar.updatePriceForCharLength(3, 317097919836);

        assertEq(ethRegistrar.getPriceDataForLength(uint16(ethRegistrar.getLastCharIndex())), 317097919836);

    }

    function test_008____updatePriceForCharLength____RevertsIfLengthDoesntExist() public{

        bytes32 node = registerAndWrap(account2);

        // revert with error CannotSetNewCharLengthAmounts if the length doesn't exist.
        vm.expectRevert(abi.encodeWithSelector(CannotSetNewCharLengthAmounts.selector));

        ethRegistrar.updatePriceForCharLength(12, 317097919836);

    }

    function test_009____getLastCharIndex____________ReturnsTheLastIndexOfCharAmounts() public{

        bytes32 node = registerAndWrap(account2);

        // Add a price for the next character (4th character).
        ethRegistrar.addNextPriceForCharLength(317097919836);
        assertEq(ethRegistrar.getLastCharIndex(), 4);
    }

    function test_011____available___________________AvailableToRegister() public{

        bytes32 node = registerAndWrap(account2);

        assertEq(ethRegistrar.available(bytes("\x03abc\x03eth\x00")), false);
        assertEq(ethRegistrar.available(bytes("\x03xyz\x03eth\x00")), true);

        // check if a 32 character name is available.
        assertEq(ethRegistrar.available(bytes("\x20123456745678asftgesnytfwsdftgnrw\x03eth\x00")), true);

        // add an extra null byte to the end of the name.
        vm.expectRevert(bytes("namehash: Junk at end of name"));
        ethRegistrar.available(bytes("\x03xyz\x03eth\x00\x00"));

        // Names with spaces are OK.
        assertEq(ethRegistrar.available(bytes("\x04x yz\x03eth\x00")), true);

        // Names with the wrong length of the label in the DNS encoding.
        vm.expectRevert(bytes(""));
        ethRegistrar.available(bytes("\x05xyz\x03eth\x00"));

        // Names with the a zero length of the label in the DNS encoding.
        vm.expectRevert(bytes(""));
        ethRegistrar.available(bytes("\x00\x03eth\x00"));


    }

    function test_012____makeCommitment______________CommitAndRegisterAName() public{

        bytes32 node = registerAndWrap(account2);

        assertEq(ethRegistrar.available(bytes("\x03abc\x03eth\x00")), false);
        assertEq(ethRegistrar.available(bytes("\x08coolname\x03eth\x00")), true);

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = ethRegistrar.makeCommitment(
            "coolname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        //Check to make sure the commitment is correct.
        bytes32 checkCommitment = keccak256(
                abi.encode(
                    "coolname", 
                    account2, 
                    bytes32(uint256(0x7878)) 
                )
            );

        assertEq(commitment, checkCommitment);

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // check to make sure the name was registered by checking the owner
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);

        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_013____commit______________________CommitCantBeUsedTwice() public{

        bytes32 node = registerAndWrap(account2);

        assertEq(ethRegistrar.available(bytes("\x03abc\x03eth\x00")), false);
        assertEq(ethRegistrar.available(bytes("\x08coolname\x03eth\x00")), true);

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = ethRegistrar.makeCommitment(
            "coolname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Expect this to revert becuase the commitment has already been used.
        vm.expectRevert( abi.encodeWithSelector(UnexpiredCommitmentExists.selector, commitment));
        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Make sure the name has been registered by checking the owner.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);

        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_014____register____________________RegistersAndWrapsAName() public{

        bytes32 node = registerAndWrap(account2);

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                ethRegistrar.register.selector,
                "coolname",
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

        bytes32 commitment = ethRegistrar.makeCommitment(
            "coolname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        stopMeasuringGas();

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                ethRegistrar.commit.selector,
                commitment
            )
        );
        startMeasuringGas("Gas usage for the commit function: ");

        ethRegistrar.commit(commitment);

        stopMeasuringGas();

        // Advance the timestamp by 61 seconds.
        skip(61);

        logBaseGasCost();
        calculateCalldataGasCost(
            abi.encodeWithSelector(
                ethRegistrar.register.selector,
                "coolname",
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

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        stopMeasuringGas();

        // Check to make sure the name is owned the name Wrapper in the Name Wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);
        

        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_014____register____________________RevertWhenNotEnoughEthIsSent() public{

        bytes32 node = registerAndWrap(account2);

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = ethRegistrar.makeCommitment(
            "coolname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Revert with InsufficientValue() if not enough ETH is sent.
        vm.expectRevert(abi.encodeWithSelector(InsufficientValue.selector));

        // Register the name, and overpay with 1 wei.
        ethRegistrar.register{value: 1}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Check to make sure the name is owned the name Wrapper in the Name Wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);

    }

    function test_015____register____________________RegistringForTooShortOrLongFails() public{

        bytes32 node = registerAndWrap(account2);

        assertEq(ethRegistrar.available(bytes("\x03abc\x03eth\x00")), false);
        assertEq(ethRegistrar.available(bytes("\x08coolname\x03eth\x00")), true);

        // Change the params duration to be one year minimum and one year maximum.
        ethRegistrar.setParams(
            oneYear, 
            oneYear,
            2, 
            254
        );

         // Set the caller to _account and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        bytes32 commitment = ethRegistrar.makeCommitment(
            "coolname", 
            account2, 
            bytes32(uint256(0x7878))
        );


        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Expect to revert if the duration is too long with a custom error InvalidDuration
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector, oneYear+1));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear+1,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Expect to revert if the duration is too short with a custom error InvalidDuration
        vm.expectRevert(abi.encodeWithSelector(InvalidDuration.selector, oneYear-1));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear-1,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Go ahead and register the name for a year.  
        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "coolname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );

        // Check to make sure the name is owned "account2" in the L2 Name Wrapper.
        assertEq(nameWrapper.ownerOf(uint256(node)), account2);
        
        vm.stopPrank();
        vm.startPrank(account);

    }

    function test_016____register____________________RevertsWhenRegisteringTooShortNames() public{

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        // make a 256 character name.
        string memory label = "a";


        bytes32 commitment = ethRegistrar.makeCommitment(
            label, 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Expect to revert with WrongNumberOfChars(label).
        vm.expectRevert(abi.encodeWithSelector(WrongNumberOfChars.selector, label));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            label,
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );
    }

    function test_017____register____________________RevertsWhenRegisteringTooLongNames() public{

        // Reset params for the L2 Eth Registrar.
        ethRegistrar.setParams(
            oneMonth, 
            type(uint64).max, //no maximum length of time. 
            3, // min three characters 
            100 // max 100 characters
        );

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        // make a 256 character name.
        bytes memory label = new bytes(101);
        for (uint256 i = 0; i < 101; i++) {
            label[i] = "a";
        }

        bytes32 commitment = ethRegistrar.makeCommitment(
            string(label), 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Expect to revert with WrongNumberOfChars(label).
        vm.expectRevert(abi.encodeWithSelector(WrongNumberOfChars.selector, string(label)));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            string(label),
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );
    }

    function test_017____register____________________RevertsWhenRegisteringNamesWith256Characters() public{

        // Reset params for the L2 Eth Registrar.
        ethRegistrar.setParams(
            oneMonth, 
            type(uint64).max, //no maximum length of time. 
            3, // min three characters 
            100 // max 100 characters
        );

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);

        // make a 256 character name.
        bytes memory label = new bytes(256);
        for (uint256 i = 0; i < 101; i++) {
            label[i] = "a";
        }

        bytes32 commitment = ethRegistrar.makeCommitment(
            string(label), 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 61 seconds.
        skip(61);

        // Expect to revert with WrongNumberOfChars(label).
        vm.expectRevert(abi.encodeWithSelector(LabelTooLong.selector));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            string(label),
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );
    }

    function test_017____register____________________RevertsWhenRegisteringUsingATooNewCommitment() public{

        // Reset params for the L2 Eth Registrar.
        ethRegistrar.setParams(
            oneMonth, 
            type(uint64).max, //no maximum length of time. 
            3, // min three characters 
            100 // max 100 characters
        );

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);


        bytes32 commitment = ethRegistrar.makeCommitment(
            "newname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by 1 seconds, which is not enough.
        skip(1);

        // Expect to revert with WrongNumberOfChars(label).
        vm.expectRevert(abi.encodeWithSelector(CommitmentTooNew.selector, commitment));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "newname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );
    }

    function test_017____register____________________RevertsWhenRegisteringUsingATooOldCommitment() public{

        // Reset params for the L2 Eth Registrar.
        ethRegistrar.setParams(
            oneMonth, 
            type(uint64).max, //no maximum length of time. 
            3, // min three characters 
            100 // max 100 characters
        );

         // Set the caller to account2 and give the account 10 ETH.
        vm.stopPrank();
        vm.startPrank(account2);
        vm.deal(account2, 10000000000000000000);


        bytes32 commitment = ethRegistrar.makeCommitment(
            "newname", 
            account2, 
            bytes32(uint256(0x7878))
        );

        ethRegistrar.commit(commitment);

        // Advance the timestamp by one week plus one second.
        skip(604801);

        // Expect to revert with WrongNumberOfChars(label).
        vm.expectRevert(abi.encodeWithSelector(CommitmentTooOld.selector, commitment));

        // Register the name, and overpay with 1 ETH.
        ethRegistrar.register{value: 1000000000000000000}(
            "newname",
            account2,
            accountReferrer, //referrer
            oneYear,
            bytes32(uint256(0x7878)), 
            address(publicResolver), 
            0 /* fuses */
        );
    }

    function test_018____renew_______________________RenewADotEth2LD() public{

        bytes32 node = registerAndWrap(account2);

        //get the previous expiry. 
        (,, uint64 prevExpiry) = nameWrapper.getData(uint256(node));

        // Renew the name for one year. Overpay with 1 Eth  
        ethRegistrar.renew{value: 1000000000000000000}(
            "abc",
            accountReferrer, 
            oneYear
        );

        // get the data for the name
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));

        // Make sure the name is renewed for one more year.
        assertEq(expiry, uint64(prevExpiry + oneYear));

    }

    function test_018____renew_______________________RevertsWhenNotEnoughEthIsSent() public{

        bytes32 node = registerAndWrap(account2);

        //get the previous expiry. 
        (,, uint64 prevExpiry) = nameWrapper.getData(uint256(node));

        // Revert when not enough value is sent. 
        vm.expectRevert(abi.encodeWithSelector(InsufficientValue.selector));

        // Renew the name for one year. Overpay with 1 Eth  
        ethRegistrar.renew{value: 1}(
            "abc",
            accountReferrer, 
            oneYear
        );

    }

    function test_018____renew_______________________RevertIfLabelIsMissing() public{

        bytes32 node = registerAndWrap(account2);

        //get the previous expiry. 
        (,, uint64 prevExpiry) = nameWrapper.getData(uint256(node));

        // Revert if the name is missing.
        vm.expectRevert(abi.encodeWithSelector(LabelTooShort.selector)); 


        // Renew the name for one year. Overpay with 1 Eth  
        ethRegistrar.renew{value: 1000000000000000000}(
            "",
            accountReferrer, 
            oneYear
        );
    }
}