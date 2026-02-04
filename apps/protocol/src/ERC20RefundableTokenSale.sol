// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Refundable.sol";
import "./interfaces/IERC20RefundableTokenSale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC20 token with refundable purchase rights that decay over time and token sale functionality
contract ERC20RefundableTokenSale is Ownable(msg.sender), ERC20Refundable, IERC20RefundableTokenSale {

    // Purchase price in funding tokens
    uint256 public purchasePrice;

    // Sale start block
    uint256 public saleStartBlock;

    // Sale end block
    uint256 public saleEndBlock;

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address fundingToken,
        address beneficiary
   ) ERC20Refundable(name, symbol, maxSupply, beneficiary, fundingToken) {
    }

    // ---------------------------------------------------------------
    // User Actions
    // ---------------------------------------------------------------

    /// @notice Purchase tokens with funding token
    /// @dev Allows users to buy tokens during the sale period
    /// @param amount Amount of tokens to purchase
    /// @param maxFundingAmount Maximum amount of funding tokens willing to spend (slippage protection)
    /// @return tokensPurchased Actual amount of tokens purchased
    function purchase(uint256 amount, uint256 maxFundingAmount) external returns (uint256 tokensPurchased) {
        // TODO: Implement purchase logic
        // 1. Verify sale is active (block.number >= saleStartBlock && block.number <= saleEndBlock)
        // 2. Calculate funding amount required (amount * purchasePrice)
        // 3. Verify funding amount doesn't exceed maxFundingAmount
        // 4. Transfer funding tokens from buyer to contract
        // 5. Mint tokens to buyer
        // 6. Update refundable balance tracking (_refundableBalances)
        // 7. Update totalFundingDeposited
        // 8. Emit Purchased event
    }

    // ---------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------

    /// @notice Set the purchase price
    /// @param newPurchasePrice New purchase price in funding tokens
    function setPurchasePrice(uint256 newPurchasePrice) external onlyOwner {
        purchasePrice = newPurchasePrice;
        emit PurchasePriceSet(newPurchasePrice);
    }

    /// @notice Set the sale start block
    /// @param newSaleStartBlock New sale start block
    function setSaleStartBlock(uint256 newSaleStartBlock) external onlyOwner {
        saleStartBlock = newSaleStartBlock;
        emit SaleStartBlockSet(newSaleStartBlock);
    }

    /// @notice Set the sale end block
    /// @param newSaleEndBlock New sale end block
    function setSaleEndBlock(uint256 newSaleEndBlock) external onlyOwner {
        saleEndBlock = newSaleEndBlock;
        emit SaleEndBlockSet(newSaleEndBlock);
    }
}


// Create sale: Cant' start unless previous one is ended
// When tokens are sold, add price to totalFundingDeposited
// At start of sale, resent total refundable tokens to 0