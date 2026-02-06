// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IERC20Refundable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {console} from "forge-std/console.sol";

/// @notice ERC20 token with refundable purchase rights that decay over time
contract ERC20Refundable is ERC20, IERC20Refundable {
    using FixedPointMathLib for uint256;
    // ---------------------------------------------------------------
    // Immutable Constants
    // ---------------------------------------------------------------

    /// @notice The ERC20 token used for purchasing this token
    address public immutable FUNDING_TOKEN;

    /// @notice Address authorized to claim funds from token sales
    address public immutable BENEFICIARY;

    // ---------------------------------------------------------------
    // Mutable State
    // ---------------------------------------------------------------

    // Purchase price in funding tokens for one unit of our token (WAD)
    uint256 public tokenSalePurchasePrice;

    /// @notice Block height when the refund window starts
    uint64 public refundWindowStartBlock;

    /// @notice Number of blocks before decay starts
    uint64 public refundableDecayStartBlock;

    /// @notice Number of blocks for full decay to complete
    uint64 public refundableDecayEndBlock;

    /// @notice Initial refundable percentage in basis points (e.g., 8000 = 80%)
    uint64 public refundableBpsAtStart;

    /// @notice Current number of refundable tokens in the contract
    uint256 internal _totalRefundableTokens;

    /// @notice Block height when the total refundable tokens were last updated
    uint64 internal _totalRefundableBlockHeight;

    /// @notice Total funding tokens deposited via token purchases
    uint256 public fundingTokensHeld;

    /// @notice Total funding tokens claimed by the agent
    uint256 public totalFundsClaimed;

    struct RefundableBalance {
        uint256 originalAmount;
        uint256 blockHeight;
    }

    /// @notice Per-user refundable token balances
    mapping(address => RefundableBalance) internal _refundableBalances;

    // ---------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------

    /// @notice Initialize the refundable token contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param maxSupply Maximum supply of the token
    /// @param beneficiary Address authorized to claim funds
    /// @param fundingToken Address of the ERC20 token used for purchases
    constructor(string memory name, string memory symbol, uint256 maxSupply, address beneficiary, address fundingToken)
        ERC20(name, symbol)
    {
        FUNDING_TOKEN = fundingToken;
        BENEFICIARY = beneficiary;

        // Mint the max supply to this contract
        _mint(address(this), maxSupply);
    }

    /// @notice Calculate the number of blocks since a given block height
    function _blocksSince(uint256 blockHeight) internal view returns (uint256) {
        return block.number > blockHeight ? block.number - blockHeight : 0;
    }

    /// @notice Calculate the number of refundable tokens currently
    /// @param originalAmount The original amount of refundable tokens
    /// @param asOfBlockHeight The block height when the original amount was set
    /// @return The number of refundable tokens at the current block height
    function _currentlyRefundable(uint256 originalAmount, uint256 asOfBlockHeight) internal view returns (uint256) {
        // If the decay has ended, none are refundable
        if (block.number > refundableDecayEndBlock) {
            return 0;
        }

        // If these are from a previous sale, none are refundable
        if (asOfBlockHeight < refundWindowStartBlock) {
            return 0;
        }

        // If the decay has not started, all are refundable
        if (block.number < refundableDecayStartBlock) {
            return originalAmount;
        }

        // Calculate the number of periods and elapsed blocks
        uint256 periods = refundableDecayEndBlock - asOfBlockHeight;
        uint256 elapsed = _blocksSince(asOfBlockHeight);

        if (periods == 0) {
            return 0;
        }
        return originalAmount / periods * (periods - elapsed);
    }

    /// @notice Get the current refundable balance for an account (with decay applied)
    /// @param account Address to query
    /// @return Current refundable token balance after applying decay
    function refundableBalanceOf(address account) external view returns (uint256) {
        return _refundableBalanceOf(account);
    }

    function _refundableBalanceOf(address account) internal view returns (uint256) {
        uint256 originalAmount = _refundableBalances[account].originalAmount;
        uint256 asOfBlockHeight = _refundableBalances[account].blockHeight;
        return _currentlyRefundable(originalAmount, asOfBlockHeight);
    }

    /// @notice Get the total supply of refundable tokens across all holders (with decay applied)
    /// @return Total refundable supply after applying decay
    function totalRefundableSupply() external view returns (uint256) {
        return _currentlyRefundable(_totalRefundableTokens, _totalRefundableBlockHeight);
    }

    /// @notice Check if the refund window is open
    /// @return True if the refund window is open, false otherwise
    function refundWindowOpen() external view returns (bool) {
        return block.number >= refundWindowStartBlock && block.number <= refundableDecayEndBlock;
    }

    // ---------------------------------------------------------------
    // Token-holder Actions
    // ---------------------------------------------------------------

    /// @notice Refund tokens to receive funding tokens back
    /// @param tokenAmount Maximum number of tokens to refund
    /// @param receiver Address to receive the funding tokens
    /// @return refundedTokenAmount Actual number of tokens refunded (may be less than requested)
    /// @return fundingTokenAmount Amount of funding tokens transferred to receiver
    function refund(uint256 tokenAmount, address receiver)
        external
        returns (uint256 refundedTokenAmount, uint256 fundingTokenAmount)
    {
        refundedTokenAmount = _refundableBalanceOf(msg.sender);
        require(refundedTokenAmount > 0, "No refundable balance");

        if (tokenAmount < refundedTokenAmount) {
            refundedTokenAmount = tokenAmount;
        }

        fundingTokenAmount = refundedTokenAmount * tokenSalePurchasePrice / 1e18;
        // Update user's remaining refundable balance
        _refundableBalances[msg.sender].originalAmount =
            _refundableBalances[msg.sender].originalAmount - refundedTokenAmount;
        _refundableBalances[msg.sender].blockHeight = block.number;

        // Update total refundable tokens
        _totalRefundableTokens -= refundedTokenAmount;
        _totalRefundableBlockHeight = uint64(block.number);

        // Return tokens to contract
        _transfer(msg.sender, address(this), refundedTokenAmount);

        // Transfer funding tokens to receiver
        fundingTokensHeld -= fundingTokenAmount;
        if (!IERC20(FUNDING_TOKEN).transfer(receiver, fundingTokenAmount)) {
            revert ERC20TransferFailed();
        }
        emit Refunded(msg.sender, receiver, refundedTokenAmount, fundingTokenAmount);
    }

    // ---------------------------------------------------------------
    // Agent Actions
    // ---------------------------------------------------------------

    /// @notice Calculate how many funding tokens the agent can currently claim
    /// @dev Subtracts funds locked for potential refunds from available balance
    /// @return Amount of funding tokens available to claim
    function claimableFunds() external view returns (uint256) {
        return _claimableFunds();
    }

    function _claimableFunds() internal view returns (uint256) {
        if (tokenSalePurchasePrice == 0) {
            return 0;
        }

        // Find how many tokens are currently refundable
        uint256 currentlyRefundableTokens = _currentlyRefundable(_totalRefundableTokens, _totalRefundableBlockHeight);
        console.log("currentlyRefundableTokens", currentlyRefundableTokens);
        // Find out how much money we would need to refund them all
        uint256 lockedFunding = currentlyRefundableTokens * tokenSalePurchasePrice / 1e18;
        console.log("lockedFunding", lockedFunding);

        // The agent can claim whatever is not locked for refunds
        console.log("fundingTokensHeld", fundingTokensHeld);
        return fundingTokensHeld - lockedFunding;
    }

    /// @notice Allows the agent to claim all available funds. Can be called by anyone.
    /// @dev NOTE: We are aware that _claimableFunds() could return more funds than it should, if the purchase prices varied between users and
    /// users who paid above the average have refunded some of their tokens (making the average purchase price incorrect).
    /// For now, we are assuming all purchase prices during one refund window are the same, but have set things up to support mixed
    /// pricing in the future.
    /// @return fundingTokensClaimed Amount of funding tokens which were claimed
    function claimFundsForBeneficiary() external returns (uint256 fundingTokensClaimed) {
        fundingTokensClaimed = _claimableFunds();
        if (!IERC20(FUNDING_TOKEN).transfer(BENEFICIARY, fundingTokensClaimed)) {
            revert ERC20TransferFailed();
        }
        emit FundsClaimedForBeneficiary(fundingTokensClaimed);
        fundingTokensHeld -= fundingTokensClaimed;
    }

    // ---------------------------------------------------------------
    // Ovverride ERC20 functions
    // ---------------------------------------------------------------

    function transfer(address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        // This will revert if anything is amiss
        super.transfer(to, amount);

        // Update the refundable balances of the sender and recipient (using refundable balance first)
        _transferRefundable(msg.sender, to, amount, false);
        return true;
    }

    function _transferRefundable(address from, address to, uint256 transferAmount, bool avoidRefundable) internal {
        // Find how many refundable tokens the sender has
        uint256 refundableBalance = _refundableBalanceOf(from);

        // Find sender's total balance
        uint256 nonRefundableBalance = balanceOf(from) - refundableBalance;

        uint256 amountToSend = 0;
        // Prioritize sending refundable tokens first
        if (!avoidRefundable) {
            amountToSend = transferAmount > refundableBalance ? refundableBalance : transferAmount;
        } else {
            // Prioritize sending non-refundable tokens first
            amountToSend = transferAmount > nonRefundableBalance ? transferAmount - nonRefundableBalance : 0;
        }

        // If no tokens are being sent, don't do anything
        if (amountToSend == 0) {
            return;
        }

        // Update balances with timestamps
        _refundableBalances[from].originalAmount = refundableBalance - amountToSend;
        _refundableBalances[from].blockHeight = block.number;

        _refundableBalances[to].originalAmount = _refundableBalanceOf(to) + amountToSend;
        _refundableBalances[to].blockHeight = block.number;
    }

    function transferFrom(address from, address to, uint256 amount) public override(ERC20, IERC20) returns (bool) {
        super.transferFrom(from, to, amount);
        _transferRefundable(from, to, amount, false);
        return true;
    }
}
