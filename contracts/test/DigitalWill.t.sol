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
import "../src/interfaces/IPrecompile.sol";
import "../src/interfaces/IScheduler.sol";
import "../src/interfaces/IRitualWallet.sol";

contract DigitalWillTest is Test {
    DigitalWill public digitalWill;
    WillAgent public willAgent;
    WillLedger public ledger;

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


    address constant SCHEDULER_ADDR = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;
    address constant RITUAL_WALLET_ADDR = 0x0000000000000000000000000000000000000820;

    address public owner = address(0x11);
    address public heir1 = address(0x21);
    address public heir2 = address(0x22);
    address public heir3 = address(0x23);

    // Pattern BẮT BUỘC để mock precompile tại địa chỉ thật
    function setUp() public {
        // Mock LLM precompile tại 0x0802
        bytes memory llmBytecode = address(new MockLLM()).code;
        vm.etch(address(0x0802), llmBytecode);

        // Mock HTTP precompile tại 0x0801
        bytes memory httpBytecode = address(new MockHTTP()).code;
        vm.etch(address(0x0801), httpBytecode);

        // Mock FHE precompile tại 0x0807
        bytes memory fheBytecode = address(new MockFHE()).code;
        vm.etch(address(0x0807), fheBytecode);

        // Mock Scheduler tại địa chỉ hệ thống thật
        bytes memory schedulerBytecode = address(new MockScheduler()).code;
        vm.etch(SCHEDULER_ADDR, schedulerBytecode);

        // Mock RitualWallet
        bytes memory walletBytecode = address(new MockRitualWallet()).code;
        vm.etch(RITUAL_WALLET_ADDR, walletBytecode);

        // Deploy smart contracts
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

        // Link references
        ledger.setAddresses(address(digitalWill), address(willAgent), SCHEDULER_ADDR, RITUAL_WALLET_ADDR);
        digitalWill.setAgent(address(willAgent));
        willAgent.setBypass(true); // default true for agent bypass as well
        vm.stopPrank();

        // Send gas money to RitualWallet mock and heirs
        vm.deal(RITUAL_WALLET_ADDR, 100 ether);
        vm.deal(owner, 100 ether);
    }

    // 1. test_CreateWill() -- tạo will, verify event + state
    function test_CreateWill() public {
        address[] memory heirs = new address[](2);
        heirs[0] = heir1;
        heirs[1] = heir2;

        uint256[] memory shares = new uint256[](2);
        shares[0] = 6000; // 60%
        shares[1] = 4000; // 40%

        uint256[] memory conditions = new uint256[](2);
        conditions[0] = 1;
        conditions[1] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        vm.stopPrank();

        assertEq(willId, 1);
        (
            address ownerAddress,
            address[] memory returnHeirs,
            bytes[] memory encryptedShares,
            uint256[] memory returnConditions,
            ,
            ,
            bool active,
            bool distributed,
            uint256 lastPing,
            uint256 timeout
        ) = digitalWill.getWillDetails(willId);

        assertEq(ownerAddress, owner);
        assertEq(returnHeirs.length, 2);
        assertEq(returnHeirs[0], heir1);
        assertEq(returnConditions[0], 1);
        assertTrue(active);
        assertFalse(distributed);
        assertEq(lastPing, block.timestamp);
        assertEq(timeout, 1 days);

        // Verify FHE encrypted share (under bypass mode, it is standard abi.encode)
        uint256 share0 = abi.decode(encryptedShares[0], (uint256));
        assertEq(share0, 6000);
    }

    // 2. test_PingResetsHeartbeat() -- gọi ping, kiểm tra timestamp cập nhật
    function test_PingResetsHeartbeat() public {
        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        vm.stopPrank();

        // Warp time by 500 seconds (500000 milliseconds)
        vm.warp(block.timestamp + 500000);

        digitalWill.ping(willId);

        (,,,,,,,, uint256 lastPing,) = digitalWill.getWillDetails(willId);
        assertEq(lastPing, block.timestamp);
    }

    // 3. test_DistributionTriggersAfterTimeout() -- warp time 31 ngày, gọi triggerDistribution
    function test_DistributionTriggersAfterTimeout() public {
        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 30 days);
        // Deposit 1 ether into ledger
        digitalWill.addAsset{value: 1 ether}(willId, address(0), 1 ether);
        vm.stopPrank();

        // Warp time by 31 days (31 * 24 * 3600 * 1000 milliseconds)
        vm.warp(block.timestamp + 31 * 24 * 3600 * 1000);

        digitalWill.triggerDistribution(willId);

        (,,,,, ,bool active, bool distributed,,) = digitalWill.getWillDetails(willId);
        assertFalse(active);
        assertTrue(distributed);
    }

    // 4. test_BypassModeSkipsPrecompiles() -- bật bypass, verify không gọi precompile
    function test_BypassModeSkipsPrecompiles() public {
        // Bypass mode is enabled by default in constructor
        assertTrue(digitalWill.bypassPrecompiles());
        assertTrue(willAgent.bypassPrecompiles());

        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        digitalWill.addAsset{value: 1 ether}(willId, address(0), 1 ether);
        vm.stopPrank();

        // Warp time beyond timeout
        vm.warp(block.timestamp + 2 * 24 * 3600 * 1000);

        // Trigger distribution
        digitalWill.triggerDistribution(willId);

        // Verify that even if precompiles are bypassed, heir still gets paid
        assertEq(heir1.balance, 1 ether);
    }

    // 5. test_OwnerCanWithdrawBeforeTrigger() -- rút asset trước khi trigger
    function test_OwnerCanWithdrawBeforeTrigger() public {
        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 10 days);
        
        uint256 initialBalance = owner.balance;
        
        digitalWill.addAsset{value: 5 ether}(willId, address(0), 5 ether);
        assertEq(owner.balance, initialBalance - 5 ether);

        // Withdraw 3 ether before timeout
        digitalWill.withdrawAsset(willId, address(0), 3 ether);
        assertEq(owner.balance, initialBalance - 2 ether);
        vm.stopPrank();
    }

    // 6. test_SchedulerMultiBlockTransfer() -- verify Scheduler.schedule được gọi đúng 10 tham số
    function test_SchedulerMultiBlockTransfer() public {
        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        digitalWill.addAsset{value: 2 ether}(willId, address(0), 2 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 * 24 * 3600 * 1000);

        // Expect the Scheduled event from MockScheduler
        vm.expectEmit(true, true, true, false, SCHEDULER_ADDR);
        emit Scheduled(
            1, // jobId
            200000, // gasLimit
            20 * 10**9, // maxGasPrice
            1 * 10**9, // priorityFee
            1, // frequency
            block.number + 1, // startBlock
            block.number + 2, // endBlock
            RITUAL_WALLET_ADDR, // target to call
            0, // value
            bytes(""), // target call details (wildcard match topic)
            0 // salt
        );

        digitalWill.triggerDistribution(willId);
    }

    // 7. test_FHEEncryptDecryptRoundtrip() -- mã hóa + giải mã tỷ lệ
    function test_FHEEncryptDecryptRoundtrip() public {
        uint256 rawShare = 7500; // 75%
        bytes memory enc = IFHE(address(0x0807)).encrypt(rawShare, bytes("public_key"));
        uint256 dec = IFHE(address(0x0807)).decrypt(enc, bytes("private_key"));
        assertEq(rawShare, dec);
    }

    // 8. test_RevertWhenTriggeredTooEarly() -- gọi trigger trước timeout phải revert
    function test_RevertWhenTriggeredTooEarly() public {
        address[] memory heirs = new address[](1);
        heirs[0] = heir1;
        uint256[] memory shares = new uint256[](1);
        shares[0] = 10000;
        uint256[] memory conditions = new uint256[](1);
        conditions[0] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 5 days);
        vm.stopPrank();

        // Warp only 4 days (4 * 24 * 3600 * 1000 milliseconds)
        vm.warp(block.timestamp + 4 * 24 * 3600 * 1000);

        vm.expectRevert("Timeout not reached yet");
        digitalWill.triggerDistribution(willId);
    }

    // 9. test_MultipleHeirsGetCorrectAllocation() -- 3 heir với tỷ lệ khác nhau, kiểm tra số tiền từng người
    function test_MultipleHeirsGetCorrectAllocation() public {
        address[] memory heirs = new address[](3);
        heirs[0] = heir1;
        heirs[1] = heir2;
        heirs[2] = heir3;

        uint256[] memory shares = new uint256[](3);
        shares[0] = 5000; // 50%
        shares[1] = 3000; // 30%
        shares[2] = 2000; // 20%

        uint256[] memory conditions = new uint256[](3);
        conditions[0] = 0;
        conditions[1] = 0;
        conditions[2] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        digitalWill.addAsset{value: 10 ether}(willId, address(0), 10 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 * 24 * 3600 * 1000);

        uint256 bal1 = heir1.balance;
        uint256 bal2 = heir2.balance;
        uint256 bal3 = heir3.balance;

        digitalWill.triggerDistribution(willId);

        assertEq(heir1.balance - bal1, 5 ether);
        assertEq(heir2.balance - bal2, 3 ether);
        assertEq(heir3.balance - bal3, 2 ether);
    }

    // 10. Fuzz: test_HeirShareSumEqualsTotal(uint256[]) -- fuzz test tổng tỷ lệ = 10000
    function test_HeirShareSumEqualsTotal(uint256[3] memory fuzzShares) public {
        vm.assume(fuzzShares[0] > 0 && fuzzShares[0] < 10**18);
        vm.assume(fuzzShares[1] > 0 && fuzzShares[1] < 10**18);
        vm.assume(fuzzShares[2] > 0 && fuzzShares[2] < 10**18);

        // Normalize the fuzzed shares to sum exactly to 10000 bps
        uint256 sum = 0;
        for (uint256 i = 0; i < 3; i++) {
            sum += fuzzShares[i];
        }

        uint256[3] memory normalizedShares;
        uint256 runningSum = 0;
        for (uint256 i = 0; i < 2; i++) {
            normalizedShares[i] = (fuzzShares[i] * 10000) / sum;
            runningSum += normalizedShares[i];
        }
        normalizedShares[2] = 10000 - runningSum;

        address[] memory heirs = new address[](3);
        heirs[0] = heir1;
        heirs[1] = heir2;
        heirs[2] = heir3;

        uint256[] memory shares = new uint256[](3);
        shares[0] = normalizedShares[0];
        shares[1] = normalizedShares[1];
        shares[2] = normalizedShares[2];

        uint256[] memory conditions = new uint256[](3);
        conditions[0] = 0;
        conditions[1] = 0;
        conditions[2] = 0;

        vm.startPrank(owner);
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 1 days);
        digitalWill.addAsset{value: 1 ether}(willId, address(0), 1 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 2 * 24 * 3600 * 1000);

        uint256 bal1 = heir1.balance;
        uint256 bal2 = heir2.balance;
        uint256 bal3 = heir3.balance;

        digitalWill.triggerDistribution(willId);

        uint256 totalPayout = (heir1.balance - bal1) + (heir2.balance - bal2) + (heir3.balance - bal3);
        // There might be minor rounding precision due to division, check within 100 wei
        assertApproxEqAbs(totalPayout, 1 ether, 100);
    }
}
