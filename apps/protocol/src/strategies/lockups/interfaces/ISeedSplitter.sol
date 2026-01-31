// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";

/// @notice Interface for splitting auction proceeds between pool seeding and treasury
interface ISeedSplitter {
    /// @notice Emitted when the auction address is set
    /// @param auction The auction address
    event AuctionSet(address indexed auction);

    /// @notice Emitted when funds are distributed
    /// @param totalRaised The total amount distributed
    /// @param seedAmount The amount sent to the pool seeder
    /// @param treasuryAmount The amount sent to the treasury
    event FundsDistributed(uint256 totalRaised, uint256 seedAmount, uint256 treasuryAmount);

    /// @notice Error thrown when the split bps is invalid
    /// @param bps The invalid bps
    error InvalidSeedBps(uint24 bps);

    /// @notice Error thrown when the pool seeder is zero
    error PoolSeederCannotBeZeroAddress();

    /// @notice Error thrown when the treasury is zero
    error TreasuryCannotBeZeroAddress();

    /// @notice Error thrown when the auction is already set
    error AuctionAlreadySet();

    /// @notice Error thrown when the auction is not set
    error AuctionNotSet();

    /// @notice Error thrown when distribution was already executed
    error AlreadyDistributed();

    /// @notice Error thrown when a native transfer fails
    error NativeTransferFailed();

    /// @notice Error thrown when an ERC20 transfer fails
    error ERC20TransferFailed();

    /// @notice Returns the auction
    function auction() external view returns (IContinuousClearingAuction);

    /// @notice Returns the token being sold
    function token() external view returns (address);

    /// @notice Returns the currency being raised
    function currency() external view returns (address);

    /// @notice Returns the pool seeder address
    function poolSeeder() external view returns (address);

    /// @notice Returns the treasury recipient address
    function treasuryRecipient() external view returns (address);

    /// @notice Returns the seed bps
    function poolSeedBps() external view returns (uint24);

    /// @notice Returns the seed data
    function seedData() external view returns (bytes memory);

    /// @notice Sets the auction address once
    /// @param auction The auction address
    function setAuction(IContinuousClearingAuction auction) external;

    /// @notice Distributes funds to the pool seeder and treasury
    function distribute() external;
}
