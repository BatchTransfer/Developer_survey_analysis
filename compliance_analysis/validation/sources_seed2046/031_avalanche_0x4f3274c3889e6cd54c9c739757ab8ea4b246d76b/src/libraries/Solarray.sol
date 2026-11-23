// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import { SafeCast } from "./SafeCast.sol";

/// @title Solarray
/// @author Umami Devs
/// @notice Array functions
library Solarray {
    using SafeCast for int256;

    function uint256s(uint256 a, uint256 b) internal pure returns (uint256[2] memory arr) {
        arr[0] = a;
        arr[1] = b;
    }

    function int256s(int256 a, int256 b) internal pure returns (int256[2] memory arr) {
        arr[0] = a;
        arr[1] = b;
    }

    function addresss(address a, address b) internal pure returns (address[2] memory arr) {
        arr[0] = a;
        arr[1] = b;
    }

    function variableAddresss(address a, address b, address c, address d) internal pure returns (address[] memory) {
        address[] memory arr = new address[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        return arr;
    }

    function addresss(address a, address b, address c, address d) internal pure returns (address[4] memory arr) {
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function uint256s(uint256 a, uint256 b, uint256 c, uint256 d) internal pure returns (uint256[4] memory arr) {
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function variableUint256s(uint256 a, uint256 b, uint256 c, uint256 d)
        internal
        pure
        returns (uint256[] memory arr)
    {
        arr = new uint256[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        return arr;
    }

    function int256s(int256 a, int256 b, int256 c, int256 d) internal pure returns (int256[4] memory arr) {
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
    }

    function variableInt256s(int256 a, int256 b, int256 c, int256 d) internal pure returns (int256[] memory arr) {
        arr = new int256[](4);
        arr[0] = a;
        arr[1] = b;
        arr[2] = c;
        arr[3] = d;
        return arr;
    }

    function intToUintArray(int256[2] memory array) internal pure returns (uint256[2] memory uintArray) {
        require(array[0] >= 0 && array[1] >= 0, "Solarray: intToUintArray: negative value");
        uintArray = [uint256(array[0]), uint256(array[1])];
    }

    function arraySum(int256[2] memory array) internal pure returns (int256 sum) {
        for (uint256 i = 0; i < 2; i++) {
            sum += array[i];
        }
    }

    function arraySum(uint256[2] memory array) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < 2; i++) {
            sum += array[i];
        }
    }

    function arraySum(uint256[] memory array) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < array.length; i++) {
            sum += array[i];
        }
    }

    function arraySumWithSafeCast(int256[] memory array) internal pure returns (uint256 sum) {
        int256 intSum;
        for (uint256 i = 0; i < array.length; i++) {
            intSum += array[i];
        }
        sum = SafeCast.toUint256(intSum);
    }

    function arraySumAbsolute(int256[2] memory array) internal pure returns (uint256 sum) {
        for (uint256 i = 0; i < 2; i++) {
            sum += array[i] > 0 ? uint256(array[i]) : uint256(-array[i]);
        }
    }

    function arrayDifference(uint256[2] memory base, int256[2] memory difference)
        internal
        pure
        returns (int256[2] memory result)
    {
        for (uint256 i = 0; i < 2; i++) {
            result[i] = SafeCast.toInt256(base[i]) + difference[i];
        }
    }

    function arrayDifference(uint256[4] memory base, uint256[4] memory difference)
        internal
        pure
        returns (int256[4] memory result)
    {
        for (uint256 i = 0; i < 4; i++) {
            result[i] = SafeCast.toInt256(base[i]) - SafeCast.toInt256(difference[i]);
        }
    }

    function arrayDifference(uint256[] memory base, int256[] memory difference)
        internal
        pure
        returns (int256[] memory)
    {
        require(base.length == difference.length);
        int256[] memory result = new int256[](base.length);
        for (uint256 i = 0; i < base.length; i++) {
            result[i] = SafeCast.toInt256(base[i]) + difference[i];
        }
        return result;
    }

    function arrayDifference(uint256[] memory base, uint256[] memory difference)
        internal
        pure
        returns (int256[] memory)
    {
        require(base.length == difference.length);
        int256[] memory result = new int256[](base.length);
        for (uint256 i = 0; i < base.length; i++) {
            result[i] = SafeCast.toInt256(base[i]) - SafeCast.toInt256(difference[i]);
        }
        return result;
    }

    function arrayAddProportion(
        uint256[] memory base,
        uint256 amount,
        int256[] memory proportions,
        uint256 divisor,
        bool positive
    ) internal pure returns (uint256[] memory) {
        require(base.length == proportions.length);
        uint256 proportion;
        bool direction;
        uint256[] memory result = new uint256[](base.length);
        for (uint256 i = 0; i < base.length; i++) {
            direction = proportions[i] > 0;
            proportion = direction ? SafeCast.toUint256(proportions[i]) : SafeCast.toUint256(-proportions[i]);
            result[i] = direction == positive ? base[i] + (amount * proportion / divisor) : base[i];
        }
        return result;
    }

    function arrayRemoveDirection(int256[] memory base, bool positive) internal pure returns (uint256[] memory) {
        uint256[] memory result = new uint256[](base.length);
        bool direction;
        for (uint256 i = 0; i < base.length; i++) {
            direction = base[i] > 0;
            result[i] =
                direction == positive ? 0 : direction ? SafeCast.toUint256(base[i]) : SafeCast.toUint256(-base[i]);
        }
        return result;
    }

    /**
     * @notice Calculates the sum of array elements in one direction ~ +/-
     * @param _array to perform the operation
     * @param positive direction of sum
     * @return sum total sum in direction
     */
    function directionalSum(int256[] memory _array, bool positive) public pure returns (int256 sum) {
        for (uint256 i = 0; i < _array.length; i++) {
            if (_array[i] > 0 && positive) {
                sum += _array[i];
            } else if (_array[i] < 0 && !positive) {
                sum += _array[i];
            }
        }
    }

    function sumColumns(int256[2][2] memory array) internal pure returns (int256[2] memory retArray) {
        for (uint256 i = 0; i < 2; i++) {
            for (uint256 j = 0; j < 2; j++) {
                retArray[i] += array[j][i];
            }
        }
    }

    function int2FixedToDynamic(int256[2] memory arr) public view returns (int256[] memory retArr) {
        bytes memory ret = fixedToDynamicArray(abi.encode(arr), 2);
        /// @solidity memory-safe-assembly
        assembly {
            retArr := ret // point to the array
        }
    }

    function uint2FixedToDynamic(uint256[2] memory arr) internal view returns (uint256[] memory retArr) {
        bytes memory ret = fixedToDynamicArray(abi.encode(arr), 2);
        /// @solidity memory-safe-assembly
        assembly {
            retArr := ret // point to the array
        }
    }

    function uint4FixedToDynamic(uint256[4] memory arr) internal view returns (uint256[] memory retArr) {
        bytes memory ret = fixedToDynamicArray(abi.encode(arr), 4);
        /// @solidity memory-safe-assembly
        assembly {
            retArr := ret // point to the array
        }
    }

    function int4FixedToDynamic(int256[4] memory arr) internal view returns (int256[] memory retArr) {
        bytes memory ret = fixedToDynamicArray(abi.encode(arr), 4);
        /// @solidity memory-safe-assembly
        assembly {
            retArr := ret // point to the array
        }
    }

    function fixedToDynamicArray(bytes memory arr, uint256 fixedSize) public view returns (bytes memory retArray) {
        (bool success, bytes memory data) = address(0x04).staticcall(arr);
        require(success, "identity precompile failed");
        /// @solidity memory-safe-assembly
        assembly {
            retArray := data // point to the copied data
            mstore(retArray, fixedSize) // store array length
        }
    }

    /**
     * @dev Gets the value of the element at the specified index in the given array. If the index is out of bounds, returns 0.
     *
     * @param arr the array to get the value from
     * @param index the index of the element in the array
     * @return the value of the element at the specified index in the array
     */
    function get(bytes32[] memory arr, uint256 index) internal pure returns (bytes32) {
        if (index < arr.length) {
            return arr[index];
        }

        return bytes32(0);
    }

    /**
     * @dev Determines whether all of the elements in the given array are equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are equal to the specified value, false otherwise
     */
    function areEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] != value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are greater than the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are greater than the specified value, false otherwise
     */
    function areGreaterThan(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] <= value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are greater than or equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are greater than or equal to the specified value, false otherwise
     */
    function areGreaterThanOrEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] < value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are less than the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are less than the specified value, false otherwise
     */
    function areLessThan(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] >= value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Determines whether all of the elements in the given array are less than or equal to the specified value.
     *
     * @param arr the array to check the elements of
     * @param value the value to compare the elements of the array to
     * @return true if all of the elements in the array are less than or equal to the specified value, false otherwise
     */
    function areLessThanOrEqualTo(uint256[] memory arr, uint256 value) internal pure returns (bool) {
        for (uint256 i; i < arr.length; i++) {
            if (arr[i] > value) {
                return false;
            }
        }

        return true;
    }

    /**
     * @dev Gets the median value of the elements in the given array. For arrays with an odd number of elements, returns the element at the middle index. For arrays with an even number of elements, returns the average of the two middle elements.
     *
     * @param arr the array to get the median value from
     * @return the median value of the elements in the given array
     */
    function getMedian(uint256[] memory arr) internal pure returns (uint256) {
        if (arr.length % 2 == 1) {
            return arr[arr.length / 2];
        }

        return (arr[arr.length / 2] + arr[arr.length / 2 - 1]) / 2;
    }
}
