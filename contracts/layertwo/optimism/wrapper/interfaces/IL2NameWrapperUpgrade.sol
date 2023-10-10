//SPDX-License-Identifier: MIT
pragma solidity >=0.8.17<0.9.0;

import {IL2RenewalController} from "./IL2RenewalController.sol";

interface IL2NameWrapperUpgrade {

    function wrapUpgraded(
        bytes memory _name,
        address owner,
        IL2RenewalController renewalController,
        uint64 expiry
    ) external;

    function extendExpiry(
        bytes32 parentNode,
        bytes32 labelhash,
        uint64 expiry
    ) external returns (uint64 expiryNormalised);
}
