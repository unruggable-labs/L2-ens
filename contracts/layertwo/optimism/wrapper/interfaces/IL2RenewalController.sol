//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IL2RenewalController {

    event NameRenewed(
        bytes indexed name,
        uint256 indexed price,
        uint64 indexed expiry
    );

    function renew(bytes calldata name, address referrer, uint256 duration)
        external
        payable;

    function rentPrice(bytes calldata name, uint256 duration)
        external
        view
        returns (uint256 weiPrice, uint256 usdPrice);
}