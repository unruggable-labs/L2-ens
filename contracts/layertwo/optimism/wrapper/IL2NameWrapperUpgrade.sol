//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

interface IL2NameWrapperUpgrade {
    function wrapFromUpgrade(
        bytes calldata name,
        address wrappedOwner,
        uint32 fuses,
        uint64 expiry,
        address approved,
        bytes calldata extraData
    ) external;
}
