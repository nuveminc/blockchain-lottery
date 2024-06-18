// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A toy lottery contract
 * @author 0xk4buk1
 * @notice This is a toy lottery contract which allows entrants to pay ETH to enter the lottery
 * and the winner is chosen randomly using Chainlink VRF after a certain spcified interval.
 * @dev Implements Chainlink VRFv2 Coordinator
 */
contract Lottery is VRFConsumerBaseV2 {
    error Lottery__NotEnoughEth();
    error Lottery__InternalNotMet();
    error Lottery__TransferFailed();
    error Lottery__LotteryNotOpen();
    error Lottery__UpdateSkipped(
        uint256 currentBalance,
        uint256 entrantsCount,
        uint256 lotteryState
    );

    /** Type declarations */
    enum LotteryState {
        OPEN, // 0
        CALCULATING // 1
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entryFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator; // should this be immutable?
    bytes32 private immutable i_gasLaneKeyHash;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    address payable[] private s_entrants;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;
    LotteryState private s_lotteryState;

    // does this use less gas and doesn't need to enumerate array?
    // uint256 private s_lotteryId;
    // mapping(uint256 lotteryId => address entrant) private s_entrantToTicket;

    /**
     * Events
     */
    event LotteryEntered(address indexed entrant);
    event WinnerChosen(address indexed winner);
    event RequestedWinner(uint256 indexed requestId);

    constructor(
        uint256 entryFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLaneKeyHash,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entryFee = entryFee;
        i_interval = interval;
        i_subscriptionId = subscriptionId;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLaneKeyHash = gasLaneKeyHash;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;
    }

    /**
     * @dev Function to enter the lottery
     * @notice This function allows users to enter the lottery
     * @notice This function emits the LotteryEntered event
     */
    function addEntry() public payable {
        if (msg.value < i_entryFee) {
            revert Lottery__NotEnoughEth();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Lottery__LotteryNotOpen();
        }
        s_entrants.push(payable(msg.sender));
        emit LotteryEntered(msg.sender);
    }

    /**
     * @dev Function that is called by Chainlink Automation node to check if the contract needs to be updated
     * The following should be true for this call to return true:
     * 1. The lottery is in OPEN state
     * 2. The interval has passed
     * 3. There are entrants (ETH)
     * 4. Subscription is funded
     * @return upkeepNeeded
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool intervalPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool isOpen = LotteryState.OPEN == s_lotteryState;
        bool hasEntrants = s_entrants.length > 0;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isOpen && intervalPassed && hasEntrants && hasBalance);
        return (upkeepNeeded, "0x0");
    }

    /**
     * @dev Function that is called by Chainlink Automation node to update the contract
     * The Chainlink Automation node will peform a callback to fulfillRandomWords with the random number.
     * This function is only called by checkUpkeep if it returns true. The check in this function is redundant.
     * 1. Set the lottery state to CALCULATING
     * 2. Request random number from Chainlink VRF
     */
    function performUpkeep(bytes calldata /* performData */) external {
        (bool update, ) = checkUpkeep("");
        if (!update) {
            revert Lottery__UpdateSkipped(
                address(this).balance,
                s_entrants.length,
                uint256(s_lotteryState)
            );
        }
        s_lotteryState = LotteryState.CALCULATING;
        // 1. Request random number (RNG)
        // Will revert if subscription is not set and funded.
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLaneKeyHash, // gas lane
            i_subscriptionId, //  id funded with link
            REQUEST_CONFIRMATIONS, // block confirmations
            i_callbackGasLimit, // gas limit - limit overspending
            NUM_WORDS // number of words
        );
        emit RequestedWinner(requestId);
    }

    /**
     * @notice This function is called by the VRF Coordinator
     * @dev This function is called by the VRF Coordinator
     * @param randomWords The random words
     */
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_entrants.length;
        address payable winner = s_entrants[indexOfWinner];
        s_recentWinner = winner;
        s_entrants = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_lotteryState = LotteryState.OPEN;
        emit WinnerChosen(winner);
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Lottery__TransferFailed();
        }
    }

    /**
     * Getter Functions
     */
    function getEntryFee() public view returns (uint256) {
        return i_entryFee;
    }

    function getState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    function getEntrantCount() public view returns (uint256) {
        return s_entrants.length;
    }

    function getLastWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }
}
