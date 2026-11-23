pragma solidity 0.8.17;

import { OracleWrapper } from "../peripheral/OracleWrapper.sol";
import { IGMIWithERC20 as GMI } from "../interfaces/IGMI.sol";
import { IGmxV2Handler, GmxV2HandlerStorage } from "../interfaces/IGmxV2Handler.sol";
import { AggregateVaultStorage, LibAggregateVaultStorage } from "../storage/AggregateVaultStorage.sol";
import { GmxStorage } from "./GmxStorage.sol";
import { Pricing } from "./Pricing.sol";
import { Delegatecall } from "./Delegatecall.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { ISwapManager } from "../interfaces/ISwapManager.sol";
import { PositionManagerRouter } from "../position-managers/PositionManagerRouter.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { UniswapV3SwapManager } from "../handlers/UniswapV3SwapManager.sol";
import { NettedPositionTracker } from "./NettedPositionTracker.sol";
import { SafeCast } from "./SafeCast.sol";
import { Emitter } from "../peripheral/Emitter.sol";
import { LibAggregateVaultUtils } from "./LibAggregateVaultUtils.sol";

using SafeCast for uint256;
using SafeCast for int256;

using SafeTransferLib for ERC20;

/// @title LibCycle
/// @author Umami Devs
/// @notice A library that contains cycle related logic for rebalancing the vault.
library LibCycle {
    /// @dev only one request can be sent for each LP
    error OnlyOneRequestPerAssetPerEpoch();
    /// @dev the request for the current epoch has already been fulfilled
    error RequestAlreadyFulfilled(bytes32);
    /// @dev Request has not been executed bu the GMX keeper
    error RequestNotExecuted();
    /// @dev Request did not succeed due to an error when fulfilling
    error RequestNotSucceded();

    bytes32 constant CYCLE_STORAGE_SLOT = keccak256("AggregateVaultHelper.cycleStorage");

    struct GMIMintRequest {
        bytes32[] depositKeys;
        uint256[] assetAmounts;
        uint256[] gmAmountsRequired;
        uint256[] gmAmountsMinted;
        address[] markets;
        address asset;
        uint256 targetGMIAmount;
        uint256 gmiMinted;
        bool fulfilled;
    }

    struct GMIBurnRequest {
        bytes32[] withdrawalKeys;
        uint256[] gmAmounts;
        address[] markets;
        address asset;
        uint256 gmiAmount;
        uint256[] shortTokenReceived;
        uint256[] longTokenReceived;
        bool fulfilled;
    }

    struct StorageCycle {
        mapping(bytes32 => GMIMintRequest) mintRequests;
        mapping(bytes32 => GMIBurnRequest) burnRequests;
    }

    function _getCycleStorage() internal pure returns (StorageCycle storage _storage) {
        bytes32 slot = CYCLE_STORAGE_SLOT;

        assembly {
            _storage.slot := slot
        }
    }

    /// @dev returns the burn request key for an asset and epoch to be used as reference
    function _getMintBurnRequestKey(address _asset, uint256 _epoch) internal pure returns (bytes32) {
        return keccak256(abi.encode(_asset, _epoch));
    }

    /// @dev sets a key in storage for a mint request to be used as reference when validating it
    function _setMintRequest(address _asset, uint256 _epoch, GMIMintRequest memory _mintRequest) internal {
        bytes32 key = _getMintBurnRequestKey(_asset, _epoch);
        if (_getCycleStorage().mintRequests[key].asset != address(0)) revert OnlyOneRequestPerAssetPerEpoch();
        _getCycleStorage().mintRequests[key] = _mintRequest;
        _emitter().emitMintRequest(_asset, _epoch, _mintRequest);
    }

    /// @dev sets a key in storage for a burn request to be used as reference when validating it
    function _setBurnRequest(address _asset, uint256 _epoch, GMIBurnRequest memory _burnRequest) internal {
        bytes32 key = _getMintBurnRequestKey(_asset, _epoch);
        if (_getCycleStorage().burnRequests[key].asset != address(0)) revert OnlyOneRequestPerAssetPerEpoch();
        _getCycleStorage().burnRequests[key] = _burnRequest;
        _emitter().emitBurnRequest(_asset, _epoch, _burnRequest);
    }

    /// @dev used to clear all requests for an epoch when resetting the storage via controller
    // function clearMintBurnRequestForEpoch(uint256 _epoch) external {
    //     bytes32 shortTokenKey = _getMintBurnRequestKey(_getShortToken(), _epoch);
    //     bytes32 longTokenKey = _getMintBurnRequestKey(_getLongToken(), _epoch);

    //     GMIMintRequest memory gmiMintRequest;
    //     GMIBurnRequest memory gmiBurnRequest;

    //     _getCycleStorage().mintRequests[shortTokenKey] = gmiMintRequest;
    //     _getCycleStorage().burnRequests[shortTokenKey] = gmiBurnRequest;

    //     _getCycleStorage().mintRequests[longTokenKey] = gmiMintRequest;
    //     _getCycleStorage().burnRequests[longTokenKey] = gmiBurnRequest;
    // }

    /**
     * @notice cycle settles internal PnL and can request a GM token rebalance in GMI
     * @param shouldRebalanceGmi if the GMI should be rebalanced this round
     * @return mintRequests any mint requests that were submitted this cycle
     * @return burnRequests any burn requests that were submitted this cycle
     */
    function cycle(bool shouldRebalanceGmi)
        external
        returns (GMIMintRequest[2] memory mintRequests, GMIBurnRequest[2] memory burnRequests)
    {
        // settle internal netted pnl only after first round
        AggregateVaultStorage.VaultState storage vaultState = LibAggregateVaultStorage.getVaultState();
        int256[2] memory prices = LibAggregateVaultUtils.getVaultTokenPrices(true);
        uint256 gmiPrice = Pricing.getIndexPps(_getOracleWrapper(), _gmi());
        if (vaultState.epoch > 0) {
            _settleInternalPnl(prices, gmiPrice);
        }
        // update next netting prices
        _updateNettingCheckpointPrice(prices, vaultState.epoch + 1);

        // rebalance glp
        return shouldRebalanceGmi ? rebalanceGmiFromRebalanceState(gmiPrice) : (mintRequests, burnRequests);
    }

    /**
     * @dev This contains logic for rebalancing the GMI held by the vaults and minting/burning the underlying of GMI
     * @param _gmiPrice current GMI price to rebalance from
     * @return _mintRequests any mint requests that were submitted
     * @return _burnRequests any burn requests that were submitted
     */
    function rebalanceGmiFromRebalanceState(uint256 _gmiPrice)
        internal
        returns (GMIMintRequest[2] memory _mintRequests, GMIBurnRequest[2] memory _burnRequests)
    {
        AggregateVaultStorage.RebalanceState storage rebalanceState = LibAggregateVaultStorage.getRebalanceState();
        uint256[2] memory targetUsd = rebalanceState.indexAllocation;
        uint256[2] memory targetShares = [targetUsd[0] * 1e18 / _gmiPrice, targetUsd[1] * 1e18 / _gmiPrice];
        uint256[2] memory currentShares = LibAggregateVaultUtils.getVaultsGmi(0, true);
        _emitter().emitRebalanceGmiFromState(targetUsd, targetShares, currentShares);
        return rebalanceGmi(currentShares, targetShares, _gmiPrice);
    }

    /**
     * @notice rebalances the GMI using USD as a numeraire
     * @param _gmiPrice current GMI price to rebalance from
     * @return _mintRequests any mint requests that were submitted
     * @return _burnRequests any burn requests that were submitted
     */
    function rebalanceGmiUsd(uint256[2] memory _current, uint256[2] memory _target, uint256 _gmiPrice)
        internal
        returns (GMIMintRequest[2] memory _mintRequests, GMIBurnRequest[2] memory _burnRequests)
    {
        uint256[2] memory targetShares = [_target[0] * 1e18 / _gmiPrice, _target[1] * 1e18 / _gmiPrice];
        uint256[2] memory currentShares = [_current[0] * 1e18 / _gmiPrice, _current[1] * 1e18 / _gmiPrice];
        return rebalanceGmi(currentShares, targetShares, _gmiPrice);
    }

    /**
     * @dev This contains logic for rebalancing the GMI held by the vaults and minting/burning the underlying of GMI
     * @param _current current GMI in USD held by vaults
     * @param _target target GMI in USD held by vaults
     * @param _gmiPrice current GMI price to rebalance from
     * @return _mintRequests any mint requests that were submitted
     * @return _burnRequests any burn requests that were submitted
     */
    function rebalanceGmi(uint256[2] memory _current, uint256[2] memory _target, uint256 _gmiPrice)
        internal
        returns (GMIMintRequest[2] memory _mintRequests, GMIBurnRequest[2] memory _burnRequests)
    {
        bool isShortTokenBurn = _target[0] < _current[0];
        bool isLongTokenBurn = _target[1] < _current[1];
        bool isOppositeDirection = isShortTokenBurn != isLongTokenBurn;

        // internally swap gmi for native asset for internally
        // settlable swap amount of gmi tokens
        if (isOppositeDirection) {
            uint256 deltaShortToken = isShortTokenBurn ? _current[0] - _target[0] : _target[0] - _current[0];
            uint256 deltaLongToken = isLongTokenBurn ? _current[1] - _target[1] : _target[1] - _current[1];
            // min of the two
            uint256 internalNet = deltaShortToken > deltaLongToken ? deltaLongToken : deltaShortToken;
            uint256 internalNetUsd = internalNet * _gmiPrice / 1e18;
            int256[2] memory prices = LibAggregateVaultUtils.getVaultTokenPrices(true);

            // swap vault assets for internal net
            if (isShortTokenBurn) {
                uint256 longTokenDecimals = _getStorage().vaults[1].decimals;
                uint256 longTokenAmount = (internalNetUsd * (10 ** longTokenDecimals)) / uint256(prices[1]);
                _swap(true, longTokenAmount);
            } else {
                uint256 shortTokenDecimals = _getStorage().vaults[0].decimals;
                uint256 shortTokenAmount = (internalNetUsd * (10 ** shortTokenDecimals)) / uint256(prices[0]);
                _swap(false, shortTokenAmount);
            }

            uint256 totalGmi = _gmi().balanceOf(address(this));

            // act as if internal netted was the current state
            if (isShortTokenBurn) {
                _current[0] = _current[0] - internalNet;
                _commitGmiDeltaProportions(0, -int256(internalNet), totalGmi);
                totalGmi = totalGmi - internalNet;

                _current[1] = _current[1] + internalNet;
                _commitGmiDeltaProportions(1, int256(internalNet), totalGmi);
            } else {
                _current[0] = _current[0] + internalNet;
                _commitGmiDeltaProportions(0, int256(internalNet), totalGmi);
                totalGmi = totalGmi + internalNet;

                _current[1] = _current[1] - internalNet;
                _commitGmiDeltaProportions(1, -int256(internalNet), totalGmi);
            }
        }

        // PERF: refactor to aggregate the mint/burn requests for both vaults to reduce
        // execution fees
        for (uint256 i = 0; i < 2; i++) {
            AggregateVaultStorage.AssetVaultStorage storage assetVault = _getStorage().vaults[i];
            address asset = assetVault.token;

            if (_target[i] > _current[i]) {
                _mintRequests[i] = _increaseGMI(asset, _target[i] - _current[i]);
            }
            // covers the do nothing on delta 0 case
            else if (_target[i] < _current[i]) {
                uint256 gmiDelta = _current[i] - _target[i];
                _burnRequests[i] = _decreaseGMI(asset, gmiDelta);
                // need to commit here because burning gmi is atomic, while minting is not
                // minting is committed in fulfilMint
                GMI gmi = GMI(_getStorage().gmi);
                uint256 prevTotal = gmi.balanceOf(address(this)) + gmiDelta;
                _commitGmiDeltaProportions(i, -int256(gmiDelta), prevTotal);
            }
        }
    }

    /**
     * @notice request an increase in GM tokens held using a quote from GMI
     * @param _asset the underlying of the vault to use for minting
     * @param _delta the delta of GMI
     * @return _mintRequest the returned GMI mint request
     */
    function _increaseGMI(address _asset, uint256 _delta) internal returns (GMIMintRequest memory _mintRequest) {
        GMI gmi = GMI(_getStorage().gmi);
        address oracle = _getStorage().oracleWrapper;
        GmxStorage.MarketPrices[] memory marketPrices = Pricing.getMarketPrices(oracle, gmi, true);
        uint256[] memory gmSharesRequired = gmi.previewMint(_delta, _asset, marketPrices);

        address[] memory markets = gmi.indexAssets();
        bytes32[] memory depositKeys = new bytes32[](markets.length);
        uint256[] memory assetAmounts = new uint256[](markets.length);
        uint256 epoch = LibAggregateVaultStorage.getVaultState().epoch;
        for (uint256 i = 0; i < markets.length; i++) {
            if (gmSharesRequired[i] > 0) {
                uint256 assetAmountRequired = _previewGmMint(markets[i], gmSharesRequired[i], _asset);
                if (assetAmountRequired == 0) {
                    gmSharesRequired[i] = 0;
                    continue;
                }
                assetAmounts[i] = assetAmountRequired;
                depositKeys[i] = _mintGmWithAsset(markets[i], _asset, assetAmountRequired);
            }
        }
        _mintRequest = GMIMintRequest({
            depositKeys: depositKeys,
            assetAmounts: assetAmounts,
            gmAmountsRequired: gmSharesRequired,
            gmAmountsMinted: new uint256[](markets.length),
            markets: markets,
            asset: _asset,
            targetGMIAmount: _delta,
            fulfilled: false,
            gmiMinted: 0
        });
        _setMintRequest(_asset, epoch, _mintRequest);
    }

    /**
     * @notice request an decrease in GM tokens held using a quote from GMI
     * @param _asset the underlying of the vault to use for burning
     * @param _delta the delta of GMI
     * @return _burnRequest the returned GMI burn request
     */
    function _decreaseGMI(address _asset, uint256 _delta) internal returns (GMIBurnRequest memory _burnRequest) {
        GMI gmi = GMI(_getStorage().gmi);
        address oracle = _getStorage().oracleWrapper;
        GmxStorage.MarketPrices[] memory marketPrices = Pricing.getMarketPrices(oracle, gmi, true);
        uint256[] memory gmSharesReceived = gmi.redeem(_delta, address(this), address(this), marketPrices);
        address[] memory markets = gmi.indexAssets();
        bytes32[] memory withdrawalKeys = new bytes32[](markets.length);
        for (uint256 i = 0; i < markets.length; i++) {
            if (gmSharesReceived[i] > 0) {
                withdrawalKeys[i] = _burnGMForAsset(markets[i], gmSharesReceived[i]);
            }
        }
        uint256 epoch = LibAggregateVaultStorage.getVaultState().epoch;
        uint256 indexSize = _gmi().indexAssetsLength();
        _burnRequest = GMIBurnRequest({
            withdrawalKeys: withdrawalKeys,
            gmAmounts: gmSharesReceived,
            asset: _asset,
            markets: markets,
            gmiAmount: _delta,
            shortTokenReceived: new uint256[](indexSize),
            longTokenReceived: new uint256[](indexSize),
            fulfilled: false
        });
        _setBurnRequest(_asset, epoch, _burnRequest);
    }

    /// @dev requests a burn GM
    function _burnGMForAsset(address _market, uint256 _amt) internal returns (bytes32 _withdrawKey) {
        bytes memory cd = abi.encodeCall(IGmxV2Handler.burnGmTokens, (_market, _amt, address(this)));
        bytes memory ret = Delegatecall.delegateCall(address(_gmxV2Handler()), cd);
        _withdrawKey = abi.decode(ret, (bytes32));
    }

    /// @dev requests a mint GM
    function _mintGmWithAsset(address _market, address _asset, uint256 _amt) internal returns (bytes32 _depositKey) {
        (uint256 amountLongToken, uint256 amountShortToken) =
            _asset == _getLongToken() ? (_amt, uint256(0)) : (uint256(0), _amt);
        bytes memory cd =
            abi.encodeCall(IGmxV2Handler.mintGmTokens, (_market, amountLongToken, amountShortToken, address(this)));
        bytes memory ret = Delegatecall.delegateCall(address(_gmxV2Handler()), cd);
        _depositKey = abi.decode(ret, (bytes32));
    }

    /// @dev previews a mint GM
    function _previewGmMint(address _gm, uint256 _gmAmount, address _asset) internal returns (uint256 _assetAmount) {
        address oracle = _getStorage().oracleWrapper;
        uint256 gmPrice = _gmTokenPrice(oracle, _gm, true); // 30 decimals
        uint256 tokenPrice = Pricing.getTokenPrice(oracle, _asset, true); // 1 wei token's price, oneToken's price is 30 decimals
        _assetAmount = (_gmAmount * gmPrice / 1e18) / tokenPrice;
    }

    /// @dev get the token price of a GM token, has a flag whether to use the LLO or onchain price
    function _gmTokenPrice(address _oracleWrapper, address _gm, bool _withLlo) internal returns (uint256) {
        GmxStorage.MarketPrices memory marketPrice = Pricing.getMarketPrice(_oracleWrapper, _gm, _withLlo);
        IGmxV2Handler gmxV2Handler = _gmxV2Handler();
        bytes memory gmMidPriceCalldata = abi.encodeCall(IGmxV2Handler.getGmMidPrice, (_gm, marketPrice));
        bytes memory ret = Delegatecall.delegateCall(address(gmxV2Handler), gmMidPriceCalldata);
        return abi.decode(ret, (uint256));
    }

    /// @dev gets the gmxV2Handler from storage
    function _gmxV2Handler() internal view returns (IGmxV2Handler) {
        return IGmxV2Handler(_getStorage().gmxV2Handler);
    }

    /**
     * @notice Called after all requests have been executed by the GMX keeper. This mints GMI if requred and
     * clears the pending requests from storage as fulfilled
     */
    function fulfilRequests() external {
        uint256 epoch = LibAggregateVaultStorage.getVaultState().epoch;
        address[2] memory assets = [_getStorage().vaults[0].token, _getStorage().vaults[1].token];
        int256[2] memory aggregateFees;
        for (uint256 i = 0; i < assets.length; i++) {
            // NOTE: only 1 GMI mint/burn request per asset per epoch
            bytes32 mintBurnKey = _getMintBurnRequestKey(assets[i], epoch);
            GMIMintRequest memory mintRequest = _getCycleStorage().mintRequests[mintBurnKey];
            if (mintRequest.asset != address(0)) {
                int256[2] memory mintFees = _fulfilMintRequest(mintBurnKey, mintRequest);
                aggregateFees[0] += mintFees[0];
                aggregateFees[1] += mintFees[1];
            }
            GMIBurnRequest memory burnRequest = _getCycleStorage().burnRequests[mintBurnKey];
            if (burnRequest.asset != address(0)) {
                int256[2] memory burnFees = _fulfilBurnRequest(mintBurnKey, burnRequest);
                aggregateFees[0] += burnFees[0];
                aggregateFees[1] += burnFees[1];
            }
        }
        uint256[2] memory toPull =
            [aggregateFees[0] > 0 ? uint256(aggregateFees[0]) : 0, aggregateFees[1] > 0 ? uint256(aggregateFees[1]) : 0];
        LibAggregateVaultUtils.pullFeeAmountsFromEscrow(toPull);
    }

    /**
     * @notice fulfils a mint request, will mint GMI with the tokens recieved
     * @param _key the key of the request
     * @param _mintRequest the mint request in storage
     */
    function _fulfilMintRequest(bytes32 _key, GMIMintRequest memory _mintRequest)
        internal
        returns (int256[2] memory feeAmounts)
    {
        if (_mintRequest.fulfilled) revert RequestAlreadyFulfilled(_key);
        bool isShortToken = _mintRequest.asset == _getShortToken();

        GMI gmi = GMI(_getStorage().gmi);
        uint256 indexSize = gmi.indexAssetsLength();
        uint256[] memory gmReceived = new uint256[](indexSize);
        for (uint256 i = 0; i < indexSize; i++) {
            if (_mintRequest.gmAmountsRequired[i] > 0 && _mintRequest.assetAmounts[i] > 0) {
                GmxV2HandlerStorage.DepositRequestDetails memory depositRequestDetails =
                    _getDepositRequestDetails(_mintRequest.depositKeys[i]);
                if (!depositRequestDetails.executed) revert RequestNotExecuted();
                if (!depositRequestDetails.success) revert RequestNotSucceded();
                gmReceived[i] = depositRequestDetails.amountMinted;
                feeAmounts[isShortToken ? 0 : 1] += depositRequestDetails.feesPaid
                    / (
                        isShortToken
                            ? int256(depositRequestDetails.shortTokenPrice)
                            : int256(depositRequestDetails.longTokenPrice)
                    );
                ERC20(_mintRequest.markets[i]).safeApprove(address(gmi), gmReceived[i]);
            }
        }

        GmxStorage.MarketPrices[] memory marketPrices = Pricing.getMarketPrices(_getStorage().oracleWrapper, gmi, true);
        uint256 gmiMinted = gmi.deposit(gmReceived, marketPrices, address(this));
        uint256 prevTotal = gmi.balanceOf(address(this)) - gmiMinted;
        uint256 vaultIdx = LibAggregateVaultStorage.getTokenToAssetVaultIndex()[_mintRequest.asset];
        _commitGmiDeltaProportions(vaultIdx, int256(gmiMinted), prevTotal);

        GMIMintRequest storage s_mintRequest = _getCycleStorage().mintRequests[_key];
        s_mintRequest.gmiMinted = gmiMinted;
        s_mintRequest.fulfilled = true;
        s_mintRequest.gmAmountsMinted = gmReceived;

        _emitter().emitFulfilGmiMintRequest(
            s_mintRequest.targetGMIAmount, gmiMinted, s_mintRequest.gmAmountsRequired, gmReceived
        );
    }

    /**
     * @notice fulfils a burn request, will swap the opposite token to vault token since gmx
     * returns some of both underlying tokens of the market when burning
     * @param _key the key of the request
     * @param _burnRequest the burn request in storage
     */
    function _fulfilBurnRequest(bytes32 _key, GMIBurnRequest memory _burnRequest)
        internal
        returns (int256[2] memory feeAmounts)
    {
        if (_burnRequest.fulfilled) revert RequestAlreadyFulfilled(_key);
        bool isShortToken = _burnRequest.asset == _getShortToken();

        uint256 indexSize = _gmi().indexAssetsLength();
        uint256[] memory shortTokenReceived = new uint256[](indexSize);
        uint256[] memory longTokenReceived = new uint256[](indexSize);
        uint256 amountOutTotal;
        for (uint256 i = 0; i < indexSize; i++) {
            if (_burnRequest.gmAmounts[i] > 0) {
                GmxV2HandlerStorage.WithdrawRequestDetails memory withdrawRequestDetails =
                    _getWithdrawalRequestDetails(_burnRequest.withdrawalKeys[i]);
                if (!withdrawRequestDetails.executed) revert RequestNotExecuted();
                if (!withdrawRequestDetails.success) revert RequestNotSucceded();

                shortTokenReceived[i] = withdrawRequestDetails.shortTokenAmountReceived;
                longTokenReceived[i] = withdrawRequestDetails.longTokenAmountReceived;

                // swap non-native token for native token
                if (isShortToken) {
                    amountOutTotal = _swap(true, longTokenReceived[i]) + shortTokenReceived[i];
                } else {
                    amountOutTotal = _swap(false, shortTokenReceived[i]) + longTokenReceived[i];
                }
                feeAmounts[isShortToken ? 0 : 1] += (withdrawRequestDetails.feesPaid)
                    / (
                        isShortToken
                            ? int256(withdrawRequestDetails.shortTokenPrice)
                            : int256(withdrawRequestDetails.longTokenPrice)
                    );
            }
        }

        GMIBurnRequest storage s_burnRequest = _getCycleStorage().burnRequests[_key];
        s_burnRequest.shortTokenReceived = shortTokenReceived;
        s_burnRequest.longTokenReceived = longTokenReceived;
        s_burnRequest.fulfilled = true;

        _emitter().emitFulfilGmiBurnRequest(s_burnRequest.gmiAmount, shortTokenReceived, longTokenReceived);
    }

    /// @dev gets the details of a request in storage
    function _getDepositRequestDetails(bytes32 _key)
        internal
        returns (GmxV2HandlerStorage.DepositRequestDetails memory)
    {
        address handler = address(_getStorage().gmxV2Handler);
        bytes memory cd = abi.encodeCall(IGmxV2Handler.getDepositRequestDetails, (_key));
        bytes memory ret = Delegatecall.delegateCall(handler, cd);
        return abi.decode(ret, (GmxV2HandlerStorage.DepositRequestDetails));
    }

    /// @dev gets the details of a request in storage
    function _getWithdrawalRequestDetails(bytes32 _key)
        internal
        returns (GmxV2HandlerStorage.WithdrawRequestDetails memory)
    {
        address handler = address(_getStorage().gmxV2Handler);
        bytes memory cd = abi.encodeCall(IGmxV2Handler.getWithdrawRequestDetails, (_key));
        bytes memory ret = Delegatecall.delegateCall(handler, cd);
        return abi.decode(ret, (GmxV2HandlerStorage.WithdrawRequestDetails));
    }

    /// @dev executes a swap using the uniswap manager in storage
    function _swap(bool _longTokenForShortToken, uint256 _amount) internal returns (uint256 _amountOut) {
        address longToken = _getLongToken();
        address shortToken = _getShortToken();
        (address tokenIn, address tokenOut) =
            _longTokenForShortToken ? (longToken, shortToken) : (shortToken, longToken);
        OracleWrapper ow = OracleWrapper(payable(_getOracleWrapper()));
        uint256 longTokenPrice = ow.getChainlinkPrice(longToken);
        uint256 shortTokenPrice = ow.getChainlinkPrice(shortToken);
        uint256 minOut = _longTokenForShortToken
            ? _amount * longTokenPrice / shortTokenPrice
            : _amount * shortTokenPrice / longTokenPrice;
        _amountOut = PositionManagerRouter(payable(address(this))).executeSwap(
            ISwapManager(_getStorage().uniswapV3SwapManager),
            tokenIn,
            tokenOut,
            _amount,
            minOut * (1e18 - _getStorage().swapSlippage) / 1e18,
            hex""
        );
    }

    /// @dev commits the changes in GMI held to storage
    function _commitGmiDeltaProportions(uint256 _vaultIdx, int256 _amt, uint256 _prevTotal) internal {
        uint256[2] memory currentAttribution = _getStorage().vaultGmiAttribution;
        uint256 totalAttribution = currentAttribution[0] + currentAttribution[1];
        uint256[2] memory currentProportions;
        if (totalAttribution == 0) {
            currentProportions = [uint256(0), uint256(0)];
        } else {
            currentProportions =
                [currentAttribution[0] * 1e18 / totalAttribution, currentAttribution[1] * 1e18 / totalAttribution];
        }
        uint256[2] memory prevAmounts =
            [_prevTotal * currentProportions[0] / 1e18, _prevTotal * currentProportions[1] / 1e18];

        if (_amt > 0) {
            prevAmounts[_vaultIdx] += uint256(_amt);
            uint256 newTotal = _prevTotal + uint256(_amt);
            currentProportions[0] = prevAmounts[0] * 1e18 / newTotal;
            currentProportions[1] = prevAmounts[1] * 1e18 / newTotal;
        } else {
            prevAmounts[_vaultIdx] -= uint256(-_amt);
            uint256 newTotal = _prevTotal - uint256(-_amt);
            currentProportions[0] = prevAmounts[0] * 1e18 / newTotal;
            currentProportions[1] = prevAmounts[1] * 1e18 / newTotal;
        }
        _getStorage().vaultGmiAttribution = currentProportions;
    }

    function _getStorage() internal pure returns (AggregateVaultStorage.AVStorage storage _storage) {
        _storage = LibAggregateVaultStorage.getStorage();
    }

    function _getOracleWrapper() internal view returns (address _oracleWrapper) {
        _oracleWrapper = _getStorage().oracleWrapper;
    }

    function _gmi() internal view returns (GMI gmIndex) {
        gmIndex = GMI(_getStorage().gmi);
    }

    function _emitter() internal view returns (Emitter emitter) {
        emitter = Emitter(_getStorage().emitter);
    }

    /**
     * @notice Settles the internal PnL for the given asset prices and GMI price
     * @param currentAssetPrices An array of the current asset prices
     * @param gmiPrice The current GMI price
     */
    function _settleInternalPnl(int256[2] memory currentAssetPrices, uint256 gmiPrice) internal {
        uint256[2] memory settledVaultIndexAmount;
        int256[2] memory nettedPnl;
        int256[2] memory indexPnl;
        int256[2] memory percentPriceChange;
        // get the previous allocated glp amount
        uint256[2] memory vaultsGmi = LibAggregateVaultUtils.getVaultsGmi(0, true);
        AggregateVaultStorage.AVStorage storage avs = _getStorage();
        (settledVaultIndexAmount, nettedPnl, indexPnl, percentPriceChange) = NettedPositionTracker
            .settleNettingPositionPnl(
            avs.nettedPositions,
            currentAssetPrices,
            _getNettedPrices(LibAggregateVaultStorage.getVaultState().epoch),
            vaultsGmi,
            gmiPrice,
            avs.zeroSumPnlThreshold
        );
        // while this is set here to gmi amount, the read and usage is always x / total
        // as proportions, its because the GMI amount in storage and real amounts
        // are not going to match because of mint/burn slippage differences, etc.
        avs.vaultGmiAttribution = settledVaultIndexAmount;
        Emitter(avs.emitter).emitSettleNettedPositionPnl(
            vaultsGmi, settledVaultIndexAmount, indexPnl, nettedPnl, percentPriceChange
        );
    }

    function _getNettedPrices(uint256 _epoch) internal view returns (int256[2] memory _nettedPrices) {
        _nettedPrices = _getStorage().lastNettedPrices[_epoch];
    }

    /// @dev updates the checkpoint prices in storage for calculating the next internal positions
    function _updateNettingCheckpointPrice(int256[2] memory _prices, uint256 epochId) internal {
        int256[2] memory prices = _getStorage().lastNettedPrices[epochId];
        require(prices[0] == 0, "AggregateVault: lastNettedPrices already inited for given epoch");
        AggregateVaultStorage.AVStorage storage avs = _getStorage();
        avs.lastNettedPrices[epochId] = _prices;
        Emitter(avs.emitter).emitUpdateNettingCheckpointPrice(_getStorage().lastNettedPrices[epochId - 1], _prices);
    }

    /// @dev assumes index 1 is always long token vault
    function _getLongToken() internal view returns (address _longToken) {
        _longToken = _getStorage().vaults[1].token;
    }

    /// @dev assumes index 0 is always short token vault
    function _getShortToken() internal view returns (address _shortToken) {
        _shortToken = _getStorage().vaults[0].token;
    }
}
