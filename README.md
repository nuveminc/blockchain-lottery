# Provably Random Contract Lottery

## About

A random smart contract lottery using a Chainlink VRF and Automation.

## What does this do?

1. Users can enter by paying for a ticket
   1. The ticket fees are going to go to the winner during the draw
2. After X eriod of time the lotter will automatically draw a winner
   1. This will be done in the contract programmatically
3. Using Chainlink VRF & Chainlink Automation
   1. Randomness => Chainlink VRF
   2. Time Trigger => Chainlink Automation

## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

-   **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
-   **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
-   **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
-   **Chisel**: Fast, utilitarian, and verbose solidity REPL.


## Testing
Generate a test coverage report

```script
$ forge coverage --report debug > coverage.txt
```

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy
The deploy currently only supports ETH SEPOLIA and ANVIL chains.
See HelperConfig to update with additional chains.
 
```shell
$ forge script script/DeployLottery.s.sol:DeployLottery --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
