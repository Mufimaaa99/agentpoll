// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentPoll} from "../src/AgentPoll.sol";

/// @notice Mainnet deploy: AgentPoll gated by the REAL Agent ID contract
///         (SPACE ID Agent ID, BSC mainnet) + the first live poll.
///         Run: forge script script/DeployMainnet.s.sol --rpc-url https://bsc-dataseed.binance.org --broadcast --private-key $PK
contract DeployMainnet is Script {
    address internal constant AGENT_ID = 0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F;

    function run() external {
        vm.startBroadcast();

        AgentPoll poll = new AgentPoll(AGENT_ID);

        string[] memory opts = new string[](3);
        opts[0] = "Yes";
        opts[1] = "No";
        opts[2] = "Not sure yet";
        poll.createPoll("Will BNB reach a new all-time high before the end of 2026?", opts, 7 days);

        vm.stopBroadcast();

        console.log("AgentPoll (mainnet):", address(poll));
        console.log("Gate (Agent ID):    ", AGENT_ID);
    }
}
