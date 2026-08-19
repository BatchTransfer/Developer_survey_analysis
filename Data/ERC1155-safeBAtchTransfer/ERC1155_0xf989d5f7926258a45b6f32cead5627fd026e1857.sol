// File: contracts/validators/KSZapValidatorV2.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import {IKSZapValidatorV2} from 'contracts/interfaces/zap/validators/IKSZapValidatorV2.sol';
import {IERC20} from 'openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IUniswapv3NFT} from 'contracts/interfaces/uniswapv3/IUniswapv3NFT.sol';
import {IAlgebraV19NFT} from 'contracts/interfaces/algebrav19/IAlgebraV19NFT.sol';
import {IZapDexEnum} from 'contracts/interfaces/zap/common/IZapDexEnum.sol';
import {KSRescueV2} from 'ks-growth-utils-sc/contracts/KSRescueV2.sol';
import {ISolidlyV3Pool} from 'contracts/interfaces/solidlyv3/ISolidlyV3Pool.sol';
import {ZapTypeHash} from 'contracts/common/ZapTypeHash.sol';

contract KSZapValidatorV2 is IKSZapValidatorV2, KSRescueV2, ZapTypeHash {
  address constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

  function prepareValidationData(
    uint8,
    bytes calldata _zapInfo
  ) external view returns (bytes memory) {
    ValidationData memory data;
    ZapInfo memory zapInfo = abi.decode(_zapInfo, (ZapInfo));

    data.srcType = zapInfo.srcType;
    data.srcValidationData = _getPrepareDataFunction(zapInfo.srcType)(zapInfo.srcZapInfo);

    data.dstType = zapInfo.dstType;
    data.dstValidationData = _getPrepareDataFunction(zapInfo.dstType)(zapInfo.dstZapInfo);

    return abi.encode(data);
  }

  function validateData(
    uint8,
    bytes calldata _extraData,
    bytes calldata _validationData,
    bytes calldata _zapResults
  ) external view returns (bool) {
    ValidationData memory validationData = abi.decode(_validationData, (ValidationData));
    ExtraData memory extraData = abi.decode(_extraData, (ExtraData));

    return _getValidateRemovingFunction(validationData.srcType)(
      extraData.srcExtraData, validationData.srcValidationData
    )
      && _getValidateResultsFunction(validationData.dstType)(
        extraData.dstExtraData, validationData.dstValidationData
      );
  }

  /// @notice Dummy function to prepare validation data for none action
  function _prepareNoneValidationData(bytes memory) internal pure returns (bytes memory) {}

  function _prepareUniswapV3ValidationData(
    bytes memory _zapInfo
  ) internal view returns (bytes memory) {
    UniswapV3ValidationData memory data;
    data.zapInfo = abi.decode(_zapInfo, (UniswapV3ZapInfo));
    if (data.zapInfo.posID == 0) {
      // minting new position, temporary store the total supply here
      data.zapInfo.posID = IUniswapv3NFT(data.zapInfo.posManager).totalSupply();
    } else {
      (,,,,,,, data.initialLiquidity,,,,) =
        IUniswapv3NFT(data.zapInfo.posManager).positions(data.zapInfo.posID);
    }
    return abi.encode(data);
  }

  function _prepareAlgebraValidationData(
    bytes memory _zapInfo
  ) internal view returns (bytes memory) {
    UniswapV3ValidationData memory data;
    data.zapInfo = abi.decode(_zapInfo, (UniswapV3ZapInfo));
    if (data.zapInfo.posID == 0) {
      // minting new position, temporary store the total supply here
      data.zapInfo.posID = IAlgebraV19NFT(data.zapInfo.posManager).totalSupply();
    } else {
      (,,,,,, data.initialLiquidity,,,,) =
        IAlgebraV19NFT(data.zapInfo.posManager).positions(data.zapInfo.posID);
    }
    return abi.encode(data);
  }

  /// @notice Generate initial data for validation for zap out action
  /// @param _zapInfo contains info of zap out
  function _prepareERC20ValidationData(bytes memory _zapInfo) internal view returns (bytes memory) {
    ERC20ValidationData memory data;
    data.zapInfo = abi.decode(_zapInfo, (ERC20ZapInfo));
    data.initialBalance = data.zapInfo.token == ETH_ADDRESS
      ? data.zapInfo.recipient.balance
      : IERC20(data.zapInfo.token).balanceOf(data.zapInfo.recipient);
    return abi.encode(data);
  }

  /// @notice Generate initial data for validation for zap in Solidly V3
  /// @param _zapInfo contains info of zap in Solidly V3
  function _prepareSolidlyV3ValidationData(
    bytes memory _zapInfo
  ) internal view returns (bytes memory) {
    SolidlyV3ValidationData memory data;
    data.zapInfo = abi.decode(_zapInfo, (SolidlyV3ZapInfo));
    bytes32 positionKey = keccak256(
      abi.encodePacked(data.zapInfo.recipient, data.zapInfo.tickLower, data.zapInfo.tickUpper)
    );
    (data.initialLiquidity,,) = ISolidlyV3Pool(data.zapInfo.pool).positions(positionKey);
    return abi.encode(data);
  }

  /// @notice Dummy function to validate none action
  function _validateNoneResult(bytes memory, bytes memory) internal pure returns (bool) {
    return true;
  }

  /// @notice Validate result for zapping into Uniswap V3
  ///   2 cases:
  ///     - new position:
  ///       + posID is the totalSupply, need to fetch the corresponding posID
  ///       + _extraData contains (recipient, posTickLower, posTickLower, minLiquidity) where:
  ///         (+) recipient is the owner of the posID
  ///         (+) posTickLower, posTickUpper are matched with position's tickLower/tickUpper
  ///         (+) pool is matched with position's pool
  ///         (+) minLiquidity <= pos.liquidity
  ///     - increase liquidity:
  ///       + _extraData contains minLiquidity, where:
  ///         (+) minLiquidity <= (pos.liquidity - initialLiquidity)
  function _validateUniswapV3Result(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    UniswapV3ValidationData memory data = abi.decode(_validationData, (UniswapV3ValidationData));
    IUniswapv3NFT posManager = IUniswapv3NFT(data.zapInfo.posManager);
    UniswapV3ExtraData memory extraData = abi.decode(_extraData, (UniswapV3ExtraData));
    uint128 newLiquidity;
    if (extraData.tickLower < extraData.tickUpper) {
      // minting a new position, need to validate many data
      // Calculate the posID and replace, it should be the last index
      uint256 posID = posManager.tokenByIndex(data.zapInfo.posID);
      // require owner of the pos id is the recipient
      if (posManager.ownerOf(posID) != extraData.recipient) return false;
      // getting pos info from Position Manager
      int24 tickLower;
      int24 tickUpper;
      (,,,,, tickLower, tickUpper, newLiquidity,,,,) = posManager.positions(posID);
      // tick ranges should match
      if (extraData.tickLower != tickLower || extraData.tickUpper != tickUpper) {
        return false;
      }
    } else {
      // not a new position, only need to verify liquidty increment
      // getting new position liquidity, make sure it is increased
      (,,,,,,, newLiquidity,,,,) = posManager.positions(data.zapInfo.posID);
    }
    return newLiquidity >= extraData.minLiquidity + data.initialLiquidity;
  }

  /// @notice Validate result for zapping into Algebra
  ///   2 cases:
  ///     - new position:
  ///       + posID is the totalSupply, need to fetch the corresponding posID
  ///       + _extraData contains (recipient, posTickLower, posTickLower, minLiquidity) where:
  ///         (+) recipient is the owner of the posID
  ///         (+) posTickLower, posTickUpper are matched with position's tickLower/tickUpper
  ///         (+) pool is matched with position's pool
  ///         (+) minLiquidity <= pos.liquidity
  ///     - increase liquidity:
  ///       + _extraData contains minLiquidity, where:
  ///         (+) minLiquidity <= (pos.liquidity - initialLiquidity)
  function _validateAlgebraResult(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    UniswapV3ValidationData memory data = abi.decode(_validationData, (UniswapV3ValidationData));
    IAlgebraV19NFT posManager = IAlgebraV19NFT(data.zapInfo.posManager);
    UniswapV3ExtraData memory extraData = abi.decode(_extraData, (UniswapV3ExtraData));
    uint128 newLiquidity;
    if (extraData.tickLower < extraData.tickUpper) {
      // minting a new position, need to validate many data
      // Calculate the posID and replace, it should be the last index
      uint256 posID = posManager.tokenByIndex(data.zapInfo.posID);
      // require owner of the pos id is the recipient
      if (posManager.ownerOf(posID) != extraData.recipient) return false;
      // getting pos info from Position Manager
      int24 tickLower;
      int24 tickUpper;
      (,,,, tickLower, tickUpper, newLiquidity,,,,) = posManager.positions(posID);
      // tick ranges should match
      if (extraData.tickLower != tickLower || extraData.tickUpper != tickUpper) {
        return false;
      }
    } else {
      // not a new position, only need to verify liquidty increment
      // getting new position liquidity, make sure it is increased
      (,,,,,, newLiquidity,,,,) = posManager.positions(data.zapInfo.posID);
    }
    return newLiquidity >= extraData.minLiquidity + data.initialLiquidity;
  }

  function _validateERC20Result(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    ERC20ValidationData memory data = abi.decode(_validationData, (ERC20ValidationData));
    uint256 minAmountOut = abi.decode(_extraData, (uint256));
    uint256 currentBalance = data.zapInfo.token == ETH_ADDRESS
      ? data.zapInfo.recipient.balance
      : IERC20(data.zapInfo.token).balanceOf(data.zapInfo.recipient);
    return currentBalance >= data.initialBalance + minAmountOut;
  }

  function _validateSolidlyV3Result(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    SolidlyV3ValidationData memory data = abi.decode(_validationData, (SolidlyV3ValidationData));
    bytes32 positionKey = keccak256(
      abi.encodePacked(data.zapInfo.recipient, data.zapInfo.tickLower, data.zapInfo.tickUpper)
    );
    (uint256 newLiquidity,,) = ISolidlyV3Pool(data.zapInfo.pool).positions(positionKey);
    uint256 minLiquidity = abi.decode(_extraData, (uint256));
    return newLiquidity >= minLiquidity + data.initialLiquidity;
  }

  /// @notice Dummy function to validate none action
  function _validateNoneRemoving(bytes memory, bytes memory) internal pure returns (bool) {
    return true;
  }

  /**
   * @notice Validate the position after removing liquidity from Uniswap V3
   * @param _extraData contains the expected liquidity to be removed
   * @param _validationData contains the initial liquidity before removing
   */
  function _validateUniswapV3Removing(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    UniswapV3ValidationData memory data = abi.decode(_validationData, (UniswapV3ValidationData));
    IUniswapv3NFT posManager = IUniswapv3NFT(data.zapInfo.posManager);
    (,,,,,,, uint128 newLiquidity,,,,) = posManager.positions(data.zapInfo.posID);
    (address owner, uint256 expectedRemoval) = abi.decode(_extraData, (address, uint256));
    if (data.initialLiquidity - newLiquidity != expectedRemoval) {
      return false;
    }
    return owner == posManager.ownerOf(data.zapInfo.posID) || newLiquidity == 0;
  }

  /**
   * @notice Validate the position after removing liquidity from Algebra
   * @param _extraData contains the expected liquidity to be removed
   * @param _validationData contains the initial liquidity before removing
   */
  function _validateAlgebraRemoving(
    bytes memory _extraData,
    bytes memory _validationData
  ) internal view returns (bool) {
    UniswapV3ValidationData memory data = abi.decode(_validationData, (UniswapV3ValidationData));
    IAlgebraV19NFT posManager = IAlgebraV19NFT(data.zapInfo.posManager);
    (,,,,,, uint128 newLiquidity,,,,) = posManager.positions(data.zapInfo.posID);
    (address owner, uint256 expectedRemoval) = abi.decode(_extraData, (address, uint256));
    if (data.initialLiquidity - newLiquidity != expectedRemoval) {
      return false;
    }
    return owner == posManager.ownerOf(data.zapInfo.posID) || newLiquidity == 0;
  }

  function _getPrepareDataFunction(
    bytes32 _type
  ) internal pure returns (function(bytes memory ) internal view returns (bytes memory)) {
    if (_type == UNISWAP_V3_TYPE) {
      return _prepareUniswapV3ValidationData;
    } else if (_type == ALGEBRA_V19_TYPE || _type == ALGEBRA_V19_DIRFEE_TYPE) {
      return _prepareAlgebraValidationData;
    } else if (_type == ERC20_TYPE) {
      return _prepareERC20ValidationData;
    } else if (_type == SOLIDLY_V3_TYPE) {
      return _prepareSolidlyV3ValidationData;
    } else {
      return _prepareNoneValidationData;
    }
  }

  function _getValidateResultsFunction(
    bytes32 _type
  ) internal pure returns (function(bytes memory, bytes memory) internal view returns (bool)) {
    if (_type == UNISWAP_V3_TYPE) {
      return _validateUniswapV3Result;
    } else if (_type == ALGEBRA_V19_TYPE || _type == ALGEBRA_V19_DIRFEE_TYPE) {
      return _validateAlgebraResult;
    } else if (_type == ERC20_TYPE) {
      return _validateERC20Result;
    } else if (_type == SOLIDLY_V3_TYPE) {
      return _validateSolidlyV3Result;
    } else {
      return _validateNoneResult;
    }
  }

  function _getValidateRemovingFunction(
    bytes32 _type
  ) internal pure returns (function(bytes memory, bytes memory) internal view returns (bool)) {
    if (_type == UNISWAP_V3_TYPE) {
      return _validateUniswapV3Removing;
    } else if (_type == ALGEBRA_V19_TYPE || _type == ALGEBRA_V19_DIRFEE_TYPE) {
      return _validateAlgebraRemoving;
    } else {
      return _validateNoneRemoving;
    }
  }
}


// File: contracts/interfaces/zap/validators/IKSZapValidatorV2.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

interface IKSZapValidatorV2 {
  function prepareValidationData(
    uint8,
    bytes calldata _zapInfo
  ) external view returns (bytes memory _validationData);

  function validateData(
    uint8,
    bytes calldata _extraData,
    bytes calldata _validationData,
    bytes calldata _zapResults
  ) external view returns (bool);

  struct ZapInfo {
    bytes32 srcType;
    bytes32 dstType;
    bytes srcZapInfo;
    bytes dstZapInfo;
  }

  struct ValidationData {
    bytes32 srcType;
    bytes32 dstType;
    bytes srcValidationData;
    bytes dstValidationData;
  }

  struct ExtraData {
    bytes srcExtraData;
    bytes dstExtraData;
  }

  /// @notice Contains pool, posManage address
  /// posID = 0 -> minting a new position, otherwise increasing to existing one
  struct UniswapV3ZapInfo {
    address pool;
    address posManager;
    uint256 posID;
  }

  /// @notice Return data for validation purpose
  /// In case minting a new position: it calculates the current total supply
  struct UniswapV3ValidationData {
    UniswapV3ZapInfo zapInfo;
    uint256 initialLiquidity;
  }

  /// @notice Extra data to be used for validation after zapping
  struct UniswapV3ExtraData {
    address recipient;
    int24 tickLower;
    int24 tickUpper;
    uint256 minLiquidity;
  }

  /// @notice Validation data for ERC20 token
  struct ERC20ValidationData {
    ERC20ZapInfo zapInfo;
    uint256 initialBalance;
  }

  /// @notice ERC20 token zap info
  struct ERC20ZapInfo {
    address token;
    address recipient;
  }

  /// @notice Solidly V3 Zap Info
  struct SolidlyV3ZapInfo {
    address pool;
    address recipient;
    int24 tickLower;
    int24 tickUpper;
  }

  /// @notice Return Solidly V3 Zap Data, and initial liquidity of the recipient
  struct SolidlyV3ValidationData {
    SolidlyV3ZapInfo zapInfo;
    uint256 initialLiquidity;
  }
}


// File: lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
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


// File: contracts/interfaces/uniswapv3/IUniswapv3NFT.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IUniswapv3NFT {
  function positions(
    uint256 tokenId
  )
    external
    view
    returns (
      uint96 nonce,
      address operator,
      address token0,
      address token1,
      uint24 fee,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    );

  struct MintParams {
    address token0;
    address token1;
    uint24 fee;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
  }

  function mint(
    MintParams calldata params
  ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

  struct IncreaseLiquidityParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  function increaseLiquidity(
    IncreaseLiquidityParams calldata params
  ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

  struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  function decreaseLiquidity(
    DecreaseLiquidityParams calldata params
  ) external payable returns (uint256 amount0, uint256 amount1);

  struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
  }

  function collect(
    CollectParams calldata params
  ) external payable returns (uint256 amount0, uint256 amount1);

  function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;

  function transferFrom(address from, address to, uint256 tokenId) external;

  function safeTransferFrom(address from, address to, uint256 tokenId) external;

  function approve(address spender, uint256 tokenId) external;

  function setApprovalForAll(address operator, bool approved) external;

  function WETH9() external view returns (address);

  function ownerOf(uint256 tokenId) external view returns (address);

  function tokenByIndex(uint256 index) external view returns (uint256);
  function totalSupply() external view returns (uint256);
}


// File: contracts/interfaces/algebrav19/IAlgebraV19NFT.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

interface IAlgebraV19NFT {
  function positions(
    uint256 tokenId
  )
    external
    view
    returns (
      uint96 nonce,
      address operator,
      address token0,
      address token1,
      int24 tickLower,
      int24 tickUpper,
      uint128 liquidity,
      uint256 feeGrowthInside0LastX128,
      uint256 feeGrowthInside1LastX128,
      uint128 tokensOwed0,
      uint128 tokensOwed1
    );

  struct MintParams {
    address token0;
    address token1;
    int24 tickLower;
    int24 tickUpper;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    address recipient;
    uint256 deadline;
  }

  function mint(
    MintParams calldata params
  ) external payable returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);

  struct IncreaseLiquidityParams {
    uint256 tokenId;
    uint256 amount0Desired;
    uint256 amount1Desired;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  function increaseLiquidity(
    IncreaseLiquidityParams calldata params
  ) external payable returns (uint128 liquidity, uint256 amount0, uint256 amount1);

  struct DecreaseLiquidityParams {
    uint256 tokenId;
    uint128 liquidity;
    uint256 amount0Min;
    uint256 amount1Min;
    uint256 deadline;
  }

  function decreaseLiquidity(
    DecreaseLiquidityParams calldata params
  ) external payable returns (uint256 amount0, uint256 amount1);

  struct CollectParams {
    uint256 tokenId;
    address recipient;
    uint128 amount0Max;
    uint128 amount1Max;
  }

  function collect(
    CollectParams calldata params
  ) external payable returns (uint256 amount0, uint256 amount1);

  function sweepToken(address token, uint256 amountMinimum, address recipient) external payable;

  function transferFrom(address from, address to, uint256 tokenId) external;

  function approve(address spender, uint256 tokenId) external;

  function setApprovalForAll(address operator, bool approved) external;

  function WETH9() external view returns (address);

  function ownerOf(uint256 tokenId) external view returns (address);

  function tokenByIndex(uint256 index) external view returns (uint256);
  function totalSupply() external view returns (uint256);
}


// File: contracts/interfaces/zap/common/IZapDexEnum.sol
// SPDX-License-Identifier: MIT
pragma solidity >= 0.8.0;

interface IZapDexEnum {
  // There must be a slot for EMPTY
  enum DexType {
    UniswapV2,
    UniswapV3,
    EMPTY,
    Curve,
    Balancer,
    AlgebraV19,
    AlgebraV19DirFee,
    RamsesV2,
    AerodromeV1,
    RingV2,
    KoiV2,
    SolidlyV3,
    AerodromeCL,
    AlgebraIntegralV12,
    Gamma,
    PancakeV3Staking,
    ArrakisV1,
    ArrakisV2
  }

  enum SrcType {
    ERC20Token,
    ERC721Token,
    ERC1155Token
  }
}


// File: lib/ks-growth-utils-sc/contracts/KSRescueV2.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KSRescue} from '@src/KSRescue.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

abstract contract KSRescueV2 is KSRescue {
  function rescueBatchERC721(
    address token,
    uint256[] calldata _ids,
    address recipient
  ) external onlyOwner {
    require(recipient != address(0), 'KSRescue: invalid recipient');
    for (uint256 i = 0; i < _ids.length; i++) {
      IERC721(token).transferFrom(address(this), recipient, _ids[i]);
    }
  }

  function rescueBatchERC1155(
    address token,
    uint256[] calldata ids,
    uint256[] memory amounts,
    bytes calldata data,
    address recipient
  ) external onlyOwner {
    require(recipient != address(0), 'KSRescue: invalid recipient');
    require(ids.length == amounts.length, 'KSRescue: invalid array length');
    for (uint256 i = 0; i < ids.length; ++i) {
      if (amounts[i] == 0) amounts[i] = IERC1155(token).balanceOf(address(this), ids[i]);
    }
    IERC1155(token).safeBatchTransferFrom(address(this), recipient, ids, amounts, data);
  }
}


// File: contracts/interfaces/solidlyv3/ISolidlyV3Pool.sol
// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.5.0;

interface ISolidlyV3Pool {
  /// @notice The first of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token0() external view returns (address);

  /// @notice The second of the two tokens of the pool, sorted by address
  /// @return The token contract address
  function token1() external view returns (address);

  /// @notice The pool tick spacing
  /// @dev Ticks can only be used at multiples of this value, minimum of 1 and always positive
  /// e.g.: a tickSpacing of 3 means ticks can be initialized every 3rd tick, i.e., ..., -6, -3, 0, 3, 6, ...
  /// This value is an int24 to avoid casting even though it is always positive.
  /// @return The tick spacing
  function tickSpacing() external view returns (int24);

  /// @notice The 0th storage slot in the pool stores many values, and is exposed as a single method to save gas
  /// when accessed externally.
  /// @return sqrtPriceX96 The current price of the pool as a sqrt(token1/token0) Q64.96 value
  /// tick The current tick of the pool, i.e. according to the last tick transition that was run.
  /// This value may not always be equal to SqrtTickMath.getTickAtSqrtRatio(sqrtPriceX96) if the price is on a tick
  /// boundary.
  /// fee The pool's current fee in hundredths of a bip, i.e. 1e-6
  /// unlocked Whether the pool is currently locked to reentrancy
  function slot0()
    external
    view
    returns (uint160 sqrtPriceX96, int24 tick, uint24 fee, bool unlocked);

  /// @notice The currently in range liquidity available to the pool
  /// @dev This value has no relationship to the total liquidity across all ticks
  function liquidity() external view returns (uint128);

  /// @notice Look up information about a specific tick in the pool
  /// @param tick The tick to look up
  /// @return liquidityGross the total amount of position liquidity that uses the pool either as tick lower or
  /// tick upper,
  /// liquidityNet how much liquidity changes when the pool price crosses the tick,
  /// initialized Set to true if the tick is initialized, i.e. liquidityGross is greater than 0, otherwise equal to false.
  /// Outside values can only be used if the tick is initialized, i.e. if liquidityGross is greater than 0.
  /// In addition, these values are only relative and must be used only in comparison to previous snapshots for
  /// a specific position.
  function ticks(
    int24 tick
  ) external view returns (uint128 liquidityGross, int128 liquidityNet, bool initialized);

  /// @notice Returns 256 packed tick initialized boolean values. See TickBitmap for more information
  function tickBitmap(int16 wordPosition) external view returns (uint256);

  /// @notice Returns the information about a position by the position's key
  /// @param key The position's key is a hash of a preimage composed by the owner, tickLower and tickUpper
  /// @return _liquidity The amount of liquidity in the position,
  /// Returns tokensOwed0 the computed amount of token0 owed to the position as of the last mint/burn/poke,
  /// Returns tokensOwed1 the computed amount of token1 owed to the position as of the last mint/burn/poke
  function positions(
    bytes32 key
  ) external view returns (uint128 _liquidity, uint128 tokensOwed0, uint128 tokensOwed1);

  /// @notice Adds liquidity for the given recipient/tickLower/tickUpper position
  /// Uses callback for payments and includes additional slippage/deadline protection
  /// @dev The caller of this method receives a callback in the form of ISolidlyV3MintCallback#solidlyV3MintCallback
  /// in which they must pay any token0 or token1 owed for the liquidity
  /// @param recipient The address for which the liquidity will be created
  /// @param tickLower The lower tick of the position in which to add liquidity
  /// @param tickUpper The upper tick of the position in which to add liquidity
  /// @param amount The amount of liquidity to mint
  /// @param amount0Min The minimum amount of token0 to spend, which serves as a slippage check
  /// @param amount1Min The minimum amount of token1 to spend, which serves as a slippage check
  /// @param deadline A constraint on the time by which the mint transaction must mined
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The amount of token0 that was paid to mint the given amount of liquidity. Matches the value in the callback
  /// @return amount1 The amount of token1 that was paid to mint the given amount of liquidity. Matches the value in the callback
  function mint(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amount,
    uint256 amount0Min,
    uint256 amount1Min,
    uint256 deadline,
    bytes calldata data
  ) external returns (uint256 amount0, uint256 amount1);

  /// @notice Convenience method to burn liquidity and then collect owed tokens in one go
  /// @param recipient The address which should receive the tokens collected
  /// @param tickLower The lower tick of the position for which to collect tokens
  /// @param tickUpper The upper tick of the position for which to collect tokens
  /// @param amountToBurn How much liquidity to burn
  /// @param amount0ToCollect How much token0 should be withdrawn from the tokens owed
  /// @param amount1ToCollect How much token1 should be withdrawn from the tokens owed
  /// @return amount0FromBurn The amount of token0 accrued to the position from the burn
  /// @return amount1FromBurn The amount of token1 accrued to the position from the burn
  /// @return amount0Collected The amount of token0 collected from the positions
  /// @return amount1Collected The amount of token1 collected from the positions
  function burnAndCollect(
    address recipient,
    int24 tickLower,
    int24 tickUpper,
    uint128 amountToBurn,
    uint128 amount0ToCollect,
    uint128 amount1ToCollect
  )
    external
    returns (
      uint256 amount0FromBurn,
      uint256 amount1FromBurn,
      uint128 amount0Collected,
      uint128 amount1Collected
    );

  /// @notice Burn liquidity from the sender and account tokens owed for the liquidity to the position
  /// @dev Tokens must be collected separately via a call to #collect
  /// @param tickLower The lower tick of the position for which to burn liquidity
  /// @param tickUpper The upper tick of the position for which to burn liquidity
  /// @param amount How much liquidity to burn
  /// @return amount0 The amount of token0 sent to the recipient
  /// @return amount1 The amount of token1 sent to the recipient
  function burn(
    int24 tickLower,
    int24 tickUpper,
    uint128 amount
  ) external returns (uint256 amount0, uint256 amount1);

  /// @notice Swap token0 for token1, or token1 for token0
  /// Uses a callback for payments; no additional slippage/deadline protection or referrer tracking
  /// @dev The caller of this method receives a callback in the form of ISolidlyV3MintCallback#solidlyV3SwapCallback
  /// in which they must pay any token0 or token1 owed for the swap
  /// @param recipient The address to receive the output of the swap
  /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to token0
  /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact input (positive), or exact output (negative)
  /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be less than this
  /// value after the swap. If one for zero, the price cannot be greater than this value after the swap
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum when positive
  /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum when positive
  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1);
}


// File: contracts/common/ZapTypeHash.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

abstract contract ZapTypeHash {
  bytes32 public constant NONE_TYPE = keccak256('None');
  bytes32 public constant UNISWAP_V3_TYPE = keccak256('UniswapV3');
  bytes32 public constant ALGEBRA_V19_TYPE = keccak256('AlgebraV19');
  bytes32 public constant ALGEBRA_V19_DIRFEE_TYPE = keccak256('AlgebraV19DirFee');
  bytes32 public constant SOLIDLY_V3_TYPE = keccak256('SolidlyV3');
  bytes32 public constant ERC20_TYPE = keccak256('ERC20');
}


// File: lib/ks-growth-utils-sc/contracts/KSRescue.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KyberSwapRole} from '@src/KyberSwapRole.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';

abstract contract KSRescue is KyberSwapRole {
  using SafeERC20 for IERC20;

  address private constant ETH_ADDRESS = address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

  function rescueFunds(address token, uint256 amount, address recipient) external onlyOwner {
    require(recipient != address(0), 'KSRescue: invalid recipient');
    if (amount == 0) amount = _getAvailableAmount(token);
    if (amount > 0) {
      if (_isETH(token)) {
        (bool success,) = recipient.call{value: amount}('');
        require(success, 'KSRescue: ETH_TRANSFER_FAILED');
      } else {
        IERC20(token).safeTransfer(recipient, amount);
      }
    }
  }

  function _getAvailableAmount(address token) internal view virtual returns (uint256 amount) {
    if (_isETH(token)) {
      amount = address(this).balance;
    } else {
      amount = IERC20(token).balanceOf(address(this));
    }
    if (amount > 0) --amount;
  }

  function _isETH(address token) internal pure returns (bool) {
    return (token == ETH_ADDRESS);
  }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC721 compliant contract.
 */
interface IERC721 is IERC165 {
    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);

    /**
     * @dev Emitted when `owner` enables or disables (`approved`) `operator` to manage all of its assets.
     */
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    /**
     * @dev Returns the number of tokens in ``owner``'s account.
     */
    function balanceOf(address owner) external view returns (uint256 balance);

    /**
     * @dev Returns the owner of the `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Usage of this method is discouraged, use {safeTransferFrom} whenever possible.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @dev Gives permission to `to` to transfer `tokenId` token to another account.
     * The approval is cleared when the token is transferred.
     *
     * Only a single account can be approved at a time, so approving the zero address clears previous approvals.
     *
     * Requirements:
     *
     * - The caller must own the token or be an approved operator.
     * - `tokenId` must exist.
     *
     * Emits an {Approval} event.
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool _approved) external;

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must be approved to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes calldata data
    ) external;
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155 is IERC165 {
    /**
     * @dev Emitted when `value` tokens of token type `id` are transferred from `from` to `to` by `operator`.
     */
    event TransferSingle(address indexed operator, address indexed from, address indexed to, uint256 id, uint256 value);

    /**
     * @dev Equivalent to multiple {TransferSingle} events, where `operator`, `from` and `to` are the same for all
     * transfers.
     */
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );

    /**
     * @dev Emitted when `account` grants or revokes permission to `operator` to transfer their tokens, according to
     * `approved`.
     */
    event ApprovalForAll(address indexed account, address indexed operator, bool approved);

    /**
     * @dev Emitted when the URI for token type `id` changes to `value`, if it is a non-programmatic URI.
     *
     * If an {URI} event was emitted for `id`, the standard
     * https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[guarantees] that `value` will equal the value
     * returned by {IERC1155MetadataURI-uri}.
     */
    event URI(string value, uint256 indexed id);

    /**
     * @dev Returns the amount of tokens of token type `id` owned by `account`.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) external view returns (uint256);

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {balanceOf}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids)
        external
        view
        returns (uint256[] memory);

    /**
     * @dev Grants or revokes permission to `operator` to transfer the caller's tokens, according to `approved`,
     *
     * Emits an {ApprovalForAll} event.
     *
     * Requirements:
     *
     * - `operator` cannot be the caller.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns true if `operator` is approved to transfer ``account``'s tokens.
     *
     * See {setApprovalForAll}.
     */
    function isApprovedForAll(address account, address operator) external view returns (bool);

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If the caller is not `from`, it must be have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;
}


// File: lib/ks-growth-utils-sc/contracts/KyberSwapRole.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {Pausable} from '@openzeppelin/contracts/security/Pausable.sol';

abstract contract KyberSwapRole is Ownable, Pausable {
  mapping(address => bool) public operators;
  mapping(address => bool) public guardians;

  /**
   * @dev Emitted when the an user was grant or revoke operator role.
   */
  event UpdateOperator(address user, bool grantOrRevoke);

  /**
   * @dev Emitted when the an user was grant or revoke guardian role.
   */
  event UpdateGuardian(address user, bool grantOrRevoke);

  /**
   * @dev Modifier to make a function callable only when caller is operator.
   *
   * Requirements:
   *
   * - Caller must have operator role.
   */
  modifier onlyOperator() {
    require(operators[msg.sender], 'KyberSwapRole: not operator');
    _;
  }

  /**
   * @dev Modifier to make a function callable only when caller is guardian.
   *
   * Requirements:
   *
   * - Caller must have guardian role.
   */
  modifier onlyGuardian() {
    require(guardians[msg.sender], 'KyberSwapRole: not guardian');
    _;
  }

  /**
   * @dev Update Operator role for user.
   * Can only be called by the current owner.
   */
  function updateOperator(address user, bool grantOrRevoke) external onlyOwner {
    operators[user] = grantOrRevoke;
    emit UpdateOperator(user, grantOrRevoke);
  }

  /**
   * @dev Update Guardian role for user.
   * Can only be called by the current owner.
   */
  function updateGuardian(address user, bool grantOrRevoke) external onlyOwner {
    guardians[user] = grantOrRevoke;
    emit UpdateGuardian(user, grantOrRevoke);
  }

  /**
   * @dev Enable logic for contract.
   * Can only be called by the current owner.
   */
  function enableLogic() external onlyOwner {
    _unpause();
  }

  /**
   * @dev Disable logic for contract.
   * Can only be called by the guardians.
   */
  function disableLogic() external onlyGuardian {
    _pause();
  }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

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
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../../../utils/Address.sol";

/**
 * @title SafeERC20
 * @dev Wrappers around ERC20 operations that throw on failure (when the token
 * contract returns false). Tokens that return no value (and instead revert or
 * throw on failure) are also supported, non-reverting calls are assumed to be
 * successful.
 * To use this library you can add a `using SafeERC20 for IERC20;` statement to your contract,
 * which allows you to call the safe operations as `token.safeTransfer(...)`, etc.
 */
library SafeERC20 {
    using Address for address;

    function safeTransfer(
        IERC20 token,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    function safeTransferFrom(
        IERC20 token,
        address from,
        address to,
        uint256 value
    ) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    function safeIncreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        uint256 newAllowance = token.allowance(address(this), spender) + value;
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
    }

    function safeDecreaseAllowance(
        IERC20 token,
        address spender,
        uint256 value
    ) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            uint256 newAllowance = oldAllowance - value;
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, newAllowance));
        }
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address.functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        if (returndata.length > 0) {
            // Return data is optional
            require(abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
        }
    }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC165 standard, as defined in the
 * https://eips.ethereum.org/EIPS/eip-165[EIP].
 *
 * Implementers can declare support of contract interfaces, which can then be
 * queried by others ({ERC165Checker}).
 *
 * For an implementation, see {ERC165}.
 */
interface IERC165 {
    /**
     * @dev Returns true if this contract implements the interface defined by
     * `interfaceId`. See the corresponding
     * https://eips.ethereum.org/EIPS/eip-165#how-interfaces-are-identified[EIP section]
     * to learn more about how these ids are created.
     *
     * This function call must use less than 30 000 gas.
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/access/Ownable.sol
// SPDX-License-Identifier: MIT

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
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/security/Pausable.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "../utils/Context.sol";

/**
 * @dev Contract module which allows children to implement an emergency stop
 * mechanism that can be triggered by an authorized account.
 *
 * This module is used through inheritance. It will make available the
 * modifiers `whenNotPaused` and `whenPaused`, which can be applied to
 * the functions of your contract. Note that they will not be pausable by
 * simply including this module, only once the modifiers are put in place.
 */
abstract contract Pausable is Context {
    /**
     * @dev Emitted when the pause is triggered by `account`.
     */
    event Paused(address account);

    /**
     * @dev Emitted when the pause is lifted by `account`.
     */
    event Unpaused(address account);

    bool private _paused;

    /**
     * @dev Initializes the contract in unpaused state.
     */
    constructor() {
        _paused = false;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        require(!paused(), "Pausable: paused");
        _;
    }

    /**
     * @dev Modifier to make a function callable only when the contract is paused.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    modifier whenPaused() {
        require(paused(), "Pausable: not paused");
        _;
    }

    /**
     * @dev Triggers stopped state.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    function _pause() internal virtual whenNotPaused {
        _paused = true;
        emit Paused(_msgSender());
    }

    /**
     * @dev Returns to normal state.
     *
     * Requirements:
     *
     * - The contract must be paused.
     */
    function _unpause() internal virtual whenPaused {
        _paused = false;
        emit Unpaused(_msgSender());
    }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

/**
 * @dev Collection of functions related to the address type
 */
library Address {
    /**
     * @dev Returns true if `account` is a contract.
     *
     * [IMPORTANT]
     * ====
     * It is unsafe to assume that an address for which this function returns
     * false is an externally-owned account (EOA) and not a contract.
     *
     * Among others, `isContract` will return false for the following
     * types of addresses:
     *
     *  - an externally-owned account
     *  - a contract in construction
     *  - an address where a contract will be created
     *  - an address where a contract lived, but was destroyed
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    /**
     * @dev Replacement for Solidity's `transfer`: sends `amount` wei to
     * `recipient`, forwarding all available gas and reverting on errors.
     *
     * https://eips.ethereum.org/EIPS/eip-1884[EIP1884] increases the gas cost
     * of certain opcodes, possibly making contracts go over the 2300 gas limit
     * imposed by `transfer`, making them unable to receive funds via
     * `transfer`. {sendValue} removes this limitation.
     *
     * https://diligence.consensys.net/posts/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.5.11/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    /**
     * @dev Performs a Solidity function call using a low level `call`. A
     * plain `call` is an unsafe replacement for a function call: use this
     * function instead.
     *
     * If `target` reverts with a revert reason, it is bubbled up by this
     * function (like regular Solidity function calls).
     *
     * Returns the raw returned data. To convert to the expected return value,
     * use https://solidity.readthedocs.io/en/latest/units-and-global-variables.html?highlight=abi.decode#abi-encoding-and-decoding-functions[`abi.decode`].
     *
     * Requirements:
     *
     * - `target` must be a contract.
     * - calling `target` with `data` must not revert.
     *
     * _Available since v3.1._
     */
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`], but with
     * `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but also transferring `value` wei to `target`.
     *
     * Requirements:
     *
     * - the calling contract must have an ETH balance of at least `value`.
     * - the called Solidity function must be `payable`.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    /**
     * @dev Same as {xref-Address-functionCallWithValue-address-bytes-uint256-}[`functionCallWithValue`], but
     * with `errorMessage` as a fallback revert reason when `target` reverts.
     *
     * _Available since v3.1._
     */
    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a static call.
     *
     * _Available since v3.3._
     */
    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    /**
     * @dev Same as {xref-Address-functionCall-address-bytes-string-}[`functionCall`],
     * but performing a delegate call.
     *
     * _Available since v3.4._
     */
    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResult(success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verifies that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason using the provided one.
     *
     * _Available since v4.3._
     */
    function verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}


// File: lib/ks-growth-utils-sc/lib/openzeppelin-contracts/contracts/utils/Context.sol
// SPDX-License-Identifier: MIT

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


