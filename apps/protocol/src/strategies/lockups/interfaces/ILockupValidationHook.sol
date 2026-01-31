// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IValidationHook} from "lib/cca/interfaces/IValidationHook.sol";

/// @notice Interface for the lockup validation hook
interface ILockupValidationHook is IValidationHook {
    /// @notice Error thrown when the caller is not the auction
    /// @param caller The invalid caller
    error OnlyAuction(address caller);

    /// @notice Error thrown when the sender is not the router
    /// @param sender The invalid sender
    error OnlyRouter(address sender);

    /// @notice Error thrown when the owner is not the vault
    /// @param owner The invalid owner
    error InvalidOwner(address owner);

    /// @notice Error thrown when the reserve price is not met
    /// @param maxPrice The submitted max price
    /// @param reservePrice The reserve price
    error ReservePriceNotMet(uint256 maxPrice, uint256 reservePrice);

    /// @notice Error thrown when the tranche id is invalid
    /// @param trancheId The invalid tranche id
    error InvalidTranche(uint8 trancheId);

    /// @notice Error thrown when a tranche cap is exceeded
    /// @param trancheId The tranche id
    /// @param attempted The attempted total used amount
    /// @param cap The tranche cap
    error TrancheCapExceeded(uint8 trancheId, uint128 attempted, uint128 cap);

    /// @notice Error thrown when the beneficiary is zero
    error BeneficiaryCannotBeZeroAddress();

    /// @notice Error thrown when a caller is not the owner
    /// @param caller The invalid caller
    error NotOwner(address caller);

    /// @notice Error thrown when the hook is already initialized
    error AlreadyInitialized();

    /// @notice Error thrown when the hook is not initialized
    error NotInitialized();

    /// @notice Error thrown when an address is zero
    error InvalidAddress();

    /// @notice Returns the auction address
    function auction() external view returns (address);

    /// @notice Returns the router address
    function router() external view returns (address);

    /// @notice Returns the vault address
    function vault() external view returns (address);

    /// @notice Returns the owner address
    function owner() external view returns (address);

    /// @notice Returns whether the hook is initialized
    function initialized() external view returns (bool);

    /// @notice Returns the reserve price in Q96
    function reservePriceX96() external view returns (uint256);

    /// @notice Returns the tranche cap for a tranche id
    /// @param trancheId The tranche id
    function trancheCaps(uint256 trancheId) external view returns (uint128);

    /// @notice Returns the tranche used amount for a tranche id
    /// @param trancheId The tranche id
    function trancheUsed(uint256 trancheId) external view returns (uint128);

    /// @notice Initializes the hook once
    /// @param auction The auction address
    /// @param router The router address
    /// @param vault The vault address
    function initialize(address auction, address router, address vault) external;
}
