// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IDistributionContract} from "ll/interfaces/IDistributionContract.sol";
import {IDistributionStrategy} from "ll/interfaces/IDistributionStrategy.sol";
import {AuctionParameters} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ILockupCCAFactory} from "./interfaces/ILockupCCAFactory.sol";
import {ILockupCCAInitializer} from "./interfaces/ILockupCCAInitializer.sol";
import {LockupCCAInitializer} from "./LockupCCAInitializer.sol";

/// @title LockupCCAFactory
/// @notice Factory for deploying lockup CCA initializers
contract LockupCCAFactory is ILockupCCAFactory {
    /// @inheritdoc IDistributionStrategy
    function initializeDistribution(address _token, uint256 _amount, bytes calldata _configData, bytes32)
        external
        override
        returns (IDistributionContract distributionContract)
    {
        if (_amount > type(uint128).max) revert InvalidAmount(_amount, type(uint128).max);

        (AuctionParameters memory auctionParameters, ILockupCCAInitializer.LockupParameters memory lockupParameters) =
            abi.decode(_configData, (AuctionParameters, ILockupCCAInitializer.LockupParameters));

        distributionContract = new LockupCCAInitializer(
            _token, uint128(_amount), auctionParameters, lockupParameters
        );
    }
}
