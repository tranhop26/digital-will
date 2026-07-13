// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IRitualWallet.sol";

contract MockRitualWallet is IRitualWallet {
    event Executed(address indexed to, uint256 value, bytes data);
    event Deposited(address indexed sender, uint256 value);

    receive() external payable {
        emit Deposited(msg.sender, msg.value);
    }

    function execute(
        address to,
        uint256 value,
        bytes calldata data
    ) external override returns (bytes memory) {
        emit Executed(to, value, data);
        (bool success, bytes memory result) = to.call{value: value}(data);
        require(success, "Wallet execution failed");
        return result;
    }

    function deposit() external override payable {
        emit Deposited(msg.sender, msg.value);
    }
}
