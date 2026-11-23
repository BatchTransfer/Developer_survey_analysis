// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { Auth, GlobalACL, SWAP_KEEPER, KEEPER_ROLE } from "../Auth.sol";
import { LibCycle } from "../libraries/LibCycle.sol";
import { AggregateVaultStorage } from "../storage/AggregateVaultStorage.sol";

/// @title Emitter
/// @author Umami Devs
/// @notice Emitter handles events from the vaults for easy indexing
contract Emitter is GlobalACL {
    event CollectVaultFees(
        uint256 totalVaultFee,
        uint256 performanceFeeInAsset,
        uint256 managementFeeInAsset,
        uint256 timelockYieldMintAmount,
        address indexed assetVault
    );

    event RebalanceGmiFromState(uint256[2] targetUsd, uint256[2] targetShares, uint256[2] currentShares);

    event MintRequest(address asset, uint256 epoch, LibCycle.GMIMintRequest _mintRequest);

    event BurnRequest(address asset, uint256 epoch, LibCycle.GMIBurnRequest _mintRequest);

    event FulfilGmiMintRequest(
        uint256 targetGMIAmount, uint256 gmiMinted, uint256[] gmAmountsRequired, uint256[] gmAmountsMinted
    );

    event FulfilGmiBurnRequest(uint256 gmiAmount, uint256[] shortTokenReceived, uint256[] longTokenReceived);

    event OpenRebalance(uint256 timestamp, uint256[2] nextVaultIndexAlloc, uint256[2] nextIndexComp, int256 position);

    event CloseRebalance(uint256 timestamp);

    event DepositRequest(uint256 indexed key, address indexed account, address indexed vault);

    event WithdrawalRequest(uint256 indexed key, address indexed account, address indexed vault);

    event RequestExecuted(uint256 indexed key, address indexed account, address indexed vault, address callback);

    event ExecutionError(uint256 indexed key, address account, address vault, bool isDeposit, bytes error);

    event CallbackExecutionError(uint256 indexed key, bytes error);

    event CallbackExecutionSuccess(uint256 indexed key, AggregateVaultStorage.OCRequest request);

    event UpdateNettingCheckpointPrice(int256[2] oldPrices, int256[2] newPrices);

    event SettleNettedPositionPnl(
        uint256[2] previousGlpAmount,
        uint256[2] settledGlpAmount,
        int256[2] glpPnl,
        int256[2] dollarPnl,
        int256[2] percentPriceChange
    );

    event SetCallback(bool status);

    constructor(Auth auth) GlobalACL(auth) { }

    function emitCollectVaultFees(
        uint256 totalVaultFee,
        uint256 performanceFeeInAsset,
        uint256 managementFeeInAsset,
        uint256 timelockYieldMintAmount,
        address assetVault
    ) external onlyAggregateVault {
        emit CollectVaultFees(
            totalVaultFee, performanceFeeInAsset, managementFeeInAsset, timelockYieldMintAmount, assetVault
        );
    }

    function emitOpenRebalance(
        uint256 timestamp,
        uint256[2] memory nextVaultIndexAlloc,
        uint256[2] memory nextIndexComp,
        int256 position
    ) external onlyAggregateVault {
        emit OpenRebalance(timestamp, nextVaultIndexAlloc, nextIndexComp, position);
    }

    function emitCloseRebalance(uint256 timestamp) external onlyAggregateVault {
        emit CloseRebalance(timestamp);
    }

    function emitDepositRequest(uint256 key, address account, address vault) external onlyAggregateVault {
        emit DepositRequest(key, account, vault);
    }

    function emitWithdrawalRequest(uint256 key, address account, address vault) external onlyAggregateVault {
        emit WithdrawalRequest(key, account, vault);
    }

    function emitRequestExecuted(uint256 key, address account, address vault, address callback)
        external
        onlyRequestHandler
    {
        emit RequestExecuted(key, account, vault, callback);
    }

    function emitExecutionError(uint256 key, address account, address vault, bool isDeposit, bytes memory err)
        external
        onlyRequestHandler
    {
        emit ExecutionError(key, account, vault, isDeposit, err);
    }

    function emitSetCallbackEnabled(bool status) external onlyRequestHandler {
        emit SetCallback(status);
    }

    function emitRequestCallbackError(uint256 key, bytes memory err) external onlyRequestHandler {
        emit CallbackExecutionError(key, err);
    }

    function emitRequestCallbackSuccess(uint256 key, AggregateVaultStorage.OCRequest memory request)
        external
        onlyRequestHandler
    {
        emit CallbackExecutionSuccess(key, request);
    }

    function emitSettleNettedPositionPnl(
        uint256[2] memory previousIndexAmount,
        uint256[2] memory settledIndexAmount,
        int256[2] memory indexPnl,
        int256[2] memory dollarPnl,
        int256[2] memory percentPriceChange
    ) external onlyAggregateVault {
        emit SettleNettedPositionPnl(previousIndexAmount, settledIndexAmount, indexPnl, dollarPnl, percentPriceChange);
    }

    function emitRebalanceGmiFromState(
        uint256[2] memory targetUsd,
        uint256[2] memory targetShares,
        uint256[2] memory currentShares
    ) external onlyAggregateVault {
        emit RebalanceGmiFromState(targetUsd, targetShares, currentShares);
    }

    function emitMintRequest(address _asset, uint256 _epoch, LibCycle.GMIMintRequest memory _mintRequest)
        external
        onlyAggregateVault
    {
        emit MintRequest(_asset, _epoch, _mintRequest);
    }

    function emitBurnRequest(address _asset, uint256 _epoch, LibCycle.GMIBurnRequest memory _burnRequest)
        external
        onlyAggregateVault
    {
        emit BurnRequest(_asset, _epoch, _burnRequest);
    }

    function emitFulfilGmiMintRequest(
        uint256 targetGMIAmount,
        uint256 gmiMinted,
        uint256[] memory gmAmountsRequired,
        uint256[] memory gmAmountsMinted
    ) external onlyAggregateVault {
        emit FulfilGmiMintRequest(targetGMIAmount, gmiMinted, gmAmountsRequired, gmAmountsMinted);
    }

    function emitFulfilGmiBurnRequest(
        uint256 gmiAmount,
        uint256[] memory shortTokenReceived,
        uint256[] memory longTokenReceived
    ) external onlyAggregateVault {
        emit FulfilGmiBurnRequest(gmiAmount, shortTokenReceived, longTokenReceived);
    }

    function emitUpdateNettingCheckpointPrice(int256[2] memory oldPrices, int256[2] memory newPrices)
        external
        onlyAggregateVault
    {
        emit UpdateNettingCheckpointPrice(oldPrices, newPrices);
    }
}
