// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ILockupBidRouter} from "./interfaces/ILockupBidRouter.sol";
import {ILockupVault} from "./interfaces/ILockupVault.sol";

/// @title LockupBidRouter
/// @notice Routes bids to a lockup vault and supplies hook data for validation
/// @dev Compatible with native currency (address(0)) auctions
contract LockupBidRouter is ILockupBidRouter {

    IContinuousClearingAuction public immutable auction;
    ILockupVault public vault;
    address public immutable owner;

    constructor(IContinuousClearingAuction _auction, address _currency) {
        auction = _auction;
        owner = msg.sender;

        if (_currency != address(0)) {
            revert CurrencyMustBeNative(_currency);
        }
    }

    /// @inheritdoc ILockupBidRouter
    function setVault(ILockupVault _vault) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (address(vault) != address(0)) revert VaultAlreadySet(address(vault));
        vault = _vault;
    }

    /// @inheritdoc ILockupBidRouter
    function submitBid(
        uint8 trancheId,
        uint256 maxPrice,
        uint128 amount,
        uint256 prevTickPrice,
        address beneficiary
    ) external payable returns (uint256 bidId) {
        if (address(vault) == address(0)) revert VaultNotSet();
        if (beneficiary == address(0)) revert BeneficiaryCannotBeZeroAddress();

        bytes memory hookData = abi.encode(trancheId, beneficiary);
        bidId = auction.submitBid{value: msg.value}(maxPrice, amount, address(vault), prevTickPrice, hookData);

        vault.registerBid(bidId, beneficiary, trancheId);
    }

    /// @inheritdoc ILockupBidRouter
    function submitBid(uint8 trancheId, uint256 maxPrice, uint128 amount, address beneficiary)
        external
        payable
        returns (uint256 bidId)
    {
        if (address(vault) == address(0)) revert VaultNotSet();
        if (beneficiary == address(0)) revert BeneficiaryCannotBeZeroAddress();

        bytes memory hookData = abi.encode(trancheId, beneficiary);
        bidId = auction.submitBid{value: msg.value}(maxPrice, amount, address(vault), hookData);

        vault.registerBid(bidId, beneficiary, trancheId);
    }
}
