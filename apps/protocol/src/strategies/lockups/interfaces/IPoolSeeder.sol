// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @notice Interface for pool seeding logic
interface IPoolSeeder {
    /// @notice Seed liquidity using the provided currency amount and clearing price
    /// @param token The token being sold in the auction
    /// @param currency The currency raised in the auction
    /// @param amount The currency amount to seed with
    /// @param clearingPriceX96 The final clearing price in Q96
    /// @param seedData Opaque data for v3/v4/new/existing pool selection
    function seed(
        address token,
        address currency,
        uint256 amount,
        uint256 clearingPriceX96,
        bytes calldata seedData
    ) external;
}
