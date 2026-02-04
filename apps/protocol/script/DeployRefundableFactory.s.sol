// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {MockERC20RefundableFactory} from "../test/mocks/MockERC20RefundableFactory.sol";

contract DeployRefundableFactory is Script {
    function run() external returns (MockERC20RefundableFactory factory) {
        console.log("=== Deploy MockERC20RefundableFactory ===");

        vm.startBroadcast();
        factory = new MockERC20RefundableFactory();
        vm.stopBroadcast();

        console.log("Deployer Address:");
        console.log("Factory:", address(factory));
    }
}
