// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";

/// @notice Deploys the TokenLiquidity library
/// @dev Run with: forge script script/DeployTokenLiquidity.s.sol:DeployTokenLiquidity --rpc-url <RPC_URL> --broadcast
contract DeployTokenLiquidity is Script {
    function run() external returns (address libraryAddress) {
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying TokenLiquidity library...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);
        libraryAddress = vm.deployCode("src/libraries/TokenLiquidity.sol:TokenLiquidity");
        vm.stopBroadcast();

        console.log("TokenLiquidity deployed at:", libraryAddress);
        console.log("export TOKEN_LIQUIDITY_LIB=%s", libraryAddress);

        return libraryAddress;
    }
}
