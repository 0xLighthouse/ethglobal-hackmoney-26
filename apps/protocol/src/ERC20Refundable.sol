// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IERC20Refundable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";


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

    /// @notice Block height when the refund window starts
    uint128 public refundWindowStartBlock;

    /// @notice Number of blocks before decay starts
    uint64 public refundableDecayStartBlock;

    /// @notice Number of blocks for full decay to complete
    uint64 public refundableDecayEndBlock;

    /// @notice Initial refundable percentage in basis points (e.g., 8000 = 80%)
    uint64 public refundableBpsAtStart;
    
    /// @notice Current number of refundable tokens in the contract
    uint256 internal _totalRefundableTokens;

    /// @notice Block height when the total refundable tokens were last updated
    uint128 internal _totalRefundableBlockHeight;

    /// @notice Total funding tokens claimed by the agent
    uint256 public totalFundsClaimed;

    /// @notice Total funding tokens refunded from the contract
    uint256 public totalFundsRefunded;

    struct RefundableBalance {
        uint128 purchasePrice;
        uint128 originalAmount;
        uint128 blockHeight;
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
    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address beneficiary,
        address fundingToken
    ) ERC20(name, symbol) {
        FUNDING_TOKEN = fundingToken;
        BENEFICIARY = beneficiary;

        // Mint the max supply to this contract
        _mint(address(this), maxSupply);
    }

    /// @notice Calculate the number of blocks since a given block height
    function _blocksSince(uint256 blockHeight) internal view returns (uint256) {
        return block.number - blockHeight;
    }

    /// @notice Get the current refundable balance for an account (with decay applied)
    /// @param account Address to query
    /// @return Current refundable token balance after applying decay
    function refundableBalanceOf(address account) external view returns (uint256) {
        return _refundableBalanceOf(account);
    }

    function _refundableBalanceOf(address account) internal view returns (uint256) {
      if (block.number > refundableDecayEndBlock) {
        return 0;
      }

      uint128 amountUpdatedAtBlock = _refundableBalances[account].blockHeight;
      if (amountUpdatedAtBlock < refundWindowStartBlock) {
        return 0;
      }

      uint256 originalAmount = _refundableBalances[account].originalAmount;
      if (block.number < refundableDecayStartBlock) {
        return originalAmount;
      }

      uint256 periods = refundableDecayEndBlock - amountUpdatedAtBlock;
      uint256 elapsed = _blocksSince(amountUpdatedAtBlock);
      return originalAmount / periods * (periods - elapsed);
    }

    /// @notice Get the total supply of refundable tokens across all holders (with decay applied)
    /// @return Total refundable supply after applying decay
    function totalRefundableSupply() external view returns (uint256) {
        if (block.number > refundableDecayEndBlock) {
          return 0;
        }
        if (block.number < refundableDecayStartBlock) {
          return _totalRefundableTokens;
        }

        uint256 periods = refundableDecayEndBlock - refundableDecayStartBlock;
        uint256 elapsed = _blocksSince(refundableDecayStartBlock);
        return _totalRefundableTokens / periods * (periods - elapsed);
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
    /// @dev Burns caller's tokens and transfers funding tokens to receiver
    /// @param tokenAmount Maximum number of tokens to refund
    /// @param receiver Address to receive the funding tokens
    /// @return refundedTokenAmount Actual number of tokens refunded (may be less than requested)
    /// @return fundingTokenAmount Amount of funding tokens transferred to receiver
    function refund(
        uint256 tokenAmount,
        address receiver
    ) external returns (uint256 refundedTokenAmount, uint256 fundingTokenAmount) {
        // TODO: Implement refund logic
        // 1. Calculate current refundable balance with decay
        // 2. Cap refund at current refundable balance
        // 3. Calculate proportion of original balance being refunded
        // 4. Calculate funding token amount to return (only refundable portion)
        // 5. Update state: reduce refundable balances and funding amounts
        // 6. Burn tokens from caller
        // 7. Transfer funding tokens to receiver
        // 8. Emit Refunded event
    }

    // ---------------------------------------------------------------
    // Agent Actions
    // ---------------------------------------------------------------

    /// @notice Calculate how many funding tokens the agent can currently claim
    /// @dev Subtracts funds locked for potential refunds from available balance
    /// @return Amount of funding tokens available to claim
    function claimableFunds() external view returns (uint256) {
        // TODO: Implement claimable funds calculation
        // 1. Calculate total refundable supply with decay
        // 2. Calculate total refundable funding (totalFundingDeposited * REFUNDABLE_BPS_START / 10000)
        // 3. Calculate locked funds for refunds (proportional to remaining refundable supply)
        // 4. Return (totalFundingDeposited - totalFundsClaimed - lockedForRefunds)
    }

    /// @notice Allows the agent to claim available funds
    /// @dev Only callable by the AGENT address
    /// @param amount Maximum amount of funding tokens to claim
    /// @return amountClaimed Actual amount claimed (may be less than requested)
    function claimFunds(uint256 amount) external returns (uint256 amountClaimed) {
        // TODO: Implement claim funds logic
        // 1. Verify caller is AGENT
        // 2. Calculate available funds using claimableFunds()
        // 3. Cap claim at available amount
        // 4. Update totalFundsClaimed
        // 5. Transfer funding tokens to AGENT
        // 6. Emit FundsClaimed event
    }

    // ---------------------------------------------------------------
    // Purchase Function (for testing/minting)
    // ---------------------------------------------------------------

    /// @notice Purchase tokens with funding token
    /// @dev Transfers funding tokens from buyer and mints new tokens
    /// @param buyer Address receiving the tokens
    /// @param fundingAmount Amount of funding tokens to spend
    /// @param tokenAmount Amount of tokens to mint
    function purchase(address buyer, uint256 fundingAmount, uint256 tokenAmount) external {
        // TODO: Implement purchase logic
        // 1. Transfer funding tokens from buyer to contract
        // 2. Mint tokens to buyer
        // 3. Update refundable balance tracking
        // 4. Update funding amount tracking
    }

    // ---------------------------------------------------------------
    // Internal Helper Functions
    // ---------------------------------------------------------------

    /// @notice Calculate refundable amount with linear decay applied
    /// @dev Implements time-based decay logic:
    ///      - Before delay: full refundable amount (originalAmount * REFUNDABLE_BPS_START / 10000)
    ///      - During decay: linear reduction from REFUNDABLE_BPS_START to 0
    ///      - After decay: 0
    /// @param originalAmount The original refundable amount (before decay)
    /// @return The current refundable amount after applying decay
    function _calculateRefundableAmount(uint256 originalAmount) internal view returns (uint256) {
        // TODO: Implement linear decay calculation
        // 1. Return 0 if originalAmount is 0
        // 2. Calculate blocks since deployment
        // 3. If before delay period: return (originalAmount * REFUNDABLE_BPS_START / 10000)
        // 4. If after decay period: return 0
        // 5. During decay: calculate remaining BPS and return (originalAmount * remainingBps / 10000)
    }
}
