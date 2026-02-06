// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20RefundableTokenSaleFactory {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Returns the total number of token sales deployed by this factory
    function totalTokensDeployed() external view returns (uint256);

    /// @notice Returns the token address at a specific index
    /// @param index Index of the deployed token
    function deployedTokens(uint256 index) external view returns (address);

    /// @notice Checks if an address is a token deployed by this factory
    /// @param token Address to check
    function isDeployedToken(address token) external view returns (bool);

    /// @notice Returns all tokens deployed by a specific deployer
    /// @param deployer Address of the deployer
    function getTokensByDeployer(address deployer) external view returns (address[] memory);

    /// @notice Returns all tokens for a specific beneficiary
    /// @param beneficiary Address of the beneficiary
    function getTokensByBeneficiary(address beneficiary) external view returns (address[] memory);

    // ---------------------------------------------------------------
    // Deployment Actions
    // ---------------------------------------------------------------

    /// @notice Deploy a new ERC20RefundableTokenSale contract
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param maxSupply Maximum supply of tokens
    /// @param beneficiary Address of the beneficiary who receives funds
    /// @param fundingToken Address of the token used for purchases (e.g., USDC)
    /// @return token Address of the newly deployed token contract
    function deployRefundableToken(
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        address beneficiary,
        address fundingToken
    ) external returns (address token);

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new refundable token is deployed
    event RefundableTokenDeployed(
        address indexed token,
        address indexed deployer,
        address indexed beneficiary,
        string name,
        string symbol,
        uint256 maxSupply
    );
}
