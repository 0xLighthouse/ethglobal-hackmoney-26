// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20Refundable.sol";
import "./interfaces/IERC20RefundableTokenSale.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {Currency} from "v4-core/types/Currency.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {StateLibrary} from "v4-core/libraries/StateLibrary.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {IPositionManager} from "v4-periphery/interfaces/IPositionManager.sol";
import {LiquidityAmounts} from "v4-periphery/libraries/LiquidityAmounts.sol";
import {TickMath} from "v4-core/libraries/TickMath.sol";
import {Actions} from "v4-periphery/libraries/Actions.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";

/// @notice ERC20 token with refundable purchase rights that decay over time and token sale functionality
contract ERC20RefundableTokenSale is Ownable(msg.sender), ERC20Refundable, IERC20RefundableTokenSale {
    using StateLibrary for IPoolManager;

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
        // Start with a 1:1 price
        uint160 sqrtPriceX96 = 79228162514264337593543950336;

        // If our funding token uses 6 decimals (USDC)...
        bool fundingTokenSixDecimals = (IERC20Metadata(fundingToken).decimals() == 6);

        // Sort tokens and adjust starting price for 1:1 if using 6 decimals
        address thisToken = address(this);
        Currency currency0;
        Currency currency1;
        if (fundingToken < thisToken) {
            currency0 = Currency.wrap(fundingToken);
            currency1 = Currency.wrap(thisToken);
            fundingTokenIsCurrency0 = true;
            if (fundingTokenSixDecimals) {
                sqrtPriceX96 = 79228162514264337593543; // sqrt(1e-12) * 2^96
            }
        } else {
            currency0 = Currency.wrap(thisToken);
            currency1 = Currency.wrap(fundingToken);
            if (fundingTokenSixDecimals) {
                sqrtPriceX96 = 79228162514264337593543950336000000; // sqrt(1e12) * 2^96
            }
        }

        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0)) // TODO: add this when we have a hook contract
        });

        poolManager.initialize(poolKey, sqrtPriceX96);

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
            params.saleStartBlock > params.saleEndBlock
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
            _increaseLiquidity(
                fundingTokenAmount * additionalTokensReservedForLiquidityBps / 100_00,
                amount * additionalTokensReservedForLiquidityBps / 100_00
            );
        }

        return amount;
    }

    // We need to find the most liquidity we can deposit using the assets we have
    function _increaseLiquidity(uint256 fundingTokenAmount, uint256 thisTokenAmount) internal {
        // Determine token ordering
        uint256 token0Amount;
        uint256 token1Amount;
        if (fundingTokenIsCurrency0) {
            token0Amount = fundingTokenAmount;
            token1Amount = thisTokenAmount;
        } else {
            token0Amount = thisTokenAmount;
            token1Amount = fundingTokenAmount;
        }

        // Get pool state and prices
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());

        int24 tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        int24 tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        // Use the minimum of the two
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, token0Amount, token1Amount
        );

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);

        params[0] = abi.encode(
            poolKey,
            tickLower,
            tickUpper,
            liquidity,
            token0Amount,
            token1Amount,
            address(this),
            bytes("") // Hook data
        );

        IAllowanceTransfer(permit2).approve(
            Currency.unwrap(poolKey.currency0),
            address(positionManager),
            uint160(token0Amount),
            uint48(block.timestamp + 3600)
        );

        IAllowanceTransfer(permit2).approve(
            Currency.unwrap(poolKey.currency1),
            address(positionManager),
            uint160(token1Amount),
            uint48(block.timestamp + 3600)
        );

        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        uint256 deadline = block.timestamp + 60;
        IPositionManager(positionManager).modifyLiquidities(abi.encode(actions, params), deadline);
    }
}
