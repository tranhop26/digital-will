const SHOWCASE_WILLS = [
  {
    id: 1,
    owner: "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb1",
    heirs: [
      { name: "Alice (daughter)", share: 50, condition: "Age >= 18" },
      { name: "Bob (son)", share: 30, condition: "None" },
      { name: "Charlie (charity)", share: 20, condition: "Verified Org" }
    ],
    assets: [
      { token: "ETH", amount: "2.5", valueUSD: 8250 },
      { token: "USDC", amount: "5000", valueUSD: 5000 }
    ],
    lastPing: "2026-07-10T08:00:00Z",
    daysUntilTrigger: 28,
    status: "Active"
  },
  {
    id: 2,
    owner: "0x90F8bf65Dccf19083a30c5ec7c41c5eb05Ec547d",
    heirs: [
      { name: "Diana (wife)", share: 80, condition: "Marriage Certificate" },
      { name: "Eve (sister)", share: 20, condition: "None" }
    ],
    assets: [
      { token: "ETH", amount: "10.0", valueUSD: 33000 }
    ],
    lastPing: "2026-06-01T12:00:00Z",
    daysUntilTrigger: 0,
    status: "Distributed"
  },
  {
    id: 3,
    owner: "0x1111111111111111111111111111111111111111",
    heirs: [
      { name: "Frank (nephew)", share: 100, condition: "Graduation proof" }
    ],
    assets: [
      { token: "LINK", amount: "350", valueUSD: 5250 }
    ],
    lastPing: "2026-07-12T23:59:00Z",
    daysUntilTrigger: 5,
    status: "Active"
  }
];

function generateRandomWill() {
  const id = Math.floor(Math.random() * 100000);
  const owners = [
    "0x9965503B1a0594008a30c5ec7c41c5eb05Ec547d",
    "0x2234C0532925a3b844Bc9e7595f0bEb1742d35Cc",
    "0x884Bc9e7595f0bEb1742d35Cc6634C0532925a3b"
  ];
  const owner = owners[Math.floor(Math.random() * owners.length)];
  
  const heirNames = [
    { name: "Grace (sister)", share: 40, condition: "None" },
    { name: "Hank (brother)", share: 30, condition: "Verify identity" },
    { name: "Ivy (niece)", share: 30, condition: "Age >= 21" }
  ];
  
  const tokens = ["ETH", "USDT", "WBTC"];
  const token = tokens[Math.floor(Math.random() * tokens.length)];
  const amount = (Math.random() * 5 + 0.1).toFixed(2);
  const valueUSD = Math.round(amount * (token === "ETH" ? 3300 : token === "USDT" ? 1 : 65000));

  // Randomize last ping between 1 and 40 days ago
  const daysAgo = Math.floor(Math.random() * 40);
  const pingDate = new Date();
  pingDate.setDate(pingDate.getDate() - daysAgo);

  const status = daysAgo > 30 ? "Distributed" : "Active";
  const daysUntilTrigger = Math.max(0, 30 - daysAgo);

  return {
    id,
    owner,
    heirs: heirNames,
    assets: [{ token, amount, valueUSD }],
    lastPing: pingDate.toISOString(),
    daysUntilTrigger,
    status
  };
}

if (typeof module !== 'undefined' && module.exports) {
  module.exports = { SHOWCASE_WILLS, generateRandomWill };
}
