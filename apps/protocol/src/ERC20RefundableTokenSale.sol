// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Refundable.sol";
import "./interfaces/IERC20RefundableTokenSale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

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
    // Override claimable funds calculation
    // ---------------------------------------------------------------

    /// @notice Override to calculate claimable funds using the fixed purchase price
    function _claimableFunds() internal view override returns (uint256) {
        // Find what percent of the total refundable tokens are currently refundable
        uint256 currentlyRefundableTokens = _currentlyRefundable(_totalRefundableTokens, _totalRefundableBlockHeight);

        // Calculate locked funding using the purchase price
        uint256 lockedFunding = currentlyRefundableTokens * tokenSalePurchasePrice / (10 ** decimals());

        // The beneficiary can claim whatever is not locked for refunds
        return fundingTokensHeld > lockedFunding ? fundingTokensHeld - lockedFunding : 0;
    }

    // ---------------------------------------------------------------
    // Buyer actions
    // ---------------------------------------------------------------

    /// @notice Purchase tokens with funding token
    /// @param amount Number of tokens to purchase
    /// @param maxFundingAmount Expected amount of funding tokens to spend
    /// @return tokensPurchased Number of tokens purchased
    function purchase(uint256 amount, uint256 maxFundingAmount) external returns (uint256 tokensPurchased) {
        if (block.number < refundWindowStartBlock || block.number > tokenSaleEndBlock) {
            revert SaleNotActive();
        }
        if (amount > remainingTokensForSale) {
            revert InsufficientTokensForSale();
        }

        uint256 fundingTokenAmount = amount * tokenSalePurchasePrice / (10 ** decimals());

        if (fundingTokenAmount > maxFundingAmount) {
            revert MaxFundingAmountExceeded();
        }

        // Update remaining tokens for sale
        remainingTokensForSale -= amount;

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

        // Update total refundable tokens
        _totalRefundableTokens += refundableBalanceAtStart;
        _totalRefundableBlockHeight = uint64(block.number);

        emit Purchased(msg.sender, amount, fundingTokenAmount);

        return amount;
    }
}
