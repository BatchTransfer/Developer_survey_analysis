pragma solidity 0.8.17;

import { BaseHandler } from "../BaseHandler.sol";
import { ISwapManager } from "../interfaces/ISwapManager.sol";
import { IHandlerContract } from "../interfaces/IHandlerContract.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";

/**
 * @title BaseSwapManager
 * @author Umami Devs
 * @notice Abstract base contract for implementing swap managers.
 * @dev This contract provides common functionality for swap manager implementations and enforces
 * swap checks using the `swapChecks` modifier.
 */
abstract contract BaseSwapManager is BaseHandler, ISwapManager {
    error InsufficientOutput();
    error InsufficientInput();
    error InvalidInput();
    error TooMuchInput();

    /**
     * @notice Returns an empty array for callback signatures.
     * @return _ret An empty bytes4[] array.
     */
    function callbackSigs() external pure returns (bytes4[] memory _ret) {
        _ret = new bytes4[](0);
    }

    /**
     * @notice Modifier to enforce swap checks, ensuring sufficient input and output token amounts.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _amountIn The amount of input tokens to swap.
     * @param _minOut The minimum amount of output tokens to receive.
     */
    modifier swapChecks(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _minOut) {
        uint256 tokenInBalance = ERC20(_tokenIn).balanceOf(address(this));
        if (tokenInBalance < _amountIn) revert InsufficientInput();
        uint256 tokenOutBalanceBefore = ERC20(_tokenOut).balanceOf(address(this));
        _;
        uint256 tokenOutBalanceAfter = ERC20(_tokenOut).balanceOf(address(this));
        uint256 actualOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
        if (actualOut < _minOut) revert InsufficientOutput();
    }

    /**
     * @notice Modifier to enforce swap checks, ensuring sufficient input and output token amounts.
     * @param _tokenIn The address of the input token.
     * @param _tokenOut The address of the output token.
     * @param _amountOut The amount of output tokens to expect.
     * @param _maxIn The max amount of input tokens to send.
     */
    modifier swapChecksExactOutput(address _tokenIn, address _tokenOut, uint256 _amountOut, uint256 _maxIn) {
        uint256 tokenInBalance = ERC20(_tokenIn).balanceOf(address(this));
        uint256 tokenOutBalanceBefore = ERC20(_tokenOut).balanceOf(address(this));
        _;
        uint256 tokenOutBalanceAfter = ERC20(_tokenOut).balanceOf(address(this));
        uint256 actualOut = tokenOutBalanceAfter - tokenOutBalanceBefore;
        if (actualOut != _amountOut) revert InsufficientOutput();
        uint256 actualIn = tokenInBalance - ERC20(_tokenIn).balanceOf(address(this));
        if (actualIn > _maxIn) revert TooMuchInput();
    }
}
