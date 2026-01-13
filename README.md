# Battleship Game on Ethereum (DApp)
A decentralized application (DApp) that implements the **Battleship** game on the **Ethereum blockchain**, featuring:
- a **simple web front-end**
- a **smart contract back-end** that manages game sessions and handles transfers in case of **win/loss** or **cheating**

## Project Goal

The goal of this project is to build a Battleship game on Ethereum that:
- supports **multiple game sessions** with different players
- securely manages **transactions** between players
- enforces rules and penalties in case of **cheating**

## Tech Stack

- **Solidity** – Smart contracts  
- **Truffle** – Compilation, migration, and testing framework  
- **Ganache** – Local Ethereum blockchain  
- **MetaMask** – Wallet and Web3 provider  
- **Node.js / npm**  
- **JavaScript / HTML / CSS** – Front-end  

## Repository Structure

Main folders and files:
- `contracts/` – Solidity smart contracts  
- `migrations/` – Truffle migration scripts  
- `test/` – Smart contract tests  
- `src/` – Front-end source code  
- `build/contracts/` – Compiled contract artifacts (ABI & bytecode)  
- `truffle-config.js` – Truffle configuration  
- `Report.pdf` – Detailed project report and user guide  

## Prerequisites

Make sure you have installed:
- **Node.js** and **npm**
- **MetaMask**
- **Ganache**
- **Truffle** (global or local dependency)

> Note: the repository includes a `node_modules/` folder.  
> Normally this should not be versioned; if you remove it, remember to run `npm install`.

## Quick Setup (Local Development)

### 1. Clone the repository and install dependencies
```bash
git clone https://github.com/AndreaGiuliani-Git/DappInEthereum.git
cd DappInEthereum
npm install
```
## Start Ganache
Launch Ganache (GUI or CLI)
Check the RPC endpoint (commonly http://127.0.0.1:7545 or http://127.0.0.1:8545)


## Configure MetaMask
Add the local Ganache networ
Import one of the Ganache accounts using its private key


## Compile and deploy smart contracts
```bash
truffle compile
truffle migrate --reset
```
If a specific network is required:
```bash
truffle migrate --reset --network development
```
## Run the front-end
Check the scripts defined in package.json. Commonly:
```bash
npm start
```
If it doesn’t work, list available scripts:
```bash
npm run
```
## Testing
Run the smart contract tests:
```bash
truffle test
```

## Gameplay Overview
Typical flow:
- Players connect MetaMask to the local Ethereum network
- A game session is created or joined
- Players place ships and take turns attacking
- The smart contract validates actions and manages outcomes
- Transfers are executed in case of victory, loss, or cheating
- For a detailed explanation of the rules, UI, and internal logic, refer to Report.pdf.

## Security and Cheating Prevention
The back-end smart contract is designed to:
- validate game actions
- determine winners and losers
- handle penalties and transfers in case of cheating

Implementation details are documented in the project report.

## License
This project is released under the MIT License.
