// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC721 {
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
}

contract WillLedger {
    address public digitalWill;
    address public willAgent;
    address public scheduler;
    address public ritualWallet;

    // Track ledger balances for safety: willId => token => amount
    mapping(uint256 => mapping(address => uint256)) public willBalances;

    event HeirPaid(address indexed heir, address indexed token, uint256 amount);
    event AssetDeposited(uint256 indexed willId, address indexed token, uint256 amount);
    event AssetWithdrawn(uint256 indexed willId, address indexed token, uint256 amount);

    modifier onlyAuthorized() {
        require(
            msg.sender == digitalWill || 
            msg.sender == willAgent || 
            msg.sender == scheduler || 
            msg.sender == ritualWallet, 
            "Unauthorized ledger caller"
        );
        _;
    }

    constructor() {
        digitalWill = msg.sender; // Will be linked properly during deploy
    }

    function setAddresses(
        address _digitalWill,
        address _willAgent,
        address _scheduler,
        address _ritualWallet
    ) external {
        // Can only set once or only by initial creator
        require(digitalWill == address(0) || msg.sender == digitalWill, "Only DigitalWill can set addresses");
        digitalWill = _digitalWill;
        willAgent = _willAgent;
        scheduler = _scheduler;
        ritualWallet = _ritualWallet;
    }

    receive() external payable {}

    // Add asset to a specific will
    function depositAsset(
        uint256 willId,
        address token,
        uint256 amount,
        address depositor
    ) external payable onlyAuthorized {
        if (token == address(0)) {
            // ETH deposit
            willBalances[willId][token] += msg.value;
            emit AssetDeposited(willId, token, msg.value);
        } else {
            // ERC-20 or ERC-721 deposit
            // Try ERC-20 transferFrom first, if it fails it might be ERC-721
            try IERC20(token).transferFrom(depositor, address(this), amount) returns (bool success) {
                require(success, "ERC20 transfer failed");
            } catch {
                // If it fails, assume it is ERC-721 where amount is tokenId
                IERC721(token).safeTransferFrom(depositor, address(this), amount);
            }
            willBalances[willId][token] += amount;
            emit AssetDeposited(willId, token, amount);
        }
    }

    // Withdraw asset back to owner
    function withdrawAsset(
        uint256 willId,
        address token,
        uint256 amount,
        address recipient
    ) external onlyAuthorized {
        require(willBalances[willId][token] >= amount, "Insufficient ledger balance");
        willBalances[willId][token] -= amount;

        if (token == address(0)) {
            payable(recipient).transfer(amount);
        } else {
            // Try standard ERC-20 transfer, catch error for ERC-721
            try IERC20(token).transfer(recipient, amount) returns (bool success) {
                if (!success) {
                    IERC721(token).safeTransferFrom(address(this), recipient, amount);
                }
            } catch {
                IERC721(token).safeTransferFrom(address(this), recipient, amount);
            }
        }
        emit AssetWithdrawn(willId, token, amount);
    }

    // Pay heir -- called by WillAgent/Scheduler/RitualWallet
    function payHeir(
        address heir,
        address token,
        uint256 amount
    ) external onlyAuthorized {
        if (token == address(0)) {
            payable(heir).transfer(amount);
        } else {
            try IERC20(token).transfer(heir, amount) returns (bool success) {
                if (!success) {
                    IERC721(token).safeTransferFrom(address(this), heir, amount);
                }
            } catch {
                IERC721(token).safeTransferFrom(address(this), heir, amount);
            }
        }
        emit HeirPaid(heir, token, amount);
    }
}
