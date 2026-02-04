// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IERC20Refundable.sol";

/// @notice ERC20-compatible token transferable refund rights.
interface IERC20RefundableTokenSale is IERC20Refundable {
    // ---------------------------------------------------------------
    // Variables
    // ---------------------------------------------------------------
 
    // Purchase price in funding tokens
    function purchasePrice() external view returns (uint256);

    // Sale start block
    function saleStartBlock() external view returns (uint256);

    // Block number when the sale ends
    function saleEndBlock() external view returns (uint256);

    // ---------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------
    
    /// @notice Purchase tokens with funding token
    /// @param amount Amount of tokens to purchase
    /// @param maxFundingAmount Maximum amount of funding tokens to spend
    /// @return tokensPurchased Amount of tokens purchased
    function purchase(uint256 amount, uint256 maxFundingAmount) external returns (uint256 tokensPurchased);
    
// ---------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------
    
    /// @notice Set the purchase price
    /// @param newPurchasePrice New purchase price in funding tokens
    function setPurchasePrice(uint256 newPurchasePrice) external;
    
    /// @notice Set the sale start block
    /// @param newSaleStartBlock New sale start block
    function setSaleStartBlock(uint256 newSaleStartBlock) external;
    
    /// @notice Set the sale end block
    /// @param newSaleEndBlock New sale end block
    function setSaleEndBlock(uint256 newSaleEndBlock) external;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event Purchased(address indexed buyer, uint256 tokensPurchased, uint256 fundingAmountSpent);
    event PurchasePriceSet(uint256 newPurchasePrice);
    event SaleStartBlockSet(uint256 newSaleStartBlock);
    event SaleEndBlockSet(uint256 newSaleEndBlock);
}