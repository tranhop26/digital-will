// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IRitualWallet {
    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external returns (bytes memory);

    function deposit() external payable;
}
