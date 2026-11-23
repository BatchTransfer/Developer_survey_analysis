// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { Solarray } from "../libraries/Solarray.sol";

/// @title NettedPositionTracker
/// @author Umami Devs
/// @notice Math for tracking netted positions in the vault
library NettedPositionTracker {
    /**
     * @notice Derive the pnl for each vault in dollars (1e18)
     * @param internalPositions matrix of internal positions taken out by each vault
     * @param assetPriceChange percent price change for each asset in 1e18 eg. 5% = 0.05 * 1e18 / 1e18
     * @return pnl pnl for each vault in dollars
     */
    function getNettedPnl(int256[2][2] memory internalPositions, int256[2] memory assetPriceChange)
        internal
        pure
        returns (int256[2] memory pnl)
    {
        int256[2] memory iPnl;
        int256[2] memory nettingCollumnSum = Solarray.sumColumns(internalPositions);

        nettingCollumnSum[0] -= internalPositions[0][0];
        nettingCollumnSum[1] -= internalPositions[1][1];

        iPnl[0] += nettingCollumnSum[0] * assetPriceChange[0] / 1e18;
        iPnl[1] += nettingCollumnSum[1] * assetPriceChange[1] / 1e18;

        pnl[0] = nettingCollumnSum[1] != 0
            ? iPnl[0] + (-iPnl[1] * (internalPositions[0][1] * 1e18 / nettingCollumnSum[1])) / 1e18
            : iPnl[0];
        pnl[1] = nettingCollumnSum[0] != 0
            ? iPnl[1] + (-iPnl[0] * (internalPositions[1][0] * 1e18 / nettingCollumnSum[0])) / 1e18
            : iPnl[1];
    }

    /**
     * @notice Returns the settle result from the internal positions
     * @param internalPositions matrix of internal netted positions the vaults hold
     * @param currentAssetPrices current asset prices in 1e18
     * @param nettedAssetPrices asset prices at last settlement
     * @param vaultIndexAmount index amount owned by each vault
     * @param indexPrice price of index in 1e18
     * @param pnlSumThreshold threshold for the sum of pnl to be under
     * @return settledVaultIndexAmount amount of index held by each vault after internal pnl is settled
     * @return nettedPnl pnl for each vault in $
     * @return indexPnl pnl for each vault in index
     */
    function settleNettingPositionPnl(
        int256[2][2] memory internalPositions,
        int256[2] memory currentAssetPrices,
        int256[2] memory nettedAssetPrices,
        uint256[2] memory vaultIndexAmount,
        uint256 indexPrice,
        uint256 pnlSumThreshold
    )
        internal
        pure
        returns (
            uint256[2] memory settledVaultIndexAmount,
            int256[2] memory nettedPnl,
            int256[2] memory indexPnl,
            int256[2] memory percentPriceChange
        )
    {
        _validatePrices(currentAssetPrices, nettedAssetPrices);
        require(indexPrice > 0, "NettedPositionTracker: indexPrice must be greater than 0");

        // calculate the change in price
        percentPriceChange = calculatePriceChange(currentAssetPrices, nettedAssetPrices);

        // get the dollar value pnl
        nettedPnl = getNettedPnl(internalPositions, percentPriceChange);

        // require 0 sum
        checkZeroSum(nettedPnl, pnlSumThreshold);

        indexPnl = pnlToIndex(int256(indexPrice), nettedPnl);

        // find the index value pnl using index price
        int256[2] memory indexPnlDifference = Solarray.arrayDifference(vaultIndexAmount, indexPnl);
        checkNegativeDifference(indexPnlDifference);

        settledVaultIndexAmount = Solarray.intToUintArray(indexPnlDifference);
    }

    /**
     * @notice Calculates the % price change for each asset in 1e18
     * @param currentPrices current asset prices
     * @param nettedPrices last netted prices
     * @return percentPriceChange % price change in 1e18 eg. 1% = 0.01 * 1e18 / 1e18
     */
    function calculatePriceChange(int256[2] memory currentPrices, int256[2] memory nettedPrices)
        internal
        pure
        returns (int256[2] memory percentPriceChange)
    {
        percentPriceChange[0] = ((currentPrices[0] - nettedPrices[0]) * 1e18 / nettedPrices[0]);
        percentPriceChange[1] = ((currentPrices[1] - nettedPrices[1]) * 1e18 / nettedPrices[1]);
    }

    /**
     * @notice Calculated the pnl denominated in the index basket
     * @param indexPrice share price of the index
     * @param pnl in $ 1e18
     * @return indexAmount index pnl for each vault
     */
    function pnlToIndex(int256 indexPrice, int256[2] memory pnl) internal pure returns (int256[2] memory indexAmount) {
        indexAmount[0] = (pnl[0] * 1e18 / indexPrice);
        indexAmount[1] = (pnl[1] * 1e18 / indexPrice);
    }

    /**
     * @notice Check for zero sum of pnl to ensure balanced pnl from internal positions
     * @param nettingPositionPnl array of pnl for each vault
     * @param zeroSumThreshold threshold for the zero sum, used for rounding errors
     */
    function checkZeroSum(int256[2] memory nettingPositionPnl, uint256 zeroSumThreshold) internal pure {
        uint256 absoluteSum = Solarray.arraySumAbsolute(nettingPositionPnl);
        int256 pnlDifference = Solarray.arraySum(nettingPositionPnl);
        uint256 pnlAbsoluteDifference = pnlDifference > 0 ? uint256(pnlDifference) : uint256(-pnlDifference);
        uint256 buffer = (absoluteSum * zeroSumThreshold) / 1e18;
        if (absoluteSum == 0) return; // no internal position change
        require(pnlAbsoluteDifference < buffer, "NettedPositionTracker: greater than threshold");
    }

    /**
     * @notice Check for vault index remaining to be above the capacity of the vault
     * @param differenceArray new allocation to index for each vault
     */
    function checkNegativeDifference(int256[2] memory differenceArray) internal pure {
        require(differenceArray[0] >= 0 && differenceArray[1] >= 0, "NettedPositionTracker: differenceArray[i] < 0");
    }

    /**
     * @notice Check for valid prices
     * @param _a prices array
     * @param _b prices array
     */
    function _validatePrices(int256[2] memory _a, int256[2] memory _b) internal pure {
        require(_a[0] > 0 && _a[1] > 0, "NettedPositionTracker: _a[i] must be greater than 0");
        require(_b[0] > 0 && _b[1] > 0, "NettedPositionTracker: _b[i] must be greater than 0");
    }
}
