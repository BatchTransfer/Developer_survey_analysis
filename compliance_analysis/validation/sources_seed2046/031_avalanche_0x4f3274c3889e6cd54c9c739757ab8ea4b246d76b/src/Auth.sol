// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

bytes32 constant CONFIGURATOR_ROLE = keccak256("CONFIGURATOR");
bytes32 constant AGGREGATE_VAULT_ROLE = keccak256("AGGREGATE_VAULT");
bytes32 constant REQUEST_HANDLER = keccak256("REQUEST_HANDLER");
bytes32 constant KEEPER_ROLE = keccak256("KEEPER_ROLE");
bytes32 constant EXECUTION_KEEPER = keccak256("EXECUTION_KEEPER");
bytes32 constant SWAP_KEEPER = keccak256("SWAP_KEEPER");

/// @title Auth
/// @author Umami Devs
/// @notice Simple centralized ACL
contract Auth {
    /// @dev user not authorized with given role
    error NotAuthorized(bytes32 _role, address _user);

    event RoleUpdated(bytes32 indexed role, address indexed user, bool authorized);

    bytes32 public constant AUTH_MANAGER_ROLE = keccak256("AUTH_MANAGER");
    mapping(bytes32 => mapping(address => bool)) public hasRole;

    constructor() {
        _updateRole(msg.sender, AUTH_MANAGER_ROLE, true);
    }

    function updateRole(address _user, bytes32 _role, bool _authorized) external {
        onlyRole(AUTH_MANAGER_ROLE, msg.sender);
        _updateRole(_user, _role, _authorized);
    }

    function onlyRole(bytes32 _role, address _user) public view {
        if (!hasRole[_role][_user]) {
            revert NotAuthorized(_role, _user);
        }
    }

    function _updateRole(address _user, bytes32 _role, bool _authorized) internal {
        hasRole[_role][_user] = _authorized;
        emit RoleUpdated(_role, _user, _authorized);
    }
}

/// @title GlobalACL
/// @author Umami Devs
abstract contract GlobalACL {
    Auth public immutable AUTH;

    constructor(Auth _auth) {
        require(address(_auth) != address(0), "GlobalACL: zero address");
        AUTH = _auth;
    }

    modifier onlyConfigurator() {
        AUTH.onlyRole(CONFIGURATOR_ROLE, msg.sender);
        _;
    }

    modifier onlyAggregateVault() {
        AUTH.onlyRole(AGGREGATE_VAULT_ROLE, msg.sender);
        _;
    }

    modifier onlyRequestHandler() {
        AUTH.onlyRole(REQUEST_HANDLER, msg.sender);
        _;
    }

    modifier onlyExecutionKeeper() {
        AUTH.onlyRole(EXECUTION_KEEPER, msg.sender);
        _;
    }

    modifier onlyRole(bytes32 _role) {
        AUTH.onlyRole(_role, msg.sender);
        _;
    }
}
