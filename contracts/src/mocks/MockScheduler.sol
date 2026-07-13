// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IScheduler.sol";

contract MockScheduler is IScheduler {
    uint256 private nextJobId = 1;
    
    event Scheduled(
        uint256 jobId,
        uint256 gasLimit,
        uint256 maxGasPrice,
        uint256 priorityFee,
        uint256 frequency,
        uint256 startBlock,
        uint256 endBlock,
        address to,
        uint256 value,
        bytes data,
        uint256 salt
    );

    function schedule(
        uint256 gasLimit,
        uint256 maxGasPrice,
        uint256 priorityFee,
        uint256 frequency,
        uint256 startBlock,
        uint256 endBlock,
        address to,
        uint256 value,
        bytes calldata data,
        uint256 salt
    ) external override returns (uint256 jobId) {
        jobId = nextJobId++;
        emit Scheduled(
            jobId,
            gasLimit,
            maxGasPrice,
            priorityFee,
            frequency,
            startBlock,
            endBlock,
            to,
            value,
            data,
            salt
        );
    }
}
