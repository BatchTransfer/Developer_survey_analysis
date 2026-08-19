// File: @openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (proxy/utils/Initializable.sol)

pragma solidity ^0.8.2;

import "../../utils/AddressUpgradeable.sol";

/**
 * @dev This is a base contract to aid in writing upgradeable contracts, or any kind of contract that will be deployed
 * behind a proxy. Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
 * external initializer function, usually called `initialize`. It then becomes necessary to protect this initializer
 * function so it can only be called once. The {initializer} modifier provided by this contract will have this effect.
 *
 * The initialization functions use a version number. Once a version number is used, it is consumed and cannot be
 * reused. This mechanism prevents re-execution of each "step" but allows the creation of new initialization steps in
 * case an upgrade adds a module that needs to be initialized.
 *
 * For example:
 *
 * [.hljs-theme-light.nopadding]
 * ```solidity
 * contract MyToken is ERC20Upgradeable {
 *     function initialize() initializer public {
 *         __ERC20_init("MyToken", "MTK");
 *     }
 * }
 *
 * contract MyTokenV2 is MyToken, ERC20PermitUpgradeable {
 *     function initializeV2() reinitializer(2) public {
 *         __ERC20Permit_init("MyToken");
 *     }
 * }
 * ```
 *
 * TIP: To avoid leaving the proxy in an uninitialized state, the initializer function should be called as early as
 * possible by providing the encoded function call as the `_data` argument to {ERC1967Proxy-constructor}.
 *
 * CAUTION: When used with inheritance, manual care must be taken to not invoke a parent initializer twice, or to ensure
 * that all initializers are idempotent. This is not verified automatically as constructors are by Solidity.
 *
 * [CAUTION]
 * ====
 * Avoid leaving a contract uninitialized.
 *
 * An uninitialized contract can be taken over by an attacker. This applies to both a proxy and its implementation
 * contract, which may impact the proxy. To prevent the implementation contract from being used, you should invoke
 * the {_disableInitializers} function in the constructor to automatically lock it when it is deployed:
 *
 * [.hljs-theme-light.nopadding]
 * ```
 * /// @custom:oz-upgrades-unsafe-allow constructor
 * constructor() {
 *     _disableInitializers();
 * }
 * ```
 * ====
 */
abstract contract Initializable {
    /**
     * @dev Indicates that the contract has been initialized.
     * @custom:oz-retyped-from bool
     */
    uint8 private _initialized;

    /**
     * @dev Indicates that the contract is in the process of being initialized.
     */
    bool private _initializing;

    /**
     * @dev Triggered when the contract has been initialized or reinitialized.
     */
    event Initialized(uint8 version);

    /**
     * @dev A modifier that defines a protected initializer function that can be invoked at most once. In its scope,
     * `onlyInitializing` functions can be used to initialize parent contracts.
     *
     * Similar to `reinitializer(1)`, except that functions marked with `initializer` can be nested in the context of a
     * constructor.
     *
     * Emits an {Initialized} event.
     */
    modifier initializer() {
        bool isTopLevelCall = !_initializing;
        require(
            (isTopLevelCall && _initialized < 1) || (!AddressUpgradeable.isContract(address(this)) && _initialized == 1),
            "Initializable: contract is already initialized"
        );
        _initialized = 1;
        if (isTopLevelCall) {
            _initializing = true;
        }
        _;
        if (isTopLevelCall) {
            _initializing = false;
            emit Initialized(1);
        }
    }

    /**
     * @dev A modifier that defines a protected reinitializer function that can be invoked at most once, and only if the
     * contract hasn't been initialized to a greater version before. In its scope, `onlyInitializing` functions can be
     * used to initialize parent contracts.
     *
     * A reinitializer may be used after the original initialization step. This is essential to configure modules that
     * are added through upgrades and that require initialization.
     *
     * When `version` is 1, this modifier is similar to `initializer`, except that functions marked with `reinitializer`
     * cannot be nested. If one is invoked in the context of another, execution will revert.
     *
     * Note that versions can jump in increments greater than 1; this implies that if multiple reinitializers coexist in
     * a contract, executing them in the right order is up to the developer or operator.
     *
     * WARNING: setting the version to 255 will prevent any future reinitialization.
     *
     * Emits an {Initialized} event.
     */
    modifier reinitializer(uint8 version) {
        require(!_initializing && _initialized < version, "Initializable: contract is already initialized");
        _initialized = version;
        _initializing = true;
        _;
        _initializing = false;
        emit Initialized(version);
    }

    /**
     * @dev Modifier to protect an initialization function so that it can only be invoked by functions with the
     * {initializer} and {reinitializer} modifiers, directly or indirectly.
     */
    modifier onlyInitializing() {
        require(_initializing, "Initializable: contract is not initializing");
        _;
    }

    /**
     * @dev Locks the contract, preventing any future reinitialization. This cannot be part of an initializer call.
     * Calling this in the constructor of a contract will prevent that contract from being initialized or reinitialized
     * to any version. It is recommended to use this to lock implementation contracts that are designed to be called
     * through proxies.
     *
     * Emits an {Initialized} event the first time it is successfully executed.
     */
    function _disableInitializers() internal virtual {
        require(!_initializing, "Initializable: contract is initializing");
        if (_initialized != type(uint8).max) {
            _initialized = type(uint8).max;
            emit Initialized(type(uint8).max);
        }
    }

    /**
     * @dev Returns the highest version that has been initialized. See {reinitializer}.
     */
    function _getInitializedVersion() internal view returns (uint8) {
        return _initialized;
    }

    /**
     * @dev Returns `true` if the contract is currently initializing. See {onlyInitializing}.
     */
    function _isInitializing() internal view returns (bool) {
        return _initializing;
    }
}


// File: @openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/ERC1155.sol)

pragma solidity ^0.8.0;

import "./IERC1155Upgradeable.sol";
import "./IERC1155ReceiverUpgradeable.sol";
import "./extensions/IERC1155MetadataURIUpgradeable.sol";
import "../../utils/AddressUpgradeable.sol";
import "../../utils/ContextUpgradeable.sol";
import "../../utils/introspection/ERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the basic standard multi-token.
 * See https://eips.ethereum.org/EIPS/eip-1155
 * Originally based on code by Enjin: https://github.com/enjin/erc-1155
 *
 * _Available since v3.1._
 */
contract ERC1155Upgradeable is Initializable, ContextUpgradeable, ERC165Upgradeable, IERC1155Upgradeable, IERC1155MetadataURIUpgradeable {
    using AddressUpgradeable for address;

    // Mapping from token ID to account balances
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Mapping from account to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Used as the URI for all token types by relying on ID substitution, e.g. https://token-cdn-domain/{id}.json
    string private _uri;

    /**
     * @dev See {_setURI}.
     */
    function __ERC1155_init(string memory uri_) internal onlyInitializing {
        __ERC1155_init_unchained(uri_);
    }

    function __ERC1155_init_unchained(string memory uri_) internal onlyInitializing {
        _setURI(uri_);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC165Upgradeable, IERC165Upgradeable) returns (bool) {
        return
            interfaceId == type(IERC1155Upgradeable).interfaceId ||
            interfaceId == type(IERC1155MetadataURIUpgradeable).interfaceId ||
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
            try IERC1155ReceiverUpgradeable(to).onERC1155Received(operator, from, id, amount, data) returns (bytes4 response) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155Received.selector) {
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
            try IERC1155ReceiverUpgradeable(to).onERC1155BatchReceived(operator, from, ids, amounts, data) returns (
                bytes4 response
            ) {
                if (response != IERC1155ReceiverUpgradeable.onERC1155BatchReceived.selector) {
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

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC1155/extensions/ERC1155Supply.sol)

pragma solidity ^0.8.0;

import "../ERC1155Upgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Extension of ERC1155 that adds tracking of total supply per id.
 *
 * Useful for scenarios where Fungible and Non-fungible tokens have to be
 * clearly identified. Note: While a totalSupply of 1 might mean the
 * corresponding is an NFT, there is no guarantees that no other token with the
 * same id are not going to be minted.
 */
abstract contract ERC1155SupplyUpgradeable is Initializable, ERC1155Upgradeable {
    function __ERC1155Supply_init() internal onlyInitializing {
    }

    function __ERC1155Supply_init_unchained() internal onlyInitializing {
    }
    mapping(uint256 => uint256) private _totalSupply;

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view virtual returns (uint256) {
        return _totalSupply[id];
    }

    /**
     * @dev Indicates whether any token exist with a given id, or not.
     */
    function exists(uint256 id) public view virtual returns (bool) {
        return ERC1155SupplyUpgradeable.totalSupply(id) > 0;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
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

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                _totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                uint256 id = ids[i];
                uint256 amount = amounts[i];
                uint256 supply = _totalSupply[id];
                require(supply >= amount, "ERC1155: burn amount exceeds totalSupply");
                unchecked {
                    _totalSupply[id] = supply - amount;
                }
            }
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[49] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC1155/extensions/IERC1155MetadataURI.sol)

pragma solidity ^0.8.0;

import "../IERC1155Upgradeable.sol";

/**
 * @dev Interface of the optional ERC1155MetadataExtension interface, as defined
 * in the https://eips.ethereum.org/EIPS/eip-1155#metadata-extensions[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155MetadataURIUpgradeable is IERC1155Upgradeable {
    /**
     * @dev Returns the URI for token type `id`.
     *
     * If the `\{id\}` substring is present in the URI, it must be replaced by
     * clients with the actual token type ID.
     */
    function uri(uint256 id) external view returns (string memory);
}


// File: @openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.5.0) (token/ERC1155/IERC1155Receiver.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev _Available since v3.1._
 */
interface IERC1155ReceiverUpgradeable is IERC165Upgradeable {
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


// File: @openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC1155/IERC1155.sol)

pragma solidity ^0.8.0;

import "../../utils/introspection/IERC165Upgradeable.sol";

/**
 * @dev Required interface of an ERC1155 compliant contract, as defined in the
 * https://eips.ethereum.org/EIPS/eip-1155[EIP].
 *
 * _Available since v3.1._
 */
interface IERC1155Upgradeable is IERC165Upgradeable {
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


// File: @openzeppelin/contracts-upgradeable/token/ERC721/IERC721ReceiverUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.6.0) (token/ERC721/IERC721Receiver.sol)

pragma solidity ^0.8.0;

/**
 * @title ERC721 token receiver interface
 * @dev Interface for any contract that wants to support safeTransfers
 * from ERC721 asset contracts.
 */
interface IERC721ReceiverUpgradeable {
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


// File: @openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC721/utils/ERC721Holder.sol)

pragma solidity ^0.8.0;

import "../IERC721ReceiverUpgradeable.sol";
import "../../../proxy/utils/Initializable.sol";

/**
 * @dev Implementation of the {IERC721Receiver} interface.
 *
 * Accepts all token transfers.
 * Make sure the contract is able to use its token with {IERC721-safeTransferFrom}, {IERC721-approve} or {IERC721-setApprovalForAll}.
 */
contract ERC721HolderUpgradeable is Initializable, IERC721ReceiverUpgradeable {
    function __ERC721Holder_init() internal onlyInitializing {
    }

    function __ERC721Holder_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC721Receiver-onERC721Received}.
     *
     * Always returns `IERC721Receiver.onERC721Received.selector`.
     */
    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Address.sol)

pragma solidity ^0.8.1;

/**
 * @dev Collection of functions related to the address type
 */
library AddressUpgradeable {
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


// File: @openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/Context.sol)

pragma solidity ^0.8.0;
import "../proxy/utils/Initializable.sol";

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
abstract contract ContextUpgradeable is Initializable {
    function __Context_init() internal onlyInitializing {
    }

    function __Context_init_unchained() internal onlyInitializing {
    }
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (utils/introspection/ERC165.sol)

pragma solidity ^0.8.0;

import "./IERC165Upgradeable.sol";
import "../../proxy/utils/Initializable.sol";

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
abstract contract ERC165Upgradeable is Initializable, IERC165Upgradeable {
    function __ERC165_init() internal onlyInitializing {
    }

    function __ERC165_init_unchained() internal onlyInitializing {
    }
    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC165Upgradeable).interfaceId;
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[50] private __gap;
}


// File: @openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol
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
interface IERC165Upgradeable {
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


// File: @openzeppelin/contracts/token/ERC20/ERC20.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/ERC20.sol)

pragma solidity ^0.8.0;

import "./IERC20.sol";
import "./extensions/IERC20Metadata.sol";
import "../../utils/Context.sol";

/**
 * @dev Implementation of the {IERC20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {ERC20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.openzeppelin.com/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * The default value of {decimals} is 18. To change this, you should override
 * this function so it returns a different value.
 *
 * We have followed general OpenZeppelin Contracts guidelines: functions revert
 * instead returning `false` on failure. This behavior is nonetheless
 * conventional and does not conflict with the expectations of ERC20
 * applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IERC20-approve}.
 */
contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    /**
     * @dev Sets the values for {name} and {symbol}.
     *
     * All two of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5.05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the default value returned by this function, unless
     * it's overridden.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address to, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * NOTE: If `amount` is the maximum `uint256`, the allowance is not updated on
     * `transferFrom`. This is semantically equivalent to an infinite approval.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * NOTE: Does not update the allowance if the current allowance
     * is the maximum `uint256`.
     *
     * Requirements:
     *
     * - `from` and `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     * - the caller must have allowance for ``from``'s tokens of at least
     * `amount`.
     */
    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    /**
     * @dev Moves `amount` of tokens from `from` to `to`.
     *
     * This internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `from` cannot be the zero address.
     * - `to` cannot be the zero address.
     * - `from` must have a balance of at least `amount`.
     */
    function _transfer(address from, address to, uint256 amount) internal virtual {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(from, to, amount);

        uint256 fromBalance = _balances[from];
        require(fromBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = fromBalance - amount;
            // Overflow not possible: the sum of all balances is capped by totalSupply, and the sum is preserved by
            // decrementing then incrementing.
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        _afterTokenTransfer(from, to, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
            // Overflow not possible: amount <= accountBalance <= totalSupply.
            _totalSupply -= amount;
        }

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Updates `owner` s allowance for `spender` based on spent `amount`.
     *
     * Does not update the allowance amount in case of infinite allowance.
     * Revert if not enough allowance is available.
     *
     * Might emit an {Approval} event.
     */
    function _spendAllowance(address owner, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual {}

    /**
     * @dev Hook that is called after any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * has been transferred to `to`.
     * - when `from` is zero, `amount` tokens have been minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens have been burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _afterTokenTransfer(address from, address to, uint256 amount) internal virtual {}
}


// File: @openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)

pragma solidity ^0.8.0;

import "../IERC20.sol";

/**
 * @dev Interface for the optional metadata functions from the ERC20 standard.
 *
 * _Available since v4.1._
 */
interface IERC20Metadata is IERC20 {
    /**
     * @dev Returns the name of the token.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the symbol of the token.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the decimals places of the token.
     */
    function decimals() external view returns (uint8);
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
// OpenZeppelin Contracts (last updated v4.9.0) (token/ERC20/utils/SafeERC20.sol)

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
     * non-reverting calls are assumed to be successful. Compatible with tokens that require the approval to be set to
     * 0 before setting it to a non-zero value.
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


// File: @openzeppelin/contracts/utils/cryptography/MerkleProof.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.2) (utils/cryptography/MerkleProof.sol)

pragma solidity ^0.8.0;

/**
 * @dev These functions deal with verification of Merkle Tree proofs.
 *
 * The tree and the proofs can be generated using our
 * https://github.com/OpenZeppelin/merkle-tree[JavaScript library].
 * You will find a quickstart guide in the readme.
 *
 * WARNING: You should avoid using leaf values that are 64 bytes long prior to
 * hashing, or use a hash function other than keccak256 for hashing leaves.
 * This is because the concatenation of a sorted pair of internal nodes in
 * the merkle tree could be reinterpreted as a leaf value.
 * OpenZeppelin's JavaScript library generates merkle trees that are safe
 * against this attack out of the box.
 */
library MerkleProof {
    /**
     * @dev Returns true if a `leaf` can be proved to be a part of a Merkle tree
     * defined by `root`. For this, a `proof` must be provided, containing
     * sibling hashes on the branch from the leaf to the root of the tree. Each
     * pair of leaves and each pair of pre-images are assumed to be sorted.
     */
    function verify(bytes32[] memory proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProof(proof, leaf) == root;
    }

    /**
     * @dev Calldata version of {verify}
     *
     * _Available since v4.7._
     */
    function verifyCalldata(bytes32[] calldata proof, bytes32 root, bytes32 leaf) internal pure returns (bool) {
        return processProofCalldata(proof, leaf) == root;
    }

    /**
     * @dev Returns the rebuilt hash obtained by traversing a Merkle tree up
     * from `leaf` using `proof`. A `proof` is valid if and only if the rebuilt
     * hash matches the root of the tree. When processing the proof, the pairs
     * of leafs & pre-images are assumed to be sorted.
     *
     * _Available since v4.4._
     */
    function processProof(bytes32[] memory proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Calldata version of {processProof}
     *
     * _Available since v4.7._
     */
    function processProofCalldata(bytes32[] calldata proof, bytes32 leaf) internal pure returns (bytes32) {
        bytes32 computedHash = leaf;
        for (uint256 i = 0; i < proof.length; i++) {
            computedHash = _hashPair(computedHash, proof[i]);
        }
        return computedHash;
    }

    /**
     * @dev Returns true if the `leaves` can be simultaneously proven to be a part of a merkle tree defined by
     * `root`, according to `proof` and `proofFlags` as described in {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerify(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProof(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Calldata version of {multiProofVerify}
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function multiProofVerifyCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32 root,
        bytes32[] memory leaves
    ) internal pure returns (bool) {
        return processMultiProofCalldata(proof, proofFlags, leaves) == root;
    }

    /**
     * @dev Returns the root of a tree reconstructed from `leaves` and sibling nodes in `proof`. The reconstruction
     * proceeds by incrementally reconstructing all inner nodes by combining a leaf/inner node with either another
     * leaf/inner node or a proof sibling node, depending on whether each `proofFlags` item is true or false
     * respectively.
     *
     * CAUTION: Not all merkle trees admit multiproofs. To use multiproofs, it is sufficient to ensure that: 1) the tree
     * is complete (but not necessarily perfect), 2) the leaves to be proven are in the opposite order they are in the
     * tree (i.e., as seen from right to left starting at the deepest layer and continuing at the next layer).
     *
     * _Available since v4.7._
     */
    function processMultiProof(
        bytes32[] memory proof,
        bool[] memory proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proofLen - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            require(proofPos == proofLen, "MerkleProof: invalid multiproof");
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    /**
     * @dev Calldata version of {processMultiProof}.
     *
     * CAUTION: Not all merkle trees admit multiproofs. See {processMultiProof} for details.
     *
     * _Available since v4.7._
     */
    function processMultiProofCalldata(
        bytes32[] calldata proof,
        bool[] calldata proofFlags,
        bytes32[] memory leaves
    ) internal pure returns (bytes32 merkleRoot) {
        // This function rebuilds the root hash by traversing the tree up from the leaves. The root is rebuilt by
        // consuming and producing values on a queue. The queue starts with the `leaves` array, then goes onto the
        // `hashes` array. At the end of the process, the last hash in the `hashes` array should contain the root of
        // the merkle tree.
        uint256 leavesLen = leaves.length;
        uint256 proofLen = proof.length;
        uint256 totalHashes = proofFlags.length;

        // Check proof validity.
        require(leavesLen + proofLen - 1 == totalHashes, "MerkleProof: invalid multiproof");

        // The xxxPos values are "pointers" to the next value to consume in each array. All accesses are done using
        // `xxx[xxxPos++]`, which return the current value and increment the pointer, thus mimicking a queue's "pop".
        bytes32[] memory hashes = new bytes32[](totalHashes);
        uint256 leafPos = 0;
        uint256 hashPos = 0;
        uint256 proofPos = 0;
        // At each step, we compute the next hash using two values:
        // - a value from the "main queue". If not all leaves have been consumed, we get the next leaf, otherwise we
        //   get the next hash.
        // - depending on the flag, either another value from the "main queue" (merging branches) or an element from the
        //   `proof` array.
        for (uint256 i = 0; i < totalHashes; i++) {
            bytes32 a = leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++];
            bytes32 b = proofFlags[i]
                ? (leafPos < leavesLen ? leaves[leafPos++] : hashes[hashPos++])
                : proof[proofPos++];
            hashes[i] = _hashPair(a, b);
        }

        if (totalHashes > 0) {
            require(proofPos == proofLen, "MerkleProof: invalid multiproof");
            unchecked {
                return hashes[totalHashes - 1];
            }
        } else if (leavesLen > 0) {
            return leaves[0];
        } else {
            return proof[0];
        }
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
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


// File: @openzeppelin/contracts/utils/Multicall.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/Multicall.sol)

pragma solidity ^0.8.0;

import "./Address.sol";

/**
 * @dev Provides a function to batch together multiple calls in a single external call.
 *
 * _Available since v4.1._
 */
abstract contract Multicall {
    /**
     * @dev Receives and executes a batch of function calls on this contract.
     * @custom:oz-upgrades-unsafe-allow-reachable delegatecall
     */
    function multicall(bytes[] calldata data) external virtual returns (bytes[] memory results) {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            results[i] = Address.functionDelegateCall(address(this), data[i]);
        }
        return results;
    }
}


// File: @openzeppelin/contracts/utils/structs/EnumerableMap.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.9.0) (utils/structs/EnumerableMap.sol)
// This file was procedurally generated from scripts/generate/templates/EnumerableMap.js.

pragma solidity ^0.8.0;

import "./EnumerableSet.sol";

/**
 * @dev Library for managing an enumerable variant of Solidity's
 * https://solidity.readthedocs.io/en/latest/types.html#mapping-types[`mapping`]
 * type.
 *
 * Maps have the following properties:
 *
 * - Entries are added, removed, and checked for existence in constant time
 * (O(1)).
 * - Entries are enumerated in O(n). No guarantees are made on the ordering.
 *
 * ```solidity
 * contract Example {
 *     // Add the library methods
 *     using EnumerableMap for EnumerableMap.UintToAddressMap;
 *
 *     // Declare a set state variable
 *     EnumerableMap.UintToAddressMap private myMap;
 * }
 * ```
 *
 * The following map types are supported:
 *
 * - `uint256 -> address` (`UintToAddressMap`) since v3.0.0
 * - `address -> uint256` (`AddressToUintMap`) since v4.6.0
 * - `bytes32 -> bytes32` (`Bytes32ToBytes32Map`) since v4.6.0
 * - `uint256 -> uint256` (`UintToUintMap`) since v4.7.0
 * - `bytes32 -> uint256` (`Bytes32ToUintMap`) since v4.7.0
 *
 * [WARNING]
 * ====
 * Trying to delete such a structure from storage will likely result in data corruption, rendering the structure
 * unusable.
 * See https://github.com/ethereum/solidity/pull/11843[ethereum/solidity#11843] for more info.
 *
 * In order to clean an EnumerableMap, you can either remove all elements one by one or create a fresh instance using an
 * array of EnumerableMap.
 * ====
 */
library EnumerableMap {
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // To implement this library for multiple types with as little code
    // repetition as possible, we write it in terms of a generic Map type with
    // bytes32 keys and values.
    // The Map implementation uses private functions, and user-facing
    // implementations (such as Uint256ToAddressMap) are just wrappers around
    // the underlying Map.
    // This means that we can only create new EnumerableMaps for types that fit
    // in bytes32.

    struct Bytes32ToBytes32Map {
        // Storage of keys
        EnumerableSet.Bytes32Set _keys;
        mapping(bytes32 => bytes32) _values;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(Bytes32ToBytes32Map storage map, bytes32 key, bytes32 value) internal returns (bool) {
        map._values[key] = value;
        return map._keys.add(key);
    }

    /**
     * @dev Removes a key-value pair from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToBytes32Map storage map, bytes32 key) internal returns (bool) {
        delete map._values[key];
        return map._keys.remove(key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool) {
        return map._keys.contains(key);
    }

    /**
     * @dev Returns the number of key-value pairs in the map. O(1).
     */
    function length(Bytes32ToBytes32Map storage map) internal view returns (uint256) {
        return map._keys.length();
    }

    /**
     * @dev Returns the key-value pair stored at position `index` in the map. O(1).
     *
     * Note that there are no guarantees on the ordering of entries inside the
     * array, and it may change when more entries are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToBytes32Map storage map, uint256 index) internal view returns (bytes32, bytes32) {
        bytes32 key = map._keys.at(index);
        return (key, map._values[key]);
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bool, bytes32) {
        bytes32 value = map._values[key];
        if (value == bytes32(0)) {
            return (contains(map, key), bytes32(0));
        } else {
            return (true, value);
        }
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToBytes32Map storage map, bytes32 key) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), "EnumerableMap: nonexistent key");
        return value;
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToBytes32Map storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (bytes32) {
        bytes32 value = map._values[key];
        require(value != 0 || contains(map, key), errorMessage);
        return value;
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(Bytes32ToBytes32Map storage map) internal view returns (bytes32[] memory) {
        return map._keys.values();
    }

    // UintToUintMap

    struct UintToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToUintMap storage map, uint256 key, uint256 value) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToUintMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToUintMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToUintMap storage map, uint256 index) internal view returns (uint256, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToUintMap storage map, uint256 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToUintMap storage map, uint256 key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key)));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(UintToUintMap storage map, uint256 key, string memory errorMessage) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(key), errorMessage));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(UintToUintMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = keys(map._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // UintToAddressMap

    struct UintToAddressMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(UintToAddressMap storage map, uint256 key, address value) internal returns (bool) {
        return set(map._inner, bytes32(key), bytes32(uint256(uint160(value))));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(UintToAddressMap storage map, uint256 key) internal returns (bool) {
        return remove(map._inner, bytes32(key));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(UintToAddressMap storage map, uint256 key) internal view returns (bool) {
        return contains(map._inner, bytes32(key));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(UintToAddressMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(UintToAddressMap storage map, uint256 index) internal view returns (uint256, address) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (uint256(key), address(uint160(uint256(value))));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(UintToAddressMap storage map, uint256 key) internal view returns (bool, address) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(key));
        return (success, address(uint160(uint256(value))));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(UintToAddressMap storage map, uint256 key) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        UintToAddressMap storage map,
        uint256 key,
        string memory errorMessage
    ) internal view returns (address) {
        return address(uint160(uint256(get(map._inner, bytes32(key), errorMessage))));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(UintToAddressMap storage map) internal view returns (uint256[] memory) {
        bytes32[] memory store = keys(map._inner);
        uint256[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // AddressToUintMap

    struct AddressToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(AddressToUintMap storage map, address key, uint256 value) internal returns (bool) {
        return set(map._inner, bytes32(uint256(uint160(key))), bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(AddressToUintMap storage map, address key) internal returns (bool) {
        return remove(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(AddressToUintMap storage map, address key) internal view returns (bool) {
        return contains(map._inner, bytes32(uint256(uint160(key))));
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(AddressToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(AddressToUintMap storage map, uint256 index) internal view returns (address, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (address(uint160(uint256(key))), uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(AddressToUintMap storage map, address key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, bytes32(uint256(uint160(key))));
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(AddressToUintMap storage map, address key) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key)))));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        AddressToUintMap storage map,
        address key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, bytes32(uint256(uint160(key))), errorMessage));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(AddressToUintMap storage map) internal view returns (address[] memory) {
        bytes32[] memory store = keys(map._inner);
        address[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
    }

    // Bytes32ToUintMap

    struct Bytes32ToUintMap {
        Bytes32ToBytes32Map _inner;
    }

    /**
     * @dev Adds a key-value pair to a map, or updates the value for an existing
     * key. O(1).
     *
     * Returns true if the key was added to the map, that is if it was not
     * already present.
     */
    function set(Bytes32ToUintMap storage map, bytes32 key, uint256 value) internal returns (bool) {
        return set(map._inner, key, bytes32(value));
    }

    /**
     * @dev Removes a value from a map. O(1).
     *
     * Returns true if the key was removed from the map, that is if it was present.
     */
    function remove(Bytes32ToUintMap storage map, bytes32 key) internal returns (bool) {
        return remove(map._inner, key);
    }

    /**
     * @dev Returns true if the key is in the map. O(1).
     */
    function contains(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool) {
        return contains(map._inner, key);
    }

    /**
     * @dev Returns the number of elements in the map. O(1).
     */
    function length(Bytes32ToUintMap storage map) internal view returns (uint256) {
        return length(map._inner);
    }

    /**
     * @dev Returns the element stored at position `index` in the map. O(1).
     * Note that there are no guarantees on the ordering of values inside the
     * array, and it may change when more values are added or removed.
     *
     * Requirements:
     *
     * - `index` must be strictly less than {length}.
     */
    function at(Bytes32ToUintMap storage map, uint256 index) internal view returns (bytes32, uint256) {
        (bytes32 key, bytes32 value) = at(map._inner, index);
        return (key, uint256(value));
    }

    /**
     * @dev Tries to returns the value associated with `key`. O(1).
     * Does not revert if `key` is not in the map.
     */
    function tryGet(Bytes32ToUintMap storage map, bytes32 key) internal view returns (bool, uint256) {
        (bool success, bytes32 value) = tryGet(map._inner, key);
        return (success, uint256(value));
    }

    /**
     * @dev Returns the value associated with `key`. O(1).
     *
     * Requirements:
     *
     * - `key` must be in the map.
     */
    function get(Bytes32ToUintMap storage map, bytes32 key) internal view returns (uint256) {
        return uint256(get(map._inner, key));
    }

    /**
     * @dev Same as {get}, with a custom error message when `key` is not in the map.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryGet}.
     */
    function get(
        Bytes32ToUintMap storage map,
        bytes32 key,
        string memory errorMessage
    ) internal view returns (uint256) {
        return uint256(get(map._inner, key, errorMessage));
    }

    /**
     * @dev Return the an array containing all the keys
     *
     * WARNING: This operation will copy the entire storage to memory, which can be quite expensive. This is designed
     * to mostly be used by view accessors that are queried without any gas fees. Developers should keep in mind that
     * this function has an unbounded cost, and using it as part of a state-changing function may render the function
     * uncallable if the map grows to a point where copying to memory consumes too much gas to fit in a block.
     */
    function keys(Bytes32ToUintMap storage map) internal view returns (bytes32[] memory) {
        bytes32[] memory store = keys(map._inner);
        bytes32[] memory result;

        /// @solidity memory-safe-assembly
        assembly {
            result := store
        }

        return result;
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


// File: @solarity/solidity-lib/access-control/MultiOwnable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {SetHelper} from "../libs/arrays/SetHelper.sol";
import {TypeCaster} from "../libs/utils/TypeCaster.sol";
import {IMultiOwnable} from "../interfaces/access-control/IMultiOwnable.sol";

/**
 * @notice The MultiOwnable module
 *
 * Contract module which provides a basic access control mechanism, where there is a list of
 * owner addresses those can be granted exclusive access to specific functions.
 * All owners are equal in their access, they can add new owners, also remove each other and themself.
 *
 * By default, the owner account will be the one that deploys the contract.
 *
 * This module will make available the modifier `onlyOwner`, which can be applied
 * to your functions to restrict their use to the owners.
 */
abstract contract MultiOwnable is IMultiOwnable, Initializable {
    using EnumerableSet for EnumerableSet.AddressSet;
    using TypeCaster for address;
    using SetHelper for EnumerableSet.AddressSet;

    EnumerableSet.AddressSet private _owners;

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Initializes the contract setting the msg.sender as the initial owner.
     */
    function __MultiOwnable_init() internal onlyInitializing {
        _addOwners(msg.sender.asSingletonArray());
    }

    function addOwners(address[] memory newOwners_) public override onlyOwner {
        _addOwners(newOwners_);
    }

    function removeOwners(address[] memory oldOwners_) public override onlyOwner {
        _removeOwners(oldOwners_);
    }

    function renounceOwnership() public override onlyOwner {
        _removeOwners(msg.sender.asSingletonArray());
    }

    function getOwners() public view override returns (address[] memory) {
        return _owners.values();
    }

    function isOwner(address address_) public view override returns (bool) {
        return _owners.contains(address_);
    }

    /**
     * @notice Gives ownership of the contract to array of new owners.
     * Null address will not be added and function will be reverted.
     * @dev Internal function without access restriction.
     * @param newOwners_ the array of addresses to add to _owners
     */
    function _addOwners(address[] memory newOwners_) private {
        _owners.add(newOwners_);

        require(!_owners.contains(address(0)), "MultiOwnable: zero address can not be added");

        emit OwnersAdded(newOwners_);
    }

    /**
     * @notice Removes ownership of the contract for every address in array.
     *
     * Note: removing ownership may leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     *
     * @dev Internal function without access restriction.
     * @param oldOwners_ the array of addresses to remove from _owners
     */
    function _removeOwners(address[] memory oldOwners_) private {
        _owners.remove(oldOwners_);

        emit OwnersRemoved(oldOwners_);
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() private view {
        require(isOwner(msg.sender), "MultiOwnable: caller is not the owner");
    }
}


// File: @solarity/solidity-lib/contracts-registry/AbstractDependant.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @notice The ContractsRegistry module
 *
 * This is a contract that must be used as dependencies accepter in the dependency injection mechanism.
 * Upon the injection, the Injector (ContractsRegistry most of the time) will call the `setDependencies()` function.
 * The dependant contract will have to pull the required addresses from the supplied ContractsRegistry as a parameter.
 *
 * The AbstractDependant is fully compatible with proxies courtesy of custom storage slot.
 */
abstract contract AbstractDependant {
    /**
     * @notice The slot where the dependency injector is located.
     * @dev bytes32(uint256(keccak256("eip6224.dependant.slot")) - 1)
     *
     * Only the injector is allowed to inject dependencies.
     * The first to call the setDependencies() (with the modifier applied) function becomes an injector
     */
    bytes32 private constant _INJECTOR_SLOT =
        0x3d1f25f1ac447e55e7fec744471c4dab1c6a2b6ffb897825f9ea3d2e8c9be583;

    modifier dependant() {
        _checkInjector();
        _;
        _setInjector(msg.sender);
    }

    /**
     * @notice The function that will be called from the ContractsRegistry (or factory) to inject dependencies.
     * The Dependant must apply dependant() modifier to this function
     * @param contractsRegistry_ the registry to pull dependencies from
     * @param data_ the extra data that might provide additional context
     */
    function setDependencies(address contractsRegistry_, bytes memory data_) public virtual;

    /**
     * @notice The function is made external to allow for the factories to set the injector to the ContractsRegistry
     * @param injector_ the new injector
     */
    function setInjector(address injector_) external {
        _checkInjector();
        _setInjector(injector_);
    }

    /**
     * @notice The function to get the current injector
     * @return injector_ the current injector
     */
    function getInjector() public view returns (address injector_) {
        bytes32 slot_ = _INJECTOR_SLOT;

        assembly {
            injector_ := sload(slot_)
        }
    }

    /**
     * @notice Internal function that sets the injector
     */
    function _setInjector(address injector_) internal {
        bytes32 slot_ = _INJECTOR_SLOT;

        assembly {
            sstore(slot_, injector_)
        }
    }

    /**
     * @notice Internal function that checks the injector credentials
     */
    function _checkInjector() internal view {
        address injector_ = getInjector();

        require(injector_ == address(0) || injector_ == msg.sender, "Dependant: not an injector");
    }
}


// File: @solarity/solidity-lib/interfaces/access-control/IMultiOwnable.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @notice The MultiOwnable module
 */
interface IMultiOwnable {
    event OwnersAdded(address[] newOwners);
    event OwnersRemoved(address[] removedOwners);

    /**
     * @notice Owner can add new owners to the contract's owners list.
     * @param newOwners_ the array of addresses to add to _owners.
     */
    function addOwners(address[] calldata newOwners_) external;

    /**
     * @notice Owner can remove the array of owners from the contract's owners list.
     * @param oldOwners_ the array of addresses to remove from _owners
     */
    function removeOwners(address[] calldata oldOwners_) external;

    /**
     * @notice Allows to remove yourself from list of owners.
     
     * Note: renouncing ownership may leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() external;

    /**
     * @notice Returns the addresses of the current owners.
     * @dev Returns a copy of the whole Set of owners.
     * @return the array of addresses.
     */
    function getOwners() external view returns (address[] memory);

    /**
     * @notice Returns true if address is in the contract's owners list.
     * @param address_ the address to check.
     * @return whether the _address in _owners.
     */
    function isOwner(address address_) external view returns (bool);
}


// File: @solarity/solidity-lib/libs/arrays/SetHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {StringSet} from "../data-structures/StringSet.sol";

/**
 * @notice A simple library to work with sets
 */
library SetHelper {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using StringSet for StringSet.Set;

    /**
     * @notice The function to insert an array of elements into the set
     * @param set the set to insert the elements into
     * @param array_ the elements to be inserted
     */
    function add(EnumerableSet.AddressSet storage set, address[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.add(array_[i]);
        }
    }

    function add(EnumerableSet.UintSet storage set, uint256[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.add(array_[i]);
        }
    }

    function add(StringSet.Set storage set, string[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.add(array_[i]);
        }
    }

    /**
     * @notice The function to remove an array of elements from the set
     * @param set the set to remove the elements from
     * @param array_ the elements to be removed
     */
    function remove(EnumerableSet.AddressSet storage set, address[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.remove(array_[i]);
        }
    }

    function remove(EnumerableSet.UintSet storage set, uint256[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.remove(array_[i]);
        }
    }

    function remove(StringSet.Set storage set, string[] memory array_) internal {
        for (uint256 i = 0; i < array_.length; i++) {
            set.remove(array_[i]);
        }
    }
}


// File: @solarity/solidity-lib/libs/data-structures/StringSet.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @notice ## Usage example:
 *
 * ```
 * using StringSet for StringSet.Set;
 *
 * StringSet.Set internal set;
 * ```
 */
library StringSet {
    struct Set {
        string[] _values;
        mapping(string => uint256) _indexes;
    }

    /**
     * @notice The function add value to set
     * @param set the set object
     * @param value_ the value to add
     */
    function add(Set storage set, string memory value_) internal returns (bool) {
        if (!contains(set, value_)) {
            set._values.push(value_);
            set._indexes[value_] = set._values.length;

            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice The function remove value to set
     * @param set the set object
     * @param value_ the value to remove
     */
    function remove(Set storage set, string memory value_) internal returns (bool) {
        uint256 valueIndex_ = set._indexes[value_];

        if (valueIndex_ != 0) {
            uint256 toDeleteIndex_ = valueIndex_ - 1;
            uint256 lastIndex_ = set._values.length - 1;

            if (lastIndex_ != toDeleteIndex_) {
                string memory lastValue_ = set._values[lastIndex_];

                set._values[toDeleteIndex_] = lastValue_;
                set._indexes[lastValue_] = valueIndex_;
            }

            set._values.pop();

            delete set._indexes[value_];

            return true;
        } else {
            return false;
        }
    }

    /**
     * @notice The function returns true if value in the set
     * @param set the set object
     * @param value_ the value to search in set
     * @return true if value is in the set, false otherwise
     */
    function contains(Set storage set, string memory value_) internal view returns (bool) {
        return set._indexes[value_] != 0;
    }

    /**
     * @notice The function returns length of set
     * @param set the set object
     * @return the the number of elements in the set
     */
    function length(Set storage set) internal view returns (uint256) {
        return set._values.length;
    }

    /**
     * @notice The function returns value from set by index
     * @param set the set object
     * @param index_ the index of slot in set
     * @return the value at index
     */
    function at(Set storage set, uint256 index_) internal view returns (string memory) {
        return set._values[index_];
    }

    /**
     * @notice The function that returns values the set stores, can be very expensive to call
     * @param set the set object
     * @return the memory array of values
     */
    function values(Set storage set) internal view returns (string[] memory) {
        return set._values;
    }
}


// File: @solarity/solidity-lib/libs/utils/DecimalsConverter.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20, IERC20, IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @notice This library is used to convert numbers that use token's N decimals to M decimals.
 * Comes extremely handy with standardizing the business logic that is intended to work with many different ERC20 tokens
 * that have different precision (decimals). One can perform calculations with 18 decimals only and resort to convertion
 * only when the payouts (or interactions) with the actual tokes have to be made.
 *
 * The best usage scenario involves accepting and calculating values with 18 decimals throughout the project, despite the tokens decimals.
 *
 * Also it is recommended to call `round18()` function on the first execution line in order to get rid of the
 * trailing numbers if the destination decimals are less than 18
 *
 * ## Usage example:
 *
 * ```
 * contract Taker {
 *     ERC20 public USDC;
 *     uint256 public paid;
 *
 *     . . .
 *
 *     function pay(uint256 amount) external {
 *         amount = amount.round18(address(USDC));
 *
 *         paid += amount;
 *         USDC.transferFrom(msg.sender, address(this), amount.from18(address(USDC)));
 *     }
 * }
 * ```
 */
library DecimalsConverter {
    /**
     * @notice The function to get the decimals of ERC20 token. Needed for bytecode optimization
     * @param token_ the ERC20 token
     * @return the decimals of provided token
     */
    function decimals(address token_) internal view returns (uint8) {
        return ERC20(token_).decimals();
    }

    /**
     * @notice The function to bring the number to 18 decimals of precision
     * @param amount_ the number to convert
     * @param token_ the token, whose decimals will be precised to 18
     * @return the number brought to 18 decimals of precision
     */
    function to18(uint256 amount_, address token_) internal view returns (uint256) {
        return to18(amount_, decimals(token_));
    }

    /**
     * @notice The function to bring the number to 18 decimals of precision
     * @param amount_ the number to convert
     * @param baseDecimals_ the current precision of the number
     * @return the number brought to 18 decimals of precision
     */
    function to18(uint256 amount_, uint256 baseDecimals_) internal pure returns (uint256) {
        return _to18(amount_, baseDecimals_);
    }

    /**
     * @notice The function to bring the number to 18 decimals of precision. Reverts if output is zero
     * @param amount_ the number to convert
     * @param token_ the token, whose decimals will be precised to 18
     * @return the number brought to 18 decimals of precision
     */
    function to18Safe(uint256 amount_, address token_) internal view returns (uint256) {
        return to18Safe(amount_, decimals(token_));
    }

    /**
     * @notice The function to bring the number to 18 decimals of precision. Reverts if output is zero
     * @param amount_ the number to convert
     * @param baseDecimals_ the current precision of the number
     * @return the number brought to 18 decimals of precision
     */
    function to18Safe(uint256 amount_, uint256 baseDecimals_) internal pure returns (uint256) {
        return _safe(_to18(amount_, baseDecimals_));
    }

    /**
     * @notice The function to bring the number from 18 decimals to the desired decimals of precision
     * @param amount_ the number to covert
     * @param token_ the token, whose decimals will be used as desired decimals of precision
     * @return the number brought from 18 to desired decimals of precision
     */
    function from18(uint256 amount_, address token_) internal view returns (uint256) {
        return from18(amount_, decimals(token_));
    }

    /**
     * @notice The function to bring the number from 18 decimals to the desired decimals of precision
     * @param amount_ the number to covert
     * @param destDecimals_ the desired precision decimals
     * @return the number brought from 18 to desired decimals of precision
     */
    function from18(uint256 amount_, uint256 destDecimals_) internal pure returns (uint256) {
        return _from18(amount_, destDecimals_);
    }

    /**
     * @notice The function to bring the number from 18 decimals to the desired decimals of precision.
     * Reverts if output is zero
     * @param amount_ the number to covert
     * @param token_ the token, whose decimals will be used as desired decimals of precision
     * @return the number brought from 18 to desired decimals of precision
     */
    function from18Safe(uint256 amount_, address token_) internal view returns (uint256) {
        return from18Safe(amount_, decimals(token_));
    }

    /**
     * @notice The function to bring the number from 18 decimals to the desired decimals of precision.
     * Reverts if output is zero
     * @param amount_ the number to covert
     * @param destDecimals_ the desired precision decimals
     * @return the number brought from 18 to desired decimals of precision
     */
    function from18Safe(uint256 amount_, uint256 destDecimals_) internal pure returns (uint256) {
        return _safe(_from18(amount_, destDecimals_));
    }

    /**
     * @notice The function to substitute the trailing digits of a number with zeros
     * @param amount_ the number to round. Should be with 18 precision decimals
     * @param token_ the token, whose decimals will be used as desired decimals of precision
     * @return the rounded number. Comes with 18 precision decimals
     */
    function round18(uint256 amount_, address token_) internal view returns (uint256) {
        return round18(amount_, decimals(token_));
    }

    /**
     * @notice The function to substitute the trailing digits of a number with zeros
     * @param amount_ the number to round. Should be with 18 precision decimals
     * @param decimals_ the required number precision
     * @return the rounded number. Comes with 18 precision decimals
     */
    function round18(uint256 amount_, uint256 decimals_) internal pure returns (uint256) {
        return to18(from18(amount_, decimals_), decimals_);
    }

    /**
     * @notice The function to substitute the trailing digits of a number with zeros. Reverts if output is zero
     * @param amount_ the number to round. Should be with 18 precision decimals
     * @param token_ the token, whose decimals will be used as desired decimals of precision
     * @return the rounded number. Comes with 18 precision decimals
     */
    function round18Safe(uint256 amount_, address token_) internal view returns (uint256) {
        return round18Safe(amount_, decimals(token_));
    }

    /**
     * @notice The function to substitute the trailing digits of a number with zeros. Reverts if output is zero
     * @param amount_ the number to round. Should be with 18 precision decimals
     * @param decimals_ the required number precision
     * @return the rounded number. Comes with 18 precision decimals
     */
    function round18Safe(uint256 amount_, uint256 decimals_) internal pure returns (uint256) {
        return _safe(_round18(amount_, decimals_));
    }

    /**
     * @notice The function to do the token precision convertion
     * @param amount_ the amount to convert
     * @param baseToken_ current token
     * @param destToken_ desired token
     * @return the converted number
     */
    function convert(
        uint256 amount_,
        address baseToken_,
        address destToken_
    ) internal view returns (uint256) {
        return convert(amount_, uint256(decimals(baseToken_)), uint256(decimals(destToken_)));
    }

    /**
     * @notice The function to do the precision convertion
     * @param amount_ the amount to covert
     * @param baseDecimals_ current number precision
     * @param destDecimals_ desired number precision
     * @return the converted number
     */
    function convert(
        uint256 amount_,
        uint256 baseDecimals_,
        uint256 destDecimals_
    ) internal pure returns (uint256) {
        if (baseDecimals_ > destDecimals_) {
            amount_ = amount_ / 10 ** (baseDecimals_ - destDecimals_);
        } else if (baseDecimals_ < destDecimals_) {
            amount_ = amount_ * 10 ** (destDecimals_ - baseDecimals_);
        }

        return amount_;
    }

    /**
     * @notice The function to bring the number to 18 decimals of precision
     * @param amount_ the number to convert
     * @param baseDecimals_ the current precision of the number
     * @return the number brought to 18 decimals of precision
     */
    function _to18(uint256 amount_, uint256 baseDecimals_) private pure returns (uint256) {
        return convert(amount_, baseDecimals_, 18);
    }

    /**
     * @notice The function to bring the number from 18 decimals to the desired decimals of precision
     * @param amount_ the number to covert
     * @param destDecimals_ the desired precision decimals
     * @return the number brought from 18 to desired decimals of precision
     */
    function _from18(uint256 amount_, uint256 destDecimals_) private pure returns (uint256) {
        return convert(amount_, 18, destDecimals_);
    }

    /**
     * @notice The function to substitute the trailing digits of a number with zeros
     * @param amount_ the number to round. Should be with 18 precision decimals
     * @param decimals_ the required number precision
     * @return the rounded number. Comes with 18 precision decimals
     */
    function _round18(uint256 amount_, uint256 decimals_) private pure returns (uint256) {
        return _to18(_from18(amount_, decimals_), decimals_);
    }

    function _safe(uint256 amount_) private pure returns (uint256) {
        require(amount_ > 0, "DecimalsConverter: conversion failed");

        return amount_;
    }
}


// File: @solarity/solidity-lib/libs/utils/TypeCaster.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/**
 * @notice This library simplifies non-obvious type castings
 */
library TypeCaster {
    /**
     * @notice The function that casts the list of `X`-type elements to the list of uint256
     * @param from_ the list of `X`-type elements
     * @return array_ the list of uint256
     */
    function asUint256Array(
        bytes32[] memory from_
    ) internal pure returns (uint256[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    function asUint256Array(
        address[] memory from_
    ) internal pure returns (uint256[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    /**
     * @notice The function that casts the list of `X`-type elements to the list of addresses
     * @param from_ the list of `X`-type elements
     * @return array_ the list of addresses
     */
    function asAddressArray(
        bytes32[] memory from_
    ) internal pure returns (address[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    function asAddressArray(
        uint256[] memory from_
    ) internal pure returns (address[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    /**
     * @notice The function that casts the list of `X`-type elements to the list of bytes32
     * @param from_ the list of `X`-type elements
     * @return array_ the list of bytes32
     */
    function asBytes32Array(
        uint256[] memory from_
    ) internal pure returns (bytes32[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    function asBytes32Array(
        address[] memory from_
    ) internal pure returns (bytes32[] memory array_) {
        assembly {
            array_ := from_
        }
    }

    /**
     * @notice The function to transform an element into an array
     * @param from_ the element
     * @return array_ the element as an array
     */
    function asSingletonArray(uint256 from_) internal pure returns (uint256[] memory array_) {
        array_ = new uint256[](1);
        array_[0] = from_;
    }

    function asSingletonArray(address from_) internal pure returns (address[] memory array_) {
        array_ = new address[](1);
        array_[0] = from_;
    }

    function asSingletonArray(bool from_) internal pure returns (bool[] memory array_) {
        array_ = new bool[](1);
        array_[0] = from_;
    }

    function asSingletonArray(string memory from_) internal pure returns (string[] memory array_) {
        array_ = new string[](1);
        array_[0] = from_;
    }

    function asSingletonArray(bytes32 from_) internal pure returns (bytes32[] memory array_) {
        array_ = new bytes32[](1);
        array_[0] = from_;
    }

    /**
     * @notice The function to convert static array to dynamic
     * @param static_ the static array to convert
     * @return dynamic_ the converted dynamic array
     */
    function asDynamic(
        uint256[1] memory static_
    ) internal pure returns (uint256[] memory dynamic_) {
        return asSingletonArray(static_[0]);
    }

    function asDynamic(
        uint256[2] memory static_
    ) internal pure returns (uint256[] memory dynamic_) {
        dynamic_ = new uint256[](2);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 2);
    }

    function asDynamic(
        uint256[3] memory static_
    ) internal pure returns (uint256[] memory dynamic_) {
        dynamic_ = new uint256[](3);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 3);
    }

    function asDynamic(
        uint256[4] memory static_
    ) internal pure returns (uint256[] memory dynamic_) {
        dynamic_ = new uint256[](4);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 4);
    }

    function asDynamic(
        uint256[5] memory static_
    ) internal pure returns (uint256[] memory dynamic_) {
        dynamic_ = new uint256[](5);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 5);
    }

    function asDynamic(
        address[1] memory static_
    ) internal pure returns (address[] memory dynamic_) {
        return asSingletonArray(static_[0]);
    }

    function asDynamic(
        address[2] memory static_
    ) internal pure returns (address[] memory dynamic_) {
        dynamic_ = new address[](2);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 2);
    }

    function asDynamic(
        address[3] memory static_
    ) internal pure returns (address[] memory dynamic_) {
        dynamic_ = new address[](3);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 3);
    }

    function asDynamic(
        address[4] memory static_
    ) internal pure returns (address[] memory dynamic_) {
        dynamic_ = new address[](4);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 4);
    }

    function asDynamic(
        address[5] memory static_
    ) internal pure returns (address[] memory dynamic_) {
        dynamic_ = new address[](5);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 5);
    }

    function asDynamic(bool[1] memory static_) internal pure returns (bool[] memory dynamic_) {
        return asSingletonArray(static_[0]);
    }

    function asDynamic(bool[2] memory static_) internal pure returns (bool[] memory dynamic_) {
        dynamic_ = new bool[](2);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 2);
    }

    function asDynamic(bool[3] memory static_) internal pure returns (bool[] memory dynamic_) {
        dynamic_ = new bool[](3);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 3);
    }

    function asDynamic(bool[4] memory static_) internal pure returns (bool[] memory dynamic_) {
        dynamic_ = new bool[](4);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 4);
    }

    function asDynamic(bool[5] memory static_) internal pure returns (bool[] memory dynamic_) {
        dynamic_ = new bool[](5);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 5);
    }

    function asDynamic(string[1] memory static_) internal pure returns (string[] memory dynamic_) {
        return asSingletonArray(static_[0]);
    }

    function asDynamic(string[2] memory static_) internal pure returns (string[] memory dynamic_) {
        dynamic_ = new string[](2);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 2);
    }

    function asDynamic(string[3] memory static_) internal pure returns (string[] memory dynamic_) {
        dynamic_ = new string[](3);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 3);
    }

    function asDynamic(string[4] memory static_) internal pure returns (string[] memory dynamic_) {
        dynamic_ = new string[](4);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 4);
    }

    function asDynamic(string[5] memory static_) internal pure returns (string[] memory dynamic_) {
        dynamic_ = new string[](5);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 5);
    }

    function asDynamic(
        bytes32[1] memory static_
    ) internal pure returns (bytes32[] memory dynamic_) {
        return asSingletonArray(static_[0]);
    }

    function asDynamic(
        bytes32[2] memory static_
    ) internal pure returns (bytes32[] memory dynamic_) {
        dynamic_ = new bytes32[](2);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 2);
    }

    function asDynamic(
        bytes32[3] memory static_
    ) internal pure returns (bytes32[] memory dynamic_) {
        dynamic_ = new bytes32[](3);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 3);
    }

    function asDynamic(
        bytes32[4] memory static_
    ) internal pure returns (bytes32[] memory dynamic_) {
        dynamic_ = new bytes32[](4);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 4);
    }

    function asDynamic(
        bytes32[5] memory static_
    ) internal pure returns (bytes32[] memory dynamic_) {
        dynamic_ = new bytes32[](5);

        uint256 pointerS_;
        uint256 pointerD_;

        assembly {
            pointerS_ := static_
            pointerD_ := dynamic_
        }

        _copy(pointerS_, pointerD_, 5);
    }

    function _copy(uint256 locationS_, uint256 locationD_, uint256 length_) private pure {
        assembly {
            for {
                let i := 0
            } lt(i, length_) {
                i := add(i, 1)
            } {
                locationD_ := add(locationD_, 0x20)

                mstore(locationD_, mload(locationS_))

                locationS_ := add(locationS_, 0x20)
            }
        }
    }
}


// File: contracts/core/CoreProperties.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@solarity/solidity-lib/access-control/MultiOwnable.sol";
import "@solarity/solidity-lib/contracts-registry/AbstractDependant.sol";

import "../interfaces/core/ICoreProperties.sol";
import "../interfaces/core/IContractsRegistry.sol";

import "./Globals.sol";

contract CoreProperties is ICoreProperties, MultiOwnable, AbstractDependant {
    CoreParameters public coreParameters;

    address internal _treasuryAddress;

    function __CoreProperties_init(CoreParameters calldata _coreParameters) external initializer {
        __MultiOwnable_init();

        coreParameters = _coreParameters;
    }

    function setDependencies(
        address contractsRegistry,
        bytes memory
    ) public virtual override dependant {
        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        _treasuryAddress = registry.getTreasuryContract();
    }

    function setCoreParameters(
        CoreParameters calldata _coreParameters
    ) external override onlyOwner {
        coreParameters = _coreParameters;
    }

    function setDEXECommissionPercentages(uint128 govCommission) external override onlyOwner {
        coreParameters.govCommissionPercentage = govCommission;
    }

    function setTokenSaleProposalCommissionPercentage(
        uint128 tokenSaleProposalCommissionPercentage
    ) external override onlyOwner {
        coreParameters
            .tokenSaleProposalCommissionPercentage = tokenSaleProposalCommissionPercentage;
    }

    function setVoteRewardsPercentages(
        uint128 micropoolVoteRewardsPercentage,
        uint128 treasuryVoteRewardsPercentage
    ) external override onlyOwner {
        coreParameters.micropoolVoteRewardsPercentage = micropoolVoteRewardsPercentage;
        coreParameters.treasuryVoteRewardsPercentage = treasuryVoteRewardsPercentage;
    }

    function setGovVotesLimit(uint128 newVotesLimit) external override onlyOwner {
        coreParameters.govVotesLimit = newVotesLimit;
    }

    function getDEXECommissionPercentages() external view override returns (uint128, address) {
        return (coreParameters.govCommissionPercentage, _treasuryAddress);
    }

    function getTokenSaleProposalCommissionPercentage() external view override returns (uint128) {
        return coreParameters.tokenSaleProposalCommissionPercentage;
    }

    function getVoteRewardsPercentages() external view override returns (uint128, uint128) {
        return (
            coreParameters.micropoolVoteRewardsPercentage,
            coreParameters.treasuryVoteRewardsPercentage
        );
    }

    function getGovVotesLimit() external view override returns (uint128) {
        return coreParameters.govVotesLimit;
    }
}


// File: contracts/core/Globals.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

uint256 constant PERCENTAGE_100 = 10 ** 27;
uint256 constant PRECISION = 10 ** 25;
uint256 constant DECIMALS = 10 ** 18;

uint256 constant MAX_UINT = type(uint256).max;

address constant ETHEREUM_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;


// File: contracts/gov/proposals/TokenSaleProposal.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts/utils/Multicall.sol";

import "@solarity/solidity-lib/contracts-registry/AbstractDependant.sol";

import "../../interfaces/gov/proposals/ITokenSaleProposal.sol";
import "../../interfaces/core/ISBT721.sol";

import "../../libs/gov/token-sale-proposal/TokenSaleProposalCreate.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalBuy.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalVesting.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalWhitelist.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalClaim.sol";
import "../../libs/gov/token-sale-proposal/TokenSaleProposalRecover.sol";

contract TokenSaleProposal is
    ITokenSaleProposal,
    ERC721HolderUpgradeable,
    ERC1155SupplyUpgradeable,
    AbstractDependant,
    Multicall
{
    using TokenSaleProposalCreate for *;
    using TokenSaleProposalBuy for Tier;
    using TokenSaleProposalVesting for Tier;
    using TokenSaleProposalWhitelist for Tier;
    using TokenSaleProposalClaim for Tier;
    using TokenSaleProposalRecover for Tier;

    address public govAddress;
    ISBT721 public babt;

    address public dexeGovAddress;
    CoreProperties public coreProperties;

    uint256 public override latestTierId;

    mapping(uint256 => Tier) internal _tiers;

    event TierCreated(
        uint256 tierId,
        address saleToken,
        ParticipationDetails[] participationDetails
    );
    event TierModified(
        uint256 tierId,
        address saleToken,
        ParticipationDetails[] participationDetails
    );
    event Bought(uint256 tierId, address paidWith, uint256 received, uint256 given, address buyer);
    event Whitelisted(uint256 tierId, address user);

    modifier onlyGov() {
        _onlyGov();
        _;
    }

    modifier onlyThis() {
        _onlyThis();
        _;
    }

    function __TokenSaleProposal_init(address _govAddress) external initializer {
        govAddress = _govAddress;
    }

    function setDependencies(
        address contractsRegistry,
        bytes memory
    ) public virtual override dependant {
        IContractsRegistry registry = IContractsRegistry(contractsRegistry);

        babt = ISBT721(registry.getBABTContract());
        dexeGovAddress = registry.getTreasuryContract();
        coreProperties = CoreProperties(registry.getCorePropertiesContract());
    }

    function createTiers(TierInitParams[] calldata tierInitParams) external override onlyGov {
        uint256 newTierId = latestTierId;

        latestTierId += tierInitParams.length;

        for (uint256 i = 0; i < tierInitParams.length; i++) {
            ++newTierId;

            _tiers.createTier(newTierId, tierInitParams[i]);

            emit TierCreated(
                newTierId,
                tierInitParams[i].saleTokenAddress,
                tierInitParams[i].participationDetails
            );
        }
    }

    function modifyTier(
        uint256 tierId,
        ITokenSaleProposal.TierInitParams calldata newSettings
    ) external onlyGov {
        _getActiveTier(tierId).modifyTier(newSettings);

        emit TierModified(tierId, newSettings.saleTokenAddress, newSettings.participationDetails);
    }

    function changeParticipationDetails(
        uint256 tierId,
        ITokenSaleProposal.ParticipationDetails[] calldata newSettings
    ) external onlyGov {
        ITokenSaleProposal.Tier storage tier = _getActiveTier(tierId);
        tier.changeParticipationDetails(newSettings);

        emit TierModified(tierId, tier.tierInitParams.saleTokenAddress, newSettings);
    }

    function addToWhitelist(WhitelistingRequest[] calldata requests) external override onlyGov {
        for (uint256 i = 0; i < requests.length; i++) {
            _getActiveTier(requests[i].tierId).addToWhitelist(requests[i]);
        }
    }

    function offTiers(uint256[] calldata tierIds) external override onlyGov {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getActiveTier(tierIds[i]).tierInfo.isOff = true;
        }
    }

    function recover(uint256[] calldata tierIds) external onlyGov {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).recover();
        }
    }

    function claim(uint256[] calldata tierIds) external override {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).claim();
        }
    }

    function vestingWithdraw(uint256[] calldata tierIds) external override {
        for (uint256 i = 0; i < tierIds.length; i++) {
            _getTier(tierIds[i]).vestingWithdraw();
        }
    }

    function buy(
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable {
        uint256 bought = _getActiveTier(tierId).buy(tierId, tokenToBuyWith, amount, proof);

        emit Bought(tierId, tokenToBuyWith, bought, amount, msg.sender);
    }

    function lockParticipationTokens(
        uint256 tierId,
        address tokenToLock,
        uint256 amountToLock
    ) external payable override {
        _getActiveTier(tierId).lockParticipationTokens(tokenToLock, amountToLock);
    }

    function lockParticipationNft(
        uint256 tierId,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external override {
        _getActiveTier(tierId).lockParticipationNft(nftToLock, nftIdsToLock);
    }

    function unlockParticipationTokens(
        uint256 tierId,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external override {
        _getTier(tierId).unlockParticipationTokens(tokenToUnlock, amountToUnlock);
    }

    function unlockParticipationNft(
        uint256 tierId,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external override {
        _getTier(tierId).unlockParticipationNft(nftToUnlock, nftIdsToUnlock);
    }

    function mint(address user, uint256 tierId) external onlyThis {
        _mint(user, tierId, 1, "");

        emit Whitelisted(tierId, user);
    }

    function getSaleTokenAmount(
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external view returns (uint256) {
        return
            _getActiveTier(tierId).getSaleTokenAmount(user, tierId, tokenToBuyWith, amount, proof);
    }

    function getClaimAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory claimAmounts) {
        claimAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < tierIds.length; i++) {
            claimAmounts[i] = _getTier(tierIds[i]).getClaimAmount(user);
        }
    }

    function getVestingWithdrawAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory vestingWithdrawAmounts) {
        vestingWithdrawAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < tierIds.length; i++) {
            vestingWithdrawAmounts[i] = _getTier(tierIds[i]).getVestingWithdrawAmount(user);
        }
    }

    function getRecoverAmounts(
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory recoveringAmounts) {
        recoveringAmounts = new uint256[](tierIds.length);

        for (uint256 i = 0; i < recoveringAmounts.length; i++) {
            recoveringAmounts[i] = _getTier(tierIds[i]).getRecoverAmount();
        }
    }

    function getTierViews(
        uint256 offset,
        uint256 limit
    ) external view returns (TierView[] memory tierViews) {
        return _tiers.getTierViews(offset, limit);
    }

    function getParticipationDetails(
        uint256 tierId
    ) external view returns (ITokenSaleProposal.ParticipationInfoView memory) {
        return _getActiveTier(tierId).getParticipationDetails();
    }

    function getUserViews(
        address user,
        uint256[] calldata tierIds,
        bytes32[][] calldata proofs
    ) external view returns (UserView[] memory userViews) {
        userViews = new UserView[](tierIds.length);

        for (uint256 i = 0; i < userViews.length; i++) {
            Tier storage tier = _getTier(tierIds[i]);

            userViews[i] = UserView({
                canParticipate: tier.canParticipate(tierIds[i], user, proofs[i]),
                purchaseView: tier.getPurchaseView(user),
                vestingUserView: tier.getVestingUserView(user)
            });
        }
    }

    function uri(uint256 tierId) public view override returns (string memory) {
        return _tiers[tierId].tierInfo.uri;
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        require(from == address(0), "TSP: only for minting");

        for (uint256 i = 0; i < ids.length; i++) {
            require(balanceOf(to, ids[i]) == 0, "TSP: balance can be only 0 or 1");
        }
    }

    function _onlyGov() internal view {
        require(msg.sender == govAddress, "TSP: not a Gov contract");
    }

    function _onlyThis() internal view {
        require(address(this) == msg.sender, "TSP: not this contract");
    }

    function _getTier(uint256 tierId) private view returns (Tier storage tier) {
        tier = _tiers[tierId];

        require(tier.tierInitParams.saleTokenAddress != address(0), "TSP: tier does not exist");
    }

    function _getActiveTier(uint256 tierId) private view returns (Tier storage tier) {
        tier = _getTier(tierId);

        require(!_tiers[tierId].tierInfo.isOff, "TSP: tier is off");
    }
}


// File: contracts/interfaces/core/IContractsRegistry.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the registry contract of DEXE platform that stores information about
 * the other contracts used by the protocol. Its purpose is to keep track of the propotol's
 * contracts, provide upgradeability mechanism and dependency injection mechanism.
 */
interface IContractsRegistry {
    /// @notice Used in dependency injection mechanism
    /// @return UserRegistry contract address
    function getUserRegistryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PoolFactory contract address
    function getPoolFactoryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PoolRegistry contract address
    function getPoolRegistryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return DEXE token contract address
    function getDEXEContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Wrapped native coin contract address
    function getWETHContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Platform's native USD token contract address. This may be USDT/BUSD/USDC/DAI/FEI
    function getUSDContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return PriceFeed contract address
    function getPriceFeedContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return TokenAllocator contract address
    function getTokenAllocatorContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return Treasury contract/wallet address
    function getTreasuryContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return CoreProperties contract address
    function getCorePropertiesContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return NetworkProperties contract address
    function getNetworkPropertiesContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return BABT contract address
    function getBABTContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return DexeExpertNft contract address
    function getDexeExpertNftContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return SphereX engine for DAOs
    function getPoolSphereXEngineContract() external view returns (address);

    /// @notice Used in dependency injection mechanism
    /// @return SphereX engine for global entities
    function getSphereXEngineContract() external view returns (address);
}


// File: contracts/interfaces/core/ICoreProperties.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the central contract of the protocol which stores the parameters that may be modified by the DAO.
 * These are commissions percentages and pools parameters
 */
interface ICoreProperties {
    /// @notice The struct that stores vital platform's parameters that may be modified by the OWNER
    /// The struct that stores GovPool parameters
    /// @param govVotesLimit the maximum number of simultaneous votes of the voter
    /// @param tokenSaleProposalCommissionPercentage the commission percentage for the token sale proposal
    /// @param micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @param treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    struct CoreParameters {
        uint128 govVotesLimit;
        uint128 govCommissionPercentage;
        uint128 tokenSaleProposalCommissionPercentage;
        uint128 micropoolVoteRewardsPercentage;
        uint128 treasuryVoteRewardsPercentage;
    }

    /// @notice The function to set CoreParameters
    /// @param _coreParameters the parameters
    function setCoreParameters(CoreParameters calldata _coreParameters) external;

    /// @notice The function to modify the platform's commission percentages
    /// @param govCommission the gov percentage commission. Should be multiplied by 10**25
    function setDEXECommissionPercentages(uint128 govCommission) external;

    /// @notice The function to set new token sale proposal commission percentage
    /// @param tokenSaleProposalCommissionPercentage the new commission percentage
    function setTokenSaleProposalCommissionPercentage(
        uint128 tokenSaleProposalCommissionPercentage
    ) external;

    /// @notice The function to set new vote rewards percentages
    /// @param micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @param treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    function setVoteRewardsPercentages(
        uint128 micropoolVoteRewardsPercentage,
        uint128 treasuryVoteRewardsPercentage
    ) external;

    /// @notice The function to set new gov votes limit
    /// @param newVotesLimit new gov votes limit
    function setGovVotesLimit(uint128 newVotesLimit) external;

    /// @notice The function to get commission percentage and receiver
    /// @return govPercentage the overall gov commission percentage
    /// @return treasuryAddress the address of the treasury commission
    function getDEXECommissionPercentages()
        external
        view
        returns (uint128 govPercentage, address treasuryAddress);

    /// @notice The function to get the token sale proposal commission percentage
    /// @return the commission percentage
    function getTokenSaleProposalCommissionPercentage() external view returns (uint128);

    /// @notice The function to get the vote rewards percentages
    /// @return micropoolVoteRewardsPercentage the percentage of the rewards for the micropool voters
    /// @return treasuryVoteRewardsPercentage the percentage of the rewards for the treasury voters
    function getVoteRewardsPercentages() external view returns (uint128, uint128);

    /// @notice The function to get max votes limit of the gov pool
    /// @return votesLimit the votes limit
    function getGovVotesLimit() external view returns (uint128 votesLimit);
}


// File: contracts/interfaces/core/ISBT721.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISBT721 {
    /**
     * @dev This emits when a new token is created and bound to an account by
     * any mechanism.
     * Note: For a reliable `to` parameter, retrieve the transaction's
     * authenticated `to` field.
     */
    event Attest(address indexed to, uint256 indexed tokenId);

    /**
     * @dev This emits when an existing SBT is revoked from an account and
     * destroyed by any mechanism.
     * Note: For a reliable `from` parameter, retrieve the transaction's
     * authenticated `from` field.
     */
    event Revoke(address indexed from, uint256 indexed tokenId);

    /**
     * @dev This emits when an existing SBT is burned by an account
     */
    event Burn(address indexed from, uint256 indexed tokenId);

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` to `to`.
     */
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    /**
     * @dev Mints SBT
     *
     * Requirements:
     *
     * - `to` must be valid.
     * - `to` must not exist.
     *
     * Emits a {Attest} event.
     * Emits a {Transfer} event.
     * @return The tokenId of the minted SBT
     */
    function attest(address to) external returns (uint256);

    /**
     * @dev Revokes SBT
     *
     * Requirements:
     *
     * - `from` must exist.
     *
     * Emits a {Revoke} event.
     * Emits a {Transfer} event.
     */
    function revoke(address from) external;

    /**
     * @notice At any time, an SBT receiver must be able to
     *  disassociate themselves from an SBT publicly through calling this
     *  function.
     *
     * Emits a {Burn} event.
     * Emits a {Transfer} event.
     */
    function burn() external;

    /**
     * @notice Count all SBTs assigned to an owner
     * @dev SBTs assigned to the zero address is considered invalid, and this
     * function throws for queries about the zero address.
     * @param owner An address for whom to query the balance
     * @return The number of SBTs owned by `owner`, possibly zero
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @param from The address of the SBT owner
     * @return The tokenId of the owner's SBT, and throw an error if there is no SBT belongs to the given address
     */
    function tokenIdOf(address from) external view returns (uint256);

    /**
     * @notice Find the address bound to a SBT
     * @dev SBTs assigned to zero address are considered invalid, and queries
     *  about them do throw.
     * @param tokenId The identifier for an SBT
     * @return The address of the owner bound to the SBT
     */
    function ownerOf(uint256 tokenId) external view returns (address);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);
}


// File: contracts/interfaces/gov/ERC20/IERC20Gov.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * DAO pools could issue their own ERC20 token and sell it to investors with custom sale logic
 */
interface IERC20Gov {
    /// @notice Initial ERC20Gov parameters. This struct is used as an input argument in the contract constructor
    /// @param name the name of the token
    /// @param symbol the symbol of the token
    /// @param users the list of users for which tokens are needed to be minted
    /// @param cap cap on the token's total supply
    /// @param mintedTotal the total amount of tokens to be minted with the contract creation
    /// @param amounts the list of token amounts which should be minted to the respective users
    struct ConstructorParams {
        string name;
        string symbol;
        address[] users;
        uint256 cap;
        uint256 mintedTotal;
        uint256[] amounts;
    }

    /// @notice This function is used to mint tokens
    /// @param account the address to which tokens should be minted
    /// @param amount the token amount to be minted
    function mint(address account, uint256 amount) external;

    /// @notice This function is used to trigger stopped contract state
    function pause() external;

    /// @notice This function is used to return default contract state
    function unpause() external;

    /// @notice This function is used to blacklist the addresses
    /// @param accounts the addresses to be blacklisted
    /// @param value the blacklist status
    function blacklist(address[] calldata accounts, bool value) external;

    /// @notice This function is used to get the total amount of blacklisted accounts
    function totalBlacklistAccounts() external view returns (uint256);

    /// @notice The paginated function to get addresses of blacklisted accounts
    /// @param offset the starting index of the accounts array
    /// @param limit the length of the array to observe
    /// @return requested blacklist array
    function getBlacklistAccounts(
        uint256 offset,
        uint256 limit
    ) external view returns (address[] memory);
}


// File: contracts/interfaces/gov/IGovPool.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../core/ICoreProperties.sol";

import "./settings/IGovSettings.sol";
import "./validators/IGovValidators.sol";

/**
 * This is the Governance pool contract. This contract is the third contract the user can deploy through
 * the factory. The users can participate in proposal's creation, voting and execution processes
 */
interface IGovPool {
    /// @notice The enum that holds information about proposal state
    /// @param Voting the proposal is in voting state
    /// @param WaitingForVotingTransfer the proposal is approved and waiting for transfer to validators contract
    /// @param ValidatorVoting the proposal is in validators voting state
    /// @param Defeated the proposal is defeated
    /// @param SucceededFor the proposal is succeeded on for step
    /// @param SucceededAgainst the proposal is succeeded on against step
    /// @param Locked the proposal is locked
    /// @param ExecutedFor the proposal is executed on for step
    /// @param ExecutedAgainst the proposal is executed on against step
    /// @param Undefined the proposal is undefined
    enum ProposalState {
        Voting,
        WaitingForVotingTransfer,
        ValidatorVoting,
        Defeated,
        SucceededFor,
        SucceededAgainst,
        Locked,
        ExecutedFor,
        ExecutedAgainst,
        Undefined
    }

    /// @notice The enum that holds information about reward type
    /// @param Create the reward type for proposal creation
    /// @param Vote the reward type for voting for proposal
    /// @param Execute the reward type for proposal execution
    /// @param SaveOffchainResults the reward type for saving off-chain results
    enum RewardType {
        Create,
        Vote,
        Execute,
        SaveOffchainResults
    }

    /// @notice The enum that holds information about vote type
    /// @param PersonalVote the vote type for personal voting
    /// @param MicropoolVote the vote type for micropool voting
    /// @param DelegatedVote the vote type for delegated voting
    /// @param TreasuryVote the vote type for treasury voting
    enum VoteType {
        PersonalVote,
        MicropoolVote,
        DelegatedVote,
        TreasuryVote
    }

    /// @notice The struct that holds information about dependencies
    /// @param settingsAddress the address of settings contract
    /// @param userKeeperAddress the address of user keeper contract
    /// @param validatorsAddress the address of validators contract
    /// @param expertNftAddress the address of expert nft contract
    /// @param nftMultiplierAddress the address of nft multiplier contract
    /// @param votePowerAddress the address of vote power contract
    struct Dependencies {
        address settingsAddress;
        address userKeeperAddress;
        address payable validatorsAddress;
        address expertNftAddress;
        address nftMultiplierAddress;
        address votePowerAddress;
    }

    /// @notice The struct holds core properties of proposal
    /// @param settings the struct that holds information about settings of the proposal
    /// @param voteEnd the timestamp of voting end for the proposal
    /// @param executeAfter the timestamp of execution in seconds after voting end
    /// @param executed the boolean indicating whether the proposal has been executed
    /// @param votesFor the total number of votes for the proposal from all voters
    /// @param votesAgainst the total number of votes against the proposal from all voters
    /// @param rawVotesFor the total number of votes for the proposal from all voters before the formula
    /// @param rawVotesAgainst the total number of votes against the proposal from all voters before the formula
    /// @param givenRewards the amount of rewards payable after the proposal execution
    struct ProposalCore {
        IGovSettings.ProposalSettings settings;
        uint64 voteEnd;
        uint64 executeAfter;
        bool executed;
        uint256 votesFor;
        uint256 votesAgainst;
        uint256 rawVotesFor;
        uint256 rawVotesAgainst;
        uint256 givenRewards;
    }

    /// @notice The struct holds information about proposal action
    /// @param executor the address of call's target, bounded by index with `value` and `data`
    /// @param value the eth value for call, bounded by index with `executor` and `data`
    /// @param data the of call data, bounded by index with `executor` and `value`
    struct ProposalAction {
        address executor;
        uint256 value;
        bytes data;
    }

    /// @notice The struct holds all information about proposal
    /// @param core the struct that holds information about core properties of proposal
    /// @param descriptionURL the string with link to IPFS doc with proposal description
    /// @param actionsOnFor the array of structs with information about actions on for step
    /// @param actionsOnAgainst the array of structs with information about actions on against step
    struct Proposal {
        ProposalCore core;
        string descriptionURL;
        ProposalAction[] actionsOnFor;
        ProposalAction[] actionsOnAgainst;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param proposal the `Proposal` struct
    /// @param validatorProposal the `ExternalProposal` struct
    /// @param proposalState the value from enum `ProposalState`, that shows proposal state at current time
    /// @param requiredQuorum the required votes amount to confirm the proposal
    /// @param requiredValidatorsQuorum the the required validator votes to confirm the proposal
    struct ProposalView {
        Proposal proposal;
        IGovValidators.ExternalProposal validatorProposal;
        ProposalState proposalState;
        uint256 requiredQuorum;
        uint256 requiredValidatorsQuorum;
    }

    /// @notice The struct that holds information about the typed vote (only for internal needs)
    /// @param tokensVoted the total erc20 amount voted from one user for the proposal before the formula
    /// @param totalVoted the total power of typed votes from one user for the proposal before the formula
    /// @param nftsAmount the amount of nfts participating in the vote
    /// @param nftsVoted the set of ids of nfts voted from one user for the proposal
    struct RawVote {
        uint256 tokensVoted;
        uint256 totalVoted;
        uint256 nftsAmount;
        EnumerableSet.UintSet nftsVoted;
    }

    /// @notice The struct that holds information about the global vote properties (only for internal needs)
    /// @param rawVotes matching vote types with their infos
    /// @param isVoteFor the boolean flag that indicates whether the vote is "for" the proposal
    /// @param totalVoted the total power of votes from one user for the proposal after the formula
    /// @param totalRawVoted the total power of votes from one user for the proposal before the formula
    struct VoteInfo {
        mapping(VoteType => RawVote) rawVotes;
        bool isVoteFor;
        uint256 totalVoted;
        uint256 totalRawVoted;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param isVoteFor the boolean flag that indicates whether the vote is "for" the proposal
    /// @param totalVoted the total power of votes from one user for the proposal after the formula
    /// @param tokensVoted the total erc20 amount voted from one user for the proposal before the formula
    /// @param totalRawVoted the total power of typed votes from one user for the proposal before the formula
    /// @param nftsVoted the set of ids of nfts voted from one user for the proposal
    struct VoteInfoView {
        bool isVoteFor;
        uint256 totalVoted;
        uint256 tokensVoted;
        uint256 totalRawVoted;
        uint256[] nftsVoted;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param rewardTokens the list of reward tokens
    /// @param isVoteFor the list of flags indicating whether the vote is "for" the proposal
    /// @param isClaimed the list of flags indicating whether the rewards have been claimed
    /// @param expectedRewards the list of expected rewards to be claimed
    struct DelegatorRewards {
        address[] rewardTokens;
        bool[] isVoteFor;
        bool[] isClaimed;
        uint256[] expectedRewards;
    }

    /// @notice The struct that holds information about the delegator (only for internal needs)
    /// @param delegationTimes the list of timestamps when delegated amount was changed
    /// @param delegationPowers the list of delegated assets powers
    /// @param isClaimed matching proposals ids with flags indicating whether rewards have been claimed
    struct DelegatorInfo {
        uint256[] delegationTimes;
        uint256[] delegationPowers;
        mapping(uint256 => bool) isClaimed;
        mapping(uint256 => uint256) partiallyClaimed;
    }

    /// @notice The struct that holds reward properties (only for internal needs)
    /// @param areVotingRewardsSet matching proposals ids with flags indicating whether voting rewards have been set during the personal or micropool claim
    /// @param staticRewards matching proposal ids to their static rewards
    /// @param votingRewards matching proposal ids to their voting rewards
    /// @param offchainRewards matching off-chain token addresses to their rewards
    /// @param offchainTokens the list of off-chain token addresses
    struct PendingRewards {
        mapping(uint256 => bool) areVotingRewardsSet;
        mapping(uint256 => uint256) staticRewards;
        mapping(uint256 => VotingRewards) votingRewards;
        mapping(address => uint256) offchainRewards;
        EnumerableSet.AddressSet offchainTokens;
    }

    /// @notice The struct that holds the user info (only for internal needs)
    /// @param voteInfos matching proposal ids to their infos
    /// @param pendingRewards user's pending rewards
    /// @param delegatorInfos matching delegators to their infos
    /// @param votedInProposals the list of active proposals user voted in
    /// @param treasuryExemptProposals the list of proposals user's treasury is exempted from
    struct UserInfo {
        mapping(uint256 => VoteInfo) voteInfos;
        PendingRewards pendingRewards;
        mapping(address => DelegatorInfo) delegatorInfos;
        EnumerableSet.UintSet votedInProposals;
        EnumerableSet.UintSet treasuryExemptProposals;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param personal rewards for the personal voting
    /// @param micropool rewards for the micropool voting
    /// @param treasury rewards for the treasury voting
    struct VotingRewards {
        uint256 personal;
        uint256 micropool;
        uint256 treasury;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param onchainTokens the list of on-chain token addresses
    /// @param staticRewards the list of static rewards
    /// @param votingRewards the list of voting rewards
    /// @param offchainRewards the list of off-chain rewards
    /// @param offchainTokens the list of off-chain token addresses
    struct PendingRewardsView {
        address[] onchainTokens;
        uint256[] staticRewards;
        VotingRewards[] votingRewards;
        uint256[] offchainRewards;
        address[] offchainTokens;
    }

    /// @notice The struct is used to hold info about validators monthly withdrawal credit
    /// @param tokenList the list of token allowed to withdraw
    /// @param tokenInfo the mapping token => withdrawals history and limits
    struct CreditInfo {
        address[] tokenList;
        mapping(address => TokenCreditInfo) tokenInfo;
    }

    /// @notice The struct is used to hold info about limits and withdrawals history
    /// @param monthLimit the monthly withdraw limit for the token
    /// @param cumulativeAmounts the list of amounts withdrawn
    /// @param timestamps the list of timestamps of withdraws
    struct TokenCreditInfo {
        uint256 monthLimit;
        uint256[] cumulativeAmounts;
        uint256[] timestamps;
    }

    /// @notice The struct is used to return info about current credit state
    /// @param token the token address
    /// @param monthLimit the amount that validator could withdraw monthly
    /// @param currentWithdrawLimit the amount that validators could withdraw now
    struct CreditInfoView {
        address token;
        uint256 monthLimit;
        uint256 currentWithdrawLimit;
    }

    /// @notice The struct that holds off-chain properties (only for internal needs)
    /// @param verifier the off-chain verifier address
    /// @param resultsHash the ipfs results hash
    /// @param usedHashes matching hashes to their usage state
    struct OffChain {
        address verifier;
        string resultsHash;
        mapping(bytes32 => bool) usedHashes;
    }

    /// @notice The function to get helper contract of this pool
    /// @return settings settings address
    /// @return userKeeper user keeper address
    /// @return validators validators address
    /// @return poolRegistry pool registry address
    /// @return votePower vote power address
    function getHelperContracts()
        external
        view
        returns (
            address settings,
            address userKeeper,
            address validators,
            address poolRegistry,
            address votePower
        );

    /// @notice The function to get helper contract of this pool
    /// @return pool registry address
    function getPoolRegistryContract() external view returns (address);

    /// @notice The function to get the nft contracts of this pool
    /// @return nftMultiplier rewards multiplier nft contract
    /// @return expertNft local expert nft contract
    /// @return dexeExpertNft global expert nft contract
    /// @return babt binance bound token
    function getNftContracts()
        external
        view
        returns (address nftMultiplier, address expertNft, address dexeExpertNft, address babt);

    /// @notice Create proposal
    /// @param descriptionURL IPFS url to the proposal's description
    /// @param actionsOnFor the array of structs with information about actions on for step
    /// @param actionsOnAgainst the array of structs with information about actions on against step
    function createProposal(
        string calldata descriptionURL,
        ProposalAction[] calldata actionsOnFor,
        ProposalAction[] calldata actionsOnAgainst
    ) external;

    /// @notice Create and vote for on the proposal
    /// @param descriptionURL IPFS url to the proposal's description
    /// @param actionsOnFor the array of structs with information about actions on for step
    /// @param actionsOnAgainst the array of structs with information about actions on against step
    /// @param voteAmount the erc20 vote amount
    /// @param voteNftIds the nft ids that will be used in voting
    function createProposalAndVote(
        string calldata descriptionURL,
        ProposalAction[] calldata actionsOnFor,
        ProposalAction[] calldata actionsOnAgainst,
        uint256 voteAmount,
        uint256[] calldata voteNftIds
    ) external;

    /// @notice Move proposal from internal voting to `Validators` contract
    /// @param proposalId Proposal ID
    function moveProposalToValidators(uint256 proposalId) external;

    /// @notice The function for voting for proposal with own tokens
    /// @notice values `voteAmount`, `voteNftIds` should be less or equal to the total deposit
    /// @param proposalId the id of the proposal
    /// @param isVoteFor the bool flag for voting for or against the proposal
    /// @param voteAmount the erc20 vote amount
    /// @param voteNftIds the nft ids that will be used in voting
    function vote(
        uint256 proposalId,
        bool isVoteFor,
        uint256 voteAmount,
        uint256[] calldata voteNftIds
    ) external;

    /// @notice The function for canceling vote
    /// @param proposalId the id of the proposal to cancel all votes from which
    function cancelVote(uint256 proposalId) external;

    /// @notice The function for depositing tokens to the pool
    /// @param amount the erc20 deposit amount
    /// @param nftIds the array of nft ids to deposit
    function deposit(uint256 amount, uint256[] calldata nftIds) external payable;

    /// @notice The function for withdrawing deposited tokens
    /// @param receiver the withdrawal receiver address
    /// @param amount the erc20 withdrawal amount
    /// @param nftIds the array of nft ids to withdraw
    function withdraw(address receiver, uint256 amount, uint256[] calldata nftIds) external;

    /// @notice The function for delegating tokens
    /// @param delegatee the target address for delegation (person who will receive the delegation)
    /// @param amount the erc20 delegation amount
    /// @param nftIds the array of nft ids to delegate
    function delegate(address delegatee, uint256 amount, uint256[] calldata nftIds) external;

    /// @notice The function for delegating tokens from treasury
    /// @param delegatee the target address for delegation (person who will receive the delegation)
    /// @param amount the erc20 delegation amount
    /// @param nftIds the array of nft ids to delegate
    function delegateTreasury(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external payable;

    /// @notice The function for undelegating delegated tokens
    /// @param delegatee the undelegation target address (person who will be undelegated)
    /// @param amount the erc20 undelegation amount
    /// @param nftIds the array of nft ids to undelegate
    function undelegate(address delegatee, uint256 amount, uint256[] calldata nftIds) external;

    /// @notice The function for undelegating delegated tokens from treasury
    /// @param delegatee the undelegation target address (person who will be undelegated)
    /// @param amount the erc20 undelegation amount
    /// @param nftIds the array of nft ids to undelegate
    function undelegateTreasury(
        address delegatee,
        uint256 amount,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function that unlocks user funds in completed proposals
    /// @param user the user whose funds to unlock
    function unlock(address user) external;

    /// @notice Execute proposal
    /// @param proposalId Proposal ID
    function execute(uint256 proposalId) external;

    /// @notice The function for claiming rewards from executed proposals
    /// @param proposalIds the array of proposal ids
    /// @param user the address of the user
    function claimRewards(uint256[] calldata proposalIds, address user) external;

    /// @notice The function for claiming micropool rewards from executed proposals
    /// @param proposalIds the array of proposal ids
    /// @param delegator the address of the delegator
    /// @param delegatee the address of the delegatee
    function claimMicropoolRewards(
        uint256[] calldata proposalIds,
        address delegator,
        address delegatee
    ) external;

    /// @notice The function to change vote power contract
    /// @param votePower new contract for the voting power formula
    function changeVotePower(address votePower) external;

    /// @notice The function for changing description url
    /// @param newDescriptionURL the string with new url
    function editDescriptionURL(string calldata newDescriptionURL) external;

    /// @notice The function for changing verifier address
    /// @param newVerifier the address of verifier
    function changeVerifier(address newVerifier) external;

    /// @notice The function for setting validators credit limit
    /// @param tokens the list of tokens to credit
    /// @param amounts the list of amounts to credit per month
    function setCreditInfo(address[] calldata tokens, uint256[] calldata amounts) external;

    /// @notice The function for fulfilling transfer request from validators
    /// @param tokens the list of tokens to send
    /// @param amounts the list of amounts to send
    /// @param destination the address to send tokens
    function transferCreditAmount(
        address[] memory tokens,
        uint256[] memory amounts,
        address destination
    ) external;

    /// @notice The function for changing the KYC restriction
    /// @param onlyBABT true id restriction is needed
    function changeBABTRestriction(bool onlyBABT) external;

    /// @notice The function for setting address of nft multiplier contract
    /// @param nftMultiplierAddress the address of nft multiplier
    function setNftMultiplierAddress(address nftMultiplierAddress) external;

    /// @notice The function for saving ipfs hash of off-chain proposal results
    /// @param resultsHash the ipfs results hash
    /// @param signature the signature from verifier
    function saveOffchainResults(string calldata resultsHash, bytes calldata signature) external;

    /// @notice The paginated function for getting proposal info list
    /// @param offset the proposal starting index
    /// @param limit the number of proposals to observe
    /// @return `ProposalView` array
    function getProposals(
        uint256 offset,
        uint256 limit
    ) external view returns (ProposalView[] memory);

    /// @param proposalId Proposal ID
    /// @return `ProposalState`:
    /// 0 -`Voting`, proposal where addresses can vote
    /// 1 -`WaitingForVotingTransfer`, approved proposal that waiting `moveProposalToValidators()` call
    /// 2 -`ValidatorVoting`, validators voting
    /// 3 -`Defeated`, proposal where voting time is over and proposal defeated on first or second step
    /// 4 -`SucceededFor`, successful proposal with votes for but not executed yet
    /// 5 -`SucceededAgainst`, successful proposal with votes against but not executed yet
    /// 6 -`Locked`, successful proposal but temporarily locked for execution
    /// 7 -`ExecutedFor`, executed proposal with the required number of votes on for step
    /// 8 -`ExecutedAgainst`, executed proposal with the required number of votes on against step
    /// 9 -`Undefined`, nonexistent proposal
    function getProposalState(uint256 proposalId) external view returns (ProposalState);

    /// @notice The function for getting user's active proposals count
    /// @param user the address of user
    /// @return the number of active proposals
    function getUserActiveProposalsCount(address user) external view returns (uint256);

    /// @notice The function for getting total raw votes in the proposal by one voter
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return `Arguments`: core raw votes for, core raw votes against, user typed raw votes, is vote for indicator
    function getTotalVotes(
        uint256 proposalId,
        address voter,
        VoteType voteType
    ) external view returns (uint256, uint256, uint256, bool);

    /// @notice The function to get required quorum of proposal
    /// @param proposalId the id of proposal
    /// @return the required number for votes to reach the quorum
    function getProposalRequiredQuorum(uint256 proposalId) external view returns (uint256);

    /// @notice The function to get information about user's votes
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return `VoteInfoView` array
    function getUserVotes(
        uint256 proposalId,
        address voter,
        VoteType voteType
    ) external view returns (VoteInfoView memory);

    /// @notice The function to get withdrawable assets
    /// @param delegator the delegator address
    /// @return `Arguments`: erc20 amount, array nft ids
    function getWithdrawableAssets(
        address delegator
    ) external view returns (uint256, uint256[] memory);

    /// @notice The function to get on-chain and off-chain rewards
    /// @param user the address of the user whose rewards are required
    /// @param proposalIds the list of proposal ids
    /// @return the list of rewards
    function getPendingRewards(
        address user,
        uint256[] calldata proposalIds
    ) external view returns (PendingRewardsView memory);

    /// @notice The function to get delegator staking rewards from all micropools
    /// @param proposalIds the list of proposal ids
    /// @param delegator the address of the delegator
    /// @param delegatee the address of the delegatee
    /// @return rewards delegator rewards
    function getDelegatorRewards(
        uint256[] calldata proposalIds,
        address delegator,
        address delegatee
    ) external view returns (DelegatorRewards memory);

    /// @notice The function to get info about validators credit limit
    /// @return the list of credit infos
    function getCreditInfo() external view returns (CreditInfoView[] memory);

    /// @notice The function to get off-chain info
    /// @return validator the verifier address
    /// @return resultsHash the ipfs hash
    function getOffchainInfo()
        external
        view
        returns (address validator, string memory resultsHash);

    /// @notice The function to get the sign hash from string resultsHash, chainid, govPool address
    /// @param resultsHash the ipfs hash
    /// @param user the user who requests the signature
    /// @return bytes32 hash
    function getOffchainSignHash(
        string calldata resultsHash,
        address user
    ) external view returns (bytes32);

    /// @notice The function to get expert status of a voter
    /// @return address of a person, who votes
    function getExpertStatus(address user) external view returns (bool);

    /// @notice The function to get core properties
    /// @return `ICoreProperties` interface
    function coreProperties() external view returns (ICoreProperties);
}


// File: contracts/interfaces/gov/proposals/ITokenSaleProposal.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";

/**
 * The contract for the additional proposal with custom settings.
 * This contract acts as a marketplace to provide DAO pools with the ability to sell their own ERC20 tokens.
 */
interface ITokenSaleProposal {
    /// @notice The enum that represents the type of requirements to participate in the tier
    /// @param DAOVotes indicates that the user must have the required voting power
    /// @param Whitelist indicates that the user must be included in the whitelist of the tier
    /// @param BABT indicates that the user must own the BABT token
    /// @param TokenLock indicates that the user must lock a specific amount of tokens in the tier
    /// @param NftLock indicates that the user must lock an nft in the tier
    /// @param MerkleWhitelist indicates that the user must have whitelist Merkle Proofs
    enum ParticipationType {
        DAOVotes,
        Whitelist,
        BABT,
        TokenLock,
        NftLock,
        MerkleWhitelist
    }

    /// @notice Metadata of the tier that is part of the initial tier parameters
    /// @param name the name of the tier
    /// @param description the description of the tier
    struct TierMetadata {
        string name;
        string description;
    }

    /// @notice Vesting parameters that are part of the initial tier parameters
    /// @param vestingPercentage percentage of the purchased token amount that goes to vesting
    /// @param vestingDuration how long vesting lasts from the time of the token purchase
    /// @param cliffPeriod how long the user cannot make a vesting withdrawal from the time of the token purchase
    /// @param unlockStep the tick step with which funds from the vesting are given to the buyer
    struct VestingSettings {
        uint256 vestingPercentage;
        uint64 vestingDuration;
        uint64 cliffPeriod;
        uint64 unlockStep;
    }

    /// @notice Participation details that are part of the initial tier parameters
    /// @param participationType the type of requirements to participate in the tier
    /// @param data the additional data associated with the participation requirements
    struct ParticipationDetails {
        ParticipationType participationType;
        bytes data;
    }

    /// @notice Initial tier parameters
    /// @param metadata metadata of the tier (see TierMetadata)
    /// @param totalTokenProvided total supply of tokens provided for the tier
    /// @param saleStartTime start time of token sales
    /// @param saleEndTime end time of token sales
    /// @param claimLockDuration the period of time between the end of the token sale and the non-vesting tokens claiming
    /// @param saleTokenAddress address of the token being sold
    /// @param purchaseTokenAddresses tokens, that can be used for purchasing token of the proposal
    /// @param exchangeRates exchange rates of other tokens to the token of TokenSaleProposal. Must disregard tokens decimals.
    /// If you want to sell 1 BTC for 1 ETH, exchangeRate has to be 10**25
    /// @param minAllocationPerUser minimal allocation of tokens per one user
    /// @param maxAllocationPerUser maximal allocation of tokens per one user
    /// @param vestingSettings settings for managing tokens vesting (unlocking). While tokens are locked investors won`t be able to withdraw them
    /// @param participationDetails the list of participation requirement parameters
    struct TierInitParams {
        TierMetadata metadata;
        uint256 totalTokenProvided;
        uint64 saleStartTime;
        uint64 saleEndTime;
        uint64 claimLockDuration;
        address saleTokenAddress;
        address[] purchaseTokenAddresses;
        uint256[] exchangeRates;
        uint256 minAllocationPerUser;
        uint256 maxAllocationPerUser;
        VestingSettings vestingSettings;
        ParticipationDetails[] participationDetails;
    }

    /// @notice Vesting tier-related parameters
    /// @param vestingStartTime the start time of the vesting when the cliff period ends
    /// @param vestingEndTime the end time of the vesting
    struct VestingTierInfo {
        uint64 vestingStartTime;
        uint64 vestingEndTime;
    }

    /// @notice Dynamic tier parameters
    /// @param isOff whether the tier is off
    /// @param totalSold how many tokens were sold
    /// @param uri whitelist uri
    /// @param vestingTierInfo vesting tier-related params
    struct TierInfo {
        bool isOff;
        uint256 totalSold;
        string uri;
        VestingTierInfo vestingTierInfo;
    }

    /// @notice Tier additional parameters
    /// @param merkleRoot root of Merkle Tree for whitelist (zero if Merkle proofs turned off)
    /// @param merkleUri merkle whitlist uri
    /// @param lastModified proposal was last modified on this block number. 0 for the new tiers
    struct TierAdditionalInfo {
        bytes32 merkleRoot;
        string merkleUri;
        uint256 lastModified;
    }

    /// @notice Purchase parameters
    /// @param spentAmounts matching purchase token addresses with spent amounts
    /// @param claimTotalAmount the total amount to be claimed
    /// @param isClaimed the boolean indicating whether the purchase has been claimed or not
    /// @param lockedTokens matching user locked tokens to locked amounts
    /// @param lockedNftAddresses the list of nft addresses locked by the user
    /// @param lockedNfts the list of nft ids locked by the user
    struct PurchaseInfo {
        EnumerableMap.AddressToUintMap spentAmounts;
        uint256 claimTotalAmount;
        bool isClaimed;
        EnumerableMap.AddressToUintMap lockedTokens;
        EnumerableSet.AddressSet lockedNftAddresses;
        mapping(address => EnumerableSet.UintSet) lockedNfts;
    }

    /// @notice Purchase parameters. This struct is used in view functions as part of a return argument
    /// @param isClaimed the boolean indicating whether non-vesting tokens have been claimed or not
    /// @param canClaim the boolean indication whether the user can claim non-vesting tokens
    /// @param claimUnlockTime the time the user can claim its non-vesting tokens
    /// @param claimTotalAmount the total amount of tokens to be claimed
    /// @param boughtTotalAmount the total amount of tokens user bought including vesting and non-vesting tokens
    /// @param lockedTokenAddresses the list of locked token addresses
    /// @param lockedTokenAmounts the list of locked token amounts
    /// @param lockedNftAddresses the list of locked nft addresses
    /// @param lockedNftIds the list of locked nft ids
    /// @param purchaseTokenAddresses the list of purchase token addresses
    /// @param purchaseTokenAmounts the list of purchase token amounts
    struct PurchaseView {
        bool isClaimed;
        bool canClaim;
        uint64 claimUnlockTime;
        uint256 claimTotalAmount;
        uint256 boughtTotalAmount;
        address[] lockedTokenAddresses;
        uint256[] lockedTokenAmounts;
        address[] lockedNftAddresses;
        uint256[][] lockedNftIds;
        address[] purchaseTokenAddresses;
        uint256[] purchaseTokenAmounts;
    }

    /// @notice Vesting user-related parameters
    /// @param latestVestingWithdraw the latest timestamp of the vesting withdrawal
    /// @param vestingTotalAmount the total amount of user vesting tokens
    /// @param vestingWithdrawnAmount the total amount of tokens user has withdrawn from vesting
    struct VestingUserInfo {
        uint64 latestVestingWithdraw;
        uint256 vestingTotalAmount;
        uint256 vestingWithdrawnAmount;
    }

    /// @notice Vesting user-related parameters. This struct is used in view functions as part of a return argument
    /// @param latestVestingWithdraw the latest timestamp of the vesting withdrawal
    /// @param nextUnlockTime the next time the user will receive vesting funds. It is zero if there are no more locked tokens
    /// @param nextUnlockAmount the token amount which will be unlocked in the next unlock time
    /// @param vestingTotalAmount the total amount of user vesting tokens
    /// @param vestingWithdrawnAmount the total amount of tokens user has withdrawn from vesting
    /// @param amountToWithdraw the vesting token amount which can be withdrawn in the current time
    /// @param lockedAmount the vesting token amount which is locked in the current time
    struct VestingUserView {
        uint64 latestVestingWithdraw;
        uint64 nextUnlockTime;
        uint256 nextUnlockAmount;
        uint256 vestingTotalAmount;
        uint256 vestingWithdrawnAmount;
        uint256 amountToWithdraw;
        uint256 lockedAmount;
    }

    /// @notice Participation parameters. Users should meet all the requirements in order to participate in the tier
    /// @param isWhitelisted the boolean indicating whether the tier requires whitelist
    /// @param isBABTed the boolean indicating whether the tier requires BABT token
    /// @param requiredDaoVotes the required amount of DAO votes
    /// @param requiredTokenLock matching token address to required lock amounts
    /// @param requiredNftLock matching nft address to required lock amounts
    struct ParticipationInfo {
        bool isWhitelisted;
        bool isBABTed;
        uint256 requiredDaoVotes;
        EnumerableMap.AddressToUintMap requiredTokenLock;
        EnumerableMap.AddressToUintMap requiredNftLock;
    }

    /// @notice Commplete list of participation parameters
    /// @param isWhitelisted the boolean indicating whether the tier requires whitelist
    /// @param isBABTed the boolean indicating whether the tier requires BABT token
    /// @param requiredDaoVotes the required amount of DAO votes
    /// @param requiredTokenAddresses list of required tokens to lock
    /// @param requiredTokenAmounts list of required amounts of token to lock
    /// @param requiredNftAddresses list of required nfts to lock
    /// @param requiredNftAmounts list of required amounts of nft to lock
    /// @param merkleRoot root of Merkle Tree for whitelist (zero if Merkle proofs turned off)
    /// @param merkleUri merkle whitlist uri
    struct ParticipationInfoView {
        bool isWhitelisted;
        bool isBABTed;
        uint256 requiredDaoVotes;
        address[] requiredTokenAddresses;
        uint256[] requiredTokenAmounts;
        address[] requiredNftAddresses;
        uint256[] requiredNftAmounts;
        bytes32 merkleRoot;
        string merkleUri;
    }

    /// @notice User parameters
    /// @param purchaseInfo the information about the user purchase
    /// @param vestingUserInfo the information about the user vesting
    struct UserInfo {
        PurchaseInfo purchaseInfo;
        VestingUserInfo vestingUserInfo;
    }

    /// @notice User parameters. This struct is used in view functions as a return argument
    /// @param canParticipate the boolean indicating whether the user is whitelisted in the corresponding tier
    /// @param purchaseView the information about the user purchase
    /// @param vestingUserView the information about the user vesting
    struct UserView {
        bool canParticipate;
        PurchaseView purchaseView;
        VestingUserView vestingUserView;
    }

    /// @notice Tier parameters
    /// @param tierInitParams the initial tier parameters
    /// @param tierInfo the information about the tier
    /// @param participationInfo the information about participation requirements
    /// @param rates the mapping of token addresses to their exchange rates
    /// @param users the mapping of user addresses to their infos
    /// @param tierAdditionalInfo the information about additional tier properties
    struct Tier {
        TierInitParams tierInitParams;
        TierInfo tierInfo;
        ParticipationInfo participationInfo;
        mapping(address => uint256) rates;
        mapping(address => UserInfo) users;
        TierAdditionalInfo tierAdditionalInfo;
    }

    /// @notice Tier parameters. This struct is used in view functions as a return argument
    /// @param tierInitParams the initial tier parameters
    /// @param tierInfo the information about the tier
    struct TierView {
        TierInitParams tierInitParams;
        TierInfo tierInfo;
        TierAdditionalInfo tierAdditionalInfo;
    }

    /// @notice Whitelisting request parameters. This struct is used as an input parameter to the whitelist update function
    /// @param tierId the id of the tier
    /// @param users the list of the users to be whitelisted
    /// @param uri tokens metadata uri
    struct WhitelistingRequest {
        uint256 tierId;
        address[] users;
        string uri;
    }

    /// @notice This function is used to get id (index) of the latest tier of the token sale
    /// @return the id of the latest tier
    function latestTierId() external view returns (uint256);

    /// @notice This function is used for tiers creation
    /// @param tiers parameters of tiers
    function createTiers(TierInitParams[] calldata tiers) external;

    /// @notice This function is used to modify tier
    /// @param tierId the id of tier
    /// @param newSettings the new tier settings
    function modifyTier(uint256 tierId, TierInitParams calldata newSettings) external;

    /// @notice This function is used for changing participation settings of the tier
    /// @param tierId id of the tier to modify
    /// @param newSettings list of participation parameters to set
    function changeParticipationDetails(
        uint256 tierId,
        ParticipationDetails[] calldata newSettings
    ) external;

    /// @notice This function is used to add users to the whitelist of tier
    /// @param requests requests for adding users to the whitelist
    function addToWhitelist(WhitelistingRequest[] calldata requests) external;

    /// @notice This function is used to set given tiers inactive
    /// @param tierIds tier ids to set inactive
    function offTiers(uint256[] calldata tierIds) external;

    /// @notice This function is used to return to the DAO treasury tokens that have not been purchased during sale
    /// @param tierIds tier ids to recover from
    function recover(uint256[] calldata tierIds) external;

    /// @notice This function is used to withdraw non-vesting tokens from given tiers
    /// @param tierIds tier ids to make withdrawals from
    function claim(uint256[] calldata tierIds) external;

    /// @notice This function is used to withdraw vesting tokens from given tiers
    /// @param tierIds tier ids to make withdrawals from
    function vestingWithdraw(uint256[] calldata tierIds) external;

    /// @notice This function is used to purchase tokens in the given tier
    /// @param tierId the id of the tier where tokens will be purchased
    /// @param tokenToBuyWith the token that will be used (exchanged) to purchase token on the token sale
    /// @param amount the amount of the token to be used for this exchange
    /// @param proof the merkle proof for merkle whitelist. Could be empty if whitelist is disabled
    function buy(
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external payable;

    /// @notice This function is used to lock the specified amount of tokens to participate in the given tier
    /// @param tierId the id of the tier to lock the tokens for
    /// @param tokenToLock the address of the token to be locked
    /// @param amountToLock the number of tokens to be locked
    function lockParticipationTokens(
        uint256 tierId,
        address tokenToLock,
        uint256 amountToLock
    ) external payable;

    /// @notice This function is used to lock the specified nft to participate in the given tier
    /// @param tierId the id of the tier to lock the nft for
    /// @param nftToLock the address of nft to be locked
    /// @param nftIdsToLock the list of nft ids to be locked
    function lockParticipationNft(
        uint256 tierId,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external;

    /// @notice This function is used to unlock participation tokens
    /// @param tierId the id of the tier to unlock the tokens for
    /// @param tokenToUnlock the address of the token to be unlocked
    /// @param amountToUnlock the number of tokens to be unlocked
    function unlockParticipationTokens(
        uint256 tierId,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external;

    /// @notice This function is used to unlock the participation nft
    /// @param tierId the id of the tier to unlock the nft for
    /// @param nftToUnlock the address of nft to be unlocked
    /// @param nftIdsToUnlock the list of nft ids to be unlocked
    function unlockParticipationNft(
        uint256 tierId,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external;

    /// @notice This function is used to get amount of `TokenSaleProposal` tokens that can be purchased
    /// @param user the address of the user that purchases tokens
    /// @param tierId the id of the tier in which tokens are purchased
    /// @param tokenToBuyWith the token which is used for exchange
    /// @param amount the token amount used for exchange
    /// @param proof the merkle proof for merkle whitelist. Could be empty if whitelist is disabled
    /// @return expected sale token amount
    function getSaleTokenAmount(
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external view returns (uint256);

    /// @notice This function is used to get information about the amount of non-vesting tokens that user can withdraw (that are unlocked) from given tiers
    /// @param user the address of the user
    /// @param tierIds the array of tier ids
    /// @return claimAmounts the array of token amounts that can be withdrawn from each tier
    function getClaimAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory claimAmounts);

    /// @notice This function is used to get information about the amount of vesting tokens that user can withdraw (that are unlocked) from given tiers
    /// @param user the address of the user
    /// @param tierIds the array of tier ids
    /// @return vestingWithdrawAmounts the array of token amounts that can be withdrawn from each tier
    function getVestingWithdrawAmounts(
        address user,
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory vestingWithdrawAmounts);

    /// @notice This function is used to get amount of tokens that have not been purchased during sale in given tiers and can be returned to DAO treasury
    /// @param tierIds the array of tier ids
    /// @return recoveringAmounts the array of token amounts that can be returned to DAO treasury in each tier
    function getRecoverAmounts(
        uint256[] calldata tierIds
    ) external view returns (uint256[] memory recoveringAmounts);

    /// @notice This function is used to get a list of tiers
    /// @param offset the offset of the list
    /// @param limit the limit for amount of elements in the list
    /// @return tierViews the list of tier views
    function getTierViews(
        uint256 offset,
        uint256 limit
    ) external view returns (TierView[] memory tierViews);

    /// @notice This function is used to get participation settings of a tier
    /// @param tierId the tier id
    /// @return tierParticipationDetails the list of tier participation settings
    function getParticipationDetails(
        uint256 tierId
    ) external view returns (ParticipationInfoView memory tierParticipationDetails);

    /// @notice This function is used to get user's infos from tiers
    /// @param user the address of the user whose infos are required
    /// @param tierIds the list of tier ids to get infos from
    /// @return userViews the list of user views
    /// @param proofs the list of merkle proofs
    function getUserViews(
        address user,
        uint256[] calldata tierIds,
        bytes32[][] calldata proofs
    ) external view returns (UserView[] memory userViews);
}


// File: contracts/interfaces/gov/settings/IGovSettings.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the contract that stores proposal settings that will be used by the governance pool
 */
interface IGovSettings {
    enum ExecutorType {
        DEFAULT,
        INTERNAL,
        VALIDATORS
    }

    /// @notice The struct holds information about settings for proposal type
    /// @param earlyCompletion the boolean flag, if true the voting completes as soon as the quorum is reached
    /// @param delegatedVotingAllowed the boolean flag, if true then delegators can vote with their own delegated tokens, else micropool vote allowed
    /// @param validatorsVote the boolean flag, if true then voting will have an additional validators step
    /// @param duration the duration of voting in seconds
    /// @param durationValidators the duration of validators voting in seconds
    /// @param executionDelay the delay in seconds before the proposal can be executed
    /// @param quorum the percentage of total votes supply (erc20 + nft) to confirm the proposal
    /// @param quorumValidators the percentage of total validator token supply to confirm the proposal
    /// @param minVotesForVoting the minimal needed voting power to vote for the proposal
    /// @param minVotesForCreating the minimal needed voting power to create the proposal
    /// @param rewardsInfo the reward info for proposal creation and execution
    /// @param executorDescription the settings description string
    struct ProposalSettings {
        bool earlyCompletion;
        bool delegatedVotingAllowed;
        bool validatorsVote;
        uint64 duration;
        uint64 durationValidators;
        uint64 executionDelay;
        uint128 quorum;
        uint128 quorumValidators;
        uint256 minVotesForVoting;
        uint256 minVotesForCreating;
        RewardsInfo rewardsInfo;
        string executorDescription;
    }

    /// @notice The struct holds information about rewards for proposals
    /// @param rewardToken the reward token address
    /// @param creationReward the amount of reward for proposal creation
    /// @param executionReward the amount of reward for proposal execution
    /// @param voteRewardsCoefficient the reward multiplier percents for voting for the proposal
    struct RewardsInfo {
        address rewardToken;
        uint256 creationReward;
        uint256 executionReward;
        uint256 voteRewardsCoefficient;
    }

    /// @notice The function to get settings of this executor
    /// @param executor the executor
    /// @return setting id of the executor
    function executorToSettings(address executor) external view returns (uint256);

    /// @notice Add new types to contract
    /// @param _settings New settings
    function addSettings(ProposalSettings[] calldata _settings) external;

    /// @notice Edit existed type
    /// @param settingsIds Existed settings IDs
    /// @param _settings New settings
    function editSettings(
        uint256[] calldata settingsIds,
        ProposalSettings[] calldata _settings
    ) external;

    /// @notice Change executors association
    /// @param executors Addresses
    /// @param settingsIds New types
    function changeExecutors(
        address[] calldata executors,
        uint256[] calldata settingsIds
    ) external;

    /// @notice The function to get default settings
    /// @return default setting
    function getDefaultSettings() external view returns (ProposalSettings memory);

    /// @notice The function to get internal settings
    /// @return internal setting
    function getInternalSettings() external view returns (ProposalSettings memory);

    /// @notice The function the get the settings of the executor
    /// @param executor Executor address
    /// @return `ProposalSettings` by `executor` address
    function getExecutorSettings(address executor) external view returns (ProposalSettings memory);
}


// File: contracts/interfaces/gov/user-keeper/IGovUserKeeper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import "../../../interfaces/gov/IGovPool.sol";

/**
 * This contract is responsible for securely storing user's funds that are used during the voting. These are either
 * ERC20 tokens or NFTs
 */
interface IGovUserKeeper {
    /// @notice The struct holds information about user deposited tokens
    /// @param tokens the amount of deposited tokens
    /// @param nfts the array of deposited nfts
    struct BalanceInfo {
        uint256 tokens;
        EnumerableSet.UintSet nfts;
    }

    /// @notice The struct holds information about user balances
    /// @param balances matching vote types with balance infos
    /// @param nftsPowers matching vote types with cached nfts powers
    /// @param delegatedBalances matching delegatees with balances infos
    /// @param delegatedNftPowers matching delegatees with delegated nft powers
    /// @param allDelegatedBalance the balance info of all delegated assets
    /// @param delegatees the array of delegatees
    /// @param maxTokensLocked the upper bound of currently locked tokens
    /// @param lockedInProposals the amount of deposited tokens locked in proposals
    struct UserInfo {
        mapping(IGovPool.VoteType => BalanceInfo) balances;
        mapping(IGovPool.VoteType => uint256) nftsPowers;
        mapping(address => BalanceInfo) delegatedBalances;
        mapping(address => uint256) delegatedNftPowers;
        BalanceInfo allDelegatedBalance;
        EnumerableSet.AddressSet delegatees;
        uint256 maxTokensLocked;
        mapping(uint256 => uint256) lockedInProposals;
    }

    /// @notice The struct holds information about nft contract
    /// @param nftAddress the address of the nft
    /// @param isSupportPower boolean flag, if true then nft contract supports power
    /// @param individualPower the voting power an nft
    /// @param totalSupply the total supply of nfts that are not enumerable
    /// @param nftMinPower matching nft ids to their minimal powers
    struct NFTInfo {
        address nftAddress;
        bool isSupportPower;
        uint256 individualPower;
        uint256 totalSupply;
        mapping(uint256 => uint256) nftMinPower;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param power the total vote power of a user
    /// @param rawPower the total deposited assets power of a user
    /// @param nftPower the total nft power of a user
    /// @param rawNftPower the total deposited nft power of a user
    /// @param perNftPower the power of every nft, bounded by index with nftIds
    /// @param ownedBalance the owned erc20 balance, decimals = 18
    /// @param ownedLength the amount of owned nfts
    /// @param nftIds the array of nft ids, bounded by index with perNftPower
    struct VotingPowerView {
        uint256 power;
        uint256 rawPower;
        uint256 nftPower;
        uint256 rawNftPower;
        uint256[] perNftPower;
        uint256 ownedBalance;
        uint256 ownedLength;
        uint256[] nftIds;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param delegatee the address of delegatee (person who gets delegation)
    /// @param delegatedTokens the amount of delegated tokens
    /// @param delegatedNfts the array of delegated nfts, bounded by index with perNftPower
    /// @param nftPower the total power of delegated nfts
    /// @param perNftPower the array of nft power, bounded by index with delegatedNfts
    struct DelegationInfoView {
        address delegatee;
        uint256 delegatedTokens;
        uint256[] delegatedNfts;
        uint256 nftPower;
        uint256[] perNftPower;
    }

    /// @notice The function for injecting dependencies from the GovPool
    /// @param contractsRegistry the address of Contracts Registry
    function setDependencies(address contractsRegistry, bytes memory) external;

    /// @notice The function for depositing tokens
    /// @param payer the address of depositor
    /// @param receiver the deposit receiver address
    /// @param amount the erc20 deposit amount
    function depositTokens(address payer, address receiver, uint256 amount) external payable;

    /// @notice The function for withdrawing tokens
    /// @param payer the address from whom to withdraw the tokens
    /// @param receiver the withdrawal receiver address
    /// @param amount the erc20 withdrawal amount
    function withdrawTokens(address payer, address receiver, uint256 amount) external;

    /// @notice The function for delegating tokens
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 delegation amount
    function delegateTokens(address delegator, address delegatee, uint256 amount) external;

    /// @notice The function for delegating tokens from Treasury
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 delegation amount
    function delegateTokensTreasury(address delegatee, uint256 amount) external payable;

    /// @notice The function for undelegating tokens
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 undelegation amount
    function undelegateTokens(address delegator, address delegatee, uint256 amount) external;

    /// @notice The function for undelegating tokens from Treasury
    /// @param delegatee the address of delegatee
    /// @param amount the erc20 undelegation amount
    function undelegateTokensTreasury(address delegatee, uint256 amount) external;

    /// @notice The function for depositing nfts
    /// @param payer the address of depositor
    /// @param receiver the deposit receiver address
    /// @param nftIds the array of deposited nft ids
    function depositNfts(address payer, address receiver, uint256[] calldata nftIds) external;

    /// @notice The function for withdrawing nfts
    /// @param payer the address from whom to withdraw the nfts
    /// @param receiver the withdrawal receiver address
    /// @param nftIds the withdrawal nft ids
    function withdrawNfts(address payer, address receiver, uint256[] calldata nftIds) external;

    /// @notice The function for delegating nfts
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of delegated nft ids
    function delegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for delegating nfts from Treasury
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of delegated nft ids
    function delegateNftsTreasury(address delegatee, uint256[] calldata nftIds) external;

    /// @notice The function for undelegating nfts
    /// @param delegator the address of delegator
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of undelegated nft ids
    function undelegateNfts(
        address delegator,
        address delegatee,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for undelegating nfts from Treasury
    /// @param delegatee the address of delegatee
    /// @param nftIds the array of undelegated nft ids
    function undelegateNftsTreasury(address delegatee, uint256[] calldata nftIds) external;

    /// @notice The function for recalculating max token locked amount of a user
    /// @param lockedProposals the array of proposal ids for recalculation
    /// @param voter the address of voter
    function updateMaxTokenLockedAmount(
        uint256[] calldata lockedProposals,
        address voter
    ) external;

    /// @notice The function for locking tokens in a proposal
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    /// @param amount the amount of tokens to lock
    function lockTokens(uint256 proposalId, address voter, uint256 amount) external;

    /// @notice The function for unlocking tokens in proposal
    /// @param proposalId the id of proposal
    /// @param voter the address of voter
    function unlockTokens(uint256 proposalId, address voter) external;

    /// @notice The function for locking nfts
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @param nftIds the array of nft ids to lock
    function lockNfts(
        address voter,
        IGovPool.VoteType voteType,
        uint256[] calldata nftIds
    ) external;

    /// @notice The function for unlocking nfts
    /// @param nftIds the array of nft ids to unlock
    function unlockNfts(uint256[] calldata nftIds) external;

    /// @notice The function for recalculating power of nfts
    /// @param nftIds the array of nft ids to recalculate the power for
    function updateNftPowers(uint256[] calldata nftIds) external;

    /// @notice The function for setting erc20 address
    /// @param _tokenAddress the erc20 address
    function setERC20Address(address _tokenAddress) external;

    /// @notice The function for setting erc721 address
    /// @param _nftAddress the erc721 address
    /// @param individualPower the voting power of an nft
    /// @param nftsTotalSupply the total supply of nft contract
    function setERC721Address(
        address _nftAddress,
        uint256 individualPower,
        uint256 nftsTotalSupply
    ) external;

    /// @notice The function for getting erc20 address
    /// @return `tokenAddress` the erc20 address
    function tokenAddress() external view returns (address);

    /// @notice The function for getting erc721 address
    /// @return `nftAddress` the erc721 address
    function nftAddress() external view returns (address);

    /// @notice The function for getting nft info
    /// @return isSupportPower boolean flag, if true then nft contract supports power
    /// @return individualPower the voting power an nft
    /// @return totalSupply the total supply of nfts that are not enumerable
    function getNftInfo()
        external
        view
        returns (bool isSupportPower, uint256 individualPower, uint256 totalSupply);

    /// @notice The function for getting max locked amount of a user
    /// @param voter the address of voter
    /// @return `max locked amount`
    function maxLockedAmount(address voter) external view returns (uint256);

    /// @notice The function for getting token balance of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return balance the total balance with delegations
    /// @return ownedBalance the user balance that is not deposited to the contract
    function tokenBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256 balance, uint256 ownedBalance);

    /// @notice The function for getting nft balance of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return balance the total balance with delegations
    /// @return ownedBalance the number of nfts that are not deposited to the contract
    function nftBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256 balance, uint256 ownedBalance);

    /// @notice The function for getting nft ids of a user
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @return nfts the array of owned nft ids
    /// @return ownedLength the number of nfts that are not deposited to the contract
    function nftExactBalance(
        address voter,
        IGovPool.VoteType voteType
    ) external view returns (uint256[] memory nfts, uint256 ownedLength);

    /// @notice The function for getting total power of nfts by ids
    /// @param nftIds the array of nft ids
    /// @param voteType the type of vote
    /// @param voter the address of user
    /// @param perNftPowerArray should the nft raw powers array be returned
    /// @return nftPower the total total power of nfts
    /// @return perNftPower the array of nft powers, bounded with nftIds by index
    function getTotalNftsPower(
        uint256[] memory nftIds,
        IGovPool.VoteType voteType,
        address voter,
        bool perNftPowerArray
    ) external view returns (uint256 nftPower, uint256[] memory perNftPower);

    /// @notice The function for getting total voting power of the contract
    /// @return power total power
    function getTotalPower() external view returns (uint256 power);

    /// @notice The function to define if voter is able to create a proposal. Includes micropool balance
    /// @param voter the address of voter
    /// @param voteType the type of vote
    /// @param requiredVotes the required voting power
    /// @return `true` - can participate, `false` - can't participate
    function canCreate(
        address voter,
        IGovPool.VoteType voteType,
        uint256 requiredVotes
    ) external view returns (bool);

    /// @notice The function for getting voting power of users
    /// @param users the array of users addresses
    /// @param voteTypes the array of vote types
    /// @param perNftPowerArray should the nft powers array be calculated
    /// @return votingPowers the array of VotingPowerView structs
    function votingPower(
        address[] calldata users,
        IGovPool.VoteType[] calldata voteTypes,
        bool perNftPowerArray
    ) external view returns (VotingPowerView[] memory votingPowers);

    /// @notice The function for getting voting power after the formula
    /// @param voter the address of the voter
    /// @param amount the amount of tokens
    /// @param nftIds the array of nft ids
    /// @return personalPower the personal voting power after the formula
    /// @return fullPower the personal plus delegated voting power after the formula
    function transformedVotingPower(
        address voter,
        uint256 amount,
        uint256[] calldata nftIds
    ) external view returns (uint256 personalPower, uint256 fullPower);

    /// @notice The function for getting information about user's delegations
    /// @param user the address of user
    /// @param perNftPowerArray should the nft powers array be calculated
    /// @return power the total delegated power
    /// @return delegationsInfo the array of DelegationInfoView structs
    function delegations(
        address user,
        bool perNftPowerArray
    ) external view returns (uint256 power, DelegationInfoView[] memory delegationsInfo);

    /// @notice The function for getting information about funds that can be withdrawn
    /// @param voter the address of voter
    /// @param lockedProposals the array of ids of locked proposals
    /// @param unlockedNfts the array of unlocked nfts
    /// @return withdrawableTokens the tokens that can we withdrawn
    /// @return withdrawableNfts the array of nfts that can we withdrawn
    function getWithdrawableAssets(
        address voter,
        uint256[] calldata lockedProposals,
        uint256[] calldata unlockedNfts
    ) external view returns (uint256 withdrawableTokens, uint256[] memory withdrawableNfts);

    /// @notice The function for getting the total delegated power by the delegator and the delegatee
    /// @param delegator the address of the delegator
    /// @param delegatee the address of the delegatee
    /// @return delegatedPower the total delegated power
    function getDelegatedAssetsPower(
        address delegator,
        address delegatee
    ) external view returns (uint256 delegatedPower);

    /// @notice The function for getting the wrapped token amount, not covered by ether
    /// @param value the ether value sent alongside the call
    /// @param amount the total amount of wrapped ether with 18 decimals
    /// @return nativeAmount the amount of wrapped ether with native decimals minus ether value
    function getAmountWithNativeDecimals(
        uint256 value,
        uint256 amount
    ) external view returns (uint256 nativeAmount);

    function stakeTokens(uint256 tierId, uint256 amount) external;

    function stakingProposalAddress() external view returns (address);

    function deployStakingProposal() external;
}


// File: contracts/interfaces/gov/validators/IGovValidators.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * This is the voting contract that is queried on the proposal's second voting stage
 */
interface IGovValidators {
    enum ProposalState {
        Voting,
        Defeated,
        Succeeded,
        Locked,
        Executed,
        Undefined
    }

    enum ProposalType {
        ChangeSettings,
        ChangeBalances,
        MonthlyWithdraw,
        OffchainProposal
    }

    /// @notice The struct holds information about settings for validators proposal
    /// @param duration the duration of voting
    /// @param executionDelay the delay in seconds after voting end
    /// @param quorum the percentage of validators token supply to confirm the proposal
    struct ProposalSettings {
        uint64 duration;
        uint64 executionDelay;
        uint128 quorum;
    }

    /// @notice The struct holds core properties of a proposal
    /// @param executed the boolean flag that indicates whether the proposal is executed or not
    /// @param snapshotId the id of snapshot
    /// @param voteEnd the timestamp of voting end of the proposal
    /// @param executeAfter the timestamp of execution in seconds after voting end
    /// @param quorum the percentage of validators token supply to confirm the proposal
    /// @param votesFor the total number of votes in proposal from all voters
    /// @param votesAgainst the total number of votes against proposal from all voters
    struct ProposalCore {
        bool executed;
        uint56 snapshotId;
        uint64 voteEnd;
        uint64 executeAfter;
        uint128 quorum;
        uint256 votesFor;
        uint256 votesAgainst;
    }

    /// @notice The struct holds information about the internal proposal
    /// @param proposalType the `ProposalType` enum
    /// @param core the struct that holds information about core properties of the proposal
    /// @param descriptionURL the string with link to IPFS doc with proposal description
    /// @param data the data to be executed
    struct InternalProposal {
        ProposalType proposalType;
        ProposalCore core;
        string descriptionURL;
        bytes data;
    }

    /// @notice The struct holds information about the external proposal
    /// @param core the struct that holds information about core properties of a proposal
    struct ExternalProposal {
        ProposalCore core;
    }

    /// @notice The struct that is used in view functions of contract as a return argument
    /// @param proposal the `InternalProposal` struct
    /// @param proposalState the `ProposalState` enum
    /// @param requiredQuorum the percentage of validators token supply to confirm the proposal
    struct InternalProposalView {
        InternalProposal proposal;
        ProposalState proposalState;
        uint256 requiredQuorum;
    }

    /// @notice The function for getting current number of validators
    /// @return `number` of validators
    function validatorsCount() external view returns (uint256);

    /// @notice Create internal proposal for changing validators balances, base quorum, base duration
    /// @param proposalType `ProposalType`
    /// 0 - `ChangeInternalDurationAndQuorum`, change base duration and quorum
    /// 1 - `ChangeBalances`, change address balance
    /// 2 - `MonthlyWithdraw`, monthly token withdraw
    /// 3 - `OffchainProposal`, offchain action
    /// @param data New packed data, depending on proposal type
    function createInternalProposal(
        ProposalType proposalType,
        string calldata descriptionURL,
        bytes calldata data
    ) external;

    /// @notice Create external proposal. This function can call only `Gov` contract
    /// @param proposalId Proposal ID from `Gov` contract
    /// @param proposalSettings `ProposalSettings` struct
    function createExternalProposal(
        uint256 proposalId,
        ProposalSettings calldata proposalSettings
    ) external;

    function voteInternalProposal(uint256 proposalId, uint256 amount, bool isVoteFor) external;

    function voteExternalProposal(uint256 proposalId, uint256 amount, bool isVoteFor) external;

    function cancelVoteInternalProposal(uint256 proposalId) external;

    function cancelVoteExternalProposal(uint256 proposalId) external;

    /// @notice Only for internal proposals. External proposals should be executed from governance.
    /// @param proposalId Internal proposal ID
    function executeInternalProposal(uint256 proposalId) external;

    /// @notice The function called by governance that marks the external proposal as executed
    /// @param proposalId External proposal ID
    function executeExternalProposal(uint256 proposalId) external;

    function changeSettings(uint64 duration, uint64 executionDelay, uint128 quorum) external;

    /// @notice The function for changing validators balances
    /// @param newValues the array of new balances
    /// @param userAddresses the array validators addresses
    function changeBalances(
        uint256[] calldata newValues,
        address[] calldata userAddresses
    ) external;

    function monthlyWithdraw(
        address[] calldata tokens,
        uint256[] calldata amounts,
        address destination
    ) external;

    /// @notice The function for getting information about the external proposals
    /// @param index the index of proposal
    /// @return `ExternalProposal` struct
    function getExternalProposal(uint256 index) external view returns (ExternalProposal memory);

    /// @notice The function for getting information about internal proposals
    /// @param offset the starting proposal index
    /// @param limit the length of the observed proposals
    /// @return `InternalProposalView` struct array
    function getInternalProposals(
        uint256 offset,
        uint256 limit
    ) external view returns (InternalProposalView[] memory);

    /// @notice Return proposal state
    /// @dev Options:
    /// `Voting` - proposal where addresses can vote.
    /// `Defeated` - proposal where voting time is over and proposal defeated.
    /// `Succeeded` - proposal with the required number of votes.
    /// `Executed` - executed proposal (only for internal proposal).
    /// `Undefined` - nonexistent proposal.
    function getProposalState(
        uint256 proposalId,
        bool isInternal
    ) external view returns (ProposalState);

    /// @notice The function for getting proposal required quorum
    /// @param proposalId the id of proposal
    /// @param isInternal the boolean flag, if true then proposal is internal
    /// @return the number of votes to reach the quorum
    function getProposalRequiredQuorum(
        uint256 proposalId,
        bool isInternal
    ) external view returns (uint256);

    /// @notice The function that checks if a user is a validator
    /// @param user the address of a user
    /// @return `flag`, if true, than user is a validator
    function isValidator(address user) external view returns (bool);
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalBuy.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import "@solarity/solidity-lib/libs/utils/TypeCaster.sol";
import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";
import "../../../interfaces/gov/IGovPool.sol";
import "../../../interfaces/gov/user-keeper/IGovUserKeeper.sol";

import "../../../core/CoreProperties.sol";
import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../libs/math/MathHelper.sol";
import "../../../libs/utils/TypeHelper.sol";

library TokenSaleProposalBuy {
    using MathHelper for uint256;
    using DecimalsConverter for *;
    using TypeCaster for *;
    using TypeHelper for *;
    using SafeERC20 for IERC20;
    using EnumerableSet for *;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using MerkleProof for *;

    function buy(
        ITokenSaleProposal.Tier storage tier,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) external returns (uint256 saleTokenAmount) {
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[msg.sender];
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = userInfo.purchaseInfo;
        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        require(
            (tokenToBuyWith != ETHEREUM_ADDRESS && msg.value == 0) || amount == msg.value,
            "TSP: wrong native amount"
        );

        saleTokenAmount = getSaleTokenAmount(
            tier,
            msg.sender,
            tierId,
            tokenToBuyWith,
            amount,
            proof
        );

        uint256 vestingCurrentAmount = saleTokenAmount.percentage(
            tierInitParams.vestingSettings.vestingPercentage
        );
        uint256 claimCurrentAmount = saleTokenAmount - vestingCurrentAmount;

        tier.tierInfo.totalSold += saleTokenAmount;

        (, uint256 previousSpentAmount) = purchaseInfo.spentAmounts.tryGet(tokenToBuyWith);
        purchaseInfo.spentAmounts.set(tokenToBuyWith, previousSpentAmount + amount);
        purchaseInfo.claimTotalAmount += claimCurrentAmount;

        userInfo.vestingUserInfo.vestingTotalAmount += vestingCurrentAmount;

        _purchaseWithCommission(tokenToBuyWith, amount);
    }

    function _purchaseWithCommission(address token, uint256 amount) internal {
        TokenSaleProposal tokenSaleProposal = TokenSaleProposal(address(this));
        address govAddress = tokenSaleProposal.govAddress();
        address dexeGovAddress = tokenSaleProposal.dexeGovAddress();

        if (govAddress != dexeGovAddress) {
            CoreProperties coreProperties = CoreProperties(tokenSaleProposal.coreProperties());

            uint256 commission = amount.percentage(
                coreProperties.getTokenSaleProposalCommissionPercentage()
            );

            _sendFunds(token, dexeGovAddress, commission);

            amount -= commission;
        }

        _sendFunds(token, govAddress, amount);
    }

    function _sendFunds(address token, address to, uint256 amount) internal {
        if (token == ETHEREUM_ADDRESS) {
            (bool success, ) = to.call{value: amount}("");
            require(success, "TSP: failed to transfer ether");
        } else {
            IERC20(token).safeTransferFrom(msg.sender, to, amount.from18Safe(token));
        }
    }

    function getSaleTokenAmount(
        ITokenSaleProposal.Tier storage tier,
        address user,
        uint256 tierId,
        address tokenToBuyWith,
        uint256 amount,
        bytes32[] calldata proof
    ) public view returns (uint256) {
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[msg.sender];

        require(amount > 0, "TSP: zero amount");
        require(canParticipate(tier, tierId, user, proof), "TSP: cannot participate");
        require(
            tierInitParams.saleStartTime <= block.timestamp &&
                block.timestamp <= tierInitParams.saleEndTime,
            "TSP: cannot buy now"
        );

        uint256 exchangeRate = tier.rates[tokenToBuyWith];

        require(exchangeRate != 0, "TSP: incorrect token");

        uint256 saleTokenAmount = amount.ratio(PRECISION, exchangeRate);
        uint256 userBoughtAmount = saleTokenAmount +
            userInfo.purchaseInfo.claimTotalAmount +
            userInfo.vestingUserInfo.vestingTotalAmount;

        require(
            tierInitParams.maxAllocationPerUser == 0 ||
                (tierInitParams.minAllocationPerUser <= userBoughtAmount &&
                    userBoughtAmount <= tierInitParams.maxAllocationPerUser),
            "TSP: wrong allocation"
        );
        require(
            tier.tierInfo.totalSold + saleTokenAmount <= tierInitParams.totalTokenProvided,
            "TSP: insufficient sale token amount"
        );

        return saleTokenAmount;
    }

    function canParticipate(
        ITokenSaleProposal.Tier storage tier,
        uint256 tierId,
        address user,
        bytes32[] calldata proof
    ) public view returns (bool) {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        TokenSaleProposal tokenSaleProposal = TokenSaleProposal(address(this));

        bool _canParticipate = true;

        if (participationInfo.requiredDaoVotes > 0) {
            (, address govUserKeeper, , , ) = IGovPool(tokenSaleProposal.govAddress())
                .getHelperContracts();

            _canParticipate =
                IGovUserKeeper(govUserKeeper)
                .votingPower(
                    user.asSingletonArray(),
                    IGovPool.VoteType.DelegatedVote.asSingletonArray(),
                    false
                )[0].rawPower >
                participationInfo.requiredDaoVotes;
        }

        bool isMerkleRootPresent = tier.tierAdditionalInfo.merkleRoot != bytes32(0);

        if (_canParticipate && (participationInfo.isWhitelisted || isMerkleRootPresent)) {
            bool turnedOnAndWhitelisted = participationInfo.isWhitelisted &&
                tokenSaleProposal.balanceOf(user, tierId) > 0;

            _canParticipate = turnedOnAndWhitelisted || _checkMerkleProofs(tier, proof, user);
        }

        if (_canParticipate && participationInfo.isBABTed) {
            _canParticipate = tokenSaleProposal.babt().balanceOf(user) > 0;
        }

        if (_canParticipate && participationInfo.requiredTokenLock.length() > 0) {
            _canParticipate = _checkUserLockedTokens(tier, user);
        }

        if (_canParticipate && participationInfo.requiredNftLock.length() > 0) {
            _canParticipate = _checkUserLockedNfts(tier, user);
        }

        return _canParticipate;
    }

    function getPurchaseView(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) external view returns (ITokenSaleProposal.PurchaseView memory purchaseView) {
        ITokenSaleProposal.UserInfo storage userInfo = tier.users[user];
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = userInfo.purchaseInfo;
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;

        purchaseView.isClaimed = purchaseInfo.isClaimed;
        purchaseView.claimUnlockTime =
            tierInitParams.saleEndTime +
            tierInitParams.claimLockDuration;
        purchaseView.canClaim = purchaseView.claimUnlockTime <= block.timestamp;
        purchaseView.claimTotalAmount = purchaseInfo.claimTotalAmount;
        purchaseView.boughtTotalAmount =
            purchaseView.claimTotalAmount +
            userInfo.vestingUserInfo.vestingTotalAmount;

        uint256 lockedTokenLength = purchaseInfo.lockedTokens.length();

        purchaseView.lockedTokenAddresses = new address[](lockedTokenLength);
        purchaseView.lockedTokenAmounts = new uint256[](lockedTokenLength);

        for (uint256 i = 0; i < lockedTokenLength; i++) {
            (
                purchaseView.lockedTokenAddresses[i],
                purchaseView.lockedTokenAmounts[i]
            ) = purchaseInfo.lockedTokens.at(i);
        }

        uint256 lockedNftLength = purchaseInfo.lockedNftAddresses.length();

        purchaseView.lockedNftAddresses = new address[](lockedNftLength);
        purchaseView.lockedNftIds = new uint256[][](lockedNftLength);

        for (uint256 i = 0; i < lockedNftLength; i++) {
            address lockedNftAddress = purchaseInfo.lockedNftAddresses.at(i);

            purchaseView.lockedNftAddresses[i] = lockedNftAddress;
            purchaseView.lockedNftIds[i] = purchaseInfo.lockedNfts[lockedNftAddress].values();
        }

        uint256 purchaseTokenLength = purchaseInfo.spentAmounts.length();

        purchaseView.purchaseTokenAddresses = new address[](purchaseTokenLength);
        purchaseView.purchaseTokenAmounts = new uint256[](purchaseTokenLength);

        for (uint256 i = 0; i < purchaseTokenLength; i++) {
            (
                purchaseView.purchaseTokenAddresses[i],
                purchaseView.purchaseTokenAmounts[i]
            ) = purchaseInfo.spentAmounts.at(i);
        }
    }

    function _checkUserLockedTokens(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) internal view returns (bool) {
        EnumerableMap.AddressToUintMap storage requiredTokenLock = tier
            .participationInfo
            .requiredTokenLock;
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[user]
            .purchaseInfo
            .lockedTokens;

        uint256 length = requiredTokenLock.length();

        for (uint256 i = 0; i < length; i++) {
            (address requiredToken, uint256 requiredAmount) = requiredTokenLock.at(i);

            (, uint256 lockedAmount) = lockedTokens.tryGet(requiredToken);

            if (lockedAmount < requiredAmount) {
                return false;
            }
        }

        return true;
    }

    function _checkUserLockedNfts(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) internal view returns (bool) {
        EnumerableMap.AddressToUintMap storage requiredNftLock = tier
            .participationInfo
            .requiredNftLock;
        mapping(address => EnumerableSet.UintSet) storage lockedNfts = tier
            .users[user]
            .purchaseInfo
            .lockedNfts;

        uint256 length = requiredNftLock.length();

        for (uint256 i = 0; i < length; i++) {
            (address requiredNft, uint256 requiredAmount) = requiredNftLock.at(i);

            if (lockedNfts[requiredNft].length() < requiredAmount) {
                return false;
            }
        }

        return true;
    }

    function _checkMerkleProofs(
        ITokenSaleProposal.Tier storage tier,
        bytes32[] calldata proof,
        address user
    ) internal view returns (bool) {
        bytes32 root = tier.tierAdditionalInfo.merkleRoot;

        if (root == bytes32(0)) {
            return false;
        }

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(user))));

        return proof.verifyCalldata(root, leaf);
    }
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalClaim.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";

library TokenSaleProposalClaim {
    using TokenBalance for IERC20;

    function claim(ITokenSaleProposal.Tier storage tier) external {
        uint256 claimAmount = getClaimAmount(tier, msg.sender);
        require(claimAmount > 0, "TSP: zero withdrawal");

        tier.users[msg.sender].purchaseInfo.isClaimed = true;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, claimAmount);
    }

    function getClaimAmount(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) public view returns (uint256) {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[user].purchaseInfo;
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;

        require(
            block.timestamp >= tierInitParams.saleEndTime + tierInitParams.claimLockDuration,
            "TSP: claim is locked"
        );

        return purchaseInfo.isClaimed ? 0 : purchaseInfo.claimTotalAmount;
    }
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalCreate.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../core/Globals.sol";

library TokenSaleProposalCreate {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using DecimalsConverter for *;

    function createTier(
        mapping(uint256 => ITokenSaleProposal.Tier) storage tiers,
        uint256 newTierId,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) external {
        _validateTierInitParams(_tierInitParams);

        ITokenSaleProposal.Tier storage tier = tiers[newTierId];

        _setParticipationInfo(tier, _tierInitParams.participationDetails);
        _setRates(tier, _tierInitParams);
        _setVestingParameters(tier, _tierInitParams);

        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        _setBasicParameters(tierInitParams, _tierInitParams);

        IERC20(tierInitParams.saleTokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _tierInitParams.totalTokenProvided.from18Safe(_tierInitParams.saleTokenAddress)
        );
    }

    function modifyTier(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams calldata newSettings
    ) external {
        require(
            block.timestamp < tier.tierInitParams.saleStartTime,
            "TSP: token sale already started"
        );
        require(
            newSettings.saleTokenAddress == tier.tierInitParams.saleTokenAddress,
            "TSP: can't change sale token"
        );

        ITokenSaleProposal.TierInitParams storage tierInitParams = tier.tierInitParams;

        _validateTierInitParams(newSettings);

        _clearTierData(tier);

        _setParticipationInfo(tier, newSettings.participationDetails);
        _setRates(tier, newSettings);
        _setVestingParameters(tier, newSettings);

        uint256 oldSupply = tierInitParams.totalTokenProvided;
        uint256 newSupply = newSettings.totalTokenProvided;

        _setBasicParameters(tierInitParams, newSettings);

        if (oldSupply < newSupply) {
            IERC20(newSettings.saleTokenAddress).safeTransferFrom(
                msg.sender,
                address(this),
                (newSupply - oldSupply).from18Safe(newSettings.saleTokenAddress)
            );
        } else if (oldSupply > newSupply) {
            IERC20(newSettings.saleTokenAddress).safeTransfer(
                msg.sender,
                (oldSupply - newSupply).from18Safe(newSettings.saleTokenAddress)
            );
        }
    }

    function changeParticipationDetails(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.ParticipationDetails[] calldata newSettings
    ) external {
        require(block.timestamp <= tier.tierInitParams.saleEndTime, "TSP: token sale is over");

        _clearParticipationData(tier);

        _setParticipationInfo(tier, newSettings);

        tier.tierAdditionalInfo.lastModified = _getBlockNumber();
    }

    function getTierViews(
        mapping(uint256 => ITokenSaleProposal.Tier) storage tiers,
        uint256 offset,
        uint256 limit
    ) external view returns (ITokenSaleProposal.TierView[] memory tierViews) {
        uint256 to = (offset + limit).min(TokenSaleProposal(address(this)).latestTierId()).max(
            offset
        );

        tierViews = new ITokenSaleProposal.TierView[](to - offset);

        for (uint256 i = offset; i < to; i++) {
            ITokenSaleProposal.Tier storage tier = tiers[i + 1];

            tierViews[i - offset] = ITokenSaleProposal.TierView({
                tierInitParams: tier.tierInitParams,
                tierInfo: tier.tierInfo,
                tierAdditionalInfo: tier.tierAdditionalInfo
            });
        }
    }

    function getParticipationDetails(
        ITokenSaleProposal.Tier storage tier
    )
        external
        view
        returns (ITokenSaleProposal.ParticipationInfoView memory participationDetails)
    {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier.tierAdditionalInfo;

        participationDetails.isWhitelisted = participationInfo.isWhitelisted;
        participationDetails.isBABTed = participationInfo.isBABTed;
        participationDetails.requiredDaoVotes = participationInfo.requiredDaoVotes;
        participationDetails.merkleRoot = additionalInfo.merkleRoot;
        participationDetails.merkleUri = additionalInfo.merkleUri;

        uint256 length = participationInfo.requiredTokenLock.length();

        address[] memory addresses = new address[](length);
        uint256[] memory amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (addresses[i], amounts[i]) = participationInfo.requiredTokenLock.at(i);
        }

        participationDetails.requiredTokenAddresses = addresses;
        participationDetails.requiredTokenAmounts = amounts;

        length = participationInfo.requiredNftLock.length();
        addresses = new address[](length);
        amounts = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            (addresses[i], amounts[i]) = participationInfo.requiredNftLock.at(i);
        }

        participationDetails.requiredNftAddresses = addresses;
        participationDetails.requiredNftAmounts = amounts;
    }

    function _setBasicParameters(
        ITokenSaleProposal.TierInitParams storage tierInitParams,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) private {
        tierInitParams.metadata = _tierInitParams.metadata;
        tierInitParams.totalTokenProvided = _tierInitParams.totalTokenProvided;
        tierInitParams.saleStartTime = _tierInitParams.saleStartTime;
        tierInitParams.saleEndTime = _tierInitParams.saleEndTime;
        tierInitParams.claimLockDuration = _tierInitParams.claimLockDuration;
        tierInitParams.saleTokenAddress = _tierInitParams.saleTokenAddress;
        tierInitParams.purchaseTokenAddresses = _tierInitParams.purchaseTokenAddresses;
        tierInitParams.exchangeRates = _tierInitParams.exchangeRates;
        tierInitParams.minAllocationPerUser = _tierInitParams.minAllocationPerUser;
        tierInitParams.maxAllocationPerUser = _tierInitParams.maxAllocationPerUser;
        tierInitParams.vestingSettings = _tierInitParams.vestingSettings;
    }

    function _setVestingParameters(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams memory _tierInitParams
    ) private {
        uint64 vestingStartTime = _tierInitParams.vestingSettings.vestingDuration == 0
            ? 0
            : _tierInitParams.saleEndTime + _tierInitParams.vestingSettings.cliffPeriod;
        tier.tierInfo.vestingTierInfo = ITokenSaleProposal.VestingTierInfo({
            vestingStartTime: vestingStartTime,
            vestingEndTime: vestingStartTime + _tierInitParams.vestingSettings.vestingDuration
        });
    }

    function _setParticipationInfo(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.ParticipationDetails[] memory participationSettings
    ) private {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;

        for (uint256 i = 0; i < participationSettings.length; i++) {
            ITokenSaleProposal.ParticipationDetails
                memory participationDetails = participationSettings[i];

            if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.DAOVotes
            ) {
                require(participationDetails.data.length == 32, "TSP: invalid DAO votes data");

                uint256 requiredDaoVotes = abi.decode(participationDetails.data, (uint256));

                require(requiredDaoVotes > 0, "TSP: zero DAO votes");
                require(
                    participationInfo.requiredDaoVotes == 0,
                    "TSP: multiple DAO votes requirements"
                );

                participationInfo.requiredDaoVotes = requiredDaoVotes;
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.Whitelist
            ) {
                require(participationDetails.data.length == 0, "TSP: invalid whitelist data");
                require(!participationInfo.isWhitelisted, "TSP: multiple whitelist requirements");

                participationInfo.isWhitelisted = true;
            } else if (
                participationDetails.participationType == ITokenSaleProposal.ParticipationType.BABT
            ) {
                require(participationDetails.data.length == 0, "TSP: invalid BABT data");
                require(!participationInfo.isBABTed, "TSP: multiple BABT requirements");

                participationInfo.isBABTed = true;
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.TokenLock
            ) {
                require(participationDetails.data.length == 64, "TSP: invalid token lock data");

                (address token, uint256 amount) = abi.decode(
                    participationDetails.data,
                    (address, uint256)
                );

                require(amount > 0, "TSP: zero token lock amount");
                require(
                    participationInfo.requiredTokenLock.set(token, amount),
                    "TSP: multiple token lock requirements"
                );
            } else if (
                participationDetails.participationType ==
                ITokenSaleProposal.ParticipationType.NftLock
            ) {
                require(participationDetails.data.length == 64, "TSP: invalid nft lock data");

                (address nft, uint256 amount) = abi.decode(
                    participationDetails.data,
                    (address, uint256)
                );

                require(amount > 0, "TSP: zero nft lock amount");
                require(
                    participationInfo.requiredNftLock.set(nft, amount),
                    "TSP: multiple nft lock requirements"
                );
            } else {
                /// @dev ITokenSaleProposal.ParticipationType.MerkleWhitelist
                require(
                    participationDetails.data.length >= 96,
                    "TSP: invalid Merkle Whitelist data"
                );

                ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier
                    .tierAdditionalInfo;

                require(
                    additionalInfo.merkleRoot == bytes32(0),
                    "TSP: multiple Merkle whitelist requirements"
                );

                (bytes32 merkleRoot, string memory merkleUri) = abi.decode(
                    participationDetails.data,
                    (bytes32, string)
                );

                require(merkleRoot != bytes32(0), "TSP: zero Merkle Root");

                additionalInfo.merkleRoot = merkleRoot;
                additionalInfo.merkleUri = merkleUri;
            }

            tier.tierInitParams.participationDetails.push(participationDetails);
        }
    }

    function _setRates(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.TierInitParams memory tierInitParams
    ) private {
        for (uint256 i = 0; i < tierInitParams.purchaseTokenAddresses.length; i++) {
            require(tierInitParams.exchangeRates[i] != 0, "TSP: rate cannot be zero");
            require(
                tierInitParams.purchaseTokenAddresses[i] != address(0),
                "TSP: purchase token cannot be zero"
            );
            require(
                tier.rates[tierInitParams.purchaseTokenAddresses[i]] == 0,
                "TSP: purchase tokens are duplicated"
            );

            tier.rates[tierInitParams.purchaseTokenAddresses[i]] = tierInitParams.exchangeRates[i];
        }
    }

    function _clearTierData(ITokenSaleProposal.Tier storage tier) private {
        for (uint256 i = 0; i < tier.tierInitParams.purchaseTokenAddresses.length; i++) {
            tier.rates[tier.tierInitParams.purchaseTokenAddresses[i]] = 0;
        }

        _clearParticipationData(tier);
    }

    function _clearParticipationData(ITokenSaleProposal.Tier storage tier) private {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        ITokenSaleProposal.TierAdditionalInfo storage additionalInfo = tier.tierAdditionalInfo;

        participationInfo.isWhitelisted = false;
        participationInfo.isBABTed = false;
        participationInfo.requiredDaoVotes = 0;
        _clearEnumerableMap(participationInfo.requiredTokenLock);
        _clearEnumerableMap(participationInfo.requiredNftLock);
        additionalInfo.merkleRoot = bytes32(0);
        additionalInfo.merkleUri = "";

        ITokenSaleProposal.ParticipationDetails[] storage participationDetails = tier
            .tierInitParams
            .participationDetails;
        assembly {
            sstore(participationDetails.slot, 0)
        }
    }

    function _validateTierInitParams(
        ITokenSaleProposal.TierInitParams memory tierInitParams
    ) private pure {
        require(tierInitParams.saleTokenAddress != address(0), "TSP: sale token cannot be zero");
        require(
            tierInitParams.saleTokenAddress != ETHEREUM_ADDRESS,
            "TSP: cannot sale native currency"
        );
        require(tierInitParams.totalTokenProvided != 0, "TSP: sale token is not provided");
        require(
            tierInitParams.saleStartTime <= tierInitParams.saleEndTime,
            "TSP: saleEndTime is less than saleStartTime"
        );
        require(
            tierInitParams.minAllocationPerUser <= tierInitParams.maxAllocationPerUser,
            "TSP: wrong allocation"
        );
        require(
            _validateVestingSettings(tierInitParams.vestingSettings),
            "TSP: vesting settings validation failed"
        );
        require(
            tierInitParams.claimLockDuration <= tierInitParams.vestingSettings.cliffPeriod,
            "TSP: claimLock > cliff"
        );
        require(
            tierInitParams.purchaseTokenAddresses.length != 0,
            "TSP: purchase tokens are not provided"
        );
        require(
            tierInitParams.purchaseTokenAddresses.length == tierInitParams.exchangeRates.length,
            "TSP: tokens and rates lengths mismatch"
        );
    }

    function _validateVestingSettings(
        ITokenSaleProposal.VestingSettings memory vestingSettings
    ) private pure returns (bool) {
        if (
            vestingSettings.vestingPercentage == 0 &&
            vestingSettings.vestingDuration == 0 &&
            vestingSettings.unlockStep == 0 &&
            vestingSettings.cliffPeriod == 0
        ) {
            return true;
        }

        return
            vestingSettings.vestingDuration != 0 &&
            vestingSettings.vestingPercentage != 0 &&
            vestingSettings.unlockStep != 0 &&
            vestingSettings.vestingPercentage <= PERCENTAGE_100 &&
            vestingSettings.vestingDuration >= vestingSettings.unlockStep;
    }

    function _clearEnumerableMap(EnumerableMap.AddressToUintMap storage map) internal {
        for (uint256 i = map.length(); i > 0; i--) {
            (address key, ) = map.at(i - 1);
            map.remove(key);
        }
    }

    function _getBlockNumber() internal view returns (uint256 block_) {
        return block.number;
    }
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalRecover.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";

library TokenSaleProposalRecover {
    using TokenBalance for IERC20;

    function recover(ITokenSaleProposal.Tier storage tier) external {
        uint256 recoveringAmount = getRecoverAmount(tier);
        require(recoveringAmount > 0, "TSP: zero recovery");

        tier.tierInfo.totalSold += recoveringAmount;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, recoveringAmount);
    }

    function getRecoverAmount(ITokenSaleProposal.Tier storage tier) public view returns (uint256) {
        ITokenSaleProposal.TierInitParams memory tierInitParams = tier.tierInitParams;
        ITokenSaleProposal.TierInfo memory tierInfo = tier.tierInfo;

        if (!tierInfo.isOff && block.timestamp <= tierInitParams.saleEndTime) {
            return 0;
        }

        return tierInitParams.totalTokenProvided - tierInfo.totalSold;
    }
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalVesting.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/math/Math.sol";

import "../../../interfaces/gov/proposals/ITokenSaleProposal.sol";

import "../../utils/TokenBalance.sol";
import "../../math/MathHelper.sol";

library TokenSaleProposalVesting {
    using Math for uint256;
    using MathHelper for uint256;
    using TokenBalance for IERC20;

    function vestingWithdraw(ITokenSaleProposal.Tier storage tier) external {
        uint256 vestingWithdrawAmount = getVestingWithdrawAmount(tier, msg.sender);
        require(vestingWithdrawAmount > 0, "TSP: zero withdrawal");

        ITokenSaleProposal.VestingUserInfo storage vestingUserInfo = tier
            .users[msg.sender]
            .vestingUserInfo;

        vestingUserInfo.latestVestingWithdraw = uint64(block.timestamp);
        vestingUserInfo.vestingWithdrawnAmount += vestingWithdrawAmount;

        IERC20(tier.tierInitParams.saleTokenAddress).sendFunds(msg.sender, vestingWithdrawAmount);
    }

    function getVestingWithdrawAmount(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) public view returns (uint256) {
        ITokenSaleProposal.VestingUserInfo memory vestingUserInfo = tier
            .users[user]
            .vestingUserInfo;

        return
            _countPrefixVestingAmount(
                block.timestamp,
                vestingUserInfo.vestingTotalAmount,
                tier.tierInfo.vestingTierInfo,
                tier.tierInitParams.vestingSettings
            ) - vestingUserInfo.vestingWithdrawnAmount;
    }

    function getVestingUserView(
        ITokenSaleProposal.Tier storage tier,
        address user
    ) external view returns (ITokenSaleProposal.VestingUserView memory vestingUserView) {
        ITokenSaleProposal.VestingUserInfo memory vestingUserInfo = tier
            .users[user]
            .vestingUserInfo;
        ITokenSaleProposal.VestingTierInfo memory vestingTierInfo = tier.tierInfo.vestingTierInfo;
        ITokenSaleProposal.VestingSettings memory vestingSettings = tier
            .tierInitParams
            .vestingSettings;

        vestingUserView.latestVestingWithdraw = vestingUserInfo.latestVestingWithdraw;
        vestingUserView.vestingTotalAmount = vestingUserInfo.vestingTotalAmount;
        vestingUserView.vestingWithdrawnAmount = vestingUserInfo.vestingWithdrawnAmount;

        if (block.timestamp < vestingTierInfo.vestingStartTime) {
            vestingUserView.nextUnlockTime =
                vestingTierInfo.vestingStartTime +
                vestingSettings.unlockStep;
        } else if (block.timestamp < vestingTierInfo.vestingEndTime) {
            vestingUserView.nextUnlockTime = uint64(block.timestamp) + vestingSettings.unlockStep;
            vestingUserView.nextUnlockTime -=
                (vestingUserView.nextUnlockTime - vestingTierInfo.vestingStartTime) %
                vestingSettings.unlockStep;
            vestingUserView.nextUnlockTime = uint64(
                uint256(vestingUserView.nextUnlockTime).min(vestingTierInfo.vestingEndTime)
            );
        }

        uint256 currentPrefixVestingAmount = _countPrefixVestingAmount(
            block.timestamp,
            vestingUserView.vestingTotalAmount,
            vestingTierInfo,
            vestingSettings
        );

        if (vestingUserView.nextUnlockTime != 0) {
            vestingUserView.nextUnlockAmount =
                _countPrefixVestingAmount(
                    vestingUserView.nextUnlockTime,
                    vestingUserView.vestingTotalAmount,
                    vestingTierInfo,
                    vestingSettings
                ) -
                currentPrefixVestingAmount;
        }

        vestingUserView.amountToWithdraw =
            currentPrefixVestingAmount -
            vestingUserView.vestingWithdrawnAmount;
        vestingUserView.lockedAmount =
            vestingUserView.vestingTotalAmount -
            currentPrefixVestingAmount;
    }

    function _countPrefixVestingAmount(
        uint256 timestamp,
        uint256 vestingTotalAmount,
        ITokenSaleProposal.VestingTierInfo memory vestingTierInfo,
        ITokenSaleProposal.VestingSettings memory vestingSettings
    ) private pure returns (uint256) {
        if (timestamp < vestingTierInfo.vestingStartTime) {
            return 0;
        }

        if (timestamp >= vestingTierInfo.vestingEndTime) {
            return vestingTotalAmount;
        }

        uint256 beforeLastSegmentAmount = vestingTotalAmount.ratio(
            vestingSettings.vestingDuration -
                (vestingSettings.vestingDuration % vestingSettings.unlockStep),
            vestingSettings.vestingDuration
        );
        uint256 segmentsTotal = vestingSettings.vestingDuration / vestingSettings.unlockStep;
        uint256 segmentsBefore = (timestamp - vestingTierInfo.vestingStartTime) /
            vestingSettings.unlockStep;

        return beforeLastSegmentAmount.ratio(segmentsBefore, segmentsTotal);
    }
}


// File: contracts/libs/gov/token-sale-proposal/TokenSaleProposalWhitelist.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";
import "@solarity/solidity-lib/libs/arrays/SetHelper.sol";

import "../../../gov/proposals/TokenSaleProposal.sol";

import "../../../libs/utils/TokenBalance.sol";
import "./TokenSaleProposalBuy.sol";

library TokenSaleProposalWhitelist {
    using TokenSaleProposalBuy for ITokenSaleProposal.Tier;
    using TokenBalance for address;
    using DecimalsConverter for *;
    using SetHelper for EnumerableSet.UintSet;
    using SafeERC20 for IERC20;
    using EnumerableSet for *;
    using EnumerableMap for EnumerableMap.AddressToUintMap;

    function lockParticipationTokens(
        ITokenSaleProposal.Tier storage tier,
        address tokenToLock,
        uint256 amountToLock
    ) external {
        ITokenSaleProposal.ParticipationInfo storage participationInfo = tier.participationInfo;
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[msg.sender]
            .purchaseInfo
            .lockedTokens;

        require(amountToLock > 0, "TSP: zero amount to lock");

        (, uint256 lockedAmount) = lockedTokens.tryGet(tokenToLock);
        (, uint256 requiredAmount) = participationInfo.requiredTokenLock.tryGet(tokenToLock);

        uint256 newLockedAmount = lockedAmount + amountToLock;

        require(newLockedAmount <= requiredAmount, "TSP: token overlock");

        lockedTokens.set(tokenToLock, newLockedAmount);

        if (tokenToLock != ETHEREUM_ADDRESS) {
            require(msg.value == 0, "TSP: wrong native lock amount");

            IERC20(tokenToLock).safeTransferFrom(
                msg.sender,
                address(this),
                amountToLock.from18Safe(tokenToLock)
            );
        } else {
            require(msg.value == amountToLock, "TSP: wrong lock amount");
        }
    }

    function lockParticipationNft(
        ITokenSaleProposal.Tier storage tier,
        address nftToLock,
        uint256[] calldata nftIdsToLock
    ) external {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[msg.sender].purchaseInfo;
        EnumerableSet.UintSet storage lockedNfts = purchaseInfo.lockedNfts[nftToLock];

        require(nftIdsToLock.length > 0, "TSP: zero nft ids to lock");

        purchaseInfo.lockedNftAddresses.add(nftToLock);

        for (uint256 i = 0; i < nftIdsToLock.length; i++) {
            require(lockedNfts.add(nftIdsToLock[i]), "TSP: lock nfts are duplicated");
        }

        (, uint256 requiredAmount) = tier.participationInfo.requiredNftLock.tryGet(nftToLock);

        require(lockedNfts.length() <= requiredAmount, "TSP: nft overlock");

        for (uint256 i = 0; i < nftIdsToLock.length; i++) {
            IERC721(nftToLock).safeTransferFrom(msg.sender, address(this), nftIdsToLock[i]);
        }
    }

    function unlockParticipationTokens(
        ITokenSaleProposal.Tier storage tier,
        address tokenToUnlock,
        uint256 amountToUnlock
    ) external {
        EnumerableMap.AddressToUintMap storage lockedTokens = tier
            .users[msg.sender]
            .purchaseInfo
            .lockedTokens;
        EnumerableMap.AddressToUintMap storage requiredTokenLock = tier
            .participationInfo
            .requiredTokenLock;

        (, uint256 lockedAmount) = lockedTokens.tryGet(tokenToUnlock);
        (, uint256 requiredAmount) = requiredTokenLock.tryGet(tokenToUnlock);
        uint256 overlock = lockedAmount < requiredAmount ? 0 : lockedAmount - requiredAmount;

        require(
            block.timestamp >= tier.tierInitParams.saleEndTime ||
                (!tier._checkUserLockedTokens(msg.sender) &&
                    _getBlockNumber() != tier.tierAdditionalInfo.lastModified) ||
                overlock >= amountToUnlock,
            "TSP: unlock unavailable"
        );

        require(amountToUnlock > 0, "TSP: zero amount to unlock");

        require(amountToUnlock <= lockedAmount, "TSP: unlock exceeds lock");

        if (amountToUnlock == lockedAmount) {
            lockedTokens.remove(tokenToUnlock);
        } else {
            lockedTokens.set(tokenToUnlock, lockedAmount - amountToUnlock);
        }

        tokenToUnlock.sendFunds(msg.sender, amountToUnlock);
    }

    function unlockParticipationNft(
        ITokenSaleProposal.Tier storage tier,
        address nftToUnlock,
        uint256[] calldata nftIdsToUnlock
    ) external {
        ITokenSaleProposal.PurchaseInfo storage purchaseInfo = tier.users[msg.sender].purchaseInfo;
        EnumerableSet.UintSet storage lockedNfts = purchaseInfo.lockedNfts[nftToUnlock];
        EnumerableMap.AddressToUintMap storage requiredNftLock = tier
            .participationInfo
            .requiredNftLock;

        (, uint256 requiredAmount) = requiredNftLock.tryGet(nftToUnlock);
        uint256 lockedAmount = lockedNfts.length();
        uint256 overlock = lockedAmount < requiredAmount ? 0 : lockedAmount - requiredAmount;

        require(
            block.timestamp >= tier.tierInitParams.saleEndTime ||
                (!tier._checkUserLockedNfts(msg.sender) &&
                    _getBlockNumber() != tier.tierAdditionalInfo.lastModified) ||
                overlock >= nftIdsToUnlock.length,
            "TSP: unlock unavailable"
        );

        require(nftIdsToUnlock.length > 0, "TSP: zero nft ids to unlock");

        for (uint256 i = 0; i < nftIdsToUnlock.length; i++) {
            require(lockedNfts.remove(nftIdsToUnlock[i]), "TSP: nft is not locked");
        }

        if (lockedNfts.length() == 0) {
            purchaseInfo.lockedNftAddresses.remove(nftToUnlock);
        }

        for (uint256 i = 0; i < nftIdsToUnlock.length; i++) {
            IERC721(nftToUnlock).safeTransferFrom(address(this), msg.sender, nftIdsToUnlock[i]);
        }
    }

    function addToWhitelist(
        ITokenSaleProposal.Tier storage tier,
        ITokenSaleProposal.WhitelistingRequest calldata request
    ) external {
        require(tier.participationInfo.isWhitelisted, "TSP: tier is not whitelisted");

        tier.tierInfo.uri = request.uri;

        for (uint256 i = 0; i < request.users.length; i++) {
            TokenSaleProposal(address(this)).mint(request.users[i], request.tierId);
        }
    }

    function _getBlockNumber() internal view returns (uint256 block_) {
        return block.number;
    }
}


// File: contracts/libs/math/MathHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../core/Globals.sol";

library MathHelper {
    /// @notice percent has to be multiplied by PRECISION
    function percentage(uint256 num, uint256 percent) internal pure returns (uint256) {
        return (num * percent) / PERCENTAGE_100;
    }

    function ratio(uint256 base, uint256 num, uint256 denom) internal pure returns (uint256) {
        return (base * num) / denom;
    }

    function ratio(int256 base, int256 num, int256 denom) internal pure returns (int256) {
        return (base * num) / denom;
    }
}


// File: contracts/libs/utils/TokenBalance.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "@solarity/solidity-lib/libs/utils/DecimalsConverter.sol";

import "../../core/Globals.sol";

import "../../interfaces/gov/ERC20/IERC20Gov.sol";

library TokenBalance {
    using DecimalsConverter for *;
    using SafeERC20 for IERC20;
    using Math for uint256;

    enum TransferType {
        Revert,
        TryMint
    }

    function sendFunds(
        address token,
        address receiver,
        uint256 amount,
        TransferType transferType
    ) internal returns (uint256) {
        if (amount == 0) {
            return 0;
        }

        uint256 balance = normThisBalance(token);

        require(balance >= amount || transferType == TransferType.TryMint, "Insufficient funds");

        if (token == ETHEREUM_ADDRESS) {
            amount = amount.min(balance);

            if (amount > 0) {
                (bool status, ) = payable(receiver).call{value: amount}("");
                require(status, "Failed to send eth");
            }
        } else {
            if (balance < amount) {
                try
                    IERC20Gov(token).mint(address(this), (amount - balance).from18(token))
                {} catch {}

                amount = normThisBalance(token).min(amount);
            }

            uint256 amountWithDecimals = amount.from18(token);

            if (amountWithDecimals > 0) {
                IERC20(token).safeTransfer(receiver, amountWithDecimals);
            }
        }

        return amount;
    }

    function sendFunds(address token, address receiver, uint256 amount) internal {
        sendFunds(token, receiver, amount, TransferType.Revert);
    }

    function sendFunds(IERC20 token, address receiver, uint256 amount) internal {
        token.safeTransfer(receiver, amount.from18Safe(address(token)));
    }

    function thisBalance(address token) internal view returns (uint256) {
        return
            token == ETHEREUM_ADDRESS
                ? address(this).balance
                : IERC20(token).balanceOf(address(this));
    }

    function normThisBalance(address token) internal view returns (uint256) {
        return token == ETHEREUM_ADDRESS ? thisBalance(token) : thisBalance(token).to18(token);
    }
}


// File: contracts/libs/utils/TypeHelper.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../../interfaces/gov/IGovPool.sol";

library TypeHelper {
    function asSingletonArray(
        IGovPool.VoteType element
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](1);
        arr[0] = element;
    }

    function asDynamic(
        IGovPool.VoteType[2] memory elements
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](2);
        arr[0] = elements[0];
        arr[1] = elements[1];
    }

    function asDynamic(
        IGovPool.VoteType[3] memory elements
    ) internal pure returns (IGovPool.VoteType[] memory arr) {
        arr = new IGovPool.VoteType[](3);
        arr[0] = elements[0];
        arr[1] = elements[1];
        arr[2] = elements[2];
    }
}


