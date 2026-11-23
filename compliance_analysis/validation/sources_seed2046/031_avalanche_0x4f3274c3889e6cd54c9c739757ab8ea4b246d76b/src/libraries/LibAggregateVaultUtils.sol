// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { AggregateVaultStorage, LibAggregateVaultStorage } from "../storage/AggregateVaultStorage.sol";
import { NettedPositionTracker } from "./NettedPositionTracker.sol";
import { IGMIWithERC20 as GMI } from "../interfaces/IGMI.sol";
import { OracleWrapper } from "../peripheral/OracleWrapper.sol";
import { DEPLOYMENT_MULTISIG } from "../constants.sol";
import { Pricing } from "./Pricing.sol";
import { SafeCast } from "./SafeCast.sol";
import { PriceCast } from "./PriceCast.sol";
import { IFeeEscrow } from "../interfaces/IFeeEscrow.sol";
import { FeeReserve } from "../peripheral/FeeReserve.sol";

using SafeCast for uint256;
using SafeCast for int256;
using PriceCast for uint256;

/// @title LibAggregateVaultUtils
/// @author Umami Devs
/// @notice A logic library that contains functionality for the AggregateVault
library LibAggregateVaultUtils {
    /**
     * @notice Calculates the GMI amount owned by a vault at a given epoch.
     * @param _vaultIdx The index of the vault.
     * @param _currentEpoch The epoch number.
     * @return _gmiAmount The amount of GMI owned by the vault.
     */
    function getVaultGmi(uint256 _vaultIdx, uint256 _currentEpoch, bool useLlo)
        internal
        view
        returns (uint256 _gmiAmount)
    {
        AggregateVaultStorage.AVStorage storage stg = _getStorage();
        int256[2] memory currentAssetPrices = getVaultTokenPrices(useLlo);
        uint256 indexPrice = useLlo
            ? Pricing.getIndexPps(stg.oracleWrapper, GMI(stg.gmi))
            : Pricing.getIndexPpsChainlink(stg.oracleWrapper, GMI(stg.gmi));
        return getVaultGmiWithPrices(_vaultIdx, _currentEpoch, indexPrice, currentAssetPrices);
    }

    /**
     * @notice Calculates the GMI amount owned by a vault at a given epoch using the currentAssetPrices
     * and indexPrice of the GMI index. This is used when passing an offchain price to calculate the current
     * value.
     * @param _vaultIdx The index of the vault.
     * @param _currentEpoch The epoch number.
     * @param indexPrice The price of one share of the GMI index.
     * @param currentAssetPrices The current prices of [SHORT_TOKEN, LONG_TOKEN] both in 18 decimal format.
     * @return _gmiAmount The amount of GMI owned by the vault.
     */
    function getVaultGmiWithPrices(
        uint256 _vaultIdx,
        uint256 _currentEpoch,
        uint256 indexPrice,
        int256[2] memory currentAssetPrices
    ) internal view returns (uint256 _gmiAmount) {
        AggregateVaultStorage.AVStorage storage stg = _getStorage();
        uint256[2] memory vaultsGmi = [vaultGmiBalanceToken(0), vaultGmiBalanceToken(1)];
        if (_currentEpoch == 0) {
            return vaultsGmi[_vaultIdx];
        } else {
            (,, int256[2] memory gmiPnl,) = NettedPositionTracker.settleNettingPositionPnl(
                stg.nettedPositions,
                currentAssetPrices,
                stg.lastNettedPrices[_currentEpoch],
                vaultsGmi,
                indexPrice,
                stg.zeroSumPnlThreshold
            );
            int256 gmiDelta = gmiPnl[_vaultIdx];
            if (gmiPnl[_vaultIdx] < 0 && vaultsGmi[_vaultIdx] < (-gmiDelta).toUint256()) {
                return 0;
            } else {
                return uint256(vaultsGmi[_vaultIdx].toInt256() + gmiDelta);
            }
        }
    }

    function pullFeeAmountsFromEscrow(uint256[2] memory _feeAmounts) external {
        AggregateVaultStorage.AVStorage storage stg = _getStorage();
        AggregateVaultStorage.VaultState storage vaultState = stg.vaultState;
        FeeReserve feeReserve = FeeReserve(vaultState.depositFeeEscrow);
        // withdrawFeeEscrow is same address post FeeReserve refactor
        feeReserve.pullAsset(_shortToken(), _feeAmounts[0], false);
        feeReserve.pullAsset(_longToken(), _feeAmounts[1], false);
    }

    /**
     * @notice Calculates the proportion of GMI attributed to a vault. 100% = 1e18, 10% = 0.1e18.
     * @param _idx The index of the vault.
     * @return _proportion The proportion of GMI attributed to the vault.
     */
    function getVaultGmiProportion(uint256 _idx) internal view returns (uint256 _proportion) {
        uint256[2] memory gmiAttribution = _getStorage().vaultGmiAttribution;
        uint256 totalAttribution = gmiAttribution[0] + gmiAttribution[1];
        if (totalAttribution == 0) return 0;
        uint256 vaultAttribution = gmiAttribution[_idx];
        return vaultAttribution * 1e18 / totalAttribution;
    }

    /**
     * @notice Calculates the value of GMI held by a vault in the vault native token
     * @param _idx The index of the vault.
     * @return - The value of gmi held by the vault.
     */
    function vaultGmiBalanceToken(uint256 _idx) internal view returns (uint256) {
        uint256 gmiBalance = GMI(_getStorage().gmi).balanceOf(address(this));
        return gmiBalance * getVaultGmiProportion(_idx) / 1e18;
    }

    /**
     * @notice Gets the vault token prices, either on-chain or using the low latency oracle price in storage
     * @param useLlo should use the LLO
     * @return tokenPrices prices of the vault tokens
     */
    function getVaultTokenPrices(bool useLlo) internal view returns (int256[2] memory tokenPrices) {
        address oracle = _getStorage().oracleWrapper;
        uint256 shortTokenPrice = OracleWrapper(payable(oracle)).getChainlinkPrice(_shortToken());
        uint256 longTokenPrice = useLlo
            ? OracleWrapper(payable(oracle)).getLloPriceWithinL1Blocks(_longToken())
            : OracleWrapper(payable(oracle)).getChainlinkPrice(_longToken());
        uint256 shortTokenDecimals = _shortTokenDecimals();
        uint256 longTokenDecimals = _longTokenDecimals();
        return [
            shortTokenPrice.toInternalPrice(shortTokenDecimals).toInt256(),
            longTokenPrice.toInternalPrice(longTokenDecimals).toInt256()
        ];
    }

    /// @dev the total GMI held by vaults may not be equal to the total supply of GMI
    function getVaultsGmi(uint256 epoch, bool useLlo) internal view returns (uint256[2] memory) {
        return [getVaultGmi(0, epoch, useLlo), getVaultGmi(1, epoch, useLlo)];
    }

    /// @dev get the storage struct
    function _getStorage() internal pure returns (AggregateVaultStorage.AVStorage storage stg) {
        stg = LibAggregateVaultStorage.getStorage();
    }

    function _longToken() internal view returns (address) {
        return _getStorage().vaults[1].token;
    }

    function _shortToken() internal view returns (address) {
        return _getStorage().vaults[0].token;
    }

    function _longTokenDecimals() internal view returns (uint256) {
        return _getStorage().vaults[1].decimals;
    }

    function _shortTokenDecimals() internal view returns (uint256) {
        return _getStorage().vaults[0].decimals;
    }
}
