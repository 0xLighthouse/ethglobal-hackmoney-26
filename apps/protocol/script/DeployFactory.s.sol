// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20RefundableTokenSaleFactory} from "../src/ERC20RefundableTokenSaleFactory.sol";

/// @notice Deploys the ERC20RefundableTokenSaleFactory contract
/// @dev Deploy TokenLiquidity first, then link it when running this script:
/// @dev forge script script/DeployFactory.s.sol:DeployFactory --rpc-url <RPC_URL> --broadcast --verify \
/// @dev   --libraries src/libraries/TokenLiquidity.sol:TokenLiquidity:<TOKEN_LIQUIDITY_LIB>
contract DeployFactory is Script {

    // Base Sepolia
    address public sepoliaPoolManager = 0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408;
    address public sepoliaPositionManager = 0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80;
    address public sepoliaPermit2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    function run() external returns (ERC20RefundableTokenSaleFactory factory) {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("Deploying ERC20RefundableTokenSaleFactory...");
        console.log("Deployer address:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Get pool manager address from environment
        address poolManager = sepoliaPoolManager;
        address positionManager = sepoliaPositionManager;
        address permit2 = sepoliaPermit2;

        // Deploy the factory (will revert if TokenLiquidity is not linked)
        bytes memory args = abi.encode(poolManager, positionManager, permit2);
        address factoryAddress = vm.deployCode(
            "ERC20RefundableTokenSaleFactory.sol:ERC20RefundableTokenSaleFactory",
            args
        );
        factory = ERC20RefundableTokenSaleFactory(factoryAddress);

        vm.stopBroadcast();

        console.log("ERC20RefundableTokenSaleFactory deployed at:", address(factory));
        console.log("\nSave this address for deploying token sales!");
        console.log("export FACTORY_ADDRESS=%s", address(factory));

        return factory;
    }
}
