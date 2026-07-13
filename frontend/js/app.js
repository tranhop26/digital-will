// Dashboard UI & Contract interactions
let activeWills = [];

// Tab switching logic
function switchTab(tabName) {
  document.querySelectorAll('.tab-content').forEach(el => el.style.display = 'none');
  document.querySelectorAll('.sidebar-nav a').forEach(el => el.classList.remove('active'));
  
  document.getElementById(`tab-${tabName}`).style.display = 'block';
  // Find nav link corresponding to tab
  const activeLink = Array.from(document.querySelectorAll('.sidebar-nav a')).find(el => el.innerText.toLowerCase().includes(tabName));
  if (activeLink) activeLink.classList.add('active');
}

// Add/Remove Heir Rows in Form
function addHeirRow() {
  const container = document.getElementById('heirs-container');
  const newRow = document.createElement('div');
  newRow.className = 'heir-input-row';
  newRow.innerHTML = `
    <input type="text" class="form-control heir-address" placeholder="Heir Address (0x...)" required>
    <input type="number" class="form-control heir-share" placeholder="Share (%)" value="30" min="1" max="100" required>
    <input type="number" class="form-control heir-condition" placeholder="Condition Code (uint)" value="0" required>
    <button type="button" class="btn-remove" onclick="removeHeirRow(this)">✕</button>
  `;
  container.appendChild(newRow);
}

function removeHeirRow(button) {
  const row = button.parentElement;
  const container = document.getElementById('heirs-container');
  if (container.children.length > 1) {
    container.removeChild(row);
  } else {
    alert("At least one heir is required.");
  }
}

// Log activity to the side panel
function logActivity(message, type = "info") {
  const container = document.getElementById('activity-log-container');
  const time = new Date().toLocaleTimeString();
  const logItem = document.createElement('div');
  logItem.className = `log-item ${type}`;
  logItem.innerHTML = `<div class="log-time">${time}</div>${message}`;
  container.prepend(logItem);
}

// Fill creation form with Showcase Data
function loadDemoWillData() {
  const demoWill = SHOWCASE_WILLS[0];
  document.getElementById('will-timeout').value = 86400 * 30; // 30 days
  document.getElementById('will-deposit').value = "2.5";
  
  const container = document.getElementById('heirs-container');
  container.innerHTML = ""; // Clear existing
  
  // Alice, Bob, Charlie (shares: 5000, 3000, 2000)
  const demoHeirs = [
    { address: "0x32ba4e0a3fe1b83c0f3a8005113eda49b3b89c76c", share: 5000, condition: 1 },
    { address: "0x9965503B1a0594008a30c5ec7c41c5eb05Ec547d", share: 3000, condition: 0 },
    { address: "0x2234C0532925a3b844Bc9e7595f0bEb1742d35Cc", share: 2000, condition: 2 }
  ];

  demoHeirs.forEach((h, idx) => {
    const row = document.createElement('div');
    row.className = 'heir-input-row';
    row.innerHTML = `
      <input type="text" class="form-control heir-address" placeholder="Heir Address (0x...)" value="${h.address}" required>
      <input type="number" class="form-control heir-share" placeholder="Share (%)" value="${h.share / 100}" min="1" max="100" required>
      <input type="number" class="form-control heir-condition" placeholder="Condition Code (uint)" value="${h.condition}" required>
      <button type="button" class="btn-remove" onclick="removeHeirRow(this)">✕</button>
    `;
    container.appendChild(row);
  });
  
  logActivity("Loaded Demo Showcase Will into form. Click Deploy to publish on-chain.", "warning");
  switchTab('create');
}

// Load random will data into form
function loadRandomWillData() {
  const randomWill = generateRandomWill();
  document.getElementById('will-timeout').value = 86400 * 5; // 5 days
  document.getElementById('will-deposit').value = randomWill.assets[0].amount;
  
  const container = document.getElementById('heirs-container');
  container.innerHTML = "";
  
  randomWill.heirs.forEach(h => {
    const randomAddr = "0x" + Math.floor(Math.random()*16**40).toString(16).padStart(40, '0');
    const row = document.createElement('div');
    row.className = 'heir-input-row';
    row.innerHTML = `
      <input type="text" class="form-control heir-address" placeholder="Heir Address (0x...)" value="${randomAddr}" required>
      <input type="number" class="form-control heir-share" placeholder="Share (%)" value="${h.share}" min="1" max="100" required>
      <input type="number" class="form-control heir-condition" placeholder="Condition Code (uint)" value="0" required>
      <button type="button" class="btn-remove" onclick="removeHeirRow(this)">✕</button>
    `;
    container.appendChild(row);
  });

  logActivity("Loaded Random Will into form. Click Deploy to publish on-chain.", "warning");
  switchTab('create');
}

// Load Wills list (Public RPC read support)
async function loadWills() {
  console.log("Loading wills...");
  const willsContainer = document.getElementById('wills-container');
  
  // If no contracts deployed yet, load showcase mockup data
  if (!DIGITAL_WILL_ADDRESS) {
    displayMockWills();
    return;
  }

  try {
    const contract = new ethers.Contract(DIGITAL_WILL_ADDRESS, DIGITAL_WILL_ABI, provider);
    const count = await contract.willCount();
    console.log(`Discovered ${count} wills on-chain.`);
    
    if (count === 0n) {
      willsContainer.innerHTML = '<p style="color: var(--text-muted); font-size: 14px; text-align: center;">No active wills found on-chain.</p>';
      return;
    }

    willsContainer.innerHTML = ''; // Clear
    activeWills = [];

    for (let i = 1; i <= count; i++) {
      const details = await contract.getWillDetails(i);
      const will = {
        id: i,
        owner: details[0],
        heirs: details[1].map((addr, idx) => ({
          address: addr,
          share: Number(details[2][idx]), // If bypass, it is decoded. If not, it will be raw bytes length
          condition: Number(details[3][idx])
        })),
        assets: details[4].map((token, idx) => ({
          token: token === ethers.ZeroAddress ? "ETH" : token,
          amount: ethers.formatEther(details[5][idx])
        })),
        active: details[6],
        distributed: details[7],
        lastPing: Number(details[8]), // in ms
        timeout: Number(details[9])  // in s
      };
      
      activeWills.push(will);
      renderWillCard(will);
    }
  } catch (error) {
    console.error("Error loading wills from blockchain:", error);
    logActivity("Failed to load wills from blockchain. Showing showcase data instead.", "danger");
    displayMockWills();
  }
}

// Display mock showcase data when blockchain is not connected or no wills deployed
function displayMockWills() {
  const container = document.getElementById('wills-container');
  container.innerHTML = '';
  
  SHOWCASE_WILLS.forEach(will => {
    const card = document.createElement('div');
    card.className = 'will-card';
    
    let heirsHtml = '';
    will.heirs.forEach(h => {
      heirsHtml += `
        <div style="margin-bottom: 8px;">
          <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 2px;">
            <span>👤 ${h.name} (Cond: ${h.condition})</span>
            <span>${h.share}%</span>
          </div>
          <div class="heir-share-bar">
            <div class="heir-share-fill" style="width: ${h.share}%;"></div>
          </div>
        </div>
      `;
    });

    let assetsHtml = '';
    will.assets.forEach(a => {
      assetsHtml += `<div>💰 <span>${a.amount} ${a.token}</span> ($${a.valueUSD})</div>`;
    });

    card.innerHTML = `
      <div class="will-header">
        <span class="will-id">Will #${will.id} (Showcase)</span>
        <span class="badge ${will.status === 'Active' ? 'badge-active' : 'badge-distributed'}">${will.status}</span>
      </div>
      <div class="will-details">
        <div>Owner: <span>${will.owner.substring(0, 6)}...${will.owner.substring(38)}</span></div>
        <div>Last Ping: <span>${new Date(will.lastPing).toLocaleString()}</span></div>
        <div>Days Until Trigger: <span>${will.daysUntilTrigger} days</span></div>
        <div>Timeout: <span>30 days</span></div>
      </div>
      <div style="margin: 8px 0; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 8px;">
        <div style="font-weight: 500; font-size: 12px; margin-bottom: 8px; color: var(--text-muted);">Assets:</div>
        ${assetsHtml}
      </div>
      <div style="margin-top: 8px;">
        <div style="font-weight: 500; font-size: 12px; margin-bottom: 8px; color: var(--text-muted);">Heirs:</div>
        ${heirsHtml}
      </div>
    `;
    container.appendChild(card);
  });
}

function renderWillCard(will) {
  const container = document.getElementById('wills-container');
  const card = document.createElement('div');
  card.className = 'will-card';

  let heirsHtml = '';
  will.heirs.forEach((h, idx) => {
    // Under FHE mode, share BPS might be encrypted, show placeholder or decode if bypass on
    const displayShare = h.share > 0 ? (h.share / 100) : "Encrypted (FHE)";
    const sharePercentage = h.share > 0 ? (h.share / 100) : 0;
    heirsHtml += `
      <div style="margin-bottom: 8px;">
        <div style="display: flex; justify-content: space-between; font-size: 12px; margin-bottom: 2px;">
          <span>👤 ${h.address.substring(0, 6)}... (Cond: ${h.condition})</span>
          <span>${displayShare}%</span>
        </div>
        <div class="heir-share-bar">
          <div class="heir-share-fill" style="width: ${sharePercentage}%;"></div>
        </div>
      </div>
    `;
  });

  let assetsHtml = '';
  will.assets.forEach(a => {
    assetsHtml += `<div>💰 <span>${a.amount} ${a.token}</span></div>`;
  });

  const timeRemaining = Math.max(0, (will.lastPing + will.timeout * 1000) - Date.now());
  const hoursRemaining = (timeRemaining / (3600 * 1000)).toFixed(1);

  card.innerHTML = `
    <div class="will-header">
      <span class="will-id">Will #${will.id} (On-chain)</span>
      <span class="badge ${will.active ? 'badge-active' : 'badge-distributed'}">${will.active ? 'Active' : 'Distributed'}</span>
    </div>
    <div class="will-details">
      <div>Owner: <span>${will.owner.substring(0, 6)}...${will.owner.substring(38)}</span></div>
      <div>Last Ping: <span>${new Date(will.lastPing).toLocaleString()}</span></div>
      <div>Hours Until Trigger: <span>${will.active ? hoursRemaining + ' hrs' : '0'}</span></div>
      <div>Timeout: <span>${will.timeout}s</span></div>
    </div>
    <div style="margin: 8px 0; border-top: 1px solid rgba(255,255,255,0.05); padding-top: 8px;">
      <div style="font-weight: 500; font-size: 12px; margin-bottom: 8px; color: var(--text-muted);">Assets:</div>
      ${assetsHtml}
    </div>
    <div style="margin-top: 8px;">
      <div style="font-weight: 500; font-size: 12px; margin-bottom: 8px; color: var(--text-muted);">Heirs:</div>
      ${heirsHtml}
    </div>
  `;
  container.appendChild(card);
}

// Deploy on-chain will via MetaMask
async function handleCreateWill(event) {
  event.preventDefault();
  if (!signer) {
    alert("Please connect your wallet first!");
    return;
  }

  const timeout = parseInt(document.getElementById('will-timeout').value);
  const deposit = parseFloat(document.getElementById('will-deposit').value);

  const heirAddresses = Array.from(document.querySelectorAll('.heir-address')).map(el => el.value);
  // Multiply percentage by 100 to convert to BPS (e.g. 50% -> 5000 BPS)
  const heirShares = Array.from(document.querySelectorAll('.heir-share')).map(el => parseInt(el.value) * 100);
  const heirConditions = Array.from(document.querySelectorAll('.heir-condition')).map(el => parseInt(el.value));

  logActivity("Deploying on-chain Will...", "info");

  try {
    const contract = new ethers.Contract(DIGITAL_WILL_ADDRESS, DIGITAL_WILL_ABI, signer);
    
    // Create will transaction
    const tx = await contract.createWill(heirAddresses, heirShares, heirConditions, timeout, {
      priorityFeePerGas: ethers.parseUnits("1", "gwei") // EIP-1559 priority fee
    });
    
    logActivity(`Tx submitted: ${tx.hash.substring(0, 10)}... waiting for confirmation`, "info");
    const receipt = await tx.wait();
    logActivity("Will contract successfully created on Ritual Testnet!", "success");

    // Fetch the willId from logs
    const eventTopic = contract.interface.getEvent("WillCreated").topicHash;
    const log = receipt.logs.find(l => l.topics[0] === eventTopic);
    let willId = 1;
    if (log) {
      const decoded = contract.interface.decodeEventLog("WillCreated", log.data, log.topics);
      willId = Number(decoded.willId);
    }

    // Deposit initial ETH asset
    if (deposit > 0) {
      logActivity(`Depositing initial capital of ${deposit} ETH...`, "info");
      const depTx = await contract.addAsset(willId, ethers.ZeroAddress, ethers.parseEther(deposit.toString()), {
        value: ethers.parseEther(deposit.toString()),
        priorityFeePerGas: ethers.parseUnits("1", "gwei")
      });
      await depTx.wait();
      logActivity(`Asset deposited successfully into Will #${willId}`, "success");
    }

    await loadWills();
    switchTab('dashboard');
  } catch (error) {
    console.error("Deployment failed:", error);
    logActivity(`Deployment failed: ${error.message.substring(0, 60)}`, "danger");
  }
}

// Simulate Heartbeat Ping on-chain
async function simulatePing() {
  if (!signer) {
    alert("Please connect your wallet!");
    return;
  }
  const willId = prompt("Enter Will ID to ping:", "1");
  if (!willId) return;

  logActivity(`Sending heartbeat ping for Will #${willId}...`, "info");
  try {
    const contract = new ethers.Contract(DIGITAL_WILL_ADDRESS, DIGITAL_WILL_ABI, signer);
    const tx = await contract.ping(willId, {
      priorityFeePerGas: ethers.parseUnits("1", "gwei")
    });
    await tx.wait();
    logActivity(`Heartbeat reset for Will #${willId}!`, "success");
    await loadWills();
  } catch (error) {
    console.error("Ping failed:", error);
    logActivity(`Ping failed: ${error.message.substring(0, 60)}`, "danger");
  }
}

// Simulate Inactivity / Trigger distribution
async function simulateInactivity() {
  if (!signer) {
    alert("Please connect your wallet!");
    return;
  }
  const willId = prompt("Enter Will ID to trigger distribution:", "1");
  if (!willId) return;

  logActivity(`Triggering distribution for Will #${willId}...`, "info");
  try {
    const contract = new ethers.Contract(DIGITAL_WILL_ADDRESS, DIGITAL_WILL_ABI, signer);
    const tx = await contract.triggerDistribution(willId, {
      priorityFeePerGas: ethers.parseUnits("1", "gwei")
    });
    logActivity("Inactivity simulation tx submitted. Waiting for Ritual AI Agent...", "info");
    await tx.wait();
    logActivity(`Distribution succeeded for Will #${willId}!`, "success");
    await loadWills();
  } catch (error) {
    console.error("Distribution trigger failed:", error);
    logActivity(`Trigger failed: ${error.message.substring(0, 60)}`, "danger");
    alert("Revert: Timeout may not be reached yet! Try checking the remaining time.");
  }
}

// Toggle Bypass Precompiles on contract
async function toggleBypassPrecompiles() {
  if (!signer) {
    alert("Please connect your wallet!");
    return;
  }
  logActivity("Toggling Precompile Bypass...", "info");
  try {
    const contract = new ethers.Contract(DIGITAL_WILL_ADDRESS, DIGITAL_WILL_ABI, signer);
    const tx = await contract.toggleBypass({
      priorityFeePerGas: ethers.parseUnits("1", "gwei")
    });
    await tx.wait();
    const currentBypass = await contract.bypassPrecompiles();
    logActivity(`Precompile bypass state updated: ${currentBypass}`, "success");
    updateUI();
  } catch (error) {
    console.error("Bypass toggle failed:", error);
    logActivity("Failed to toggle bypass (ensure you are the contract deployer owner)", "danger");
  }
}

// Update UI elements based on connection status
function updateUI() {
  const btnConnects = document.querySelectorAll('.btn-connect');
  const networkStatus = document.getElementById('network-status');
  const networkIndicator = document.getElementById('network-indicator');

  if (userAddress) {
    btnConnects.forEach(btn => {
      btn.innerText = `${userAddress.substring(0, 6)}...${userAddress.substring(38)}`;
    });
    networkStatus.innerText = "Ritual Connected";
    networkIndicator.style.backgroundColor = "var(--success)";
    networkIndicator.style.boxShadow = "0 0 10px var(--success)";
  } else {
    btnConnects.forEach(btn => {
      btn.innerText = "Connect Wallet";
    });
    networkStatus.innerText = "Ritual Testnet";
    networkIndicator.style.backgroundColor = "var(--accent-cyan)";
    networkIndicator.style.boxShadow = "0 0 10px var(--accent-cyan)";
  }
}

// Load static showcase data initially
function initShowcaseData() {
  displayMockWills();
}
