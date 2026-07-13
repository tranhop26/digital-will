// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPrecompile.sol";

interface IWillAgent {
    function executeDistribution(uint256 willId) external;
}

interface IWillLedger {
    function depositAsset(
        uint256 willId,
        address token,
        uint256 amount,
        address depositor
    ) external payable;

    function withdrawAsset(
        uint256 willId,
        address token,
        uint256 amount,
        address recipient
    ) external;
}

contract DigitalWill {
    address public owner;
    address public ledger;
    address public agent;
    address public fhePrecompile;

    bool public bypassPrecompiles = true; // Default to true as per instructions
    uint256 public willCount;

    struct Heir {
        address beneficiary;
        bytes encryptedShare; // Encrypted via FHE or plain abi.encode
        uint256 condition;
    }

    struct Will {
        uint256 id;
        address ownerAddress;
        Heir[] heirs;
        address[] tokens;
        uint256[] amounts;
        uint256 lastPing; // Milliseconds on Ritual Network
        uint256 timeout;  // Seconds, to be multiplied by 1000 for compare
        bool active;
        bool distributed;
    }

    mapping(uint256 => Will) private wills;

    event WillCreated(uint256 indexed willId, address indexed ownerAddress, uint256 timeout);
    event HeartbeatPinged(uint256 indexed willId, uint256 lastPing);
    event DistributionTriggered(uint256 indexed willId);
    event AssetAdded(uint256 indexed willId, address indexed token, uint256 amount);
    event AssetWithdrawn(uint256 indexed willId, address indexed token, uint256 amount);
    event BypassToggled(bool bypass);
    event AgentUpdated(address agent);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier onlyAgent() {
        require(msg.sender == agent, "Only Agent can call");
        _;
    }

    modifier onlyWillOwner(uint256 willId) {
        require(wills[willId].ownerAddress == msg.sender, "Not the will owner");
        _;
    }

    constructor(address _ledger, address _fhePrecompile) {
        owner = msg.sender;
        ledger = _ledger;
        fhePrecompile = _fhePrecompile;
        bypassPrecompiles = true; // BẮT BUỘC set bypassPrecompiles = true mặc định
    }

    function setAgent(address _agent) external onlyOwner {
        agent = _agent;
        emit AgentUpdated(_agent);
    }

    function toggleBypass() external onlyOwner {
        bypassPrecompiles = !bypassPrecompiles;
        emit BypassToggled(bypassPrecompiles);
    }

    // Create a new will
    function createWill(
        address[] calldata heirs,
        uint256[] calldata shares,
        uint256[] calldata conditions,
        uint256 timeout
    ) external returns (uint256 willId) {
        require(heirs.length == shares.length && heirs.length == conditions.length, "Array lengths mismatch");
        require(heirs.length > 0, "At least one heir required");
        
        uint256 totalShares = 0;
        for (uint256 i = 0; i < shares.length; i++) {
            totalShares += shares[i];
        }
        require(totalShares == 10000, "Total shares must equal 10000 BPS");

        willId = ++willCount;
        Will storage newWill = wills[willId];
        newWill.id = willId;
        newWill.ownerAddress = msg.sender;
        newWill.timeout = timeout;
        
        // RITUAL NETWORK BLOCK TIMESTAMP MATH:
        // On Ritual Network, block.timestamp is measured in MILLISECONDS.
        // This is a major difference from Ethereum where block.timestamp is in SECONDS.
        newWill.lastPing = block.timestamp;
        newWill.active = true;
        newWill.distributed = false;

        for (uint256 i = 0; i < heirs.length; i++) {
            bytes memory encShare;
            if (bypassPrecompiles) {
                // If bypassing precompiles, encode as standard plaintext bytes
                encShare = abi.encode(shares[i]);
            } else {
                // Call FHE precompile (0x0807) to encrypt the share
                try IFHE(fhePrecompile).encrypt(shares[i], bytes("public_key")) returns (bytes memory res) {
                    encShare = res;
                } catch {
                    // Fallback to plaintext if precompile fails
                    encShare = abi.encode(shares[i]);
                }
            }
            newWill.heirs.push(Heir({
                beneficiary: heirs[i],
                encryptedShare: encShare,
                condition: conditions[i]
            }));
        }

        emit WillCreated(willId, msg.sender, timeout);
    }

    // Ping will to update heartbeat
    function ping(uint256 willId) external {
        require(wills[willId].active, "Will is not active");
        
        // Update heartbeat with millisecond timestamp
        wills[willId].lastPing = block.timestamp;
        emit HeartbeatPinged(willId, block.timestamp);
    }

    // Trigger distribution
    function triggerDistribution(uint256 willId) external {
        Will storage w = wills[willId];
        require(w.active, "Will is not active");
        require(!w.distributed, "Will already distributed");

        // RITUAL NETWORK TIMEOUT MATH:
        // block.timestamp is in MILLISECONDS (since Ritual block time is ~350ms).
        // w.timeout is stored in SECONDS. We must multiply timeout by 1000.
        // This differs from Ethereum where block.timestamp is in seconds.
        require(block.timestamp > w.lastPing + w.timeout * 1000, "Timeout not reached yet");

        emit DistributionTriggered(willId);

        // Call the AI Agent to execute precompile-based checks and distribution
        IWillAgent(agent).executeDistribution(willId);
    }

    // Add asset to the will (payable for ETH support)
    function addAsset(uint256 willId, address token, uint256 amount) external payable {
        Will storage w = wills[willId];
        require(w.active, "Will is not active");
        require(!w.distributed, "Will already distributed");

        // Deposit directly to WillLedger
        IWillLedger(ledger).depositAsset{value: msg.value}(willId, token, amount, msg.sender);

        // Update token balances inside Will struct
        bool found = false;
        for (uint256 i = 0; i < w.tokens.length; i++) {
            if (w.tokens[i] == token) {
                w.amounts[i] += (token == address(0)) ? msg.value : amount;
                found = true;
                break;
            }
        }
        if (!found) {
            w.tokens.push(token);
            w.amounts.push((token == address(0)) ? msg.value : amount);
        }

        emit AssetAdded(willId, token, (token == address(0)) ? msg.value : amount);
    }

    // Withdraw asset back to owner
    function withdrawAsset(uint256 willId, address token, uint256 amount) external onlyWillOwner(willId) {
        Will storage w = wills[willId];
        require(w.active, "Will is not active");
        require(!w.distributed, "Will already distributed");

        // Update token balances first
        bool found = false;
        for (uint256 i = 0; i < w.tokens.length; i++) {
            if (w.tokens[i] == token) {
                require(w.amounts[i] >= amount, "Insufficient amount stored");
                w.amounts[i] -= amount;
                found = true;
                break;
            }
        }
        require(found, "Asset not found in will");

        // Withdraw from WillLedger back to owner
        IWillLedger(ledger).withdrawAsset(willId, token, amount, msg.sender);
        emit AssetWithdrawn(willId, token, amount);
    }

    function markAsDistributed(uint256 willId) external onlyAgent {
        wills[willId].distributed = true;
        wills[willId].active = false;
    }

    // Helper function for Agent to fetch will details
    function getWillDetails(uint256 willId) external view returns (
        address ownerAddress,
        address[] memory heirs,
        bytes[] memory encryptedShares,
        uint256[] memory conditions,
        address[] memory tokens,
        uint256[] memory amounts,
        bool active,
        bool distributed,
        uint256 lastPing,
        uint256 timeout
    ) {
        Will storage w = wills[willId];
        ownerAddress = w.ownerAddress;
        active = w.active;
        distributed = w.distributed;
        lastPing = w.lastPing;
        timeout = w.timeout;
        tokens = w.tokens;
        amounts = w.amounts;

        uint256 length = w.heirs.length;
        heirs = new address[](length);
        encryptedShares = new bytes[](length);
        conditions = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            heirs[i] = w.heirs[i].beneficiary;
            encryptedShares[i] = w.heirs[i].encryptedShare;
            conditions[i] = w.heirs[i].condition;
        }
    }
}
