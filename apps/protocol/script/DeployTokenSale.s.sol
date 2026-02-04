// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20Factory} from "../src/ERC20Factory.sol";
import {ERC20RefundableTokenSale} from "../src/ERC20RefundableTokenSale.sol";
import {IERC20RefundableTokenSale} from "../src/interfaces/IERC20RefundableTokenSale.sol";

/// @notice Deploys a new token sale through the factory and creates a sale
/// @dev Run with: forge script script/DeployTokenSale.s.sol:DeployTokenSale --rpc-url <RPC_URL> --broadcast
/// @dev Required env vars: PRIVATE_KEY, FACTORY_ADDRESS, FUNDING_TOKEN, BENEFICIARY
/// @dev Optional env vars: TOKEN_NAME, TOKEN_SYMBOL, MAX_SUPPLY, SALE_AMOUNT, PURCHASE_PRICE, etc.
contract DeployTokenSale is Script {
    function _createSale(ERC20RefundableTokenSale token) internal {
        uint256 saleAmount = vm.envOr("SALE_AMOUNT", uint256(100_000 ether));
        uint256 purchasePrice = vm.envOr("PURCHASE_PRICE", uint256(1));
        uint256 startBlock = vm.envOr("SALE_START_BLOCK", uint256(block.number));
        uint256 endBlock = vm.envOr("SALE_END_BLOCK", uint256(block.number + 100_000));
        uint64 bpsStart = uint64(vm.envOr("REFUNDABLE_BPS_START", uint256(8000)));
        uint64 decayDelay = uint64(vm.envOr("REFUNDABLE_DECAY_DELAY", uint256(43_200)));
        uint64 decayDuration = uint64(vm.envOr("REFUNDABLE_DECAY_DURATION", uint256(86_400)));

        console.log("Sale Amount:", saleAmount);
        console.log("Purchase Price:", purchasePrice);
        console.log("Sale Start Block:", startBlock);
        console.log("Sale End Block:", endBlock);

        token.createSale(
            IERC20RefundableTokenSale.SaleParams({
                saleAmount: saleAmount,
                purchasePrice: purchasePrice,
                saleStartBlock: uint64(startBlock),
                saleEndBlock: uint64(endBlock),
                refundableDecayStartBlock: uint64(startBlock + decayDelay),
                refundableDecayEndBlock: uint64(startBlock + decayDelay + decayDuration),
                refundableBpsAtStart: bpsStart
            })
        );
    }

    function run() external returns (ERC20RefundableTokenSale token) {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get factory address from environment
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        ERC20Factory factory = ERC20Factory(factoryAddress);

        // Get required parameters
        address fundingToken = vm.envAddress("FUNDING_TOKEN");
        address beneficiary = vm.envAddress("BENEFICIARY");

        // Get optional parameters with defaults
        string memory tokenName = vm.envOr("TOKEN_NAME", string("Refundable Token"));
        string memory tokenSymbol = vm.envOr("TOKEN_SYMBOL", string("RTOKEN"));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(1_000_000 ether));

        console.log("Deploying Token Sale...");
        console.log("Deployer:", deployer);
        console.log("Factory:", factoryAddress);
        console.log("Funding Token:", fundingToken);
        console.log("Beneficiary:", beneficiary);
        console.log("Token Name:", tokenName);
        console.log("Token Symbol:", tokenSymbol);
        console.log("Max Supply:", maxSupply);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy token through factory
        address tokenAddress = factory.deployRefundableToken(
            tokenName,
            tokenSymbol,
            maxSupply,
            beneficiary,
            fundingToken
        );

        token = ERC20RefundableTokenSale(tokenAddress);

        console.log("\nToken deployed at:", tokenAddress);

        // Check if we should create a sale
        if (vm.envOr("CREATE_SALE", false)) {
            console.log("\nCreating token sale...");

            _createSale(token);

            console.log("Sale created successfully!");
        }

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
