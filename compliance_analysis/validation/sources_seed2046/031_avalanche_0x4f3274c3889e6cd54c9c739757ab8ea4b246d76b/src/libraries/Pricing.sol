// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { OracleWrapper } from "../peripheral/OracleWrapper.sol";
import { IGMIWithERC20 as GMI } from "../interfaces/IGMI.sol";
import { GmxStorage } from "./GmxStorage.sol";
import { PriceCast } from "./PriceCast.sol";
import { MarketUtils, DataStore, Market } from "@gmx/market/MarketUtils.sol";
import { GMX_V2_DATA_STORE } from "../constants.sol";

/// @title GMPricing
/// @author Umami Devs
library GMPricing {
    function getMarketPrice(address _oracle, address _gm, bool _useLlo)
        internal
        view
        returns (GmxStorage.MarketPrices memory)
    {
        Market.Props memory marketProps = MarketUtils.getEnabledMarket(DataStore(GMX_V2_DATA_STORE), _gm);
        return getMarketPrice(_oracle, _gm, _useLlo, marketProps.longToken, marketProps.shortToken);
    }

    function getMarketPrice(address _oracle, address _gm, bool _useLlo, address _longToken, address _shortToken)
        internal
        view
        returns (GmxStorage.MarketPrices memory)
    {
        uint256 longTokenPrice = getTokenPrice(_oracle, _longToken, _useLlo);
        uint256 shortTokenPrice = getTokenPrice(_oracle, _shortToken, _useLlo);

        return getMarketPrice(_oracle, _gm, longTokenPrice, shortTokenPrice, _useLlo);
    }

    function getMarketPrice(
        address _oracle,
        address _gm,
        uint256 _longTokenPrice,
        uint256 _shortTokenPrice,
        bool _useLlo
    ) internal view returns (GmxStorage.MarketPrices memory marketPrice) {
        address indexToken = MarketUtils.getEnabledMarket(DataStore(GMX_V2_DATA_STORE), _gm).indexToken;
        marketPrice.longTokenPrice = GmxStorage.Price({ min: _longTokenPrice, max: _longTokenPrice });
        marketPrice.shortTokenPrice = GmxStorage.Price({ min: _shortTokenPrice, max: _shortTokenPrice });
        uint256 indexTokenPrice = getTokenPrice(_oracle, indexToken, _useLlo);
        marketPrice.indexTokenPrice = GmxStorage.Price({ min: indexTokenPrice, max: indexTokenPrice });
    }

    function getTokenPrice(address _oracle, address _token, bool _withLlo) internal view returns (uint256) {
        return _withLlo
            ? OracleWrapper(payable(_oracle)).getLloPriceWithinL1Blocks(_token)
            : OracleWrapper(payable(_oracle)).getChainlinkPrice(_token);
    }
}

/// @title Pricing
/// @author Umami Devs
library Pricing {
    function getMarketPrices(address _oracle, GMI _gmi, bool _useLlo)
        internal
        view
        returns (GmxStorage.MarketPrices[] memory marketPrices)
    {
        uint256 indexSize = _gmi.indexAssetsLength();
        marketPrices = new GmxStorage.MarketPrices[](indexSize);
        address[] memory marketTokens = _gmi.indexAssets();
        // assuming all markets in GMI has same long and short token
        // which it will.
        Market.Props memory marketProps = MarketUtils.getEnabledMarket(DataStore(GMX_V2_DATA_STORE), marketTokens[0]);
        uint256 longTokenPrice = getTokenPrice(_oracle, marketProps.longToken, _useLlo);
        uint256 shortTokenPrice = getTokenPrice(_oracle, marketProps.shortToken, _useLlo);
        for (uint256 i = 0; i < indexSize; i++) {
            marketPrices[i] = getMarketPrice(_oracle, marketTokens[i], longTokenPrice, shortTokenPrice, _useLlo);
        }
        return marketPrices;
    }

    function getIndexTvl(address _oracle, GMI _gmi) internal view returns (uint256) {
        return _gmi.tvl(getMarketPrices(_oracle, _gmi, true));
    }

    function getIndexTvlChainlink(address _oracle, GMI _gmi) internal view returns (uint256) {
        return _gmi.tvl(getMarketPrices(_oracle, _gmi, false));
    }

    function getIndexPps(address _oracle, GMI _gmi) internal view returns (uint256) {
        return _gmi.pps(getMarketPrices(_oracle, _gmi, true));
    }

    function getIndexPpsChainlink(address _oracle, GMI _gmi) internal view returns (uint256) {
        return _gmi.pps(getMarketPrices(_oracle, _gmi, false));
    }

    function getMarketPrice(address _oracle, address _gm, bool _useLlo)
        internal
        view
        returns (GmxStorage.MarketPrices memory)
    {
        return GMPricing.getMarketPrice(_oracle, _gm, _useLlo);
    }

    function getMarketPrice(
        address _oracle,
        address _gm,
        uint256 _longTokenPrice,
        uint256 _shortTokenPrice,
        bool _useLlo
    ) internal view returns (GmxStorage.MarketPrices memory marketPrice) {
        return GMPricing.getMarketPrice(_oracle, _gm, _longTokenPrice, _shortTokenPrice, _useLlo);
    }

    function getTokenPrice(address _oracle, address _token, bool _withLlo) internal view returns (uint256) {
        return GMPricing.getTokenPrice(_oracle, _token, _withLlo);
    }
}
