// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ===================== AgoraDollarErc1967Proxy ======================
// ====================================================================

import { Proxy } from "@openzeppelin/contracts/proxy/Proxy.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";

import { AgoraDollar } from "../AgoraDollar.sol";
import { AgoraDollarCore } from "../AgoraDollarCore.sol";
import { Eip3009, Eip712 } from "../Eip3009.sol";
import { AgoraProxyAdmin } from "./AgoraProxyAdmin.sol";

import { StorageLib } from "./StorageLib.sol";

import { ITransparentUpgradeableProxy } from "../interfaces/ITransparentUpgradeableProxy.sol";

struct ConstructorParams {
    address newImplementation;
    address proxyAdminOwnerAddress;
    string eip712Name;
    string eip712Version;
}

contract AgoraDollarErc1967Proxy is Eip3009, Proxy {
    using SafeCastLib for uint256;
    using StorageLib for uint256;

    address private immutable PROXY_ADMIN_ADDRESS;

    constructor(ConstructorParams memory _params) payable Eip712(_params.eip712Name, _params.eip712Version) {
        // Effects: Set the proxy admin address
        PROXY_ADMIN_ADDRESS = address(new AgoraProxyAdmin({ _initialOwner: _params.proxyAdminOwnerAddress }));
        StorageLib.getPointerToAgoraDollarErc1967ProxyAdminStorage().proxyAdminAddress = PROXY_ADMIN_ADDRESS;

        // Emit event
        emit AdminChanged({ previousAdmin: address(0), newAdmin: PROXY_ADMIN_ADDRESS });

        // Generate calldata for initialization
        AgoraDollar.InitializeParams memory _initializeParams = AgoraDollarCore.InitializeParams({
            initialAdminAddress: _params.proxyAdminOwnerAddress
        });
        bytes memory _initializeCalldata = abi.encodeWithSelector(
            AgoraDollarCore.initialize.selector,
            _initializeParams
        );

        _upgradeToAndCall({ _newImplementation: _params.newImplementation, _callData: _initializeCalldata });
    }

    fallback() external payable override {
        _fallback();
    }

    //==============================================================================
    // Proxy Functions
    //==============================================================================

    function _implementation() internal view override returns (address _implementationAddress) {
        _implementationAddress = StorageLib.sloadImplementationSlotDataAsUint256().implementation();
    }

    function _fallback() internal override {
        if (msg.sender == PROXY_ADMIN_ADDRESS) {
            if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            } else {
                (address _newImplementation, bytes memory _callData) = abi.decode(msg.data[4:], (address, bytes));
                _upgradeToAndCall({ _newImplementation: _newImplementation, _callData: _callData });
            }
        } else {
            super._fallback();
        }
    }

    /// @notice The ```_upgradeToAndCall``` function is an internal implementation which sets the new implementation address and calls the new implementation with the given data.
    /// @param _newImplementation The address of the new implementation.
    /// @param _callData The call data using the new implementation as a target.
    function _upgradeToAndCall(address _newImplementation, bytes memory _callData) internal {
        // Checks: Ensure the new implementation is a contract
        if (_newImplementation.code.length == 0) revert ImplementationTargetNotAContract();

        // Effects: Write the storage value for new implementation
        StorageLib.AgoraDollarErc1967ProxyContractStorage storage contractData = StorageLib
            .getPointerToAgoraDollarErc1967ProxyContractStorage();
        contractData.implementationAddress = _newImplementation;

        // Emit event
        emit Upgraded({ implementation: _newImplementation });

        // Execute calldata for new implementation
        if (_callData.length > 0) Address.functionDelegateCall({ target: _newImplementation, data: _callData });
        else if (msg.value > 0) revert AgoraDollarErc1967NonPayable();
    }

    //==============================================================================
    // Erc20 Functions
    //==============================================================================

    function transfer(address _to, uint256 _transferValue) external returns (bool) {
        // Get data from implementation slot as a uint256
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();

        bool _isTransferUpgraded = _contractData.isTransferUpgraded();
        if (_isTransferUpgraded) {
            // new implementation address is stored in the least significant 160 bits of the contract data
            address _newImplementation = address(uint160(_contractData));
            _delegate({ implementation: _newImplementation });
        } else {
            // Effects: Transfer the tokens
            _transfer({ _from: msg.sender, _to: _to, _transferValue: _transferValue.toUint248() });
            return true;
        }
    }

    function transferFrom(address _from, address _to, uint256 _transferValue) external returns (bool) {
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        bool _isTransferFromUpgraded = _contractData.isTransferFromUpgraded();
        if (_isTransferFromUpgraded) {
            // new implementation address is stored in the least significant 160 bits of the contract data
            address _newImplementation = address(uint160(_contractData));
            _delegate({ implementation: _newImplementation });
        } else {
            // Reading account data for sender adds gas so we should only do it if set true
            bool _isMsgSenderFrozenCheckEnabled = _contractData.isMsgSenderFrozenCheckEnabled();
            if (
                _isMsgSenderFrozenCheckEnabled &&
                StorageLib.getPointerToErc20CoreStorage().accountData[msg.sender].isFrozen
            ) revert AccountIsFrozen({ frozenAccount: msg.sender });

            // Effects: Decrease the allowance of the spender
            _spendAllowance({ _owner: _from, _spender: msg.sender, _value: _transferValue });

            // Effects: Transfer the tokens
            _transfer({ _from: _from, _to: _to, _transferValue: _transferValue.toUint248() });
            return true;
        }
    }

    //==============================================================================
    // Eip-3009 Overriden Functions
    //==============================================================================

    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Packs signature pieces into bytes
        transferWithAuthorization({
            _from: _from,
            _to: _to,
            _value: _value,
            _validAfter: _validAfter,
            _validBefore: _validBefore,
            _nonce: _nonce,
            _signature: abi.encodePacked(_r, _s, _v)
        });
    }

    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) public {
        // Get data from implementation slot as a uint256
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();

        bool _isTransferWithAuthorizationUpgraded = _contractData.isTransferWithAuthorizationUpgraded();
        if (_isTransferWithAuthorizationUpgraded) {
            // new implementation address is stored in the least significant 160 bits of the contract data
            address _newImplementation = address(uint160(_contractData));
            _delegate({ implementation: _newImplementation });
        } else {
            // Reading account data for sender adds gas so we should only do it if set true
            bool _isMsgSenderFrozenCheckEnabled = _contractData.isMsgSenderFrozenCheckEnabled();
            if (
                _isMsgSenderFrozenCheckEnabled &&
                StorageLib.getPointerToErc20CoreStorage().accountData[msg.sender].isFrozen
            ) revert AccountIsFrozen({ frozenAccount: msg.sender });

            // Effects: transfer the tokens
            _transferWithAuthorization({
                _from: _from,
                _to: _to,
                _value: _value,
                _validAfter: _validAfter,
                _validBefore: _validBefore,
                _nonce: _nonce,
                _signature: _signature
            });
        }
    }

    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // Packs signature pieces into bytes
        receiveWithAuthorization({
            _from: _from,
            _to: _to,
            _value: _value,
            _validAfter: _validAfter,
            _validBefore: _validBefore,
            _nonce: _nonce,
            _signature: abi.encodePacked(_r, _s, _v)
        });
    }

    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) public {
        // Get data from implementation slot as a uint256
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();

        bool _isReceiveWithAuthorizationUpgraded = _contractData.isReceiveWithAuthorizationUpgraded();
        if (_isReceiveWithAuthorizationUpgraded) {
            // new implementation address is stored in the least significant 160 bits of the contract data
            address _newImplementation = address(uint160(_contractData));
            _delegate({ implementation: _newImplementation });
        } else {
            // Reading account data for sender adds gas so we should only do it if set true
            bool _isMsgSenderFrozenCheckEnabled = _contractData.isMsgSenderFrozenCheckEnabled();
            if (
                _isMsgSenderFrozenCheckEnabled &&
                StorageLib.getPointerToErc20CoreStorage().accountData[msg.sender].isFrozen
            ) revert AccountIsFrozen({ frozenAccount: msg.sender });

            // Effects: transfer the tokens
            _receiveWithAuthorization({
                _from: _from,
                _to: _to,
                _value: _value,
                _validAfter: _validAfter,
                _validBefore: _validBefore,
                _nonce: _nonce,
                _signature: _signature
            });
        }
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @dev Emitted when the implementation is upgraded.
    event Upgraded(address indexed implementation);

    /// @dev Emitted when the admin account has changed.
    event AdminChanged(address previousAdmin, address newAdmin);

    //==============================================================================
    // Errors
    //==============================================================================

    /// @dev Emitted when trying to send ether to a non-payable contract
    error AgoraDollarErc1967NonPayable();

    /// @dev The proxy caller is the current admin, and can't fallback to the proxy target.
    error ProxyDeniedAdminAccess();

    /// @dev The target of the proxy is not a contract.
    error ImplementationTargetNotAContract();
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// solhint-disable func-name-mixedcase
// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// =========================== AgoraDollar ============================
// ====================================================================

import { AgoraDollarCore, ConstructorParams, ShortStrings } from "./AgoraDollarCore.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

/// @title AgoraDollar
contract AgoraDollar is AgoraDollarCore {
    using StorageLib for uint256;
    using ShortStrings for *;

    constructor(ConstructorParams memory _params) AgoraDollarCore(_params) {}

    //==============================================================================
    // External View Functions: Erc3009
    //==============================================================================

    function TRANSFER_WITH_AUTHORIZATION_TYPEHASH() external pure returns (bytes32) {
        return TRANSFER_WITH_AUTHORIZATION_TYPEHASH_;
    }

    function RECEIVE_WITH_AUTHORIZATION_TYPEHASH() external pure returns (bytes32) {
        return RECEIVE_WITH_AUTHORIZATION_TYPEHASH_;
    }

    function CANCEL_AUTHORIZATION_TYPEHASH() external pure returns (bytes32) {
        return CANCEL_AUTHORIZATION_TYPEHASH_;
    }

    /// @notice The ```authorizationState;``` maps the following:
    /// @notice Key: ```_authorizer``` the account which is providing the authorization
    /// @notice Key: ```_nonce``` the unique nonce for the authorization
    /// @return _isNonceUsed the state of the authorization
    function authorizationState(address _authorizer, bytes32 _nonce) external view returns (bool _isNonceUsed) {
        _isNonceUsed = StorageLib.getPointerToEip3009Storage().isAuthorizationUsed[_authorizer][_nonce];
    }

    //==============================================================================
    //  Eip712 Functions
    //==============================================================================

    function hashTypedDataV4(bytes32 _structHash) external view returns (bytes32) {
        return _hashTypedDataV4({ structHash: _structHash });
    }

    function domainSeparatorV4() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    //==============================================================================
    // External View Functions: Erc2612
    //==============================================================================

    function ERC2612_STORAGE_SLOT() external pure returns (bytes32) {
        return StorageLib.ERC2612_STORAGE_SLOT_;
    }

    function nonces(address _account) external view returns (uint256 _nonce) {
        _nonce = StorageLib.getPointerToErc2612Storage().nonces[_account];
    }

    //==============================================================================
    // External View Functions: Erc20
    //==============================================================================

    function name() external view returns (string memory) {
        return _name.toString();
    }

    function symbol() external view returns (string memory) {
        return _symbol.toString();
    }

    function balanceOf(address _account) external view returns (uint256) {
        return StorageLib.getPointerToErc20CoreStorage().accountData[_account].balance;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return StorageLib.getPointerToErc20CoreStorage().accountAllowances[_owner][_spender];
    }

    function totalSupply() external view returns (uint256) {
        return StorageLib.getPointerToErc20CoreStorage().totalSupply;
    }

    function isAccountFrozen(address _account) external view returns (bool) {
        return StorageLib.getPointerToErc20CoreStorage().accountData[_account].isFrozen;
    }

    function accountData(address _account) external view returns (StorageLib.Erc20AccountData memory) {
        return StorageLib.getPointerToErc20CoreStorage().accountData[_account];
    }

    function ERC20_CORE_STORAGE_SLOT() external pure returns (bytes32) {
        return StorageLib.ERC20_CORE_STORAGE_SLOT_;
    }

    //==============================================================================
    // External View Functions: AccessControlMetadata
    //==============================================================================

    function getRoleData(bytes32 _roleId) external view returns (StorageLib.AgoraDollarAccessControlRoleData memory) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_roleId];
    }

    function adminAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[ADMIN_ROLE].currentRoleAddress;
    }

    function pendingAdminAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[ADMIN_ROLE].pendingRoleAddress;
    }

    function minterAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[MINTER_ROLE].currentRoleAddress;
    }

    function pendingMinterAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[MINTER_ROLE].pendingRoleAddress;
    }

    function burnerAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[BURNER_ROLE].currentRoleAddress;
    }

    function pendingBurnerAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[BURNER_ROLE].pendingRoleAddress;
    }

    function pauserAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[PAUSER_ROLE].currentRoleAddress;
    }

    function pendingPauserAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[PAUSER_ROLE].pendingRoleAddress;
    }

    function freezerAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[FREEZER_ROLE].currentRoleAddress;
    }

    function pendingFreezerAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[FREEZER_ROLE].pendingRoleAddress;
    }

    //==============================================================================
    // External View Functions: Eip712
    //==============================================================================

    function eip712Domain()
        external
        view
        returns (
            bytes1 _fields,
            string memory _name,
            string memory _version,
            uint256 _chainId,
            address _verifyingContract,
            bytes32 _salt,
            uint256[] memory _extensions
        )
    {
        return (
            hex"0f", // 01111
            _Eip712Name(),
            _Eip712Version(),
            block.chainid,
            address(this),
            bytes32(0),
            new uint256[](0)
        );
    }

    //==============================================================================
    // External View Functions: AgoraDollarErc1967 Proxy State
    //==============================================================================

    function proxyAdminAddress() external view returns (address) {
        return StorageLib.getPointerToAgoraDollarErc1967ProxyAdminStorage().proxyAdminAddress;
    }

    function isMsgSenderFrozenCheckEnabled() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isMsgSenderFrozenCheckEnabled();
    }

    function isTransferPaused() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isTransferPaused();
    }

    function isSignatureVerificationPaused() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isSignatureVerificationPaused();
    }

    function isMintPaused() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isMintPaused();
    }

    function isFreezingPaused() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isFreezingPaused();
    }

    function isTransferUpgraded() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isTransferUpgraded();
    }

    function isTransferFromUpgraded() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isTransferFromUpgraded();
    }

    function isTransferWithAuthorizationUpgraded() external view returns (bool) {
        return StorageLib.sloadImplementationSlotDataAsUint256().isTransferWithAuthorizationUpgraded();
    }

    function implementation() external view returns (address) {
        return StorageLib.sloadImplementationSlotDataAsUint256().implementation();
    }

    //==============================================================================
    // Proxy Utils BitMasks
    //==============================================================================

    function IS_MSG_SENDER_FROZEN_CHECK_ENABLED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_MSG_SENDER_FROZEN_CHECK_ENABLED_BIT_POSITION_;
    }

    function IS_MINT_PAUSED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_MINT_PAUSED_BIT_POSITION_;
    }

    function IS_FREEZING_PAUSED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_FREEZING_PAUSED_BIT_POSITION_;
    }

    function IS_TRANSFER_PAUSED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_TRANSFER_PAUSED_BIT_POSITION_;
    }

    function IS_TRANSFER_UPGRADED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_TRANSFER_UPGRADED_BIT_POSITION_;
    }

    function IS_TRANSFER_FROM_UPGRADED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_TRANSFER_FROM_UPGRADED_BIT_POSITION_;
    }

    function IS_TRANSFER_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_TRANSFER_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_;
    }

    function IS_RECEIVE_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION() external pure returns (uint256) {
        return StorageLib.IS_RECEIVE_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_;
    }
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// solhint-disable func-name-mixedcase
// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ========================= AgoraDollarCore ==========================
// ====================================================================

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";

import { Eip3009 } from "./Eip3009.sol";
import { Eip712 } from "./Eip712.sol";
import { Erc20Privileged } from "./Erc20Privileged.sol";
import { Erc2612 } from "./Erc2612.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

struct ConstructorParams {
    string name;
    string symbol;
    string eip712Name;
    string eip712Version;
}

contract AgoraDollarCore is Initializable, Eip3009, Erc2612, Erc20Privileged {
    using StorageLib for uint256;
    using ShortStrings for *;

    ShortString internal immutable _name;

    ShortString internal immutable _symbol;

    uint8 public immutable decimals = 18;

    constructor(ConstructorParams memory _params) Eip712(_params.eip712Name, _params.eip712Version) {
        _name = _params.name.toShortString();
        _symbol = _params.symbol.toShortString();
    }

    struct InitializeParams {
        address initialAdminAddress;
    }

    function initialize(InitializeParams memory _initializeParams) external reinitializer(1) {
        _initializeAgoraDollarAccessControl({ _initialAdminAddress: _initializeParams.initialAdminAddress });
    }

    //==============================================================================
    // External stateful Functions: Erc20
    //==============================================================================

    function approve(address _spender, uint256 _value) external returns (bool) {
        _approve({ _owner: msg.sender, _spender: _spender, _value: _value });
        return true;
    }

    function transfer(address _to, uint256 _value) external returns (bool) {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    function transferFrom(address _from, address _to, uint256 _value) external returns (bool) {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    //==============================================================================
    // External Stateful Functions: Erc3009
    //==============================================================================

    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    function transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) public {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    function receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) public {
        // NOTE: implemented in proxy, here to check for signature collisions
    }

    function cancelAuthorization(address _authorizer, bytes32 _nonce, uint8 _v, bytes32 _r, bytes32 _s) external {
        cancelAuthorization({ _authorizer: _authorizer, _nonce: _nonce, _signature: abi.encodePacked(_r, _s, _v) });
    }

    function cancelAuthorization(address _authorizer, bytes32 _nonce, bytes memory _signature) public {
        // Effects: mark the signature as used
        _cancelAuthorization({ _authorizer: _authorizer, _nonce: _nonce, _signature: _signature });
    }

    //==============================================================================
    // ContractDataSetters Functions
    //==============================================================================

    function setIsMsgSenderCheckEnabled(bool _isEnabled) external {
        _requireSenderIsRole({ _role: ADMIN_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_MSG_SENDER_FROZEN_CHECK_ENABLED_BIT_POSITION_,
            _setBitToOne: _isEnabled
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsMsgSenderCheckEnabled({ isEnabled: _isEnabled });
    }

    function setIsMintPaused(bool _isPaused) external {
        _requireSenderIsRole({ _role: PAUSER_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_MINT_PAUSED_BIT_POSITION_,
            _setBitToOne: _isPaused
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsMintPaused({ isPaused: _isPaused });
    }

    function setIsFreezingPaused(bool _isPaused) external {
        _requireSenderIsRole({ _role: PAUSER_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_FREEZING_PAUSED_BIT_POSITION_,
            _setBitToOne: _isPaused
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsFreezingPaused({ isPaused: _isPaused });
    }

    function setIsTransferPaused(bool _isPaused) external {
        _requireSenderIsRole({ _role: PAUSER_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_TRANSFER_PAUSED_BIT_POSITION_,
            _setBitToOne: _isPaused
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsTransferPaused({ isPaused: _isPaused });
    }

    function setIsSignatureVerificationPaused(bool _isPaused) external {
        _requireSenderIsRole({ _role: PAUSER_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_SIGNATURE_VERIFICATION_PAUSED_BIT_POSITION_,
            _setBitToOne: _isPaused
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsSignatureVerificationPaused({ isPaused: _isPaused });
    }

    function setIsTransferUpgraded(bool _isUpgraded) external {
        _requireSenderIsRole({ _role: ADMIN_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_TRANSFER_UPGRADED_BIT_POSITION_,
            _setBitToOne: _isUpgraded
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsTransferUpgraded({ isUpgraded: _isUpgraded });
    }

    function setIsTransferFromUpgraded(bool _isUpgraded) external {
        _requireSenderIsRole({ _role: ADMIN_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_TRANSFER_FROM_UPGRADED_BIT_POSITION_,
            _setBitToOne: _isUpgraded
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsTransferFromUpgraded({ isUpgraded: _isUpgraded });
    }

    function setIsTransferWithAuthorizationUpgraded(bool _isUpgraded) external {
        _requireSenderIsRole({ _role: ADMIN_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_TRANSFER_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_,
            _setBitToOne: _isUpgraded
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsTransferWithAuthorizationUpgraded({ isUpgraded: _isUpgraded });
    }

    function setIsReceiveWithAuthorizationUpgraded(bool _isUpgraded) external {
        _requireSenderIsRole({ _role: ADMIN_ROLE });
        uint256 _contractData = StorageLib.sloadImplementationSlotDataAsUint256();
        uint256 _newContractData = _contractData.setBitWithMask({
            _bitToSet: StorageLib.IS_RECEIVE_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_,
            _setBitToOne: _isUpgraded
        });
        _newContractData.sstoreImplementationSlotDataAsUint256();
        emit SetIsReceiveWithAuthorizationUpgraded({ isUpgraded: _isUpgraded });
    }

    //==============================================================================
    // Events
    //==============================================================================
    /// @notice The ```SetIsMsgSenderCheckEnabled``` event is emitted when the isMsgSenderCheckEnabled state variable is updated
    /// @param isEnabled The new value of the isMsgSenderCheckEnabled state variable
    event SetIsMsgSenderCheckEnabled(bool isEnabled);

    /// @notice The ```SetIsMintPaused``` event is emitted when the isMintPaused state variable is updated
    /// @param isPaused The new value of the isMintPaused state variable
    event SetIsMintPaused(bool isPaused);

    /// @notice The ```SetIsFreezingPaused``` event is emitted when the isFreezingPaused state variable is updated
    /// @param isPaused The new value of the isFreezingPaused state variable
    event SetIsFreezingPaused(bool isPaused);

    /// @notice The ```SetIsTransferPaused``` event is emitted when the isTransferPaused state variable is updated
    /// @param isPaused The new value of the isTransferPaused state variable
    event SetIsTransferPaused(bool isPaused);

    /// @notice The ```SetIsSignatureVerificationPaused``` event is emitted when the isSignatureVerificationPaused state variable is updated
    /// @param isPaused The new value of the isSignatureVerificationPaused state variable
    event SetIsSignatureVerificationPaused(bool isPaused);

    /// @notice The ```SetIsTransferUpgraded``` event is emitted when the isTransferUpgraded state variable is updated
    /// @param isUpgraded The new value of the isTransferUpgraded state variable
    event SetIsTransferUpgraded(bool isUpgraded);

    /// @notice The ```SetIsTransferFromUpgraded``` event is emitted when the isTransferFromUpgraded state variable is updated
    /// @param isUpgraded The new value of the isTransferFromUpgraded state variable
    event SetIsTransferFromUpgraded(bool isUpgraded);

    /// @notice The ```SetIsTransferWithAuthorizationUpgraded``` event is emitted when the isTransferWithAuthorizationUpgraded state variable is updated
    /// @param isUpgraded The new value of the isTransferWithAuthorizationUpgraded state variable
    event SetIsTransferWithAuthorizationUpgraded(bool isUpgraded);

    /// @notice The ```SetIsReceiveWithAuthorizationUpgraded``` event is emitted when the isReceiveWithAuthorizationUpgraded state variable is updated
    /// @param isUpgraded The new value of the isReceiveWithAuthorizationUpgraded state variable
    event SetIsReceiveWithAuthorizationUpgraded(bool isUpgraded);
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ============================= Eip3009 ==============================
// ====================================================================

import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";
import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";

import { Eip712 } from "./Eip712.sol";
import { Erc20Core } from "./Erc20Core.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

/// @title Eip-3009
/// @notice Inspired by Circle's Eip3009 implementation, Contracts provide internal implementations for gas-abstracted transfers
abstract contract Eip3009 is Eip712, Erc20Core {
    using SafeCastLib for uint256;
    using StorageLib for uint256;

    /// @notice keccak256("TransferWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 internal constant TRANSFER_WITH_AUTHORIZATION_TYPEHASH_ =
        0x7c7c6cdb67a18743f49ec6fa9b35f50d52ed05cbed4cc592e13b44501c1a2267;

    /// @notice keccak256("ReceiveWithAuthorization(address from,address to,uint256 value,uint256 validAfter,uint256 validBefore,bytes32 nonce)")
    bytes32 internal constant RECEIVE_WITH_AUTHORIZATION_TYPEHASH_ =
        0xd099cc98ef71107a616c4f0f941f04c322d8e254fe26b3c6668db87aae413de8;

    /// @notice keccak256("CancelAuthorization(address authorizer,bytes32 nonce)")
    bytes32 internal constant CANCEL_AUTHORIZATION_TYPEHASH_ =
        0x158b0a9edf7a828aad02f63cd515c68ef2f50ba807396f6d12842833a1597429;

    //==============================================================================
    // Internal Procedural Functions
    //==============================================================================

    /// @notice Execute a transfer with a signed authorization
    /// @dev EOA wallet signatures should be packed in the order of r, s, v.
    /// @param _from          Payer's address (Authorizer)
    /// @param _to            Payee's address
    /// @param _value         Amount to be transferred
    /// @param _validAfter    The time after which this is valid (unix time)
    /// @param _validBefore   The time before which this is valid (unix time)
    /// @param _nonce         Unique nonce
    /// @param _signature     Signature byte array produced by an EOA wallet or a contract wallet
    function _transferWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) internal {
        // Checks: contract-wide access control
        bool _isSignatureVerificationPaused = StorageLib
            .sloadImplementationSlotDataAsUint256()
            .isSignatureVerificationPaused();
        if (_isSignatureVerificationPaused) revert StorageLib.SignatureVerificationPaused();

        // Checks: authorization validity
        if (block.timestamp <= _validAfter) revert InvalidAuthorization();
        if (block.timestamp >= _validBefore) revert ExpiredAuthorization();
        _requireUnusedAuthorization({ _authorizer: _from, _nonce: _nonce });

        // Checks: valid signature
        _requireIsValidSignatureNow({
            _signer: _from,
            _dataHash: keccak256(
                abi.encode(TRANSFER_WITH_AUTHORIZATION_TYPEHASH_, _from, _to, _value, _validAfter, _validBefore, _nonce)
            ),
            _signature: _signature
        });

        // Effects: mark authorization as used and transfer
        _markAuthorizationAsUsed({ _authorizer: _from, _nonce: _nonce });
        _transfer({ _from: _from, _to: _to, _transferValue: _value.toUint248() });
    }

    /// @notice Receive a transfer with a signed authorization from the payer
    /// @dev This has an additional check to ensure that the payee's address matches the caller of this function to prevent front-running attacks.
    /// @dev EOA wallet signatures should be packed in the order of r, s, v.
    /// @param _from          Payer's address (Authorizer)
    /// @param _to            Payee's address
    /// @param _value         Amount to be transferred
    /// @param _validAfter    The time after which this is valid (unix time)
    /// @param _validBefore   The time before which this is valid (unix time)
    /// @param _nonce         Unique nonce
    /// @param _signature     Signature byte array produced by an EOA wallet or a contract wallet
    function _receiveWithAuthorization(
        address _from,
        address _to,
        uint256 _value,
        uint256 _validAfter,
        uint256 _validBefore,
        bytes32 _nonce,
        bytes memory _signature
    ) internal {
        // Checks: contract-wide access control
        bool _isSignatureVerificationPaused = StorageLib
            .sloadImplementationSlotDataAsUint256()
            .isSignatureVerificationPaused();
        if (_isSignatureVerificationPaused) revert StorageLib.SignatureVerificationPaused();

        // Checks: authorization validity
        if (_to != msg.sender) revert InvalidPayee(msg.sender, _to);
        if (block.timestamp <= _validAfter) revert InvalidAuthorization();
        if (block.timestamp >= _validBefore) revert ExpiredAuthorization();
        _requireUnusedAuthorization({ _authorizer: _from, _nonce: _nonce });

        // Checks: valid signature
        _requireIsValidSignatureNow({
            _signer: _from,
            _dataHash: keccak256(
                abi.encode(RECEIVE_WITH_AUTHORIZATION_TYPEHASH_, _from, _to, _value, _validAfter, _validBefore, _nonce)
            ),
            _signature: _signature
        });

        // Effects: mark authorization as used and transfer
        _markAuthorizationAsUsed({ _authorizer: _from, _nonce: _nonce });
        _transfer({ _from: _from, _to: _to, _transferValue: _value.toUint248() });
    }

    /// @notice Attempt to cancel an authorization
    /// @dev EOA wallet signatures should be packed in the order of r, s, v.
    /// @param _authorizer    Authorizer's address
    /// @param _nonce         Nonce of the authorization
    /// @param _signature     Signature byte array produced by an EOA wallet or a contract wallet
    function _cancelAuthorization(address _authorizer, bytes32 _nonce, bytes memory _signature) internal {
        _requireUnusedAuthorization({ _authorizer: _authorizer, _nonce: _nonce });
        _requireIsValidSignatureNow({
            _signer: _authorizer,
            _dataHash: keccak256(abi.encode(CANCEL_AUTHORIZATION_TYPEHASH_, _authorizer, _nonce)),
            _signature: _signature
        });

        StorageLib.getPointerToEip3009Storage().isAuthorizationUsed[_authorizer][_nonce] = true;
        emit AuthorizationCanceled({ authorizer: _authorizer, nonce: _nonce });
    }

    //==============================================================================
    // Internal Checks Functions
    //==============================================================================

    /// @notice Validates that signature against input data struct
    /// @param _signer        Signer's address
    /// @param _dataHash      Hash of encoded data struct
    /// @param _signature     Signature byte array produced by an EOA wallet or a contract wallet
    function _requireIsValidSignatureNow(address _signer, bytes32 _dataHash, bytes memory _signature) private view {
        if (
            !SignatureCheckerLib.isValidSignatureNow({
                signer: _signer,
                hash: MessageHashUtils.toTypedDataHash({
                    domainSeparator: _domainSeparatorV4(),
                    structHash: _dataHash
                }),
                signature: _signature
            })
        ) revert InvalidSignature();
    }

    /// @notice Check that an authorization is unused
    /// @param _authorizer    Authorizer's address
    /// @param _nonce         Nonce of the authorization
    function _requireUnusedAuthorization(address _authorizer, bytes32 _nonce) private view {
        if (StorageLib.getPointerToEip3009Storage().isAuthorizationUsed[_authorizer][_nonce])
            revert UsedOrCanceledAuthorization();
    }

    //==============================================================================
    // Internal Effects Functions
    //==============================================================================

    /// @notice Mark an authorization as used
    /// @param _authorizer    Authorizer's address
    /// @param _nonce         Nonce of the authorization
    function _markAuthorizationAsUsed(address _authorizer, bytes32 _nonce) private {
        StorageLib.getPointerToEip3009Storage().isAuthorizationUsed[_authorizer][_nonce] = true;
        emit AuthorizationUsed({ authorizer: _authorizer, nonce: _nonce });
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice ```AuthorizationUsed``` event is emitted when an authorization is used
    /// @param authorizer    Authorizer's address
    /// @param nonce         Nonce of the authorization
    event AuthorizationUsed(address indexed authorizer, bytes32 indexed nonce);

    /// @notice ```AuthorizationCanceled``` event is emitted when an authorization is canceled
    /// @param authorizer    Authorizer's address
    /// @param nonce         Nonce of the authorization
    event AuthorizationCanceled(address indexed authorizer, bytes32 indexed nonce);

    //==============================================================================
    // Errors
    //==============================================================================

    /// @notice The ```InvalidPayee``` error is emitted when the payee does not match sender in receiveWithAuthorization
    /// @param caller    The caller of the function
    /// @param payee     The expected payee in the function
    error InvalidPayee(address caller, address payee);

    /// @notice The ```InvalidAuthorization``` error is emitted when the authorization is invalid because its too early
    error InvalidAuthorization();

    /// @notice The ```ExpiredAuthorization``` error is emitted when the authorization is expired
    error ExpiredAuthorization();

    /// @notice The ```InvalidSignature``` error is emitted when the signature is invalid
    error InvalidSignature();

    /// @notice The ```UsedOrCanceledAuthorization``` error is emitted when the authorization nonce is already used or canceled
    error UsedOrCanceledAuthorization();
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ======================== AgoraProxyAdmin ===========================
// ====================================================================

import { Ownable, Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";
import { ProxyAdmin } from "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

contract AgoraProxyAdmin is ProxyAdmin, Ownable2Step {
    constructor(address _initialOwner) ProxyAdmin(_initialOwner) {}

    /// @notice Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
    /// @dev Can only be called by the current owner.
    /// @param _newOwner The address to which ownership of the contract will be transferred.
    function transferOwnership(address _newOwner) public override(Ownable, Ownable2Step) onlyOwner {
        // NOTE: Order of inheritance/override is important to ensure we are calling Ownable2Step version of transferOwnership
        super.transferOwnership({ newOwner: _newOwner });
    }

    /// @notice Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
    /// @dev Internal function without access restriction.
    /// @param _newOwner The address to which ownership of the contract will be transferred.
    function _transferOwnership(address _newOwner) internal override(Ownable, Ownable2Step) {
        // NOTE: Order of inheritance/override is important to ensure we are calling Ownable2Step version of _transferOwnership
        super._transferOwnership({ newOwner: _newOwner });
    }
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ============================ StorageLib ============================
// ====================================================================

/**
 * This library contains information for accessing unstructured storage following erc1967
 * and erc7201 standards.
 *
 * The erc1967 storage slots are defined using their own formula/namespace.
 * These are listed last in the contract.
 *
 * The erc7201 namespace is defined as <ContractName>.<Namespace>
 * The deriveErc7201StorageSlot() function is used to derive the storage slot for a given namespace
 * and to check that value against the hard-coded bytes32 value for the slot location in testing frameworks
 * Each inherited contract has its own struct of the form <ContractName>Storage which matches <Namespace>
 * from above. Each struct is held in a unique namespace and has a unique storage slot.
 * See: https://eips.ethereum.org/EIPS/eip-7201 for additional information regarding this standard
 */
library StorageLib {
    // Global namespace for use in deriving storage slot locations
    string internal constant GLOBAL_ERC7201_NAMESPACE = "AgoraDollarErc1967Proxy";

    // Use this function to check hardcoded bytes32 values against the expected formula
    function deriveErc7201StorageSlot(string memory _localNamespace) internal pure returns (bytes32) {
        bytes memory _namespace = abi.encodePacked(GLOBAL_ERC7201_NAMESPACE, ".", _localNamespace);
        return keccak256(abi.encode(uint256(keccak256(_namespace)) - 1)) & ~bytes32(uint256(0xff));
    }

    //==============================================================================
    // Eip3009 Storage Items
    //==============================================================================

    string internal constant EIP3009_NAMESPACE = "Eip3009Storage";

    /// @custom:storage-location erc7201:AgoraDollarErc1967Proxy.Eip3009Storage
    struct Eip3009Storage {
        mapping(address _authorizer => mapping(bytes32 _nonce => bool _isNonceUsed)) isAuthorizationUsed;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraDollarErc1967Proxy.Eip3009Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant EIP3009_STORAGE_SLOT_ =
        0xbb0a37da742be2e3b68bdb11d195150f4243c03fb37d3cdfa756046082a38600;

    function getPointerToEip3009Storage() internal pure returns (Eip3009Storage storage $) {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := EIP3009_STORAGE_SLOT_
        }
    }

    //==============================================================================
    // Erc2612 Storage Items
    //==============================================================================

    string internal constant ERC2612_NAMESPACE = "Erc2612Storage";

    /// @custom:storage-location erc7201:AgoraDollarErc1967Proxy.Erc2612Storage
    struct Erc2612Storage {
        mapping(address => uint256) nonces;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraDollarErc1967Proxy.Erc2612Storage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant ERC2612_STORAGE_SLOT_ =
        0x69e87f5b9323740fce20cdf574dacd1d10e756da64a1f2df70fd1ace4c7cc300;

    function getPointerToErc2612Storage() internal pure returns (Erc2612Storage storage $) {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := ERC2612_STORAGE_SLOT_
        }
    }

    //==============================================================================
    // Erc20Core Storage Items
    //==============================================================================

    string internal constant ERC20_CORE_NAMESPACE = "Erc20CoreStorage";

    struct Erc20AccountData {
        bool isFrozen;
        uint248 balance;
    }

    /// @custom:storage-location erc7201:AgoraDollarErc1967Proxy.Erc20CoreStorage
    struct Erc20CoreStorage {
        /// @dev _account the account whose data we are accessing
        /// @dev _accountData the account data for the account
        mapping(address _account => Erc20AccountData _accountData) accountData;
        /// @dev _owner The owner of the tokens
        /// @dev _spender The spender of the tokens
        /// @dev _accountAllowance the allowance of the spender
        mapping(address _owner => mapping(address _spender => uint256 _accountAllowance)) accountAllowances;
        uint256 totalSupply;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraDollarErc1967Proxy.Erc20CoreStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant ERC20_CORE_STORAGE_SLOT_ =
        0x455730fed596673e69db1907be2e521374ba893f1a04cc5f5dd931616cd6b700;

    function getPointerToErc20CoreStorage() internal pure returns (Erc20CoreStorage storage $) {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := ERC20_CORE_STORAGE_SLOT_
        }
    }

    //==============================================================================
    // AgoraDollarAccessControl Storage Items
    //==============================================================================

    string internal constant AGORA_DOLLAR_ACCESS_CONTROL_NAMESPACE = "AgoraDollarAccessControlStorage";

    /// @notice The RoleData struct
    /// @param pendingRoleAddress The address of the nominated (pending) role
    /// @param currentRoleAddress The address of the current role
    struct AgoraDollarAccessControlRoleData {
        address pendingRoleAddress;
        address currentRoleAddress;
    }

    /// @custom:storage-location erc7201:AgoraDollarErc1967Proxy.AgoraDollarAccessControlStorage
    struct AgoraDollarAccessControlStorage {
        /// @dev _roleData the data for the role
        mapping(bytes32 _role => AgoraDollarAccessControlRoleData _roleData) roleData;
    }

    /// @dev keccak256(abi.encode(uint256(keccak256("AgoraDollarErc1967Proxy.AgoraDollarAccessControlStorage")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 internal constant AGORA_DOLLAR_ACCESS_CONTROL_STORAGE_SLOT_ =
        0x9d28e63f6379c0b2127b14120db65179caba9597ddafa73863de41a4ba1fe700;

    function getPointerToAgoraDollarAccessControlStorage()
        internal
        pure
        returns (AgoraDollarAccessControlStorage storage $)
    {
        /// @solidity memory-safe-assembly
        assembly {
            $.slot := AGORA_DOLLAR_ACCESS_CONTROL_STORAGE_SLOT_
        }
    }

    //==============================================================================
    // AgoraDollarErc1967 Admin Slot Items
    //==============================================================================

    /// @custom:storage-location erc1967:eip1967.proxy.admin
    struct AgoraDollarErc1967ProxyAdminStorage {
        address proxyAdminAddress;
    }

    // NOTE: deviates from erc7201 standard because erc1967 defines its own storage slot algorithm
    /// @dev bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1)
    bytes32 internal constant AGORA_DOLLAR_ERC1967_PROXY_ADMIN_STORAGE_SLOT_ =
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function getPointerToAgoraDollarErc1967ProxyAdminStorage()
        internal
        pure
        returns (AgoraDollarErc1967ProxyAdminStorage storage adminSlot)
    {
        /// @solidity memory-safe-assembly
        assembly {
            adminSlot.slot := AGORA_DOLLAR_ERC1967_PROXY_ADMIN_STORAGE_SLOT_
        }
    }

    //==============================================================================
    // AgoraDollarErc1967 Implementation Slot Items
    //==============================================================================

    /// @custom:storage-location erc1967:eip1967.proxy.implementation
    struct AgoraDollarErc1967ProxyContractStorage {
        address implementationAddress; // least significant bits first
        uint96 placeholder; // Placeholder for bitmask items defined below
    }

    /// @dev bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1)
    bytes32 internal constant AGORA_DOLLAR_ERC1967_PROXY_CONTRACT_STORAGE_SLOT_ =
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /// @notice The ```getPointerToAgoraDollarErc1967ProxyContractStorage``` function returns a pointer to the storage slot for the implementation address.
    /// @return contractData The data in the storage slot for the implementation address and other data.
    function getPointerToAgoraDollarErc1967ProxyContractStorage()
        internal
        pure
        returns (AgoraDollarErc1967ProxyContractStorage storage contractData)
    {
        /// @solidity memory-safe-assembly
        assembly {
            contractData.slot := AGORA_DOLLAR_ERC1967_PROXY_CONTRACT_STORAGE_SLOT_
        }
    }

    function sloadImplementationSlotDataAsUint256() internal view returns (uint256 _contractData) {
        /// @solidity memory-safe-assembly
        assembly {
            _contractData := sload(AGORA_DOLLAR_ERC1967_PROXY_CONTRACT_STORAGE_SLOT_)
        }
    }

    function sstoreImplementationSlotDataAsUint256(uint256 _contractData) internal {
        /// @solidity memory-safe-assembly
        assembly {
            sstore(AGORA_DOLLAR_ERC1967_PROXY_CONTRACT_STORAGE_SLOT_, _contractData)
        }
    }

    // Contract Access Control masks
    uint256 internal constant IS_MSG_SENDER_FROZEN_CHECK_ENABLED_BIT_POSITION_ = 1 << (255 - 0);
    uint256 internal constant IS_MINT_PAUSED_BIT_POSITION_ = 1 << (255 - 1);
    uint256 internal constant IS_FREEZING_PAUSED_BIT_POSITION_ = 1 << (255 - 2);
    uint256 internal constant IS_TRANSFER_PAUSED_BIT_POSITION_ = 1 << (255 - 3);
    uint256 internal constant IS_SIGNATURE_VERIFICATION_PAUSED_BIT_POSITION_ = 1 << (255 - 4);

    // internal function upgrade masks
    // Erc20
    uint256 internal constant IS_TRANSFER_UPGRADED_BIT_POSITION_ = 1 << (255 - 10);
    uint256 internal constant IS_TRANSFER_FROM_UPGRADED_BIT_POSITION_ = 1 << (255 - 11);

    // Eip 3009
    uint256 internal constant IS_TRANSFER_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_ = 1 << (255 - 12);
    uint256 internal constant IS_RECEIVE_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_ = 1 << (255 - 13);

    //==============================================================================
    // Bitmask Functions
    //==============================================================================

    function isMsgSenderFrozenCheckEnabled(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_MSG_SENDER_FROZEN_CHECK_ENABLED_BIT_POSITION_ != 0;
    }

    function isMintPaused(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_MINT_PAUSED_BIT_POSITION_ != 0;
    }

    function isFreezingPaused(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_FREEZING_PAUSED_BIT_POSITION_ != 0;
    }

    function isTransferPaused(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_TRANSFER_PAUSED_BIT_POSITION_ != 0;
    }

    function isSignatureVerificationPaused(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_SIGNATURE_VERIFICATION_PAUSED_BIT_POSITION_ != 0;
    }

    function isTransferUpgraded(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_TRANSFER_UPGRADED_BIT_POSITION_ != 0;
    }

    function isTransferFromUpgraded(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_TRANSFER_FROM_UPGRADED_BIT_POSITION_ != 0;
    }

    function isTransferWithAuthorizationUpgraded(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_TRANSFER_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_ != 0;
    }

    function isReceiveWithAuthorizationUpgraded(uint256 _contractData) internal pure returns (bool) {
        return _contractData & IS_RECEIVE_WITH_AUTHORIZATION_UPGRADED_BIT_POSITION_ != 0;
    }

    function implementation(uint256 _contractData) internal pure returns (address) {
        // return least significant 160 bits and cast to an address
        return address(uint160(_contractData));
    }

    function setBitWithMask(
        uint256 _original,
        uint256 _bitToSet,
        bool _setBitToOne
    ) internal pure returns (uint256 _new) {
        // Sets the specified bit to 1 or 0
        _new = _setBitToOne ? _original | _bitToSet : _original & ~_bitToSet;
    }

    //==============================================================================
    // Errors
    //==============================================================================

    error TransferPaused();
    error SignatureVerificationPaused();
    error MintPaused();
    error FreezingPaused();
}// SPDX-License-Identifier: Apache-2.0

// ***NOTE***: This file has been modified to remove external functions and storage for use in a transparent-ish proxy
// ***NOTE***: Modified from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/dbb6104ce834628e473d2173bbc9d47f81a9eec3/contracts/utils/cryptography/EIP712.sol

pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ============================= Eip712 ===============================
// ====================================================================

import { ShortString, ShortStrings } from "@openzeppelin/contracts/utils/ShortStrings.sol";
import { MessageHashUtils } from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @dev https://eips.ethereum.org/EIPS/eip-712[EIP 712] is a standard for hashing and signing of typed structured data.
 *
 * The encoding scheme specified in the EIP requires a domain separator and a hash of the typed structured data, whose
 * encoding is very generic and therefore its implementation in Solidity is not feasible, thus this contract
 * does not implement the encoding itself. Protocols need to implement the type-specific encoding they need in order to
 * produce the hash of their typed data using a combination of `abi.encode` and `keccak256`.
 *
 * This contract implements the EIP 712 domain separator ({_domainSeparatorV4}) that is used as part of the encoding
 * scheme, and the final step of the encoding to obtain the message digest that is then signed via ECDSA
 * ({_hashTypedDataV4}).
 *
 * The implementation of the domain separator was designed to be as efficient as possible while still properly updating
 * the chain id to protect against replay attacks on an eventual fork of the chain.
 *
 * NOTE: This contract implements the version of the encoding known as "v4", as implemented by the JSON RPC method
 * https://docs.metamask.io/guide/signing-data.html[`eth_signTypedDataV4` in MetaMask].
 *
 */
abstract contract Eip712 {
    using ShortStrings for *;

    bytes32 private constant TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    // Cache the domain separator as an immutable value, but also store the chain id that it corresponds to, in order to
    // invalidate the cached domain separator if the chain id changes.
    bytes32 private immutable _cachedDomainSeparator;
    uint256 private immutable _cachedChainId;
    address private immutable _cachedThis;

    bytes32 private immutable _hashedName;
    bytes32 private immutable _hashedVersion;

    ShortString private immutable _name;
    ShortString private immutable _version;

    /**
     * @dev Initializes the domain separator and parameter caches.
     *
     * The meaning of `name` and `version` is specified in
     * https://eips.ethereum.org/EIPS/eip-712#definition-of-domainseparator[EIP 712]:
     *
     * - `name`: the user readable name of the signing domain, i.e. the name of the DApp or the protocol.
     * - `version`: the current major version of the signing domain.
     */
    constructor(string memory name, string memory version) {
        _name = name.toShortString();
        _version = version.toShortString();
        _hashedName = keccak256(bytes(name));
        _hashedVersion = keccak256(bytes(version));

        _cachedChainId = block.chainid;
        _cachedDomainSeparator = _buildDomainSeparator();
        _cachedThis = address(this);
    }

    /// @dev Returns the domain separator for the current chain.
    function _domainSeparatorV4() internal view returns (bytes32) {
        if (address(this) == _cachedThis && block.chainid == _cachedChainId) return _cachedDomainSeparator;
        else return _buildDomainSeparator();
    }

    function _buildDomainSeparator() private view returns (bytes32) {
        return keccak256(abi.encode(TYPE_HASH, _hashedName, _hashedVersion, block.chainid, address(this)));
    }

    /**
     * @dev Given an already https://eips.ethereum.org/EIPS/eip-712#definition-of-hashstruct[hashed struct], this
     * function returns the hash of the fully encoded EIP712 message for this domain.
     *
     * This hash can be used together with {ECDSA-recover} to obtain the signer of a message. For example:
     *
     * ```solidity
     * bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
     *     keccak256("Mail(address to,string contents)"),
     *     mailTo,
     *     keccak256(bytes(mailContents))
     * )));
     * address signer = ECDSA.recover(digest, signature);
     * ```
     */
    function _hashTypedDataV4(bytes32 structHash) internal view returns (bytes32) {
        return MessageHashUtils.toTypedDataHash({ domainSeparator: _domainSeparatorV4(), structHash: structHash });
    }

    /**
     * @dev The name parameter for the Eip712 domain.
     *
     * NOTE: By default this function reads _name which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _Eip712Name() internal view returns (string memory) {
        return _name.toString();
    }

    /**
     * @dev The version parameter for the Eip712 domain.
     *
     * NOTE: By default this function reads _version which is an immutable value.
     * It only reads from storage if necessary (in case the value is too large to fit in a ShortString).
     */
    // solhint-disable-next-line func-name-mixedcase
    function _Eip712Version() internal view returns (string memory) {
        return _version.toString();
    }
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ========================= Erc20Privileged ==========================
// ====================================================================

import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";

import { AgoraDollarAccessControl } from "./AgoraDollarAccessControl.sol";
import { Erc20Core } from "./Erc20Core.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

abstract contract Erc20Privileged is Erc20Core, AgoraDollarAccessControl {
    using SafeCastLib for uint256;
    using StorageLib for uint256;

    //==============================================================================
    // Mint Functions
    //==============================================================================

    struct BatchMintParam {
        address receiverAddress;
        uint256 value;
    }

    function batchMint(BatchMintParam[] memory _mints) external {
        // Checks: sender must be minter
        _requireSenderIsRole({ _role: MINTER_ROLE });

        // Checks: minting must not be paused
        if (StorageLib.sloadImplementationSlotDataAsUint256().isMintPaused()) revert StorageLib.MintPaused();

        // Effects: add to totalSupply and account balances
        for (uint256 i = 0; i < _mints.length; i++) {
            // Checks: account cannot be 0 address
            if (_mints[i].receiverAddress == address(0)) revert ERC20InvalidReceiver(address(0));

            // Effects: add to totalSupply and account balance
            uint248 _value248 = _mints[i].value.toUint248();
            StorageLib.getPointerToErc20CoreStorage().totalSupply += _value248;
            StorageLib.getPointerToErc20CoreStorage().accountData[_mints[i].receiverAddress].balance += _value248;

            // Emit event
            emit Transfer({ from: address(0), to: _mints[i].receiverAddress, value: _mints[i].value });
            emit Minted({ receiver: _mints[i].receiverAddress, value: _mints[i].value });
        }
    }

    //==============================================================================
    // Burn Functions
    //==============================================================================

    struct BatchBurnFromParam {
        address burnFromAddress;
        uint256 value;
    }

    function batchBurnFrom(BatchBurnFromParam[] memory _burns) external {
        // Checks: sender must be burner
        _requireSenderIsRole(BURNER_ROLE);

        for (uint256 i = 0; i < _burns.length; i++) {
            // Effects: subtract from totalSupply and account balance
            uint248 _value248 = _burns[i].value.toUint248();
            StorageLib.getPointerToErc20CoreStorage().totalSupply -= _value248;
            StorageLib.getPointerToErc20CoreStorage().accountData[_burns[i].burnFromAddress].balance -= _value248;

            // emit event (include Burned event to prevent spoofing of Transfer event as we dont check for 0 address in transfer)
            emit Transfer({ from: _burns[i].burnFromAddress, to: address(0), value: _burns[i].value });
            emit Burned({ burnFrom: _burns[i].burnFromAddress, value: _burns[i].value });
        }
    }

    //==============================================================================
    // Freeze Functions
    //==============================================================================

    /// @notice Freeze an account.
    /// @param _account The account to freeze.
    function freeze(address _account) external {
        _requireSenderIsRole({ _role: FREEZER_ROLE });
        if (StorageLib.sloadImplementationSlotDataAsUint256().isFreezingPaused()) revert StorageLib.FreezingPaused();

        StorageLib.getPointerToErc20CoreStorage().accountData[_account].isFrozen = true;
        emit AccountFrozen({ account: _account });
    }

    /// @notice Unfreeze an account so that it can transfer tokens again.
    /// @param _account The account to unfreeze.
    function unfreeze(address _account) external {
        _requireSenderIsRole({ _role: FREEZER_ROLE });
        if (StorageLib.sloadImplementationSlotDataAsUint256().isFreezingPaused()) revert StorageLib.FreezingPaused();

        StorageLib.getPointerToErc20CoreStorage().accountData[_account].isFrozen = false;
        emit AccountUnfrozen({ account: _account });
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice The ```AccountUnfrozen``` event is emitted when an account is unfrozen.
    /// @param account The account that was unfrozen.
    event AccountUnfrozen(address indexed account);

    /// @notice The ```AccountFrozen``` event is emitted when an account is frozen.
    /// @param account The account that was frozen.
    event AccountFrozen(address indexed account);

    /// @notice The ```Minted``` event is emitted when tokens are minted.
    /// @param receiver The account that received the minted tokens.
    /// @param value The amount of tokens minted.
    event Minted(address indexed receiver, uint256 value);

    /// @notice The ```Burned``` event is emitted when tokens are burned.
    /// @param burnFrom The account that burned the tokens.
    /// @param value The amount of tokens burned.
    event Burned(address indexed burnFrom, uint256 value);
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ============================= Erc2612 ==============================
// ====================================================================

import { SignatureCheckerLib } from "solady/src/utils/SignatureCheckerLib.sol";

import { Eip712 } from "./Eip712.sol";
import { Erc20Core } from "./Erc20Core.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

abstract contract Erc2612 is Eip712, Erc20Core {
    using StorageLib for uint256;

    /// @notice The ```PERMIT_TYPEHASH``` stores keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    /// @notice The ```permit``` function allows funds to be transferred without using a signature
    /// @param _owner the account that signed the message
    /// @param _spender the account that is allowed to spend the funds
    /// @param _value the amount of funds that can be spent
    /// @param _deadline the time by which the transaction must be completed
    /// @param _v the v of the signature
    /// @param _r the r of the signature
    /// @param _s the s of the signature
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external {
        permit({
            _owner: _owner,
            _spender: _spender,
            _value: _value,
            _deadline: _deadline,
            _signature: abi.encodePacked(_r, _s, _v)
        });
    }
    /// @notice The ```permit``` function allows funds to be transferred without using a signature
    /// @param _owner the account that signed the message
    /// @param _spender the account that is allowed to spend the funds
    /// @param _value the amount of funds that can be spent
    /// @param _deadline the time by which the transaction must be completed
    /// @param _signature the signature of the message

    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        bytes memory _signature
    ) public {
        // Checks: contract-wide access control
        bool _isSignatureVerificationPaused = StorageLib
            .sloadImplementationSlotDataAsUint256()
            .isSignatureVerificationPaused();
        if (_isSignatureVerificationPaused) revert StorageLib.SignatureVerificationPaused();

        // Checks: deadline
        if (block.timestamp > _deadline) revert Erc2612ExpiredSignature({ deadline: _deadline });

        // Effects: increment nonce
        uint256 _nextNonce;
        unchecked {
            _nextNonce = StorageLib.getPointerToErc2612Storage().nonces[_owner]++;
        }
        bytes32 _structHash = keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, _nextNonce, _deadline));

        bytes32 _hash = _hashTypedDataV4({ structHash: _structHash });

        // Checks: is valid eoa or eip1271 signature
        bool _isValidSignature = SignatureCheckerLib.isValidSignatureNow({
            signer: _owner,
            hash: _hash,
            signature: _signature
        });
        if (!_isValidSignature) revert Erc2612InvalidSignature();

        // Effects: update bookkeeping
        _approve({ _owner: _owner, _spender: _spender, _value: _value });
    }

    /// @notice The ```DOMAIN_SEPARATOR``` function returns the configured domain separator
    /// @dev This value can technically be updated, but it is not recommended
    /// @return _domainSeparator the domain separator
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32 _domainSeparator) {
        _domainSeparator = _domainSeparatorV4();
    }

    //==============================================================================
    // Errors
    //==============================================================================

    /// @notice The ```Erc2612ExpiredSignature``` error is emitted when the signature is expired
    /// @param deadline the time by which the transaction must be completed
    error Erc2612ExpiredSignature(uint256 deadline);

    /// @notice The ```Erc2612InvalidSignature``` error is emitted when the signature is invalid
    error Erc2612InvalidSignature();
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ============================ Erc20Core =============================
// ====================================================================

import { IERC20Errors as IErc20Errors } from "@openzeppelin/contracts/interfaces/draft-IErc6093.sol";
import { SafeCastLib } from "solady/src/utils/SafeCastLib.sol";

import { StorageLib } from "./proxy/StorageLib.sol";

abstract contract Erc20Core is IErc20Errors {
    using StorageLib for uint256;
    using SafeCastLib for uint256;

    //==============================================================================
    // Functions: Internal Effects
    //==============================================================================

    function _approve(address _owner, address _spender, uint256 _value) internal {
        StorageLib.getPointerToErc20CoreStorage().accountAllowances[_owner][_spender] = _value;
        emit Approval({ owner: _owner, spender: _spender, value: _value });
    }

    function _transfer(address _from, address _to, uint248 _transferValue) internal {
        // Checks: contract-wide access control
        bool _isTransferPaused = StorageLib.sloadImplementationSlotDataAsUint256().isTransferPaused();
        if (_isTransferPaused) revert StorageLib.TransferPaused();

        // Checks: Ensure _from address is not frozen
        StorageLib.Erc20AccountData memory _accountDataFrom = StorageLib.getPointerToErc20CoreStorage().accountData[
            _from
        ];
        if (_accountDataFrom.isFrozen) revert AccountIsFrozen({ frozenAccount: _from });

        // Checks: Ensure _from has enough balance
        if (_accountDataFrom.balance < _transferValue)
            revert ERC20InsufficientBalance({
                sender: _from,
                balance: _accountDataFrom.balance,
                needed: _transferValue
            });

        // Effects: update balances on the _from account
        unchecked {
            // Underflow not possible: _transferValue <= fromBalance asserted above
            StorageLib.getPointerToErc20CoreStorage().accountData[_from].balance =
                _accountDataFrom.balance -
                _transferValue;
        }

        // NOTE: typically checks are done before effects, but in this case we need to handle the case where _to == _from and so we want to read the latest values
        // Checks: Ensure _to address is not frozen
        StorageLib.Erc20AccountData memory _accountDataTo = StorageLib.getPointerToErc20CoreStorage().accountData[_to];
        if (_accountDataTo.isFrozen) revert AccountIsFrozen({ frozenAccount: _to });

        // Effects: update balances on the _to account
        unchecked {
            // Overflow not possible: _transferValue + toBalance <= (2^248 -1) x 10^18 [more money than atoms in the galaxy]
            StorageLib.getPointerToErc20CoreStorage().accountData[_to].balance =
                _accountDataTo.balance +
                _transferValue;
        }

        emit Transfer({ from: _from, to: _to, value: _transferValue });
    }

    function _spendAllowance(address _owner, address _spender, uint256 _value) internal {
        uint256 _currentAllowance = StorageLib.getPointerToErc20CoreStorage().accountAllowances[_owner][_spender];

        // We treat uint256.max as infinite allowance, so we don't need to read/write storage in that case
        if (_currentAllowance != type(uint256).max) {
            if (_currentAllowance < _value) revert ERC20InsufficientAllowance(_spender, _currentAllowance, _value);
            unchecked {
                StorageLib.getPointerToErc20CoreStorage().accountAllowances[_owner][_spender] =
                    _currentAllowance -
                    _value;
            }
        }
    }

    //==============================================================================
    // Events
    //==============================================================================

    /// @notice The ```Transfer``` event is emitted when tokens are transferred from one account to another.
    /// @param from The account that is transferring tokens
    /// @param to The account that is receiving tokens
    /// @param value The amount of tokens being transferred
    event Transfer(address indexed from, address indexed to, uint256 value);

    /// @notice ```Approval``` emitted when the allowance of a `spender` for an `owner` is set by a call to {approve}.
    /// @param owner The account that is allowing the spender to spend
    /// @param spender The account that is allowed to spend
    /// @param value The amount of funds that the spender is allowed to spend
    event Approval(address indexed owner, address indexed spender, uint256 value);

    //==============================================================================
    // Errors
    //==============================================================================

    /// @notice ```AccountIsFrozen``` is emitted when an account is frozen and a transfer is attempted
    /// @param frozenAccount The account that is frozen
    error AccountIsFrozen(address frozenAccount);
}// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// ====================================================================
//             _        ______     ___   _______          _
//            / \     .' ___  |  .'   `.|_   __ \        / \
//           / _ \   / .'   \_| /  .-.  \ | |__) |      / _ \
//          / ___ \  | |   ____ | |   | | |  __ /      / ___ \
//        _/ /   \ \_\ `.___]  |\  `-'  /_| |  \ \_  _/ /   \ \_
//       |____| |____|`._____.'  `.___.'|____| |___||____| |____|
// ====================================================================
// ===================== AgoraDollarAccessControl =====================
// ====================================================================

import { StorageLib } from "./proxy/StorageLib.sol";

/// @title AgoraDollarAccessControl
/// @dev Inspired by FraxFinance's Timelock2Step contract which was inspired by OZ's Ownable2Step contract
/// @notice  An abstract contract which contains 2-step transfer and renounce logic for a privileged roles
abstract contract AgoraDollarAccessControl {
    /// @notice The ADMIN_ROLE identifier
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    /// @notice The MINTER_ROLE identifier
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice The BURNER_ROLE identifier
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice The PAUSER_ROLE identifier
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /// @notice The FREEZER_ROLE identifier
    bytes32 public constant FREEZER_ROLE = keccak256("FREEZER_ROLE");

    /// @notice The RoleData struct
    /// @param pendingRoleAddress The address of the nominated (pending) role
    /// @param currentRoleAddress The address of the current role
    struct RoleData {
        address pendingRoleAddress;
        address currentRoleAddress;
    }

    function _initializeAgoraDollarAccessControl(address _initialAdminAddress) internal {
        StorageLib
            .getPointerToAgoraDollarAccessControlStorage()
            .roleData[ADMIN_ROLE]
            .currentRoleAddress = _initialAdminAddress;
    }

    // ============================================================================================
    // Functions: External Stateful Functions
    // ============================================================================================

    /// @notice The ```transferRole``` function initiates the role transfer
    /// @dev Must be called by the current role or the Admin
    /// @param _newAddress The address of the nominated (pending) role
    function transferRole(bytes32 _role, address _newAddress) external virtual {
        // Checks: Only current role or Admin can transfer role
        if (!(_isRole({ _role: _role, _address: msg.sender }) || _isRole({ _role: ADMIN_ROLE, _address: msg.sender })))
            revert AddressIsNotRole({ role: _role });

        // Effects: update pendingRole
        _setPendingRoleAddress({ _role: _role, _newAddress: _newAddress });
    }

    /// @notice The ```acceptTransferRole``` function completes the role transfer
    /// @dev Must be called by the pending role
    function acceptTransferRole(bytes32 _role) external virtual {
        // Checks
        _requireSenderIsPendingRole({ _role: _role });

        // Effects update role address
        _acceptTransferRole({ _role: _role });
    }

    // ============================================================================================
    // Functions: Internal Effects
    // ============================================================================================

    /// @notice The ```_transferRole``` function initiates the role transfer
    /// @dev This function is to be implemented by a public function
    /// @param _role The role to transfer
    /// @param _newAddress The address of the nominated (pending) role
    function _setPendingRoleAddress(bytes32 _role, address _newAddress) internal {
        StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_role].pendingRoleAddress = _newAddress;
        emit RoleTransferStarted({
            role: _role,
            previousAddress: StorageLib
                .getPointerToAgoraDollarAccessControlStorage()
                .roleData[_role]
                .currentRoleAddress,
            newAddress: _newAddress
        });
    }

    /// @notice The ```_acceptTransferRole``` function completes the role transfer
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to transfer
    function _acceptTransferRole(bytes32 _role) internal {
        StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_role].pendingRoleAddress = address(0);
        _setCurrentRoleAddress({ _role: _role, _newAddress: msg.sender });
    }

    /// @notice The ```_setRole``` function sets the role address
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to transfer
    /// @param _newAddress The address of the new role
    function _setCurrentRoleAddress(bytes32 _role, address _newAddress) internal {
        emit RoleTransferred({
            role: _role,
            previousAddress: StorageLib
                .getPointerToAgoraDollarAccessControlStorage()
                .roleData[_role]
                .currentRoleAddress,
            newAddress: _newAddress
        });
        StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_role].currentRoleAddress = _newAddress;
    }

    // ============================================================================================
    // Functions: Internal Checks
    // ============================================================================================

    /// @notice The ```_isRole``` function checks if _address is current role address
    /// @param _role The role identifier to check
    /// @param _address The address to check against the role
    /// @return Whether or not msg.sender is current role address
    function _isRole(bytes32 _role, address _address) internal view returns (bool) {
        return _address == StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_role].currentRoleAddress;
    }

    /// @notice The ```_requireIsRole``` function reverts if _address is not current role address
    /// @param _role The role identifier to check
    /// @param _address The address to check against the role
    function _requireIsRole(bytes32 _role, address _address) internal view {
        if (!_isRole({ _role: _role, _address: _address })) revert AddressIsNotRole({ role: _role });
    }

    /// @notice The ```_requireSenderIsRole``` function reverts if msg.sender is not current role address
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to check
    function _requireSenderIsRole(bytes32 _role) internal view {
        _requireIsRole({ _role: _role, _address: msg.sender });
    }

    /// @notice The ```_isPendingRole``` function checks if the _address is pending role address
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to check
    /// @param _address The address to check against the pending role
    /// @return Whether or not _address is pending role address
    function _isPendingRole(bytes32 _role, address _address) internal view returns (bool) {
        return _address == StorageLib.getPointerToAgoraDollarAccessControlStorage().roleData[_role].pendingRoleAddress;
    }

    /// @notice The ```_requireIsPendingRole``` function reverts if the _address is not pending role address
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to check
    /// @param _address The address to check against the pending role
    function _requireIsPendingRole(bytes32 _role, address _address) internal view {
        if (!_isPendingRole({ _role: _role, _address: _address })) revert AddressIsNotPendingRole({ role: _role });
    }

    /// @notice The ```_requirePendingRole``` function reverts if msg.sender is not pending role address
    /// @dev This function is to be implemented by a public function
    /// @param _role The role identifier to check
    function _requireSenderIsPendingRole(bytes32 _role) internal view {
        _requireIsPendingRole({ _role: _role, _address: msg.sender });
    }

    // ============================================================================================
    // Functions: Events
    // ============================================================================================

    /// @notice The ```RoleTransferStarted``` event is emitted when the role transfer is initiated
    /// @param role The bytes32 identifier of the role that is being transferred
    /// @param previousAddress The address of the previous role
    /// @param newAddress The address of the new role
    event RoleTransferStarted(bytes32 role, address indexed previousAddress, address indexed newAddress);

    /// @notice The ```RoleTransferred``` event is emitted when the role transfer is completed
    /// @param role The bytes32 identifier of the role that was transferred
    /// @param previousAddress The address of the previous role
    /// @param newAddress The address of the new role
    event RoleTransferred(bytes32 role, address indexed previousAddress, address indexed newAddress);

    // ============================================================================================
    // Functions: Errors
    // ============================================================================================

    /// @notice Emitted when role is transferred
    error AddressIsNotRole(bytes32 role);

    /// @notice Emitted when pending role is transferred
    error AddressIsNotPendingRole(bytes32 role);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/draft-IERC6093.sol)
pragma solidity ^0.8.20;

/**
 * @dev Standard ERC20 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC20 tokens.
 */
interface IERC20Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientBalance(address sender, uint256 balance, uint256 needed);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC20InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC20InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `spender`’s `allowance`. Used in transfers.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     * @param allowance Amount of tokens a `spender` is allowed to operate with.
     * @param needed Minimum amount required to perform a transfer.
     */
    error ERC20InsufficientAllowance(address spender, uint256 allowance, uint256 needed);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC20InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `spender` to be approved. Used in approvals.
     * @param spender Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC20InvalidSpender(address spender);
}

/**
 * @dev Standard ERC721 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC721 tokens.
 */
interface IERC721Errors {
    /**
     * @dev Indicates that an address can't be an owner. For example, `address(0)` is a forbidden owner in EIP-20.
     * Used in balance queries.
     * @param owner Address of the current owner of a token.
     */
    error ERC721InvalidOwner(address owner);

    /**
     * @dev Indicates a `tokenId` whose `owner` is the zero address.
     * @param tokenId Identifier number of a token.
     */
    error ERC721NonexistentToken(uint256 tokenId);

    /**
     * @dev Indicates an error related to the ownership over a particular token. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param tokenId Identifier number of a token.
     * @param owner Address of the current owner of a token.
     */
    error ERC721IncorrectOwner(address sender, uint256 tokenId, address owner);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC721InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC721InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param tokenId Identifier number of a token.
     */
    error ERC721InsufficientApproval(address operator, uint256 tokenId);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC721InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC721InvalidOperator(address operator);
}

/**
 * @dev Standard ERC1155 Errors
 * Interface of the https://eips.ethereum.org/EIPS/eip-6093[ERC-6093] custom errors for ERC1155 tokens.
 */
interface IERC1155Errors {
    /**
     * @dev Indicates an error related to the current `balance` of a `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     * @param balance Current balance for the interacting account.
     * @param needed Minimum amount required to perform a transfer.
     * @param tokenId Identifier number of a token.
     */
    error ERC1155InsufficientBalance(address sender, uint256 balance, uint256 needed, uint256 tokenId);

    /**
     * @dev Indicates a failure with the token `sender`. Used in transfers.
     * @param sender Address whose tokens are being transferred.
     */
    error ERC1155InvalidSender(address sender);

    /**
     * @dev Indicates a failure with the token `receiver`. Used in transfers.
     * @param receiver Address to which tokens are being transferred.
     */
    error ERC1155InvalidReceiver(address receiver);

    /**
     * @dev Indicates a failure with the `operator`’s approval. Used in transfers.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     * @param owner Address of the current owner of a token.
     */
    error ERC1155MissingApprovalForAll(address operator, address owner);

    /**
     * @dev Indicates a failure with the `approver` of a token to be approved. Used in approvals.
     * @param approver Address initiating an approval operation.
     */
    error ERC1155InvalidApprover(address approver);

    /**
     * @dev Indicates a failure with the `operator` to be approved. Used in approvals.
     * @param operator Address that may be allowed to operate on tokens without being their owner.
     */
    error ERC1155InvalidOperator(address operator);

    /**
     * @dev Indicates an array length mismatch between ids and values in a safeBatchTransferFrom operation.
     * Used in batch transfers.
     * @param idsLength Length of the array of token identifiers
     * @param valuesLength Length of the array of token amounts
     */
    error ERC1155InvalidArrayLength(uint256 idsLength, uint256 valuesLength);
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/transparent/TransparentUpgradeableProxy.sol)

pragma solidity ^0.8.20;

import {ERC1967Utils} from "../ERC1967/ERC1967Utils.sol";
import {ERC1967Proxy} from "../ERC1967/ERC1967Proxy.sol";
import {IERC1967} from "../../interfaces/IERC1967.sol";
import {ProxyAdmin} from "./ProxyAdmin.sol";

/**
 * @dev Interface for {TransparentUpgradeableProxy}. In order to implement transparency, {TransparentUpgradeableProxy}
 * does not implement this interface directly, and its upgradeability mechanism is implemented by an internal dispatch
 * mechanism. The compiler is unaware that these functions are implemented by {TransparentUpgradeableProxy} and will not
 * include them in the ABI so this interface must be used to interact with it.
 */
interface ITransparentUpgradeableProxy is IERC1967 {
    function upgradeToAndCall(address, bytes calldata) external payable;
}

/**
 * @dev This contract implements a proxy that is upgradeable through an associated {ProxyAdmin} instance.
 *
 * To avoid https://medium.com/nomic-labs-blog/malicious-backdoors-in-ethereum-proxies-62629adf3357[proxy selector
 * clashing], which can potentially be used in an attack, this contract uses the
 * https://blog.openzeppelin.com/the-transparent-proxy-pattern/[transparent proxy pattern]. This pattern implies two
 * things that go hand in hand:
 *
 * 1. If any account other than the admin calls the proxy, the call will be forwarded to the implementation, even if
 * that call matches the {ITransparentUpgradeableProxy-upgradeToAndCall} function exposed by the proxy itself.
 * 2. If the admin calls the proxy, it can call the `upgradeToAndCall` function but any other call won't be forwarded to
 * the implementation. If the admin tries to call a function on the implementation it will fail with an error indicating
 * the proxy admin cannot fallback to the target implementation.
 *
 * These properties mean that the admin account can only be used for upgrading the proxy, so it's best if it's a
 * dedicated account that is not used for anything else. This will avoid headaches due to sudden errors when trying to
 * call a function from the proxy implementation. For this reason, the proxy deploys an instance of {ProxyAdmin} and
 * allows upgrades only if they come through it. You should think of the `ProxyAdmin` instance as the administrative
 * interface of the proxy, including the ability to change who can trigger upgrades by transferring ownership.
 *
 * NOTE: The real interface of this proxy is that defined in `ITransparentUpgradeableProxy`. This contract does not
 * inherit from that interface, and instead `upgradeToAndCall` is implicitly implemented using a custom dispatch
 * mechanism in `_fallback`. Consequently, the compiler will not produce an ABI for this contract. This is necessary to
 * fully implement transparency without decoding reverts caused by selector clashes between the proxy and the
 * implementation.
 *
 * NOTE: This proxy does not inherit from {Context} deliberately. The {ProxyAdmin} of this contract won't send a
 * meta-transaction in any way, and any other meta-transaction setup should be made in the implementation contract.
 *
 * IMPORTANT: This contract avoids unnecessary storage reads by setting the admin only during construction as an
 * immutable variable, preventing any changes thereafter. However, the admin slot defined in ERC-1967 can still be
 * overwritten by the implementation logic pointed to by this proxy. In such cases, the contract may end up in an
 * undesirable state where the admin slot is different from the actual admin.
 *
 * WARNING: It is not recommended to extend this contract to add additional external functions. If you do so, the
 * compiler will not check that there are no selector conflicts, due to the note above. A selector clash between any new
 * function and the functions declared in {ITransparentUpgradeableProxy} will be resolved in favor of the new one. This
 * could render the `upgradeToAndCall` function inaccessible, preventing upgradeability and compromising transparency.
 */
contract TransparentUpgradeableProxy is ERC1967Proxy {
    // An immutable address for the admin to avoid unnecessary SLOADs before each call
    // at the expense of removing the ability to change the admin once it's set.
    // This is acceptable if the admin is always a ProxyAdmin instance or similar contract
    // with its own ability to transfer the permissions to another account.
    address private immutable _admin;

    /**
     * @dev The proxy caller is the current admin, and can't fallback to the proxy target.
     */
    error ProxyDeniedAdminAccess();

    /**
     * @dev Initializes an upgradeable proxy managed by an instance of a {ProxyAdmin} with an `initialOwner`,
     * backed by the implementation at `_logic`, and optionally initialized with `_data` as explained in
     * {ERC1967Proxy-constructor}.
     */
    constructor(address _logic, address initialOwner, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
        _admin = address(new ProxyAdmin(initialOwner));
        // Set the storage value and emit an event for ERC-1967 compatibility
        ERC1967Utils.changeAdmin(_proxyAdmin());
    }

    /**
     * @dev Returns the admin of this proxy.
     */
    function _proxyAdmin() internal virtual returns (address) {
        return _admin;
    }

    /**
     * @dev If caller is the admin process the call internally, otherwise transparently fallback to the proxy behavior.
     */
    function _fallback() internal virtual override {
        if (msg.sender == _proxyAdmin()) {
            if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
                revert ProxyDeniedAdminAccess();
            } else {
                _dispatchUpgradeToAndCall();
            }
        } else {
            super._fallback();
        }
    }

    /**
     * @dev Upgrade the implementation of the proxy. See {ERC1967Utils-upgradeToAndCall}.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    function _dispatchUpgradeToAndCall() private {
        (address newImplementation, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
        ERC1967Utils.upgradeToAndCall(newImplementation, data);
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Utils.sol)

pragma solidity ^0.8.20;

import {IBeacon} from "../beacon/IBeacon.sol";
import {Address} from "../../utils/Address.sol";
import {StorageSlot} from "../../utils/StorageSlot.sol";

/**
 * @dev This abstract contract provides getters and event emitting update functions for
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967] slots.
 */
library ERC1967Utils {
    // We re-declare ERC-1967 events here because they can't be used directly from IERC1967.
    // This will be fixed in Solidity 0.8.21. At that point we should remove these events.
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);

    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;

    /**
     * @dev The `implementation` of the proxy is invalid.
     */
    error ERC1967InvalidImplementation(address implementation);

    /**
     * @dev The `admin` of the proxy is invalid.
     */
    error ERC1967InvalidAdmin(address admin);

    /**
     * @dev The `beacon` of the proxy is invalid.
     */
    error ERC1967InvalidBeacon(address beacon);

    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();

    /**
     * @dev Returns the current implementation address.
     */
    function getImplementation() internal view returns (address) {
        return StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 implementation slot.
     */
    function _setImplementation(address newImplementation) private {
        if (newImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(newImplementation);
        }
        StorageSlot.getAddressSlot(IMPLEMENTATION_SLOT).value = newImplementation;
    }

    /**
     * @dev Performs implementation upgrade with additional setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-Upgraded} event.
     */
    function upgradeToAndCall(address newImplementation, bytes memory data) internal {
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);

        if (data.length > 0) {
            Address.functionDelegateCall(newImplementation, data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Storage slot with the admin of the contract.
     * This is the keccak-256 hash of "eip1967.proxy.admin" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    /**
     * @dev Returns the current admin.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103`
     */
    function getAdmin() internal view returns (address) {
        return StorageSlot.getAddressSlot(ADMIN_SLOT).value;
    }

    /**
     * @dev Stores a new address in the EIP1967 admin slot.
     */
    function _setAdmin(address newAdmin) private {
        if (newAdmin == address(0)) {
            revert ERC1967InvalidAdmin(address(0));
        }
        StorageSlot.getAddressSlot(ADMIN_SLOT).value = newAdmin;
    }

    /**
     * @dev Changes the admin of the proxy.
     *
     * Emits an {IERC1967-AdminChanged} event.
     */
    function changeAdmin(address newAdmin) internal {
        emit AdminChanged(getAdmin(), newAdmin);
        _setAdmin(newAdmin);
    }

    /**
     * @dev The storage slot of the UpgradeableBeacon contract which defines the implementation for this proxy.
     * This is the keccak-256 hash of "eip1967.proxy.beacon" subtracted by 1.
     */
    // solhint-disable-next-line private-vars-leading-underscore
    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;

    /**
     * @dev Returns the current beacon.
     */
    function getBeacon() internal view returns (address) {
        return StorageSlot.getAddressSlot(BEACON_SLOT).value;
    }

    /**
     * @dev Stores a new beacon in the EIP1967 beacon slot.
     */
    function _setBeacon(address newBeacon) private {
        if (newBeacon.code.length == 0) {
            revert ERC1967InvalidBeacon(newBeacon);
        }

        StorageSlot.getAddressSlot(BEACON_SLOT).value = newBeacon;

        address beaconImplementation = IBeacon(newBeacon).implementation();
        if (beaconImplementation.code.length == 0) {
            revert ERC1967InvalidImplementation(beaconImplementation);
        }
    }

    /**
     * @dev Change the beacon and trigger a setup call if data is nonempty.
     * This function is payable only if the setup call is performed, otherwise `msg.value` is rejected
     * to avoid stuck value in the contract.
     *
     * Emits an {IERC1967-BeaconUpgraded} event.
     *
     * CAUTION: Invoking this function has no effect on an instance of {BeaconProxy} since v5, since
     * it uses an immutable beacon without looking at the value of the ERC-1967 beacon slot for
     * efficiency.
     */
    function upgradeBeaconToAndCall(address newBeacon, bytes memory data) internal {
        _setBeacon(newBeacon);
        emit BeaconUpgraded(newBeacon);

        if (data.length > 0) {
            Address.functionDelegateCall(IBeacon(newBeacon).implementation(), data);
        } else {
            _checkNonPayable();
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (proxy/ERC1967/ERC1967Proxy.sol)

pragma solidity ^0.8.20;

import {Proxy} from "../Proxy.sol";
import {ERC1967Utils} from "./ERC1967Utils.sol";

/**
 * @dev This contract implements an upgradeable proxy. It is upgradeable because calls are delegated to an
 * implementation address that can be changed. This address is stored in storage in the location specified by
 * https://eips.ethereum.org/EIPS/eip-1967[EIP1967], so that it doesn't conflict with the storage layout of the
 * implementation behind the proxy.
 */
contract ERC1967Proxy is Proxy {
    /**
     * @dev Initializes the upgradeable proxy with an initial implementation specified by `implementation`.
     *
     * If `_data` is nonempty, it's used as data in a delegate call to `implementation`. This will typically be an
     * encoded function call, and allows initializing the storage of the proxy like a Solidity constructor.
     *
     * Requirements:
     *
     * - If `data` is empty, `msg.value` must be zero.
     */
    constructor(address implementation, bytes memory _data) payable {
        ERC1967Utils.upgradeToAndCall(implementation, _data);
    }

    /**
     * @dev Returns the current implementation address.
     *
     * TIP: To get this value clients can read directly from the storage slot shown below (specified by EIP1967) using
     * the https://eth.wiki/json-rpc/API#eth_getstorageat[`eth_getStorageAt`] RPC call.
     * `0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc`
     */
    function _implementation() internal view virtual override returns (address) {
        return ERC1967Utils.getImplementation();
    }
}// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.0.0) (interfaces/IERC1967.sol)

pragma solidity ^0.8.20;

/**
 * @dev ERC-1967: Proxy Storage Slots. This interface contains the events defined in the ERC.
 */
interface IERC1967 {
    /**
     * @dev Emitted when the implementation is upgraded.
     */
    event Upgraded(address indexed implementation);

    /**
     * @dev Emitted when the admin account has changed.
     */
    event AdminChanged(address previousAdmin, address newAdmin);

    /**
     * @dev Emitted when the beacon is changed.
     */
    event BeaconUpgraded(address indexed beacon);
}