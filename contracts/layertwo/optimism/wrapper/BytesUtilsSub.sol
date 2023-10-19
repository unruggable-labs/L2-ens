//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

library BytesUtilsSub {
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
    function namehash(bytes memory self, uint256 offset)
        internal
        pure
        returns (bytes32)
    {
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
    function readLabel(bytes memory self, uint256 idx)
        internal
        pure
        returns (bytes32 labelhash, uint256 newIdx)
    {
        require(idx < self.length, "readLabel: Index out of bounds");
        uint256 len = uint256(uint8(self[idx]));
        if (len > 0) {
            labelhash = keccak(self, idx + 1, len);
        } else {
            labelhash = bytes32(0);
        }
        newIdx = idx + len + 1;
    }

    /**
     * @dev This function takes a bytes input which represents the DNS name and
     * returns the first label of a domain name in DNS format.
     * @param domain The domain in DNS format wherein the length precedes each label
     * and is terminted with a 0x0 byte, e.g. "cb.id" => [0x02,0x63,0x62,0x02,0x69,0x64,0x00].
     * @return string memory the first label.
     */

    function getFirstLabel(bytes memory domain) internal pure returns (string memory, uint256) {

        // Get the first byte of the domain which represents the length of the first label
        uint256 labelLength = uint256(uint8(domain[0]));

        // Check to make sure the label length is less than the domain length and greater than zero. 
        require(labelLength < domain.length && labelLength > 0);

        // Create a new byte array to hold the first label
        bytes memory firstLabel = new bytes(labelLength);

        // Iterate through the domain bytes to copy the first label to the new byte array
        // skipping the first byte which represents the length of the first label.
        for (uint256 i = 0; i < labelLength; ++i) {
            firstLabel[i] = domain[i+1];
        }

        // Convert the first label to string and return, with the length of the first label.
        return (string(firstLabel), labelLength);
    }

    /**
     * @dev This function takes a bytes input which represents the DNS name and
     * returns the TLD (last label) of a domain name. A domain can have a maximum of 10 labels.
     * @param domain bytes memory.
     * @return string memory the TLD.
     */

    function getTLD(bytes memory domain) internal pure returns (string memory) {
        // Variable used to keep track of the level count.

        uint levels = 0;
        // Variable used to keep track of the index of each length byte.

        // Iterate through the domain bytes. 
        for (uint i = 0; i < domain.length; i++) {

            // If level count exceed 10, break the loop.
            if (levels > 10) {
                break;
            }

            // Get the label length from the current byte.
            uint labelLength = uint(uint8(domain[i]));

            // Check to make sure we have found the terminal byte and it is equal to zero.
            if(i + labelLength + 2 == domain.length && domain[labelLength + i + 1] == 0) {

                // Create a new byte array to hold the TLD.
                bytes memory lastLabel = new bytes(labelLength);

                // Copy the TLD from the domain array to the new byte array.
                for (uint j = 0; j < labelLength; j++) {
                    lastLabel[j] = domain[i + 1 + j];
                }

                // Convert the TLD to string and return.
                return string(lastLabel);
            }

            // Move to the next label
            i += labelLength;

            // Increment the level count.
            levels++;
        }

        // Revert if TLD not found.
        revert("TLD not found");
    }

    //"\x03123\x03eth\x00";

    function replaceTLD(bytes memory domain, bytes memory newTld) internal pure returns (string memory) {
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

            return string(newName);
        }

        // Revert if TLD not found.
        revert("TLD not found");
    }
}