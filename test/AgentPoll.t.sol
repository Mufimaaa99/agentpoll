// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AgentPoll} from "../src/AgentPoll.sol";
import {MockAgentID} from "../src/MockAgentID.sol";

contract AgentPollTest is Test {
    MockAgentID internal mock;
    AgentPoll internal poll;

    address internal owner = address(this);
    address internal alice = makeAddr("alice"); // Agent ID holder
    address internal bob = makeAddr("bob"); // Agent ID holder
    address internal carol = makeAddr("carol"); // non-holder
    address internal dave = makeAddr("dave"); // non-owner holder

    function setUp() public {
        mock = new MockAgentID();
        poll = new AgentPoll(address(mock));
        mock.setBalance(alice, 1);
        mock.setBalance(bob, 1);
        mock.setBalance(dave, 2);
        // carol: balance 0 (non-holder)
    }

    function _options() internal pure returns (string[] memory opts) {
        opts = new string[](3);
        opts[0] = "Yes";
        opts[1] = "No";
        opts[2] = "Abstain";
    }

    function _createDefault() internal returns (uint256 id) {
        id = poll.createPoll("Ship it?", _options(), 1 days);
    }

    // ---------- createPoll ----------

    function test_OwnerCanCreatePoll() public {
        uint256 id = _createDefault();
        assertEq(id, 0);
        assertEq(poll.pollCount(), 1);
        (string memory q, string[] memory opts, uint64 closesAt, uint256 total) = poll.getPoll(id);
        assertEq(q, "Ship it?");
        assertEq(opts.length, 3);
        assertEq(opts[0], "Yes");
        assertGt(closesAt, uint64(block.timestamp));
        assertEq(total, 0);
    }

    function test_CreatePollEmitsEvent() public {
        vm.expectEmit(true, false, false, false);
        emit AgentPoll.PollCreated(0, "Ship it?", 0);
        _createDefault();
    }

    function test_NonOwnerCannotCreatePoll() public {
        vm.prank(dave);
        vm.expectRevert(AgentPoll.NotOwner.selector);
        poll.createPoll("Nope?", _options(), 1 days);
    }

    function test_CreatePollTooFewOptionsReverts() public {
        string[] memory one = new string[](1);
        one[0] = "Only";
        vm.expectRevert(AgentPoll.BadOptionCount.selector);
        poll.createPoll("Bad?", one, 1 days);
    }

    function test_CreatePollTooManyOptionsReverts() public {
        string[] memory six = new string[](6);
        for (uint256 i = 0; i < 6; i++) six[i] = "x";
        vm.expectRevert(AgentPoll.BadOptionCount.selector);
        poll.createPoll("Bad?", six, 1 days);
    }

    function test_CreatePollFiveOptionsOk() public {
        string[] memory five = new string[](5);
        five[0] = "a";
        five[1] = "b";
        five[2] = "c";
        five[3] = "d";
        five[4] = "e";
        uint256 id = poll.createPoll("Five?", five, 0); // 0 duration = no deadline
        (, , uint64 closesAt, ) = poll.getPoll(id);
        assertEq(closesAt, type(uint64).max);
        assertTrue(poll.isOpen(id));
    }

    // ---------- vote ----------

    function test_HolderCanVote() public {
        uint256 id = _createDefault();
        vm.expectEmit(true, true, false, true);
        emit AgentPoll.Voted(id, alice, 0);
        vm.prank(alice);
        poll.vote(id, 0);
        assertTrue(poll.hasVoted(id, alice));
        uint256[] memory counts = poll.getResults(id);
        assertEq(counts[0], 1);
        assertEq(counts[1], 0);
    }

    function test_NonHolderCannotVote() public {
        uint256 id = _createDefault();
        vm.prank(carol);
        vm.expectRevert(AgentPoll.NoAgentId.selector);
        poll.vote(id, 0);
        assertFalse(poll.hasVoted(id, carol));
    }

    function test_DoubleVoteReverts() public {
        uint256 id = _createDefault();
        vm.startPrank(alice);
        poll.vote(id, 1);
        vm.expectRevert(AgentPoll.AlreadyVoted.selector);
        poll.vote(id, 2); // even a different option must fail
        vm.stopPrank();
    }

    function test_TallyIsCorrect() public {
        uint256 id = _createDefault();
        vm.prank(alice);
        poll.vote(id, 0);
        vm.prank(bob);
        poll.vote(id, 0);
        vm.prank(dave);
        poll.vote(id, 2);

        uint256[] memory counts = poll.getResults(id);
        assertEq(counts[0], 2);
        assertEq(counts[1], 0);
        assertEq(counts[2], 1);

        (, , , uint256 total) = poll.getPoll(id);
        assertEq(total, 3);

        (bool voted, uint256 choice) = poll.choiceOf(id, dave);
        assertTrue(voted);
        assertEq(choice, 2);
    }

    function test_VoteAfterCloseReverts() public {
        uint256 id = poll.createPoll("Short?", _options(), 1 hours);
        vm.warp(block.timestamp + 2 hours);
        assertFalse(poll.isOpen(id));
        vm.prank(alice);
        vm.expectRevert(AgentPoll.PollClosed.selector);
        poll.vote(id, 0);
    }

    function test_VoteBadOptionIndexReverts() public {
        uint256 id = _createDefault();
        vm.prank(alice);
        vm.expectRevert(AgentPoll.BadOptionIndex.selector);
        poll.vote(id, 3);
    }

    function test_VoteUnknownPollReverts() public {
        vm.prank(alice);
        vm.expectRevert(AgentPoll.PollNotFound.selector);
        poll.vote(99, 0);
    }

    function test_VotesArePerPoll() public {
        uint256 a = _createDefault();
        uint256 b = poll.createPoll("Second?", _options(), 1 days);
        vm.startPrank(alice);
        poll.vote(a, 0);
        poll.vote(b, 1); // same voter, different poll: allowed
        vm.stopPrank();
        assertTrue(poll.hasVoted(a, alice));
        assertTrue(poll.hasVoted(b, alice));
    }

    function test_OwnerHasNoSpecialVotingPower() public {
        // Owner holds no Agent ID in this setup, so owner cannot vote either,
        // and there is no function to alter results.
        uint256 id = _createDefault();
        vm.expectRevert(AgentPoll.NoAgentId.selector);
        poll.vote(id, 0);
    }
}
