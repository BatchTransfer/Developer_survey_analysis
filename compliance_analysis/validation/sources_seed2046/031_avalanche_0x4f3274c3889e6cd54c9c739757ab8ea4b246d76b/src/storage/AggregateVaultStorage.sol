// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { Delegatecall } from "../libraries/Delegatecall.sol";
import { IHookExecutor, HookType } from "../interfaces/IHookExecutor.sol";
import { IPositionManager } from "../interfaces/IPositionManager.sol";
import { IArbSys } from "../interfaces/IArbSys.sol";
import { ARBSYS } from "../constants.sol";

bytes32 constant STORAGE_SLOT = keccak256("AggregateVault.storage");

/// @title LibAggregateVaultStorage
/// @author Umami Devs
/// @notice Library for some storage logic
library LibAggregateVaultStorage {
    function getStorage() internal pure returns (AggregateVaultStorage.AVStorage storage _storage) {
        bytes32 slot = STORAGE_SLOT;

        assembly {
            _storage.slot := slot
        }
    }

    function getTokenToAssetVaultIndex()
        internal
        view
        returns (mapping(address => uint256) storage _tokenToAssetVaultIndex)
    {
        _tokenToAssetVaultIndex = getStorage().tokenToAssetVaultIndex;
    }

    /**
     * @dev Retrieves the vault state from storage.
     * @return _vaultState The current vault state.
     */
    function getVaultState() internal view returns (AggregateVaultStorage.VaultState storage _vaultState) {
        _vaultState = getStorage().vaultState;
    }

    /**
     * @dev Retrieves the current rebalance state from storage.
     * @return _rebalanceState The current rebalance state.
     */
    function getRebalanceState() internal view returns (AggregateVaultStorage.RebalanceState storage _rebalanceState) {
        _rebalanceState = getStorage().rebalanceState;
    }

    function getEmitter() internal view returns (address _emitter) {
        _emitter = getStorage().emitter;
    }
}

/// @title AggregateVaultStorage
/// @author Umami Devs
/// @notice Storage inheritance for AggregateVault
abstract contract AggregateVaultStorage {
    error InvalidAsset();

    enum CallType {
        Call,
        DelegateCall
    }

    struct AssetVaultStorage {
        // size 8
        address vault; // 0
        address token; // 1
        address timelockYieldBoost; // 2
        uint256 feeWatermarkPPS; // 3
        uint256 feeWatermarkDate; // 4
        int256 epochDelta; // 5
        uint256 lastCheckpointTvl; // 6
        uint256 timelockBoostPercent; // 7
        uint8 decimals;
    }

    struct SetPricesParams {
        address[] realtimeFeedTokens;
        bytes[] realtimeFeedData;
    }

    struct RebalanceState {
        // size 6
        uint256[2] indexAllocation; // 0
        uint256[2] indexComposition; // 2
        int256 externalPosition; // 4
        uint256 epoch; // 5
    }

    struct VaultState {
        // size 12
        uint256 epoch; // 0
        bool rebalanceOpen; // 1
        uint256 lastRebalanceTime; // 2
        address feeRecipient; // 3
        address depositFeeEscrow; // 4
        address withdrawalFeeEscrow; // 5
        uint256[2] indexAllocation; // 6
        uint256[2] vaultCaps; // 8
        uint256[2] rebalancePPS; // 10
    }

    struct VaultFees {
        // size 4
        uint256 performanceFee; // 0
        uint256 managementFee; // 1
        uint256 withdrawalFee; // 2
        uint256 depositFee; // 3
    }

    /// @dev open close request
    struct OCRequest {
        address sender;
        address account;
        address vault;
        address callback;
        bool isDeposit;
        uint256 amount;
        uint256 minOut;
        uint256 requestBlock;
    }

    struct AVStorage {
        /// @dev vault state
        VaultState vaultState; // 0-11
        /// @notice The array of asset vault entries.
        AssetVaultStorage[2] vaults; // 12-19, 19-26
        /// @dev vault fee storage
        VaultFees vaultFees; // 27-30
        /// @notice The mapping of token addresses to asset vault indices.
        mapping(address => uint256) tokenToAssetVaultIndex; // 31
        /// @notice The mapping of vault indices to asset vault indices.
        mapping(address => uint256) vaultToAssetVaultIndex; // 32
        /// @notice The current rebalance state.
        RebalanceState rebalanceState; // 33-39
        /// @dev |.....||depositHook|withdrawHook|openHook|closeHook|
        bytes32 hooksConfig; // 40
        address hookHandler; // 41
        /// @dev event emitter
        address emitter;
        uint256 requestNonce;
        /// @notice The array of position manager contracts.
        IPositionManager[] positionManagers; // 44
        /// @dev active external position size
        int256 externalPosition; // 45
        /// @dev the vault netted positions
        int256[2][2] nettedPositions; // 46-49
        /// @dev open/close request storage: nonce => request
        mapping(uint256 => OCRequest) pendingRequests; // 50
        /// @dev execution keeper address for gas rebates
        address rebalanceKeeper; // 51
        /// @dev fee logic
        address feeHelper; // 52
        /// @dev execution amount for regular request
        uint256 executionGasAmount; // 53
        /// @dev execution amount for callback request
        uint256 executionGasAmountCallback; // 54
        /// @notice Maps epoch IDs to the last netted prices.
        mapping(uint256 => int256[2]) lastNettedPrices; // 55
        /// @notice The zero sum PnL threshold value.
        uint256 zeroSumPnlThreshold;
        /// @dev block tolerance for acceptable LLO price
        uint8 L1BlockTolerance;
        /// @notice Flag to indicate whether netting should be checked.
        bool shouldCheckNetting; // 57
        /// @notice The netted threshold value.
        uint256 nettedThreshold;
        /// @notice oracle contract.
        address oracleWrapper;
        uint256[2] vaultGmiAttribution; // SHORT_TOKEN, LONG_TOKEN
        /// @notice GMI index
        address payable gmi;
        /// @notice Active helper contract
        address aggregateVaultHelper;
        /// @notice active GMX V2 handler contract
        address gmxV2Handler;
        /// @notice Active request handler
        address requestHandler;
        /// @notice If the GMX fee logic should be used on deposit/withdrawal
        bool shouldUseGmxFee;
        /// @notice UNIV3 swap manager
        address uniswapV3SwapManager;
        /// @notice Slippage param for uniswap
        uint256 swapSlippage;
        /// @notice if the last pps was above watermark
        bool[2] isAboveWatermark;
    }

    /**
     * @dev Retrieves the storage struct of the contract.
     * @return _storage The storage struct containing all contract state variables.
     */
    function _getStorage() internal pure returns (AVStorage storage _storage) {
        _storage = LibAggregateVaultStorage.getStorage();
    }

    /**
     * @dev Retrieves the vault state from storage.
     * @return _vaultState The current vault state.
     */
    function _getVaultState() internal view returns (VaultState storage _vaultState) {
        _vaultState = _getStorage().vaultState;
    }

    function _getEmitter() internal view returns (address _emitter) {
        _emitter = _getStorage().emitter;
    }

    function _getRequestHandler() internal view returns (address _rhandler) {
        _rhandler = _getStorage().requestHandler;
    }

    function _getOracleWrapper() internal view returns (address) {
        return _getStorage().oracleWrapper;
    }

    function _getGmxV2Handler() internal view returns (address) {
        return _getStorage().gmxV2Handler;
    }

    function _getShouldUseGmxFee() internal view returns (bool) {
        return _getStorage().shouldUseGmxFee;
    }

    function _getL1BlockTolerance() internal view returns (uint8) {
        return _getStorage().L1BlockTolerance;
    }

    /**
     * @dev Retrieves the vault entries array from storage.
     * @return vaults The array of asset vault entries.
     */
    function _getAssetVaultEntries() internal view returns (AssetVaultStorage[2] storage) {
        return _getStorage().vaults;
    }

    /**
     * @dev Sets the rebalance keeper in storage.
     */
    function _setL1BlockTolerance(uint8 newTolerance) internal {
        _getStorage().L1BlockTolerance = newTolerance;
    }

    /**
     * @dev Sets the rebalance keeper in storage.
     */
    function _setRebalanceKeeper(address newKeeper) internal {
        _getStorage().rebalanceKeeper = newKeeper;
    }

    /**
     * @dev Retrieves the current rebalance state from storage.
     * @return _rebalanceState The current rebalance state.
     */
    function _getRebalanceState() internal view returns (RebalanceState storage _rebalanceState) {
        _rebalanceState = _getStorage().rebalanceState;
    }

    /**
     * @dev Retrieves the netted threshold from storage.
     * @return _nettedThreshold The current netted threshold value.
     */
    function _getNettedThreshold() internal view returns (uint256 _nettedThreshold) {
        _nettedThreshold = _getStorage().nettedThreshold;
    }

    /**
     * @dev Retrieves the array of position managers from storage.
     * @return _positionManagers The array of position managers.
     */
    function _getPositionManagers() internal view returns (IPositionManager[] storage _positionManagers) {
        _positionManagers = _getStorage().positionManagers;
    }

    /**
     * @dev Retrieves the vault to asset vault index mapping from storage.
     * @return _vaultToAssetVaultIndex The mapping of vault addresses to asset vault indexes.
     */
    function _getVaultToAssetVaultIndex()
        internal
        view
        returns (mapping(address => uint256) storage _vaultToAssetVaultIndex)
    {
        _vaultToAssetVaultIndex = _getStorage().vaultToAssetVaultIndex;
    }

    /**
     * @dev Retrieves the token to asset vault index mapping from storage.
     * @return _tokenToAssetVaultIndex The mapping of token addresses to asset vault indexes.
     */
    function _getTokenToAssetVaultIndex()
        internal
        view
        returns (mapping(address => uint256) storage _tokenToAssetVaultIndex)
    {
        _tokenToAssetVaultIndex = _getStorage().tokenToAssetVaultIndex;
    }

    /**
     * @dev Retrieves the netted positions matrix from storage.
     * @return _nettedPositions The matrix of netted positions.
     */
    function _getNettedPositions() internal view returns (int256[2][2] storage _nettedPositions) {
        _nettedPositions = _getStorage().nettedPositions;
    }

    /**
     * @dev Retrieves the netted prices at epoch.
     * @return _nettedPrices The array of netted prices.
     */
    function _getNettedPrices(uint256 epoch) internal view returns (int256[2] storage _nettedPrices) {
        _nettedPrices = _getStorage().lastNettedPrices[epoch];
    }

    /**
     * @dev Retrieves the zero sum PnL threshold from storage.
     * @return _zeroSumPnlThreshold The current zero sum PnL threshold value.
     */
    function _getZeroSumPnlThreshold() internal view returns (uint256 _zeroSumPnlThreshold) {
        _zeroSumPnlThreshold = _getStorage().zeroSumPnlThreshold;
    }

    /**
     * @dev Retrieves the external position from storage.
     * @return _extenralPosition The positions.
     */
    function _getExternalPosition() internal view returns (int256 _extenralPosition) {
        _extenralPosition = _getStorage().externalPosition;
    }

    /**
     * @dev Retrieves the fee helper from storage.
     * @return _feeHelper The current fee helper.
     */
    function _getFeeHelper() internal view returns (address _feeHelper) {
        _feeHelper = _getStorage().feeHelper;
    }

    /**
     * @dev Retrieves the vault fees struct from storage.
     * @return _vaultFees The current vault fees.
     */
    function _getVaultFees() internal view returns (VaultFees storage _vaultFees) {
        _vaultFees = _getStorage().vaultFees;
    }

    /**
     * @dev Retrieves the asset vault entry for the given asset address.
     * @param asset The asset address for which to retrieve the vault entry.
     * @return vault The asset vault entry for the given asset address.
     */
    function _getVaultFromAsset(address asset) internal view returns (AssetVaultStorage storage vault) {
        AssetVaultStorage[2] storage vaults = _getAssetVaultEntries();
        if (vaults[0].token == asset) {
            return vaults[0];
        } else if (vaults[1].token == asset) {
            return vaults[1];
        } else {
            revert InvalidAsset();
        }
    }

    /**
     * @dev Sets the netted positions matrix in storage.
     * @param _nettedPositions The updated netted positions matrix.
     */
    function _setPositions(int256[2][2] memory _nettedPositions, int256 _externalPosition) internal {
        int256[2][2] storage nettedPositions = _getNettedPositions();
        _getStorage().externalPosition = _externalPosition;
        nettedPositions[0][0] = _nettedPositions[0][0];
        nettedPositions[0][1] = _nettedPositions[0][1];
        nettedPositions[1][0] = _nettedPositions[1][0];
        nettedPositions[1][1] = _nettedPositions[1][1];
    }

    /**
     * @dev Sets the vault GMI attribution array in storage.
     * @param vaultGmiAttribution The updated vault GMI attribution array.
     */
    function _setVaultGmiAttribution(uint256[2] memory vaultGmiAttribution) internal {
        uint256[2] storage gmiAttribution = _getStorage().vaultGmiAttribution;
        gmiAttribution[0] = vaultGmiAttribution[0];
        gmiAttribution[1] = vaultGmiAttribution[1];
    }

    /**
     * @notice Get the AssetVaultEntry at the given index.
     * @param _idx The index of the AssetVaultEntry.
     * @return _assetVault The AssetVaultEntry at the given index.
     */
    function _getAssetVaultEntry(uint256 _idx) internal view returns (AssetVaultStorage storage _assetVault) {
        _assetVault = _getAssetVaultEntries()[_idx];
    }

    // HOOKS
    // ------------------------------------------------------------------------

    function _isHookEnabledMask(HookType _type) internal pure returns (uint256) {
        uint256 hookNum = uint256(_type);
        return 1 << ((hookNum * 2) + 1);
    }

    function _hookCallTypeMask(HookType _type) internal pure returns (uint256) {
        uint256 hookNum = uint256(_type);
        return 1 << (hookNum * 2);
    }

    function _getHook(HookType _type) internal view returns (bool _isEnabled, bool _isDelegateHook) {
        bytes32 config = _getStorage().hooksConfig;
        uint256 isEnabledMask = _isHookEnabledMask(_type);
        uint256 callTypeMask = _hookCallTypeMask(_type);
        _isEnabled = (uint256(config) & isEnabledMask) != 0;
        _isDelegateHook = (uint256(config) & callTypeMask) != 0;
    }

    function _enableHook(HookType _type, CallType _callType) internal {
        bytes32 config = _getStorage().hooksConfig;
        uint256 isEnabledMask = _isHookEnabledMask(_type);
        uint256 callTypeMask = _hookCallTypeMask(_type);
        // cleared
        config = bytes32(uint256(config) & ~(isEnabledMask | callTypeMask));
        // set
        config = bytes32(uint256(config) | isEnabledMask | (_callType == CallType.DelegateCall ? callTypeMask : 0));
        _getStorage().hooksConfig = config;
    }

    function _disableHook(HookType _type) internal {
        bytes32 config = _getStorage().hooksConfig;
        uint256 isEnabledMask = _isHookEnabledMask(_type);
        uint256 callTypeMask = _hookCallTypeMask(_type);
        config = bytes32(uint256(config) & ~(isEnabledMask | callTypeMask));
        _getStorage().hooksConfig = config;
    }

    function _executeHook(HookType _hookType, bytes memory _cd) internal returns (bytes memory) {
        (bool isEnabled, bool isDelegateHook) = _getHook(_hookType);
        if (isEnabled) {
            address hookHandler = _getStorage().hookHandler;
            bytes memory hcd = abi.encodeCall(IHookExecutor.executeHook, (_hookType, _cd));

            if (isDelegateHook) {
                return Delegatecall.delegateCall(hookHandler, hcd);
            } else {
                (bool success, bytes memory ret) = hookHandler.call(hcd);
                if (!success) {
                    assembly {
                        let length := mload(ret)
                        let start := add(ret, 0x20)
                        revert(start, length)
                    }
                }
                return ret;
            }
        }
        return hex"";
    }

    function _getBlockNumber() internal view returns (uint256 _blockNumber) {
        _blockNumber = block.number;
    }

    // REQUESTS
    // ------------------------------------------------------------------------

    function _saveRequest(
        address sender,
        address account,
        address vault,
        address callback,
        bool isDeposit,
        uint256 amount,
        uint256 minOut
    ) internal returns (uint256 requestNonce) {
        AVStorage storage stg = _getStorage();
        stg.pendingRequests[++stg.requestNonce] = OCRequest({
            sender: sender,
            account: account,
            vault: vault,
            callback: callback,
            isDeposit: isDeposit,
            amount: amount,
            minOut: minOut,
            requestBlock: _getBlockNumber()
        });
        return stg.requestNonce;
    }

    function _getRequest(uint256 key) internal view returns (OCRequest memory order) {
        AVStorage storage stg = _getStorage();
        order = stg.pendingRequests[key];
    }

    function _getLongToken() internal view returns (address _longToken) {
        _longToken = _getStorage().vaults[1].token;
    }

    function _getShortToken() internal view returns (address _shortToken) {
        _shortToken = _getStorage().vaults[0].token;
    }
}
