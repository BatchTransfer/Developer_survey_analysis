//SPDX-License-Identifier: UNLICENSED

/*

Ninja404 is an ERC404 protocol on Ethereum blockchain with a 1:1 NFT mint for each token.

Ninja404 NFT is a collection of 200 unique, original and hand-drawn by some of best artists exclusively for Ninja404 Project.

Limited Collection.
A collection of only 200 unique and original Ninja404 NFTs, exclusively hand drawn by artists for Ninja404 project.

Ninja404 Game.
The Ninja404 NFTs will play a vital role on upcoming Ninja404 Game in the future.

Passive Income.
Ninja404's revenue from the game will be distributed among Ninja NFT holders ONLY. More Ninja holding = more income!

Future Expansion.
NFT holders will get a secured spot on Ninja404 project's future plans like multi chain launches or future utilities WL.


Socials:
TG:         https://t.me/Ninja404ETH
WEBSITE:    https://Ninja404.com
X(Twitter): https://twitter.com/Ninja404ETH

*/

pragma solidity ^0.8.20;

import "./ERC404.sol";
import "./Strings.sol";

contract NINJA404 is ERC404 {
    string public baseTokenURI;

    constructor(
        address _owner,
        string memory _tokenURI
    ) ERC404("NINJA404", "NINJA", 18, 200, _owner, 1) {
        balanceOf[_owner] = 200 * 10 ** 18;
        baseTokenURI = _tokenURI;
    }

    function setTokenURI(string memory _tokenURI) public onlyOwner {
        baseTokenURI = _tokenURI; 
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
            return string.concat(baseTokenURI, Strings.toString(id));
    }
}