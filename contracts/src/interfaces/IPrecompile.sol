// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ILLM {
    function run(string calldata prompt, bytes calldata context) external returns (bytes memory);
}

interface IHTTP {
    function request(
        string calldata url,
        string calldata method,
        bytes calldata headers,
        bytes calldata body
    ) external returns (bytes memory);
}

interface IFHE {
    function encrypt(uint256 value, bytes calldata publicKey) external returns (bytes memory);
    function decrypt(bytes calldata ciphertext, bytes calldata privateKey) external returns (uint256);
}
