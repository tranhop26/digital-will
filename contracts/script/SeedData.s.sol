// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/DigitalWill.sol";

contract SeedData is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        // Read the deployed contract address from the environment or pass a placeholder
        address digitalWillAddr = vm.envOr("DIGITAL_WILL", address(0));
        
        if (digitalWillAddr == address(0)) {
            console.log("No DIGITAL_WILL address provided to seed script. Skipping...");
            return;
        }

        vm.startBroadcast(deployerPrivateKey);
        
        DigitalWill will = DigitalWill(digitalWillAddr);
        
        address[] memory heirs = new address[](2);
        heirs[0] = address(0x2234);
        heirs[1] = address(0x9965);
        
        uint256[] memory shares = new uint256[](2);
        shares[0] = 6000;
        shares[1] = 4000;
        
        uint256[] memory conditions = new uint256[](2);
        conditions[0] = 1;
        conditions[1] = 0;
        
        uint256 willId = will.createWill(heirs, shares, conditions, 86400); // 1 day timeout
        console.log("Seeded mock Will ID:", willId);
        
        will.addAsset{value: 0.01 ether}(willId, address(0), 0.01 ether);
        console.log("Seeded 0.01 ether asset into Will ID:", willId);
        
        vm.stopBroadcast();
    }
}
