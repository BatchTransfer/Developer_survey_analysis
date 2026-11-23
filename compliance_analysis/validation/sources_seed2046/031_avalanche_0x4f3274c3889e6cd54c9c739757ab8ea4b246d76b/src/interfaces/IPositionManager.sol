// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import { IHandlerContract } from "./IHandlerContract.sol";

interface IPositionManager is IHandlerContract {
    function positionNotional(address _indexToken) external view returns (uint256, bool);

    function positionMargin(address _indexToken) external view returns (uint256, bool);
}
