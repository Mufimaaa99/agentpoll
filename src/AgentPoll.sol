// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Minimal interface for the Agent ID contract (SPACE ID Agent ID, ERC-721).
/// @dev The real contract is NOT ERC721Enumerable, so only `balanceOf` is used.
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title AgentPoll — Sybil-resistant on-chain polls for Agent ID holders.
/// @notice One Agent ID = one vote per poll. The contract holds NO funds,
///         performs NO token approvals, and the owner can only create polls:
///         the owner cannot alter votes, change results, or close a poll early.
contract AgentPoll {
    struct Poll {
        string question;
        string[] options;
        uint256[] counts; // votes per option index
        uint64 closesAt; // unix timestamp; type(uint64).max = no deadline
        bool exists;
    }

    IAgentID public immutable agentId;
    address public immutable owner;

    Poll[] private _polls;
    mapping(uint256 => mapping(address => bool)) private _hasVoted;
    mapping(uint256 => mapping(address => uint256)) private _choiceOf;

    event PollCreated(uint256 indexed pollId, string question, uint64 closesAt);
    event Voted(uint256 indexed pollId, address indexed voter, uint256 optionIndex);

    error NotOwner();
    error BadOptionCount();
    error EmptyQuestion();
    error PollNotFound();
    error PollClosed();
    error BadOptionIndex();
    error AlreadyVoted();
    error NoAgentId();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    /// @param agentIdContract Address of the Agent ID contract used as the voting gate.
    ///        Mainnet BSC: 0x60b9262456de011f7d15a54cdd8c48baaa8b022f
    constructor(address agentIdContract) {
        agentId = IAgentID(agentIdContract);
        owner = msg.sender;
    }

    /// @notice Create a new poll. Owner only.
    /// @param question The poll question.
    /// @param options 2–5 answer options.
    /// @param durationSeconds Voting window in seconds; 0 = no deadline.
    function createPoll(string calldata question, string[] calldata options, uint64 durationSeconds)
        external
        onlyOwner
        returns (uint256 pollId)
    {
        if (bytes(question).length == 0) revert EmptyQuestion();
        if (options.length < 2 || options.length > 5) revert BadOptionCount();

        pollId = _polls.length;
        Poll storage p = _polls.push();
        p.question = question;
        for (uint256 i = 0; i < options.length; i++) {
            p.options.push(options[i]);
        }
        p.counts = new uint256[](options.length);
        p.closesAt = durationSeconds == 0 ? type(uint64).max : uint64(block.timestamp) + durationSeconds;
        p.exists = true;

        emit PollCreated(pollId, question, p.closesAt);
    }

    /// @notice Cast a vote. Requires holding at least 1 Agent ID.
    ///         One address = one vote per poll; a vote cannot be changed.
    function vote(uint256 pollId, uint256 optionIndex) external {
        if (pollId >= _polls.length) revert PollNotFound();
        Poll storage p = _polls[pollId];
        if (block.timestamp > p.closesAt) revert PollClosed();
        if (optionIndex >= p.options.length) revert BadOptionIndex();
        if (_hasVoted[pollId][msg.sender]) revert AlreadyVoted();
        if (agentId.balanceOf(msg.sender) == 0) revert NoAgentId();

        _hasVoted[pollId][msg.sender] = true;
        _choiceOf[pollId][msg.sender] = optionIndex;
        p.counts[optionIndex] += 1;

        emit Voted(pollId, msg.sender, optionIndex);
    }

    // ---------- Views (used by the frontend) ----------

    function pollCount() external view returns (uint256) {
        return _polls.length;
    }

    function getPoll(uint256 pollId)
        external
        view
        returns (string memory question, string[] memory options, uint64 closesAt, uint256 totalVotes)
    {
        if (pollId >= _polls.length) revert PollNotFound();
        Poll storage p = _polls[pollId];
        question = p.question;
        options = p.options;
        closesAt = p.closesAt;
        for (uint256 i = 0; i < p.counts.length; i++) {
            totalVotes += p.counts[i];
        }
    }

    function getResults(uint256 pollId) external view returns (uint256[] memory counts) {
        if (pollId >= _polls.length) revert PollNotFound();
        return _polls[pollId].counts;
    }

    function hasVoted(uint256 pollId, address voter) external view returns (bool) {
        if (pollId >= _polls.length) return false;
        return _hasVoted[pollId][voter];
    }

    function choiceOf(uint256 pollId, address voter) external view returns (bool voted, uint256 optionIndex) {
        voted = _hasVoted[pollId][voter];
        optionIndex = _choiceOf[pollId][voter];
    }

    function isOpen(uint256 pollId) external view returns (bool) {
        if (pollId >= _polls.length) return false;
        return block.timestamp <= _polls[pollId].closesAt;
    }
}
