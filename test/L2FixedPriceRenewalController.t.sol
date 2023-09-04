// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {L2SubnameRegistrar} from "optimism/wrapper/L2SubnameRegistrar.sol";
import {ISubnameRegistrar} from "optimism/wrapper/interfaces/ISubnameRegistrar.sol";
import {L2NameWrapper} from "optimism/wrapper/L2NameWrapper.sol";
import {ENSRegistry} from "ens-contracts/registry/ENSRegistry.sol";
import {StaticMetadataService} from "ens-contracts/wrapper/StaticMetadataService.sol";
import {L2PublicResolver} from "optimism/resolvers/L2PublicResolver.sol";
import {IL2NameWrapper, CANNOT_BURN_NAME, PARENT_CANNOT_CONTROL} from "optimism/wrapper/interfaces/IL2NameWrapper.sol";
import {INameWrapper} from "ens-contracts/wrapper/INameWrapper.sol";
import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import {Resolver} from "ens-contracts/resolvers/Resolver.sol";
import {BytesUtils} from "ens-contracts/wrapper/BytesUtils.sol";
import {USDOracleMock} from "optimism/wrapper/mocks/USDOracleMock.sol";

import {IERC1155MetadataURI} from "openzeppelin-contracts/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import {GasHelpers} from "./GasHelpers.sol";
import {IERC165} from "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import {IAddrResolver} from "ens-contracts/resolvers/profiles/IAddrResolver.sol";

import {L2FixedPriceRenewalController} from "optimism/wrapper/renewalControllers/L2FixedPriceRenewalController.sol";
import {IRenewalController} from "optimism/wrapper/interfaces/IRenewalController.sol";
import {IFixedPriceRenewalController} from "optimism/wrapper/interfaces/rCInterfaces/IFixedPriceRenewalController.sol";
import {UnauthorizedAddress, InsufficientValue} from "optimism/wrapper/L2RenewalControllerBase.sol";
import {IL2NameWrapperUpgrade} from "optimism/wrapper/interfaces/IL2NameWrapperUpgrade.sol";

error ZeroLengthLabel();

contract L2FixedPriceRenewalControllerTest is Test, GasHelpers {

    uint64 private constant GRACE_PERIOD = 90 days;
    bytes32 private constant ETH_NODE =
        0x93cdeb708b7545dc668eb9280176169d1c33cfd8ed6f04690a0bcc88a93fc4ae;
    bytes32 private constant ETH_LABELHASH =
        0x4f5b812789fc606be1b3b16908db13fc7a9adf7ca72641f84d75b47069d3d7f0;
    bytes32 private constant ROOT_NODE =
        0x0000000000000000000000000000000000000000000000000000000000000000;
    bytes32 private constant UNRUGGABLE_TLD_NODE = 
        0xc951937fc733cfe92dd3ea5d53048d4f39082c7e84dfc0501b03d5e2dd672d5d;
    bytes32 private constant UNRUGGABLE_TLD_LABELHASH = 
        0x0fb49d3befd591078ec044334b6cad68f02609749d39e161fa1ff9bf6ce96d8c;

    string MAINNET_RPC_URL = "https://eth-mainnet.g.alchemy.com/v2/_YutYRi0sYLsh44jlBvM7QgDOcK-JhtY";
    uint64 twoYears = 63072000; // aprox. 2 years
    uint64 oneYear = 31536000; // A year in seconds.
    uint64 oneMonth = 2592000; // A month in seconds.
    uint64 oneDay = 86400; // A day in seconds.
    address account = 0x0000000000000000000000000000000000003511;
    address account2 = 0x0000000000000000000000000000000000004612;
    address accountReferrer = 0x0000000000000000000000000000000000005627;
    address trustedEthAddress = 0x0000000000000000000000000000000000009568;
    address hacker = 0x0000000000000000000000000000000000001101; 

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
    L2FixedPriceRenewalController fixedPriceRenewalController;

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

        // Deploy the public resolver.
        publicResolver = new L2PublicResolver(ens, nameWrapper, trustedEthAddress);

        // Deploy the Subname Registrar.
        subnameRegistrar = new L2SubnameRegistrar(
            60, //one minute
            604800, //one week
            ens,
            nameWrapper,
            usdOracle
        );

        // Allow "account" to register names in the name wrapper.
        nameWrapper.setController(account, true);

        /**
         * Set up the .unruggable TLD in the ENS registry. The .unruggable TLD is a special TLD that
         * we use to be able to assign anyone a random second level name, which can be used to issue subnamees.
         * The .unruggable TLD is owned by the caller and the caller can approve the subname registrar to
         * register subnames under the .unruggable TLD.
         */
        ens.setSubnodeOwner(ROOT_NODE, UNRUGGABLE_TLD_LABELHASH, account);
        assertEq(ens.owner(UNRUGGABLE_TLD_NODE), account);

        // Approve the NameWrapper to register subnames under the .unruggable TLD.
        ens.setApprovalForAll(address(nameWrapper), true);

        // Wrap the .unruggable TLD in the NameWrapper.
        nameWrapper.wrapTLD(
            bytes("\x0aunruggable\x00"), 
            account, 
            PARENT_CANNOT_CONTROL | CANNOT_BURN_NAME, 
            uint64(type(uint64).max)
        );

        // Make sure we are the owner of .unruggable TLD in the NameWrapper.
        assertEq(nameWrapper.ownerOf(uint256(UNRUGGABLE_TLD_NODE)), account);


        // Register a 2LD .eth name in the NameWrapper
        nameWrapper.registerAndWrapEth2LD(
            "abc", 
            account,
            address(0), //no approved contract
            twoYears,
            address(publicResolver),
            uint16(CANNOT_BURN_NAME)
        );

        // Revoke the approval for "account".
        nameWrapper.setController(account, false);

        // Revoke the approval for "account" in the ENS registry.
        ens.setApprovalForAll(address(nameWrapper), false);

        /**
         * In order to register subnames of abc.eth and the .unruggable TLD, 
         * which are both owned by "account" in the NameWrapper,
         * we need to approve all for subname registrar.
         */

        nameWrapper.setApprovalForAll(address(subnameRegistrar), true);


        // Deploy a fixed price renewal controller.
        fixedPriceRenewalController = new L2FixedPriceRenewalController(
            nameWrapper,
            usdOracle,
            158548959918 // (≈$5/year) calculated as $/sec with 18 decimals.
        );
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
            IRenewalController(address(fixedPriceRenewalController)), 
            3600, 
            type(uint64).max,
            3, // min chars
            32 // max length of a subname 
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
    function test2000__________________L2_FIXED_PRICE_RENEWAL_CONTROLLER______________________() public {}
    function test3000_________________________________________________________________________() public {}

    //Check to make sure the subname wrapper contract supports interface detection. 
    function test_001____supportsInterface___________SupportsCorrectInterfaces() public {

        // Check for the ISubnameWrapper interface.  
        assertEq(fixedPriceRenewalController.supportsInterface(type(IRenewalController).interfaceId), true);

        // Check for the IERC165 interface.
        assertEq(fixedPriceRenewalController.supportsInterface(type(IERC165).interfaceId), true);

        // Check for the IFixedPriceRenewalController interface.
        assertEq(fixedPriceRenewalController.supportsInterface(type(IFixedPriceRenewalController).interfaceId), true);

    }

    function test_002____renew_________________________RenewsTheSubname() public {

        bytes32 node = registerAndWrap(account2);

        // Switch to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Get the expiry of the subname using getData.
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));

        // Advance the timestamp to one second before the name expires.
        skip(expiry - block.timestamp - 1);

        // Get the balance of account2.
        uint256 balance = address(account2).balance;

        // Renew the subname, with 1 Eth overpayment.
        fixedPriceRenewalController.renew{value: 1000000000000000000}(
            "\x03xyz\x03abc\x03eth\x00",
            accountReferrer,
            oneYear
        );

        // Check to make sure the subname has been renewed using getData.
        (, , uint64 newExpiry) = nameWrapper.getData(uint256(node));

        // Check to make sure the new expiry is correct.
        assertEq(newExpiry, expiry + oneYear);

        // Get the new balance of account2.
        uint256 newBalance = address(account2).balance;

        // Check to make sure the balance of account2 has decreased. 
        assertEq(newBalance < balance, true);

    }

    function test_002____renew_________________________RevertsIfNotTheOwnerOrApproved() public {

        bytes32 node = registerAndWrap(account2);

        // Switch to account2.
        vm.stopPrank();
        vm.startPrank(hacker);

        // Give the hacker 10 ETH.
        vm.deal(hacker, 10000000000000000000);

        // Get the expiry of the subname using getData.
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));

        // Advance the timestamp to one second before the name expires.
        skip(expiry - block.timestamp - 1);

        // Make sure it reverts if not the owner or approved.
        vm.expectRevert( abi.encodeWithSelector(UnauthorizedAddress.selector, node));

        // Renew the subname, with 1 Eth overpayment.
        fixedPriceRenewalController.renew{value: 1000000000000000000}(
            "\x03xyz\x03abc\x03eth\x00",
            accountReferrer,
            oneYear
        );
    }

    // Revert if too little money was sent to renew the subname.
    function test_002____renew_________________________RevertsIfNotEnoughMoney() public {

        bytes32 node = registerAndWrap(account2);

        // Switch to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Get the expiry of the subname using getData.
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));

        // Advance the timestamp to one second before the name expires.
        skip(expiry - block.timestamp - 1);

        // Make sure it reverts if not enough money is sent.
        vm.expectRevert( abi.encodeWithSelector(InsufficientValue.selector));

        // Renew the subname, with only 1 wei, which is not enough.
        fixedPriceRenewalController.renew{value: 1}(
            "\x03xyz\x03abc\x03eth\x00",
            accountReferrer,
            oneYear
        );
    }


    // Test to make sure that if we renew for 3 years, the expiry is actually set to the parent expiry.
    function test_002____renew_________________________SetsTheExpiryToTheParentExpiry() public {

        bytes32 node = registerAndWrap(account2);

        // Switch to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Get the expiry of the subname using getData.
        (, , uint64 expiry) = nameWrapper.getData(uint256(node));

        // Advance the timestamp to one second before the name expires.
        skip(expiry - block.timestamp - 1);

        // Renew the subname, with 3 years.
        fixedPriceRenewalController.renew{value: 1000000000000000000}(
            "\x03xyz\x03abc\x03eth\x00",
            accountReferrer,
            3 * oneYear
        );

        // Check to make sure the subname has been renewed using getData.
        (, , uint64 newExpiry) = nameWrapper.getData(uint256(node));

        // Check to make sure the new expiry is correct (We need subtract 61 because of skip).
        assertEq(newExpiry, expiry + oneYear + GRACE_PERIOD - 61);

    }

    function test_002____addNextNameWrapperVersion______AddsTheNextNameWrapperVersion() public {

        // Create a new name wrapper.
        L2NameWrapper newNameWrapper = new L2NameWrapper(
            ens, 
            IMetadataService(address(staticMetadataService))
        );

        // Add the name wrapper to the renewal controller.
        fixedPriceRenewalController.addNextNameWrapperVersion(IL2NameWrapperUpgrade(address(newNameWrapper)));

        // Check to make sure the name wrapper has been added.
        assertEq(address(fixedPriceRenewalController.nameWrappers(1)), address(address(newNameWrapper)));

    }

    function test_002____setUSDPrice____________________SetsTheUSDPrice() public {

        // Set the USD price.
        fixedPriceRenewalController.setUSDPrice(1000000000000000000);

        // Check to make sure the price is correct.
        assertEq(fixedPriceRenewalController.usdPrice(), 1000000000000000000);

    }

    // Test the updateOracle function.
    function test_002____updateOracle___________________UpdatesTheOracle() public {

        // Create a new USD oracle.
        USDOracleMock newUsdOracle = new USDOracleMock();

        // Set the oracle address.
        fixedPriceRenewalController.updateOracle(newUsdOracle);

        // Check to make sure the oracle address is correct.
        assertEq(address(fixedPriceRenewalController.usdOracle()), address(newUsdOracle));

    }

    function test_003____getPrice_______________________GetsThePriceOfTheRenewal() public {

        bytes32 node = registerAndWrap(account2);

        // Switch to account2.
        vm.stopPrank();
        vm.startPrank(account2);

        // Get the price of the renewal.
        (uint256 priceEth, uint256 priceUsd) = fixedPriceRenewalController.rentPrice(
            "\x03xyz\x03abc\x03eth\x00",
            1
        );

        // Check to make sure the price is correct.
        assertEq(priceUsd, 158548959918);

        // @audit - We are not checking the Eth price, here, the only way to check it is to redo the calculation.
        // Maybe just make sure it makes sense. 

    }

}
