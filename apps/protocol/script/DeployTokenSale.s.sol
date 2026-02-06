// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20RefundableTokenSaleFactory} from "../src/ERC20RefundableTokenSaleFactory.sol";
import {ERC20RefundableTokenSale} from "../src/ERC20RefundableTokenSale.sol";
import {IERC20RefundableTokenSale} from "../src/interfaces/IERC20RefundableTokenSale.sol";

/// @notice Deploys a new token sale through the factory and creates a sale
/// @dev Run with: forge script script/DeployTokenSale.s.sol:DeployTokenSale --rpc-url <RPC_URL> --broadcast
/// @dev Required env vars: DEPLOYER_PRIVATE_KEY
contract DeployTokenSale is Script {
    function _createSale(ERC20RefundableTokenSale token) internal {
        uint256 saleAmount = 100_000 ether;
        uint256 purchasePrice = 1e5; // 0.1 USDC
        uint256 startBlock = block.number;
        uint256 endBlock = block.number + 100_000;
        uint64 bpsStart = 8000; // 80%
        uint64 decayDelay = 50; // 50 blocks (10 minutes)
        uint64 decayDuration = 100; // 100 blocks (2 days)
        uint64 additionalTokensReservedForLiquidityBps = 0;

        token.createSale(
            IERC20RefundableTokenSale.SaleParams({
                saleAmount: saleAmount,
                purchasePrice: purchasePrice,
                saleStartBlock: uint64(startBlock),
                saleEndBlock: uint64(endBlock),
                refundableDecayStartBlock: uint64(startBlock + decayDelay),
                refundableDecayEndBlock: uint64(startBlock + decayDelay + decayDuration),
                refundableBpsAtStart: bpsStart,
                additionalTokensReservedForLiquidityBps: additionalTokensReservedForLiquidityBps
            })
        );
    }

    function run() external returns (ERC20RefundableTokenSale token) {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get factory address from environment
        address factoryAddress = 0xF0d3Cc6ea346d35b4830f99Efeda99925AA8a056;
        ERC20RefundableTokenSaleFactory factory = ERC20RefundableTokenSaleFactory(factoryAddress);

        // Get required parameters
        address fundingToken = 0x036CbD53842c5426634e7929541eC2318f3dCF7e; // USDC on Base Sepolia
        address beneficiary = 0x6837047F46Da1d5d9A79846b25810b92adF456F6; // 1a35e1.eth

        string memory tokenName = "Clawbackable Labs";
        string memory tokenSymbol = "CLBK";
        uint256 maxSupply = 10_000_000 ether;

        // Deploy token through factory
        vm.startBroadcast(deployerPrivateKey);
        address tokenAddress =
            factory.deployRefundableToken(tokenName, tokenSymbol, maxSupply, beneficiary, fundingToken);
        vm.stopBroadcast();

        token = ERC20RefundableTokenSale(tokenAddress);

        console.log("\nToken deployed at:", tokenAddress);

        // Check if we should create a sale
        vm.startBroadcast(deployerPrivateKey);
        _createSale(token);
        vm.stopBroadcast();

        console.log("\n=== Deployment Summary ===");
        console.log("Token Address:", tokenAddress);
        console.log("Owner:", deployer);
        console.log("Beneficiary:", beneficiary);
        console.log("\nUsers can now purchase tokens by calling:");
        console.log("token.purchase(amount, maxFundingAmount)");

        return token;
    }
}
