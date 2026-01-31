// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {Currency, CurrencyLibrary} from "lib/cca/libraries/CurrencyLibrary.sol";
import {ILockupVault} from "./interfaces/ILockupVault.sol";

/// @title LockupVault
/// @notice Holds claimed tokens and refunds, enforcing tranche-based lockups per offering
contract LockupVault is ILockupVault {
    using CurrencyLibrary for Currency;

    IContinuousClearingAuction public immutable auction;
    address public router;
    address public immutable owner;
    Currency public immutable token;
    Currency public immutable currency;

    uint32[4] public lockupSeconds;

    mapping(uint256 => BidInfo) public bidInfo;
    mapping(uint256 => uint256) public bidRefund;
    mapping(uint256 => uint256) public bidTokensFilled;
    mapping(address => Lockup[]) public lockups;

    constructor(
        IContinuousClearingAuction _auction,
        address _token,
        address _currency,
        uint32[4] memory _lockupMonths
    ) {
        auction = _auction;
        owner = msg.sender;
        token = Currency.wrap(_token);
        currency = Currency.wrap(_currency);

        for (uint256 i = 0; i < 4; i++) {
            lockupSeconds[i] = uint32(uint256(_lockupMonths[i]) * 30 days);
        }
    }

    /// @inheritdoc ILockupVault
    function setRouter(address _router) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (router != address(0)) revert RouterAlreadySet(router);
        router = _router;
    }

    /// @inheritdoc ILockupVault
    function registerBid(uint256 bidId, address beneficiary, uint8 trancheId) external {
        if (router == address(0)) revert RouterNotSet();
        if (msg.sender != router) revert NotRouter(msg.sender);
        if (trancheId >= 4) revert InvalidTranche(trancheId);
        if (bidInfo[bidId].beneficiary != address(0)) revert BidAlreadyRegistered(bidId);

        bidInfo[bidId] = BidInfo({beneficiary: beneficiary, trancheId: trancheId, exited: false, claimed: false});
        emit BidRegistered(bidId, beneficiary, trancheId);
    }

    /// @inheritdoc ILockupVault
    function exitBid(uint256 bidId) external {
        _exitBid(bidId, 0, 0, false);
    }

    /// @inheritdoc ILockupVault
    function exitPartiallyFilledBid(uint256 bidId, uint64 lastFullyFilledCheckpointBlock, uint64 outbidBlock) external {
        _exitBid(bidId, lastFullyFilledCheckpointBlock, outbidBlock, true);
    }

    /// @inheritdoc ILockupVault
    function claimAndLock(uint256 bidId) external {
        BidInfo storage info = bidInfo[bidId];
        if (info.beneficiary == address(0)) revert BidNotRegistered(bidId);
        if (msg.sender != router && msg.sender != info.beneficiary) revert Unauthorized(msg.sender);
        if (info.claimed) revert BidAlreadyClaimed(bidId);

        uint256 tokensFilled = bidTokensFilled[bidId];
        if (tokensFilled == 0) {
            tokensFilled = auction.bids(bidId).tokensFilled;
            if (tokensFilled > 0) {
                bidTokensFilled[bidId] = tokensFilled;
            }
        }

        auction.claimTokens(bidId);
        info.claimed = true;

        if (tokensFilled > 0) {
            uint64 unlockTime = uint64(block.timestamp + lockupSeconds[info.trancheId]);
            lockups[info.beneficiary].push(
                Lockup({amount: uint128(tokensFilled), unlockTime: unlockTime})
            );
            emit TokensLocked(info.beneficiary, bidId, uint128(tokensFilled), unlockTime);
        }
    }

    /// @inheritdoc ILockupVault
    function claimRefund(uint256 bidId) external {
        BidInfo memory info = bidInfo[bidId];
        if (info.beneficiary == address(0)) revert BidNotRegistered(bidId);
        if (msg.sender != info.beneficiary) revert Unauthorized(msg.sender);

        uint256 refund = bidRefund[bidId];
        if (refund == 0) revert NoRefund(bidId);
        bidRefund[bidId] = 0;

        currency.transfer(msg.sender, refund);
        emit RefundClaimed(bidId, msg.sender, refund);
    }

    /// @inheritdoc ILockupVault
    function withdrawLocked(uint256 index) external {
        Lockup storage lockup = lockups[msg.sender][index];
        if (lockup.amount == 0) revert EmptyLockup(index);
        if (block.timestamp < lockup.unlockTime) revert LockupNotMatured(lockup.unlockTime);

        uint128 amount = lockup.amount;
        lockup.amount = 0;

        token.transfer(msg.sender, amount);
        emit TokensWithdrawn(msg.sender, amount);
    }

    /// @inheritdoc ILockupVault
    function lockupCount(address beneficiary) external view returns (uint256) {
        return lockups[beneficiary].length;
    }

    function _exitBid(
        uint256 bidId,
        uint64 lastFullyFilledCheckpointBlock,
        uint64 outbidBlock,
        bool isPartial
    ) internal {
        BidInfo storage info = bidInfo[bidId];
        if (info.beneficiary == address(0)) revert BidNotRegistered(bidId);
        if (msg.sender != router && msg.sender != info.beneficiary) revert Unauthorized(msg.sender);
        if (info.exited) revert BidAlreadyExited(bidId);

        uint256 beforeBalance = currency.balanceOf(address(this));
        if (isPartial) {
            auction.exitPartiallyFilledBid(bidId, lastFullyFilledCheckpointBlock, outbidBlock);
        } else {
            auction.exitBid(bidId);
        }
        uint256 afterBalance = currency.balanceOf(address(this));
        uint256 refund = afterBalance - beforeBalance;

        if (refund > 0) {
            bidRefund[bidId] = refund;
        }

        uint256 tokensFilled = auction.bids(bidId).tokensFilled;
        if (tokensFilled > 0) {
            bidTokensFilled[bidId] = tokensFilled;
        }

        info.exited = true;
        emit BidExited(bidId, refund);
    }

    receive() external payable {}
}
