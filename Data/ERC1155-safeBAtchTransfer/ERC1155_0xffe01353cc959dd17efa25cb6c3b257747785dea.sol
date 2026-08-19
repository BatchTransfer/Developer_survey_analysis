// File: @chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface AggregatorV3Interface {
  function decimals() external view returns (uint8);

  function description() external view returns (string memory);

  function version() external view returns (uint256);

  function getRoundData(uint80 _roundId)
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );

  function latestRoundData()
    external
    view
    returns (
      uint80 roundId,
      int256 answer,
      uint256 startedAt,
      uint256 updatedAt,
      uint80 answeredInRound
    );
}


// File: @chainlink/contracts/src/v0.8/interfaces/ERC677ReceiverInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

interface ERC677ReceiverInterface {
  function onTokenTransfer(
    address sender,
    uint256 amount,
    bytes calldata data
  ) external;
}


// File: @chainlink/contracts/src/v0.8/interfaces/LinkTokenInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface LinkTokenInterface {
  function allowance(address owner, address spender) external view returns (uint256 remaining);

  function approve(address spender, uint256 value) external returns (bool success);

  function balanceOf(address owner) external view returns (uint256 balance);

  function decimals() external view returns (uint8 decimalPlaces);

  function decreaseApproval(address spender, uint256 addedValue) external returns (bool success);

  function increaseApproval(address spender, uint256 subtractedValue) external;

  function name() external view returns (string memory tokenName);

  function symbol() external view returns (string memory tokenSymbol);

  function totalSupply() external view returns (uint256 totalTokensIssued);

  function transfer(address to, uint256 value) external returns (bool success);

  function transferAndCall(
    address to,
    uint256 value,
    bytes calldata data
  ) external returns (bool success);

  function transferFrom(
    address from,
    address to,
    uint256 value
  ) external returns (bool success);
}


// File: @chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFCoordinatorV2Interface {
  /**
   * @notice Get configuration relevant for making requests
   * @return minimumRequestConfirmations global min for request confirmations
   * @return maxGasLimit global max for request gas limit
   * @return s_provingKeyHashes list of registered key hashes
   */
  function getRequestConfig()
    external
    view
    returns (
      uint16,
      uint32,
      bytes32[] memory
    );

  /**
   * @notice Request a set of random words.
   * @param keyHash - Corresponds to a particular oracle job which uses
   * that key for generating the VRF proof. Different keyHash's have different gas price
   * ceilings, so you can select a specific one to bound your maximum per request cost.
   * @param subId  - The ID of the VRF subscription. Must be funded
   * with the minimum subscription balance required for the selected keyHash.
   * @param minimumRequestConfirmations - How many blocks you'd like the
   * oracle to wait before responding to the request. See SECURITY CONSIDERATIONS
   * for why you may want to request more. The acceptable range is
   * [minimumRequestBlockConfirmations, 200].
   * @param callbackGasLimit - How much gas you'd like to receive in your
   * fulfillRandomWords callback. Note that gasleft() inside fulfillRandomWords
   * may be slightly less than this amount because of gas used calling the function
   * (argument decoding etc.), so you may need to request slightly more than you expect
   * to have inside fulfillRandomWords. The acceptable range is
   * [0, maxGasLimit]
   * @param numWords - The number of uint256 random values you'd like to receive
   * in your fulfillRandomWords callback. Note these numbers are expanded in a
   * secure way by the VRFCoordinator from a single random value supplied by the oracle.
   * @return requestId - A unique identifier of the request. Can be used to match
   * a request to a response in fulfillRandomWords.
   */
  function requestRandomWords(
    bytes32 keyHash,
    uint64 subId,
    uint16 minimumRequestConfirmations,
    uint32 callbackGasLimit,
    uint32 numWords
  ) external returns (uint256 requestId);

  /**
   * @notice Create a VRF subscription.
   * @return subId - A unique subscription id.
   * @dev You can manage the consumer set dynamically with addConsumer/removeConsumer.
   * @dev Note to fund the subscription, use transferAndCall. For example
   * @dev  LINKTOKEN.transferAndCall(
   * @dev    address(COORDINATOR),
   * @dev    amount,
   * @dev    abi.encode(subId));
   */
  function createSubscription() external returns (uint64 subId);

  /**
   * @notice Get a VRF subscription.
   * @param subId - ID of the subscription
   * @return balance - LINK balance of the subscription in juels.
   * @return reqCount - number of requests for this subscription, determines fee tier.
   * @return owner - owner of the subscription.
   * @return consumers - list of consumer address which are able to use this subscription.
   */
  function getSubscription(uint64 subId)
    external
    view
    returns (
      uint96 balance,
      uint64 reqCount,
      address owner,
      address[] memory consumers
    );

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @param newOwner - proposed new owner of the subscription
   */
  function requestSubscriptionOwnerTransfer(uint64 subId, address newOwner) external;

  /**
   * @notice Request subscription owner transfer.
   * @param subId - ID of the subscription
   * @dev will revert if original owner of subId has
   * not requested that msg.sender become the new owner.
   */
  function acceptSubscriptionOwnerTransfer(uint64 subId) external;

  /**
   * @notice Add a consumer to a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - New consumer which can use the subscription
   */
  function addConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Remove a consumer from a VRF subscription.
   * @param subId - ID of the subscription
   * @param consumer - Consumer to remove from the subscription
   */
  function removeConsumer(uint64 subId, address consumer) external;

  /**
   * @notice Cancel a subscription
   * @param subId - ID of the subscription
   * @param to - Where to send the remaining LINK to
   */
  function cancelSubscription(uint64 subId, address to) external;

  /*
   * @notice Check to see if there exists a request commitment consumers
   * for all consumers and keyhashes for a given sub.
   * @param subId - ID of the subscription
   * @return true if there exists at least one unfulfilled request for the subscription, false
   * otherwise.
   */
  function pendingRequestExists(uint64 subId) external view returns (bool);
}


// File: @chainlink/contracts/src/v0.8/interfaces/VRFV2WrapperInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface VRFV2WrapperInterface {
  /**
   * @return the request ID of the most recent VRF V2 request made by this wrapper. This should only
   * be relied option within the same transaction that the request was made.
   */
  function lastRequestId() external view returns (uint256);

  /**
   * @notice Calculates the price of a VRF request with the given callbackGasLimit at the current
   * @notice block.
   *
   * @dev This function relies on the transaction gas price which is not automatically set during
   * @dev simulation. To estimate the price at a specific gas price, use the estimatePrice function.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   */
  function calculateRequestPrice(uint32 _callbackGasLimit) external view returns (uint256);

  /**
   * @notice Estimates the price of a VRF request with a specific gas limit and gas price.
   *
   * @dev This is a convenience function that can be called in simulation to better understand
   * @dev pricing.
   *
   * @param _callbackGasLimit is the gas limit used to estimate the price.
   * @param _requestGasPriceWei is the gas price in wei used for the estimation.
   */
  function estimateRequestPrice(uint32 _callbackGasLimit, uint256 _requestGasPriceWei) external view returns (uint256);
}


// File: @chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces/LinkTokenInterface.sol";
import "./interfaces/VRFV2WrapperInterface.sol";

/** *******************************************************************************
 * @notice Interface for contracts using VRF randomness through the VRF V2 wrapper
 * ********************************************************************************
 * @dev PURPOSE
 *
 * @dev Create VRF V2 requests without the need for subscription management. Rather than creating
 * @dev and funding a VRF V2 subscription, a user can use this wrapper to create one off requests,
 * @dev paying up front rather than at fulfillment.
 *
 * @dev Since the price is determined using the gas price of the request transaction rather than
 * @dev the fulfillment transaction, the wrapper charges an additional premium on callback gas
 * @dev usage, in addition to some extra overhead costs associated with the VRFV2Wrapper contract.
 * *****************************************************************************
 * @dev USAGE
 *
 * @dev Calling contracts must inherit from VRFV2WrapperConsumerBase. The consumer must be funded
 * @dev with enough LINK to make the request, otherwise requests will revert. To request randomness,
 * @dev call the 'requestRandomness' function with the desired VRF parameters. This function handles
 * @dev paying for the request based on the current pricing.
 *
 * @dev Consumers must implement the fullfillRandomWords function, which will be called during
 * @dev fulfillment with the randomness result.
 */
abstract contract VRFV2WrapperConsumerBase {
  LinkTokenInterface internal immutable LINK;
  VRFV2WrapperInterface internal immutable VRF_V2_WRAPPER;

  /**
   * @param _link is the address of LinkToken
   * @param _vrfV2Wrapper is the address of the VRFV2Wrapper contract
   */
  constructor(address _link, address _vrfV2Wrapper) {
    LINK = LinkTokenInterface(_link);
    VRF_V2_WRAPPER = VRFV2WrapperInterface(_vrfV2Wrapper);
  }

  /**
   * @dev Requests randomness from the VRF V2 wrapper.
   *
   * @param _callbackGasLimit is the gas limit that should be used when calling the consumer's
   *        fulfillRandomWords function.
   * @param _requestConfirmations is the number of confirmations to wait before fulfilling the
   *        request. A higher number of confirmations increases security by reducing the likelihood
   *        that a chain re-org changes a published randomness outcome.
   * @param _numWords is the number of random words to request.
   *
   * @return requestId is the VRF V2 request ID of the newly created randomness request.
   */
  function requestRandomness(
    uint32 _callbackGasLimit,
    uint16 _requestConfirmations,
    uint32 _numWords
  ) internal returns (uint256 requestId) {
    LINK.transferAndCall(
      address(VRF_V2_WRAPPER),
      VRF_V2_WRAPPER.calculateRequestPrice(_callbackGasLimit),
      abi.encode(_callbackGasLimit, _requestConfirmations, _numWords)
    );
    return VRF_V2_WRAPPER.lastRequestId();
  }

  /**
   * @notice fulfillRandomWords handles the VRF V2 wrapper response. The consuming contract must
   * @notice implement it.
   *
   * @param _requestId is the VRF V2 request ID.
   * @param _randomWords is the randomness result.
   */
  function fulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) internal virtual;

  function rawFulfillRandomWords(uint256 _requestId, uint256[] memory _randomWords) external {
    require(msg.sender == address(VRF_V2_WRAPPER), "only VRF V2 wrapper can fulfill");
    fulfillRandomWords(_requestId, _randomWords);
  }
}


// File: @openzeppelin/contracts/access/AccessControl.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (access/AccessControl.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";
import "../utils/Context.sol";
import "../utils/Strings.sol";
import "../utils/introspection/ERC165.sol";

/**
 * @dev Contract module that allows children to implement role-based access
 * control mechanisms. This is a lightweight version that doesn't allow enumerating role
 * members except through off-chain means by accessing the contract event logs. Some
 * applications may benefit from on-chain enumerability, for those cases see
 * {AccessControlEnumerable}.
 *
 * Roles are referred to by their `bytes32` identifier. These should be exposed
 * in the external API and be unique. The best way to achieve this is by
 * using `public constant` hash digests:
 *
 * ```solidity
 * bytes32 public constant MY_ROLE = keccak256("MY_ROLE");
 * ```
 *
 * Roles can be used to represent a set of permissions. To restrict access to a
 * function call, use {hasRole}:
 *
 * ```solidity
 * function foo() public {
 *     require(hasRole(MY_ROLE, msg.sender));
 *     ...
 * }
 * ```
 *
 * Roles can be granted and revoked dynamically via the {grantRole} and
 * {revokeRole} functions. Each role has an associated admin role, and only
 * accounts that have a role's admin role can call {grantRole} and {revokeRole}.
 *
 * By default, the admin role for all roles is `DEFAULT_ADMIN_ROLE`, which means
 * that only accounts with this role will be able to grant or revoke other
 * roles. More complex role relationships can be created by using
 * {_setRoleAdmin}.
 *
 * WARNING: The `DEFAULT_ADMIN_ROLE` is also its own admin: it has permission to
 * grant and revoke this role. Extra precautions should be taken to secure
 * accounts that have been granted it. We recommend using {AccessControlDefaultAdminRules}
 * to enforce additional security measures for this role.
 */
abstract contract AccessControl is Context, IAccessControl, ERC165 {
    struct RoleData {
        mapping(address => bool) members;
        bytes32 adminRole;
    }

    mapping(bytes32 => RoleData) private _roles;

    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;

    /**
     * @dev Modifier that checks that an account has a specific role. Reverts
     * with a standardized message including the required role.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     *
     * _Available since v4.1._
     */
    modifier onlyRole(bytes32 role) {
        _checkRole(role);
        _;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControl).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) public view virtual override returns (bool) {
        return _roles[role].members[account];
    }

    /**
     * @dev Revert with a standard message if `_msgSender()` is missing `role`.
     * Overriding this function changes the behavior of the {onlyRole} modifier.
     *
     * Format of the revert message is described in {_checkRole}.
     *
     * _Available since v4.6._
     */
    function _checkRole(bytes32 role) internal view virtual {
        _checkRole(role, _msgSender());
    }

    /**
     * @dev Revert with a standard message if `account` is missing `role`.
     *
     * The format of the revert reason is given by the following regular expression:
     *
     *  /^AccessControl: account (0x[0-9a-f]{40}) is missing role (0x[0-9a-f]{64})$/
     */
    function _checkRole(bytes32 role, address account) internal view virtual {
        if (!hasRole(role, account)) {
            revert(
                string(
                    abi.encodePacked(
                        "AccessControl: account ",
                        Strings.toHexString(account),
                        " is missing role ",
                        Strings.toHexString(uint256(role), 32)
                    )
                )
            );
        }
    }

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) public view virtual override returns (bytes32) {
        return _roles[role].adminRole;
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleGranted} event.
     */
    function grantRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _grantRole(role, account);
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     *
     * May emit a {RoleRevoked} event.
     */
    function revokeRole(bytes32 role, address account) public virtual override onlyRole(getRoleAdmin(role)) {
        _revokeRole(role, account);
    }

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been revoked `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     *
     * May emit a {RoleRevoked} event.
     */
    function renounceRole(bytes32 role, address account) public virtual override {
        require(account == _msgSender(), "AccessControl: can only renounce roles for self");

        _revokeRole(role, account);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event. Note that unlike {grantRole}, this function doesn't perform any
     * checks on the calling account.
     *
     * May emit a {RoleGranted} event.
     *
     * [WARNING]
     * ====
     * This function should only be called from the constructor when setting
     * up the initial roles for the system.
     *
     * Using this function in any other way is effectively circumventing the admin
     * system imposed by {AccessControl}.
     * ====
     *
     * NOTE: This function is deprecated in favor of {_grantRole}.
     */
    function _setupRole(bytes32 role, address account) internal virtual {
        _grantRole(role, account);
    }

    /**
     * @dev Sets `adminRole` as ``role``'s admin role.
     *
     * Emits a {RoleAdminChanged} event.
     */
    function _setRoleAdmin(bytes32 role, bytes32 adminRole) internal virtual {
        bytes32 previousAdminRole = getRoleAdmin(role);
        _roles[role].adminRole = adminRole;
        emit RoleAdminChanged(role, previousAdminRole, adminRole);
    }

    /**
     * @dev Grants `role` to `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleGranted} event.
     */
    function _grantRole(bytes32 role, address account) internal virtual {
        if (!hasRole(role, account)) {
            _roles[role].members[account] = true;
            emit RoleGranted(role, account, _msgSender());
        }
    }

    /**
     * @dev Revokes `role` from `account`.
     *
     * Internal function without access restriction.
     *
     * May emit a {RoleRevoked} event.
     */
    function _revokeRole(bytes32 role, address account) internal virtual {
        if (hasRole(role, account)) {
            _roles[role].members[account] = false;
            emit RoleRevoked(role, account, _msgSender());
        }
    }
}


// File: @openzeppelin/contracts/access/AccessControlEnumerable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (access/AccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControlEnumerable.sol";
import "./AccessControl.sol";
import "../utils/structs/EnumerableSet.sol";

/**
 * @dev Extension of {AccessControl} that allows enumerating the members of each role.
 */
abstract contract AccessControlEnumerable is IAccessControlEnumerable, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(bytes32 => EnumerableSet.AddressSet) private _roleMembers;

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IAccessControlEnumerable).interfaceId || super.supportsInterface(interfaceId);
    }

    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) public view virtual override returns (address) {
        return _roleMembers[role].at(index);
    }

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) public view virtual override returns (uint256) {
        return _roleMembers[role].length();
    }

    /**
     * @dev Overload {_grantRole} to track enumerable memberships
     */
    function _grantRole(bytes32 role, address account) internal virtual override {
        super._grantRole(role, account);
        _roleMembers[role].add(account);
    }

    /**
     * @dev Overload {_revokeRole} to track enumerable memberships
     */
    function _revokeRole(bytes32 role, address account) internal virtual override {
        super._revokeRole(role, account);
        _roleMembers[role].remove(account);
    }
}


// File: @openzeppelin/contracts/access/IAccessControl.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControl.sol)

pragma solidity ^0.8.0;

/**
 * @dev External interface of AccessControl declared to support ERC165 detection.
 */
interface IAccessControl {
    /**
     * @dev Emitted when `newAdminRole` is set as ``role``'s admin role, replacing `previousAdminRole`
     *
     * `DEFAULT_ADMIN_ROLE` is the starting admin for all roles, despite
     * {RoleAdminChanged} not being emitted signaling this.
     *
     * _Available since v3.1._
     */
    event RoleAdminChanged(bytes32 indexed role, bytes32 indexed previousAdminRole, bytes32 indexed newAdminRole);

    /**
     * @dev Emitted when `account` is granted `role`.
     *
     * `sender` is the account that originated the contract call, an admin role
     * bearer except when using {AccessControl-_setupRole}.
     */
    event RoleGranted(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Emitted when `account` is revoked `role`.
     *
     * `sender` is the account that originated the contract call:
     *   - if using `revokeRole`, it is the admin role bearer
     *   - if using `renounceRole`, it is the role bearer (i.e. `account`)
     */
    event RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender);

    /**
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(bytes32 role, address account) external view returns (bool);

    /**
     * @dev Returns the admin role that controls `role`. See {grantRole} and
     * {revokeRole}.
     *
     * To change a role's admin, use {AccessControl-_setRoleAdmin}.
     */
    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    /**
     * @dev Grants `role` to `account`.
     *
     * If `account` had not been already granted `role`, emits a {RoleGranted}
     * event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from `account`.
     *
     * If `account` had been granted `role`, emits a {RoleRevoked} event.
     *
     * Requirements:
     *
     * - the caller must have ``role``'s admin role.
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @dev Revokes `role` from the calling account.
     *
     * Roles are often managed via {grantRole} and {revokeRole}: this function's
     * purpose is to provide a mechanism for accounts to lose their privileges
     * if they are compromised (such as when a trusted device is misplaced).
     *
     * If the calling account had been granted `role`, emits a {RoleRevoked}
     * event.
     *
     * Requirements:
     *
     * - the caller must be `account`.
     */
    function renounceRole(bytes32 role, address account) external;
}


// File: @openzeppelin/contracts/access/IAccessControlEnumerable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (access/IAccessControlEnumerable.sol)

pragma solidity ^0.8.0;

import "./IAccessControl.sol";

/**
 * @dev External interface of AccessControlEnumerable declared to support ERC165 detection.
 */
interface IAccessControlEnumerable is IAccessControl {
    /**
     * @dev Returns one of the accounts that have `role`. `index` must be a
     * value between 0 and {getRoleMemberCount}, non-inclusive.
     *
     * Role bearers are not sorted in any particular way, and their ordering may
     * change at any point.
     *
     * WARNING: When using {getRoleMember} and {getRoleMemberCount}, make sure
     * you perform all queries on the same block. See the following
     * https://forum.openzeppelin.com/t/iterating-over-elements-on-enumerableset-in-openzeppelin-contracts/2296[forum post]
     * for more information.
     */
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    /**
     * @dev Returns the number of accounts that have `role`. Can be used
     * together with {getRoleMember} to enumerate all bearers of a role.
     */
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
}


// File: @openzeppelin/contracts/security/Pausable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.7.0) (security/Pausable.sol)

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
     * @dev Modifier to make a function callable only when the contract is not paused.
     *
     * Requirements:
     *
     * - The contract must not be paused.
     */
    modifier whenNotPaused() {
        _requireNotPaused();
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
        _requirePaused();
        _;
    }

    /**
     * @dev Returns true if the contract is paused, and false otherwise.
     */
    function paused() public view virtual returns (bool) {
        return _paused;
    }

    /**
     * @dev Throws if the contract is paused.
     */
    function _requireNotPaused() internal view virtual {
        require(!paused(), "Pausable: paused");
    }

    /**
     * @dev Throws if the contract is not paused.
     */
    function _requirePaused() internal view virtual {
        require(paused(), "Pausable: not paused");
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


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155.sol";
import "./IERC1155Receiver.sol";
import "./extensions/IERC1155MetadataURI.sol";
import "../../utils/Address.sol";
import "../../utils/Context.sol";
import "../../utils/introspection/ERC165.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155 is Context, ERC165, IERC1155, IERC1155MetadataURI {
    using Address for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    constructor(string memory uri_) {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IERC1155).interfaceId ||
            interfaceId == type(IERC1155MetadataURI).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC1155MetadataURI-uri}.
     *
     * This implementation returns the same URI for *all* token types. It relies
     * on the token type ID substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * Clients calling this function must replace the `\{id\}` substring with the
     * actual token type ID.
     */
    function uri(uint256) public view virtual override returns (string memory) {
        return _uri;
    }

    /**
     * @dev See {IERC1155-balanceOf}.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function balanceOf(address account, uint256 id) public view virtual override returns (uint256) {
        require(account != address(0), "ERC1155: address zero is not a valid owner");
        return _balances[id][account];
    }

    /**
     * @dev See {IERC1155-balanceOfBatch}.
     *
     * Requirements:
     *
     * - `accounts` and `ids` must have the same length.
     */
    function balanceOfBatch(
        address[] memory accounts,
        uint256[] memory ids
    ) public view virtual override returns (uint256[] memory) {
        require(accounts.length == ids.length, "ERC1155: accounts and ids length mismatch");

        uint256[] memory batchBalances = new uint256[](accounts.length);

        for (uint256 i = 0; i < accounts.length; ++i) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    /**
     * @dev See {IERC1155-setApprovalForAll}.
     */
    function setApprovalForAll(address operator, bool approved) public virtual override {
        _setApprovalForAll(_msgSender(), operator, approved);
    }

    /**
     * @dev See {IERC1155-isApprovedForAll}.
     */
    function isApprovedForAll(address account, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[account][operator];
    }

    /**
     * @dev See {IERC1155-safeTransferFrom}.
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev See {IERC1155-safeBatchTransferFrom}.
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        require(
            from == _msgSender() || isApprovedForAll(from, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );
        _safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /**
     * @dev Transfers `amount` tokens of token type `id` from `from` to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }
        _balances[id][to] += amount;

        emit TransferSingle(operator, from, to, id, amount);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, from, to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_safeTransferFrom}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");
        require(to != address(0), "ERC1155: transfer to the zero address");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: insufficient balance for transfer");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
            _balances[id][to] += amount;
        }

        emit TransferBatch(operator, from, to, ids, amounts);

        _afterTokenTransfer(operator, from, to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, from, to, ids, amounts, data);
    }

    /**
     * @dev Sets a new URI for all token types, by relying on the token type ID
     * substitution mechanism
     * https://eips.ethereum.org/EIPS/eip-1155#metadata[defined in the EIP].
     *
     * By this mechanism, any occurrence of the `\{id\}` substring in either the
     * URI or any of the amounts in the JSON file at said URI will be replaced by
     * clients with the token type ID.
     *
     * For example, the `https://token-cdn-domain/\{id\}.json` URI would be
     * interpreted by clients as
     * `https://token-cdn-domain/000000000000000000000000000000000000000000000000000000000004cce0.json`
     * for token type ID 0x4cce0.
     *
     * See {uri}.
     *
     * Because these URIs cannot be meaningfully represented by the {URI} event,
     * this function emits no events.
     */
    function _setURI(string memory newuri) internal virtual {
        _uri = newuri;
    }

    /**
     * @dev Creates `amount` tokens of token type `id`, and assigns them to `to`.
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function _mint(address to, uint256 id, uint256 amount, bytes memory data) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        _balances[id][to] += amount;
        emit TransferSingle(operator, address(0), to, id, amount);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeTransferAcceptanceCheck(operator, address(0), to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_mint}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155BatchReceived} and return the
     * acceptance magic value.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {
        require(to != address(0), "ERC1155: mint to the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, address(0), to, ids, amounts, data);

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(operator, address(0), to, ids, amounts);

        _afterTokenTransfer(operator, address(0), to, ids, amounts, data);

        _doSafeBatchTransferAcceptanceCheck(operator, address(0), to, ids, amounts, data);
    }

    /**
     * @dev Destroys `amount` tokens of token type `id` from `from`
     *
     * Emits a {TransferSingle} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `from` must have at least `amount` tokens of token type `id`.
     */
    function _burn(address from, uint256 id, uint256 amount) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");

        address operator = _msgSender();
        uint256[] memory ids = _asSingletonArray(id);
        uint256[] memory amounts = _asSingletonArray(amount);

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(operator, from, address(0), id, amount);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] version of {_burn}.
     *
     * Emits a {TransferBatch} event.
     *
     * Requirements:
     *
     * - `ids` and `amounts` must have the same length.
     */
    function _burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) internal virtual {
        require(from != address(0), "ERC1155: burn from the zero address");
        require(ids.length == amounts.length, "ERC1155: ids and amounts length mismatch");

        address operator = _msgSender();

        _beforeTokenTransfer(operator, from, address(0), ids, amounts, "");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "ERC1155: burn amount exceeds balance");
            unchecked {
                _balances[id][from] = fromBalance - amount;
            }
        }

        emit TransferBatch(operator, from, address(0), ids, amounts);

        _afterTokenTransfer(operator, from, address(0), ids, amounts, "");
    }

    /**
     * @dev Approve `operator` to operate on all of `owner` tokens
     *
     * Emits an {ApprovalForAll} event.
     */
    function _setApprovalForAll(address owner, address operator, bool approved) internal virtual {
        require(owner != operator, "ERC1155: setting approval status for self");
        _operatorApprovals[owner][operator] = approved;
        emit ApprovalForAll(owner, operator, approved);
    }

    /**
     * @dev Hook that is called before any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `ids` and `amounts` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    /**
     * @dev Hook that is called after any token transfer. This includes minting
     * and burning, as well as batched variants.
     *
     * The same hook is called on both single and batched variants. For single
     * transfers, the length of the `id` and `amount` arrays will be 1.
     *
     * Calling conditions (for each `id` and `amount` pair):
     *
     * - When `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * of token type `id` will be  transferred to `to`.
     * - When `from` is zero, `amount` tokens of token type `id` will be minted
     * for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens of token type `id`
     * will be burned.
     * - `from` and `to` are never both zero.
     * - `ids` and `amounts` have the same, non-zero length.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual {}

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155Receiver.onERC1155Received.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _doSafeBatchTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.isContract()) {
            try IERC1155Receiver(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155Receiver.onERC1155BatchReceived.selector) {
                    revert("ERC1155: ERC1155Receiver rejected tokens");
                }
            } catch Error(string memory reason) {
                revert(reason);
            } catch {
                revert("ERC1155: transfer to non-ERC1155Receiver implementer");
            }
        }
    }

    function _asSingletonArray(uint256 element) private pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](1);
        array[0] = element;

        return array;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/extensions/ERC1155Burnable.sol)

pragma solidity ^0.8.0;

import "../ERC1155.sol";

/**
 * @dev Extension of {ERC1155} that allows token holders to destroy both their
 * own tokens and those that they have been approved to use.
 *
 * _Available since v3.1._
 */
abstract contract ERC1155Burnable is ERC1155 {
    function burn(address account, uint256 id, uint256 value) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burn(account, id, value);
    }

    function burnBatch(address account, uint256[] memory ids, uint256[] memory values) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not token owner or approved"
        );

        _burnBatch(account, ids, values);
    }
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.2) (token/ERC1155/extensions/ERC1155Pausable.sol)

pragma solidity ^0.8.0;

import "../ERC1155.sol";
import "../../../security/Pausable.sol";

/**
 * @dev ERC1155 token with pausable token transfers, minting and burning.
 *
 * Useful for scenarios such as preventing trades until the end of an evaluation
 * period, or having an emergency switch for freezing all token transfers in the
 * event of a large bug.
 *
 * IMPORTANT: This contract does not include public pause and unpause functions. In
 * addition to inheriting this contract, you must define both functions, invoking the
 * {Pausable-_pause} and {Pausable-_unpause} internal functions, with appropriate
 * access control, e.g. using {AccessControl} or {Ownable}. Not doing so will
 * make the contract unpausable.
 *
 * _Available since v3.1._
 */
abstract contract ERC1155Pausable is ERC1155, Pausable {
    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        require(!paused(), "ERC1155Pausable: token transfer while paused");
    }
}


// File: @openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURI is IERC1155 {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts/token/ERC1155/IERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

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
    function balanceOfBatch(
        address[] calldata accounts,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

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
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
     * - `from` must have a balance of tokens of type `id` of at least `amount`.
     * - If `to` refers to a smart contract, it must implement {IERC1155Receiver-onERC1155Received} and return the
     * acceptance magic value.
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external;

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


// File: @openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155Receiver is IERC165 {
    /**
     * @dev Handles the receipt of a single ERC1155 token type. This function is
     * called at the end of a `safeTransferFrom` after the balance has been updated.
     *
     * NOTE: To accept the transfer, this must return
     * `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))`
     * (i.e. 0xf23a6e61, or its own function selector).
     *
     * @param operator The address which initiated the transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param id The ID of the token being transferred
     * @param value The amount of tokens being transferred
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155Received(address,address,uint256,uint256,bytes)"))` if transfer is allowed
     */
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    /**
     * @dev Handles the receipt of a multiple ERC1155 token types. This function
     * is called at the end of a `safeBatchTransferFrom` after the balances have
     * been updated.
     *
     * NOTE: To accept the transfer(s), this must return
     * `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))`
     * (i.e. 0xbc197c81, or its own function selector).
     *
     * @param operator The address which initiated the batch transfer (i.e. msg.sender)
     * @param from The address which previously owned the token
     * @param ids An array containing ids of each token being transferred (order and length must match values array)
     * @param values An array containing amounts of each token being transferred (order and length must match ids array)
     * @param data Additional data with no specified format
     * @return `bytes4(keccak256("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"))` if transfer is allowed
     */
    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/presets/ERC1155PresetMinterPauser.sol)

pragma solidity ^0.8.0;

import "../ERC1155.sol";
import "../extensions/ERC1155Burnable.sol";
import "../extensions/ERC1155Pausable.sol";
import "../../../access/AccessControlEnumerable.sol";
import "../../../utils/Context.sol";

/**
 * @dev {ERC1155} token, including:
 *
 *  - ability for holders to burn (destroy) their tokens
 *  - a minter role that allows for token minting (creation)
 *  - a pauser role that allows to stop all token transfers
 *
 * This contract uses {AccessControl} to lock permissioned functions using the
 * different roles - head to its documentation for details.
 *
 * The account that deploys the contract will be granted the minter and pauser
 * roles, as well as the default admin role, which will let it grant both minter
 * and pauser roles to other accounts.
 *
 * _Deprecated in favor of https://wizard.openzeppelin.com/[Contracts Wizard]._
 */
contract ERC1155PresetMinterPauser is Context, AccessControlEnumerable, ERC1155Burnable, ERC1155Pausable {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE`, `MINTER_ROLE`, and `PAUSER_ROLE` to the account that
     * deploys the contract.
     */
    constructor(string memory uri) ERC1155(uri) {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());

        _setupRole(MINTER_ROLE, _msgSender());
        _setupRole(PAUSER_ROLE, _msgSender());
    }

    /**
     * @dev Creates `amount` new tokens for `to`, of token type `id`.
     *
     * See {ERC1155-_mint}.
     *
     * Requirements:
     *
     * - the caller must have the `MINTER_ROLE`.
     */
    function mint(address to, uint256 id, uint256 amount, bytes memory data) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mint(to, id, amount, data);
    }

    /**
     * @dev xref:ROOT:erc1155.adoc#batch-operations[Batched] variant of {mint}.
     */
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) public virtual {
        require(hasRole(MINTER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have minter role to mint");

        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function pause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to pause");
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC1155Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the `PAUSER_ROLE`.
     */
    function unpause() public virtual {
        require(hasRole(PAUSER_ROLE, _msgSender()), "ERC1155PresetMinterPauser: must have pauser role to unpause");
        _unpause();
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerable, ERC1155) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override(ERC1155, ERC1155Pausable) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/utils/ERC1155Holder.sol)

pragma solidity ^0.8.0;

import "./ERC1155Receiver.sol";

/**
 * Simple implementation of `ERC1155Receiver` that will allow a contract to hold ERC1155 tokens.
 *
 * IMPORTANT: When inheriting this contract, you must include a way to use the received tokens, otherwise they will be
 * stuck.
 *
 * @dev _Available since v3.1._
 */
contract ERC1155Holder is ERC1155Receiver {
    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }
}


// File: @openzeppelin/contracts/token/ERC1155/utils/ERC1155Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/utils/ERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../IERC1155Receiver.sol";
import "../../../utils/introspection/ERC165.sol";

/**
 * @dev _Available since v3.1._
 */
abstract contract ERC1155Receiver is ERC165, IERC1155Receiver {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165, IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId || super.supportsInterface(interfaceId);
    }
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol
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


// File: @openzeppelin/contracts/token/ERC20/IERC20.sol
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


// File: @openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.3) (token/ERC20/utils/SafeERC20.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";
import "../extensions/IERC20Permit.sol";
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

    /**
     * @dev Transfer `value` amount of `token` from the calling contract to `to`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transfer.selector, to, value));
    }

    /**
     * @dev Transfer `value` amount of `token` from `from` to `to`, spending the approval given by `from` to the
     * calling contract. If `token` returns no value, non-reverting calls are assumed to be successful.
     */
    function safeTransferFrom(IERC20 token, address from, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeWithSelector(token.transferFrom.selector, from, to, value));
    }

    /**
     * @dev Deprecated. This function has issues similar to the ones found in
     * {IERC20-approve}, and its usage is discouraged.
     *
     * Whenever possible, use {safeIncreaseAllowance} and
     * {safeDecreaseAllowance} instead.
     */
    function safeApprove(IERC20 token, address spender, uint256 value) internal {
        // safeApprove should only be called when setting an initial allowance,
        // or when resetting it to zero. To increase and decrease it, use
        // 'safeIncreaseAllowance' and 'safeDecreaseAllowance'
        require(
            (value == 0) || (token.allowance(address(this), spender) == 0),
            "SafeERC20: approve from non-zero to non-zero allowance"
        );
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, value));
    }

    /**
     * @dev Increase the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeIncreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        uint256 oldAllowance = token.allowance(address(this), spender);
        _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance + value));
    }

    /**
     * @dev Decrease the calling contract's allowance toward `spender` by `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful.
     */
    function safeDecreaseAllowance(IERC20 token, address spender, uint256 value) internal {
        unchecked {
            uint256 oldAllowance = token.allowance(address(this), spender);
            require(oldAllowance >= value, "SafeERC20: decreased allowance below zero");
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, oldAllowance - value));
        }
    }

    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeWithSelector(token.approve.selector, spender, value);

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeWithSelector(token.approve.selector, spender, 0));
            _callOptionalReturn(token, approvalCall);
        }
    }

    /**
     * @dev Use a ERC-2612 signature to set the `owner` approval toward `spender` on `token`.
     * Revert on invalid signature.
     */
    function safePermit(
        IERC20Permit token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        uint256 nonceBefore = token.nonces(owner);
        token.permit(owner, spender, value, deadline, v, r, s);
        uint256 nonceAfter = token.nonces(owner);
        require(nonceAfter == nonceBefore + 1, "SafeERC20: permit did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data, "SafeERC20: low-level call failed");
        require(returndata.length == 0 || abi.decode(returndata, (bool)), "SafeERC20: ERC20 operation did not succeed");
    }

    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     *
     * This is a variant of {_callOptionalReturn} that silents catches all reverts and returns a bool instead.
     */
    function _callOptionalReturnBool(IERC20 token, bytes memory data) private returns (bool) {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We cannot use {Address-functionCall} here since this should return false
        // and not revert is the subcall reverts.

        (bool success, bytes memory returndata) = address(token).call(data);
        return
            success && (returndata.length == 0 || abi.decode(returndata, (bool))) && Address.isContract(address(token));
    }
}


// File: @openzeppelin/contracts/token/ERC721/IERC721.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/IERC721.sol)

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
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    /**
     * @dev Safely transfers `tokenId` token from `from` to `to`, checking first that contract recipients
     * are aware of the ERC721 protocol to prevent tokens from being forever locked.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `tokenId` token must exist and be owned by `from`.
     * - If the caller is not `from`, it must have been allowed to move this token by either {approve} or {setApprovalForAll}.
     * - If `to` refers to a smart contract, it must implement {IERC721Receiver-onERC721Received}, which is called upon a safe transfer.
     *
     * Emits a {Transfer} event.
     */
    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @dev Transfers `tokenId` token from `from` to `to`.
     *
     * WARNING: Note that the caller is responsible to confirm that the recipient is capable of receiving ERC721
     * or else they may be permanently lost. Usage of {safeTransferFrom} prevents loss, though the caller must
     * understand this adds an external call which potentially creates a reentrancy vulnerability.
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
    function transferFrom(address from, address to, uint256 tokenId) external;

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
     * @dev Approve or remove `operator` as an operator for the caller.
     * Operators can call {transferFrom} or {safeTransferFrom} for any token owned by the caller.
     *
     * Requirements:
     *
     * - The `operator` cannot be the caller.
     *
     * Emits an {ApprovalForAll} event.
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @dev Returns the account approved for `tokenId` token.
     *
     * Requirements:
     *
     * - `tokenId` must exist.
     */
    function getApproved(uint256 tokenId) external view returns (address operator);

    /**
     * @dev Returns if the `operator` is allowed to manage all of the assets of `owner`.
     *
     * See {setApprovalForAll}
     */
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}


// File: @openzeppelin/contracts/token/ERC721/IERC721Receiver.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721Receiver {
    /**
     * @dev Whenever an {IERC721} `tokenId` token is transferred to this contract via {IERC721-safeTransferFrom}
     * by `operator` from `from`, this function is called.
     *
     * It must return its Solidity selector to confirm the token transfer.
     * If any other value is returned or the interface is not implemented by the recipient, the transfer will be reverted.
     *
     * The selector can be obtained in Solidity with `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4);
}


// File: @openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721Receiver.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721Holder is IERC721Receiver {
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

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
     *
     * Furthermore, `isContract` will also return true if the target contract within
     * the same transaction is already scheduled for destruction by `SELFDESTRUCT`,
     * which only has an effect at the end of a transaction.
     * ====
     *
     * [IMPORTANT]
     * ====
     * You shouldn't rely on `isContract` to protect against flash loan attacks!
     *
     * Preventing calls from contracts is highly discouraged. It breaks composability, breaks support for smart wallets
     * like Gnosis Safe, and does not provide security since it can be circumvented by calling from a contract
     * constructor.
     * ====
     */
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize/address.code.length, which returns 0
        // for contracts in construction, since the code is only stored at the end
        // of the constructor execution.

        return account.code.length > 0;
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
     * https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/[Learn more].
     *
     * IMPORTANT: because control is transferred to `recipient`, care must be
     * taken to not create reentrancy vulnerabilities. Consider using
     * {ReentrancyGuard} or the
     * https://solidity.readthedocs.io/en/v0.8.0/security-considerations.html#use-the-checks-effects-interactions-pattern[checks-effects-interactions pattern].
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
        return functionCallWithValue(target, data, 0, "Address: low-level call failed");
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
    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
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
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.staticcall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
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
        (bool success, bytes memory returndata) = target.delegatecall(data);
        return verifyCallResultFromTarget(target, success, returndata, errorMessage);
    }

    /**
     * @dev Tool to verify that a low level call to smart-contract was successful, and revert (either by bubbling
     * the revert reason or using the provided one) in case of unsuccessful call or if target was not a contract.
     *
     * _Available since v4.8._
     */
    function verifyCallResultFromTarget(
        address target,
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                // only check isContract if the call was successful and the return data is empty
                // otherwise we already know that it was a contract
                require(isContract(target), "Address: call to non-contract");
            }
            return returndata;
        } else {
            _revert(returndata, errorMessage);
        }
    }

    /**
     * @dev Tool to verify that a low level call was successful, and revert if it wasn't, either by bubbling the
     * revert reason or using the provided one.
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
            _revert(returndata, errorMessage);
        }
    }

    function _revert(bytes memory returndata, string memory errorMessage) private pure {
        // Look for revert reason and bubble it up if present
        if (returndata.length > 0) {
            // The easiest way to bubble the revert reason is using memory via assembly
            /// @solidity memory-safe-assembly
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            revert(errorMessage);
        }
    }
}


// File: @openzeppelin/contracts/utils/Context.sol
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


// File: @openzeppelin/contracts/utils/introspection/ERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165.sol";

/**
 * @dev Implementation of the {IERC165} interface.
 *
 * Contracts that want to implement ERC165 should inherit from this contract and override {supportsInterface} to check
 * for the additional interface id that will be supported. For example:
 *
 * ```solidity
 * function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
 *     return interfaceId == type(MyInterface).interfaceId || super.supportsInterface(interfaceId);
 * }
 * ```
 *
 * Alternatively, {ERC165Storage} provides an easier to use but more expensive implementation.
 */
abstract contract ERC165 is IERC165 {
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165).interfaceId;
    }
}


// File: @openzeppelin/contracts/utils/introspection/IERC165.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/IERC165.sol)

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


// File: @openzeppelin/contracts/utils/math/Math.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/math/Math.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard math utilities missing in the Solidity language.
 */
library Math {
    enum Rounding {
        Down, // Toward negative infinity
        Up, // Toward infinity
        Zero // Toward zero
    }

    /**
     * @dev Returns the largest of two numbers.
     */
    function max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two numbers.
     */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two numbers. The result is rounded towards
     * zero.
     */
    function average(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b) / 2 can overflow.
        return (a & b) + (a ^ b) / 2;
    }

    /**
     * @dev Returns the ceiling of the division of two numbers.
     *
     * This differs from standard division with `/` in that it rounds up instead
     * of rounding down.
     */
    function ceilDiv(uint256 a, uint256 b) internal pure returns (uint256) {
        // (a + b - 1) / b can overflow on addition, so we distribute.
        return a == 0 ? 0 : (a - 1) / b + 1;
    }

    /**
     * @notice Calculates floor(x * y / denominator) with full precision. Throws if result overflows a uint256 or denominator == 0
     * @dev Original credit to Remco Bloemen under MIT license (https://xn--2-umb.com/21/muldiv)
     * with further edits by Uniswap Labs also under MIT license.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator) internal pure returns (uint256 result) {
        unchecked {
            // 512-bit multiply [prod1 prod0] = x * y. Compute the product mod 2^256 and mod 2^256 - 1, then use
            // use the Chinese Remainder Theorem to reconstruct the 512 bit result. The result is stored in two 256
            // variables such that product = prod1 * 2^256 + prod0.
            uint256 prod0; // Least significant 256 bits of the product
            uint256 prod1; // Most significant 256 bits of the product
            assembly {
                let mm := mulmod(x, y, not(0))
                prod0 := mul(x, y)
                prod1 := sub(sub(mm, prod0), lt(mm, prod0))
            }

            // Handle non-overflow cases, 256 by 256 division.
            if (prod1 == 0) {
                // Solidity will revert if denominator == 0, unlike the div opcode on its own.
                // The surrounding unchecked block does not change this fact.
                // See https://docs.soliditylang.org/en/latest/control-structures.html#checked-or-unchecked-arithmetic.
                return prod0 / denominator;
            }

            // Make sure the result is less than 2^256. Also prevents denominator == 0.
            require(denominator > prod1, "Math: mulDiv overflow");

            ///////////////////////////////////////////////
            // 512 by 256 division.
            ///////////////////////////////////////////////

            // Make division exact by subtracting the remainder from [prod1 prod0].
            uint256 remainder;
            assembly {
                // Compute remainder using mulmod.
                remainder := mulmod(x, y, denominator)

                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
            }

            // Factor powers of two out of denominator and compute largest power of two divisor of denominator. Always >= 1.
            // See https://cs.stackexchange.com/q/138556/92363.

            // Does not overflow because the denominator cannot be zero at this stage in the function.
            uint256 twos = denominator & (~denominator + 1);
            assembly {
                // Divide denominator by twos.
                denominator := div(denominator, twos)

                // Divide [prod1 prod0] by twos.
                prod0 := div(prod0, twos)

                // Flip twos such that it is 2^256 / twos. If twos is zero, then it becomes one.
                twos := add(div(sub(0, twos), twos), 1)
            }

            // Shift in bits from prod1 into prod0.
            prod0 |= prod1 * twos;

            // Invert denominator mod 2^256. Now that denominator is an odd number, it has an inverse modulo 2^256 such
            // that denominator * inv = 1 mod 2^256. Compute the inverse by starting with a seed that is correct for
            // four bits. That is, denominator * inv = 1 mod 2^4.
            uint256 inverse = (3 * denominator) ^ 2;

            // Use the Newton-Raphson iteration to improve the precision. Thanks to Hensel's lifting lemma, this also works
            // in modular arithmetic, doubling the correct bits in each step.
            inverse *= 2 - denominator * inverse; // inverse mod 2^8
            inverse *= 2 - denominator * inverse; // inverse mod 2^16
            inverse *= 2 - denominator * inverse; // inverse mod 2^32
            inverse *= 2 - denominator * inverse; // inverse mod 2^64
            inverse *= 2 - denominator * inverse; // inverse mod 2^128
            inverse *= 2 - denominator * inverse; // inverse mod 2^256

            // Because the division is now exact we can divide by multiplying with the modular inverse of denominator.
            // This will give us the correct result modulo 2^256. Since the preconditions guarantee that the outcome is
            // less than 2^256, this is the final result. We don't need to compute the high bits of the result and prod1
            // is no longer required.
            result = prod0 * inverse;
            return result;
        }
    }

    /**
     * @notice Calculates x * y / denominator with full precision, following the selected rounding direction.
     */
    function mulDiv(uint256 x, uint256 y, uint256 denominator, Rounding rounding) internal pure returns (uint256) {
        uint256 result = mulDiv(x, y, denominator);
        if (rounding == Rounding.Up && mulmod(x, y, denominator) > 0) {
            result += 1;
        }
        return result;
    }

    /**
     * @dev Returns the square root of a number. If the number is not a perfect square, the value is rounded down.
     *
     * Inspired by Henry S. Warren, Jr.'s "Hacker's Delight" (Chapter 11).
     */
    function sqrt(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        // For our first guess, we get the biggest power of 2 which is smaller than the square root of the target.
        //
        // We know that the "msb" (most significant bit) of our target number `a` is a power of 2 such that we have
        // `msb(a) <= a < 2*msb(a)`. This value can be written `msb(a)=2**k` with `k=log2(a)`.
        //
        // This can be rewritten `2**log2(a) <= a < 2**(log2(a) + 1)`
        // → `sqrt(2**k) <= sqrt(a) < sqrt(2**(k+1))`
        // → `2**(k/2) <= sqrt(a) < 2**((k+1)/2) <= 2**(k/2 + 1)`
        //
        // Consequently, `2**(log2(a) / 2)` is a good first approximation of `sqrt(a)` with at least 1 correct bit.
        uint256 result = 1 << (log2(a) >> 1);

        // At this point `result` is an estimation with one bit of precision. We know the true value is a uint128,
        // since it is the square root of a uint256. Newton's method converges quadratically (precision doubles at
        // every iteration). We thus need at most 7 iteration to turn our partial result with one bit of precision
        // into the expected uint128 result.
        unchecked {
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            result = (result + a / result) >> 1;
            return min(result, a / result);
        }
    }

    /**
     * @notice Calculates sqrt(a), following the selected rounding direction.
     */
    function sqrt(uint256 a, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = sqrt(a);
            return result + (rounding == Rounding.Up && result * result < a ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 2, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 2, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log2(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log2(value);
            return result + (rounding == Rounding.Up && 1 << result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 10, rounded down, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >= 10 ** 64) {
                value /= 10 ** 64;
                result += 64;
            }
            if (value >= 10 ** 32) {
                value /= 10 ** 32;
                result += 32;
            }
            if (value >= 10 ** 16) {
                value /= 10 ** 16;
                result += 16;
            }
            if (value >= 10 ** 8) {
                value /= 10 ** 8;
                result += 8;
            }
            if (value >= 10 ** 4) {
                value /= 10 ** 4;
                result += 4;
            }
            if (value >= 10 ** 2) {
                value /= 10 ** 2;
                result += 2;
            }
            if (value >= 10 ** 1) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 10, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log10(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log10(value);
            return result + (rounding == Rounding.Up && 10 ** result < value ? 1 : 0);
        }
    }

    /**
     * @dev Return the log in base 256, rounded down, of a positive value.
     * Returns 0 if given 0.
     *
     * Adding one to the result gives the number of pairs of hex symbols needed to represent `value` as a hex string.
     */
    function log256(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 16;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 8;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 4;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 2;
            }
            if (value >> 8 > 0) {
                result += 1;
            }
        }
        return result;
    }

    /**
     * @dev Return the log in base 256, following the selected rounding direction, of a positive value.
     * Returns 0 if given 0.
     */
    function log256(uint256 value, Rounding rounding) internal pure returns (uint256) {
        unchecked {
            uint256 result = log256(value);
            return result + (rounding == Rounding.Up && 1 << (result << 3) < value ? 1 : 0);
        }
    }
}


// File: @openzeppelin/contracts/utils/math/SafeCast.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SafeCast.sol)
// This file was procedurally generated from scripts/generate/templates/SafeCast.js.

pragma solidity ^0.8.0;

/**
 * @dev Wrappers over Solidity's uintXX/intXX casting operators with added overflow
 * checks.
 *
 * Downcasting from uint256/int256 in Solidity does not revert on overflow. This can
 * easily result in undesired exploitation or bugs, since developers usually
 * assume that overflows raise errors. `SafeCast` restores this intuition by
 * reverting the transaction when such an operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 *
 * Can be combined with {SafeMath} and {SignedSafeMath} to extend it to smaller types, by performing
 * all math on `uint256` and `int256` and then downcasting.
 */
library SafeCast {
    /**
     * @dev Returns the downcasted uint248 from uint256, reverting on
     * overflow (when the input is greater than largest uint248).
     *
     * Counterpart to Solidity's `uint248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toUint248(uint256 value) internal pure returns (uint248) {
        require(value <= type(uint248).max, "SafeCast: value doesn't fit in 248 bits");
        return uint248(value);
    }

    /**
     * @dev Returns the downcasted uint240 from uint256, reverting on
     * overflow (when the input is greater than largest uint240).
     *
     * Counterpart to Solidity's `uint240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toUint240(uint256 value) internal pure returns (uint240) {
        require(value <= type(uint240).max, "SafeCast: value doesn't fit in 240 bits");
        return uint240(value);
    }

    /**
     * @dev Returns the downcasted uint232 from uint256, reverting on
     * overflow (when the input is greater than largest uint232).
     *
     * Counterpart to Solidity's `uint232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toUint232(uint256 value) internal pure returns (uint232) {
        require(value <= type(uint232).max, "SafeCast: value doesn't fit in 232 bits");
        return uint232(value);
    }

    /**
     * @dev Returns the downcasted uint224 from uint256, reverting on
     * overflow (when the input is greater than largest uint224).
     *
     * Counterpart to Solidity's `uint224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.2._
     */
    function toUint224(uint256 value) internal pure returns (uint224) {
        require(value <= type(uint224).max, "SafeCast: value doesn't fit in 224 bits");
        return uint224(value);
    }

    /**
     * @dev Returns the downcasted uint216 from uint256, reverting on
     * overflow (when the input is greater than largest uint216).
     *
     * Counterpart to Solidity's `uint216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toUint216(uint256 value) internal pure returns (uint216) {
        require(value <= type(uint216).max, "SafeCast: value doesn't fit in 216 bits");
        return uint216(value);
    }

    /**
     * @dev Returns the downcasted uint208 from uint256, reverting on
     * overflow (when the input is greater than largest uint208).
     *
     * Counterpart to Solidity's `uint208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toUint208(uint256 value) internal pure returns (uint208) {
        require(value <= type(uint208).max, "SafeCast: value doesn't fit in 208 bits");
        return uint208(value);
    }

    /**
     * @dev Returns the downcasted uint200 from uint256, reverting on
     * overflow (when the input is greater than largest uint200).
     *
     * Counterpart to Solidity's `uint200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toUint200(uint256 value) internal pure returns (uint200) {
        require(value <= type(uint200).max, "SafeCast: value doesn't fit in 200 bits");
        return uint200(value);
    }

    /**
     * @dev Returns the downcasted uint192 from uint256, reverting on
     * overflow (when the input is greater than largest uint192).
     *
     * Counterpart to Solidity's `uint192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toUint192(uint256 value) internal pure returns (uint192) {
        require(value <= type(uint192).max, "SafeCast: value doesn't fit in 192 bits");
        return uint192(value);
    }

    /**
     * @dev Returns the downcasted uint184 from uint256, reverting on
     * overflow (when the input is greater than largest uint184).
     *
     * Counterpart to Solidity's `uint184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toUint184(uint256 value) internal pure returns (uint184) {
        require(value <= type(uint184).max, "SafeCast: value doesn't fit in 184 bits");
        return uint184(value);
    }

    /**
     * @dev Returns the downcasted uint176 from uint256, reverting on
     * overflow (when the input is greater than largest uint176).
     *
     * Counterpart to Solidity's `uint176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toUint176(uint256 value) internal pure returns (uint176) {
        require(value <= type(uint176).max, "SafeCast: value doesn't fit in 176 bits");
        return uint176(value);
    }

    /**
     * @dev Returns the downcasted uint168 from uint256, reverting on
     * overflow (when the input is greater than largest uint168).
     *
     * Counterpart to Solidity's `uint168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toUint168(uint256 value) internal pure returns (uint168) {
        require(value <= type(uint168).max, "SafeCast: value doesn't fit in 168 bits");
        return uint168(value);
    }

    /**
     * @dev Returns the downcasted uint160 from uint256, reverting on
     * overflow (when the input is greater than largest uint160).
     *
     * Counterpart to Solidity's `uint160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toUint160(uint256 value) internal pure returns (uint160) {
        require(value <= type(uint160).max, "SafeCast: value doesn't fit in 160 bits");
        return uint160(value);
    }

    /**
     * @dev Returns the downcasted uint152 from uint256, reverting on
     * overflow (when the input is greater than largest uint152).
     *
     * Counterpart to Solidity's `uint152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toUint152(uint256 value) internal pure returns (uint152) {
        require(value <= type(uint152).max, "SafeCast: value doesn't fit in 152 bits");
        return uint152(value);
    }

    /**
     * @dev Returns the downcasted uint144 from uint256, reverting on
     * overflow (when the input is greater than largest uint144).
     *
     * Counterpart to Solidity's `uint144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toUint144(uint256 value) internal pure returns (uint144) {
        require(value <= type(uint144).max, "SafeCast: value doesn't fit in 144 bits");
        return uint144(value);
    }

    /**
     * @dev Returns the downcasted uint136 from uint256, reverting on
     * overflow (when the input is greater than largest uint136).
     *
     * Counterpart to Solidity's `uint136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toUint136(uint256 value) internal pure returns (uint136) {
        require(value <= type(uint136).max, "SafeCast: value doesn't fit in 136 bits");
        return uint136(value);
    }

    /**
     * @dev Returns the downcasted uint128 from uint256, reverting on
     * overflow (when the input is greater than largest uint128).
     *
     * Counterpart to Solidity's `uint128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v2.5._
     */
    function toUint128(uint256 value) internal pure returns (uint128) {
        require(value <= type(uint128).max, "SafeCast: value doesn't fit in 128 bits");
        return uint128(value);
    }

    /**
     * @dev Returns the downcasted uint120 from uint256, reverting on
     * overflow (when the input is greater than largest uint120).
     *
     * Counterpart to Solidity's `uint120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toUint120(uint256 value) internal pure returns (uint120) {
        require(value <= type(uint120).max, "SafeCast: value doesn't fit in 120 bits");
        return uint120(value);
    }

    /**
     * @dev Returns the downcasted uint112 from uint256, reverting on
     * overflow (when the input is greater than largest uint112).
     *
     * Counterpart to Solidity's `uint112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toUint112(uint256 value) internal pure returns (uint112) {
        require(value <= type(uint112).max, "SafeCast: value doesn't fit in 112 bits");
        return uint112(value);
    }

    /**
     * @dev Returns the downcasted uint104 from uint256, reverting on
     * overflow (when the input is greater than largest uint104).
     *
     * Counterpart to Solidity's `uint104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toUint104(uint256 value) internal pure returns (uint104) {
        require(value <= type(uint104).max, "SafeCast: value doesn't fit in 104 bits");
        return uint104(value);
    }

    /**
     * @dev Returns the downcasted uint96 from uint256, reverting on
     * overflow (when the input is greater than largest uint96).
     *
     * Counterpart to Solidity's `uint96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.2._
     */
    function toUint96(uint256 value) internal pure returns (uint96) {
        require(value <= type(uint96).max, "SafeCast: value doesn't fit in 96 bits");
        return uint96(value);
    }

    /**
     * @dev Returns the downcasted uint88 from uint256, reverting on
     * overflow (when the input is greater than largest uint88).
     *
     * Counterpart to Solidity's `uint88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toUint88(uint256 value) internal pure returns (uint88) {
        require(value <= type(uint88).max, "SafeCast: value doesn't fit in 88 bits");
        return uint88(value);
    }

    /**
     * @dev Returns the downcasted uint80 from uint256, reverting on
     * overflow (when the input is greater than largest uint80).
     *
     * Counterpart to Solidity's `uint80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toUint80(uint256 value) internal pure returns (uint80) {
        require(value <= type(uint80).max, "SafeCast: value doesn't fit in 80 bits");
        return uint80(value);
    }

    /**
     * @dev Returns the downcasted uint72 from uint256, reverting on
     * overflow (when the input is greater than largest uint72).
     *
     * Counterpart to Solidity's `uint72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toUint72(uint256 value) internal pure returns (uint72) {
        require(value <= type(uint72).max, "SafeCast: value doesn't fit in 72 bits");
        return uint72(value);
    }

    /**
     * @dev Returns the downcasted uint64 from uint256, reverting on
     * overflow (when the input is greater than largest uint64).
     *
     * Counterpart to Solidity's `uint64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v2.5._
     */
    function toUint64(uint256 value) internal pure returns (uint64) {
        require(value <= type(uint64).max, "SafeCast: value doesn't fit in 64 bits");
        return uint64(value);
    }

    /**
     * @dev Returns the downcasted uint56 from uint256, reverting on
     * overflow (when the input is greater than largest uint56).
     *
     * Counterpart to Solidity's `uint56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toUint56(uint256 value) internal pure returns (uint56) {
        require(value <= type(uint56).max, "SafeCast: value doesn't fit in 56 bits");
        return uint56(value);
    }

    /**
     * @dev Returns the downcasted uint48 from uint256, reverting on
     * overflow (when the input is greater than largest uint48).
     *
     * Counterpart to Solidity's `uint48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toUint48(uint256 value) internal pure returns (uint48) {
        require(value <= type(uint48).max, "SafeCast: value doesn't fit in 48 bits");
        return uint48(value);
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value <= type(uint40).max, "SafeCast: value doesn't fit in 40 bits");
        return uint40(value);
    }

    /**
     * @dev Returns the downcasted uint32 from uint256, reverting on
     * overflow (when the input is greater than largest uint32).
     *
     * Counterpart to Solidity's `uint32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v2.5._
     */
    function toUint32(uint256 value) internal pure returns (uint32) {
        require(value <= type(uint32).max, "SafeCast: value doesn't fit in 32 bits");
        return uint32(value);
    }

    /**
     * @dev Returns the downcasted uint24 from uint256, reverting on
     * overflow (when the input is greater than largest uint24).
     *
     * Counterpart to Solidity's `uint24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toUint24(uint256 value) internal pure returns (uint24) {
        require(value <= type(uint24).max, "SafeCast: value doesn't fit in 24 bits");
        return uint24(value);
    }

    /**
     * @dev Returns the downcasted uint16 from uint256, reverting on
     * overflow (when the input is greater than largest uint16).
     *
     * Counterpart to Solidity's `uint16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v2.5._
     */
    function toUint16(uint256 value) internal pure returns (uint16) {
        require(value <= type(uint16).max, "SafeCast: value doesn't fit in 16 bits");
        return uint16(value);
    }

    /**
     * @dev Returns the downcasted uint8 from uint256, reverting on
     * overflow (when the input is greater than largest uint8).
     *
     * Counterpart to Solidity's `uint8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v2.5._
     */
    function toUint8(uint256 value) internal pure returns (uint8) {
        require(value <= type(uint8).max, "SafeCast: value doesn't fit in 8 bits");
        return uint8(value);
    }

    /**
     * @dev Converts a signed int256 into an unsigned uint256.
     *
     * Requirements:
     *
     * - input must be greater than or equal to 0.
     *
     * _Available since v3.0._
     */
    function toUint256(int256 value) internal pure returns (uint256) {
        require(value >= 0, "SafeCast: value must be positive");
        return uint256(value);
    }

    /**
     * @dev Returns the downcasted int248 from int256, reverting on
     * overflow (when the input is less than smallest int248 or
     * greater than largest int248).
     *
     * Counterpart to Solidity's `int248` operator.
     *
     * Requirements:
     *
     * - input must fit into 248 bits
     *
     * _Available since v4.7._
     */
    function toInt248(int256 value) internal pure returns (int248 downcasted) {
        downcasted = int248(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 248 bits");
    }

    /**
     * @dev Returns the downcasted int240 from int256, reverting on
     * overflow (when the input is less than smallest int240 or
     * greater than largest int240).
     *
     * Counterpart to Solidity's `int240` operator.
     *
     * Requirements:
     *
     * - input must fit into 240 bits
     *
     * _Available since v4.7._
     */
    function toInt240(int256 value) internal pure returns (int240 downcasted) {
        downcasted = int240(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 240 bits");
    }

    /**
     * @dev Returns the downcasted int232 from int256, reverting on
     * overflow (when the input is less than smallest int232 or
     * greater than largest int232).
     *
     * Counterpart to Solidity's `int232` operator.
     *
     * Requirements:
     *
     * - input must fit into 232 bits
     *
     * _Available since v4.7._
     */
    function toInt232(int256 value) internal pure returns (int232 downcasted) {
        downcasted = int232(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 232 bits");
    }

    /**
     * @dev Returns the downcasted int224 from int256, reverting on
     * overflow (when the input is less than smallest int224 or
     * greater than largest int224).
     *
     * Counterpart to Solidity's `int224` operator.
     *
     * Requirements:
     *
     * - input must fit into 224 bits
     *
     * _Available since v4.7._
     */
    function toInt224(int256 value) internal pure returns (int224 downcasted) {
        downcasted = int224(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 224 bits");
    }

    /**
     * @dev Returns the downcasted int216 from int256, reverting on
     * overflow (when the input is less than smallest int216 or
     * greater than largest int216).
     *
     * Counterpart to Solidity's `int216` operator.
     *
     * Requirements:
     *
     * - input must fit into 216 bits
     *
     * _Available since v4.7._
     */
    function toInt216(int256 value) internal pure returns (int216 downcasted) {
        downcasted = int216(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 216 bits");
    }

    /**
     * @dev Returns the downcasted int208 from int256, reverting on
     * overflow (when the input is less than smallest int208 or
     * greater than largest int208).
     *
     * Counterpart to Solidity's `int208` operator.
     *
     * Requirements:
     *
     * - input must fit into 208 bits
     *
     * _Available since v4.7._
     */
    function toInt208(int256 value) internal pure returns (int208 downcasted) {
        downcasted = int208(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 208 bits");
    }

    /**
     * @dev Returns the downcasted int200 from int256, reverting on
     * overflow (when the input is less than smallest int200 or
     * greater than largest int200).
     *
     * Counterpart to Solidity's `int200` operator.
     *
     * Requirements:
     *
     * - input must fit into 200 bits
     *
     * _Available since v4.7._
     */
    function toInt200(int256 value) internal pure returns (int200 downcasted) {
        downcasted = int200(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 200 bits");
    }

    /**
     * @dev Returns the downcasted int192 from int256, reverting on
     * overflow (when the input is less than smallest int192 or
     * greater than largest int192).
     *
     * Counterpart to Solidity's `int192` operator.
     *
     * Requirements:
     *
     * - input must fit into 192 bits
     *
     * _Available since v4.7._
     */
    function toInt192(int256 value) internal pure returns (int192 downcasted) {
        downcasted = int192(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 192 bits");
    }

    /**
     * @dev Returns the downcasted int184 from int256, reverting on
     * overflow (when the input is less than smallest int184 or
     * greater than largest int184).
     *
     * Counterpart to Solidity's `int184` operator.
     *
     * Requirements:
     *
     * - input must fit into 184 bits
     *
     * _Available since v4.7._
     */
    function toInt184(int256 value) internal pure returns (int184 downcasted) {
        downcasted = int184(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 184 bits");
    }

    /**
     * @dev Returns the downcasted int176 from int256, reverting on
     * overflow (when the input is less than smallest int176 or
     * greater than largest int176).
     *
     * Counterpart to Solidity's `int176` operator.
     *
     * Requirements:
     *
     * - input must fit into 176 bits
     *
     * _Available since v4.7._
     */
    function toInt176(int256 value) internal pure returns (int176 downcasted) {
        downcasted = int176(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 176 bits");
    }

    /**
     * @dev Returns the downcasted int168 from int256, reverting on
     * overflow (when the input is less than smallest int168 or
     * greater than largest int168).
     *
     * Counterpart to Solidity's `int168` operator.
     *
     * Requirements:
     *
     * - input must fit into 168 bits
     *
     * _Available since v4.7._
     */
    function toInt168(int256 value) internal pure returns (int168 downcasted) {
        downcasted = int168(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 168 bits");
    }

    /**
     * @dev Returns the downcasted int160 from int256, reverting on
     * overflow (when the input is less than smallest int160 or
     * greater than largest int160).
     *
     * Counterpart to Solidity's `int160` operator.
     *
     * Requirements:
     *
     * - input must fit into 160 bits
     *
     * _Available since v4.7._
     */
    function toInt160(int256 value) internal pure returns (int160 downcasted) {
        downcasted = int160(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 160 bits");
    }

    /**
     * @dev Returns the downcasted int152 from int256, reverting on
     * overflow (when the input is less than smallest int152 or
     * greater than largest int152).
     *
     * Counterpart to Solidity's `int152` operator.
     *
     * Requirements:
     *
     * - input must fit into 152 bits
     *
     * _Available since v4.7._
     */
    function toInt152(int256 value) internal pure returns (int152 downcasted) {
        downcasted = int152(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 152 bits");
    }

    /**
     * @dev Returns the downcasted int144 from int256, reverting on
     * overflow (when the input is less than smallest int144 or
     * greater than largest int144).
     *
     * Counterpart to Solidity's `int144` operator.
     *
     * Requirements:
     *
     * - input must fit into 144 bits
     *
     * _Available since v4.7._
     */
    function toInt144(int256 value) internal pure returns (int144 downcasted) {
        downcasted = int144(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 144 bits");
    }

    /**
     * @dev Returns the downcasted int136 from int256, reverting on
     * overflow (when the input is less than smallest int136 or
     * greater than largest int136).
     *
     * Counterpart to Solidity's `int136` operator.
     *
     * Requirements:
     *
     * - input must fit into 136 bits
     *
     * _Available since v4.7._
     */
    function toInt136(int256 value) internal pure returns (int136 downcasted) {
        downcasted = int136(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 136 bits");
    }

    /**
     * @dev Returns the downcasted int128 from int256, reverting on
     * overflow (when the input is less than smallest int128 or
     * greater than largest int128).
     *
     * Counterpart to Solidity's `int128` operator.
     *
     * Requirements:
     *
     * - input must fit into 128 bits
     *
     * _Available since v3.1._
     */
    function toInt128(int256 value) internal pure returns (int128 downcasted) {
        downcasted = int128(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 128 bits");
    }

    /**
     * @dev Returns the downcasted int120 from int256, reverting on
     * overflow (when the input is less than smallest int120 or
     * greater than largest int120).
     *
     * Counterpart to Solidity's `int120` operator.
     *
     * Requirements:
     *
     * - input must fit into 120 bits
     *
     * _Available since v4.7._
     */
    function toInt120(int256 value) internal pure returns (int120 downcasted) {
        downcasted = int120(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 120 bits");
    }

    /**
     * @dev Returns the downcasted int112 from int256, reverting on
     * overflow (when the input is less than smallest int112 or
     * greater than largest int112).
     *
     * Counterpart to Solidity's `int112` operator.
     *
     * Requirements:
     *
     * - input must fit into 112 bits
     *
     * _Available since v4.7._
     */
    function toInt112(int256 value) internal pure returns (int112 downcasted) {
        downcasted = int112(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 112 bits");
    }

    /**
     * @dev Returns the downcasted int104 from int256, reverting on
     * overflow (when the input is less than smallest int104 or
     * greater than largest int104).
     *
     * Counterpart to Solidity's `int104` operator.
     *
     * Requirements:
     *
     * - input must fit into 104 bits
     *
     * _Available since v4.7._
     */
    function toInt104(int256 value) internal pure returns (int104 downcasted) {
        downcasted = int104(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 104 bits");
    }

    /**
     * @dev Returns the downcasted int96 from int256, reverting on
     * overflow (when the input is less than smallest int96 or
     * greater than largest int96).
     *
     * Counterpart to Solidity's `int96` operator.
     *
     * Requirements:
     *
     * - input must fit into 96 bits
     *
     * _Available since v4.7._
     */
    function toInt96(int256 value) internal pure returns (int96 downcasted) {
        downcasted = int96(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 96 bits");
    }

    /**
     * @dev Returns the downcasted int88 from int256, reverting on
     * overflow (when the input is less than smallest int88 or
     * greater than largest int88).
     *
     * Counterpart to Solidity's `int88` operator.
     *
     * Requirements:
     *
     * - input must fit into 88 bits
     *
     * _Available since v4.7._
     */
    function toInt88(int256 value) internal pure returns (int88 downcasted) {
        downcasted = int88(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 88 bits");
    }

    /**
     * @dev Returns the downcasted int80 from int256, reverting on
     * overflow (when the input is less than smallest int80 or
     * greater than largest int80).
     *
     * Counterpart to Solidity's `int80` operator.
     *
     * Requirements:
     *
     * - input must fit into 80 bits
     *
     * _Available since v4.7._
     */
    function toInt80(int256 value) internal pure returns (int80 downcasted) {
        downcasted = int80(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 80 bits");
    }

    /**
     * @dev Returns the downcasted int72 from int256, reverting on
     * overflow (when the input is less than smallest int72 or
     * greater than largest int72).
     *
     * Counterpart to Solidity's `int72` operator.
     *
     * Requirements:
     *
     * - input must fit into 72 bits
     *
     * _Available since v4.7._
     */
    function toInt72(int256 value) internal pure returns (int72 downcasted) {
        downcasted = int72(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 72 bits");
    }

    /**
     * @dev Returns the downcasted int64 from int256, reverting on
     * overflow (when the input is less than smallest int64 or
     * greater than largest int64).
     *
     * Counterpart to Solidity's `int64` operator.
     *
     * Requirements:
     *
     * - input must fit into 64 bits
     *
     * _Available since v3.1._
     */
    function toInt64(int256 value) internal pure returns (int64 downcasted) {
        downcasted = int64(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 64 bits");
    }

    /**
     * @dev Returns the downcasted int56 from int256, reverting on
     * overflow (when the input is less than smallest int56 or
     * greater than largest int56).
     *
     * Counterpart to Solidity's `int56` operator.
     *
     * Requirements:
     *
     * - input must fit into 56 bits
     *
     * _Available since v4.7._
     */
    function toInt56(int256 value) internal pure returns (int56 downcasted) {
        downcasted = int56(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 56 bits");
    }

    /**
     * @dev Returns the downcasted int48 from int256, reverting on
     * overflow (when the input is less than smallest int48 or
     * greater than largest int48).
     *
     * Counterpart to Solidity's `int48` operator.
     *
     * Requirements:
     *
     * - input must fit into 48 bits
     *
     * _Available since v4.7._
     */
    function toInt48(int256 value) internal pure returns (int48 downcasted) {
        downcasted = int48(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 48 bits");
    }

    /**
     * @dev Returns the downcasted int40 from int256, reverting on
     * overflow (when the input is less than smallest int40 or
     * greater than largest int40).
     *
     * Counterpart to Solidity's `int40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     *
     * _Available since v4.7._
     */
    function toInt40(int256 value) internal pure returns (int40 downcasted) {
        downcasted = int40(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 40 bits");
    }

    /**
     * @dev Returns the downcasted int32 from int256, reverting on
     * overflow (when the input is less than smallest int32 or
     * greater than largest int32).
     *
     * Counterpart to Solidity's `int32` operator.
     *
     * Requirements:
     *
     * - input must fit into 32 bits
     *
     * _Available since v3.1._
     */
    function toInt32(int256 value) internal pure returns (int32 downcasted) {
        downcasted = int32(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 32 bits");
    }

    /**
     * @dev Returns the downcasted int24 from int256, reverting on
     * overflow (when the input is less than smallest int24 or
     * greater than largest int24).
     *
     * Counterpart to Solidity's `int24` operator.
     *
     * Requirements:
     *
     * - input must fit into 24 bits
     *
     * _Available since v4.7._
     */
    function toInt24(int256 value) internal pure returns (int24 downcasted) {
        downcasted = int24(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 24 bits");
    }

    /**
     * @dev Returns the downcasted int16 from int256, reverting on
     * overflow (when the input is less than smallest int16 or
     * greater than largest int16).
     *
     * Counterpart to Solidity's `int16` operator.
     *
     * Requirements:
     *
     * - input must fit into 16 bits
     *
     * _Available since v3.1._
     */
    function toInt16(int256 value) internal pure returns (int16 downcasted) {
        downcasted = int16(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 16 bits");
    }

    /**
     * @dev Returns the downcasted int8 from int256, reverting on
     * overflow (when the input is less than smallest int8 or
     * greater than largest int8).
     *
     * Counterpart to Solidity's `int8` operator.
     *
     * Requirements:
     *
     * - input must fit into 8 bits
     *
     * _Available since v3.1._
     */
    function toInt8(int256 value) internal pure returns (int8 downcasted) {
        downcasted = int8(value);
        require(downcasted == value, "SafeCast: value doesn't fit in 8 bits");
    }

    /**
     * @dev Converts an unsigned uint256 into a signed int256.
     *
     * Requirements:
     *
     * - input must be less than or equal to maxInt256.
     *
     * _Available since v3.0._
     */
    function toInt256(uint256 value) internal pure returns (int256) {
        // Note: Unsafe cast below is okay because `type(int256).max` is guaranteed to be positive
        require(value <= uint256(type(int256).max), "SafeCast: value doesn't fit in an int256");
        return int256(value);
    }
}


// File: @openzeppelin/contracts/utils/math/SignedMath.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/math/SignedMath.sol)

pragma solidity ^0.8.0;

/**
 * @dev Standard signed math utilities missing in the Solidity language.
 */
library SignedMath {
    /**
     * @dev Returns the largest of two signed numbers.
     */
    function max(int256 a, int256 b) internal pure returns (int256) {
        return a > b ? a : b;
    }

    /**
     * @dev Returns the smallest of two signed numbers.
     */
    function min(int256 a, int256 b) internal pure returns (int256) {
        return a < b ? a : b;
    }

    /**
     * @dev Returns the average of two signed numbers without overflow.
     * The result is rounded towards zero.
     */
    function average(int256 a, int256 b) internal pure returns (int256) {
        // Formula from the book "Hacker's Delight"
        int256 x = (a & b) + ((a ^ b) >> 1);
        return x + (int256(uint256(x) >> 255) & (a ^ b));
    }

    /**
     * @dev Returns the absolute unsigned value of a signed value.
     */
    function abs(int256 n) internal pure returns (uint256) {
        unchecked {
            // must be unchecked in order to support `n = type(int256).min`
            return uint256(n >= 0 ? n : -n);
        }
    }
}


// File: @openzeppelin/contracts/utils/Strings.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Strings.sol)

pragma solidity ^0.8.0;

import "./math/Math.sol";
import "./math/SignedMath.sol";

/**
 * @dev String operations.
 */
library Strings {
    bytes16 private constant _SYMBOLS = "0123456789abcdef";
    uint8 private constant _ADDRESS_LENGTH = 20;

    /**
     * @dev Converts a `uint256` to its ASCII `string` decimal representation.
     */
    function toString(uint256 value) internal pure returns (string memory) {
        unchecked {
            uint256 length = Math.log10(value) + 1;
            string memory buffer = new string(length);
            uint256 ptr;
            /// @solidity memory-safe-assembly
            assembly {
                ptr := add(buffer, add(32, length))
            }
            while (true) {
                ptr--;
                /// @solidity memory-safe-assembly
                assembly {
                    mstore8(ptr, byte(mod(value, 10), _SYMBOLS))
                }
                value /= 10;
                if (value == 0) break;
            }
            return buffer;
        }
    }

    /**
     * @dev Converts a `int256` to its ASCII `string` decimal representation.
     */
    function toString(int256 value) internal pure returns (string memory) {
        return string(abi.encodePacked(value < 0 ? "-" : "", toString(SignedMath.abs(value))));
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation.
     */
    function toHexString(uint256 value) internal pure returns (string memory) {
        unchecked {
            return toHexString(value, Math.log256(value) + 1);
        }
    }

    /**
     * @dev Converts a `uint256` to its ASCII `string` hexadecimal representation with fixed length.
     */
    function toHexString(uint256 value, uint256 length) internal pure returns (string memory) {
        bytes memory buffer = new bytes(2 * length + 2);
        buffer[0] = "0";
        buffer[1] = "x";
        for (uint256 i = 2 * length + 1; i > 1; --i) {
            buffer[i] = _SYMBOLS[value & 0xf];
            value >>= 4;
        }
        require(value == 0, "Strings: hex length insufficient");
        return string(buffer);
    }

    /**
     * @dev Converts an `address` with fixed length of 20 bytes to its not checksummed ASCII `string` hexadecimal representation.
     */
    function toHexString(address addr) internal pure returns (string memory) {
        return toHexString(uint256(uint160(addr)), _ADDRESS_LENGTH);
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(string memory a, string memory b) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}


// File: @openzeppelin/contracts/utils/structs/EnumerableSet.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableSet.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableSet.js.

pragma solidity ^0.8.0;

/**
 * @dev Library for managing
 * https://en.wikipedia.org/wiki/Set_(abstract_data_type)[sets] of primitive
 * types.
 *
 * Sets have the following properties:
 *
 * - Elements are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Elements are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableSet for EnumerableSet.AddressSet;
 *
 *     // Declare a set state variable
 *     EnumerableSet.AddressSet private mySet;
 * }
 * ```
 *
 * As of v3.3.0, sets of type `bytes32` (`Bytes32Set`), `address` (`AddressSet`)
 * and `uint256` (`UintSet`) are supported.
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableSet, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableSet.
 * ====
 */
library EnumerableSet {
    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Set type with
    // bytes32 values.
    // The Set implementation uses private functions, and user-facing
    // implementations (such as AddressSet) are just wrappers around the
    // underlying Set.
    // This means that we can only create new EnumerableSets for types that fit
    // in bytes32.

    struct Set {
        // Storage of set values
        bytes32[] _values;
        // Position of the value in the `values` array, plus 1 because index 0
        // means a value is not in the set.
        mapping(bytes32 => uint256) _indexes;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function _add(Set storage set, bytes32 value) private returns (bool) {
        if (!_contains(set, value)) {
            set._values.push(value);
            // The value is stored at length-1, but we add 1 to all indexes
            // and use 0 as a sentinel value
            set._indexes[value] = set._values.length;
            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function _remove(Set storage set, bytes32 value) private returns (bool) {
        // We read and store the value's index to prevent multiple reads from the same storage slot
        uint256 valueIndex = set._indexes[value];

        if (valueIndex != 0) {
            // Equivalent to contains(set, value)
            // To delete an element from the _values array in O(1), we swap the element to delete with the last one in
            // the array, and then remove the last element (sometimes called as 'swap and pop').
            // This modifies the order of the array, as noted in {at}.

            uint256 toDeleteIndex = valueIndex - 1;
            uint256 lastIndex = set._values.length - 1;

            if (lastIndex != toDeleteIndex) {
                bytes32 lastValue = set._values[lastIndex];

                // Move the last value to the index where the value to delete is
                set._values[toDeleteIndex] = lastValue;
                // Update the index for the moved value
                set._indexes[lastValue] = valueIndex; // Replace lastValue's index to valueIndex
            }

            // Delete the slot where the moved value was stored
            set._values.pop();

            // Delete the index for the deleted slot
            delete set._indexes[value];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function _contains(Set storage set, bytes32 value) private view returns (bool) {
        return set._indexes[value] != 0;
    }

    /**
     * @dev Returns the number of values on the set. O(1).
     */
    function _length(Set storage set) private view returns (uint256) {
        return set._values.length;
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function _at(Set storage set, uint256 index) private view returns (bytes32) {
        return set._values[index];
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function _values(Set storage set) private view returns (bytes32[] memory) {
        return set._values;
    }

    // Bytes32Set

    struct Bytes32Set {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _add(set._inner, value);
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(Bytes32Set storage set, bytes32 value) internal returns (bool) {
        return _remove(set._inner, value);
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(Bytes32Set storage set, bytes32 value) internal view returns (bool) {
        return _contains(set._inner, value);
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(Bytes32Set storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32Set storage set, uint256 index) internal view returns (bytes32) {
        return _at(set._inner, index);
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(Bytes32Set storage set) internal view returns (bytes32[] memory) {
        bytes32[] memory store = _values(set._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressSet

    struct AddressSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(AddressSet storage set, address value) internal returns (bool) {
        return _add(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(AddressSet storage set, address value) internal returns (bool) {
        return _remove(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(AddressSet storage set, address value) internal view returns (bool) {
        return _contains(set._inner, bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(AddressSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressSet storage set, uint256 index) internal view returns (address) {
        return address(uint160(uint256(_at(set._inner, index))));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(AddressSet storage set) internal view returns (address[] memory) {
        bytes32[] memory store = _values(set._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintSet

    struct UintSet {
        Set _inner;
    }

    /**
     * @dev Add a value to a set. O(1).
     *
     * Returns true if the value was added to the set, that is if it was not
     * already present.
     */
    function add(UintSet storage set, uint256 value) internal returns (bool) {
        return _add(set._inner, bytes32(value));
    }

    /**
     * @dev Removes a value from a set. O(1).
     *
     * Returns true if the value was removed from the set, that is if it was
     * present.
     */
    function remove(UintSet storage set, uint256 value) internal returns (bool) {
        return _remove(set._inner, bytes32(value));
    }

    /**
     * @dev Returns true if the value is in the set. O(1).
     */
    function contains(UintSet storage set, uint256 value) internal view returns (bool) {
        return _contains(set._inner, bytes32(value));
    }

    /**
     * @dev Returns the number of values in the set. O(1).
     */
    function length(UintSet storage set) internal view returns (uint256) {
        return _length(set._inner);
    }

    /**
     * @dev Returns the value stored at position `index` in the set. O(1).
     *
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintSet storage set, uint256 index) internal view returns (uint256) {
        return uint256(_at(set._inner, index));
    }

    /**
     * @dev Return the entire set in an array
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the set grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function values(UintSet storage set) internal view returns (uint256[] memory) {
        bytes32[] memory store = _values(set._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }
}


// File: contracts/interfaces/ILootboxFactory.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface ILootboxFactory {
  function feePerUnit(address _lootbox) external view returns (uint);
  receive() external payable;
}


// File: contracts/interfaces/IVRFV2Wrapper.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {AggregatorV3Interface} from '@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol';

interface IVRFV2Wrapper {
  function LINK_ETH_FEED() external pure returns (AggregatorV3Interface);
  function COORDINATOR() external pure returns (address);
  function calculateRequestPrice(uint32 _callbackGasLimit) external view returns (uint256);
  function estimateRequestPrice(uint32 _callbackGasLimit, uint256 _requestGasPriceWei) external view returns (uint256);
  function rawFulfillRandomWords(uint256 requestId, uint256[] memory randomWords) external;
}


// File: contracts/Lootbox.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';
import {IERC721Receiver} from '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import {ERC721Holder} from '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155PresetMinterPauser} from '@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol';
import {ERC1155Holder, ERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {SafeCast} from '@openzeppelin/contracts/utils/math/SafeCast.sol';
import {Address} from '@openzeppelin/contracts/utils/Address.sol';
import {VRFCoordinatorV2Interface} from '@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol';
import {ERC677ReceiverInterface} from '@chainlink/contracts/src/v0.8/interfaces/ERC677ReceiverInterface.sol';
import {VRFV2WrapperInterface} from '@chainlink/contracts/src/v0.8/interfaces/VRFV2WrapperInterface.sol';
import {VRFV2WrapperConsumerBase} from '@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol';
import {ILootboxFactory} from './interfaces/ILootboxFactory.sol';
import {IVRFV2Wrapper, AggregatorV3Interface} from './interfaces/IVRFV2Wrapper.sol';
import {LootboxInterface} from './LootboxInterface.sol';

//  $$$$$$\  $$\   $$\  $$$$$$\  $$$$$$\ $$\   $$\  $$$$$$\   $$$$$$\  $$$$$$$$\ $$$$$$$$\ 
// $$  __$$\ $$ |  $$ |$$  __$$\ \_$$  _|$$$\  $$ |$$  __$$\ $$  __$$\ $$  _____|$$  _____|
// $$ /  \__|$$ |  $$ |$$ /  $$ |  $$ |  $$$$\ $$ |$$ /  \__|$$ /  $$ |$$ |      $$ |      
// $$ |      $$$$$$$$ |$$$$$$$$ |  $$ |  $$ $$\$$ |\$$$$$$\  $$$$$$$$ |$$$$$\    $$$$$\    
// $$ |      $$  __$$ |$$  __$$ |  $$ |  $$ \$$$$ | \____$$\ $$  __$$ |$$  __|   $$  __|   
// $$ |  $$\ $$ |  $$ |$$ |  $$ |  $$ |  $$ |\$$$ |$$\   $$ |$$ |  $$ |$$ |      $$ |      
// \$$$$$$  |$$ |  $$ |$$ |  $$ |$$$$$$\ $$ | \$$ |\$$$$$$  |$$ |  $$ |$$ |      $$$$$$$$\ 
//  \______/ \__|  \__|\__|  \__|\______|\__|  \__| \______/ \__|  \__|\__|      \________|                                                                                                                                                                              
                                                                                        
// $$\       $$$$$$\   $$$$$$\ $$$$$$$$\ $$$$$$$\   $$$$$$\  $$\   $$\ $$$$$$$$\  $$$$$$\  
// $$ |     $$  __$$\ $$  __$$\\__$$  __|$$  __$$\ $$  __$$\ $$ |  $$ |$$  _____|$$  __$$\ 
// $$ |     $$ /  $$ |$$ /  $$ |  $$ |   $$ |  $$ |$$ /  $$ |\$$\ $$  |$$ |      $$ /  \__|
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$$$$$$\ |$$ |  $$ | \$$$$  / $$$$$\    \$$$$$$\  
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$  __$$\ $$ |  $$ | $$  $$<  $$  __|    \____$$\ 
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$ |  $$ |$$ |  $$ |$$  /\$$\ $$ |      $$\   $$ |
// $$$$$$$$\ $$$$$$  | $$$$$$  |  $$ |   $$$$$$$  | $$$$$$  |$$ /  $$ |$$$$$$$$\ \$$$$$$  |
// \________|\______/  \______/   \__|   \_______/  \______/ \__|  \__|\________| \______/ 

/// @title Lootbox
/// @author ChainSafe Systems: Oleksii (Functionality) Sneakz (Natspec assistance)
/// @notice This contract holds lootbox functions used in Chainsafe's SDK, Documentation can be found here: https://docs.gaming.chainsafe.io/current/lootboxes
/// @notice Glossary:
/// @notice   Reward is a token that could be received by opening a lootbox.
/// @notice   Unit is a common, across all rewards, denomination of what user receives by openning a lootbox with Type/ID 1.
/// @notice   Lootbox Type/ID is a property of a lootbox that defines how many units will be received by opening this lootbox,
/// @notice     eg. opening a lootbox with Type/ID 3 will produce 3 random units of rewards.
/// @notice   Amount per unit is a property of a reward that defines how many tokens of this reward will be received for single unit,
/// @notice     eg. opening a lootbox with Type/ID 1 that ended up being a TOKEN_X of type ERC20 would produce 30 TOKEN_X for the user,
/// @notice     or if it ended up being a TOKEN_Y of type ERC721 would produce 2 TOKEN_Y NFTs for the user,
/// @notice     or if it ended up being a TOKEN_Z of type ERC1155 would produce 20 TOKEN_Y ID 5, or 50 TOKEN_Y ID 10 for the user.
/// @notice   Reward Type is self describing with one caveat. The ERC1155NFT type is an ERC1155 where each ID could have a balance of only 1.
/// @notice   Which technically makes it behave just like ERC721, ie. an NFT. Contrary to ERC1155 where each ID could have arbitrary balances, i.e fungible.
/// @notice   Supplier is an address that is allowed to send rewards into the inventory.
/// @notice   Inventory is a pool of rewards that could be claimed by opening lootboxes.
/// @notice   Rewards adding process:
/// @notice   1. Add tokens list to be allowed for rewards.
/// @notice   2. Add suppliers that hold desired reward tokens.
/// @notice   3. Make suppliers transfer reward tokens to the Lootbox address:
/// @notice     For ERC20, simple transfer(lootbox, amount).
/// @notice     For ERC721, safeTransferFrom(from, lootbox, tokenId, '0x').
/// @notice     For ERC1155, safeTransferFrom(from, lootbox, tokenId, amountOfTokenId, '0x') or
/// @notice       safeBatchTransferFrom(from, lootbox, tokenIds[], amountsOfTokenIds[], '0x').
/// @notice     For ERC1155NFT, same as for ERC1155, but amounts should be strictly 1. Note that ERC1155 initially transferred with amount 1,
/// @notice       will be recognized as ERC1155NFT and won't be able to have amounts above 1 in the future.
/// @notice   4. Set amount per unit for supplied reward tokens:
/// @notice     For ERC20, id is not used, only amount does. Eg. 100 means that a single unit could be converted into 100 tokens.
/// @notice     For ERC721, id is not used, only amount does. Eg. 3 means that a single unit could be converted into 3 different NFT ids.
/// @notice     For ERC1155, id used to specify which particular internal token id is configured with the amount.
/// @notice       Eg. id 5 and amount 30 means that a single unit could be converted into 30 tokens of internal token id 5.
/// @notice     For ERC1155NFT, id is not used, only amount does. Eg. 2 means that a single unit could be converted into 2 different internal token ids.
/// @dev Contract allows users to open a lootbox and receive a random reward. All function calls are tested and have been implemented in ChainSafe's SDK.

type RewardInfo is uint248; // 8 bytes unitsAvailable | 23 bytes amountPerUnit
uint constant UNITS_OFFSET = 8 * 23;

contract Lootbox is VRFV2WrapperConsumerBase, ERC721Holder, ERC1155Holder, ERC1155PresetMinterPauser {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;
  using EnumerableSet for EnumerableSet.UintSet;
  using Address for address payable;
  using SafeCast for uint;

  /*//////////////////////////////////////////////////////////////
                                STATE
  //////////////////////////////////////////////////////////////*/

  enum RewardType {
    UNSET,
    ERC20,
    ERC721,
    ERC1155,
    ERC1155NFT
  }

  struct Reward {
    RewardType rewardType;
    RewardInfo rewardInfo;
    EnumerableSet.UintSet ids; // only 721 and 1155
    mapping(uint => RewardInfo) extraInfo; // only for 1155
  }

  struct AllocationInfo {
    EnumerableSet.UintSet ids;
    mapping(uint => uint) amount; // id 0 for ERC20
  }

  ILootboxFactory private immutable FACTORY;
  address private immutable VIEW;
  uint private constant LINK_UNIT = 1e18;

  uint private unitsSupply; // Supply of units.
  uint private unitsRequested; // Amount of units requested for opening.
  uint private unitsMinted; // Boxed units.
  uint private price; // Native currency needed to buy a lootbox.
  bool private isEmergencyMode; // State of emergency.
  EnumerableSet.UintSet private lootboxTypes; // Types of lootboxes.
  EnumerableSet.AddressSet private suppliers; // Supplier addresses being used.
  EnumerableSet.AddressSet private allowedTokens; // Tokens allowed for rewards.
  EnumerableSet.AddressSet private inventory; // Tokens available for rewards.
  mapping(address => mapping(uint => uint)) private allocated; // Token => TokenId => Balance. ERC20 and fungible ERC1155 allocated for claiming.
  mapping(address => Reward) private rewards; // Info about reward tokens.
  mapping(address => mapping(address => AllocationInfo)) private allocationInfo; // Claimer => Token => Info.
  mapping(address => EnumerableSet.UintSet) private extraIds; // ERC1155 internal token ids ever touching the lootbox.

  /*//////////////////////////////////////////////////////////////
                             VRF RELATED
  //////////////////////////////////////////////////////////////*/

  /// @notice The number of blocks confirmed before the request is considered fulfilled
  uint16 private constant REQUEST_CONFIRMATIONS = 3;

  /// @notice The number of random words to request
  uint32 private constant NUMWORDS = 1;

  /// @notice The VRF request struct
  struct Request {
    address opener;
    uint96 unitsToGet;
    uint[] lootIds;
    uint[] lootAmounts;
  }

  /// @notice The VRF request IDs and their corresponding parameters as well as the randomness when fulfilled
  mapping(uint256 => Request) private requests;

  /// @notice The VRF request IDs and their corresponding openers
  mapping(address => uint256) private openerRequests;

  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a lootbox is openning is requested
  /// @param opener The address of the user that requested the open
  /// @param unitsToGet The amount of lootbox units to receive
  /// @param requestId The ID of the VRF request
  event OpenRequested(address opener, uint256 unitsToGet, uint256 requestId);

  /// @notice Emitted when a randomness request is fulfilled and the lootbox rewards can be claimed
  /// @param requestId The ID of the VRF request
  /// @param randomness The random number that was generated
  event OpenRequestFulfilled(uint256 requestId, uint256 randomness);

  /// @notice Emitted when a randomness request ran out of gas and now must be recovered
  /// @param requestId The ID of the VRF request
  event OpenRequestFailed(uint256 requestId, bytes reason);

  event SupplierAdded(address supplier);

  event SupplierRemoved(address supplier);

  /// @notice Emitted when a new reward token gets whitelisted for supply
  event TokenAdded(address token);

  /// @notice Emitted when a reward token amount per unit changes
  /// @param newSupply The new supply of reward units available
  event AmountPerUnitSet(address token, uint tokenId, uint amountPerUnit, uint newSupply);

  /// @notice Emitted when the lootbox rewards are claimed
  /// @param opener The address of the user that received the rewards
  /// @param token The rewarded token contract address
  /// @param tokenId The internal tokenId for ERC721 and ERC1155
  /// @param amount The amount of claimed tokens
  event RewardsClaimed(address opener, address token, uint tokenId, uint amount);

  /// @notice Emitted when the lootbox rewards are allocated
  /// @param opener The address of the user that received the allocation
  /// @param token The rewarded token contract address
  /// @param tokenId The internal tokenId for ERC721 and ERC1155
  /// @param amount The amount of allocated tokens
  event Allocated(address opener, address token, uint tokenId, uint amount);

  /// @notice Emitted when the lootboxes gets recovered from a failed open request
  /// @param opener The address of the user that received the allocation
  /// @param requestId The ID of the VRF request
  event BoxesRecovered(address opener, uint requestId);

  /// @notice Emitted when the contract stops operation and assets being withdrawn by the admin
  /// @param caller The address of the admin who initiated the emergency
  event EmergencyModeEnabled(address caller);

  /// @notice Emitted when an admin withdraws assets in case of emergency
  /// @param token The token contract address
  /// @param tokenType The type of asset of token contract
  /// @param to The address that received the withdrawn assets
  /// @param ids The internal tokenIds for ERC721 and ERC1155
  /// @param amounts The amounts of withdrawn tokens/ids
  event EmergencyWithdrawal(address token, RewardType tokenType, address to, uint[] ids, uint[] amounts);

  /// @notice Emitted when an admin withdraws ERC20 or native currency
  /// @param token The token contract address or zero for native currency
  /// @param to The address that received the withdrawn assets
  /// @param amount The amount withdrawn
  event Withdraw(address token, address to, uint amount);

  /// @notice Emitted when an admin sets purchase price
  /// @param newPrice The amount of native currency to pay to buy a lootbox, or 0 if disabled
  event PriceUpdated(uint newPrice);

  /// @notice Emitted when user buys lootboxes
  /// @param buyer The address of the user that purchased lootboxes
  /// @param amount The amount of id 1 lootboxes sold
  /// @param payment The amount of native currency user paid
  event Sold(address buyer, uint amount, uint payment);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice There are no tokens to put in the lootbox
  error NoTokens();

  /// @notice The tokens array length does not match the perUnitAmounts array length
  error InvalidLength();

  /// @notice Supplying 1155NFT with amount > 1
  error InvalidTokenAmount();

  /// @notice The amount to open is zero
  error ZeroAmount();

  /// @notice Token not allowed as reward
  error TokenDenied(address token);

  /// @notice Deposits only allowed from whitelisted addresses
  error SupplyDenied(address from);

  /// @notice The amount to open exceeds the supply
  error SupplyExceeded(uint256 supply, uint256 unitsToGet);

  /// @notice The new supply amount is less than already requested to open
  error InsufficientSupply(uint256 supply, uint256 requested);

  /// @notice Has to finish the open request first
  error PendingOpenRequest(uint256 requestId);

  /// @notice Has to open some lootboxes first
  error NothingToClaim();

  /// @notice Reward type is immutable
  error ModifiedRewardType(RewardType oldType, RewardType newType);

  /// @notice Only LINK could be sent with an ERC677 call
  error AcceptingOnlyLINK();

  /// @notice Not enough pay for a VRF request or purchase
  error InsufficientPayment();

  /// @notice Not enough pay for a lootbox opening fee
  error InsufficientFee();

  /// @notice There should be a failed VRF request for recovery
  error NothingToRecover();

  /// @notice LINK price must be positive from an oracle
  error InvalidLinkPrice(int value);

  /// @notice Zero value ERC1155 supplies are not alloved
  error ZeroSupply(address token, uint id);

  /// @notice Function could only be called by this contract itself
  error OnlyThis();

  /// @notice Unexpected reward type for current logic
  error UnexpectedRewardType(RewardType rewardType);

  /// @notice Units should fit in 64 bits
  error UnitsOverflow(uint value);

  /// @notice Amount per unit should fit in 184 bits
  error AmountPerUnitOverflow(uint value);

  /// @notice Token id was already present in the inventory with units set to 0
  error DepositStateCorruption(address token, uint tokenId);

  /// @notice Token was already present in the inventory with units set to 0
  error InventoryStateCorruption(address token);

  /// @notice Not enough gas is provided for opening
  error InsufficientGas();

  /// @notice Lootbox id represents the number of rewrad units it will produce, so it should be > 0 and < 256
  error InvalidLootboxType();

  /// @notice The request is either already failed/fulfilled or was never created
  error InvalidRequestAllocation(uint requestId);

  /// @notice Requested operation is not supported in current version
  error Unsupported();

  /// @notice Token is allowed as reward and cannot be withdrawn
  error RewardWithdrawalDenied(address token);

  /// @notice Contrat was put into emergency mode and stopped operations
  error EndOfService();

  /// @notice Contrat could only be initialized by the factory
  error OnlyFactory();

  /// @notice View function reverted without reason
  error ViewCallFailed();

  /// @notice Purchase price is unexpectedly high or zero
  error UnexpectedPrice(uint currentPrice);

  /// @notice Caller does not have required role
  error AccessDenied(bytes32 role);

  /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  /// @notice Deploys a new Lootbox contract with the given parameters.
  /// @param _link The ChainLink LINK token address.
  /// @param _vrfV2Wrapper The ChainLink VRFV2Wrapper contract address.
  /// @param _view The LootboxView contract address.
  /// @param _factory The LootboxFactory contract address.
  constructor(
    address _link,
    address _vrfV2Wrapper,
    address _view,
    address payable _factory
  ) VRFV2WrapperConsumerBase(_link, _vrfV2Wrapper) ERC1155PresetMinterPauser('') {
    FACTORY = ILootboxFactory(_factory);
    VIEW = _view;
  }

  /// @notice Deploys a new Lootbox contract with the given parameters.
  /// @param _uri The Lootbox ERC1155 base URI.
  /// @param _owner The admin of the lootbox contract.
  function initialize(string memory _uri, address _owner) external {
    if (msg.sender != address(FACTORY)) revert OnlyFactory();
    _setupRole(DEFAULT_ADMIN_ROLE, _owner);
    _setupRole(MINTER_ROLE, _owner);
    _setupRole(PAUSER_ROLE, _owner);
    _setURI(_uri);
  }

  /*//////////////////////////////////////////////////////////////
                        INVENTORY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  modifier notEmergency() {
    _notEmergency();
    _;
  }

  modifier onlyAdmin() {
    _checkRole(DEFAULT_ADMIN_ROLE);
    _;
  }

  modifier onlyPauser() {
    _checkRole(PAUSER_ROLE);
    _;
  }

  /// @notice Sets the URI for the contract.
  /// @param _baseURI The base URI being used.
  function setURI(string memory _baseURI) external onlyAdmin() {
    _setURI(_baseURI);
  }

  /// @notice Adds loot suppliers.
  /// @param _suppliers An array of loot suppliers being added.
  function addSuppliers(address[] calldata _suppliers) external onlyAdmin() {
    for (uint i = 0; i < _suppliers.length; i = _inc(i)) {
      _addSupplier(_suppliers[i]);
    }
  }

  /// @notice Removes contract suppliers.
  /// @param _suppliers An array of suppliers being removed.
  function removeSuppliers(address[] calldata _suppliers) external onlyAdmin() {
    for (uint i = 0; i < _suppliers.length; i = _inc(i)) {
      _removeSupplier(_suppliers[i]);
    }
  }

  /// @notice Adds reward tokens for lootbox usage.
  /// @param _tokens An array of tokens being added.
  function addTokens(address[] calldata _tokens) external onlyAdmin() {
    for (uint i = 0; i < _tokens.length; i = _inc(i)) {
      _addToken(_tokens[i]);
    }
  }

  /// @notice Sets the how much of a token you get per lootbox.
  /// @dev Stops working during the emergency.
  /// @param _tokens An array of tokens being added.
  /// @param _ids An array of ids being added.
  /// @param _amountsPerUnit An array of amounts being added.
  function setAmountsPerUnit(address[] calldata _tokens, uint[] calldata _ids, uint[] calldata _amountsPerUnit) external notEmergency() onlyAdmin() {
    if (_tokens.length != _ids.length || _tokens.length != _amountsPerUnit.length) revert InvalidLength();
    uint currentSupply = unitsSupply;
    for (uint i = 0; i < _tokens.length; i = _inc(i)) {
      currentSupply = _setAmountPerUnit(currentSupply, _tokens[i], _ids[i], _amountsPerUnit[i]);
    }
    if (currentSupply < unitsRequested) revert InsufficientSupply(currentSupply, unitsRequested);
    unitsSupply = currentSupply;
  }

  function emergencyWithdraw(address _token, RewardType _type, address _to, uint[] calldata _ids, uint[] calldata _amounts) external onlyAdmin() {
    if (_not(isEmergencyMode)) {
      isEmergencyMode = true;
      emit EmergencyModeEnabled(_msgSender());
    }
    if (_to == address(0)) {
      _to = _msgSender();
    }
    uint length = _ids.length;
    if (length != _amounts.length) revert InvalidLength();
    for (uint i = 0; i < length; i = _inc(i)) {
      _transferToken(_token, _type, _to, _ids[i], _amounts[i]);
    }

    emit EmergencyWithdrawal(_token, _type, _to, _ids, _amounts);
  }

  /// @notice Sets required information when a 721 token is received.
  /// @param from The address the token is coming from.
  /// @param tokenId The id of of the 721 token.
  /// @return onERC721Received if successful.
  function onERC721Received(
    address,
    address from,
    uint256 tokenId,
    bytes memory
  ) public override notEmergency() returns (bytes4) {
    address token = _validateReceive(from);
    Reward storage reward = rewards[token];
    RewardInfo rewardInfo = reward.rewardInfo;
    RewardType rewardType = reward.rewardType;
    bool isFirstTime = rewardType == RewardType.UNSET;
    if (isFirstTime) {
      rewardInfo = toInfo(0, 1);
      reward.rewardInfo = rewardInfo;
      reward.rewardType = RewardType.ERC721;
    } else if (rewardType != RewardType.ERC721) {
      revert ModifiedRewardType(rewardType, RewardType.ERC721);
    }
    _supplyNFT(reward, rewardInfo, token, tokenId);
    return this.onERC721Received.selector;
  }

  /// @notice Sets required information when a 1155 token batch is received.
  /// @param from The address the token is coming from.
  /// @param ids An array of 1155 ids to be added to the account.
  /// @param values An array of values to be added to the account.
  /// @return onERC1155BatchReceived if successful.
  function onERC1155BatchReceived(
    address,
    address from,
    uint256[] memory ids,
    uint256[] memory values,
    bytes memory
  ) public override notEmergency() returns (bytes4) {
    address token = _validateReceive(from);
    uint len = ids.length;
    for (uint i = 0; i < len; i = _inc(i)) {
      _supply1155(token, ids[i], values[i]);
    }
    return this.onERC1155BatchReceived.selector;
  }

  /// @notice Sets required information when a 1155 token is received.
  /// @param from The address the token is coming from.
  /// @param id The 1155 id to be added to the account.
  /// @param value The value to be added to the account.
  /// @return onERC1155Received if successful.
  function onERC1155Received(
    address,
    address from,
    uint256 id,
    uint256 value,
    bytes memory
  ) public override notEmergency() returns (bytes4) {
    address token = _validateReceive(from);
    _supply1155(token, id, value);
    return this.onERC1155Received.selector;
  }

  /*//////////////////////////////////////////////////////////////
                           OPEN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Requests a lootbox openning paying with native currency
  /// @param _gas Gas limit for allocation. Safe estimate is number of reward units multiplied by 100,000 plus 50,000.
  /// @param _lootIds Lootbox ids to open
  /// @param _lootAmounts Lootbox amounts to open
  function open(uint32 _gas, uint[] calldata _lootIds, uint[] calldata _lootAmounts) external notEmergency() payable {
    uint vrfPrice = VRF_V2_WRAPPER.calculateRequestPrice(_gas);
    uint vrfPriceNative = vrfPrice * _getLinkPrice() / LINK_UNIT;
    if (msg.value < vrfPriceNative) revert InsufficientPayment();
    uint payment = msg.value - vrfPriceNative;
    address opener = _msgSender();
    uint unitsToGet = _requestOpen(opener, _gas, _lootIds, _lootAmounts);
    uint feePerUnit = FACTORY.feePerUnit(address(this));
    uint feeInNative = feePerUnit * unitsToGet;
    if (payment < feeInNative) revert InsufficientFee();
    if (feeInNative > 0) {
      payable(FACTORY).sendValue(feeInNative);
    }
    if (payment > feeInNative) {
      payable(opener).sendValue(payment - feeInNative);
    }
  }

  // TODO: allow partial claiming to avoid OOG.
  /// @notice Claims the rewards for the lootbox openning.
  /// @dev The user must have some rewards allocated.
  /// @param _opener The address of the user that has an allocation after opening.
  function claimRewards(address _opener) external whenNotPaused() {
    uint ids = allowedTokens.length();
    for (uint i = 0; i < ids; i = _inc(i)) {
      address token = allowedTokens.at(i);
      AllocationInfo storage info = allocationInfo[_opener][token];
      RewardType rewardType = rewards[token].rewardType;
      if (rewardType == RewardType.ERC20) {
        uint amount = info.amount[0];
        if (amount == 0) {
          continue;
        }
        info.amount[0] = 0;
        _deAllocate(token, 0, amount);
        _transferToken(token, rewardType, _opener, 0, amount);
        _emitClaimed(_opener, token, 0, amount);
      }
      else {
        uint tokenIds = info.ids.length();
        while(tokenIds > 0) {
          uint nextIndex = --tokenIds;
          uint tokenId = info.ids.at(nextIndex);
          info.ids.remove(tokenId);
          uint amount = 1;
          if (rewardType == RewardType.ERC1155) {
            amount = info.amount[tokenId];
            info.amount[tokenId] = 0;
            _deAllocate(token, tokenId, amount);
          }
          _transferToken(token, rewardType, _opener, tokenId, amount);
          _emitClaimed(_opener, token, tokenId, amount);
        }
      }
    }
  }

  /// @notice Used to recover lootboxes for an address.
  /// @param _opener The address that opened the boxes.
  function recoverBoxes(address _opener) external {
    uint requestId = openerRequests[_opener];
    if (requestId == 0) revert NothingToRecover();
    Request storage request = requests[requestId];
    if (request.unitsToGet > 0) revert PendingOpenRequest(requestId);
    uint[] memory ids = request.lootIds;
    uint[] memory amounts = request.lootAmounts;
    delete requests[requestId];
    delete openerRequests[_opener];
    _mintBatch(_opener, ids, amounts, '');
    emit BoxesRecovered(_opener, requestId);
  }

  /*//////////////////////////////////////////////////////////////
                           BUY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Sets the native currency price to buy a lootbox.
  /// @notice Set to 0 to prevent sales.
  /// @param _newPrice An amount of native currency user needs to pay to get a single lootbox.
  function setPrice(uint _newPrice) external onlyAdmin() {
    price = _newPrice;
    emit PriceUpdated(_newPrice);
  }

  /// @notice Mints requested amount of lootboxes for the caller assuming valid payment.
  /// @notice Remainder is sent back to the caller.
  /// @param _amount An amount lootboxes to mint.
  /// @param _maxPrice A maximum price the caller is willing to pay per lootbox.
  function buy(uint _amount, uint _maxPrice) external payable {
    address payable sender = payable(_msgSender());
    uint currentPrice = price;
    if (currentPrice == 0 || currentPrice > _maxPrice) revert UnexpectedPrice(currentPrice);
    uint valueNeeded = _amount * currentPrice;
    if (msg.value < valueNeeded) revert InsufficientPayment();
    _mint(sender, 1, _amount, '');
    uint remainder = msg.value - valueNeeded;
    if (remainder > 0) {
      sender.sendValue(remainder);
    }
    emit Sold(sender, _amount, valueNeeded);
  }

  /*//////////////////////////////////////////////////////////////
                          GETTER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  fallback(bytes calldata _data) external returns (bytes memory result) {
    bool success;
    if (msg.sender == address(this)) {
      (success, result) = VIEW.delegatecall(_data);
    } else {
      (success, result) = address(this).staticcall(_data);
    }
    if (_not(success)) {
      _revert(result);
    }
    return result;
  }

  /*//////////////////////////////////////////////////////////////
                           OWNER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Transfer the contract balance to the owner.
  /// @dev Allowed for rewards tokens cannot be withdrawn.
  /// @param _token The token contract address or zero for native currency.
  /// @param _to The receiver address or zero for caller address.
  /// @param _amount The amount of token to withdraw or zero for full amount.
  function withdraw(address _token, address payable _to, uint _amount) external onlyAdmin() {
    if (_tokenAllowed(_token)) revert RewardWithdrawalDenied(_token);
    if (_to == payable(0)) {
      _to = payable(_msgSender());
    }
    emit Withdraw(_token, _to, _amount);
    if (_token == address(0)) {
      _to.sendValue(_amount == 0 ? address(this).balance : _amount);
      return;
    }
    _transferToken(_token, RewardType.ERC20, _to, 0, _amount == 0 ? _tryBalanceOfThis(_token) : _amount);
  }

  function mintToMany(address[] calldata _tos, uint[] calldata _lootboxTypes, uint[] calldata _amounts) external onlyRole(MINTER_ROLE) {
    uint len = _tos.length;
    if (len != _lootboxTypes.length || len != _amounts.length) revert InvalidLength();
    for (uint i = 0; i < len; i = _inc(i)) {
      _mint(_tos[i], _lootboxTypes[i], _amounts[i], '');
    }
  }

  /*//////////////////////////////////////////////////////////////
                              VRF LOGIC
  //////////////////////////////////////////////////////////////*/

  /// @notice Requests randomness from Chainlink VRF.
  /// @dev The VRF subscription must be active and sufficient LINK must be available.
  /// @return requestId The ID of the request.
  function _requestRandomness(uint32 _gas) internal returns (uint256 requestId) {
    return requestRandomness(
      _gas,
      REQUEST_CONFIRMATIONS,
      NUMWORDS
    );
  }

  /// @inheritdoc VRFV2WrapperConsumerBase
  function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
    try this._allocateRewards{gas: gasleft() - 20000}(requestId, randomWords[0]) {
      emit OpenRequestFulfilled(requestId, randomWords[0]);
    } catch (bytes memory reason) {
      Request storage request = requests[requestId];
      unitsRequested = unitsRequested - request.unitsToGet;
      request.unitsToGet = 0;
      emit OpenRequestFailed(requestId, reason);
    }
  }

  /*//////////////////////////////////////////////////////////////
                         INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Removes an authorized supplier for the contract.
  /// @param _address The address being removed.
  function _removeSupplier(address _address) internal {
    if (suppliers.remove(_address)) {
      emit SupplierRemoved(_address);
    }
  }

  /// @notice Adds a supplier for the contract.
  /// @param _address The address being added.
  function _addSupplier(address _address) internal {
    if (suppliers.add(_address)) {
      emit SupplierAdded(_address);
    }
  }

  /// @notice Adds a supplier for the contract.
  /// @param _token The token address being added.
  function _addToken(address _token) internal {
    if (_token == address(0)) revert TokenDenied(_token);
    if (allowedTokens.add(_token)) {
      emit TokenAdded(_token);
    }
  }

  // TODO: Deal with the ERC721 sent through simple transferFrom, instead of safeTransferFrom.
  /// @notice Sets amount per unit.
  /// @param _currentSupply The current supply of units.
  /// @param _token The token being supplied.
  /// @param _id The id being used.
  /// @param _amountPerUnit The amount per unit.
  /// @return uint The new supply of units after calculation.
  function _setAmountPerUnit(uint _currentSupply, address _token, uint _id, uint _amountPerUnit) internal returns (uint) {
    if (_not(_tokenAllowed(_token))) revert TokenDenied(_token);
    Reward storage reward = rewards[_token];
    uint unitsOld = units(reward.rewardInfo);
    uint unitsNew;
    RewardType rewardType = reward.rewardType;
    if (rewardType == RewardType.UNSET) {
      // Assuming ERC20.
      if (_tryBalanceOfThis(_token) == 0) revert NoTokens();
      rewardType = RewardType.ERC20;
      reward.rewardType = rewardType;
    }

    uint newAmountPerUnit = _amountPerUnit;
    if (rewardType == RewardType.ERC20) {
      unitsNew = _amountPerUnit == 0 ? 0 : (_tryBalanceOfThis(_token) - allocated[_token][0]) / _amountPerUnit;
    } else if (rewardType == RewardType.ERC721 || rewardType == RewardType.ERC1155NFT) {
      unitsNew = _amountPerUnit == 0 ? 0 : reward.ids.length() / _amountPerUnit;
    } else if (rewardType == RewardType.ERC1155) {
      uint tokenUnitsOld = units(reward.extraInfo[_id]);
      uint balance = _balanceOfThis1155(_token, _id) - allocated[_token][_id];
      uint tokenUnitsNew = _amountPerUnit == 0 ? 0 : balance / _amountPerUnit;
      reward.extraInfo[_id] = toInfo(tokenUnitsNew, _amountPerUnit);
      newAmountPerUnit = amountPerUnit(reward.rewardInfo);
      unitsNew = unitsOld - tokenUnitsOld + tokenUnitsNew;
      if (tokenUnitsNew > 0) {
        reward.ids.add(_id);
      } else {
        reward.ids.remove(_id);
      }
    }
    reward.rewardInfo = toInfo(unitsNew, newAmountPerUnit);
    uint newSupply = _currentSupply - unitsOld + unitsNew;
    if (unitsNew > 0) {
      inventory.add(_token);
    } else {
      inventory.remove(_token);
    }

    emit AmountPerUnitSet(_token, _id, _amountPerUnit, newSupply);
    return newSupply;
  }

  /// @notice Gets LINK price.
  /// @return uint The link price from wei converted to uint.
  function _getLinkPrice() internal view returns (uint) {
    return LootboxInterface(address(this)).getLinkPrice();
  }

  /// @notice Allows specific 1155 tokens to be used in the inventory.
  /// @param token The token address.
  /// @param id The token id.
  /// @param value The token value.
  function _supply1155(address token, uint id, uint value) internal {
    if (value == 0) revert ZeroSupply(token, id);
    Reward storage reward = rewards[token];
    RewardInfo rewardInfo = reward.rewardInfo;
    RewardType rewardType = reward.rewardType;
    bool isFirstTime = rewardType == RewardType.UNSET;
    if (isFirstTime) {
      if (value == 1) {
        // If the value is 1, then we assume token to be distributed as NFT.
        rewardInfo = toInfo(0, 1);
        reward.rewardInfo = rewardInfo;
        rewardType = RewardType.ERC1155NFT;
      } else {
        rewardType = RewardType.ERC1155;
      }
      reward.rewardType = rewardType;
    } else if (rewardType != RewardType.ERC1155 && rewardType != RewardType.ERC1155NFT) {
      revert ModifiedRewardType(reward.rewardType, RewardType.ERC1155);
    }
    if (rewardType == RewardType.ERC1155) {
      _supply1155(reward, rewardInfo, token, id, value);
    } else {
      if (value > 1) revert InvalidTokenAmount();
      _supplyNFT(reward, rewardInfo, token, id);
    }
  }

  /// @notice Allows specific 1155 tokens to be used in the inventory with reward information.
  /// @param rewardInfo The reward information.
  /// @param token The token address.
  /// @param id The token id.
  /// @param value The token value.
  function _supply1155(Reward storage reward, RewardInfo rewardInfo, address token, uint id, uint value) internal {
    RewardInfo extraInfo = reward.extraInfo[id];
    bool isNotConfigured = isEmpty(extraInfo);
    uint unitsOld = units(extraInfo);
    uint unitsNew = unitsOld + (isNotConfigured ? 0 : (value / amountPerUnit(extraInfo)));
    uint unitsAdded = unitsNew - unitsOld;
    if (unitsAdded > 0) {
      unitsSupply = unitsSupply + unitsAdded;
      reward.extraInfo[id] = toInfo(unitsNew, amountPerUnit(extraInfo));
      if (unitsOld == 0) {
        if (_not(reward.ids.add(id))) revert DepositStateCorruption(token, id);
      }
      uint tokenUnitsOld = units(rewardInfo);
      reward.rewardInfo = toInfo(tokenUnitsOld + unitsAdded, amountPerUnit(rewardInfo));
      if (tokenUnitsOld == 0) {
        if (_not(inventory.add(token))) revert InventoryStateCorruption(token);
      }
    }
    if (isNotConfigured) {
      extraIds[token].add(id);
    }
  }

  /// @notice Allows specific NFTs to be used in the inventory with reward information.
  /// @param rewardInfo The reward information.
  /// @param token The token address.
  /// @param id The token id.
  function _supplyNFT(Reward storage reward, RewardInfo rewardInfo, address token, uint id) internal {
    if (_not(reward.ids.add(id))) revert DepositStateCorruption(token, id);
    uint perUnit = amountPerUnit(rewardInfo);
    uint unitsOld = units(rewardInfo);
    uint unitsNew = perUnit == 0 ? 0 : (reward.ids.length() / perUnit);
    uint unitsAdded = unitsNew - unitsOld;
    if (unitsAdded > 0) {
      reward.rewardInfo = toInfo(unitsNew, perUnit);
      unitsSupply = unitsSupply + unitsAdded;
      if (unitsOld == 0) {
        if (_not(inventory.add(token))) revert InventoryStateCorruption(token);
      }
    }
  }

  /// @dev Requests randomness from Chainlink VRF and stores the request data for later use.
  /// @notice Creates a lootbox open request for the given loot.
  /// @param _opener The address requesting to open the lootbox.
  /// @param _gas The gas amount.
  /// @param _lootIds An array of loot ids.
  /// @param _lootAmounts An array of loot amounts.
  /// @return uint The units.
  function _requestOpen(
    address _opener,
    uint32 _gas,
    uint[] memory _lootIds,
    uint[] memory _lootAmounts
  ) internal returns (uint) {
    if (openerRequests[_opener] != 0) revert PendingOpenRequest(openerRequests[_opener]);
    if (_gas < 100000) revert InsufficientGas();
    _burnBatch(_opener, _lootIds, _lootAmounts);
    uint unitsToGet = 0;
    uint ids = _lootIds.length;
    for (uint i = 0; i < ids; i = _inc(i)) {
      unitsToGet += _lootIds[i] * _lootAmounts[i];
    }
    if (unitsToGet == 0) revert ZeroAmount();
    uint unitsAvailable = unitsSupply - unitsRequested;
    if (unitsAvailable < unitsToGet) revert SupplyExceeded(unitsAvailable, unitsToGet);

    unitsRequested = unitsRequested + unitsToGet;
    uint256 requestId = _requestRandomness(_gas);

    Request storage request = requests[requestId];
    request.opener = _opener;
    request.unitsToGet = unitsToGet.toUint96();
    request.lootIds = _lootIds;
    request.lootAmounts = _lootAmounts;

    openerRequests[_opener] = requestId;

    emit OpenRequested(_opener, unitsToGet, requestId);

    return unitsToGet;
  }

  function _allocate(address _token, uint _id, uint _amount) internal {
    allocated[_token][_id] += _amount;
  }

  function _deAllocate(address _token, uint _id, uint _amount) internal {
    allocated[_token][_id] -= _amount;
  }

  function _emitAllocated(address _to, address _token, uint _id, uint _amount) internal {
    emit Allocated(_to, _token, _id, _amount);
  }

  function _emitClaimed(address _claimer, address _token, uint _id, uint _amount) internal {
    emit RewardsClaimed(_claimer, _token, _id, _amount);
  }

  // Meant to reduce bytecode size.
  function _reduceRandom(bytes memory _input, uint _target) internal pure returns (uint) {
    return uint(keccak256(_input)) % _target;
  }

  /// @notice Picks the rewards using the given randomness as a seed.
  /// @param _requestId The amount of lootbox units the user is opening.
  /// @param _randomness The random number used to pick the rewards.
  function _allocateRewards(
    uint256 _requestId,
    uint256 _randomness
  ) external {
    if (msg.sender != address(this)) revert OnlyThis();
    address opener = requests[_requestId].opener;
    uint unitsToGet = requests[_requestId].unitsToGet;
    if (unitsToGet == 0) revert InvalidRequestAllocation(_requestId);
    delete requests[_requestId];
    delete openerRequests[opener];
    uint256 totalUnits = unitsSupply;
    unitsSupply = totalUnits - unitsToGet;
    unitsRequested = unitsRequested - unitsToGet;

    for (; unitsToGet > 0; --unitsToGet) {
      uint256 target = _reduceRandom(abi.encodePacked(_randomness, unitsToGet), totalUnits);
      uint256 offset = 0;

      for (uint256 j = 0;; j = _inc(j)) {
        address token = inventory.at(j);
        AllocationInfo storage openerInfo = allocationInfo[opener][token];
        Reward storage reward = rewards[token];
        RewardType rewardType = reward.rewardType;
        uint256 unitsOfToken = units(reward.rewardInfo);

        if (target < offset + unitsOfToken) {
          --totalUnits;
          uint amount = amountPerUnit(reward.rewardInfo);
          reward.rewardInfo = toInfo(unitsOfToken - 1, amount);
          if (unitsOfToken - 1 == 0) {
            inventory.remove(token);
          }
          if (rewardType == RewardType.ERC20) {
            openerInfo.amount[0] += amount;
            _allocate(token, 0, amount);
            _emitAllocated(opener, token, 0, amount);
          }
          else if (rewardType == RewardType.ERC721 || rewardType == RewardType.ERC1155NFT) {
            uint ids = reward.ids.length();
            for (uint k = 0; k < amount; k = _inc(k)) {
              target = _reduceRandom(abi.encodePacked(_randomness, unitsToGet, k), ids);
              uint tokenId = reward.ids.at(target);
              reward.ids.remove(tokenId);
              --ids;
              openerInfo.ids.add(tokenId);
              _emitAllocated(opener, token, tokenId, 1);
            }
          }
          else if (rewardType == RewardType.ERC1155) {
            // Reusing variables before inevitable break of the loop.
            target = target - offset;
            offset = 0;
            for (uint k = 0;; k = _inc(k)) {
              uint id = reward.ids.at(k);
              RewardInfo extraInfo = reward.extraInfo[id];
              unitsOfToken = units(extraInfo);
              if (target < offset + unitsOfToken) {
                amount = amountPerUnit(extraInfo);
                extraInfo = toInfo(unitsOfToken - 1, amount);
                reward.extraInfo[id] = extraInfo;
                openerInfo.ids.add(id);
                openerInfo.amount[id] += amount;
                _allocate(token, id, amount);
                if (units(extraInfo) == 0) {
                  reward.ids.remove(id);
                }
                _emitAllocated(opener, token, id, amount);
                break;
              }

              offset += unitsOfToken;
            }
          }
          else {
            revert UnexpectedRewardType(rewardType);
          }

          break;
        }

        offset += unitsOfToken;
      }
    }
  }

  function _tokenAllowed(address _token) internal view returns (bool) {
    return allowedTokens.contains(_token);
  }

  function _validateReceive(address _from) internal view returns (address) {
    address token = msg.sender;
    if (_not(_tokenAllowed(token))) revert TokenDenied(token);
    if (_not(suppliers.contains(_from))) revert SupplyDenied(_from);
    return token;
  }

  function _transferToken(address _token, RewardType _type, address _to, uint _id, uint _amount) internal {
    if (_type == RewardType.ERC20) {
      IERC20(_token).safeTransfer(_to, _amount);
    } else if (_type == RewardType.ERC721) {
      IERC721(_token).safeTransferFrom(address(this), _to, _id);
    } else if (_type == RewardType.ERC1155 || _type == RewardType.ERC1155NFT) {
      IERC1155(_token).safeTransferFrom(address(this), _to, _id, _amount, '');
    } else {
      revert UnexpectedRewardType(_type);
    }
  }

  /// @notice Checks the balance of an erc20 token.
  /// @param _token The token being checked.
  /// @return uint erc20 token balance, else 0 if not an erc20 token.
  function _tryBalanceOfThis(address _token) internal view returns (uint) {
    try IERC20(_token).balanceOf(address(this)) returns(uint result) {
      return result;
    } catch {
      // not an ERC20 so has to transfer first.
      return 0;
    }
  }

  function _balanceOfThis1155(address _token, uint _id) internal view returns (uint) {
    return IERC1155(_token).balanceOf(address(this), _id);
  }

  /// @notice Checks units by by reward information.
  /// @param _rewardInfo The reward information.
  /// @return RewardInfo Reward information as uint.
  function units(RewardInfo _rewardInfo) internal pure returns (uint) {
    return RewardInfo.unwrap(_rewardInfo) >> UNITS_OFFSET;
  }

  /// @notice Checks amount per unity by reward information.
  /// @param _rewardInfo The reward information.
  /// @return RewardInfo Reward information as uint.
  function amountPerUnit(RewardInfo _rewardInfo) internal pure returns (uint) {
    return uint184(RewardInfo.unwrap(_rewardInfo));
  }

  /// @notice Checks amount per unity by reward information.
  /// @param _units The reward information.
  /// @param _amountPerUnit The amount per unit.
  /// @return RewardInfo Reward information or amounts per unit.
  function toInfo(uint _units, uint _amountPerUnit) internal pure returns (RewardInfo) {
    if (_units > type(uint64).max) revert UnitsOverflow(_units);
    if (_amountPerUnit > type(uint184).max) revert AmountPerUnitOverflow(_amountPerUnit);
    return RewardInfo.wrap(uint248((_units << UNITS_OFFSET) | _amountPerUnit));
  }

  /// @notice Checks if reward information is empty.
  /// @param _rewardInfo The reaward information.
  /// @return RewardInfo Empty reward information.
  function isEmpty(RewardInfo _rewardInfo) internal pure returns (bool) {
    return RewardInfo.unwrap(_rewardInfo) == 0;
  }

  /// @notice Returns value bool.
  /// @dev Meant to improve readability over the ! operator.
  /// @param _value Boolean value.
  /// @return bool Opposite bool value.
  function _not(bool _value) internal pure returns (bool) {
    return !_value;
  }

  function _inc(uint i) internal pure returns (uint) {
    unchecked {
      return i + 1;
    }
  }

  /// @dev Inspired by OZ implementation.
  function _revert(bytes memory _returnData) private pure {
    // Look for revert reason and bubble it up if present
    if (_returnData.length > 0) {
      // The easiest way to bubble the revert reason is using memory via assembly
      assembly {
        let returndata_size := mload(_returnData)
        revert(add(32, _returnData), returndata_size)
      }
    }
    revert ViewCallFailed();
  }

  function _notEmergency() internal view {
    if (isEmergencyMode) revert EndOfService();
  }

  /**
   * @dev See {IERC165-supportsInterface}.
   */
  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155Receiver, ERC1155PresetMinterPauser)
    returns (bool)
  {
    return ERC1155Receiver.supportsInterface(interfaceId) ||
      ERC1155PresetMinterPauser.supportsInterface(interfaceId);
  }

  /// @notice Fires after token transfer.
  /// @param operator Boolean value.
  /// @param from From address.
  /// @param to To address.
  /// @param ids Id array.
  /// @param amounts Amounts array.
  /// @param data Data in bytes.
  function _afterTokenTransfer(
    address operator,
    address from,
    address to,
    uint256[] memory ids,
    uint256[] memory amounts,
    bytes memory data
  ) internal virtual override {
    if (from == address(0)) {
      uint unitBoxesAdded = 0;
      uint len = ids.length;
      for (uint i = 0; i < len; i = _inc(i)) {
        uint id = ids[i];
        if (id == 0 || id > type(uint8).max) revert InvalidLootboxType();
        lootboxTypes.add(id);
        unitBoxesAdded = unitBoxesAdded + (id * amounts[i]);
      }
      unitsMinted = unitsMinted + unitBoxesAdded;
    }
    if (to == address(0)) {
      uint unitBoxesRemoved = 0;
      uint len = ids.length;
      for (uint i = 0; i < len; i = _inc(i)) {
        unitBoxesRemoved = unitBoxesRemoved + (ids[i] * amounts[i]);
      }
      unitsMinted = unitsMinted - unitBoxesRemoved;
    }
    super._afterTokenTransfer(operator, from, to, ids, amounts, data);
  }

  // @dev Added override for code size optimization.
  function _checkRole(bytes32 role) internal view override {
    if (_not(hasRole(role, _msgSender()))) revert AccessDenied(role);
  }

  function pause() public override onlyPauser() {
    _pause();
  }

  function unpause() public override onlyPauser() {
    _unpause();
  }
}


// File: contracts/LootboxInterface.sol
// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC1155PresetMinterPauser} from '@openzeppelin/contracts/token/ERC1155/presets/ERC1155PresetMinterPauser.sol';
import {ERC721Holder} from '@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol';
import {ERC1155Holder, ERC1155Receiver} from '@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol';
import {VRFV2WrapperConsumerBase} from '@chainlink/contracts/src/v0.8/VRFV2WrapperConsumerBase.sol';
import {EnumerableSet} from '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {ILootboxFactory} from './interfaces/ILootboxFactory.sol';
import {IVRFV2Wrapper, AggregatorV3Interface} from './interfaces/IVRFV2Wrapper.sol';
import {RewardInfo} from './Lootbox.sol';

//  $$$$$$\  $$\   $$\  $$$$$$\  $$$$$$\ $$\   $$\  $$$$$$\   $$$$$$\  $$$$$$$$\ $$$$$$$$\ 
// $$  __$$\ $$ |  $$ |$$  __$$\ \_$$  _|$$$\  $$ |$$  __$$\ $$  __$$\ $$  _____|$$  _____|
// $$ /  \__|$$ |  $$ |$$ /  $$ |  $$ |  $$$$\ $$ |$$ /  \__|$$ /  $$ |$$ |      $$ |      
// $$ |      $$$$$$$$ |$$$$$$$$ |  $$ |  $$ $$\$$ |\$$$$$$\  $$$$$$$$ |$$$$$\    $$$$$\    
// $$ |      $$  __$$ |$$  __$$ |  $$ |  $$ \$$$$ | \____$$\ $$  __$$ |$$  __|   $$  __|   
// $$ |  $$\ $$ |  $$ |$$ |  $$ |  $$ |  $$ |\$$$ |$$\   $$ |$$ |  $$ |$$ |      $$ |      
// \$$$$$$  |$$ |  $$ |$$ |  $$ |$$$$$$\ $$ | \$$ |\$$$$$$  |$$ |  $$ |$$ |      $$$$$$$$\ 
//  \______/ \__|  \__|\__|  \__|\______|\__|  \__| \______/ \__|  \__|\__|      \________|                                                                                                                                                                              
                                                                                        
// $$\       $$$$$$\   $$$$$$\ $$$$$$$$\ $$$$$$$\   $$$$$$\  $$\   $$\ $$$$$$$$\  $$$$$$\  
// $$ |     $$  __$$\ $$  __$$\\__$$  __|$$  __$$\ $$  __$$\ $$ |  $$ |$$  _____|$$  __$$\ 
// $$ |     $$ /  $$ |$$ /  $$ |  $$ |   $$ |  $$ |$$ /  $$ |\$$\ $$  |$$ |      $$ /  \__|
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$$$$$$\ |$$ |  $$ | \$$$$  / $$$$$\    \$$$$$$\  
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$  __$$\ $$ |  $$ | $$  $$<  $$  __|    \____$$\ 
// $$ |     $$ |  $$ |$$ |  $$ |  $$ |   $$ |  $$ |$$ |  $$ |$$  /\$$\ $$ |      $$\   $$ |
// $$$$$$$$\ $$$$$$  | $$$$$$  |  $$ |   $$$$$$$  | $$$$$$  |$$ /  $$ |$$$$$$$$\ \$$$$$$  |
// \________|\______/  \______/   \__|   \_______/  \______/ \__|  \__|\________| \______/ 

/// @title Lootbox Interface to combine Lootbox implementation and View contracts.
/// @author ChainSafe Systems: Oleksii (Functionality) Sneakz (Natspec assistance)

abstract contract LootboxInterface is VRFV2WrapperConsumerBase, ERC721Holder, ERC1155Holder, ERC1155PresetMinterPauser {
  enum RewardType {
    UNSET,
    ERC20,
    ERC721,
    ERC1155,
    ERC1155NFT
  }

  struct Reward {
    RewardType rewardType;
    RewardInfo rewardInfo;
    EnumerableSet.UintSet ids; // only 721 and 1155
    mapping(uint => RewardInfo) extraInfo; // only for 1155
  }

  struct AllocationInfo {
    EnumerableSet.UintSet ids;
    mapping(uint => uint) amount; // id 0 for ERC20
  }

  ILootboxFactory public FACTORY;
  AggregatorV3Interface public LINK_ETH_FEED;

  uint public unitsSupply; // Supply of units.
  uint public unitsRequested; // Amount of units requested for opening.
  uint public unitsMinted; // Boxed units.
  bool public isEmergencyMode; // State of emergency.

  /*//////////////////////////////////////////////////////////////
                             VRF RELATED
  //////////////////////////////////////////////////////////////*/

  /// @notice The VRF request struct
  struct Request {
    address opener;
    uint96 unitsToGet;
    uint[] lootIds;
    uint[] lootAmounts;
  }

  /// @notice The VRF request IDs and their corresponding openers
  mapping(address => uint256) public openerRequests;

  struct ExtraRewardInfo {
    uint id;
    uint units;
    uint amountPerUnit;
    uint balance;
  }

  struct RewardView {
    address rewardToken;
    RewardType rewardType;
    uint units;
    uint amountPerUnit;
    uint balance;
    ExtraRewardInfo[] extra;
  }

  /*//////////////////////////////////////////////////////////////
                                EVENTS
  //////////////////////////////////////////////////////////////*/

  /// @notice Emitted when a lootbox is openning is requested
  /// @param opener The address of the user that requested the open
  /// @param unitsToGet The amount of lootbox units to receive
  /// @param requestId The ID of the VRF request
  event OpenRequested(address opener, uint256 unitsToGet, uint256 requestId);

  /// @notice Emitted when a randomness request is fulfilled and the lootbox rewards can be claimed
  /// @param requestId The ID of the VRF request
  /// @param randomness The random number that was generated
  event OpenRequestFulfilled(uint256 requestId, uint256 randomness);

  /// @notice Emitted when a randomness request ran out of gas and now must be recovered
  /// @param requestId The ID of the VRF request
  event OpenRequestFailed(uint256 requestId, bytes reason);

  event SupplierAdded(address supplier);

  event SupplierRemoved(address supplier);

  /// @notice Emitted when a new reward token gets whitelisted for supply
  event TokenAdded(address token);

  /// @notice Emitted when a reward token amount per unit changes
  /// @param newSupply The new supply of reward units available
  event AmountPerUnitSet(address token, uint tokenId, uint amountPerUnit, uint newSupply);

  /// @notice Emitted when the lootbox rewards are claimed
  /// @param opener The address of the user that received the rewards
  /// @param token The rewarded token contract address
  /// @param tokenId The internal tokenId for ERC721 and ERC1155
  /// @param amount The amount of claimed tokens
  event RewardsClaimed(address opener, address token, uint tokenId, uint amount);

  /// @notice Emitted when the lootbox rewards are allocated
  /// @param opener The address of the user that received the allocation
  /// @param token The rewarded token contract address
  /// @param tokenId The internal tokenId for ERC721 and ERC1155
  /// @param amount The amount of allocated tokens
  event Allocated(address opener, address token, uint tokenId, uint amount);

  /// @notice Emitted when the lootboxes gets recovered from a failed open request
  /// @param opener The address of the user that received the allocation
  /// @param requestId The ID of the VRF request
  event BoxesRecovered(address opener, uint requestId);

  /// @notice Emitted when the contract stops operation and assets being withdrawn by the admin
  /// @param caller The address of the admin who initiated the emergency
  event EmergencyModeEnabled(address caller);

  /// @notice Emitted when an admin withdraws assets in case of emergency
  /// @param token The token contract address
  /// @param tokenType The type of asset of token contract
  /// @param to The address that received the withdrawn assets
  /// @param ids The internal tokenIds for ERC721 and ERC1155
  /// @param amounts The amounts of withdrawn tokens/ids
  event EmergencyWithdrawal(address token, RewardType tokenType, address to, uint[] ids, uint[] amounts);

  /// @notice Emitted when an admin withdraws ERC20 or native currency
  /// @param token The token contract address or zero for native currency
  /// @param to The address that received the withdrawn assets
  /// @param amount The amount withdrawn
  event Withdraw(address token, address to, uint amount);

  /// @notice Emitted when an admin sets purchase price
  /// @param newPrice The amount of native currency to pay to buy a lootbox, or 0 if disabled
  event PriceUpdated(uint newPrice);

  /// @notice Emitted when user buys lootboxes
  /// @param buyer The address of the user that purchased lootboxes
  /// @param amount The amount of id 1 lootboxes sold
  /// @param payment The amount of native currency user paid
  event Sold(address buyer, uint amount, uint payment);

  /*//////////////////////////////////////////////////////////////
                                ERRORS
  //////////////////////////////////////////////////////////////*/

  /// @notice There are no tokens to put in the lootbox
  error NoTokens();

  /// @notice The tokens array length does not match the perUnitAmounts array length
  error InvalidLength();

  /// @notice Supplying 1155NFT with amount > 1
  error InvalidTokenAmount();

  /// @notice The amount to open is zero
  error ZeroAmount();

  /// @notice Token not allowed as reward
  error TokenDenied(address token);

  /// @notice Deposits only allowed from whitelisted addresses
  error SupplyDenied(address from);

  /// @notice The amount to open exceeds the supply
  error SupplyExceeded(uint256 supply, uint256 unitsToGet);

  /// @notice The new supply amount is less than already requested to open
  error InsufficientSupply(uint256 supply, uint256 requested);

  /// @notice Has to finish the open request first
  error PendingOpenRequest(uint256 requestId);

  /// @notice Has to open some lootboxes first
  error NothingToClaim();

  /// @notice Reward type is immutable
  error ModifiedRewardType(RewardType oldType, RewardType newType);

  /// @notice Only LINK could be sent with an ERC677 call
  error AcceptingOnlyLINK();

  /// @notice Not enough pay for a VRF request
  error InsufficientPayment();

  /// @notice Not enough pay for a lootbox opening fee
  error InsufficientFee();

  /// @notice There should be a failed VRF request for recovery
  error NothingToRecover();

  /// @notice LINK price must be positive from an oracle
  error InvalidLinkPrice(int value);

  /// @notice Zero value ERC1155 supplies are not alloved
  error ZeroSupply(address token, uint id);

  /// @notice Function could only be called by this contract itself
  error OnlyThis();

  /// @notice Unexpected reward type for current logic
  error UnexpectedRewardType(RewardType rewardType);

  /// @notice Units should fit in 64 bits
  error UnitsOverflow(uint value);

  /// @notice Amount per unit should fit in 184 bits
  error AmountPerUnitOverflow(uint value);

  /// @notice Token id was already present in the inventory with units set to 0
  error DepositStateCorruption(address token, uint tokenId);

  /// @notice Token was already present in the inventory with units set to 0
  error InventoryStateCorruption(address token);

  /// @notice Not enough gas is provided for opening
  error InsufficientGas();

  /// @notice Lootbox id represents the number of rewrad units it will produce, so it should be > 0 and < 256
  error InvalidLootboxType();

  /// @notice The request is either already failed/fulfilled or was never created
  error InvalidRequestAllocation(uint requestId);

  /// @notice Requested operation is not supported in current version
  error Unsupported();

  /// @notice Token is allowed as reward and cannot be withdrawn
  error RewardWithdrawalDenied(address token);

  /// @notice Contrat was put into emergency mode and stopped operations
  error EndOfService();

  /// @notice View function reverted without reason
  error ViewCallFailed();

  /// @notice Purchase price is unexpectedly high or zero
  error UnexpectedPrice(uint currentPrice);

  /// @notice Caller does not have required role
  error AccessDenied(bytes32 role);

  /// @notice Sets the URI for the contract.
  /// @param _baseURI The base URI being used.
  function setURI(string memory _baseURI) external virtual;

  /// @notice Adds loot suppliers.
  /// @param _suppliers An array of loot suppliers being added.
  function addSuppliers(address[] calldata _suppliers) external virtual;

  /// @notice Removes contract suppliers.
  /// @param _suppliers An array of suppliers being removed.
  function removeSuppliers(address[] calldata _suppliers) external virtual;

  /// @notice Adds tokens for lootbox usage.
  /// @param _tokens An array of tokens being added.
  function addTokens(address[] calldata _tokens) external virtual;

  /// @notice Sets the how much of a token you get per lootbox.
  /// @dev Stops working during the emergency.
  /// @param _tokens An array of tokens being added.
  /// @param _ids An array of ids being added.
  /// @param _amountsPerUnit An array of amounts being added.
  function setAmountsPerUnit(address[] calldata _tokens, uint[] calldata _ids, uint[] calldata _amountsPerUnit) external virtual;

  function emergencyWithdraw(address _token, RewardType _type, address _to, uint[] calldata _ids, uint[] calldata _amounts) external virtual;

  /// @notice Requests a lootbox openning paying with native currency
  /// @param _gas Gas limit for allocation
  /// @param _lootIds Lootbox ids to open
  /// @param _lootAmounts Lootbox amounts to open
  function open(uint32 _gas, uint[] calldata _lootIds, uint[] calldata _lootAmounts) external payable virtual;

  /// @notice Claims the rewards for the lootbox openning.
  /// @dev The user must have some rewards allocated.
  /// @param _opener The address of the user that has an allocation after opening.
  function claimRewards(address _opener) external virtual;


  /*//////////////////////////////////////////////////////////////
                           BUY FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @notice Sets the native currency price to buy a lootbox.
  /// @notice Set to 0 to prevent sales.
  /// @param _newPrice An amount of native currency user needs to pay to get a single lootbox.
  function setPrice(uint _newPrice) external virtual;

  /// @notice Gets the native currency price to buy a lootbox.
  function getPrice() external view virtual returns(uint);

  /// @notice Mints requested amount of lootboxes for the caller assuming valid payment.
  /// @notice Remainder is sent back to the caller.
  /// @param _amount An amount lootboxes to mint.
  /// @param _maxPrice A maximum price the caller is willing to pay per lootbox.
  function buy(uint _amount, uint _maxPrice) external payable virtual;

  /// @notice Used to recover lootboxes for an address.
  /// @param _opener The address that opened the boxes.
  function recoverBoxes(address _opener) external virtual;

  /// @notice Picks the rewards using the given randomness as a seed.
  /// @param _requestId The amount of lootbox units the user is opening.
  /// @param _randomness The random number used to pick the rewards.
  function _allocateRewards(uint256 _requestId, uint256 _randomness) external virtual;

  /*//////////////////////////////////////////////////////////////
                          GETTER FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function viewCall() external virtual;

  /// @notice Transfer the contract balance to the owner.
  /// @dev Allowed for rewards tokens cannot be withdrawn.
  /// @param _token The token contract address or zero for native currency.
  /// @param _to The receiver address or zero for caller address.
  /// @param _amount The amount of token to withdraw or zero for full amount.
  function withdraw(address _token, address payable _to, uint _amount) external virtual;

  function mintToMany(address[] calldata _tos, uint[] calldata _lootboxTypes, uint[] calldata _amounts) external virtual;

  /// @notice Gets number of units that still could be requested for opening.
  /// @dev Returns 0 during emergency.
  /// @return uint number of units.
  function getAvailableSupply() external virtual view returns (uint);

  /// @notice Gets lootbox types that have been minted for the contract.
  /// @return uint Array of lootbox types that have been minted.
  function getLootboxTypes() external virtual view returns (uint[] memory);

  /// @notice Gets allowed reward tokens for the contract.
  /// @return address Array of reward tokens addresses if they exist and are allowed.
  function getAllowedTokens() external virtual view returns (address[] memory);

  /// @notice Gets allowed token reward types for the contract.
  /// @return result Array of token reward types in the same order as getAllowedTokens().
  function getAllowedTokenTypes() external virtual view returns (RewardType[] memory result);

  /// @notice Gets authorized suppliers for the contract.
  /// @return address Array of addresses if they exist and are allowed to supply.
  function getSuppliers() external virtual view returns (address[] memory);

  /// @notice Gets allowed tokens for the contract.
  /// @param _token The token being allowed.
  /// @return bool True if the token if it exists and is allowed.
  function tokenAllowed(address _token) external virtual view returns (bool);

  /// @notice Gets allowed supply address for the contract.
  /// @param _from The address of the supplier.
  /// @return bool True if the address of the supplier exists and is allowed.
  function supplyAllowed(address _from) external virtual view returns (bool);

  /// @notice Calculates the opening price of lootboxes.
  /// @param _gas The gas of the request price.
  /// @param _gasPriceInWei The gas price for the opening transaction.
  /// @param _units The units being calculated.
  /// @return uint The VRF price after calculation with units and fees.
  function calculateOpenPrice(uint32 _gas, uint _gasPriceInWei, uint _units) external virtual view returns (uint);

  /// @notice Returns the tokens and amounts per unit of the lootbox.
  /// @return result The list of rewards available for getting.
  /// @return leftoversResult The list of rewards that are not configured or has insufficient supply.
  function getInventory() external virtual view returns (RewardView[] memory result, RewardView[] memory leftoversResult);

  /// @notice Returns whether the rewards for the given opener can be claimed.
  /// @param _opener The address of the user that opened the lootbox.
  /// @return bool True if claim is possible, otherwise false.
  function canClaimRewards(address _opener) public view virtual returns (bool);

  /// @notice Returns details of the lootbox open request.
  /// @notice If request is not empty but unitsToGet == 0, then user need to recoverBoxes().
  /// @param _opener The address of the user that opened the lootbox.
  /// @return request empty if there are no pending request.
  function getOpenerRequestDetails(address _opener) external virtual view returns (Request memory request);

  /// @notice Gets the LINK token address.
  /// @return address The address of the LINK token.
  function getLink() external view virtual returns (address);

  /// @notice Gets the VRF wrapper for the contract.
  /// @return address The address of the VRF wrapper.
  function getVRFV2Wrapper() external view virtual returns (address);

  function getLinkPrice() external view virtual returns (uint);

  function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC1155Receiver, ERC1155PresetMinterPauser)
    returns (bool)
  {
    return ERC1155Receiver.supportsInterface(interfaceId) ||
      ERC1155PresetMinterPauser.supportsInterface(interfaceId);
  }
}


