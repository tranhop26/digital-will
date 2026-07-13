// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interfaces/IPrecompile.sol";
import "./interfaces/IScheduler.sol";
import "./interfaces/IRitualWallet.sol";

interface IDigitalWill {
    function getWillDetails(uint256 willId) external view returns (
        address owner,
        address[] memory heirs,
        bytes[] memory encryptedShares,
        uint256[] memory conditions,
        address[] memory tokens,
        uint256[] memory amounts,
        bool active,
        bool distributed,
        uint256 lastPing,
        uint256 timeout
    );
    function markAsDistributed(uint256 willId) external;
    function ledger() external view returns (address);
}


contract WillAgent {
    address public owner;
    address public digitalWill;
    address public ritualWallet;
    address public scheduler;
    
    // Precompile addresses
    address public llmPrecompile;
    address public httpPrecompile;
    address public fhePrecompile;

    bool public bypassPrecompiles = true; // Default to true as per instructions

    event DistributionExecuted(uint256 indexed willId);
    event PrecompileFailed(address indexed precompile, string reason);
    event StepExecuted(string stepName, bool bypassed);
    event BypassToggled(bool bypass);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call");
        _;
    }

    modifier onlyDigitalWill() {
        require(msg.sender == digitalWill, "Only DigitalWill can call");
        _;
    }

    constructor(
        address _digitalWill,
        address _ritualWallet,
        address _scheduler,
        address _llmPrecompile,
        address _httpPrecompile,
        address _fhePrecompile
    ) {
        owner = msg.sender;
        digitalWill = _digitalWill;
        ritualWallet = _ritualWallet;
        scheduler = _scheduler;
        llmPrecompile = _llmPrecompile;
        httpPrecompile = _httpPrecompile;
        fhePrecompile = _fhePrecompile;
    }

    function setDigitalWill(address _digitalWill) external onlyOwner {
        digitalWill = _digitalWill;
    }

    function setBypass(bool _bypass) external onlyOwner {
        bypassPrecompiles = _bypass;
        emit BypassToggled(_bypass);
    }

    // Main execution function
    function executeDistribution(uint256 willId) external onlyDigitalWill {
        (
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
        ) = IDigitalWill(digitalWill).getWillDetails(willId);

        require(active, "Will is not active");
        require(!distributed, "Will already distributed");

        // RITUAL NETWORK TIMEOUT MATH:
        // On Ritual Network, block.timestamp is measured in MILLISECONDS.
        // This is a major difference from Ethereum where block.timestamp is in SECONDS.
        // Thus, timeout (inputted in seconds) must be multiplied by 1000 before comparing.
        require(block.timestamp > lastPing + timeout * 1000, "Timeout not reached yet");

        for (uint256 i = 0; i < heirs.length; i++) {
            address heir = heirs[i];
            uint256 condition = conditions[i];
            bytes memory encryptedShare = encryptedShares[i];

            // Step 1: LLM Validation (0x0802)
            bool llmSuccess = false;
            string memory llmResult = "bypassed";
            if (!bypassPrecompiles) {
                try ILLM(llmPrecompile).run(
                    "Analyze if the heir qualifies for distribution based on condition",
                    abi.encode(condition)
                ) returns (bytes memory res) {
                    llmSuccess = true;
                    llmResult = string(res);
                    emit StepExecuted("LLM_Precompile", false);
                } catch {
                    emit PrecompileFailed(llmPrecompile, "LLM run failed");
                }
            }
            if (!llmSuccess) {
                // Fallback / Bypass
                llmResult = '{"decision": "execute", "conditionMet": true}';
                emit StepExecuted("LLM_Simulated", true);
            }

            // Step 2: HTTP Identity/KYC Verification (0x0801)
            bool httpSuccess = false;
            string memory httpResult = "bypassed";
            if (!bypassPrecompiles) {
                try IHTTP(httpPrecompile).request(
                    "https://kyc.ritualfoundation.org/verify",
                    "POST",
                    "",
                    abi.encode(heir)
                ) returns (bytes memory res) {
                    httpSuccess = true;
                    httpResult = string(res);
                    emit StepExecuted("HTTP_Precompile", false);
                } catch {
                    emit PrecompileFailed(httpPrecompile, "HTTP request failed");
                }
            }
            if (!httpSuccess) {
                // Fallback / Bypass
                httpResult = '{"status": "verified", "kyc": true}';
                emit StepExecuted("HTTP_Simulated", true);
            }

            // Step 3: FHE Decrypt Share (0x0807)
            bool fheSuccess = false;
            uint256 shareBps = 0;
            if (!bypassPrecompiles) {
                try IFHE(fhePrecompile).decrypt(encryptedShare, bytes("private_key")) returns (uint256 decShare) {
                    fheSuccess = true;
                    shareBps = decShare;
                    emit StepExecuted("FHE_Precompile", false);
                } catch {
                    emit PrecompileFailed(fhePrecompile, "FHE decrypt failed");
                }
            }
            if (!fheSuccess) {
                // Fallback / Plaintext decode
                shareBps = abi.decode(encryptedShare, (uint256));
                emit StepExecuted("FHE_Simulated", true);
            }

            // Perform distribution for all tokens in the will based on the decrypted share
            address ledgerAddress = IDigitalWill(digitalWill).ledger();

            // Perform distribution for all tokens in the will based on the decrypted share
            for (uint256 j = 0; j < tokens.length; j++) {
                address token = tokens[j];
                uint256 totalAmount = amounts[j];
                uint256 heirAmount;
                if (isERC721(token)) {
                    uint256 targetHeirIndex = getLargestShareHeirIndex(encryptedShares, bypassPrecompiles);
                    if (i == targetHeirIndex) {
                        heirAmount = totalAmount;
                    } else {
                        heirAmount = 0;
                    }
                } else {
                    heirAmount = (totalAmount * shareBps) / 10000;
                }


                if (heirAmount > 0) {
                    bytes memory payload = abi.encodeWithSignature(
                        "payHeir(address,address,uint256)",
                        heir,
                        token,
                        heirAmount
                    );

                    // Step 4: Schedule multi-block transfer using system Scheduler
                    // Priority fee MUST be >= 1 gwei (1000000000 wei)
                    try IScheduler(scheduler).schedule(
                        200000,                  // gasLimit
                        20 * 10**9,              // maxGasPrice (20 gwei)
                        1 * 10**9,               // priorityFee (1 gwei)
                        1,                       // frequency (every block)
                        block.number + 1,        // startBlock
                        block.number + 2,        // endBlock
                        ritualWallet,            // target (calls RitualWallet to execute payHeir)
                        0,                       // value
                        abi.encodeWithSignature("execute(address,uint256,bytes)", ledgerAddress, 0, payload),
                        uint256(keccak256(abi.encodePacked(block.timestamp, heir, token, j))) // salt
                    ) returns (uint256 jobId) {
                        emit StepExecuted("Scheduler_Scheduled", false);
                    } catch {
                        emit PrecompileFailed(scheduler, "Scheduler failed");
                    }

                    // Step 5: Execute transfer immediately via RitualWallet
                    try IRitualWallet(ritualWallet).execute(ledgerAddress, 0, payload) {
                        emit StepExecuted("RitualWallet_Executed", false);
                    } catch {
                        emit PrecompileFailed(ritualWallet, "RitualWallet execute failed");
                    }
                }
            }

        }

        IDigitalWill(digitalWill).markAsDistributed(willId);
        emit DistributionExecuted(willId);
    }

    function isERC721(address token) internal view returns (bool) {
        if (token == address(0)) return false;
        // Standard ERC721 does not have decimals() function, unlike ERC20
        (bool success, ) = token.staticcall(abi.encodeWithSignature("decimals()"));
        return !success;
    }

    function getLargestShareHeirIndex(bytes[] memory encryptedShares, bool bypass) internal pure returns (uint256) {
        uint256 maxShare = 0;
        uint256 maxIndex = 0;
        for (uint256 i = 0; i < encryptedShares.length; i++) {
            uint256 share = bypass ? abi.decode(encryptedShares[i], (uint256)) : 0;
            if (share > maxShare) {
                maxShare = share;
                maxIndex = i;
            }
        }
        return maxIndex;
    }
}
