// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { AggregateVaultStorage, IPositionManager } from "../storage/AggregateVaultStorage.sol";
import { Emitter } from "../peripheral/Emitter.sol";
import { OracleWrapper } from "../peripheral/OracleWrapper.sol";

/// @title StorageViewer
/// @author Umami Devs
contract StorageViewer is AggregateVaultStorage {
    function getRequest(uint256 key) external view returns (OCRequest memory order) {
        return _getRequest(key);
    }

    function getEmitter() external view returns (Emitter) {
        return Emitter(_getStorage().emitter);
    }

    function rebalanceOpen() external view returns (bool) {
        return _getVaultState().rebalanceOpen;
    }

    function getOracleWrapper() external view returns (OracleWrapper) {
        return OracleWrapper(payable(_getStorage().oracleWrapper));
    }

    function getVaultState() external view returns (VaultState memory) {
        return _getStorage().vaultState;
    }

    function getAssetVaults() external view returns (AssetVaultStorage[2] memory _vaults) {
        _vaults = _getStorage().vaults;
    }

    function getTokenToAssetVaultIndex(address _token) external view returns (uint256 _index) {
        _index = _getStorage().tokenToAssetVaultIndex[_token];
    }

    function getVaultToAssetVaultIndex(address _vault) external view returns (uint256 _index) {
        _index = _getStorage().vaultToAssetVaultIndex[_vault];
    }

    function getRebalanceState() external view returns (RebalanceState memory _rebalanceState) {
        _rebalanceState = _getStorage().rebalanceState;
    }

    function getVaultFees() external view returns (VaultFees memory _vaultFees) {
        _vaultFees = _getStorage().vaultFees;
    }

    function getEpoch() external view returns (uint256 _epoch) {
        _epoch = _getStorage().vaultState.epoch;
    }

    function getBlockTolerance() external view returns (uint8 _blockTolerance) {
        _blockTolerance = _getStorage().L1BlockTolerance;
    }

    function getPositionManagers() external view returns (IPositionManager[] memory) {
        return _getStorage().positionManagers;
    }

    function getHookHandler() external view returns (address) {
        return _getStorage().hookHandler;
    }

    function getRebalanceKeeper() external view returns (address) {
        return _getStorage().rebalanceKeeper;
    }

    function getNettedThreshold() external view returns (uint256) {
        return _getStorage().nettedThreshold;
    }

    function getFeeHelper() external view returns (address) {
        return _getStorage().feeHelper;
    }

    function getGmi() external view returns (address) {
        return _getStorage().gmi;
    }

    function getAggregateVaultHelper() external view returns (address) {
        return _getStorage().aggregateVaultHelper;
    }

    function getGmxV2Handler() external view returns (address) {
        return _getStorage().gmxV2Handler;
    }

    function getRequestHandler() external view returns (address) {
        return _getStorage().requestHandler;
    }

    function getUniswapV3SwapManager() external view returns (address) {
        return _getStorage().uniswapV3SwapManager;
    }

    function getSwapSlippage() external view returns (uint256) {
        return _getStorage().swapSlippage;
    }

    function getRequestNonce() external view returns (uint256) {
        return _getStorage().requestNonce;
    }

    function getExecutionGasAmount() external view returns (uint256) {
        return _getStorage().executionGasAmount;
    }

    function getExecutionGasAmountCallback() external view returns (uint256) {
        return _getStorage().executionGasAmountCallback;
    }

    function getZeroSumPnlThreshold() external view returns (uint256) {
        return _getStorage().zeroSumPnlThreshold;
    }

    function getL1BlockTolerance() external view returns (uint256) {
        return _getStorage().L1BlockTolerance;
    }

    function getShouldCheckNetting() external view returns (bool) {
        return _getStorage().shouldCheckNetting;
    }

    function getShouldUseGmxFee() external view returns (bool) {
        return _getStorage().shouldUseGmxFee;
    }

    function getEpochStorageKey() external view returns (bytes32 _key) {
        VaultState storage vaultState = _getStorage().vaultState;
        assembly {
            _key := vaultState.slot
        }
    }

    function readStorageSlots(bytes32[] calldata _slots) external view returns (bytes32[] memory _values) {
        _values = new bytes32[](_slots.length);
        for (uint256 i; i < _slots.length; i++) {
            uint256 value;
            bytes32 slot = _slots[i];
            assembly {
                value := sload(slot)
            }
            _values[i] = bytes32(value);
        }
    }

    function gasRequirement(bool _callback) external view returns (uint256) {
        return _callback ? _getStorage().executionGasAmountCallback : _getStorage().executionGasAmount;
    }

    function getExternalPosition() external view returns (int256) {
        return _getStorage().externalPosition;
    }

    function getLastNettedPrice(uint256 _epoch) external view returns (int256[2] memory _prices) {
        _prices = _getStorage().lastNettedPrices[_epoch];
    }

    function getVaultGmiAttribution() external view returns (uint256[2] memory _vaultGmiAttribution) {
        _vaultGmiAttribution = _getStorage().vaultGmiAttribution;
    }

    function getLongAndShortToken() external view returns (address _longToken, address _shortToken) {
        _shortToken = _getStorage().vaults[0].token;
        _longToken = _getStorage().vaults[1].token;
    }
}
