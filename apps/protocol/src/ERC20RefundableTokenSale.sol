// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Refundable.sol";
import "./interfaces/IERC20RefundableTokenSale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {PoolId} from "v4-core/types/PoolId.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {TokenLiquidity} from "./libraries/TokenLiquidity.sol";

/// @notice ERC20 token with refundable purchase rights that decay over time and token sale functionality
contract ERC20RefundableTokenSale is Ownable(msg.sender), ERC20Refundable, IERC20RefundableTokenSale {
    // How many additional tokens are reserved to add liquidity
    uint256 public additionalTokensReservedForLiquidityBps;

    // Sale end block
    uint256 public tokenSaleEndBlock;

    // Tokens still available for the current sale
    uint256 public remainingTokensForSale;

    // Uniswap details
    IPoolManager public poolManager;
    IPositionManager public positionManager;
    PoolKey public poolKey;
    IAllowanceTransfer public permit2;

    bool private fundingTokenIsCurrency0;

    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address fundingToken,
        address beneficiary,
        address poolManager_,
        address positionManager_,
        address permit2_
    ) ERC20Refundable(name, symbol, maxSupply, beneficiary, fundingToken) {
        if (poolManager_ == address(0) || positionManager_ == address(0) || permit2_ == address(0)) return;

        // Deploy a pool for our new token
        poolManager = IPoolManager(poolManager_);
        positionManager = IPositionManager(positionManager_);
        permit2 = IAllowanceTransfer(permit2_);
        (poolKey, fundingTokenIsCurrency0) = TokenLiquidity.createPool(poolManager, fundingToken, address(this));
        emit PoolInitialized(address(this), fundingToken, PoolId.unwrap(poolKey.toId()));

        // Permit the max for both so we can use the position manager, because we trust permit2 (can optomize this later)
        _approve(address(this), address(permit2), type(uint256).max);
        IERC20(fundingToken).approve(address(permit2), type(uint256).max);
    }

    // ---------------------------------------------------------------
    // Owner actions
    // ---------------------------------------------------------------

    function createSale(SaleParams memory params) external onlyOwner {
        if (block.number <= refundableDecayEndBlock) {
            revert SaleInProgress();
        }
        // Sale start and end time must be valid and we can't commit more than 100% of the tokens being sold
        if (
            params.saleStartBlock > params.saleEndBlock || params.saleEndBlock > params.refundableDecayStartBlock
                || params.refundableDecayStartBlock > params.refundableDecayEndBlock
                || params.refundableBpsAtStart + params.additionalTokensReservedForLiquidityBps > 100_00
                || (poolManager == IPoolManager(address(0)) && params.additionalTokensReservedForLiquidityBps > 0)
        ) {
            revert SaleInvalid();
        }

        // We need to reserve the amount of tokens being sold, plus the additional tokens reserved for liquidity
        if (
            balanceOf(address(this))
                < params.saleAmount + params.saleAmount * params.additionalTokensReservedForLiquidityBps / 100_00
        ) {
            revert InsufficientTokensForSale();
        }

        if (fundingTokensHeld > 0) {
            // Send the beneficiary all the funding tokens that are unclaimed
            if (!IERC20(FUNDING_TOKEN).transfer(BENEFICIARY, fundingTokensHeld)) {
                revert ERC20TransferFailed();
            }
            fundingTokensHeld = 0;
        }

        _totalRefundableTokens = 0;
        _totalRefundableBlockHeight = uint64(block.number);

        remainingTokensForSale = params.saleAmount;
        tokenSalePurchasePrice = params.purchasePrice;
        additionalTokensReservedForLiquidityBps = params.additionalTokensReservedForLiquidityBps;
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

    /// @notice Purchase tokens with funding token
    /// @param amount Number of tokens to purchase
    /// @param maxFundingAmount Expected amount of funding tokens to spend
    /// @return tokensPurchased Number of tokens purchased
    function purchase(uint256 amount, uint256 maxFundingAmount) external returns (uint256 tokensPurchased) {
        if (block.number < refundWindowStartBlock || block.number > tokenSaleEndBlock) {
            revert SaleNotActive();
        }
        if (amount > remainingTokensForSale || amount > balanceOf(address(this))) {
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
        }

        // Record user's refundable balance
        uint256 refundableBalanceAtStart = amount * refundableBpsAtStart / 100_00;
        _refundableBalances[msg.sender].originalAmount = _refundableBalanceOf(msg.sender) + refundableBalanceAtStart;
        _refundableBalances[msg.sender].blockHeight = uint64(block.number);

        // Update total refundable tokens
        _totalRefundableTokens =
            _currentlyRefundable(_totalRefundableTokens, _totalRefundableBlockHeight) + refundableBalanceAtStart;
        _totalRefundableBlockHeight = uint64(block.number);

        emit Purchased(msg.sender, amount, fundingTokenAmount);

        // Add liquidity to the pool. We can use reservedBps worth of funding token we received, and an additional reservedBps of the tokens that were sold.
        if (additionalTokensReservedForLiquidityBps > 0) {
            TokenLiquidity.increaseLiquidity(
                poolManager,
                positionManager,
                permit2,
                poolKey,
                fundingTokenIsCurrency0,
                fundingTokenAmount * additionalTokensReservedForLiquidityBps / 100_00,
                amount * additionalTokensReservedForLiquidityBps / 100_00
            );
        }

        return amount;
    }
}
