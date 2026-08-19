// SPDX-License-Identifier: UNLICENSED
// Source: 0xa15b150faa3e40165836fb8495964c960dbe5c45
// Contract Name: Revswap
// This is a flattened version of all source files
// Generated on: 2026-05-06 13:21:31


================================================================================
// FILE: @openzeppelin/contracts/access/Ownable.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/Ownable.sol)

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


================================================================================
// FILE: @openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/draft-IERC20Permit.sol)

pragma solidity ^0.8.0;

// EIP-2612 is Final as of 2022-11-01. This file is deprecated.

import "./IERC20Permit.sol";


================================================================================
// FILE: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/extensions/IERC20Permit.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 Permit extension allowing approvals to be made via signatures, as defined in
 * https://eips.ethereum.org/EIPS/eip-2612[EIP-2612].
 *
 * Adds the {permit} method, which can be used to change an account's ERC20 allowance (see {IERC20-allowance}) by
 * presenting a message signed by the account. By not relying on {IERC20-approve}, the token holder account doesn't
 * need to send a transaction, and thus is not required to hold Ether at all.
 */
interface IERC20Permit {
    /**
     * @dev Sets `value` as the allowance of `spender` over ``owner``'s tokens,
     * given ``owner``'s signed approval.
     *
     * IMPORTANT: The same issues {IERC20-approve} has related to transaction
     * ordering also apply here.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `deadline` must be a timestamp in the future.
     * - `v`, `r` and `s` must be a valid `secp256k1` signature from `owner`
     * over the EIP712-formatted function arguments.
     * - the signature must use ``owner``'s current nonce (see {nonces}).
     *
     * For more information on the signature format, see the
     * https://eips.ethereum.org/EIPS/eip-2612#specification[relevant EIP
     * section].
     */
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    /**
     * @dev Returns the current nonce for `owner`. This value must be
     * included whenever a signature is generated for {permit}.
     *
     * Every successful call to {permit} increases ``owner``'s nonce by one. This
     * prevents a signature from being used multiple times.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @dev Returns the domain separator used in the encoding of the signature for {permit}, as defined by {EIP712}.
     */
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


================================================================================
// FILE: @openzeppelin/contracts/token/ERC20/IERC20.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/IERC20.sol)

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}


================================================================================
// FILE: @openzeppelin/contracts/utils/Context.sol
================================================================================

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}


================================================================================
// FILE: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol
================================================================================

pragma solidity >=0.6.2;

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}


================================================================================
// FILE: @uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol
================================================================================

pragma solidity >=0.6.2;

import './IUniswapV2Router01.sol';

interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


================================================================================
// FILE: contracts/Revswap.sol
================================================================================

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20PermitWithNonce {
    function permit(
        address holder,
        address spender,
        uint256 nonce,
        uint256 expiry,
        bool allowed,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

contract Revswap is Ownable {
    // Constants and state variables
    address public constant rvsToken =
        0xf282484234D905D7229a6C22A0e46bb4b0363eE0;
    address public constant swapRouterAddress =
        0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    IUniswapV2Router02 public immutable swapRouter =
        IUniswapV2Router02(swapRouterAddress);
    uint256 public minRVSForBonification = 5000;
    uint256 public feePercentage = 100; // 1% fee
    uint256 public feePercentageForHolders = 200; // 2% fee

    // Events
    event TokensSwapped(
        address indexed user,
        address indexed token,
        uint256 totalToSwap,
        uint256 totalETHSwapped,
        uint256 gasCost
    );

    // Structs
    struct SwapDetails {
        address tokenIn;
        uint256 amountIn;
        uint256 amountOutMin;
        address recipient;
    }

    struct PermitDetails {
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    struct PermitDetailsWithNonce {
        uint256 nonce;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    // Swap functions
    function swapTokenForETHNoNonce(
        SwapDetails memory swapDetails,
        PermitDetails memory permitDetails,
        uint256 deadline
    ) external onlyOwner {
        _swapTokenForETH(swapDetails, deadline, true, permitDetails);
    }

    function swapTokenForETHWithNonce(
        SwapDetails memory swapDetails,
        PermitDetailsWithNonce memory permitDetails,
        uint256 deadline
    ) external onlyOwner {
        _swapTokenForETHWithNonce(swapDetails, permitDetails, deadline);
    }

    function swapTokenForETHAlreadyApproved(
        SwapDetails memory swapDetails,
        uint256 deadline
    ) external onlyOwner {
        _swapTokenForETH(swapDetails, deadline, false, PermitDetails(0, 0, 0));
    }

    // Helper functions
    function _swapTokenForETH(
        SwapDetails memory swapDetails,
        uint256 deadline,
        bool usePermit,
        PermitDetails memory permitDetails
    ) internal {
        uint256 gasStart = gasleft();

        if (usePermit) {
            IERC20Permit(swapDetails.tokenIn).permit(
                swapDetails.recipient,
                address(this),
                swapDetails.amountIn,
                deadline,
                permitDetails.v,
                permitDetails.r,
                permitDetails.s
            );
        }

        require(
            IERC20(swapDetails.tokenIn).transferFrom(
                swapDetails.recipient,
                address(this),
                swapDetails.amountIn
            ),
            "Transfer of tokens failed."
        );

        _performSwap(swapDetails, deadline, gasStart);
    }

    function _swapTokenForETHWithNonce(
        SwapDetails memory swapDetails,
        PermitDetailsWithNonce memory permitDetails,
        uint256 deadline
    ) internal {
        uint256 gasStart = gasleft();

        IERC20PermitWithNonce(swapDetails.tokenIn).permit(
            swapDetails.recipient,
            address(this),
            permitDetails.nonce,
            deadline,
            true,
            permitDetails.v,
            permitDetails.r,
            permitDetails.s
        );

        require(
            IERC20(swapDetails.tokenIn).transferFrom(
                swapDetails.recipient,
                address(this),
                swapDetails.amountIn
            ),
            "Transfer of tokens failed."
        );

        _performSwap(swapDetails, deadline, gasStart);
    }

    function _performSwap(
        SwapDetails memory swapDetails,
        uint256 deadline,
        uint256 gasStart
    ) internal {
        IERC20(swapDetails.tokenIn).approve(
            address(swapRouter),
            swapDetails.amountIn
        );

        address[] memory path = new address[](2);
        path[0] = swapDetails.tokenIn;
        path[1] = swapRouter.WETH();
        uint256[] memory amounts = swapRouter.swapExactTokensForETH(
            swapDetails.amountIn,
            swapDetails.amountOutMin,
            path,
            address(this),
            deadline
        );

        uint256 ethAmount = amounts[amounts.length - 1];
        uint256 feeToApply = IERC20(rvsToken).balanceOf(swapDetails.recipient) >
            minRVSForBonification * 10 ** 18
            ? feePercentage
            : feePercentageForHolders;
        uint256 fee = (ethAmount * feeToApply) / 10000;
        uint256 gasCost = (gasStart - gasleft()) * tx.gasprice;

        _transferFunds(swapDetails.recipient, ethAmount, gasCost, fee);
        emit TokensSwapped(
            swapDetails.recipient,
            swapDetails.tokenIn,
            swapDetails.amountIn,
            ethAmount,
            gasCost
        );
    }

    function _transferFunds(
        address recipient,
        uint256 ethAmount,
        uint256 gasCost,
        uint256 fee
    ) internal {
        (bool sentToRecipient, ) = recipient.call{
            value: ethAmount - gasCost - fee
        }("");
        require(sentToRecipient, "Failed to send ETH to recipient");

        (bool sentToOwner, ) = owner().call{value: gasCost + fee}("");
        require(sentToOwner, "Failed to refund gas cost to owner");
    }

    // Management functions
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount <= address(this).balance, "Insufficient balance");
        (bool sent, ) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send ETH");
    }

    function setFeePercentage(
        uint256 _feePercentage,
        uint256 _feePercentageForHolders
    ) external onlyOwner {
        require(
            _feePercentage <= 1000 && _feePercentageForHolders <= 1000,
            "Fee cannot be greater than 10%"
        );
        feePercentage = _feePercentage;
        feePercentageForHolders = _feePercentageForHolders;
    }

    function setMinRVSForBonification(
        uint256 _minRVSForBonification
    ) external onlyOwner {
        minRVSForBonification = _minRVSForBonification;
    }

    // Receive function
    receive() external payable {}
}
