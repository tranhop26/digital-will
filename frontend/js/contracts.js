// Human-Readable ABIs for Ethers.js v6
const DIGITAL_WILL_ABI = [
  "function createWill(address[] heirs, uint256[] shares, uint256[] conditions, uint256 timeout) returns (uint256)",
  "function ping(uint256 willId)",
  "function triggerDistribution(uint256 willId)",
  "function addAsset(uint256 willId, address token, uint256 amount) payable",
  "function withdrawAsset(uint256 willId, address token, uint256 amount)",
  "function getWillDetails(uint256 willId) view returns (address ownerAddress, address[] heirs, bytes[] encryptedShares, uint256[] conditions, address[] tokens, uint256[] amounts, bool active, bool distributed, uint256 lastPing, uint256 timeout)",
  "function willCount() view returns (uint256)",
  "function bypassPrecompiles() view returns (bool)",
  "function toggleBypass()",
  "event WillCreated(uint256 indexed willId, address indexed ownerAddress, uint256 timeout)",
  "event HeartbeatPinged(uint256 indexed willId, uint256 lastPing)",
  "event DistributionTriggered(uint256 indexed willId)",
  "event AssetAdded(uint256 indexed willId, address indexed token, uint256 amount)",
  "event AssetWithdrawn(uint256 indexed willId, address indexed token, uint256 amount)",
  "event BypassToggled(bool bypass)"
];

const WILL_LEDGER_ABI = [
  "function willBalances(uint256 willId, address token) view returns (uint256)",
  "event HeirPaid(address indexed heir, address indexed token, uint256 amount)",
  "event AssetDeposited(uint256 indexed willId, address indexed token, uint256 amount)",
  "event AssetWithdrawn(uint256 indexed willId, address indexed token, uint256 amount)"
];

const WILL_AGENT_ABI = [
  "function bypassPrecompiles() view returns (bool)",
  "function setBypass(bool bypass)",
  "event DistributionExecuted(uint256 indexed willId)",
  "event PrecompileFailed(address indexed precompile, string reason)",
  "event StepExecuted(string stepName, bool bypassed)",
  "event BypassToggled(bool bypass)"
];

// Placeholders for contract deployment addresses (updated after deploying)
let DIGITAL_WILL_ADDRESS = "0x243A9A1ab9F96EFdaB527216AA0CF337181D9e45";
let WILL_AGENT_ADDRESS = "0x14955188e8312F4dED56A8A831E8340963a8d63e";
let WILL_LEDGER_ADDRESS = "0x7D6Cd89686f7520b4028749f6Ff56300035FC48d";

if (typeof module !== 'undefined' && module.exports) {
  module.exports = {
    DIGITAL_WILL_ABI,
    WILL_LEDGER_ABI,
    WILL_AGENT_ABI,
    DIGITAL_WILL_ADDRESS,
    WILL_AGENT_ADDRESS,
    WILL_LEDGER_ADDRESS
  };
}
