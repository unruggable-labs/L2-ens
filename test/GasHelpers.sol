// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17; 

import "forge-std/Test.sol";

contract GasHelpers is Test{
    string private checkpointLabel;
    uint256 private checkpointGasLeft = 1; // Start the slot warm.

    function calculateCalldataGasCost(bytes memory data) public {
        uint256 calldataGasCost = 0;
        for (uint256 i = 0; i < data.length; i++) {
            if (data[i] == 0x00) {
                calldataGasCost += 4;
            } else {
                calldataGasCost += 16;
            }
        }

        emit log_named_uint("Calldata Gas Cost ", calldataGasCost);
    }

    // log base gas cost function
    function logBaseGasCost() public {
        emit log_named_uint("Base Gas Cost ", 21000);
    }

    function startMeasuringGas(string memory label) internal virtual {
        checkpointLabel = label;

        checkpointGasLeft = gasleft();
    }

    function stopMeasuringGas() internal virtual {
        uint256 checkpointGasLeft2 = gasleft();

        // Subtract 100 to account for the warm SLOAD in startMeasuringGas.
        uint256 gasDelta = checkpointGasLeft - checkpointGasLeft2 - 100;

        emit log_named_uint(string(abi.encodePacked(checkpointLabel, " Gas")), gasDelta);
    }
}