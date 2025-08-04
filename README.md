## ✈️ Aviator Game on Ethereum

A decentralized version of the popular **Aviator multiplier crash game**, built on the Ethereum blockchain using Solidity smart contracts and a browser-based frontend powered by `ethers.js` and TailwindCSS.

---

### 🎮 How the Game Works

* Players place bets before the game starts.
* The game launches and a multiplier increases over time.
* Players must **cash out** before the randomly determined **crash point**.
* If they cash out in time, they win based on the multiplier.
* If the game crashes first, they lose their bet.

---

### 💸 Owner Profit Mechanism

* The **house earns profit** when players fail to cash out in time.
* When a player wins, the house keeps the difference between their bet and payout.
* At the end of each round, the owner can withdraw accumulated profits via `withdrawProfit()`.

---

### ⚙️ Smart Contract Features

* **Commit-Reveal Scheme** to prevent cheating (server commits to a hash before revealing the crash seed).
* **Crash Point Algorithm** is pseudo-random and capped for fairness.
* Players can:

  * `placeBet()`
  * `cashOut()` before crash
  * `claimPayout()` after round ends
  * `refund()` if the game is stalled
* Owner can:

  * `commitSeedHash()` → commit the round
  * `startGame()` → launch the game
  * `revealSeedAndPayout()` → reveal crash and allow payouts
  * `resetRound()` → start new round
  * `withdrawProfit()` → collect house earnings

---

### 🔐 Provable Fairness

* Each round uses a **committed hash of a server seed**.
* After the game, the seed is revealed and the crash point is calculated:

  ```solidity
  uint256 crash = (100000 * PRECISION) / (100000 - (randomValue % 99000));
  ```
* This ensures the crash is determined **before** gameplay and can’t be manipulated.

---

### 🧑‍💻 Frontend

**Tech Stack:**

* HTML + TailwindCSS
* JavaScript (`ethers.js` v5.2 via CDN)
* MetaMask wallet integration

**Frontend Features:**

* Wallet connection with MetaMask
* Place bet & cash out buttons
* Live feedback messages
* Placeholder for multiplier animation and game UI

📄 The frontend connects directly to the deployed smart contract via `ethers.js`.

---

### 🚀 How to Run Locally

1. **Deploy Smart Contract** (using Hardhat or Remix):

   ```bash
   // Example: using Hardhat
   npx hardhat compile
   npx hardhat run scripts/deploy.js --network goerli
   ```

2. **Update the Frontend**

   * Replace the placeholder contract address and ABI in the JS file.
   * Add game logic to read/write from the contract using `ethers.js`.

3. **Open HTML File**

   ```bash
   open index.html
   ```

---

### 🔐 Security Considerations

* The game is a prototype. Use caution with real ETH.
* Always test on **testnets** (e.g., Goerli) before mainnet deployment.
* Payout logic depends on timestamp-based multipliers, which may vary slightly due to block timing.

---

### 📄 License

This project is licensed under the **MIT License**.

---

