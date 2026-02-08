// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

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
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

library TokenLiquidity {
    using StateLibrary for IPoolManager;

    function createPool(IPoolManager poolManager, address fundingToken, address thisToken)
        external
        returns (PoolKey memory poolKey, bool fundingTokenIsCurrency0)
    {
        // Start with a 1:1 price
        uint160 sqrtPriceX96 = 79228162514264337593543950336;

        // If our funding token uses 6 decimals (USDC)...
        bool fundingTokenSixDecimals = (IERC20Metadata(fundingToken).decimals() == 6);

        // Sort tokens and adjust starting price for 1:1 if using 6 decimals
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
    }

    function _amounts(bool fundingTokenIsCurrency0, uint256 fundingTokenAmount, uint256 thisTokenAmount)
        private
        pure
        returns (uint256 token0Amount, uint256 token1Amount)
    {
        if (fundingTokenIsCurrency0) {
            return (fundingTokenAmount, thisTokenAmount);
        }
        return (thisTokenAmount, fundingTokenAmount);
    }

    function _computeLiquidity(
        IPoolManager poolManager,
        PoolKey memory poolKey,
        uint256 token0Amount,
        uint256 token1Amount
    ) private view returns (uint128 liquidity, int24 tickLower, int24 tickUpper) {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());
        tickLower = TickMath.minUsableTick(poolKey.tickSpacing);
        tickUpper = TickMath.maxUsableTick(poolKey.tickSpacing);

        uint160 sqrtRatioAX96 = TickMath.getSqrtPriceAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtPriceAtTick(tickUpper);

        liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, token0Amount, token1Amount
        );
    }

    function _approve(IAllowanceTransfer permit2, Currency currency, IPositionManager positionManager, uint256 amount)
        private
    {
        permit2.approve(
            Currency.unwrap(currency), address(positionManager), uint160(amount), uint48(block.timestamp + 3600)
        );
    }

    function increaseLiquidity(
        IPoolManager poolManager,
        IPositionManager positionManager,
        IAllowanceTransfer permit2,
        PoolKey memory poolKey,
        bool fundingTokenIsCurrency0,
        uint256 fundingTokenAmount,
        uint256 thisTokenAmount
    ) external {
        (uint256 token0Amount, uint256 token1Amount) =
            _amounts(fundingTokenIsCurrency0, fundingTokenAmount, thisTokenAmount);

        (uint128 liquidity, int24 tickLower, int24 tickUpper) =
            _computeLiquidity(poolManager, poolKey, token0Amount, token1Amount);

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

        _approve(permit2, poolKey.currency0, positionManager, token0Amount);
        _approve(permit2, poolKey.currency1, positionManager, token1Amount);

        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        uint256 deadline = block.timestamp + 60;
        positionManager.modifyLiquidities(abi.encode(actions, params), deadline);
    }
}
