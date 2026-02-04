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

    /// @notice The address of the beneficiary who can claim funds
    function BENEFICIARY() external view returns (address);

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Block height when the refund window starts
    function refundWindowStartBlock() external view returns (uint128);

    /// @notice Block height when decay starts
    function refundableDecayStartBlock() external view returns (uint64);

    /// @notice Block height when decay ends
    function refundableDecayEndBlock() external view returns (uint64);

    /// @notice Initial refundable percentage in basis points (e.g., 8000 = 80%)
    function refundableBpsAtStart() external view returns (uint64);

    /// @notice Total funding tokens deposited via token purchases
    function fundingTokensHeld() external view returns (uint256);

    /// @notice Total funding tokens claimed by the beneficiary
    function totalFundsClaimed() external view returns (uint256);
  
    // ---------------------------------------------------------------
    // Refund-specific views
    // ---------------------------------------------------------------

    /// @notice Number of refundable tokens belonging to the account.
    function refundableBalanceOf(address account) external view returns (uint256);

    /// @notice Total supply of tokens that are still refundable across all holders.
    function totalRefundableSupply() external view returns (uint256);

    /// @notice Check if the refund window is open
    function refundWindowOpen() external view returns (bool);

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
    // Beneficiary actions
    // ---------------------------------------------------------------

    /// @notice Reports how many funds are available for the beneficiary to claim
    function claimableFunds() external view returns (uint256);

    /// @notice Allows anyone to claim all available funds for the beneficiary
    /// @return fundingTokensClaimed Amount of funding tokens which were claimed
    function claimFundsForBeneficiary() external returns (uint256 fundingTokensClaimed);
    
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

    /// @notice Emitted when funds are claimed by the beneficiary.
    event FundsClaimedForBeneficiary(
        uint256 fundingTokensClaimed
    );

    /// @notice Emitted when a transfer fails.
    error ERC20TransferFailed();
}