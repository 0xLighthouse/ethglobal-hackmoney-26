// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Refundable.sol";
import "./interfaces/IERC20RefundableTokenSale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @notice ERC20 token with refundable purchase rights that decay over time and token sale functionality
contract ERC20RefundableTokenSale is Ownable(msg.sender), ERC20Refundable, IERC20RefundableTokenSale {
    // Purchase price in funding tokens
    uint256 public tokenSalePurchasePrice;

    // Sale end block
    uint256 public tokenSaleEndBlock;

    uint256 public remainingTokensForSale;

    constructor(string memory name, string memory symbol, uint256 maxSupply, address fundingToken, address beneficiary)
        ERC20Refundable(name, symbol, maxSupply, beneficiary, fundingToken)
    {}

    // ---------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------

    function createSale(SaleParams memory params) external onlyOwner {
        if (block.number <= refundableDecayEndBlock) {
            revert SaleInProgress();
        }
        // Sale start and end time must be valid and there must be enough tokens to sell
        if (params.saleStartBlock > params.saleEndBlock || balanceOf(address(this)) < params.saleAmount) {
            revert SaleInvalid();
        }

        _totalRefundableTokens = 0;
        _totalRefundableBlockHeight = uint64(block.number);

        remainingTokensForSale = params.saleAmount;
        tokenSalePurchasePrice = params.purchasePrice;
        refundWindowStartBlock = params.saleStartBlock;
        tokenSaleEndBlock = params.saleEndBlock;
        refundableDecayStartBlock = params.refundableDecayStartBlock;
        refundableDecayEndBlock = params.refundableDecayEndBlock;
        refundableBpsAtStart = params.refundableBpsAtStart;

        emit SaleCreated(params.saleAmount, params.purchasePrice, params.saleStartBlock, params.saleEndBlock);
    }

    function endSale() external onlyOwner {
        tokenSaleEndBlock = block.number < tokenSaleEndBlock ? block.number : tokenSaleEndBlock;
    }

    // ---------------------------------------------------------------
    // Buyer actions
    // ---------------------------------------------------------------

    function purchase(uint256 amount, uint256 maxFundingAmount) external returns (uint256 tokensPurchased) {
        if (block.number < refundWindowStartBlock || block.number > tokenSaleEndBlock) {
            revert SaleNotActive();
        }
        if (amount > remainingTokensForSale) {
            revert InsufficientTokensForSale();
        }
        uint256 fundingTokenAmount = amount * tokenSalePurchasePrice;
        if (fundingTokenAmount > maxFundingAmount) {
            revert MaxFundingAmountExceeded();
        }

        // Transfer funding tokens from buyer to contract
        if (!IERC20(FUNDING_TOKEN).transferFrom(msg.sender, address(this), fundingTokenAmount)) {
            revert ERC20TransferFailed();
        }
        fundingTokensHeld += fundingTokenAmount;

        // Give user tokens
        _transfer(address(this), msg.sender, amount);

        // Clear any old state if it exists
        if (_refundableBalances[msg.sender].blockHeight < refundWindowStartBlock) {
            _refundableBalances[msg.sender].originalAmount = 0;
            _refundableBalances[msg.sender].purchasePrice = 0;
        }

        // Record user's refundable balance
        uint256 refundableBalanceAtStart = amount * refundableBpsAtStart / 100_00;
        _refundableBalances[msg.sender].originalAmount += refundableBalanceAtStart;
        _refundableBalances[msg.sender].purchasePrice = tokenSalePurchasePrice;
        _refundableBalances[msg.sender].blockHeight = uint64(block.number);

        emit Purchased(msg.sender, amount, fundingTokenAmount);
    }
}
