//SPDX-License-Identifier: UNLICENSED

// Website: https://capo404.com
// Twitter/X: https://twitter.com/capo_404
// Telegram: https://t.me/capo404

pragma solidity ^0.8.0;

import "./ERC404/ERC404.sol";
import "./utils/Strings.sol";

contract Capo404 is ERC404 {
    string public dataURI;
    string public baseTokenURI;

    constructor(
        address _owner
    ) ERC404("Capo404", "CAPO", 18, 1000, _owner) {
        balanceOf[_owner] = 1000 * 10 ** 18;
        dataURI = "ipfs://bafybeigvzb7zsqymkznwnjinaka3tdbfx3hdzrar3i3nwljftydsah55oi/";
    }

    function setDataURI(string memory _dataURI) public onlyOwner {
        dataURI = _dataURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function setNameSymbol(
        string memory _name,
        string memory _symbol
    ) public onlyOwner {
        _setNameSymbol(_name, _symbol);
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, Strings.toString(id));
        } else {
            uint8 seed = uint8(bytes1(keccak256(abi.encodePacked(id))));
            string memory image;

            if (seed + 1 > 236) {
                image = string.concat(Strings.toString(1), ".png");
            } else {
                image = string.concat(Strings.toString(seed + 1), ".png");
            }

            string memory jsonPreImage = string.concat(
                string.concat(
                    string.concat('{"name": "Capo #', Strings.toString(id)),
                    '","description":"A collection of 1,000 Replicants enabled by ERC404, an experimental token standard","external_url":"https://capo404.com","image":"'
                ),
                string.concat(dataURI, image)
            );
            string memory jsonPostTraits = '"}';

            return
                string.concat(
                    "data:application/json;utf8,",
                    string.concat(
                        jsonPreImage,
                        jsonPostTraits
                    )
                );
        }
    }
}