// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Lottery} from "@lottery/Lottery.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFSubscriptionFactory, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Lottery, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 entryFee,
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLaneKeyHash,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address linkToken // uint256 deployKey
        ) = helperConfig.activeNetworkConfig();

        if (subscriptionId == 0) {
            console.log("SubscriptionId not set, creating new subscription");
            VRFSubscriptionFactory subscriptionFactory = new VRFSubscriptionFactory();
            subscriptionId = subscriptionFactory.createSubscription(
                vrfCoordinator
            );

            console.log("Subscription created with id %d", subscriptionId);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                vrfCoordinator,
                subscriptionId,
                linkToken
            );
        }

        vm.startBroadcast();
        Lottery lottery = new Lottery(
            entryFee,
            interval,
            vrfCoordinator,
            gasLaneKeyHash,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        // Add a consumer to the VRF Coordinator
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(lottery),
            vrfCoordinator,
            subscriptionId
            // deployKey
        );

        return (lottery, helperConfig);
    }
}
