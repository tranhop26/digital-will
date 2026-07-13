// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DigitalWill.sol";
import "../src/WillAgent.sol";
import "../src/WillLedger.sol";
import "../src/mocks/MockLLM.sol";
import "../src/mocks/MockHTTP.sol";
import "../src/mocks/MockFHE.sol";
import "../src/mocks/MockScheduler.sol";
import "../src/mocks/MockRitualWallet.sol";

contract WillAgentTest is Test {
    DigitalWill public digitalWill;
    WillAgent public willAgent;
    WillLedger public ledger;

    address constant SCHEDULER_ADDR = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;
    address constant RITUAL_WALLET_ADDR = 0x0000000000000000000000000000000000000820;

    address public owner = address(0x11);
    address public heir1 = address(0x21);

    function setUp() public {
        bytes memory llmBytecode = address(new MockLLM()).code;
        vm.etch(address(0x0802), llmBytecode);

        bytes memory httpBytecode = address(new MockHTTP()).code;
        vm.etch(address(0x0801), httpBytecode);

        bytes memory fheBytecode = address(new MockFHE()).code;
        vm.etch(address(0x0807), fheBytecode);

        bytes memory schedulerBytecode = address(new MockScheduler()).code;
        vm.etch(SCHEDULER_ADDR, schedulerBytecode);

        bytes memory walletBytecode = address(new MockRitualWallet()).code;
        vm.etch(RITUAL_WALLET_ADDR, walletBytecode);

        vm.startPrank(owner);
        ledger = new WillLedger();
        digitalWill = new DigitalWill(address(ledger), address(0x0807));
        willAgent = new WillAgent(
            address(digitalWill),
            RITUAL_WALLET_ADDR,
            SCHEDULER_ADDR,
            address(0x0802),
            address(0x0801),
            address(0x0807)
        );

        ledger.setAddresses(address(digitalWill), address(willAgent), SCHEDULER_ADDR, RITUAL_WALLET_ADDR);
        digitalWill.setAgent(address(willAgent));
        vm.stopPrank();

        vm.deal(RITUAL_WALLET_ADDR, 100 ether);
    }

    function test_AgentInitialization() public {
        assertEq(willAgent.digitalWill(), address(digitalWill));
        assertEq(willAgent.ritualWallet(), RITUAL_WALLET_ADDR);
        assertEq(willAgent.scheduler(), SCHEDULER_ADDR);
        assertTrue(willAgent.bypassPrecompiles());
    }

    function test_AgentBypassToggle() public {
        vm.startPrank(owner);
        willAgent.setBypass(false);
        assertFalse(willAgent.bypassPrecompiles());
        vm.stopPrank();
    }
}
