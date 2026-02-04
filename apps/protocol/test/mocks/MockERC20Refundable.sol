// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../../src/interfaces/IERC20Refundable.sol";

/// @notice Mock implementation of ERC20Refundable for testing
contract MockERC20Refundable is ERC20, IERC20Refundable {
    address public immutable FUNDING_TOKEN;
    uint64 public immutable REFUNDABLE_BPS_START;
    uint64 public immutable REFUNDABLE_DECAY_BLOCK_DELAY;
    uint64 public immutable REFUNDABLE_DECAY_BLOCK_DURATION;
    address public immutable BENEFICIARY;

    uint256 public immutable deploymentBlock;
    uint256 public totalFundingDeposited; // Total funding ever deposited
    uint256 public totalFundsClaimed;
    uint256 public totalFundsRefunded;

    // Track refundable balances per user
    mapping(address => uint256) private _refundableBalances;
    uint256 private _totalRefundableSupply;

    // Track original purchase amounts for refund calculations
    mapping(address => uint256) private _originalFundingAmounts;

    constructor(
        string memory name,
        string memory symbol,
        address fundingToken,
        uint64 refundableBpsStart,
        uint64 refundableDecayBlockDelay,
        uint64 refundableDecayBlockDuration,
        address beneficiary
    ) ERC20(name, symbol) {
        FUNDING_TOKEN = fundingToken;
        REFUNDABLE_BPS_START = refundableBpsStart;
        REFUNDABLE_DECAY_BLOCK_DELAY = refundableDecayBlockDelay;
        REFUNDABLE_DECAY_BLOCK_DURATION = refundableDecayBlockDuration;
        BENEFICIARY = beneficiary;
        deploymentBlock = block.number;
    }

    /// @notice Purchase tokens with funding token (for testing)
    function purchase(address buyer, uint256 fundingAmount, uint256 tokenAmount) external {
        require(msg.sender == address(this) || msg.sender == buyer, "Unauthorized");

        // Transfer funding tokens from buyer
        IERC20(FUNDING_TOKEN).transferFrom(buyer, address(this), fundingAmount);

        // Mint tokens
        _mint(buyer, tokenAmount);

        // Track refundable balance
        _refundableBalances[buyer] += tokenAmount;
        _totalRefundableSupply += tokenAmount;

        // Track full funding amount
        _originalFundingAmounts[buyer] += fundingAmount;
        totalFundingDeposited += fundingAmount;
    }

    function refundableBalanceOf(address account) external view returns (uint256) {
        return _calculateRefundableAmount(_refundableBalances[account]);
    }

    function totalRefundableSupply() external view returns (uint256) {
        return _calculateRefundableAmount(_totalRefundableSupply);
    }

    function refundWindowStartBlock() external view returns (uint128) {
        return uint128(deploymentBlock);
    }

    function refundableDecayStartBlock() external view returns (uint64) {
        return uint64(deploymentBlock + REFUNDABLE_DECAY_BLOCK_DELAY);
    }

    function refundableDecayEndBlock() external view returns (uint64) {
        return uint64(deploymentBlock + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION);
    }

    function refundableBpsAtStart() external view returns (uint64) {
        return REFUNDABLE_BPS_START;
    }

    function refundWindowOpen() external view returns (bool) {
        uint256 blocksSinceDeployment = block.number - deploymentBlock;
        uint256 decayEndBlock = REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION;
        return blocksSinceDeployment <= decayEndBlock;
    }

    // Debug helpers
    function getOriginalRefundableBalance(address account) external view returns (uint256) {
        return _refundableBalances[account];
    }

    function getOriginalFundingAmount(address account) external view returns (uint256) {
        return _originalFundingAmounts[account];
    }

    function refund(
        uint256 tokenAmount,
        address receiver
    ) external returns (uint256 refundedTokenAmount, uint256 fundingTokenAmount) {
        uint256 currentRefundableBalance = _calculateRefundableAmount(_refundableBalances[msg.sender]);

        // Cap at current refundable balance (after decay)
        refundedTokenAmount = tokenAmount > currentRefundableBalance ? currentRefundableBalance : tokenAmount;
        require(refundedTokenAmount > 0, "No refundable balance");

        // Calculate what portion of original balance this represents
        uint256 originalRefundableBalance = _refundableBalances[msg.sender];
        uint256 currentTotalRefundable = _calculateRefundableAmount(originalRefundableBalance);

        // Calculate how much of the original balance to reduce
        uint256 originalAmountToReduce;
        if (currentTotalRefundable > 0) {
            originalAmountToReduce = (originalRefundableBalance * refundedTokenAmount) / currentTotalRefundable;
        } else {
            originalAmountToReduce = 0;
        }

        // Calculate funding amounts
        uint256 totalOriginalFunding = _originalFundingAmounts[msg.sender];
        uint256 refundableFunding = (totalOriginalFunding * REFUNDABLE_BPS_START) / 10000;

        // Amount to return to user (only the refundable portion)
        if (originalRefundableBalance > 0) {
            fundingTokenAmount = (refundableFunding * originalAmountToReduce) / originalRefundableBalance;
        }

        // Amount to reduce from total funding accounting (proportional to tokens being removed)
        uint256 fundingToReduce;
        if (originalRefundableBalance > 0) {
            fundingToReduce = (totalOriginalFunding * originalAmountToReduce) / originalRefundableBalance;
        }

        // Update state - reduce by the calculated original amount
        _refundableBalances[msg.sender] -= originalAmountToReduce;
        _totalRefundableSupply -= originalAmountToReduce;
        _originalFundingAmounts[msg.sender] -= fundingToReduce;
        totalFundingDeposited -= fundingToReduce;

        // Burn tokens
        _burn(msg.sender, refundedTokenAmount);

        // Transfer funding tokens
        IERC20(FUNDING_TOKEN).transfer(receiver, fundingTokenAmount);

        emit Refunded(msg.sender, receiver, refundedTokenAmount, fundingTokenAmount);
    }

    function claimableFunds() external view returns (uint256) {
        uint256 totalRefundable = _calculateRefundableAmount(_totalRefundableSupply);

        // Calculate how much funding is locked for refunds
        // Only the refundable portion of funding (REFUNDABLE_BPS_START) can be refunded
        uint256 totalRefundableFunding = (totalFundingDeposited * REFUNDABLE_BPS_START) / 10000;
        uint256 lockedForRefunds = 0;
        if (_totalRefundableSupply > 0) {
            lockedForRefunds = (totalRefundableFunding * totalRefundable) / _totalRefundableSupply;
        }

        uint256 fundsInContract = totalFundingDeposited > totalFundsClaimed
            ? totalFundingDeposited - totalFundsClaimed
            : 0;

        uint256 availableFunds = fundsInContract > lockedForRefunds
            ? fundsInContract - lockedForRefunds
            : 0;

        return availableFunds;
    }

    function claimFunds(uint256 amount) external returns (uint256 amountClaimed) {
        require(msg.sender == BENEFICIARY, "Only beneficiary can claim");

        uint256 available = this.claimableFunds();
        amountClaimed = amount > available ? available : amount;
        require(amountClaimed > 0, "No funds available");

        totalFundsClaimed += amountClaimed;

        IERC20(FUNDING_TOKEN).transfer(BENEFICIARY, amountClaimed);

        emit FundsClaimed(amountClaimed);
    }

    /// @notice Calculate refundable amount based on decay
    function _calculateRefundableAmount(uint256 originalAmount) internal view returns (uint256) {
        if (originalAmount == 0) return 0;

        uint256 blocksSinceDeployment = block.number - deploymentBlock;

        // Before decay starts
        if (blocksSinceDeployment < REFUNDABLE_DECAY_BLOCK_DELAY) {
            return (originalAmount * REFUNDABLE_BPS_START) / 10000;
        }

        // After decay ends
        uint256 decayEndBlock = REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION;
        if (blocksSinceDeployment >= decayEndBlock) {
            return 0;
        }

        // During decay
        uint256 blocksSinceDecayStart = blocksSinceDeployment - REFUNDABLE_DECAY_BLOCK_DELAY;
        uint256 remainingBps = REFUNDABLE_BPS_START -
            (REFUNDABLE_BPS_START * blocksSinceDecayStart) / REFUNDABLE_DECAY_BLOCK_DURATION;

        return (originalAmount * remainingBps) / 10000;
    }
}
