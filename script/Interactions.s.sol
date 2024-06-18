// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "./../src/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "./../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract VRFSubscriptionFactory is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chain %s", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Subscription created with id %d", subId);
        console.log("NOTE** subscriptionId should be updated in HelperConfig");
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address linkToken,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(vrfCoordinator, subId, linkToken, deployerKey);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address linkToken,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription:", subId);
        console.log("\tUsing Coordinator:", vrfCoordinator);
        console.log("\tOn ChainId", block.chainid);
        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            console.log("Funding on Anvil chain");
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            console.log("Funding Seolia chain");
            vm.startBroadcast(deployerKey);
            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
        console.log("Subscription funded with %d LINK", FUND_AMOUNT);
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumer(
        address lottery,
        address vrfCoordinator,
        uint64 subId, // uint256 deployerKey
        uint256 deployerKey
    ) public {
        console.log("Adding consumer to lottery contract");
        console.log("Consumer added to lottery contract");
        console.log("SubscriptionId:", subId);
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, lottery);
        vm.stopBroadcast();
    }

    function addConsumerUserConfig(address lottery) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId, // uint256 deployerKey
            ,
            ,
            uint256 deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(lottery, vrfCoordinator, subId, deployerKey);
    }

    function run() public {
        address lottery = DevOpsTools.get_most_recent_deployment(
            "Lottery",
            block.chainid
        );
        addConsumerUserConfig(lottery);
    }
}
