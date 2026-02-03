// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @notice ERC20-compatible token transferable refund rights.
interface IERC20Refundable is IERC20 {
    // ---------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------
 
    /// @notice The asset that was used for purchasing tokens
    function FUNDING_TOKEN() external view returns (address);
    /// How much of the tokens are immediately refundable
    function REFUNDABLE_BPS_START() external view returns (uint64);
    /// How many blocks until refund decay starts
    function REFUNDABLE_DECAY_BLOCK_DELAY() external view returns (uint64);
    /// How many blocks until decay is depleted
    function REFUNDABLE_DECAY_BLOCK_DURATION() external view returns (uint64);
    /// The address of the agent (who is able to claim funds from the sale)
    function AGENT() external view returns (address);
    
    // ---------------------------------------------------------------
    // Refund-specific views
    // ---------------------------------------------------------------

    /// @notice Number of refundable tokens belonging to the account.
    function refundableBalanceOf(address account) external view returns (uint256);

    /// @notice Total supply of tokens that are still refundable across all holders.
    function totalRefundableSupply() external view returns (uint256);

    // ---------------------------------------------------------------
    // Token-holder actions
    // ---------------------------------------------------------------

    /// @notice Refund up to `tokenAmount` using the caller’s refundable balance.
    /// @param tokenAmount Maximum amount of tokens to attempt to refund.
    /// @param receiver Recipient of the refunded tokens (can be different from msg.sender).
    /// @return refundedTokenAmount Number of tokens refunded(may be < tokenAmount).
    /// @return fundingTokenAmount Amount of funding token sent to receiver.
   
    function refund(
        uint256 tokenAmount,
        address receiver
    )
        external
        returns (uint256 refundedTokenAmount, uint256 fundingTokenAmount);

    // ---------------------------------------------------------------
    // Agent actions
    // ---------------------------------------------------------------
    
    /// @notice Reports how many funds are available for the agent to claim
    function claimableFunds() external view returns (uint256);
    
    /// @notice Allows the agent to claim funds that have already been released
    function claimFunds(uint256 amount) external returns (uint256 amountClaimed);
    
    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when tokens are refunded.
    event Refunded(
        address indexed account,
        address indexed receiver,
        uint256 tokenAmount,
        uint256 fundingTokenAmount
    );

    /// @notice Emitted when funds are claimed by the agent.
    event FundsClaimed(
        uint256 fundingTokenAmount
    );
}