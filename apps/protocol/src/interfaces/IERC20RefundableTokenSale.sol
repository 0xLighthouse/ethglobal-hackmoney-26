// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC20Refundable.sol";

/// @notice ERC20-compatible token transferable refund rights.
interface IERC20RefundableTokenSale is IERC20Refundable {
    // ---------------------------------------------------------------
    // Variables
    // ---------------------------------------------------------------

    // Purchase price in funding tokens
    function tokenSalePurchasePrice() external view returns (uint256);

    // Block number when the sale ends
    function tokenSaleEndBlock() external view returns (uint256);

    // Remaining tokens available for sale
    function remainingTokensForSale() external view returns (uint256);

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

    struct SaleParams {
        uint256 saleAmount;
        uint256 purchasePrice;
        uint64 saleStartBlock;
        uint64 saleEndBlock;
        uint64 refundableDecayStartBlock;
        uint64 refundableDecayEndBlock;
        uint64 refundableBpsAtStart;
    }

    /// @notice Create a new token sale
    /// @param params Sale parameters including amount, price, and timing
    function createSale(SaleParams memory params) external;

    /// @notice End the sale early
    function endSale() external;

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    event SaleCreated(uint256 amount, uint256 purchasePrice, uint256 saleStartBlock, uint256 saleEndBlock);
    event Purchased(address indexed buyer, uint256 tokensPurchased, uint256 fundingAmountSpent);

    error SaleInProgress();
    error SaleInvalid();
    error SaleNotActive();
    error MaxFundingAmountExceeded();
    error InsufficientTokensForSale();
}
