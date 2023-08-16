//SPDX-License-Identifier: MIT
pragma solidity ~0.8.17;

import {IMetadataService} from "ens-contracts/wrapper/IMetadataService.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract L2MetadataService is IMetadataService {
    string private _uri;

    constructor(string memory _metaDataUri) {
        _uri = _metaDataUri;
    }

    function uri(uint256 _tokenId) public view returns (string memory) {

        return string.concat(
            _uri,
            Strings.toString(_tokenId)
        );
    }
}
