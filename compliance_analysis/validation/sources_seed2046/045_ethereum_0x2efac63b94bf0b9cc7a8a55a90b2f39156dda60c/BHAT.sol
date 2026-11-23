/*

█████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████
█░░░░░░░░░░░░░░███░░░░░░█████████░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░██░░░░░░░░█░░░░░░██░░░░░░█░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█
█░░▄▀▄▀▄▀▄▀▄▀░░███░░▄▀░░█████████░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀░░██░░▄▀▄▀░░█░░▄▀░░██░░▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█
█░░▄▀░░░░░░▄▀░░███░░▄▀░░█████████░░▄▀░░░░░░▄▀░░█░░▄▀░░░░░░░░░░█░░▄▀░░██░░▄▀░░░░█░░▄▀░░██░░▄▀░░█░░▄▀░░░░░░▄▀░░█░░░░░░▄▀░░░░░░█
█░░▄▀░░██░░▄▀░░███░░▄▀░░█████████░░▄▀░░██░░▄▀░░█░░▄▀░░█████████░░▄▀░░██░░▄▀░░███░░▄▀░░██░░▄▀░░█░░▄▀░░██░░▄▀░░█████░░▄▀░░█████
█░░▄▀░░░░░░▄▀░░░░█░░▄▀░░█████████░░▄▀░░░░░░▄▀░░█░░▄▀░░█████████░░▄▀░░░░░░▄▀░░███░░▄▀░░░░░░▄▀░░█░░▄▀░░░░░░▄▀░░█████░░▄▀░░█████
█░░▄▀▄▀▄▀▄▀▄▀▄▀░░█░░▄▀░░█████████░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀░░█████████░░▄▀▄▀▄▀▄▀▄▀░░███░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█████░░▄▀░░█████
█░░▄▀░░░░░░░░▄▀░░█░░▄▀░░█████████░░▄▀░░░░░░▄▀░░█░░▄▀░░█████████░░▄▀░░░░░░▄▀░░███░░▄▀░░░░░░▄▀░░█░░▄▀░░░░░░▄▀░░█████░░▄▀░░█████
█░░▄▀░░████░░▄▀░░█░░▄▀░░█████████░░▄▀░░██░░▄▀░░█░░▄▀░░█████████░░▄▀░░██░░▄▀░░███░░▄▀░░██░░▄▀░░█░░▄▀░░██░░▄▀░░█████░░▄▀░░█████
█░░▄▀░░░░░░░░▄▀░░█░░▄▀░░░░░░░░░░█░░▄▀░░██░░▄▀░░█░░▄▀░░░░░░░░░░█░░▄▀░░██░░▄▀░░░░█░░▄▀░░██░░▄▀░░█░░▄▀░░██░░▄▀░░█████░░▄▀░░█████
█░░▄▀▄▀▄▀▄▀▄▀▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀░░██░░▄▀░░█░░▄▀▄▀▄▀▄▀▄▀░░█░░▄▀░░██░░▄▀▄▀░░█░░▄▀░░██░░▄▀░░█░░▄▀░░██░░▄▀░░█████░░▄▀░░█████
█░░░░░░░░░░░░░░░░█░░░░░░░░░░░░░░█░░░░░░██░░░░░░█░░░░░░░░░░░░░░█░░░░░░██░░░░░░░░█░░░░░░██░░░░░░█░░░░░░██░░░░░░█████░░░░░░█████
█████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████████
the black shine nft
*/

// SPDX-License-Identifier: MIT

pragma solidity ^0.8.11;
import "./ERC404.sol";
import "./Base64.sol";

contract BHAT is ERC404 {
    constructor(address _owner, uint256 _totalSupply)
        ERC404("BLACKHAT", "BHAT", 18, _totalSupply, _owner)
    {
        balanceOf[_owner] = _totalSupply * 10**18;
        setWhitelist(_owner, true);
    }

    string[] private skinColors = [
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000"
    ];

    string[] private lipColors = [
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000"
    ];
    string[] private shirtColors = [
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000",
        "#000000"
    ];

    function random(string memory input) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(input)));
    }

    function getSkii2nColor(uint256 tokenId) public view returns (string memory) {
        uint256 rand = random(
            string(abi.encodePacked("SKINCOLOR", toString(tokenId)))
        );
        return skinColors[rand % skinColors.length];
    }

    function getLi2pColor(uint256 tokenId) public view returns (string memory) {
        uint256 rand = random(
            string(abi.encodePacked("LIPCOLOR", toString(tokenId)))
        );
        return lipColors[rand % lipColors.length];
    }

    function getShi2rtColor(uint256 tokenId)
        public
        view
        returns (string memory)
    {
        uint256 rand = random(
            string(abi.encodePacked("SHIRTCOLOR", toString(tokenId)))
        );
        return shirtColors[rand % shirtColors.length];
    }

    function pluck(
        uint256 tokenId,
        string memory keyPrefix,
        string[] memory sourceArray
    ) internal pure returns (string memory) {
        uint256 rand = random(
            string(abi.encodePacked(keyPrefix, toString(tokenId)))
        );
        return sourceArray[rand % sourceArray.length];
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        string memory skinColor = getSkii2nColor(tokenId);
        string memory shirtColor = getShi2rtColor(tokenId);
        string memory lipColor = getLi2pColor(tokenId);

        string memory svg = string(
            abi.encodePacked(
                '<svg xmlns="http://www.w3ss.org/2000/svg" width="400" height="400" viewBox="0 0 400 400" fill="none">',
                '<rect width="80" height="40" x="150" y="77" fill="',
                skinColor,
                '"/>',
                '<rect width="80" height="40" x="270" y="77" fill="',
                skinColor,
                '"/>',
                '<rect width="280" height="41" x="110" y="116" fill="',
                skinColor,
                '"/>',
                '<rect width="80" height="41" x="70" y="156" fill="',
                skinColor,
                '"/>',
                '<rect width="40" height="41" x="150" y="156" fill="#ffffff"/>',
                '<rect width="40" height="41" x="190" y="156" fill="#000000"/>',
                '<rect width="80" height="41" x="230" y="156" fill="#ffffff"/>',
                '<rect width="40" height="41" x="310" y="156" fill="#000000"/>',
                '<rect width="40" height="41" x="350" y="156" fill="',
                skinColor,
                '"/>',
                '<rect width="280" height="41" x="70" y="196" fill="',
                skinColor,
                '"/>',
                '<rect width="160" height="41" x="29" y="236" fill="',
                skinColor,
                '"/>',
                '<rect width="161" height="41" x="189" y="236" fill="',
                lipColor,
                '"/>',
                '<rect width="280" height="41" x="29" y="276" fill="',
                skinColor,
                '"/>',
                '<rect width="280" height="41" x="29" y="316" fill="',
                shirtColor,
                '"/>',
                "</svg>"
            )
        );

        string memory json = Base64.encode(
            bytes(
                string(
                    abi.encodePacked(
                        '{"name": "BHAT',
                        toString(tokenId),
                        '", "description": "77 pix format of black hat nft", "image": "data:imagesor/svg+xml;base64,',
                        Base64.encode(bytes(svg)),
                        '"}'
                    )
                )
            )
        );

        return string(abi.encodePacked("data:appldication/json;base64,", json));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) {
            return "0";
        }
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}
