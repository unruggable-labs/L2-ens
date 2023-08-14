//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

// Chainlink oracle interface
interface IAggregatorInterface {
    function latestAnswer() external view returns (int256);
}