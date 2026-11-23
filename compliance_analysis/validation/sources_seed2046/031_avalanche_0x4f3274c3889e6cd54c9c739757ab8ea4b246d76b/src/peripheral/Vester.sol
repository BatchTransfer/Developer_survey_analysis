// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { GlobalACL } from "../Auth.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { AggregateVault } from "src/vaults/AggregateVault.sol";

uint256 constant PRECISION = 1e18;

/// @title Vester
/// @author Umami Devs
/// @notice Vester contract to vest deposit and withdraw fee surplus into the aggregate vault
contract Vester is GlobalACL {
    using SafeTransferLib for ERC20;

    event SetVestDuration(uint256 previousVestDuration, uint256 newVestDuration);
    event Claimed(address indexed token, uint256 amount);
    event AddVest(address indexed token, uint256 amount);

    error VestingPerSecondTooLow();

    address public immutable aggregateVault;

    struct VestingInfo {
        uint256 vestingPerSecond;
        uint256 lastClaim;
    }

    mapping(address => VestingInfo) public vestingInfo;
    uint256 public vestDuration;

    constructor(AggregateVault _aggregateVault, uint256 _vestDuration) GlobalACL(_aggregateVault.AUTH()) {
        aggregateVault = address(_aggregateVault);
        _setVestDuration(_vestDuration);
    }

    /**
     * @notice Set the vest duration
     * @param _vestDuration The new vest duration
     */
    function setVestDuration(uint256 _vestDuration) external onlyConfigurator {
        _setVestDuration(_vestDuration);
    }

    /**
     * @notice Claim vested tokens into aggregate vault
     * @param _asset The asset to claim
     */
    function claim(address _asset) public returns (uint256) {
        uint256 _vested = vested(_asset);
        if (_vested == 0) return 0;

        vestingInfo[_asset].lastClaim = block.timestamp;
        emit Claimed(_asset, _vested);

        ERC20(_asset).safeTransfer(aggregateVault, _vested);
        return _vested;
    }

    /**
     * @notice Add new vesting tokens
     * @param _asset The asset to vest
     * @param _amount The amount to vest
     */
    function addVest(address _asset, uint256 _amount) external {
        claim(_asset);

        emit AddVest(_asset, _amount);
        ERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 currentBalance = ERC20(_asset).balanceOf(address(this));

        uint256 vestingPerSecond = currentBalance * PRECISION / vestDuration;
        if (vestingPerSecond == 0) revert VestingPerSecondTooLow();

        vestingInfo[_asset] = VestingInfo({ vestingPerSecond: vestingPerSecond, lastClaim: block.timestamp });
    }

    /**
     * Get vested amount of an asset
     * @param _asset The asset to get vested amount of
     * @return The vested amount
     */
    function vested(address _asset) public view returns (uint256) {
        uint256 duration = block.timestamp - vestingInfo[_asset].lastClaim;
        uint256 totalVested = duration * vestingInfo[_asset].vestingPerSecond / PRECISION;
        uint256 totalBalance = ERC20(_asset).balanceOf(address(this));
        return totalVested > totalBalance ? totalBalance : totalVested;
    }

    function _setVestDuration(uint256 _newVestDuration) internal {
        uint256 previousVestDuration = vestDuration;
        vestDuration = _newVestDuration;
        emit SetVestDuration(previousVestDuration, _newVestDuration);
    }
}
