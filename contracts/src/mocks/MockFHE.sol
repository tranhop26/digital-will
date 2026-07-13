// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPrecompile.sol";

contract MockFHE is IFHE {
    function encrypt(uint256 value, bytes calldata publicKey) external override pure returns (bytes memory) {
        // Simple mock: encode value as ciphertext
        return abi.encode(value);
    }

    function decrypt(bytes calldata ciphertext, bytes calldata privateKey) external override pure returns (uint256) {
        // Simple mock: decode ciphertext as value
        return abi.decode(ciphertext, (uint256));
    }
}
