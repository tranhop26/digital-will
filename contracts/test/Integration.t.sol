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

// Simple Mock ERC20 Token
contract MockERC20 {
    string public name = "Mock ERC20";
    string public symbol = "M20";
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor() {
        balanceOf[msg.sender] = 1000000 ether;
        totalSupply = 1000000 ether;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

// Simple Mock ERC721 Token
contract MockERC721 {
    string public name = "Mock ERC721";
    string public symbol = "M721";
    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    mapping(uint256 => address) public getApproved;
    mapping(address => mapping(address => bool)) public isApprovedForAll;

    function mint(address to, uint256 tokenId) external {
        ownerOf[tokenId] = to;
        balanceOf[to] += 1;
    }

    function approve(address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == msg.sender, "Not owner");
        getApproved[tokenId] = to;
    }

    function setApprovalForAll(address operator, bool approved) external {
        isApprovedForAll[msg.sender][operator] = approved;
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) external {
        require(ownerOf[tokenId] == from, "Not owner");
        require(msg.sender == from || getApproved[tokenId] == msg.sender || isApprovedForAll[from][msg.sender], "Not approved");
        
        getApproved[tokenId] = address(0);
        balanceOf[from] -= 1;
        balanceOf[to] += 1;
        ownerOf[tokenId] = to;
    }
}

contract IntegrationTest is Test {
    DigitalWill public digitalWill;
    WillAgent public willAgent;
    WillLedger public ledger;

    MockERC20 public erc20;
    MockERC721 public erc721;

    address constant SCHEDULER_ADDR = 0x56e776BAE2DD60664b69Bd5F865F1180ffB7D58B;
    address constant RITUAL_WALLET_ADDR = 0x0000000000000000000000000000000000000820;

    address public owner = address(0x11);
    address public heir1 = address(0x21);
    address public heir2 = address(0x22);

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

        // Deploy ledger, digitalWill, willAgent
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
        willAgent.setBypass(true); // default bypass true
        vm.stopPrank();

        // Deploy mock tokens
        erc20 = new MockERC20();
        erc721 = new MockERC721();
        
        // Transfer some MockERC20 to owner so they can deposit
        erc20.transfer(owner, 10000 ether);

        // Deal ETH
        vm.deal(owner, 100 ether);
        vm.deal(RITUAL_WALLET_ADDR, 100 ether);
    }

    function test_EndToEndERC20AndERC721Inheritance() public {
        // Mint ERC721 token 77 to owner
        erc721.mint(owner, 77);

        // Distribute to two heirs: 70% and 30%
        address[] memory heirs = new address[](2);
        heirs[0] = heir1;
        heirs[1] = heir2;

        uint256[] memory shares = new uint256[](2);
        shares[0] = 7000; // 70%
        shares[1] = 3000; // 30%

        uint256[] memory conditions = new uint256[](2);
        conditions[0] = 0;
        conditions[1] = 0;

        vm.startPrank(owner);
        // Create will with 2 days timeout
        uint256 willId = digitalWill.createWill(heirs, shares, conditions, 2 days);

        // Approve and deposit 1000 MockERC20
        erc20.approve(address(ledger), 1000 ether);
        digitalWill.addAsset(willId, address(erc20), 1000 ether);

        // Approve and deposit ERC721
        erc721.approve(address(ledger), 77);
        digitalWill.addAsset(willId, address(erc721), 77); // amount is tokenId
        vm.stopPrank();

        // Verify assets are deposited in the ledger
        assertEq(erc20.balanceOf(address(ledger)), 1000 ether);
        assertEq(erc721.ownerOf(77), address(ledger));

        // Warp time beyond 2 days timeout (2 * 24 * 3600 * 1000 milliseconds)
        vm.warp(block.timestamp + 3 * 24 * 3600 * 1000);

        // Trigger distribution
        digitalWill.triggerDistribution(willId);

        // Verify ERC20 balances: heir1 gets 700, heir2 gets 300
        assertEq(erc20.balanceOf(heir1), 700 ether);
        assertEq(erc20.balanceOf(heir2), 300 ether);

        // Verify ERC721 ownership: since it cannot be split, the largest share heir (heir1) gets it.
        assertEq(erc721.ownerOf(77), heir1);
    }
}
