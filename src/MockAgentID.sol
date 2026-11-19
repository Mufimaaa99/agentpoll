// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title MockAgentID — test double for the Agent ID contract.
/// @notice Only implements `balanceOf`, which is the single function AgentPoll
///         relies on. Balances can be set freely so tests and the BSC-testnet
///         deployment can simulate holders / non-holders. NEVER use on mainnet.
contract MockAgentID {
    mapping(address => uint256) private _balances;

    function setBalance(address account, uint256 amount) external {
        _balances[account] = amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }
}
