// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/// @title Price Cast
/// @author Umami Devs
/// @notice Contains methods for casting price to gmx decimals
library PriceCast {
    /// @notice Cast an internal 1e18 price to price per unit
    /// @param internalPrice The 1e18 price to be casted
    /// @param decimals The token decimals
    /// @return externalPrice Price per unit
    function toExternalPricing(uint256 internalPrice, uint256 decimals) internal pure returns (uint256 externalPrice) {
        externalPrice = (internalPrice * 1e12) / 10 ** decimals;
    }

    /// @notice Cast price per unit to 1e18 standard
    /// @param externalPrice The price per unit
    /// @param decimals The token decimals
    /// @return internalPrice 1e18 decmal price
    function toInternalPrice(uint256 externalPrice, uint256 decimals) internal pure returns (uint256 internalPrice) {
        internalPrice = (externalPrice * 1e18) / 10 ** (30 - decimals);
    }
}
