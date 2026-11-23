// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { BaseVault } from "./BaseVault.sol";
import { ERC20 } from "solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "solmate/utils/SafeTransferLib.sol";
import { ReentrancyGuard } from "solmate/utils/ReentrancyGuard.sol";
import { ShareMath } from "../libraries/ShareMath.sol";

import { GlobalACL, REQUEST_HANDLER, AGGREGATE_VAULT_ROLE } from "../Auth.sol";
import { PausableVault } from "../PausableVault.sol";
import { AggregateVault } from "./AggregateVault.sol";
import { AggregateVaultStorage } from "../storage/AggregateVaultStorage.sol";

/// @title AssetVault
/// @author Umami DAO
/// @notice ERC4626-like implementation for vault receipt tokens
contract AssetVault is BaseVault, PausableVault, GlobalACL, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    /// @dev the aggregate vault for the strategy
    AggregateVault public aggregateVault;

    constructor(ERC20 _asset, string memory _name, string memory _symbol, address _aggregateVault)
        BaseVault(_asset, _name, _symbol)
        GlobalACL(AggregateVault(payable(_aggregateVault)).AUTH())
    {
        aggregateVault = AggregateVault(payable(_aggregateVault));
    }

    // DEPOSIT & WITHDRAW
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Deposit a specified amount of assets and mint corresponding shares to the receiver
     * @param assets The amount of assets to deposit
     * @param minOutAfterFees Minimum amount out after fees
     * @param receiver The address to receive the minted shares
     * @return shares The estimate amount of shares minted for the deposited assets
     */
    function deposit(uint256 assets, uint256 minOutAfterFees, address receiver)
        public
        payable
        override
        whenDepositNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        require(
            totalAssets() + assets <= previewVaultCap() + asset.balanceOf(address(this)), "AssetVault: over vault cap"
        );
        // Transfer assets to aggregate vault, transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);
        aggregateVault.handleDeposit{ value: msg.value }(assets, minOutAfterFees, receiver, msg.sender, address(0));

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Redeem a specified amount of shares by burning them and transferring the corresponding amount of assets to the receiver
     * @param shares The amount of shares to redeem
     * @param minOutAfterFees Minimum amount out after fees
     * @param receiver The address to receive the corresponding assets
     * @param owner The address of the share owner
     * @return assets The estimate amount of assets transferred for the redeemed shares
     */
    function redeem(uint256 shares, uint256 minOutAfterFees, address receiver, address owner)
        public
        payable
        override
        whenWithdrawalNotPaused
        nonReentrant
        returns (uint256 assets)
    {
        require(shares > 0, "AssetVault: !shares > 0");
        assets = totalSupply == 0 ? shares : ShareMath.sharesToAsset(shares, pps(), decimals);
        if (msg.sender != owner) _checkAllowance(owner, shares);
        require(assets <= asset.balanceOf(address(aggregateVault)), "AssetVault: assets not available");

        // Check for rounding error since we round down in previewRedeem.
        require(previewRedeem(shares) != 0, "ZERO_ASSETS");

        // transfer shares in
        ERC20(address(this)).safeTransferFrom(owner, address(this), shares);

        // handle withdraw
        aggregateVault.handleWithdraw{ value: msg.value }(shares, minOutAfterFees, receiver, msg.sender, address(0));

        emit Withdraw(owner, receiver, owner, assets, shares);
    }

    // WITH CALLBACKS
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Deposit a specified amount of assets and mint corresponding shares to the receiver
     * @param assets The amount of assets to deposit
     * @param minOutAfterFees Minimum amount out after fees
     * @param receiver The address to receive the minted shares
     * @param callback The address to callback to after execution
     * @return shares The estimate amount of shares minted for the deposited assets
     */
    function depositWithCallback(uint256 assets, uint256 minOutAfterFees, address receiver, address callback)
        public
        payable
        whenDepositNotPaused
        nonReentrant
        returns (uint256 shares)
    {
        // Check for rounding error since we round down in previewDeposit.
        require((shares = previewDeposit(assets)) != 0, "ZERO_SHARES");
        require(
            totalAssets() + assets <= previewVaultCap() + asset.balanceOf(address(this)), "AssetVault: over vault cap"
        );
        // Transfer assets to aggregate vault, transfer before minting or ERC777s could reenter.
        asset.safeTransferFrom(msg.sender, address(this), assets);
        aggregateVault.handleDeposit{ value: msg.value }(assets, minOutAfterFees, receiver, msg.sender, callback);
        emit Deposit(msg.sender, receiver, assets, shares);
    }

    /**
     * @notice Redeem a specified amount of shares by burning them and transferring the corresponding amount of assets to the receiver
     * @param shares The amount of shares to redeem
     * @param minOutAfterFees Minimum amount out after fees
     * @param receiver The address to receive the corresponding assets
     * @param owner The address of the share owner
     * @param callback The address to callback to after execution
     * @return assets The estimate amount of assets transferred for the redeemed shares
     */
    function redeemWithCallback(
        uint256 shares,
        uint256 minOutAfterFees,
        address receiver,
        address owner,
        address callback
    ) public payable whenWithdrawalNotPaused nonReentrant returns (uint256 assets) {
        require(shares > 0, "AssetVault: !shares > 0");
        assets = totalSupply == 0 ? shares : ShareMath.sharesToAsset(shares, pps(), decimals);

        if (msg.sender != owner) _checkAllowance(owner, shares);

        // Check for rounding error since we round down in previewRedeem.
        require(previewRedeem(shares) != 0, "ZERO_ASSETS");

        // transfer shares in
        ERC20(address(this)).safeTransferFrom(owner, address(this), shares);

        // handle withdrawal
        aggregateVault.handleWithdraw{ value: msg.value }(shares, minOutAfterFees, receiver, msg.sender, callback);

        emit Withdraw(owner, receiver, owner, assets, shares);
    }

    /**
     * @notice Cancels a vault request for this vault
     * @param key The request key to cancel
     */
    function cancelRequest(uint256 key) external {
        AggregateVaultStorage.OCRequest memory request = aggregateVault.getRequest(key);
        require(request.vault == address(this), "AssetVault: invalid vault");
        require(request.sender == msg.sender, "AssetVault: invalid account");

        if (request.isDeposit) {
            asset.safeTransfer(msg.sender, request.amount);
        } else {
            ERC20(address(this)).safeTransfer(msg.sender, request.amount);
        }

        aggregateVault.clearRequest(key);
    }

    // MATH
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Get the total value locked (TVL) of the vault
     * @return totalValueLocked The current total value locked
     */
    function totalAssets() public view override returns (uint256 totalValueLocked) {
        (bool success, bytes memory ret) =
            address(aggregateVault).staticcall(abi.encodeCall(AggregateVault.getVaultTVL, (address(this), false)));

        // bubble up error message
        if (!success) {
            assembly {
                let length := mload(ret)
                revert(add(32, ret), length)
            }
        }
        totalValueLocked = abi.decode(ret, (uint256));
    }

    /**
     * @notice Get the price per share (PPS) of the vault
     * @return pricePerShare The current price per share
     */
    function pps() public view returns (uint256 pricePerShare) {
        (bool success, bytes memory ret) =
            address(aggregateVault).staticcall(abi.encodeCall(AggregateVault.getVaultPPS, (address(this), true, false)));

        // bubble up error message
        if (!success) {
            assembly {
                let length := mload(ret)
                revert(add(32, ret), length)
            }
        }

        pricePerShare = abi.decode(ret, (uint256));
    }

    /**
     * @notice Convert a specified amount of assets to shares
     * @param assets The amount of assets to convert
     * @return - The amount of shares corresponding to the given assets
     */
    function convertToShares(uint256 assets) public view override returns (uint256) {
        return totalSupply == 0 ? assets : ShareMath.assetToShares(assets, pps(), decimals);
    }

    /**
     * @notice Convert a specified amount of shares to assets
     * @param shares The amount of shares to convert
     * @return - The amount of assets corresponding to the given shares
     */
    function convertToAssets(uint256 shares) public view override returns (uint256) {
        return totalSupply == 0 ? shares : ShareMath.sharesToAsset(shares, pps(), decimals);
    }

    /**
     * @notice Preview the amount of shares for a given deposit amount
     * @param assets The amount of assets to deposit
     * @return - The amount of shares for the given deposit amount
     */
    function previewDeposit(uint256 assets) public view override returns (uint256) {
        uint256 assetFee = previewDepositFee(assets);
        if (assetFee >= assets) return 0;
        return convertToShares(assets - assetFee);
    }

    /**
     * @notice Preview the amount of assets for a given redeem amount
     * @param shares The amount of shares to redeem
     * @return The amount of assets for the given redeem amount
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        uint256 assets = ShareMath.sharesToAsset(shares, pps(), decimals);
        uint256 assetFee = previewWithdrawalFee(assets);
        if (assetFee >= assets) return 0;
        return assets - assetFee;
    }

    // DEPOSIT & WITHDRAW LIMIT
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Get the maximum deposit amount for an address
     * @dev _address The address to check the maximum deposit amount for
     * @dev returns the maximum deposit amount for the given address
     */
    function maxDeposit(address) public view override returns (uint256) {
        uint256 cap = previewVaultCap();
        uint256 tvl_ = totalAssets();
        return cap > tvl_ ? cap - tvl_ : 0;
    }

    /**
     * @notice Get the maximum mint amount for an address
     */
    function maxMint(address) public view override returns (uint256) {
        uint256 cap = previewVaultCap();
        uint256 tvl_ = totalAssets();
        return cap > tvl_ ? convertToShares(cap - tvl_) : 0;
    }

    /**
     * @notice Get the maximum withdrawal amount for an address
     * @param owner The address to check the maximum withdrawal amount for
     * @return The maximum withdrawal amount for the given address
     */
    function maxWithdraw(address owner) public view override returns (uint256) {
        uint256 aggBalance = asset.balanceOf(address(aggregateVault));
        uint256 userMaxAssets = convertToAssets(balanceOf[owner]);
        return aggBalance > userMaxAssets ? userMaxAssets : aggBalance;
    }

    /**
     * @notice Get the maximum redeem amount for an address
     * @param owner The address to check the maximum redeem amount for
     * @return - The maximum redeem amount for the given address
     */
    function maxRedeem(address owner) public view override returns (uint256) {
        uint256 aggBalance = convertToShares(asset.balanceOf(address(aggregateVault)));
        return aggBalance > balanceOf[owner] ? balanceOf[owner] : aggBalance;
    }

    // UTILS
    // ------------------------------------------------------------------------------------------

    /**
     * @notice Pause deposit and withdrawal operations
     */
    function pauseDepositWithdraw() external onlyAggregateVault {
        _pause();
    }

    /**
     * @notice Unpause deposit and withdrawal operations
     */
    function unpauseDepositWithdraw() external onlyAggregateVault {
        _unpause();
    }

    /**
     * @notice Pause deposits operations
     */
    function pauseDeposits() external onlyConfigurator {
        _pauseDeposit();
    }

    /**
     * @notice Unpause deposit operations
     */
    function unpauseDeposits() external onlyConfigurator {
        _unpauseDeposit();
    }

    /**
     * @notice Pause withdrawal operations
     */
    function pauseWithdrawals() external onlyConfigurator {
        _pauseWithdrawal();
    }

    /**
     * @notice Unpause withdrawal operations
     */
    function unpauseWithdrawals() external onlyConfigurator {
        _unpauseWithdrawal();
    }

    /**
     * @notice Update the aggregate vault to a new instance
     * @param _newAggregateVault The new aggregate vault instance to update to
     */
    function updateAggregateVault(AggregateVault _newAggregateVault) external onlyConfigurator {
        aggregateVault = _newAggregateVault;
    }

    /**
     * @notice Mint a specified amount of shares to an address
     * @param _mintAmount The amount of shares to mint
     * @param _toAddress The address to mint
     */
    function mintTo(uint256 _mintAmount, address _toAddress) external validateMintCallAuth(_toAddress) {
        _mint(_toAddress, _mintAmount);
    }

    /**
     * @notice Burn tokens during order execution
     * @param _burnAmount The amount of shares to burn
     */
    function burnShares(uint256 _burnAmount) external onlyRequestHandler {
        _burn(address(this), _burnAmount);
    }

    /**
     * @notice Lodge the underlying assets for a deposit execution
     * @param _assetAmount The amount of assets to lodge
     */
    function lodgeAssets(uint256 _assetAmount, address feeReciever, uint256 _depositFees) external onlyRequestHandler {
        asset.safeTransfer(address(aggregateVault), _assetAmount);
        if (_depositFees > 0 && feeReciever != address(0)) asset.safeTransfer(feeReciever, _depositFees);
    }

    /**
     * @notice Return deposited assets
     */
    function returnAssets(address _to, uint256 _amt) external onlyRequestHandler {
        asset.safeTransfer(_to, _amt);
    }

    /**
     * @notice Return withdraw request shares
     */
    function returnShares(address _to, uint256 _amt) external onlyRequestHandler {
        ERC20(address(this)).safeTransfer(_to, _amt);
    }

    /**
     * @notice Preview the deposit fee for a specified amount of assets
     * @param size The amount of assets to preview the deposit fee for
     * @return totalDepositFee The total deposit fee for the specified amount of assets
     */
    function previewDepositFee(uint256 size) public view returns (uint256 totalDepositFee) {
        (bool success, bytes memory ret) = address(aggregateVault).staticcall(
            abi.encodeCall(AggregateVault.previewDepositFee, (address(asset), size, false))
        );
        if (!success) {
            assembly {
                let length := mload(ret)
                revert(add(32, ret), length)
            }
        }
        totalDepositFee = abi.decode(ret, (uint256));
    }

    /**
     * @notice Preview the withdrawal fee for a specified amount of assets
     * @param size The amount of assets to preview the withdrawal fee for
     * @return totalWithdrawalFee The total withdrawal fee for the specified amount of assets
     */
    function previewWithdrawalFee(uint256 size) public view returns (uint256 totalWithdrawalFee) {
        (bool success, bytes memory ret) = address(aggregateVault).staticcall(
            abi.encodeCall(AggregateVault.previewWithdrawalFee, (address(asset), size, false))
        );
        if (!success) {
            assembly {
                let length := mload(ret)
                revert(add(32, ret), length)
            }
        }
        totalWithdrawalFee = abi.decode(ret, (uint256));
    }

    /**
     * @notice Preview the deposit cap for the vault
     * @return - The current deposit cap for the vault
     */
    function previewVaultCap() public view returns (uint256) {
        return aggregateVault.previewVaultCap(address(asset));
    }

    /**
     * @dev Check the owners spend allowance
     */
    function _checkAllowance(address owner, uint256 shares) internal {
        uint256 allowed = allowance[owner][msg.sender]; // Saves gas for limited approvals.
        if (allowed != type(uint256).max) allowance[owner][msg.sender] = allowed - shares;
    }

    /// @dev validate the mint call
    modifier validateMintCallAuth(address _mintTo) {
        require(
            (_mintTo == aggregateVault.getVaultTimelockAddress(address(asset)) && address(aggregateVault) == msg.sender)
                || AUTH.hasRole(REQUEST_HANDLER, msg.sender),
            "AssetVault: !validateMintCallAuth"
        );
        _;
    }
}
