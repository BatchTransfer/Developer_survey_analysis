// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

/// @title Transfer utilities for tokens and eth
/// @author Umami Devs
library TransferUtils {
    using SafeTransferLib for ERC20;

    /**
     * @notice Helper function to make an ERC20 transfer
     * @param asset the asset to transfer
     * @param recipient is the receiving address
     * @param amount is the transfer amount
     */
    function transferAsset(address asset, address recipient, uint256 amount) internal {
        ERC20(asset).safeTransfer(recipient, amount);
    }

    /**
     * @notice Helper function to make an ETH transfer
     * @param recipient is the receiving address
     * @param amount is the transfer amount
     */
    function transferNativeAsset(address recipient, uint256 amount) internal {
        (bool success,) = recipient.call{ value: amount }("");
        require(success, "TransferUtils: failed native token transfer");
    }
}
