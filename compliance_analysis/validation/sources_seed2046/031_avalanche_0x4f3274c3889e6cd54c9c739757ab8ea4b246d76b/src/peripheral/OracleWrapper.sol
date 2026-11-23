// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { GlobalACL, Auth, REQUEST_HANDLER, AGGREGATE_VAULT_ROLE, KEEPER_ROLE } from "../Auth.sol";
import { IAggregatorV3Interface } from "../interfaces/IAggregatorV3Interface.sol";
import { IVerifierProxy, IFeeManager } from "../interfaces/IVerifierProxy.sol";
import { IArbSys } from "../interfaces/IArbSys.sol";
import { ARBSYS, TOKEN_USDC_NATIVE, TOKEN_WETH } from "../constants.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ISupraSValueFeed } from "../interfaces/ISupraSValueFeed.sol";
import { StorageViewer } from "./StorageViewer.sol";

using SafeTransferLib for ERC20;

library LLOReportDecoder {
    struct SignedReportData {
        bytes32[3] context;
        bytes blob;
        bytes32[] rawRs;
        bytes32[] rawSs;
        bytes32 rawVs;
    }

    struct ReportData {
        bytes32 feedId;
        uint32 validFromTimestamp;
        uint32 observationsTimestamp;
        uint192 nativeFee;
        uint192 linkFee;
        uint32 expiresAt;
        int192 benchmarkPrice;
    }

    function decodeSignedReport(bytes memory _signedReportData)
        internal
        pure
        returns (SignedReportData memory _reportData)
    {
        (_reportData.context, _reportData.blob, _reportData.rawRs, _reportData.rawSs, _reportData.rawVs) =
            abi.decode(_signedReportData, (bytes32[3], bytes, bytes32[], bytes32[], bytes32));
    }

    function decodeReportBlob(bytes memory _reportBlob) internal pure returns (ReportData memory _reportData) {
        (
            _reportData.feedId,
            _reportData.validFromTimestamp,
            _reportData.observationsTimestamp,
            _reportData.nativeFee,
            _reportData.linkFee,
            _reportData.expiresAt,
            _reportData.benchmarkPrice
        ) = abi.decode(_reportBlob, (bytes32, uint32, uint32, uint192, uint192, uint32, int192));
    }
}

/// @title OracleWrapper
/// @author Umami Devs
/// @notice Contains core oracle logic
contract OracleWrapper is GlobalACL {
    error ZeroAddress();
    error InvalidPrice();
    error FailedDeviationCheck(uint256);
    error InvalidToken();
    error PriceOutsideTolerance();
    error OracleWrapper__NotEnoughBalance();
    error OracleWrapper__Stale();

    event UpdateTokenDetails(address indexed _token, TokenDetails _tokenDetails);

    struct TokenDetails {
        uint96 decimals;
        address chainlinkPriceFeed;
        bytes32 lloFeedId;
    }

    struct PriceDetails {
        uint32 validFrom;
        uint32 validTill;
        uint192 price;
        uint128 lastUpdatedBlockNumber;
        uint128 lastUpdatedBlockNumberL2;
        uint128 lastUpdatedBlockTimestamp;
        bytes32 feedId;
    }

    mapping(address => TokenDetails) public tokenDetails;
    IVerifierProxy public verifierProxy;
    address public immutable LINK;
    mapping(address => PriceDetails) public lloPriceDetails;
    StorageViewer public storageViewer;
    uint256 public lloDeviationFactor;
    uint256 public lloTimeTolerance = 5 minutes;
    bool public useLlo;

    constructor(
        Auth _auth,
        StorageViewer viewer,
        address _verifierProxy,
        address _link,
        uint256 _lloTimeTolerance,
        uint256 _lloDeviationFactor,
        address[] memory _tokens,
        TokenDetails[] memory _tokenDetails,
        bool _useLlo
    ) GlobalACL(_auth) {
        verifierProxy = IVerifierProxy(_verifierProxy);
        LINK = _link;
        require(address(viewer) != address(0));
        storageViewer = viewer;
        lloTimeTolerance = _lloTimeTolerance;
        lloDeviationFactor = _lloDeviationFactor;

        for (uint256 i = 0; i < _tokenDetails.length; i++) {
            _updateTokenDetails(_tokens[i], _tokenDetails[i]);
        }
        useLlo = _useLlo;
    }

    function updateViewer(StorageViewer viewer) external onlyConfigurator {
        require(address(viewer) != address(0));
        storageViewer = viewer;
    }

    function updateDeviationFactor(uint256 _newDeviationFactor) external onlyConfigurator {
        require(_newDeviationFactor < 1e18);
        lloDeviationFactor = _newDeviationFactor;
    }

    function updateTokenDetails(address _token, address _chainlinkPriceFeed, uint96 _decimals, bytes32 _lloFeedId)
        external
        onlyConfigurator
    {
        _updateTokenDetails(
            _token,
            TokenDetails({ lloFeedId: _lloFeedId, chainlinkPriceFeed: _chainlinkPriceFeed, decimals: _decimals })
        );
    }

    function updateVerifierProxy(address _verifierProxy) external onlyConfigurator {
        verifierProxy = IVerifierProxy(_verifierProxy);
    }

    function updateLloTimeTolerance(uint256 _lloTimeTolerance) external onlyConfigurator {
        lloTimeTolerance = _lloTimeTolerance;
    }

    function updateUseLlo(bool _useLlo) external onlyConfigurator {
        useLlo = _useLlo;
    }

    function getChainlinkPrice(address _token) public view returns (uint256 _price) {
        TokenDetails storage deets = tokenDetails[_token];
        uint256 tokenDecimals = deets.decimals;
        uint256 priceDecimal;

        address priceFeed = deets.chainlinkPriceFeed;
        if (priceFeed == address(0)) revert ZeroAddress();

        (, int256 price,,,) = IAggregatorV3Interface(priceFeed).latestRoundData();
        if (price < 0) revert InvalidPrice();
        _price = uint256(price);
        priceDecimal = IAggregatorV3Interface(priceFeed).decimals();

        uint256 targetDecimals = 30;
        if (priceDecimal + tokenDecimals < targetDecimals) {
            _price = _price * (10 ** (targetDecimals - priceDecimal - tokenDecimals));
        } else {
            _price = _price / (10 ** (priceDecimal + tokenDecimals - targetDecimals));
        }
    }

    function getChainlinkPriceInternal(address _token) public view returns (uint256) {
        uint256 externalPrice = getChainlinkPrice(_token);
        TokenDetails storage deets = tokenDetails[_token];
        uint256 tokenDecimals = deets.decimals;
        uint256 oneToken = 10 ** tokenDecimals;
        return externalPrice * oneToken / 1e12;
    }

    function setAndGetLloPrice(address _token, bytes memory _report)
        public
        payable
        validateSetPriceAuth
        returns (uint256 _price)
    {
        if (useLlo) {
            _price = _setAndGetPriceLlo(_token, _report);
        } else {
            _price = _setAndGetPriceInternal(_token, _report);
        }
    }

    function setAndGetLloPrices(address[] memory _tokens, bytes[] memory _reports)
        public
        payable
        returns (uint256[] memory _prices)
    {
        require(_tokens.length == _reports.length, "OracleWrapper: invalid length");
        _prices = new uint256[](_tokens.length);
        for (uint256 i = 0; i < _tokens.length; i++) {
            _prices[i] = setAndGetLloPrice(_tokens[i], _reports[i]);
        }
    }

    function depositEth() external payable { }

    function withdrawEth(address _to, uint256 _amt) external onlyConfigurator {
        (bool success,) = _to.call{ value: _amt }(hex"");
        require(success, "OracleWrapper: withdraw failed");
    }

    function getLloPriceWithinL1Blocks(address _token) public view returns (uint256 _price) {
        if (_token == TOKEN_USDC_NATIVE) return getChainlinkPrice(_token);
        PriceDetails storage priceDeets = lloPriceDetails[_token];
        if (priceDeets.feedId == bytes32(0)) revert InvalidToken();
        uint256 minBlockNumber = block.number - storageViewer.getBlockTolerance();
        if (priceDeets.lastUpdatedBlockNumber < minBlockNumber) revert PriceOutsideTolerance();
        _price = priceDeets.price;
    }

    function getLloPriceWithinL2Blocks(address _token) public view returns (uint256 _price) {
        if (_token == TOKEN_USDC_NATIVE) return getChainlinkPrice(_token);
        PriceDetails storage priceDeets = lloPriceDetails[_token];
        if (priceDeets.feedId == bytes32(0)) revert InvalidToken();
        uint256 minBlockNumber = block.number - storageViewer.getBlockTolerance();
        if (priceDeets.lastUpdatedBlockNumberL2 < minBlockNumber) revert PriceOutsideTolerance();
        _price = priceDeets.price;
    }

    function getLloPriceWithinSeconds(address _token, uint256 _seconds) public view returns (uint256 _price) {
        if (_token == TOKEN_USDC_NATIVE) return getChainlinkPrice(_token);
        PriceDetails storage priceDeets = lloPriceDetails[_token];
        if (priceDeets.feedId == bytes32(0)) revert InvalidToken();
        uint256 minTimestamp = block.timestamp - _seconds;
        if (priceDeets.lastUpdatedBlockTimestamp < minTimestamp) revert PriceOutsideTolerance();
        _price = priceDeets.price;
    }

    receive() external payable { }

    /// @dev mostly a test util, this.call so it catches the mock
    function _getLloPrice18Decimals(address _token) public view returns (uint256 _price) {
        uint256 lloPrice = this.getLloPriceWithinL1Blocks(_token);
        TokenDetails storage deets = tokenDetails[_token];
        uint256 tokenDecimals = deets.decimals;
        uint256 oneToken = uint256(10) ** tokenDecimals;
        _price = lloPrice * oneToken / 1e12;
    }

    function _approveTokens(bytes memory _report, bool _shouldApprove)
        internal
        returns (uint256 _nativeFee, uint256 _linkFee)
    {
        LLOReportDecoder.SignedReportData memory signedReportData = LLOReportDecoder.decodeSignedReport(_report);
        LLOReportDecoder.ReportData memory reportData = LLOReportDecoder.decodeReportBlob(signedReportData.blob);
        if (_shouldApprove) {
            ERC20(LINK).safeApprove(IFeeManager(verifierProxy.s_feeManager()).i_rewardManager(), reportData.linkFee);
        }
        _nativeFee = _getNativeFee(reportData.nativeFee);
        _linkFee = reportData.linkFee;
    }

    function _getBlockNumber() internal view returns (uint256 _blockNumber) {
        _blockNumber = IArbSys(ARBSYS).arbBlockNumber();
    }

    function _setAndGetPriceInternal(address _token, bytes memory _report) internal returns (uint256 _price) {
        _price = abi.decode(_report, (uint256));
        _checkPriceDeviation(_token, _price);
        lloPriceDetails[_token] = PriceDetails({
            validFrom: uint32(block.timestamp),
            validTill: uint32(block.timestamp + 5 minutes),
            price: uint192(_price),
            lastUpdatedBlockNumberL2: uint128(block.number),
            lastUpdatedBlockNumber: uint128(block.number),
            lastUpdatedBlockTimestamp: uint128(block.timestamp),
            feedId: bytes32(type(uint256).max)
        });
    }

    function _setAndGetPriceLlo(address _token, bytes memory _report) internal returns (uint256 _price) {
        bytes32 lloFeedId = tokenDetails[_token].lloFeedId;
        uint256 decimals = tokenDetails[_token].decimals;
        uint256 oneToken = 10 ** decimals;
        if (lloFeedId == bytes32(0)) revert InvalidToken();

        (uint256 nativeFee,) = _approveTokens(_report, false);
        if (nativeFee > address(this).balance) revert OracleWrapper__NotEnoughBalance();
        bytes memory verifiedData = verifierProxy.verify{ value: nativeFee }(_report, abi.encode(TOKEN_WETH));
        LLOReportDecoder.ReportData memory reportData = LLOReportDecoder.decodeReportBlob(verifiedData);
        if (reportData.benchmarkPrice < 0) revert InvalidPrice();
        if (reportData.feedId != lloFeedId) revert InvalidToken();
        _price = uint256(uint192(reportData.benchmarkPrice)) * 1e12; // 18 decimals
        _price = _price / oneToken;

        uint256 timeDiff = block.timestamp > reportData.observationsTimestamp
            ? block.timestamp - reportData.observationsTimestamp
            : reportData.observationsTimestamp - block.timestamp;
        if (timeDiff > lloTimeTolerance) revert OracleWrapper__Stale();

        _checkPriceDeviation(_token, _price);
        lloPriceDetails[_token] = PriceDetails({
            validFrom: reportData.validFromTimestamp,
            validTill: reportData.expiresAt,
            price: uint192(_price),
            lastUpdatedBlockNumberL2: uint128(block.number),
            lastUpdatedBlockNumber: uint128(block.number),
            lastUpdatedBlockTimestamp: uint128(block.timestamp),
            feedId: lloFeedId
        });
    }

    function _checkPriceDeviation(address _token, uint256 _newPrice) internal view {
        uint256 externalPrice = getChainlinkPrice(_token);
        uint256 deviation = _newPrice * 1e18 / externalPrice;
        if (deviation < 1e18 - lloDeviationFactor || deviation > 1e18 + lloDeviationFactor) {
            revert FailedDeviationCheck(deviation);
        }
    }

    function _getNativeFee(uint256 _nativeFee) internal view returns (uint256) {
        uint256 surcharge = IFeeManager(verifierProxy.s_feeManager()).s_nativeSurcharge();
        return _ceilDiv(_nativeFee * (1e18 + surcharge), 1e18);
    }

    function _ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    function _updateTokenDetails(address _token, TokenDetails memory _tokenDetails) internal {
        tokenDetails[_token] = _tokenDetails;
        emit UpdateTokenDetails(_token, _tokenDetails);
    }

    /// @dev validate the set price call
    modifier validateSetPriceAuth() {
        require(
            AUTH.hasRole(AGGREGATE_VAULT_ROLE, msg.sender) || AUTH.hasRole(REQUEST_HANDLER, msg.sender)
                || AUTH.hasRole(KEEPER_ROLE, msg.sender),
            "OracleWrapper: !authorized"
        );
        _;
    }
}
