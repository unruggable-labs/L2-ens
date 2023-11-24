//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IAggregatorInterface} from "../interfaces/IAggregatorInterface.sol";

contract USDOracleMock is IAggregatorInterface{

    int256 public latestPrice = 185444000000;

    function latestAnswer() external view returns (int256){
        return int256(latestPrice);
    }
}