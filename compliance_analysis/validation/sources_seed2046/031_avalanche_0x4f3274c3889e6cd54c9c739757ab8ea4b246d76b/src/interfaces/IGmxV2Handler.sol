// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { GmxStorage } from "../libraries/GmxStorage.sol";
import { Price } from "gmx-synthetics/price/Price.sol";
import { Market } from "gmx-synthetics/market/MarketUtils.sol";

import { GmxStorage } from "../libraries/GmxStorage.sol";

/// @title GmxV2HandlerStorage
/// @author Umami Devs
contract GmxV2HandlerStorage {
    struct DepositRequestDetails {
        address market;
        uint256 longTokenAmountDeposited;
        uint256 shortTokenAmountDeposited;
        uint256 amountMinted;
        bool executed;
        bool success;
        uint256 longTokenPrice;
        uint256 shortTokenPrice;
        int256 feesPaid;
    }

    struct WithdrawRequestDetails {
        address market;
        uint256 gmAmountDeposited;
        uint256 shortTokenAmountReceived;
        uint256 longTokenAmountReceived;
        bool executed;
        bool success;
        uint256 longTokenPrice;
        uint256 shortTokenPrice;
        int256 feesPaid;
    }

    struct RequestDetails {
        address market;
        address withAsset;
        uint256 amount; // in case of deposit it is the
        bool isDeposit;
    }

    struct GmxV2Storage {
        mapping(bytes32 => DepositRequestDetails) depositRequests;
        mapping(bytes32 => WithdrawRequestDetails) withdrawRequests;
    }

    bytes32 GMX_V2_STORAGE_SLOT = keccak256("gmx.v2.storage");

    function _getGmxV2Storage() internal view returns (GmxV2Storage storage _storage) {
        bytes32 position = GMX_V2_STORAGE_SLOT;
        assembly {
            _storage.slot := position
        }
    }
}

interface IGmxV2Handler {
    function burnGmTokens(address _market, uint256 _amount, address _receiver)
        external
        returns (bytes32 _withdrawKey);
    function mintGmTokens(address _market, uint256 _amountLongToken, uint256 _amountShortToken, address _receiver)
        external
        payable
        returns (bytes32 _depositKey);
    function getMarket(address _market) external view returns (Market.Props memory _marketProps);
    function getGmMidPrice(address market, GmxStorage.MarketPrices memory tokenPrices)
        external
        view
        returns (uint256 price);
    function getDepositRequestDetails(bytes32 _key)
        external
        view
        returns (GmxV2HandlerStorage.DepositRequestDetails memory);
    function getWithdrawRequestDetails(bytes32 _key)
        external
        view
        returns (GmxV2HandlerStorage.WithdrawRequestDetails memory);
    function getMaxDepositAmount(address _market, address _token) external view returns (uint256 maxDepositAmount);
}
