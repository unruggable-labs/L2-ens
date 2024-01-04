// SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

contract BasicDemoL2 {
    uint256 public latest;                         // Slot 0
    string public name;                            // Slot 1
    mapping(uint256=>uint256) highscores;   // Slot 2
    mapping(uint256=>string) highscorers;   // Slot 3
    mapping(string=>string) realnames;      // Slot 4
    uint256 zero;                           // Slot 5
    mapping(uint256=>mapping(bytes32=>string)) testing;   // Slot 6

    mapping(uint64 => mapping(bytes => mapping(bytes32 => mapping(uint256 => bytes)))) public addresses_with_context;              //Slot 7

    constructor() {
        latest = 42;
        name = "Satoshi";
        highscores[latest] = 12345;
        highscorers[latest] = "Hal Finney";
        highscorers[1] = "Hubert Blaine Wolfeschlegelsteinhausenbergerdorff Sr.";
        realnames["Money Skeleton"] = "Vitalik Buterin";
        realnames["Satoshi"] = "Hal Finney";

        bytes32 node = bytes32(0x3d5d2e21162745e4df4f56471fd7f651f441adaaca25deb70e4738c6f63d1224);

        testing[latest][node] = "hello";

        address addressToUse = address(0xFC04D70bea992Da2C67995BbddC3500767394513);
        bytes memory addressBytes = addressToBytes(addressToUse);

        addresses_with_context[0][addressBytes][node][60] = addressBytes;
    }


    function addressToBytes(address a) internal pure returns (bytes memory b) {
        b = new bytes(20);
        assembly {
            mstore(add(b, 32), mul(a, exp(256, 12)))
        }
    }
}