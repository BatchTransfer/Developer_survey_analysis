// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { IHandlerContract } from "./interfaces/IHandlerContract.sol";
import { ISwapManager } from "./interfaces/ISwapManager.sol";
import { PositionManagerRouter } from "./position-managers/PositionManagerRouter.sol";

/**
 * @title BaseHandler
 * @author Umami DAO
 * @notice Abstract base contract for implementing handler contracts with a delegate call restriction.
 * @dev Any contract inheriting from this contract must implement the IHandlerContract interface.
 */
abstract contract BaseHandler is IHandlerContract {
    address immutable SELF;

    error OnlyDelegateCall();

    constructor() {
        SELF = address(this);
    }

    /**
     * @notice Executes a token swap using the provided SwapManager instance.
     * @param _swapManager The SwapManager instance to use for the swap.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _amountIn The input amount to swap.
     * @param _minOut The minimum output amount required for the swap.
     * @param _data Additional data for the swap.
     * @return _amountOut The output amount received from the swap.
     */
    function _executeSwap(
        ISwapManager _swapManager,
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _minOut,
        bytes memory _data
    ) internal returns (uint256 _amountOut) {
        _amountOut = PositionManagerRouter(payable(address(this))).executeSwap(
            _swapManager, _tokenIn, _tokenOut, _amountIn, _minOut, _data
        );
    }

    /**
     * @notice Modifier to restrict functions to be called only via delegate call.
     * @dev Reverts if the function is called directly (not via delegate call).
     */
    modifier onlyDelegateCall() {
        if (address(this) == SELF) {
            revert OnlyDelegateCall();
        }
        _;
    }
}
