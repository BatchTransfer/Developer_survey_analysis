// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

interface IVerifierProxy {
    function verify(bytes calldata, bytes calldata) external payable returns (bytes memory);

    function s_feeManager() external view returns (address);
}

interface IFeeManager {
    function s_nativeSurcharge() external view returns (uint256);
    function i_rewardManager() external view returns (address);
}
