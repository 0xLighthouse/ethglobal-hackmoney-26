// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {Currency} from "lib/cca/libraries/CurrencyLibrary.sol";

/// @notice Interface for the lockup vault
interface ILockupVault {
    /// @notice Emitted when a bid is registered for lockup
    /// @param bidId The bid id in the auction
    /// @param beneficiary The beneficiary who will receive the locked tokens
    /// @param trancheId The tranche id used for lockup duration
    event BidRegistered(uint256 indexed bidId, address indexed beneficiary, uint8 trancheId);

    /// @notice Emitted when a bid is exited and a refund is recorded
    /// @param bidId The bid id in the auction
    /// @param refundAmount The refund amount recorded for the bid
    event BidExited(uint256 indexed bidId, uint256 refundAmount);

    /// @notice Emitted when tokens are locked for a beneficiary
    /// @param beneficiary The beneficiary who will receive the locked tokens
    /// @param bidId The bid id in the auction
    /// @param amount The amount of tokens locked
    /// @param unlockTime The unix timestamp when the lockup matures
    event TokensLocked(address indexed beneficiary, uint256 indexed bidId, uint128 amount, uint64 unlockTime);

    /// @notice Emitted when a refund is claimed
    /// @param bidId The bid id in the auction
    /// @param beneficiary The beneficiary who claimed the refund
    /// @param amount The refund amount claimed
    event RefundClaimed(uint256 indexed bidId, address indexed beneficiary, uint256 amount);

    /// @notice Emitted when locked tokens are withdrawn
    /// @param beneficiary The beneficiary who withdrew the tokens
    /// @param amount The amount of tokens withdrawn
    event TokensWithdrawn(address indexed beneficiary, uint128 amount);

    /// @notice Error thrown when a caller is not the router
    /// @param caller The invalid caller
    error NotRouter(address caller);

    /// @notice Error thrown when a caller is not authorized
    /// @param caller The invalid caller
    error Unauthorized(address caller);

    /// @notice Error thrown when a tranche id is invalid
    /// @param trancheId The invalid tranche id
    error InvalidTranche(uint8 trancheId);

    /// @notice Error thrown when a bid is already registered
    /// @param bidId The bid id
    error BidAlreadyRegistered(uint256 bidId);

    /// @notice Error thrown when a bid is not registered
    /// @param bidId The bid id
    error BidNotRegistered(uint256 bidId);

    /// @notice Error thrown when a bid was already exited
    /// @param bidId The bid id
    error BidAlreadyExited(uint256 bidId);

    /// @notice Error thrown when a bid was already claimed
    /// @param bidId The bid id
    error BidAlreadyClaimed(uint256 bidId);

    /// @notice Error thrown when no refund is available for a bid
    /// @param bidId The bid id
    error NoRefund(uint256 bidId);

    /// @notice Error thrown when a lockup is not yet matured
    /// @param unlockTime The lockup unlock time
    error LockupNotMatured(uint64 unlockTime);

    /// @notice Error thrown when a lockup entry is empty
    /// @param index The lockup index
    error EmptyLockup(uint256 index);

    /// @notice Error thrown when a caller is not the owner
    /// @param caller The invalid caller
    error NotOwner(address caller);

    /// @notice Error thrown when the router is already set
    /// @param router The router already set
    error RouterAlreadySet(address router);

    /// @notice Error thrown when the router is not set
    error RouterNotSet();

    /// @notice Bid metadata tracked by the vault
    struct BidInfo {
        address beneficiary;
        uint8 trancheId;
        bool exited;
        bool claimed;
    }

    /// @notice A lockup entry
    struct Lockup {
        uint128 amount;
        uint64 unlockTime;
    }

    /// @notice Returns the auction instance
    function auction() external view returns (IContinuousClearingAuction);

    /// @notice Returns the router allowed to register bids
    function router() external view returns (address);

    /// @notice Returns the owner that can set the router
    function owner() external view returns (address);

    /// @notice Returns the token currency wrapper
    function token() external view returns (Currency);

    /// @notice Returns the bid currency wrapper
    function currency() external view returns (Currency);

    /// @notice Returns the lockup duration in seconds for a tranche
    /// @param trancheId The tranche id
    function lockupSeconds(uint256 trancheId) external view returns (uint32);

    /// @notice Returns bid info for a bid id
    /// @param bidId The bid id
    function bidInfo(uint256 bidId)
        external
        view
        returns (address beneficiary, uint8 trancheId, bool exited, bool claimed);

    /// @notice Returns the refund amount recorded for a bid
    /// @param bidId The bid id
    function bidRefund(uint256 bidId) external view returns (uint256);

    /// @notice Returns the tokens filled recorded for a bid
    /// @param bidId The bid id
    function bidTokensFilled(uint256 bidId) external view returns (uint256);

    /// @notice Returns a lockup entry by beneficiary and index
    /// @param beneficiary The beneficiary address
    /// @param index The lockup index
    function lockups(address beneficiary, uint256 index) external view returns (uint128 amount, uint64 unlockTime);

    /// @notice Sets the router address once
    /// @param router The router address
    function setRouter(address router) external;

    /// @notice Registers a bid after submission
    /// @param bidId The bid id
    /// @param beneficiary The beneficiary who will receive locked tokens
    /// @param trancheId The tranche id for lockup duration
    function registerBid(uint256 bidId, address beneficiary, uint8 trancheId) external;

    /// @notice Exits a fully filled bid
    /// @param bidId The bid id
    function exitBid(uint256 bidId) external;

    /// @notice Exits a partially filled bid
    /// @param bidId The bid id
    /// @param lastFullyFilledCheckpointBlock The last fully filled checkpoint block hint
    /// @param outbidBlock The outbid block hint
    function exitPartiallyFilledBid(uint256 bidId, uint64 lastFullyFilledCheckpointBlock, uint64 outbidBlock) external;

    /// @notice Claims tokens and locks them for the beneficiary
    /// @param bidId The bid id
    function claimAndLock(uint256 bidId) external;

    /// @notice Claims a refund for a bid
    /// @param bidId The bid id
    function claimRefund(uint256 bidId) external;

    /// @notice Withdraws a matured lockup
    /// @param index The lockup index
    function withdrawLocked(uint256 index) external;

    /// @notice Returns the number of lockups for a beneficiary
    /// @param beneficiary The beneficiary
    function lockupCount(address beneficiary) external view returns (uint256);
}
