// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

/// @title Delegatecall
/// @author Umami Devs
library Delegatecall {
    error EmptyContract(address);

    function delegateCall(address _target, bytes memory _calldata) internal returns (bytes memory _ret) {
        if (_target.code.length == 0) revert EmptyContract(_target);

        bool success;
        (success, _ret) = _target.delegatecall(_calldata);
        if (!success) {
            /// @solidity memory-safe-assembly
            assembly {
                let length := mload(_ret)
                let start := add(_ret, 0x20)
                revert(start, length)
            }
        }
    }
}
