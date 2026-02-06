// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20RefundableTokenSaleFactory} from "../src/ERC20RefundableTokenSaleFactory.sol";

/// @notice Deploys the ERC20RefundableTokenSaleFactory contract
/// @dev Run with: forge script script/DeployFactory.s.sol:DeployFactory --rpc-url <RPC_URL> --broadcast --verify
contract DeployFactory is Script {
    function run() external returns (ERC20RefundableTokenSaleFactory factory) {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying ERC20RefundableTokenSaleFactory...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Get pool manager address from environment
        address poolManager = vm.envAddress("POOL_MANAGER");
        address positionManager = vm.envAddress("POSITION_MANAGER");
        address permit2 = vm.envAddress("PERMIT2");

        // Deploy the factory
        factory = new ERC20RefundableTokenSaleFactory(poolManager, positionManager, permit2);

        vm.stopBroadcast();

        console.log("ERC20RefundableTokenSaleFactory deployed at:", address(factory));
        console.log("\nSave this address for deploying token sales!");
        console.log("export FACTORY_ADDRESS=%s", address(factory));

        return factory;
    }
}
