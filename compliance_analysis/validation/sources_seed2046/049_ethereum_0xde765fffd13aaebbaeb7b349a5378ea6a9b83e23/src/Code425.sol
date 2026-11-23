//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC404/ERC404.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Code425 is ERC404 {
    string public baseTokenURI;
    uint mintCount;

    constructor(
        address _owner
    ) ERC404("Code425", "425", 18, 10000, _owner) {
        balanceOf[_owner] = 1000 * 10 ** 18;
        whitelist[_owner] = true;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        if (bytes(baseTokenURI).length > 0) {
            return string.concat(baseTokenURI, Strings.toString(id));
        } 
        return "https://i.postimg.cc/QtK7c8W4/DALL-E-2024-02-08-17-52-40-Imagine-a-digital-futuristic-scale-embodying-the-Ethereum-blockchain.webp";
    }

    function mint() public {
        require(balanceOf[msg.sender] >= 2,"No more");
        require(mintCount++ < 9000,"Max");

        _mint(msg.sender);
    }
}
