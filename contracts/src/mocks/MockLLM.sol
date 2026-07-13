// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IPrecompile.sol";

contract MockLLM is ILLM {
    function run(string calldata prompt, bytes calldata context) external override returns (bytes memory) {
        // Return dummy JSON decision indicating condition is met
        return bytes('{"decision": "execute", "conditionMet": true}');
    }
}
