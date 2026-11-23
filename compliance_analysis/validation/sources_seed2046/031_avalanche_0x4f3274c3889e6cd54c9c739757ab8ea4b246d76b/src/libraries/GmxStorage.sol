// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { PriceCast } from "./PriceCast.sol";

/// @title GmxStorage
/// @dev Struct wrapper for Gmx Storage
/// @author Umami Devs
library GmxStorage {
    // pricing struct for a gmx market
    struct MarketPrices {
        Price indexTokenPrice;
        Price longTokenPrice;
        Price shortTokenPrice;
    }

    // @param min the min price
    // @param max the max price
    struct Price {
        uint256 min;
        uint256 max;
    }

    // cast from 1e18
    function castToPrice(uint256 min, uint256 max, uint256 decimals) internal pure returns (Price memory) {
        return Price(PriceCast.toExternalPricing(min, decimals), PriceCast.toExternalPricing(max, decimals));
    }

    // market token prices as [index, long, short]
    function castToMarketPrices(uint256[3] memory min, uint256[3] memory max, uint256[3] memory decimals)
        internal
        pure
        returns (MarketPrices memory)
    {
        return MarketPrices(
            castToPrice(min[0], max[0], decimals[0]),
            castToPrice(min[1], max[1], decimals[1]),
            castToPrice(min[2], max[2], decimals[2])
        );
    }
}
