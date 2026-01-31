// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ILockupVault} from "./ILockupVault.sol";

/// @notice Interface for the lockup bid router
interface ILockupBidRouter {
    /// @notice Error thrown when the currency is not native
    /// @param currency The invalid currency
    error CurrencyMustBeNative(address currency);

    /// @notice Error thrown when the beneficiary is the zero address
    error BeneficiaryCannotBeZeroAddress();

    /// @notice Error thrown when a caller is not the owner
    /// @param caller The invalid caller
    error NotOwner(address caller);

    /// @notice Error thrown when the vault is already set
    /// @param vault The vault already set
    error VaultAlreadySet(address vault);

    /// @notice Error thrown when the vault is not set
    error VaultNotSet();

    /// @notice Returns the auction instance
    function auction() external view returns (IContinuousClearingAuction);

    /// @notice Returns the lockup vault
    function vault() external view returns (ILockupVault);

    /// @notice Returns the owner that can set the vault
    function owner() external view returns (address);

    /// @notice Sets the vault address once
    /// @param vault The vault to set
    function setVault(ILockupVault vault) external;

    /// @notice Submits a bid with an explicit previous tick price
    /// @param trancheId The tranche id for lockup duration
    /// @param maxPrice The max price for the bid
    /// @param amount The bid amount
    /// @param prevTickPrice The previous tick price hint
    /// @param beneficiary The beneficiary who will receive locked tokens
    /// @return bidId The bid id
    function submitBid(
        uint8 trancheId,
        uint256 maxPrice,
        uint128 amount,
        uint256 prevTickPrice,
        address beneficiary
    ) external payable returns (uint256 bidId);

    /// @notice Submits a bid without a previous tick price
    /// @param trancheId The tranche id for lockup duration
    /// @param maxPrice The max price for the bid
    /// @param amount The bid amount
    /// @param beneficiary The beneficiary who will receive locked tokens
    /// @return bidId The bid id
    function submitBid(uint8 trancheId, uint256 maxPrice, uint128 amount, address beneficiary)
        external
        payable
        returns (uint256 bidId);
}
