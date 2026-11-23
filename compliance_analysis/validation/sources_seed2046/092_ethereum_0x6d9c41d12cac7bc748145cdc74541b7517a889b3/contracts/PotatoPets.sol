//SPDX-License-Identifier: UNLICENSED

/*
PotatoPets - ERC404

8888888b.           888             888             8888888b.           888
888   Y88b          888             888             888   Y88b          888
888    888          888             888             888    888          888
888   d88P  .d88b.  888888  8888b.  888888  .d88b.  888   d88P  .d88b.  888888 .d8888b
8888888P"  d88""88b 888        "88b 888    d88""88b 8888888P"  d8P  Y8b 888    88K
888        888  888 888    .d888888 888    888  888 888        88888888 888    "Y8888b.
888        Y88..88P Y88b.  888  888 Y88b.  Y88..88P 888        Y8b.     Y88b.       X88
888         "Y88P"   "Y888 "Y888888  "Y888  "Y88P"  888         "Y8888   "Y888  88888P'

Website: https://www.potato-pet.com

 */
pragma solidity ^0.8.0;

import "./ERC404/ERC404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract PotatoPets is ERC404 {
    string public dataURI;
    string public baseTokenURI;

    constructor() ERC404("Potato Pets", "POTATOPETS", 18, 1000, msg.sender) {
        balanceOf[msg.sender] = 1000 * 10 ** 18;
        whitelist[msg.sender] = true;
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
            string memory rarity;

            if (seed <= 100) {
                image = "1.png";
                rarity = "Commen";
            } else if (seed <= 160) {
                image = "2.png";
                rarity = "Uncommen";
            } else if (seed <= 210) {
                image = "3.png";
                rarity = "Rare";
            } else if (seed <= 240) {
                image = "4.png";
                rarity = "Very Rare";
            } else if (seed <= 255) {
                image = "5.png";
                rarity = "Super Rare";
            }

            string memory jsonPreImage = string.concat(
                string.concat(
                    string.concat(
                        '{"name": "PotatoPets #',
                        Strings.toString(id)
                    ),
                    '","description":"Welcome to Potato Pets, where digital art meets blockchain. 1,000 unique NFTs with charming potato companions crafted on ERC 404 protocol.","external_url":"https://potato-pet.com","image":"'
                ),
                string.concat(dataURI, image)
            );
            string memory jsonPostImage = string.concat(
                '","attributes":[{"trait_type":"Rarity","value":"',
                rarity
            );
            string memory jsonPostTraits = '"}]}';

            return
                string.concat(
                    "data:application/json;utf8,",
                    string.concat(
                        string.concat(jsonPreImage, jsonPostImage),
                        jsonPostTraits
                    )
                );
        }
    }
}
