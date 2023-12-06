//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library UnruggableBytesUtils {
    
    /**
     * @dev This function takes a bytes input which represents the DNS name and
     * replaces the TLD (last label).
     * @param domain bytes memory.
     * @param newTld bytes memory.
     * @return string memory the name with replaced tld.
     */
    function replaceTLD(bytes memory domain, bytes memory newTld) internal pure returns (bytes memory) {
        // Variable used to keep track of the level count.

        uint levels = 0;
        // Variable used to keep track of the index of each length byte.

        uint lastLabelLength = 0;

        // Iterate through the domain bytes. 
        for (uint i = 0; i < domain.length;) {

            // If level count exceed 10, break the loop.
            if (levels > 10) {

                break;
            }

            // Get the label length from the current byte.
            uint labelLength = uint(uint8(domain[i]));

            i += labelLength + 1;

            if (labelLength != 0) {

                lastLabelLength = labelLength;
                levels++;

                continue;
            }
        }

        if (levels <= 10) {
            uint newTldLength = newTld.length;

            bytes memory newName = new bytes(domain.length - lastLabelLength + newTldLength - 2);

            uint newNameLength = 0;

            for (uint i = 0; i < domain.length - (lastLabelLength + 2); i++) {

                newName[i] = domain[i];
                newNameLength++;
            }

            for (uint j = 0; j < newTldLength; j++) {

                newName[j + newNameLength] = newTld[j];
            }

            return newName;
        }

        // Revert if TLD not found.
        revert("TLD not found");
    }


    /*
     * @dev Returns the keccak-256 hash of a byte range.
     * @param self The byte string to hash.
     * @param offset The position to start hashing at.
     * @param len The number of bytes to hash.
     * @return The hash of the byte range.
     */
    function keccak(
        bytes memory self,
        uint256 offset,
        uint256 len
    ) internal pure returns (bytes32 ret) {
        require(offset + len <= self.length);
        assembly {
            ret := keccak256(add(add(self, 32), offset), len)
        }
    }

    /**
     * @dev Returns the ENS namehash of a DNS-encoded name.
     * @param self The DNS-encoded name to hash.
     * @param offset The offset at which to start hashing.
     * @return The namehash of the name.
     */
    function namehash(
        bytes memory self,
        uint256 offset
    ) internal pure returns (bytes32) {
        (bytes32 labelhash, uint256 newOffset) = readLabel(self, offset);
        if (labelhash == bytes32(0)) {
            require(offset == self.length - 1, "namehash: Junk at end of name");
            return bytes32(0);
        }
        return
            keccak256(abi.encodePacked(namehash(self, newOffset), labelhash));
    }

    /**
     * @dev Returns the keccak-256 hash of a DNS-encoded label, and the offset to the start of the next label.
     * @param self The byte string to read a label from.
     * @param idx The index to read a label at.
     * @return labelhash The hash of the label at the specified index, or 0 if it is the last label.
     * @return newIdx The index of the start of the next label.
     */
    function readLabel(
        bytes memory self,
        uint256 idx
    ) internal pure returns (bytes32 labelhash, uint256 newIdx) {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }
}