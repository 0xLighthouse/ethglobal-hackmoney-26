// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20Minimal} from "lib/cca/interfaces/external/IERC20Minimal.sol";
import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ISeedSplitter} from "./interfaces/ISeedSplitter.sol";
import {IPoolSeeder} from "./interfaces/IPoolSeeder.sol";

/// @title SeedSplitter
/// @notice Splits auction proceeds into pool seeding and treasury allocations
contract SeedSplitter is ISeedSplitter {
    uint24 public immutable poolSeedBps;
    address public immutable poolSeeder;
    address public immutable treasuryRecipient;
    address public immutable token;
    address public immutable currency;
    bytes public seedData;

    IContinuousClearingAuction public auction;
    bool private _distributed;

    constructor(
        address _token,
        address _currency,
        uint24 _poolSeedBps,
        address _poolSeeder,
        address _treasuryRecipient,
        bytes memory _seedData
    ) {
        if (_poolSeedBps > 10_000) revert InvalidSeedBps(_poolSeedBps);
        if (_poolSeedBps > 0 && _poolSeeder == address(0)) revert PoolSeederCannotBeZeroAddress();
        if (_treasuryRecipient == address(0)) revert TreasuryCannotBeZeroAddress();

        token = _token;
        currency = _currency;
        poolSeedBps = _poolSeedBps;
        poolSeeder = _poolSeeder;
        treasuryRecipient = _treasuryRecipient;
        seedData = _seedData;
    }

    /// @inheritdoc ISeedSplitter
    function setAuction(IContinuousClearingAuction _auction) external {
        if (address(auction) != address(0)) revert AuctionAlreadySet();
        auction = _auction;
        emit AuctionSet(address(_auction));
    }

    /// @inheritdoc ISeedSplitter
    function distribute() external {
        if (address(auction) == address(0)) revert AuctionNotSet();
        if (_distributed) revert AlreadyDistributed();

        uint256 balance = _currencyBalance();
        uint256 seedAmount = (balance * poolSeedBps) / 10_000;
        uint256 treasuryAmount = balance - seedAmount;

        if (seedAmount > 0) {
            _transferCurrency(poolSeeder, seedAmount);
            uint256 clearingPriceX96 = auction.lbpInitializationParams().initialPriceX96;
            IPoolSeeder(poolSeeder).seed(token, currency, seedAmount, clearingPriceX96, seedData);
        }

        if (treasuryAmount > 0) {
            _transferCurrency(treasuryRecipient, treasuryAmount);
        }

        _distributed = true;
        emit FundsDistributed(balance, seedAmount, treasuryAmount);
    }

    function _currencyBalance() internal view returns (uint256) {
        if (currency == address(0)) return address(this).balance;
        return IERC20Minimal(currency).balanceOf(address(this));
    }

    function _transferCurrency(address to, uint256 amount) internal {
        if (currency == address(0)) {
            (bool success, ) = to.call{value: amount}("");
            if (!success) revert NativeTransferFailed();
        } else {
            if (!IERC20Minimal(currency).transfer(to, amount)) revert ERC20TransferFailed();
        }
    }

    receive() external payable {}
}
