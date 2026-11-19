// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AgentPoll} from "../src/AgentPoll.sol";
import {MockAgentID} from "../src/MockAgentID.sol";

/// @notice Testnet deploy: MockAgentID (gate) + AgentPoll + one demo poll.
///         Run: forge script script/DeployTestnet.s.sol --rpc-url bsc_testnet --broadcast --private-key $PK
contract DeployTestnet is Script {
    function run() external {
        vm.startBroadcast();

        MockAgentID mock = new MockAgentID();
        AgentPoll poll = new AgentPoll(address(mock));

        // Make the deployer a "holder" on the mock so the demo poll can be voted on.
        mock.setBalance(msg.sender, 1);

        string[] memory opts = new string[](3);
        opts[0] = "Yes";
        opts[1] = "No";
        opts[2] = "Not sure yet";
        poll.createPoll("Should Agent ID holders get one-person-one-vote polls?", opts, 7 days);

        vm.stopBroadcast();

        console.log("MockAgentID:", address(mock));
        console.log("AgentPoll:  ", address(poll));
    }
}
