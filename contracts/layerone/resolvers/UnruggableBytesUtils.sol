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
}