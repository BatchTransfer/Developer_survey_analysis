// SPDX-License-Identifier: UNLICENCED
pragma solidity 0.8.17;

interface IHandlerContract {
    function callbackSigs() external pure returns (bytes4[] memory);
}
