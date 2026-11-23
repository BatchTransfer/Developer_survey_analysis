// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { SafeCast } from "./SafeCast.sol";
import { Solarray } from "./Solarray.sol";

/// @title NettingMath
/// @author Umami Devs
/// @notice Contains math for validating a set of netted parameters
library NettingMath {
    // PUBLIC
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Calculates the GLP exposure and vault ratio for each position
     * @param vaultCumulativeHoldings The vault's cumulative index TVL
     * @param indexComposition The index composition as an array of two uint256 values
     * @param vaultHoldings The amount of the index token allocated to each vault
     * @param externalPosition the external positions
     * @return indexExposure An array of index exposure for each position
     * @return vaultRatio An array of vault ratios for each position
     */
    function vaultDeltaAdjustment(
        uint256 vaultCumulativeHoldings,
        uint256[2] memory indexComposition,
        uint256[2] memory vaultHoldings,
        int256 externalPosition
    ) public pure returns (uint256[2] memory indexExposure, uint256 vaultRatio) {
        indexExposure[0] = vaultCumulativeHoldings * indexComposition[0] / 1e18;
        indexExposure[1] = vaultCumulativeHoldings * indexComposition[1] / 1e18;

        if (externalPosition < 0) {
            indexExposure[1] += uint256(-externalPosition);
        } else {
            indexExposure[1] -= uint256(externalPosition);
        }

        vaultRatio = indexExposure[1] * 1e18 / vaultHoldings[1];
    }

    /**
     * @notice Calculates the netted and exposure matrices for the given positions and GLP composition
     * @param externalPosition The external position for the vaults
     * @param indexComposition The index composition as an array of two uint256 values
     * @param indexHeldDollars The GLP held as an array of five uint256 values
     * @return nettedMatrix A 2x2 matrix of netted positions
     * @return exposureMatrix A 2x2 matrix of exposures
     */
    function calculateNettedPositions(
        int256 externalPosition,
        uint256[2] memory indexComposition,
        uint256[2] memory indexHeldDollars
    ) public pure returns (int256[2][2] memory nettedMatrix, int256[2][2] memory exposureMatrix) {
        exposureMatrix[0] = _vaultExposureInt(indexHeldDollars[0], indexComposition);
        exposureMatrix[1] = _vaultExposureInt(indexHeldDollars[1], indexComposition);

        nettedMatrix[0][0] = exposureMatrix[0][0];
        nettedMatrix[1][1] = exposureMatrix[1][1];

        if (externalPosition > 0) {
            nettedMatrix[0][1] = exposureMatrix[0][1] - externalPosition;
            nettedMatrix[1][0] = exposureMatrix[1][0];
        } else {
            nettedMatrix[0][1] = exposureMatrix[0][1];
            nettedMatrix[1][0] = exposureMatrix[1][0] + externalPosition;
        }
    }

    /**
     * @notice Determines whether the given netted state is within the netted threshold
     * @param vaultCumulativeHoldings The current netted state containing GLP held and external positions
     * @param indexComposition The asset somposition of the udnelrying index
     * @param vaultHoldings The amount of the index token allocated to each vault
     * @param externalPosition The external position for the vaults
     * @param nettedThreshold The threshold for the netted amount
     * @return netted if the vaults are balances
     */
    function isNetted(
        uint256 vaultCumulativeHoldings,
        uint256[2] memory indexComposition,
        uint256[2] memory vaultHoldings,
        int256 externalPosition,
        uint256 nettedThreshold
    ) public pure returns (bool netted) {
        uint256[2] memory indexExposure;
        uint256 vaultRatio;
        // if the vault is 0'd out
        if (vaultCumulativeHoldings < 1e18) return true;
        // note positions are NOT scaled up by a factor x to account for counterparty affect when using gmx.
        // here we take the unscaled externalPositions as input
        (indexExposure, vaultRatio) =
            vaultDeltaAdjustment(vaultCumulativeHoldings, indexComposition, vaultHoldings, externalPosition);

        uint256 upper = 1e18 * (10_000 + nettedThreshold) / 10_000;
        uint256 lower = 1e18 * (10_000 - nettedThreshold) / 10_000;
        netted = true;
        if (vaultRatio > upper || vaultRatio < lower) {
            netted = false;
        }
    }

    // INTERNAL
    // ------------------------------------------------------------------------------------------

    function _vaultExposureInt(uint256 glpHeldDollars, uint256[2] memory indexComposition)
        internal
        pure
        returns (int256[2] memory exposure)
    {
        for (uint256 i = 0; i < 2; i++) {
            exposure[i] = SafeCast.toInt256((glpHeldDollars * indexComposition[i]) / 1e18);
        }
    }
}
