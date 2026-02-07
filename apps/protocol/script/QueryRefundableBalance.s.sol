// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {ERC20RefundableTokenSale} from "../src/ERC20RefundableTokenSale.sol";

/// @notice Query the refundable balance for a token holder
/// @dev Run with: TOKEN_ADDRESS=0x... HOLDER_ADDRESS=0x... forge script script/QueryRefundableBalance.s.sol:QueryRefundableBalance --rpc-url $BASE_SEPOLIA_RPC_URL
contract QueryRefundableBalance is Script {
    function run() external view {
        // Get addresses from environment variables
        address tokenAddress = 0x8B914D575cc3555fe5EFB044fB07A697f19f8B57;
        address holderAddress = 0x8DC791f24589F480fF31Fe654D09bD01B5c5c2E8;

        // Instantiate the token contract
        ERC20RefundableTokenSale token = ERC20RefundableTokenSale(tokenAddress);

        // Query the refundable balance
        uint256 balance = token.balanceOf(holderAddress);
        uint256 refundableBalance = token.refundableBalanceOf(holderAddress);

        // Display the result
        console.log("Token Contract:", tokenAddress);
        console.log("Holder Address:", holderAddress);
        console.log("Refundable Balance:", refundableBalance);
        console.log("Balance:", balance);
    }
}
