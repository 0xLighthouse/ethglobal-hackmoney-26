// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20RefundableTokenSale} from "../src/ERC20RefundableTokenSale.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

/// @notice Deploys a new token sale through the factory and creates a sale
/// @dev Run with: forge script script/BuyTokens.s.sol:BuyTokens --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast
/// @dev Required env vars: DEPLOYER_PRIVATE_KEY
contract BuyTokens is Script {
    function run() external {
        // Get deployer from private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        address tokenAddress = 0xc4385a64760f2AeAF03D33f69c65a08c7E1C6bf2;
        ERC20RefundableTokenSale token = ERC20RefundableTokenSale(tokenAddress);

        address fundingTokenAddress = token.FUNDING_TOKEN();
        IERC20 fundingToken = IERC20(fundingTokenAddress);
        uint8 fundingTokenDecimals = IERC20Metadata(fundingTokenAddress).decimals();
        uint8 tokenDecimals = token.decimals();

        uint256 unitPrice = token.tokenSalePurchasePrice();

        uint256 tokens = 100 ether; // 100 tokens (10 USDC)
        uint256 grandTotal = tokens * unitPrice / (10 ** tokenDecimals);

        address buyer = vm.addr(deployerPrivateKey);
        uint256 buyerBalance = fundingToken.balanceOf(buyer);
        uint256 buyerAllowance = fundingToken.allowance(buyer, address(token));

        console.log("Buyer", buyer);
        console.log("Token", address(token));
        console.log("Funding token", fundingTokenAddress);
        console.log("Funding token decimals", fundingTokenDecimals);
        console.log("Token decimals", tokenDecimals);
        console.log("Unit price", unitPrice);
        console.log("Tokens requested", tokens);
        console.log("Grand total", grandTotal);
        console.log("Buyer balance", buyerBalance);
        console.log("Buyer allowance", buyerAllowance);

        // Buy tokens
        vm.startBroadcast(deployerPrivateKey);
        fundingToken.approve(address(token), grandTotal);
        token.purchase(tokens, grandTotal);
        vm.stopBroadcast();
    }
}
