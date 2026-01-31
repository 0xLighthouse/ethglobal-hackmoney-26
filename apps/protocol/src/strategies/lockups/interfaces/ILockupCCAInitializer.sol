// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IDistributionContract} from "ll/interfaces/IDistributionContract.sol";
import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ILockupValidationHook} from "./ILockupValidationHook.sol";
import {ILockupBidRouter} from "./ILockupBidRouter.sol";
import {ILockupVault} from "./ILockupVault.sol";
import {AuctionParameters} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ISeedSplitter} from "./ISeedSplitter.sol";

/// @notice Interface for the lockup CCA initializer
interface ILockupCCAInitializer is IDistributionContract {
    /// @notice Emitted when the validation hook is deployed
    /// @param hook The hook address
    event HookDeployed(address indexed hook);

    /// @notice Emitted when the auction is deployed
    /// @param auction The auction address
    event AuctionDeployed(address indexed auction);

    /// @notice Emitted when the lockup vault is deployed
    /// @param vault The vault address
    event VaultDeployed(address indexed vault);

    /// @notice Emitted when the bid router is deployed
    /// @param router The router address
    event RouterDeployed(address indexed router);

    /// @notice Emitted when the seed splitter is deployed
    /// @param splitter The splitter address
    event SeedSplitterDeployed(address indexed splitter);

    /// @notice Error thrown when the currency is not native
    /// @param currency The invalid currency
    error CurrencyMustBeNative(address currency);

    /// @notice Error thrown when tokens were already received
    error TokensAlreadyReceived();

    /// @notice Error thrown when token balance is insufficient
    /// @param expected The expected token amount
    /// @param received The actual token balance
    error InvalidTokenAmountReceived(uint256 expected, uint256 received);

    /// @notice Returns the token address
    function token() external view returns (address);

    /// @notice Returns the total supply to distribute
    function totalSupply() external view returns (uint128);

    /// @notice Returns the auction parameters
    function auctionParameters() external view returns (AuctionParameters memory);

    /// @notice Seed configuration for optional pool seeding
    struct SeedConfig {
        uint24 poolSeedBps;
        address poolSeeder;
        address treasuryRecipient;
        bytes seedData;
    }

    /// @notice Lockup parameters for a distribution
    struct LockupParameters {
        uint128[4] trancheCaps;
        uint32[4] lockupMonths;
        SeedConfig seedConfig;
    }

    /// @notice Returns the lockup parameters
    function lockupParameters() external view returns (LockupParameters memory);

    /// @notice Returns the tranche caps
    function trancheCaps(uint256 trancheId) external view returns (uint128);

    /// @notice Returns the lockup months
    function lockupMonths(uint256 trancheId) external view returns (uint32);

    /// @notice Returns the deployed auction
    function auction() external view returns (IContinuousClearingAuction);

    /// @notice Returns the deployed hook
    function hook() external view returns (ILockupValidationHook);

    /// @notice Returns the deployed router
    function router() external view returns (ILockupBidRouter);

    /// @notice Returns the deployed vault
    function vault() external view returns (ILockupVault);

    /// @notice Returns the deployed seed splitter
    function seedSplitter() external view returns (ISeedSplitter);
}
