// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { ERC20 } from "solmate/tokens/ERC20.sol";
import { TransferUtils } from "../libraries/TransferUtils.sol";
import { Auth, GlobalACL, SWAP_KEEPER, KEEPER_ROLE, REQUEST_HANDLER } from "../Auth.sol";
import { AssetVault } from "./AssetVault.sol";
import { AggregateVaultStorage } from "../storage/AggregateVaultStorage.sol";
import { PositionManagerRouter, WhitelistedTokenRegistry } from "../position-managers/PositionManagerRouter.sol";
import { Multicall } from "../libraries/Multicall.sol";
import { NettingMath } from "../libraries/NettingMath.sol";
import { HookType } from "../interfaces/IHookExecutor.sol";
import { Emitter } from "../peripheral/Emitter.sol";
import { Delegatecall } from "../libraries/Delegatecall.sol";
import { OracleWrapper } from "../peripheral/OracleWrapper.sol";
import { AggregateVaultHelper } from "../peripheral/AggregateVaultHelper.sol";
import { IAssetVault } from "../interfaces/IAssetVault.sol";
import { IVaultFees } from "../interfaces/IVaultFees.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { IPositionManager } from "../interfaces/IPositionManager.sol";
import { Solarray } from "../libraries/Solarray.sol";

enum Peripheral {
    HookHandler,
    EventEmitter,
    OracleWrapper,
    GMI,
    AggregateVaultHelper,
    GmxV2Handler,
    FeeHelper,
    RequestHandler,
    UniswapV3SwapManager
}

enum ConfigItem {
    VaultFees,
    ShouldCheckNetting,
    ShouldUseGmxFee,
    L1BlockTolerance,
    ExecutionGasAmounts,
    RebalanceKeeper,
    FeeRecipient,
    VaultCaps,
    Thresholds
}

using Delegatecall for address;
using SafeTransferLib for ERC20;

/// @title AggregateVault
/// @author Umami Devs
/// @notice Contains common logic for all asset vaults and core keeper interactions
contract AggregateVault is Multicall, AggregateVaultStorage, PositionManagerRouter, GlobalACL {
    // ERRORS
    // ------------------------------------------------------------------------------------------

    /// @dev address should not be zero
    error ZeroAddress();
    /// @dev gas is not above the min required for the keeper execution
    error MinGasRequirement();
    /// @dev amount should be greater than 0
    error AmountEqualsZero();
    /// @dev vault rebalance is open
    error RebalanceOpen();
    /// @dev vault rebealance is closed
    error RebalanceNotOpen();
    /// @dev netting check has failed for the parameters passed
    error FailedNettingCheck();
    /// @dev config validation failed on set
    error FailedConfigValidation();
    /// @dev delevate view did not revert
    error DelegateViewRevert();
    /// @dev oracle price length is not equal to config requirement
    error OraclePriceSizeInvalid();
    /// @dev caller is not the asset vault
    error NotAssetVault();
    /// @dev not RequestHandler or AssetVault
    error notRequestHandlerOrAssetVault();
    /// @dev already paused
    error AggregateVault__AlreadyPaused();
    /// @dev invalid config item
    error AggregateVault__InvalidConfigItem();

    constructor(Auth _auth, WhitelistedTokenRegistry _whitelistedTokenRegistry)
        PositionManagerRouter(_whitelistedTokenRegistry)
        GlobalACL(_auth)
    { }

    // DEPOSIT & WITHDRAW
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Handles a deposit of a specified amount of an ERC20 asset into the AggregateVault from an account, with a deposit fee deducted.
     * @param assets The amount of the asset to be deposited.
     * @param account The address of the account from which the deposit will be made.
     */
    function handleDeposit(uint256 assets, uint256 minOutAfterFees, address account, address sender, address callback)
        external
        payable
        onlyAssetVault
    {
        if (assets == 0) revert AmountEqualsZero();
        if (account == address(0)) revert ZeroAddress();
        AVStorage storage stg = _getStorage();
        uint256 gas = _gasRequirement(callback != address(0));
        if (msg.value < gas * tx.gasprice) revert MinGasRequirement();

        // store request data
        uint256 key = _saveRequest(sender, account, msg.sender, callback, true, assets, minOutAfterFees);

        // send execution gas cost
        TransferUtils.transferNativeAsset(stg.rebalanceKeeper, msg.value);

        _executeHook(HookType.DEPOSIT_HOOK, msg.data[4:]);

        // emit request event
        Emitter(stg.emitter).emitDepositRequest(key, account, msg.sender);
    }

    /**
     * @notice Handles a withdrawal of a specified amount of an ERC20 asset from the AggregateVault to an account, with a withdrawal fee deducted.
     * @param shares The amount of the shares to be withdrawn.
     * @param account The address of the account to which the withdrawal will be made.
     */
    function handleWithdraw(uint256 shares, uint256 minOutAfterFees, address account, address sender, address callback)
        external
        payable
        onlyAssetVault
    {
        if (shares == 0) revert AmountEqualsZero();
        if (account == address(0)) revert ZeroAddress();
        AVStorage storage stg = _getStorage();
        uint256 gas = _gasRequirement(callback != address(0));
        if (msg.value < gas * tx.gasprice) revert MinGasRequirement();

        // store request data
        uint256 key = _saveRequest(sender, account, msg.sender, callback, false, shares, minOutAfterFees);

        // send execution gas cost
        TransferUtils.transferNativeAsset(stg.rebalanceKeeper, msg.value);

        _executeHook(HookType.WITHDRAW_HOOK, msg.data[4:]);

        // emit request event
        Emitter(stg.emitter).emitWithdrawalRequest(key, account, msg.sender);
    }

    /**
     * @notice clear a request from storage when a request is cancelled or fulfilled by handler
     */
    function clearRequest(uint256 key) external onlyRequestHandlerOrAssetVault returns (OCRequest memory order) {
        AVStorage storage stg = _getStorage();
        order = stg.pendingRequests[key];
        delete stg.pendingRequests[key];
    }

    /**
     * @notice releases funds for withdrawal to the user, can only be called by the request handler
     * @param underlyingToken the underlying vault token for the request
     * @param account the account the request was made for
     * @param assets the amounf of assets
     * @param baseWithdrawalFee size of the base withdrawal fee calculated in request handler
     * @param managmentPerformanceFee the size of the managment and performance fee prorata for the withdrawal
     */
    function releaseWithdrawal(
        address underlyingToken,
        address account,
        uint256 assets,
        uint256 baseWithdrawalFee,
        uint256 managmentPerformanceFee
    ) external onlyRequestHandler {
        TransferUtils.transferAsset(underlyingToken, account, assets);
        VaultState storage vaultState = _getVaultState();
        if (baseWithdrawalFee > 0) {
            TransferUtils.transferAsset(underlyingToken, vaultState.withdrawalFeeEscrow, baseWithdrawalFee);
        }
        if (managmentPerformanceFee > 0) {
            TransferUtils.transferAsset(underlyingToken, vaultState.feeRecipient, managmentPerformanceFee);
        }
    }

    /**
     * @notice Increments the epoch deposit/withdraw delta.
     */
    function incrementEpochDelta(address asset, int256 amount) external onlyRequestHandler {
        AssetVaultStorage storage vaultStg = _getVaultFromAsset(asset);
        vaultStg.epochDelta += amount;
    }

    // REBALANCE
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Executes a multicall in the context of the aggregate vault.
     * @param data the calls to be executed.
     * @return results the return values of each call.
     */
    function multicall(bytes[] calldata data)
        external
        payable
        onlyRole(KEEPER_ROLE)
        returns (bytes[] memory results, uint256[] memory gasEstimates)
    {
        (results, gasEstimates) = _multicall(data);
    }

    /**
     * @notice Opens the rebalance period and validates next rebalance state.
     * @param nextVaultIndexAlloc next vault GMI allocations in $
     * @param nextIndexComposition the composition of the GMI index
     * @param externalPosition the external position the vaults are taking on in $
     * @param priceData token price data.
     * @param _hook hook
     */
    function openRebalancePeriod(
        uint256[2] memory nextVaultIndexAlloc,
        uint256[2] memory nextIndexComposition,
        int256 externalPosition,
        SetPricesParams memory priceData,
        bytes memory _hook
    ) external onlyRole(KEEPER_ROLE) setOraclePricing(priceData) {
        // before rebalance hook
        _executeHook(HookType.OPEN_REBALANCE_HOOK, _hook);
        VaultState storage vaultState = _getVaultState();
        if (vaultState.rebalanceOpen) revert RebalanceOpen();

        // check netting constraint
        checkNettingConstraint(
            Solarray.arraySum(nextVaultIndexAlloc), nextVaultIndexAlloc, nextIndexComposition, externalPosition
        );

        // pause vault deposits
        pauseDeposits();

        // set rebalance storage
        RebalanceState storage rebalanceState = _getRebalanceState();
        rebalanceState.indexAllocation = nextVaultIndexAlloc;
        rebalanceState.indexComposition = nextIndexComposition;
        rebalanceState.externalPosition = externalPosition;
        rebalanceState.epoch = vaultState.epoch;

        // cache the rebalance PPS
        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();
        for (uint256 i = 0; i < 2; i++) {
            vaultState.rebalancePPS[i] = getVaultPPS(assetVaults[i].vault, false, true);
        }
        vaultState.rebalanceOpen = true;

        Emitter(_getEmitter()).emitOpenRebalance(
            block.timestamp, nextVaultIndexAlloc, nextIndexComposition, externalPosition
        );
    }

    /**
     * @notice Closes a rebalance period and validates current state is valid.
     */
    function closeRebalancePeriod(SetPricesParams memory priceData, bytes memory _hook)
        external
        onlyRole(KEEPER_ROLE)
        setOraclePricing(priceData)
    {
        VaultState storage vaultState = _getVaultState();
        if (!vaultState.rebalanceOpen) revert RebalanceNotOpen();
        RebalanceState storage rebalanceState = _getRebalanceState();

        address aggregateVaultHelper = _getStorage().aggregateVaultHelper;
        bytes memory gmiValue = aggregateVaultHelper.delegateCall(
            abi.encodeCall(AggregateVaultHelper.getVaultsGmiValue, (vaultState.epoch, true))
        );
        uint256[2] memory vaultIndexAllocation = abi.decode(gmiValue, (uint256[2]));

        // check netting constraint
        checkNettingConstraint(
            Solarray.arraySum(vaultIndexAllocation),
            rebalanceState.indexAllocation,
            rebalanceState.indexComposition,
            rebalanceState.externalPosition
        );

        // calculate the new netted positions
        (int256[2][2] memory nettedMatrix,) = NettingMath.calculateNettedPositions(
            rebalanceState.externalPosition, rebalanceState.indexComposition, vaultIndexAllocation
        );

        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();

        // collect fees
        if (vaultState.epoch > 0) _collectVaultRebalanceFees(assetVaults);

        // reset epoch delta
        _resetEpochDeltas();

        vaultState.rebalanceOpen = false;
        vaultState.indexAllocation = rebalanceState.indexAllocation;

        // set netted positions
        _setPositions(nettedMatrix, rebalanceState.externalPosition);

        // finalise tvl checkpoint
        _setCheckpointTvls(assetVaults);

        // note set last to not trigger internal pnl
        vaultState.epoch += 1;
        vaultState.lastRebalanceTime = block.timestamp;

        // after rebalance hook
        _executeHook(HookType.CLOSE_REBALANCE_HOOK, _hook);

        // unpause vaults
        unpauseDeposits();

        Emitter(_getEmitter()).emitCloseRebalance(block.timestamp);
    }

    /**
     * @notice Checks if the netting constraint is satisfied for the given input values.
     * @dev Reverts if the netting constraint is not satisfied.
     * @param vaultCumulativeHoldings The total dollars deposited in backing.
     * @param indexComposition composition of the backing index.
     * @param vaultHoldings amount held by each vault.
     * @param externalPosition the external position to hedge.
     */
    function checkNettingConstraint(
        uint256 vaultCumulativeHoldings,
        uint256[2] memory vaultHoldings,
        uint256[2] memory indexComposition,
        int256 externalPosition
    ) internal view {
        if (_getStorage().shouldCheckNetting) {
            if (
                !NettingMath.isNetted(
                    vaultCumulativeHoldings, indexComposition, vaultHoldings, externalPosition, _getNettedThreshold()
                )
            ) {
                revert FailedNettingCheck();
            }
        }
    }

    // VIEWS
    // ------------------------------------------------------------------------------------------

    /**
     * @notice vault rebalance in progress
     */
    function rebalanceOpen() external view returns (bool) {
        return _getVaultState().rebalanceOpen;
    }

    /**
     * @notice preview a vault request
     * @param key The request key to query for
     * @return - The OCRequest corresponding to the key if set
     */
    function getRequest(uint256 key) external view returns (OCRequest memory) {
        return _getStorage().pendingRequests[key];
    }

    /**
     * @notice Gets the current asset vault price per share (PPS)
     * @param _assetVault The address of the asset vault whose PPS is being queried
     * @param useLlo should use the low latency oracle price
     * @return _tvl The current asset vault PPS
     */
    function getVaultPPS(address _assetVault, bool isDeposit, bool useLlo) public returns (uint256) {
        address aggregateVaultHelper = _getStorage().aggregateVaultHelper;
        bytes memory ret = aggregateVaultHelper.delegateCall(
            abi.encodeCall(AggregateVaultHelper.getVaultPPS, (_assetVault, isDeposit, useLlo))
        );
        return abi.decode(ret, (uint256));
    }

    /**
     * @notice Gets the current asset vault total value locked (TVL)
     * @param _assetVault The address of the asset vault whose TVL is being queried
     * @param useLlo should use the low latency oracle price
     * @return _tvl The current asset vault TVL
     */
    function getVaultTVL(address _assetVault, bool useLlo) public returns (uint256 _tvl) {
        address aggregateVaultHelper = _getStorage().aggregateVaultHelper;
        bytes memory ret =
            aggregateVaultHelper.delegateCall(abi.encodeCall(AggregateVaultHelper.getVaultTVL, (_assetVault, useLlo)));
        return abi.decode(ret, (uint256));
    }

    /**
     * @notice preview deposit fee
     * @param size The size of the deposit for which the fee is being calculated
     * @return totalDepositFee The calculated deposit fee
     */
    function previewDepositFee(address token, uint256 size, bool useLlo) external returns (uint256 totalDepositFee) {
        address feeHelper = _getFeeHelper();
        (bytes memory ret) = feeHelper.delegateCall(abi.encodeCall(IVaultFees.getDepositFee, (token, size, useLlo)));
        (totalDepositFee) = abi.decode(ret, (uint256));
    }

    /**
     * @notice preview withdrawal fee
     * @param token The address of the token for which the withdrawal fee is being calculated
     * @param size The size of the withdrawal for which the fee is being calculated
     * @return totalWithdrawalFee The calculated withdrawal fee
     */
    function previewWithdrawalFee(address token, uint256 size, bool useLlo)
        external
        returns (uint256 totalWithdrawalFee)
    {
        address feeHelper = _getFeeHelper();
        (bytes memory ret) = feeHelper.delegateCall(abi.encodeCall(IVaultFees.getWithdrawalFee, (token, size, useLlo)));
        uint256 baseFee;
        (totalWithdrawalFee, baseFee) = abi.decode(ret, (uint256, uint256));
        totalWithdrawalFee += baseFee;
    }

    /**
     * @notice Preview the asset vault cap
     * @param _asset The address of the asset whose vault cap is being queried
     * @return The current asset vault cap
     */
    function previewVaultCap(address _asset) external view returns (uint256) {
        uint256 vidx = _getTokenToAssetVaultIndex()[_asset];
        VaultState memory state = _getVaultState();
        return state.vaultCaps[vidx];
    }

    /**
     * @notice Preview the timelock address for an asset vault
     * @param _asset The address of the asset whose vault timelock is being queried
     * @return timelock address of the timelock contract
     */
    function getVaultTimelockAddress(address _asset) external view returns (address timelock) {
        AssetVaultStorage storage vaultStg = _getVaultFromAsset(_asset);
        return vaultStg.timelockYieldBoost;
    }

    /**
     * @dev reads storage slots in the contract returned as bytes32[] result
     */
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

    /**
     * @notice Update asset vault receipt contracts
     * @param assetVaults An array of new asset vault entries
     */
    function setAssetVaults(AssetVaultStorage[2] calldata assetVaults) external onlyConfigurator {
        AssetVaultStorage[2] storage vaults = _getAssetVaultEntries();
        mapping(address => uint256) storage tokenToAssetVaultIndex = _getTokenToAssetVaultIndex();
        mapping(address => uint256) storage vaultToAssetVaultIndex = _getVaultToAssetVaultIndex();

        for (uint256 i = 0; i < 2; i++) {
            vaults[i] = assetVaults[i];
            tokenToAssetVaultIndex[assetVaults[i].token] = i;
            vaultToAssetVaultIndex[assetVaults[i].vault] = i;
        }
    }

    // CONFIG
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Set the peripheral contract addresses
     * @param peripheral The enum value of the peripheral type
     * @param addr The address of the peripheral contract
     */
    function setPeripheral(Peripheral peripheral, address addr) external onlyConfigurator {
        AVStorage storage stg = _getStorage();
        if (peripheral == Peripheral.HookHandler) {
            stg.hookHandler = addr;
        } else if (peripheral == Peripheral.EventEmitter) {
            stg.emitter = addr;
        } else if (peripheral == Peripheral.OracleWrapper) {
            stg.oracleWrapper = addr;
        } else if (peripheral == Peripheral.GMI) {
            stg.gmi = payable(addr);
        } else if (peripheral == Peripheral.AggregateVaultHelper) {
            stg.aggregateVaultHelper = addr;
        } else if (peripheral == Peripheral.GmxV2Handler) {
            stg.gmxV2Handler = addr;
        } else if (peripheral == Peripheral.FeeHelper) {
            stg.feeHelper = addr;
        } else if (peripheral == Peripheral.RequestHandler) {
            stg.requestHandler = addr;
        } else if (peripheral == Peripheral.UniswapV3SwapManager) {
            stg.uniswapV3SwapManager = addr;
        } else {
            revert("AggregateVault: invalid peripheral");
        }
    }

    function setConfig(ConfigItem _item, bytes calldata _data) external onlyConfigurator {
        AVStorage storage stg = _getStorage();
        if (_item == ConfigItem.VaultFees) {
            (uint256 performanceFee, uint256 managementFee, uint256 withdrawalFee, uint256 depositFee) =
                abi.decode(_data, (uint256, uint256, uint256, uint256));
            _getStorage().vaultFees = VaultFees({
                performanceFee: performanceFee,
                managementFee: managementFee,
                withdrawalFee: withdrawalFee,
                depositFee: depositFee
            });
        } else if (_item == ConfigItem.ShouldCheckNetting) {
            bool val = abi.decode(_data, (bool));
            stg.shouldCheckNetting = val;
        } else if (_item == ConfigItem.ShouldUseGmxFee) {
            bool val = abi.decode(_data, (bool));
            stg.shouldUseGmxFee = val;
        } else if (_item == ConfigItem.L1BlockTolerance) {
            uint8 newBlockTolerance = abi.decode(_data, (uint8));
            _setL1BlockTolerance(newBlockTolerance);
        } else if (_item == ConfigItem.ExecutionGasAmounts) {
            (uint256 executionGasAmount, uint256 executionGasAmountCallback) = abi.decode(_data, (uint256, uint256));
            stg.executionGasAmount = executionGasAmount;
            stg.executionGasAmountCallback = executionGasAmountCallback;
        } else if (_item == ConfigItem.RebalanceKeeper) {
            address newKeeper = abi.decode(_data, (address));
            _setRebalanceKeeper(newKeeper);
        } else if (_item == ConfigItem.FeeRecipient) {
            (address recipient, address depositFeeEscrow, address withdrawalFeeEscrow) =
                abi.decode(_data, (address, address, address));
            VaultState storage state = _getVaultState();
            state.feeRecipient = recipient;
            state.depositFeeEscrow = depositFeeEscrow;
            state.withdrawalFeeEscrow = withdrawalFeeEscrow;
        } else if (_item == ConfigItem.VaultCaps) {
            (uint256[2] memory caps) = abi.decode(_data, (uint256[2]));
            VaultState storage state = _getVaultState();
            state.vaultCaps = caps;
        } else if (_item == ConfigItem.Thresholds) {
            (uint256 newNettedThreshold, uint256 zeroSumPnlThreshold, uint256 swapSlippage) =
                abi.decode(_data, (uint256, uint256, uint256));

            if (
                zeroSumPnlThreshold == 0 || zeroSumPnlThreshold >= 1e18 || newNettedThreshold == 0
                    || newNettedThreshold >= 10_000
            ) revert FailedConfigValidation();

            stg.zeroSumPnlThreshold = zeroSumPnlThreshold;
            stg.nettedThreshold = newNettedThreshold;
            stg.swapSlippage = swapSlippage;
        } else {
            revert AggregateVault__InvalidConfigItem();
        }
    }

    /**
     * @notice Add a new position manager to the list of position managers
     * @param _manager The address of the new position manager
     */
    function addPositionManager(IPositionManager _manager) external onlyConfigurator {
        IPositionManager[] storage positionManagers = _getPositionManagers();
        positionManagers.push(_manager);
    }

    // DELEGATE VIEWS
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Executes a delegate view to the specified target with the provided data and decodes the response as bytes.
     */
    function delegateview(address _target, bytes calldata _data) external returns (bool _success, bytes memory _ret) {
        (bool success, bytes memory ret) = address(this).call(abi.encodeCall(this.delegateviewRevert, (_target, _data)));
        if (success) revert DelegateViewRevert();
        (_success, _ret) = abi.decode(ret, (bool, bytes));
    }

    /**
     * @notice Executes a delegate call to the specified target with the provided data and reverts on error.
     */
    function delegateviewRevert(address _target, bytes memory _data) external {
        (bool success, bytes memory ret) = _target.delegatecall(_data);
        bytes memory encoded = abi.encode(success, ret);
        /// @solidity memory-safe-assembly
        assembly {
            revert(add(encoded, 0x20), mload(encoded))
        }
    }

    // INTERNAL
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Collects vault rebalance fees, mints timelock shares and distributes them.
     */
    function _collectVaultRebalanceFees(AssetVaultStorage[2] memory assetVaults) internal {
        uint256 performanceFeeInAsset;
        uint256 managementFeeInAsset;
        uint256 timelockYieldMintAmount;
        uint256 totalVaultFee;
        address feeHelper = _getFeeHelper();
        VaultState storage vaultState = _getVaultState();
        for (uint256 i = 0; i < 2; i++) {
            (bytes memory ret) = feeHelper.delegateCall(
                abi.encodeCall(IVaultFees.getVaultRebalanceFees, (assetVaults[i].token, vaultState.lastRebalanceTime))
            );
            (performanceFeeInAsset, managementFeeInAsset, timelockYieldMintAmount, totalVaultFee) =
                abi.decode(ret, (uint256, uint256, uint256, uint256));

            if (totalVaultFee > 0) {
                TransferUtils.transferAsset(assetVaults[i].token, vaultState.feeRecipient, totalVaultFee);
            }
            if (timelockYieldMintAmount > 0 && assetVaults[i].timelockYieldBoost != address(0)) {
                AssetVault(assetVaults[i].vault).mintTo(timelockYieldMintAmount, assetVaults[i].timelockYieldBoost);
            }

            Emitter(_getEmitter()).emitCollectVaultFees(
                totalVaultFee,
                performanceFeeInAsset,
                managementFeeInAsset,
                timelockYieldMintAmount,
                assetVaults[i].vault
            );
        }
    }

    /**
     * @notice Resets the epoch deposit/withdraw delta for all asset vaults.
     */
    function _resetEpochDeltas() internal {
        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();
        assetVaults[0].epochDelta = int256(0);
        assetVaults[1].epochDelta = int256(0);
    }

    /**
     * @notice Sets the checkpoint TVL for all asset vaults.
     */
    function _setCheckpointTvls(AssetVaultStorage[2] storage assetVaults) internal {
        assetVaults[0].lastCheckpointTvl = getVaultTVL(assetVaults[0].vault, true);
        assetVaults[1].lastCheckpointTvl = getVaultTVL(assetVaults[1].vault, true);
    }

    // UTILS
    // ------------------------------------------------------------------------------------------

    function depositEth() external payable onlyRole(KEEPER_ROLE) { }

    function withdrawEth(uint256 amount) external payable onlyRole(KEEPER_ROLE) {
        TransferUtils.transferNativeAsset(msg.sender, amount);
    }

    /**
     * @notice Pause deposits and withdrawals for the asset vaults
     */
    function pauseDeposits() public onlyRole(KEEPER_ROLE) {
        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();
        for (uint256 i = 0; i < 2; i++) {
            bool isPaused = IAssetVault(assetVaults[i].vault).depositPaused()
                || IAssetVault(assetVaults[i].vault).withdrawalPaused();
            if (isPaused) revert AggregateVault__AlreadyPaused();
            IAssetVault(assetVaults[i].vault).pauseDepositWithdraw();
        }
    }

    /**
     * @notice Unpause deposits and withdrawals for the asset vaults
     */
    function unpauseDeposits() public onlyRole(KEEPER_ROLE) {
        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();
        for (uint256 i = 0; i < 2; i++) {
            IAssetVault(assetVaults[i].vault).unpauseDepositWithdraw();
        }
    }

    /**
     * @notice Sets the oracle ricing
     */
    modifier setOraclePricing(SetPricesParams memory prices) {
        if (prices.realtimeFeedTokens.length != prices.realtimeFeedData.length) revert OraclePriceSizeInvalid();
        for (uint256 i = 0; i < prices.realtimeFeedTokens.length; i++) {
            OracleWrapper(payable(_getOracleWrapper())).setAndGetLloPrice(
                prices.realtimeFeedTokens[i], prices.realtimeFeedData[i]
            );
        }
        _;
    }

    /**
     * @notice Ensures the caller is an asset vault.
     */
    modifier onlyAssetVault() {
        if (!_isAssetVault()) revert NotAssetVault();
        _;
    }

    /**
     * @notice Ensures the caller is the RequestHandler or the AssetVault.
     */
    modifier onlyRequestHandlerOrAssetVault() {
        if (!(_isAssetVault() || AUTH.hasRole(REQUEST_HANDLER, msg.sender))) revert notRequestHandlerOrAssetVault();
        _;
    }

    /**
     * @notice check if the sender is an assetVault
     */
    function _isAssetVault() internal view returns (bool) {
        AssetVaultStorage[2] storage assetVaults = _getAssetVaultEntries();
        for (uint256 i = 0; i < 2; ++i) {
            if (msg.sender == assetVaults[i].vault) {
                return true;
            }
        }
        return false;
    }

    /**
     * @dev returns the gas requirement for call execution.
     */
    function _gasRequirement(bool _callback) internal view returns (uint256) {
        return _callback ? _getStorage().executionGasAmountCallback : _getStorage().executionGasAmount;
    }

    /// @dev To be implemented by inheriting contracts to restrict certain functions to a configurator role.
    function _onlyConfigurator() internal override onlyConfigurator { }

    /// @dev To be implemented by inheriting contracts to validate the caller's authorization for execute calls.
    function _validateExecuteCallAuth() internal override onlyRole(KEEPER_ROLE) { }

    /**
     * @notice Ensures the caller is permissioned to swap.
     */
    function _onlySwapIssuer() internal override onlyRole(SWAP_KEEPER) { }
}
