// Web3 connection provider using Ethers.js v6
const PUBLIC_RPC = "https://rpc.ritualfoundation.org";
const CHAIN_ID = 1979;
const CHAIN_CONFIG = {
  chainId: "0x7BB", // 1979 in hex
  chainName: "Ritual Testnet",
  nativeCurrency: { name: "RITUAL", symbol: "RITUAL", decimals: 18 },
  rpcUrls: [PUBLIC_RPC],
  blockExplorerUrls: ["https://explorer.ritualfoundation.org"]
};

let provider = new ethers.JsonRpcProvider(PUBLIC_RPC);
let signer = null;
let userAddress = null;

// Initialize read-only mode immediately when entering dashboard
async function initReadOnly() {
  console.log("Initializing read-only provider via public RPC...");
  try {
    // These will be defined in app.js
    if (typeof loadWills === 'function') await loadWills();
    if (typeof loadActivityLog === 'function') await loadActivityLog();
    if (typeof initShowcaseData === 'function') await initShowcaseData();
  } catch (error) {
    console.error("Read-only init error:", error);
  }
}

// Connect MetaMask wallet
async function connectWallet() {
  if (!window.ethereum) {
    alert("Please install MetaMask to interact with the blockchain!");
    return;
  }
  try {
    const accounts = await window.ethereum.request({
      method: "eth_requestAccounts"
    });
    userAddress = accounts[0];
    
    const browserProvider = new ethers.BrowserProvider(window.ethereum);
    signer = await browserProvider.getSigner();
    provider = browserProvider; // Override with browser provider

    // Check chain and switch to Ritual Testnet
    const currentChainId = await window.ethereum.request({ method: 'eth_chainId' });
    if (currentChainId.toLowerCase() !== CHAIN_CONFIG.chainId.toLowerCase()) {
      try {
        await window.ethereum.request({
          method: "wallet_switchEthereumChain",
          params: [{ chainId: CHAIN_CONFIG.chainId }]
        });
      } catch (switchError) {
        // This error code indicates that the chain has not been added to MetaMask.
        if (switchError.code === 4902) {
          await window.ethereum.request({
            method: "wallet_addEthereumChain",
            params: [CHAIN_CONFIG]
          });
        } else {
          throw switchError;
        }
      }
    }

    if (typeof updateUI === 'function') updateUI();
    if (typeof logActivity === 'function') {
      logActivity(`Wallet connected: ${userAddress.substring(0, 6)}...${userAddress.substring(38)}`, "success");
    }
  } catch (err) {
    console.error("Connection failed:", err);
    if (typeof logActivity === 'function') {
      logActivity("Wallet connection failed or rejected", "danger");
    }
  }
}

// EVENT LISTENERS FOR ACCOUNTS & CHAIN CHANGED
if (window.ethereum) {
  window.ethereum.on("accountsChanged", async (accounts) => {
    console.log("MetaMask account changed:", accounts);
    userAddress = accounts[0] || null;
    if (userAddress) {
      const browserProvider = new ethers.BrowserProvider(window.ethereum);
      signer = await browserProvider.getSigner();
      provider = browserProvider;
    } else {
      signer = null;
      provider = new ethers.JsonRpcProvider(PUBLIC_RPC);
    }
    if (typeof updateUI === 'function') updateUI();
    if (typeof logActivity === 'function') {
      logActivity(userAddress ? `Account changed: ${userAddress.substring(0, 6)}...` : "Wallet disconnected", "warning");
    }
  });

  window.ethereum.on("chainChanged", (chainId) => {
    console.log("MetaMask chain changed:", chainId);
    if (chainId.toLowerCase() !== CHAIN_CONFIG.chainId.toLowerCase()) {
      alert("Network changed. Reconnecting to Ritual Testnet...");
    }
    // Safest reset as requested by user
    location.reload();
  });
}

document.addEventListener("DOMContentLoaded", initReadOnly);
