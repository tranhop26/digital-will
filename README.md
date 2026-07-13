# Digital Will -- AI Dead Man's Switch on Ritual Network

[![Solidity Version](https://img.shields.urlencoded.io/badge/Solidity-0.8.20-blue.svg)](https://soliditylang.org/)
[![Ritual Network](https://img.shields.urlencoded.io/badge/Ritual-Testnet-purple.svg)](https://ritual.net/)
[![License](https://img.shields.urlencoded.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)

**Digital Will** is a decentralized "Dead Man's Switch" smart contract and AI Agent system built on the **Ritual Network** (Chain ID 1979). If a wallet owner remains inactive (fails to "ping" the contract) for a user-defined timeout period, the system triggers an autonomous AI Agent to distribute the owner's on-chain assets (ETH, ERC-20, ERC-721) to their heirs according to homomorphically encrypted shares.

## System Architecture

```
                       +-------------------+
                       |    Wallet Owner   |
                       +---------+---------+
                                 | (ping / createWill / deposit)
                                 v
                       +-------------------+
                       |  DigitalWill.sol  |
                       +---------+---------+
                                 | (triggerDistribution)
                                 v
                       +-------------------+
                       |   WillAgent.sol   |
                       +---------+---------+
                                 |
         +-----------------------+-----------------------+
         | (1. Check conditions) | (2. Verify identity)  | (3. Decrypt shares)
         v                       v                       v
  +--------------+        +--------------+        +--------------+
  | LLM (0x0802) |        | HTTP (0x0801)|        | FHE (0x0807) |
  +--------------+        +--------------+        +--------------+
         |                       |                       |
         +-----------------------+-----------------------+
                                 | (4. Schedule / 5. Execute)
                                 v
                       +-------------------+
                       |  RitualWallet /   |
                       |  WillLedger.sol   |
                       +---------+---------+
                                 | (Distribute assets)
                                 v
                       +-------------------+
                       | Heirs/Beneficiers |
                       +-------------------+
```

## Ritual Network Core Integrations

1. **LLM Precompile (0x0802)**: Evaluates dynamic conditions (e.g. checking if heirs qualify based on rules).
2. **HTTP Precompile (0x0801)**: Interacts with KYC/identity providers to verify the heir's status.
3. **FHE Precompile (0x0807)**: Decrypts allocation percentages stored encrypted on-chain, preserving privacy.
4. **Scheduler (0x56e7...)**: Orchestrates multi-block asset distribution tasks.
5. **RitualWallet (0x0820)**: The escrow wallet sovereign to the agent.
6. **WillLedger.sol**: Holds custody of assets and executes payments to heirs.

---

## Smart Contract Details

### Ritual-Specific Configurations:
- **Block Timestamp in Milliseconds**: Unlike Ethereum where `block.timestamp` is in seconds, Ritual's timestamp is in **milliseconds**. Any timeout comparison scales seconds by `1000` (`timeout * 1000`).
- **Default Precompile Bypass**: Because precompile bytecodes might not be active on testnet, `bypassPrecompiles` defaults to `true` inside the `DigitalWill` constructor. The owner can call `toggleBypass()` to activate precompile execution when supported.

---

## Deployment & Verification

### Prerequisites
Install Foundry inside WSL or Windows:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Compile & Test
Run the comprehensive test suite (including mocks for all 5 Ritual precompiles and fuzzing):
```bash
cd contracts
forge test -vvv
```

### Deploy to Ritual Testnet
Deploy contracts using the EIP-1559 configuration:
```bash
forge script script/Deploy.s.sol:Deploy \
  --rpc-url https://rpc.ritualfoundation.org \
  --broadcast \
  --priority-gas-price 1gwei
```
> [!IMPORTANT]
> **DO NOT** use the `--legacy` flag during deployment. Ritual Network strictly enforces EIP-1559 transaction fees and requires a minimum priority fee of `1 gwei`.

---

## Frontend Web App
The frontend is built with a premium glassmorphism dark theme and connects to the Ritual network using Ethers.js v6.
- Listeners for `accountsChanged` and `chainChanged` reload the page dynamically to prevent incorrect state.
- Features a public RPC read-only mode to load Wills and Activity Logs without prompting wallet connection first.
- Includes showcase simulation buttons ("I'm Inactive", "Load Demo Data", "Random Will") for quick testing.

## License
MIT
