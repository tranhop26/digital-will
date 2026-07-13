// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IScheduler {
    function schedule(
        uint256 gasLimit,        // 1
        uint256 maxGasPrice,     // 2
        uint256 priorityFee,     // 3 -- >= 1 gwei
        uint256 frequency,       // 4 -- number of blocks between steps
        uint256 startBlock,      // 5
        uint256 endBlock,        // 6
        address to,              // 7 -- target address (e.g. WillLedger or RitualWallet)
        uint256 value,           // 8
        bytes calldata data,     // 9 -- encoded call data
        uint256 salt             // 10
    ) external returns (uint256 jobId);
}
