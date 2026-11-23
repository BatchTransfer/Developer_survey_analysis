// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

interface IFeeEscrow {
    function pullFeesAndVest(uint256[2] memory _feeAmounts, address keeper, uint256 keeperBps) external;

    function setVaultReturnBips(uint256 _newBips) external;
}
