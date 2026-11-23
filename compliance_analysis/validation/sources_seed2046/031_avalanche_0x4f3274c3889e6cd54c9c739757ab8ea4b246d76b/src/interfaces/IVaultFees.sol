// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

interface IVaultFees {
    function getVaultRebalanceFees(address vault, uint256 lastRebalance)
        external
        returns (uint256, uint256, uint256, uint256);

    function getWithdrawalFee(address vault, uint256 size, bool useLlo) external view returns (uint256, uint256);

    function getDepositFee(address vault, uint256 size, bool useLlo) external view returns (uint256);

    function _getVaultRebalanceFees(
        uint256 currentBalance,
        bool isAboveWatermark,
        uint256 performanceFeePercent,
        uint256 managementFeePercent
    ) external returns (uint256 _performanceFeeInAsset, uint256 _managementFeeInAsset, uint256 _totalVaultFee);
}
