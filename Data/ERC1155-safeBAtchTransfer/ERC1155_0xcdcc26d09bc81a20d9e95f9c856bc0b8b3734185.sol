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


// File: @openzeppelin/contracts/token/ERC1155/ERC1155.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (token/ERC1155/ERC1155.sol)

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
    function balanceOfBatch(address[] memory accounts, uint256[] memory ids)
        public
        view
        virtual
        override
        returns (uint256[] memory)
    {
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
    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal virtual {
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
    function _burn(
        address from,
        uint256 id,
        uint256 amount
    ) internal virtual {
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
    function _burnBatch(
        address from,
        uint256[] memory ids,
        uint256[] memory amounts
    ) internal virtual {
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
    function _setApprovalForAll(
        address owner,
        address operator,
        bool approved
    ) internal virtual {
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
// OpenZeppelin Contracts (last updated v4.7.0) (token/ERC1155/IERC1155.sol)

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
     * - If the caller is not `from`, it must have been approved to spend ``from``'s tokens via {setApprovalForAll}.
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


// File: @openzeppelin/contracts/utils/Address.sol
// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v4.8.0) (utils/Address.sol)

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


// File: contracts/interfaces/IAccessManager.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import {IAddressesRegistry} from "./IAddressesRegistry.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IAccessManager
 * @author Souq.Finance
 * @notice The interface for the Access Manager Contract
 * @notice License: https://souq-peripheral-v1.s3.amazonaws.com/LICENSE.md
 */
interface IAccessManager is IAccessControl {
    
    /**
     * @notice Returns the contract address of the PoolAddressesProvider
     * @return The address of the PoolAddressesProvider
     */
    function ADDRESSES_PROVIDER() external view returns (IAddressesRegistry);

    /**
     * @notice Returns the identifier of the Pool Operations role
     * @return The id of the Pool Operations role
     */
    function POOL_OPERATIONS_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the PoolAdmin role
     * @return The id of the PoolAdmin role
     */
    function POOL_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the EmergencyAdmin role
     * @return The id of the EmergencyAdmin role
     */
    function EMERGENCY_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the OracleAdmin role
     * @return The id of the Oracle role
     */
    function ORACLE_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the ConnectorRouterAdmin role
     * @return The id of the ConnectorRouterAdmin role
     */
    function CONNECTOR_ROUTER_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the StablecoinYieldConnectorAdmin role
     * @return The id of the StablecoinYieldConnectorAdmin role
     */
    function STABLECOIN_YIELD_CONNECTOR_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the StablecoinYieldConnectorLender role
     * @return The id of the StablecoinYieldConnectorLender role
     */
    function STABLECOIN_YIELD_CONNECTOR_LENDER_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the UpgraderAdmin role
     * @return The id of the UpgraderAdmin role
     */

    function UPGRADER_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Returns the identifier of the TimelockAdmin role
     * @return The id of the TimelockAdmin role
     */

    function TIMELOCK_ADMIN_ROLE() external view returns (bytes32);

    /**
     * @dev set the default admin for the contract
     * @param newAdmin The new default admin address
     */
    function changeDefaultAdmin(address newAdmin) external;
    
    /**
     * @dev return the version of the contract
     * @return the version of the contract
     */
    function getVersion() external pure returns (uint256);
    /**
     * @notice Set the role as admin of a specific role.
     * @dev By default the admin role for all roles is `DEFAULT_ADMIN_ROLE`.
     * @param role The role to be managed by the admin role
     * @param adminRole The admin role
     */

    function setRoleAdmin(bytes32 role, bytes32 adminRole) external;

    /**
     * @notice Adds a new admin as PoolAdmin
     * @param admin The address of the new admin
     */
    function addPoolAdmin(address admin) external;

    /**
     * @notice Removes an admin as PoolAdmin
     * @param admin The address of the admin to remove
     */
    function removePoolAdmin(address admin) external;

    /**
     * @notice Returns true if the address is PoolAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is PoolAdmin, false otherwise
     */
    function isPoolAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as Pool Operations
     * @param admin The address of the new admin
     */
    function addPoolOperations(address admin) external;

    /**
     * @notice Removes an admin as Pool Operations
     * @param admin The address of the admin to remove
     */
    function removePoolOperations(address admin) external;

    /**
     * @notice Returns true if the address is Pool Operations, false otherwise
     * @param admin The address to check
     * @return True if the given address is Pool Operations, false otherwise
     */
    function isPoolOperations(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as EmergencyAdmin
     * @param admin The address of the new admin
     */
    function addEmergencyAdmin(address admin) external;

    /**
     * @notice Removes an admin as EmergencyAdmin
     * @param admin The address of the admin to remove
     */
    function removeEmergencyAdmin(address admin) external;

    /**
     * @notice Returns true if the address is EmergencyAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is EmergencyAdmin, false otherwise
     */
    function isEmergencyAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as OracleAdmin
     * @param admin The address of the new admin
     */
    function addOracleAdmin(address admin) external;

    /**
     * @notice Removes an admin as OracleAdmin
     * @param admin The address of the admin to remove
     */
    function removeOracleAdmin(address admin) external;

    /**
     * @notice Returns true if the address is OracleAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is OracleAdmin, false otherwise
     */
    function isOracleAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as ConnectorRouterAdmin
     * @param admin The address of the new admin
     */
    function addConnectorAdmin(address admin) external;

    /**
     * @notice Removes an admin as ConnectorRouterAdmin
     * @param admin The address of the admin to remove
     */
    function removeConnectorAdmin(address admin) external;

    /**
     * @notice Returns true if the address is ConnectorRouterAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is ConnectorRouterAdmin, false otherwise
     */
    function isConnectorAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as StablecoinYieldConnectorAdmin
     * @param admin The address of the new admin
     */
    function addStablecoinYieldAdmin(address admin) external;

    /**
     * @notice Removes an admin as StablecoinYieldConnectorAdmin
     * @param admin The address of the admin to remove
     */
    function removeStablecoinYieldAdmin(address admin) external;

    /**
     * @notice Returns true if the address is StablecoinYieldConnectorAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is StablecoinYieldConnectorAdmin, false otherwise
     */
    function isStablecoinYieldAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as StablecoinYieldLender
     * @param lender The address of the new lender
     */
    function addStablecoinYieldLender(address lender) external;

    /**
     * @notice Removes an lender as StablecoinYieldLender
     * @param lender The address of the lender to remove
     */
    function removeStablecoinYieldLender(address lender) external;

    /**
     * @notice Returns true if the address is StablecoinYieldLender, false otherwise
     * @param lender The address to check
     * @return True if the given address is StablecoinYieldLender, false otherwise
     */
    function isStablecoinYieldLender(address lender) external view returns (bool);

    /**
     * @notice Adds a new admin as UpgraderAdmin
     * @param admin The address of the new admin
     */
    function addUpgraderAdmin(address admin) external;

    /**
     * @notice Removes an admin as UpgraderAdmin
     * @param admin The address of the admin to remove
     */
    function removeUpgraderAdmin(address admin) external;

    /**
     * @notice Returns true if the address is UpgraderAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is UpgraderAdmin, false otherwise
     */
    function isUpgraderAdmin(address admin) external view returns (bool);

    /**
     * @notice Adds a new admin as TimelockAdmin
     * @param admin The address of the new admin
     */
    function addTimelockAdmin(address admin) external;

    /**
     * @notice Removes an admin as TimelockAdmin
     * @param admin The address of the admin to remove
     */
    function removeTimelockAdmin(address admin) external;

    /**
     * @notice Returns true if the address is TimelockAdmin, false otherwise
     * @param admin The address to check
     * @return True if the given address is TimelockAdmin, false otherwise
     */
    function isTimelockAdmin(address admin) external view returns (bool);
}


// File: contracts/interfaces/IAccessNFT.sol
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

/**
 * @title IAccessNFT
 * @author Souq.Finance
 * @notice Defines the interface of the Access NFT contract
 * @notice License: https://souq-peripheral-v1.s3.amazonaws.com/LICENSE.md
 */
interface IAccessNFT {
    /**
     * @dev Event emitted wjem deadline for the function name and token id combination is set
     * @param functionName The function name in bytes32
     * @param deadline The deadline is seconds
     * @param tokenId The token id
     */
    event DeadlineSet(string functionName, bytes32 functionHash, uint256 deadline, uint256 tokenId);

    /**
     * @dev event emitted when the use of deadlines in the contract is toggled
     * @param deadlinesOn The flag returned (true=turned on)
     */
    event ToggleDeadlines(bool deadlinesOn);

    /**
     * @dev Checks if a user has access to a specific function based on ownership of NFTs. If current time > deadline of the function and token id combination
     * @param user The address of the user
     * @param tokenId The token id
     * @param functionName The function name
     * @return bool The boolean (true = has nft)
     */
    function HasAccessNFT(address user, uint256 tokenId, string calldata functionName) external view returns (bool);
    /**
     * @dev Sets the deadline for a specific function and token id (NFT)
     * @param functionName The function name
     * @param deadline The new deadline
     * @param tokenId The token id
     */
    function setDeadline(string calldata functionName, uint256 deadline, uint256 tokenId) external;
    /**
     * @dev Retrieves the deadline for a specific function and NFT.
     * @param hashedFunctionName The hashed function name
     * @param tokenId The token id
     * @return deadline The deadline
     */
    function getDeadline(bytes32 hashedFunctionName, uint256 tokenId) external view returns (uint256);
    /**
     * @dev Toggles the state of deadlines for function access.
     */
    function toggleDeadlines() external;
    /**
     * @dev Sets the fee discount percentage for a specific NFT
     * @param tokenId The token id
     * @param discount The discount in wei
     */
    function setFeeDiscount(uint256 tokenId, uint256 discount) external;
    /**
     * @dev Sets the URI for the token metadata
     * @param newuri The token id
     */
    function setURI(string memory newuri) external;
    /**
     * @dev Burns a specific amount of tokens owned by an account
     * @param account The account to burn from
     * @param id The token id
     * @param amount The amount to burn
     */
    function adminBurn(address account, uint256 id, uint256 amount) external;
}


// File: contracts/interfaces/IAddressesRegistry.sol
// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.10;

/**
 * @title IAddressesRegistry
 * @author Souq.Finance
 * @notice Defines the interface of the addresses registry.
 * @notice License: https://souq-peripheral-v1.s3.amazonaws.com/LICENSE.md
 */
 
interface IAddressesRegistry {
    /**
     * @dev Emitted when the connectors router address is updated.
     * @param oldAddress The old address
     * @param newAddress The new address
     */
    event RouterUpdated(address indexed oldAddress, address indexed newAddress);
    /**
     * @dev Emitted when the Access manager address is updated.
     * @param oldAddress The old address
     * @param newAddress The new address
     */
    event AccessManagerUpdated(address indexed oldAddress, address indexed newAddress);
    /**
     * @dev Emitted when the access admin address is updated.
     * @param oldAddress The old address
     * @param newAddress The new address
     */
    event AccessAdminUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when the collection connector address is updated.
     * @param oldAddress the old address
     * @param newAddress the new address
     */
    event CollectionConnectorUpdated(address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when a specific pool factory address is updated.
     * @param id The short id of the pool factory.
     * @param oldAddress The old address
     * @param newAddress The new address
     */

    event PoolFactoryUpdated(bytes32 id, address indexed oldAddress, address indexed newAddress);
    /**
     * @dev Emitted when a specific pool factory address is added.
     * @param id The short id of the pool factory.
     * @param newAddress The new address
     */
    event PoolFactoryAdded(bytes32 id, address indexed newAddress);
    /**
     * @dev Emitted when a specific vault factory address is updated.
     * @param id The short id of the vault factory.
     * @param oldAddress The old address
     * @param newAddress The new address
     */
    event VaultFactoryUpdated(bytes32 id, address indexed oldAddress, address indexed newAddress);
    /**
     * @dev Emitted when a specific vault factory address is added.
     * @param id The short id of the vault factory.
     * @param newAddress The new address
     */
    event VaultFactoryAdded(bytes32 id, address indexed newAddress);
    /**
     * @dev Emitted when a any address is updated.
     * @param id The full id of the address.
     * @param oldAddress The old address
     * @param newAddress The new address
     */
    event AddressUpdated(bytes32 id, address indexed oldAddress, address indexed newAddress);

    /**
     * @dev Emitted when a proxy is deployed for an implementation
     * @param id The full id of the address to be saved
     * @param logic The address of the implementation
     * @param proxy The address of the proxy deployed in that id slot
     */
    event ProxyDeployed(bytes32 id, address indexed logic, address indexed proxy);

    /**
     * @dev Emitted when a proxy is deployed for an implementation
     * @param id The full id of the address to be upgraded
     * @param newLogic The address of the new implementation
     * @param proxy The address of the proxy that was upgraded
     */
    event ProxyUpgraded(bytes32 id, address indexed newLogic, address indexed proxy);

    /**
     * @notice Returns the address of the identifier.
     * @param _id The id of the contract
     * @return The Pool proxy address
     */
    function getAddress(bytes32 _id) external view returns (address);

    /**
     * @notice Sets the address of the identifier.
     * @param _id The id of the contract
     * @param _add The address to set
     */
    function setAddress(bytes32 _id, address _add) external;

    /**
     * @notice Returns the address of the connectors router defined as: CONNECTORS_ROUTER
     * @return The address
     */
    function getConnectorsRouter() external view returns (address);

    /**
     * @notice Sets the address of the Connectors router.
     * @param _add The address to set
     */
    function setConnectorsRouter(address _add) external;

    /**
     * @notice Returns the address of access manager defined as: ACCESS_MANAGER
     * @return The address
     */
    function getAccessManager() external view returns (address);

    /**
     * @notice Sets the address of the Access Manager.
     * @param _add The address to set
     */
    function setAccessManager(address _add) external;

    /**
     * @notice Returns the address of access admin defined as: ACCESS_ADMIN
     * @return The address
     */
    function getAccessAdmin() external view returns (address);

    /**
     * @notice Sets the address of the Access Admin.
     * @param _add The address to set
     */
    function setAccessAdmin(address _add) external;

    /**
     * @notice Returns the address of the specific pool factory short id
     * @param _id The pool factory id such as "SVS"
     * @return The address
     */
    function getPoolFactoryAddress(bytes32 _id) external view returns (address);

    /**
     * @notice Returns the full id of pool factory short id
     * @param _id The pool factory id such as "SVS"
     * @return The full id
     */
    function getIdFromPoolFactory(bytes32 _id) external view returns (bytes32);

    /**
     * @notice Sets the address of a specific pool factory using short id.
     * @param _id the pool factory short id
     * @param _add The address to set
     */
    function setPoolFactory(bytes32 _id, address _add) external;

    /**
     * @notice adds a new pool factory with address and short id. The short id will be converted to full id and saved.
     * @param _id the pool factory short id
     * @param _add The address to add
     */
    function addPoolFactory(bytes32 _id, address _add) external;

    /**
     * @notice Returns the address of the specific vault factory short id
     * @param _id The vault id such as "SVS"
     * @return The address
     */
    function getVaultFactoryAddress(bytes32 _id) external view returns (address);

    /**
     * @notice Returns the full id of vault factory id
     * @param _id The vault factory id such as "SVS"
     * @return The full id
     */
    function getIdFromVaultFactory(bytes32 _id) external view returns (bytes32);

    /**
     * @notice Sets the address of a specific vault factory using short id.
     * @param _id the vault factory short id
     * @param _add The address to set
     */
    function setVaultFactory(bytes32 _id, address _add) external;

    /**
     * @notice adds a new vault factory with address and short id. The short id will be converted to full id and saved.
     * @param _id the vault factory short id
     * @param _add The address to add
     */
    function addVaultFactory(bytes32 _id, address _add) external;

    /**
     * @notice Deploys a proxy for an implimentation and initializes then saves in the registry.
     * @param _id the full id to be saved.
     * @param _logic The address of the implementation
     * @param _data The initialization low data
     */
    function updateImplementation(bytes32 _id, address _logic, bytes memory _data) external;

    /**
     * @notice Updates a proxy with a new implementation logic while keeping the store intact.
     * @param _id the full id to be saved.
     * @param _logic The address of the new implementation
     */
    function updateProxy(bytes32 _id, address _logic) external;
}


// File: contracts/libraries/Errors.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

/**
 * @title library for Errors mapping
 * @author Souq
 * @notice Defines the output of error messages reverted by the contracts of the Souq protocol
 * @notice License: https://souq-peripheral-v1.s3.amazonaws.com/LICENSE.md
 */
library Errors {
    string public constant ADDRESS_IS_ZERO = "ADDRESS_IS_ZERO";
    string public constant NOT_ENOUGH_USER_BALANCE = "NOT_ENOUGH_USER_BALANCE";
    string public constant NOT_ENOUGH_APPROVED = "NOT_ENOUGH_APPROVED";
    string public constant INVALID_AMOUNT = "INVALID_AMOUNT";
    string public constant AMM_PAUSED = "AMM_PAUSED";
    string public constant VAULT_PAUSED = "VAULT_PAUSED";
    string public constant FLASHLOAN_DISABLED = "FLASHLOAN_DISABLED";
    string public constant ADDRESSES_REGISTRY_NOT_SET = "ADDRESSES_REGISTRY_NOT_SET";
    string public constant UPGRADEABILITY_DISABLED = "UPGRADEABILITY_DISABLED";
    string public constant CALLER_NOT_UPGRADER = "CALLER_NOT_UPGRADER";
    string public constant CALLER_NOT_POOL_ADMIN = "CALLER_NOT_POOL_ADMIN";
    string public constant CALLER_NOT_ACCESS_ADMIN = "CALLER_NOT_ACCESS_ADMIN";
    string public constant CALLER_NOT_POOL_ADMIN_OR_OPERATIONS = "CALLER_NOT_POOL_ADMIN_OR_OPERATIONS";
    string public constant CALLER_NOT_ORACLE_ADMIN = "CALLER_NOT_ORACLE_ADMIN";
    string public constant CALLER_NOT_TIMELOCK="CALLER_NOT_TIMELOCK";
    string public constant CALLER_NOT_TIMELOCK_ADMIN="CALLER_NOT_TIMELOCK_ADMIN";
    string public constant ADDRESS_IS_PROXY = "ADDRESS_IS_PROXY";
    string public constant ARRAY_NOT_SAME_LENGTH = "ARRAY_NOT_SAME_LENGTH";
    string public constant NO_SUB_POOL_AVAILABLE = "NO_SUB_POOL_AVAILABLE";
    string public constant LIQUIDITY_MODE_RESTRICTED = "LIQUIDITY_MODE_RESTRICTED";
    string public constant TVL_LIMIT_REACHED = "TVL_LIMIT_REACHED";
    string public constant CALLER_MUST_BE_POOL = "CALLER_MUST_BE_POOL";
    string public constant CANNOT_RESCUE_POOL_TOKEN = "CANNOT_RESCUE_POOL_TOKEN";
    string public constant CALLER_MUST_BE_STABLEYIELD_ADMIN = "CALLER_MUST_BE_STABLEYIELD_ADMIN";
    string public constant CALLER_MUST_BE_STABLEYIELD_LENDER = "CALLER_MUST_BE_STABLEYIELD_LENDER";
    string public constant FUNCTION_REQUIRES_ACCESS_NFT = "FUNCTION_REQUIRES_ACCESS_NFT";
    string public constant FEE_OUT_OF_BOUNDS = "FEE_OUT_OF_BOUNDS";
    string public constant ONLY_ADMIN_CAN_ADD_LIQUIDITY = "ONLY_ADMIN_CAN_ADD_LIQUIDITY";
    string public constant NOT_ENOUGH_POOL_RESERVE = "NOT_ENOUGH_POOL_RESERVE";
    string public constant NOT_ENOUGH_SUBPOOL_RESERVE = "NOT_ENOUGH_SUBPOOL_RESERVE";
    string public constant NOT_ENOUGH_SUBPOOL_SHARES = "NOT_ENOUGH_SUBPOOL_SHARES";
    string public constant SUBPOOL_DISABLED = "SUBPOOL_DISABLED";
    string public constant ADDRESS_NOT_CONNECTOR_ADMIN = "ADDRESS_NOT_CONNECTOR_ADMIN";
    string public constant WITHDRAW_LIMIT_REACHED = "WITHDRAW_LIMIT_REACHED";
    string public constant DEPOSIT_LIMIT_REACHED = "DEPOSIT_LIMIT_REACHED";
    string public constant SHARES_VALUE_EXCEEDS_TARGET = "SHARES_VALUE_EXCEEDS_TARGET";
    string public constant SHARES_VALUE_BELOW_TARGET = "SHARES_VALUE_BELOW_TARGET";
    string public constant SHARES_TARGET_EXCEEDS_RESERVE = "SHARES_TARGET_EXCEEDS_RESERVE";
    string public constant SWAPPING_SHARES_TEMPORARY_DISABLED_DUE_TO_LOW_CONDITIONS =
        "SWAPPING_SHARES_TEMPORARY_DISABLED_DUE_TO_LOW_CONDITIONS";
    string public constant ADDING_SHARES_TEMPORARY_DISABLED_DUE_TO_LOW_CONDITIONS =
        "ADDING_SHARES_TEMPORARY_DISABLED_DUE_TO_LOW_CONDITIONS";
    string public constant UPGRADE_DISABLED = "UPGRADE_DISABLED";
    string public constant USER_CANNOT_BE_CONTRACT = "USER_CANNOT_BE_CONTRACT";
    string public constant DEADLINE_NOT_FOUND = "DEADLINE_NOT_FOUND";
    string public constant FLASHLOAN_PROTECTION_ENABLED = "FLASHLOAN_PROTECTION_ENABLED";
    string public constant INVALID_POOL_ADDRESS = "INVALID_POOL_ADDRESS";
    string public constant INVALID_SUBPOOL_ID = "INVALID_SUBPOOL_ID";
    string public constant INVALID_YIELD_DISTRIBUTOR_ADDRESS="INVALID_YIELD_DISTRIBUTOR_ADDRESS";
    string public constant YIELD_DISTRIBUTOR_NOT_FOUND="YIELD_DISTRIBUTOR_NOT_FOUND";
    string public constant INVALID_TOKEN_ID="INVALID_TOKEN_ID";
    string public constant INVALID_VAULT_ADDRESS = "INVALID_VAULT_ADDRESS";
    string public constant VAULT_NOT_FOUND="VAULT_NOT_FOUND";
    string public constant INVALID_TOKEN_ADDRESS="INVALID_TOKEN_ADDRESS";
    string public constant INVALID_STAKING_CONTRACT="INVALID_STAKING_CONTRACT";
    string public constant STAKING_CONTRACT_NOT_FOUND="STAKING_CONTRACT_NOT_FOUND";
    string public constant INVALID_SWAP_CONTRACT="INVALID_SWAP_CONTRACT";
    string public constant SWAP_CONTRACT_NOT_FOUND="SWAP_CONTRACT_NOT_FOUND";
    string public constant INVALID_ORACLE_CONNECTOR="INVALID_ORACLE_CONNECTOR";
    string public constant ORACLE_CONNECTOR_NOT_FOUND="ORACLE_CONNECTOR_NOT_FOUND";
    string public constant INVALID_COLLECTION_CONTRACT="INVALID_COLLECTION_CONTRACT";
    string public constant COLLECTION_CONTRACT_NOT_FOUND="COLLECTION_CONTRACT_NOT_FOUND";
    string public constant INVALID_STABLECOIN_YIELD_CONNECTOR="INVALID_STABLECOIN_YIELD_CONNECTOR";
    string public constant STABLECOIN_YIELD_CONNECTOR_NOT_FOUND="STABLECOIN_YIELD_CONNECTOR_NOT_FOUND";
    string public constant TIMELOCK_USES_ACCESS_CONTROL="TIMELOCK_USES_ACCESS_CONTROL";
}


// File: contracts/peripherals/AccessNFT.sol
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "../interfaces/IAccessManager.sol";
import "../interfaces/IAddressesRegistry.sol";
import "../libraries/Errors.sol";
import {IAccessNFT} from "../interfaces/IAccessNFT.sol";

/**
 * @title AccessNFT
 * @author Souq.Finance
 * @notice The ERC1155 Access NFT Contract that enables users to interact with the Pool at approved times and get discounts if set
 * @notice License: https://souq-peripheral-v1.s3.amazonaws.com/LICENSE.md
 */

contract AccessNFT is ERC1155, IAccessNFT {
    bool public deadlinesOn;
    address public immutable addressesRegistry;
    //function hashes -> tokenIDs -> deadline
    mapping(bytes32 => mapping(uint256 => uint256)) public deadlines;
    //tokenIDs -> fee discount percentage
    mapping(uint256 => uint256) public discountPercentage;
    //flashloan protection
    mapping(uint256 => bytes32) public tokenUsedInTransaction;

    constructor(address _addressesRegistry, bool _deadlinesOn) ERC1155("") {
        addressesRegistry = _addressesRegistry;
        deadlinesOn = _deadlinesOn;
    }

    /**
     * @dev modifier for when the address is the pool admin only
     */
    modifier onlyPoolAdmin() {
        require(
            IAccessManager(IAddressesRegistry(addressesRegistry).getAccessManager()).isPoolAdmin(msg.sender),
            Errors.CALLER_NOT_POOL_ADMIN
        );
        _;
    }

    /// @inheritdoc IAccessNFT
    function HasAccessNFT(address user, uint256 tokenId, string calldata functionName) external view returns (bool) {
        bytes32 hashedName = keccak256(bytes(functionName));
        require(!isContract(user), Errors.USER_CANNOT_BE_CONTRACT);
        require(deadlines[hashedName][tokenId] != 0, Errors.DEADLINE_NOT_FOUND);
        //Everyone has access after deadline ends
        //Using block.timestamp is safer than block number
        //See: https://ethereum.stackexchange.com/questions/11060/what-is-block-timestamp/11072#11072
        if ((block.timestamp > deadlines[hashedName][tokenId]) || (deadlinesOn == false)) {
            return true;
        }
        return this.balanceOf(user, tokenId) > 0;
    }

    /**
     * @dev Safely transfers NFTs from one address to another with flashloan protection
     * @param from The account to transfer from
     * @param to The account to transfer to
     * @param id the token id
     * @param amount The amount
     * @param data The data of the transaction
     */
    function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes memory data) public virtual override {
        bytes32 currentTransaction = keccak256(abi.encodePacked(block.number));
        require(tokenUsedInTransaction[id] != currentTransaction, Errors.FLASHLOAN_PROTECTION_ENABLED);
        tokenUsedInTransaction[id] = keccak256(abi.encodePacked(block.number));
        super.safeTransferFrom(from, to, id, amount, data);
    }

    /**
     * @dev Safely transfers multiple NFTs from one address to another with flashloan protection
     * @param from The account to transfer from
     * @param to The account to transfer to
     * @param ids the token ids array
     * @param amounts The amounts array
     * @param data The data of the transaction
     */
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override {
        bytes32 currentTransaction = keccak256(abi.encodePacked(block.number));
        for (uint256 i = 0; i < ids.length; i++) {
            require(tokenUsedInTransaction[ids[i]] != currentTransaction, Errors.FLASHLOAN_PROTECTION_ENABLED);
            tokenUsedInTransaction[ids[i]] = keccak256(abi.encodePacked(block.number));
        }
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }

    /// @inheritdoc IAccessNFT
    function setDeadline(string calldata functionName, uint256 deadline, uint256 tokenId) external onlyPoolAdmin {
        bytes32 hashedName = keccak256(bytes(functionName));
        deadlines[hashedName][tokenId] = deadline;

        emit DeadlineSet(functionName, hashedName, deadline, tokenId);
    }

    /// @inheritdoc IAccessNFT
    function getDeadline(bytes32 hashedFunctionName, uint256 tokenId) external view returns (uint256) {
        return deadlines[hashedFunctionName][tokenId];
    }

    /// @inheritdoc IAccessNFT
    function toggleDeadlines() external onlyPoolAdmin {
        deadlinesOn = !deadlinesOn;

        emit ToggleDeadlines(deadlinesOn);
    }

    /// @inheritdoc IAccessNFT
    function setFeeDiscount(uint256 tokenId, uint256 discount) external onlyPoolAdmin {
        require(discount >= 0, "Discount must not be less than 0");
        require(discount <= 100, "Discount must be less than or equal to 100");
        discountPercentage[tokenId] = discount;
    }

    /**
     * @dev Checks if an account address is a contract
     * @param account The account address
     */
    function isContract(address account) internal view returns (bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470; // hash of empty string
        assembly {
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    /// @inheritdoc IAccessNFT
    function setURI(string memory newuri) external onlyPoolAdmin {
        _setURI(newuri);
    }

    /// @inheritdoc IAccessNFT
    function adminBurn(address account, uint256 id, uint256 amount) external onlyPoolAdmin {
        _burn(account, id, amount);
    }

        function mint(address account, uint256 id, uint256 amount, bytes memory data) external onlyPoolAdmin {
        _mint(account, id, amount, data);
    }

    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts, bytes memory data) external onlyPoolAdmin {
        _mintBatch(to, ids, amounts, data);
    }
}


