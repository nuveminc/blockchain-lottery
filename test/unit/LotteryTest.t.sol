// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {DeployLottery} from "./../../script/DeployLottery.s.sol";
import {HelperConfig} from "./../../script/HelperConfig.s.sol";
import {Lottery} from "./../../src/Lottery.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract LotteryTest is Test {
    uint256 public constant ENTRANT_STARTING_BALANCE = 10 ether;

    Lottery public lottery;
    HelperConfig public helperConfig;
    address public ENTRANT = makeAddr("entrant");

    uint256 private entryFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private gasLaneKeyHash;
    uint64 private subscriptionId;
    uint32 private callbackGasLimit;
    address private linkToken;

    /* Events */
    event LotteryEntered(address indexed entrant);

    /* Modifiers */
    modifier enterAndTimetravelForward() {
        vm.prank(ENTRANT);
        lottery.addEntry{value: entryFee}();
        // mock setting the block timestamp
        vm.warp(block.timestamp + interval + 1);
        // mock roll forward the block height to next block
        vm.roll(block.number + 1);
        _;
    }

    modifier timetravelForward() {
        // mock setting the block timestamp
        vm.warp(block.timestamp + interval + 1);
        // mock roll forward the block height to next block
        vm.roll(block.number + 1);
        _;
    }

    modifier skipForkedNetwork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function setUp() external {
        DeployLottery deployer = new DeployLottery();
        (lottery, helperConfig) = deployer.run();
        (
            entryFee,
            interval,
            vrfCoordinator,
            gasLaneKeyHash,
            subscriptionId,
            callbackGasLimit,
            linkToken,

        ) = helperConfig.activeNetworkConfig();
        vm.deal(ENTRANT, ENTRANT_STARTING_BALANCE);
    }

    function testIntializedInOpenState() public view {
        assert(lottery.getState() == Lottery.LotteryState.OPEN);
    }

    function testRevertWhenNoEth() public {
        vm.prank(ENTRANT);
        vm.expectRevert(Lottery.Lottery__NotEnoughEth.selector);
        lottery.addEntry();
    }

    function testRevertWhenNotEnoughEth() public {
        vm.prank(ENTRANT);
        vm.expectRevert(Lottery.Lottery__NotEnoughEth.selector);
        lottery.addEntry{value: .01 ether}();
    }

    function testAddsEntry() public {
        vm.prank(ENTRANT);
        lottery.addEntry{value: entryFee}();
        assert(lottery.getEntrantCount() == 1);
    }

    function testEmitsEventOnEntry() public {
        vm.prank(ENTRANT);
        vm.expectEmit(true, false, false, false, address(lottery));
        emit LotteryEntered(ENTRANT);
        lottery.addEntry{value: entryFee}();
    }

    function testLotteryNotOpen() public enterAndTimetravelForward {
        lottery.performUpKeep("");
        vm.prank(ENTRANT);
        vm.expectRevert(Lottery.Lottery__LotteryNotOpen.selector);
        lottery.addEntry{value: entryFee}();
    }

    /** Check Upkeep */

    function testCheckUpKeepFalseIfNoBalance() public timetravelForward {
        (bool update, ) = lottery.checkUpKeep("");

        assert(update == false);
    }

    function testCheckUpKeepFalseIfLotteryCalculating()
        public
        enterAndTimetravelForward
    {
        lottery.performUpKeep("");

        (bool update, ) = lottery.checkUpKeep("");

        assert(lottery.getState() == Lottery.LotteryState.CALCULATING);
        assert(update == false);
    }

    function testPerformUpKeepWhenCheckUpKeepIsTrueWhenTimetravelForward()
        public
        enterAndTimetravelForward
    {
        // Assert
        lottery.performUpKeep("");
        assert(lottery.getState() == Lottery.LotteryState.CALCULATING);
    }

    function testPerformUpKeepRevertsWhenCheckUpKeepIsFalse() public {
        uint256 balance = 0;
        uint256 entrants = 0;
        uint256 state = uint256(Lottery.LotteryState.OPEN);
        // Expect revert with parameters
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.Lottery__UpdateSkipped.selector,
                balance,
                entrants,
                state
            )
        );
        lottery.performUpKeep("");
    }

    function testPerformUpkeepUpdatesLotteryAndEmitsRequestId()
        public
        enterAndTimetravelForward
    {
        // Act
        vm.recordLogs();
        lottery.performUpKeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // remove the last log

        Lottery.LotteryState state = lottery.getState();

        // Assert
        assert(uint256(requestId) > 0);
        assert(state == Lottery.LotteryState.CALCULATING);
    }

    // Uses "fuzzing" within testing by passing in an argument
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public enterAndTimetravelForward skipForkedNetwork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(lottery)
        );
    }

    function testFulfillRandomWorksSelectsAWinnerAndSendsFunds()
        public
        enterAndTimetravelForward
        skipForkedNetwork
    {
        // Arrange
        uint256 entrants = 5;
        for (uint256 i = 0; i < entrants; i++) {
            address entrant = address(uint160(i));
            // is setting the user ("prank") and "dealing" them a starting balance
            hoax(entrant, ENTRANT_STARTING_BALANCE);
            lottery.addEntry{value: entryFee}();
        }

        uint256 lotteryBalance = address(lottery).balance;
        uint256 prize = (entrants + 1) * entryFee;

        vm.recordLogs();
        lottery.performUpKeep("");

        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1]; // remove the last log

        uint256 previousTimestamp = lottery.getLastTimestamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(lottery)
        );

        // Assert
        assert(lottery.getState() == Lottery.LotteryState.OPEN);
        assert(lottery.getLastWinner() != address(0));
        assert(lottery.getEntrantCount() == 0);
        assert(lottery.getLastTimestamp() > previousTimestamp);
        assert(address(lottery).balance == 0);
        console.log("Lottery Balance", lotteryBalance);
        console.log("Starting balance", ENTRANT_STARTING_BALANCE);
        console.log("Prize", prize);
        console.log("Winner balance", lottery.getLastWinner().balance);
        assert(
            (lottery.getLastWinner().balance) ==
                (ENTRANT_STARTING_BALANCE + prize - entryFee)
        );
    }
}
