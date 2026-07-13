// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPrecompile.sol";

contract MockHTTP is IHTTP {
    function request(
        string calldata url,
        string calldata method,
        bytes calldata headers,
        bytes calldata body
    ) external override returns (bytes memory) {
        // Return simulated verified identity KYC response
        return bytes('{"status": "verified", "kyc": true}');
    }
}
