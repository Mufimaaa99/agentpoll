[README.md](https://github.com/user-attachments/files/35072854/README.md)
# AgentPoll

**One Agent ID, one voice.**

AgentPoll is a Sybil-resistant on-chain polling dApp for Agent ID holders. Voting rights come
directly from holding an Agent ID: one address holding at least one Agent ID gets exactly one
vote per poll. Results are stored on-chain and can be audited by anyone from contract state and
events.

This is an independent community project. It is not affiliated with or endorsed by any exchange
or chain foundation. Polls carry no financial reward of any kind.

## How it works

- The voting gate is the Agent ID contract's `balanceOf(address)` function only. The real Agent
  ID contract does not support enumeration, and AgentPoll does not need it.
- Mainnet gate contract (BNB Smart Chain): `0x60b9262456de011f7d15a54cdd8c48baaa8b022f`
- One address = one vote per poll. A vote cannot be changed after it is cast.
- A poll has 2–5 options and an optional duration. A duration of 0 means no deadline.

## Owner permissions (full disclosure)

The contract owner can do exactly one thing:

- `createPoll(question, options, durationSeconds)` — create a new poll.

The owner **cannot**:

- change, delete, or add votes;
- change results or tallies;
- close a poll early or extend it;
- withdraw or move any assets (the contract holds no funds and has no transfer functions);
- approve or move user tokens (there are no token approvals anywhere in the design).

The gate contract address is fixed at deployment time in the constructor and cannot be changed.

## Repository layout

- `src/AgentPoll.sol` — the poll contract.
- `src/MockAgentID.sol` — test double implementing only `balanceOf`; used for tests and for the
  BSC testnet deployment (the real Agent ID contract exists only on mainnet). Never for mainnet.
- `test/AgentPoll.t.sol` — Foundry test suite.
- `script/DeployTestnet.s.sol` — deploys MockAgentID + AgentPoll + one demo poll on BSC testnet.
- `frontend/` — static one-page frontend (vanilla HTML/JS + ethers.js from CDN). Wallet
  connection uses the standard `window.ethereum` provider; every write is confirmed in the
  user's own wallet. Contract address and chain settings live in `frontend/config.js`.

## Build & test

```sh
forge build
forge test
```

## Testnet deploy (BSC testnet, chainId 97)

```sh
forge script script/DeployTestnet.s.sol --rpc-url bsc_testnet --broadcast --private-key $PK
```

Then paste the deployed addresses into `frontend/config.js` (`pollAddress` and
`agentIdAddress` = the MockAgentID address on testnet).
