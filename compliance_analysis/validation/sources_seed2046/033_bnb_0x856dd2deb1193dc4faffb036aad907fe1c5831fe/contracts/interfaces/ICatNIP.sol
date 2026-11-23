// SPDX-License-Identifier: MIT

pragma solidity ^0.8.6;


interface ICatNIP {

    function totalSupply() external view returns (uint256);

    function routerAddressForDEX() external view returns (address);
    function pancakeswapPair() external view returns (address);
    
    function isBannedFromAllGamesForManipulation(address) external view returns (bool);
    function isGameSystemEnabled() external view returns (bool);

    function depositWallet() external view returns (address);
    function directorAccount() external view returns (address);

    function GetNipDepositAmountTotal(address) external view returns (uint256);
    function GetGasDepositAmountTotal(address) external view returns (uint256);
    function GetDepositsAmountTotal(address) external view returns (uint256, uint256);


    function DecreaseDepositAmountTotal(uint256, address) external;

    function RandomNumberForGamesViewable() external view returns (uint256);


    
}
