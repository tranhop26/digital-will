// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalWill.sol";
import "../src/WillAgent.sol";
import "../src/WillLedger.sol";
import "../src/mocks/MockRitualWallet.sol";

contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy Ledger
        WillLedger ledger = new WillLedger();
        console.log("Deployed WillLedger at:", address(ledger));

        // Deploy MockRitualWallet on testnet to act as the agent wallet
        MockRitualWallet wallet = new MockRitualWallet();
        console.log("Deployed MockRitualWallet at:", address(wallet));

        // Define precompile addresses (using 0xDEAD placeholders as precompiles are not enabled yet)
        address llm = address(0xDEAD);
        address http = address(0xDEAD);
        address fhe = address(0xDEAD);
        address scheduler = address(0xDEAD);

        // Deploy DigitalWill
        DigitalWill digitalWill = new DigitalWill(address(ledger), fhe);
        console.log("Deployed DigitalWill at:", address(digitalWill));

        // Deploy WillAgent
        WillAgent agent = new WillAgent(
            address(digitalWill),
            address(wallet),
            scheduler,
            llm,
            http,
            fhe
        );
        console.log("Deployed WillAgent at:", address(agent));

        // Setup references and permissions
        ledger.setAddresses(
            address(digitalWill),
            address(agent),
            scheduler,
            address(wallet)
        );
        digitalWill.setAgent(address(agent));

        // Deposit some native tokens into RitualWallet for the agent
        wallet.deposit{value: 0.05 ether}();
        console.log("Deposited 0.05 ether to RitualWallet");

        vm.stopBroadcast();
    }
}
