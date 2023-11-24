// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {BytesUtilsSub} from "optimism/wrapper/BytesUtilsSub.sol";

contract BytesUtilsSubTests is Test {


    function test1000_________________________________________________________________________() public {}
    function test2000_______________________BYTES_UTILS_SUB_TESTS_____________________________() public {}
    function test3000_________________________________________________________________________() public {}

    // Test BytesUtilsSub.getFirstLabel
    function test_001____getFirstLabel_______________GetTheLabelFromADNSEncodedBytesName() public {
        bytes memory name = "\x03123\x03eth\x00";
        (string memory label, ) = BytesUtilsSub.getFirstLabel(name);
        assertEq(label, "123");
    }

    // Test BytesUtilsSub.getFirstLabel
    function test_002____getFirstLabel_______________GetTheLabelFromADNSEncodedBytesNameEdgeCases() public {

        bytes memory name;
        string memory label;

        // Check the output of a malformed DNS encoded name - wrong prefix length. 
        name = "\x16abc\x05files\x00";
        // expect revert 
        vm.expectRevert(bytes(""));
        BytesUtilsSub.getFirstLabel(name);

        // Check the output of a malformed DNS encoded name - zero length prefix.
        name = "\x00abcd\x03eth\x00";
        // expect revert 
        vm.expectRevert(bytes(""));
        BytesUtilsSub.getFirstLabel(name);

        // Check the output of a malformed DNS encoded name - no TLD.
        name = "\x05hello\x00";
        (label, ) = BytesUtilsSub.getFirstLabel(name);
        assertEq(label, "hello");

        // Check the output of a malformed DNS encoded name - no suffix \x00.
        name = "\x05hello\x03eth";
        (label, ) = BytesUtilsSub.getFirstLabel(name);
        assertEq(label, "hello");

        // Check the output of a malformed DNS encoded name - wrong prefix length.
        name = "\x04abc\x05files\x00";
        (label, ) = BytesUtilsSub.getFirstLabel(name);
        assertEq(bytes(label), bytes("abc\x05"));

    }
    // Test BytesUtilsSub.getTLD
    function test_003____getTLD______________________GetTheTLDFromADNSEncodedBytesName() public {
        bytes memory name = "\x03123\x03eth\x00";
        string memory tld = BytesUtilsSub.getTLD(name);
        assertEq(tld, "eth");
    }

    // Test BytesUtilsSub.getTLD
    function test_004____getTLD______________________GetTheTLDFromADNSEncodedBytesNameEdgeCases() public {


        bytes memory name;

        // Check the output of a malformed DNS encoded name - wrong prefix length.
        name = "\x05123\x03eth\x00";
        vm.expectRevert(bytes("TLD not found"));
        BytesUtilsSub.getTLD(name);

        // Check the output of a malformed DNS encoded name - wrong TLD length.
        name = "\x03123\x01eth\x00";
        vm.expectRevert(bytes("TLD not found"));
        BytesUtilsSub.getTLD(name);

        // Check the output of a malformed DNS encoded name - too long length of the TLD.
        name = "\x03123\x04eth\x00";
        vm.expectRevert(bytes("TLD not found"));
        BytesUtilsSub.getTLD(name);

    }

    // Test keccak
    function test_005____keccak______________________TestKeccak() public {
        bytes memory name = "\x03123\x03eth\x00";
        bytes32 hash = BytesUtilsSub.keccak(name, 5, 4);

        bytes memory name2 = "eth\x00";
        bytes32 hash2 = keccak256(name2);

        assertEq(hash, hash2);

    }

    // Test keccak edge cases
    function test_006____keccak______________________TestKeccakEdgeCases() public {
        bytes memory name = "\x03123\x03eth\x00";

        // expect revert 
        vm.expectRevert(bytes(""));

        // make the length + offset exceed the length of the name
        BytesUtilsSub.keccak(name, 5, 5);


        // expect revert 
        vm.expectRevert(bytes(""));

        // make the offset greater than the length of the name
        BytesUtilsSub.keccak(name, 22, 0);


        // expect revert
        vm.expectRevert(bytes(""));

        // make the length set to 0
        BytesUtilsSub.keccak(name, 0, 0);

    }

    // Test readlabel
    function test_007____readLabel___________________TestReadLabel() public {
        bytes memory name = "\x03123\x03eth\x00";
        (bytes32 labelhash, uint256 offset) = BytesUtilsSub.readLabel(name, 0);
        assertEq(labelhash, bytes32(keccak256(bytes("123"))));
        assertEq(offset, 4);
    }

    // Test readlabel edge cases
    function test_008____readLabel___________________TestReadLabelEdgeCases() public {

        bytes memory name = "\x03123\x03eth\x00";

        // expect revert
        vm.expectRevert(bytes("readLabel: Index out of bounds"));

        // make the offset exceed the length of the name
        BytesUtilsSub.readLabel(name, 22);

    }


    function test_009____replaceLabel___________________ReplaceEthWithUnruggable() public {

        bytes memory name = "\x04test\x08testccip\x03eth\x00"; //9
        bytes memory newTld = "\x0aunruggable\x00"; //12

        bytes memory expectedName = "\x04test\x08testccip\x0aunruggable\x00"; //16

        // make the offset exceed the length of the name
        string memory replacedName = BytesUtilsSub.replaceTLD(name, newTld);

        assertEq(replacedName, string(expectedName));

    }

}