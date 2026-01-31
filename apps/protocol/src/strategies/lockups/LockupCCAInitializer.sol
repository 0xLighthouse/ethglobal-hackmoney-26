// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20Minimal} from "lib/cca/interfaces/external/IERC20Minimal.sol";
import {IContinuousClearingAuction, AuctionParameters} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ContinuousClearingAuction} from "lib/cca/ContinuousClearingAuction.sol";
import {Currency, CurrencyLibrary} from "lib/cca/libraries/CurrencyLibrary.sol";
import {IDistributionContract} from "ll/interfaces/IDistributionContract.sol";
import {ILockupCCAInitializer} from "./interfaces/ILockupCCAInitializer.sol";
import {ISeedSplitter} from "./interfaces/ISeedSplitter.sol";
import {ILockupValidationHook} from "./interfaces/ILockupValidationHook.sol";
import {ILockupBidRouter} from "./interfaces/ILockupBidRouter.sol";
import {ILockupVault} from "./interfaces/ILockupVault.sol";
import {LockupValidationHook} from "./LockupValidationHook.sol";
import {LockupBidRouter} from "./LockupBidRouter.sol";
import {LockupVault} from "./LockupVault.sol";
import {SeedSplitter} from "./SeedSplitter.sol";

/// @title LockupCCAInitializer
/// @notice Deploys a CCA and lockup components, then transfers tokens to the auction
contract LockupCCAInitializer is ILockupCCAInitializer {
    using CurrencyLibrary for Currency;

    address public immutable token;
    uint128 public immutable totalSupply;
    AuctionParameters private _auctionParameters;
    LockupParameters private _lockupParameters;
    uint128[4] public trancheCaps;
    uint32[4] public lockupMonths;

    IContinuousClearingAuction public auction;
    ILockupValidationHook public hook;
    ILockupBidRouter public router;
    ILockupVault public vault;
    ISeedSplitter public seedSplitter;

    bool private _tokensReceived;

    constructor(
        address _token,
        uint128 _totalSupply,
        AuctionParameters memory auctionParameters_,
        LockupParameters memory lockupParameters_
    ) {
        if (auctionParameters_.currency != address(0)) revert CurrencyMustBeNative(auctionParameters_.currency);

        token = _token;
        totalSupply = _totalSupply;
        trancheCaps = lockupParameters_.trancheCaps;
        lockupMonths = lockupParameters_.lockupMonths;
        _lockupParameters = lockupParameters_;

        hook = new LockupValidationHook(auctionParameters_.floorPrice, lockupParameters_.trancheCaps);
        emit HookDeployed(address(hook));

        if (lockupParameters_.seedConfig.poolSeedBps > 0) {
            SeedSplitter splitter = new SeedSplitter(
                _token,
                auctionParameters_.currency,
                lockupParameters_.seedConfig.poolSeedBps,
                lockupParameters_.seedConfig.poolSeeder,
                lockupParameters_.seedConfig.treasuryRecipient,
                lockupParameters_.seedConfig.seedData
            );
            seedSplitter = splitter;
            emit SeedSplitterDeployed(address(splitter));
            auctionParameters_.fundsRecipient = address(splitter);
        }

        auctionParameters_.validationHook = address(hook);
        _auctionParameters = auctionParameters_;
    }

    /// @inheritdoc IDistributionContract
    function onTokensReceived() external override {
        if (_tokensReceived) revert TokensAlreadyReceived();

        uint256 balance = IERC20Minimal(token).balanceOf(address(this));
        if (balance < totalSupply) revert InvalidTokenAmountReceived(totalSupply, balance);

        IContinuousClearingAuction _auction = new ContinuousClearingAuction(token, totalSupply, _auctionParameters);
        auction = _auction;
        emit AuctionDeployed(address(_auction));

        vault = new LockupVault(_auction, token, _auctionParameters.currency, lockupMonths);
        emit VaultDeployed(address(vault));

        router = new LockupBidRouter(_auction, _auctionParameters.currency);
        emit RouterDeployed(address(router));

        vault.setRouter(address(router));
        router.setVault(vault);
        hook.initialize(address(_auction), address(router), address(vault));

        Currency.wrap(token).transfer(address(_auction), totalSupply);
        _auction.onTokensReceived();

        if (address(seedSplitter) != address(0)) {
            seedSplitter.setAuction(_auction);
        }

        _tokensReceived = true;
    }

    /// @inheritdoc ILockupCCAInitializer
    function auctionParameters() external view override returns (AuctionParameters memory) {
        return _auctionParameters;
    }

    /// @inheritdoc ILockupCCAInitializer
    function lockupParameters() external view override returns (LockupParameters memory) {
        return _lockupParameters;
    }
}
