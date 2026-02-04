// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20Factory {

    // ---------------------------------------------------------------
    // Structs
    // ---------------------------------------------------------------

    /// @notice Parameters for deploying an ERC20Refundable token
    struct TokenDeploymentParams {
        string name;
        string symbol;
        uint256 initialSupply;
        address fundingToken;
        address beneficiary;
        uint128 refundWindowStartBlock;
        uint64 refundableDecayStartBlock;
        uint64 refundableDecayEndBlock;
        uint64 refundableBpsAtStart;
    }

    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Returns the total number of tokens deployed by this factory
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

    // ---------------------------------------------------------------
    // Deployment Actions
    // ---------------------------------------------------------------

    /// @notice Deploy a new ERC20Refundable token with specified parameters
    /// @param params Token deployment parameters
    /// @return tokenAddress Address of the newly deployed token
    function deployToken(TokenDeploymentParams calldata params) external returns (address tokenAddress);

    /// @notice Deploy a new ERC20Refundable token with simple parameters
    /// @param name Token name
    /// @param symbol Token symbol
    /// @param initialSupply Initial supply of tokens
    /// @param fundingToken Address of the funding token
    /// @param beneficiary Address of the beneficiary
    /// @return tokenAddress Address of the newly deployed token
    function deployTokenSimple(
        string calldata name,
        string calldata symbol,
        uint256 initialSupply,
        address fundingToken,
        address beneficiary
    ) external returns (address tokenAddress);

    // ---------------------------------------------------------------
    // Events
    // ---------------------------------------------------------------

    /// @notice Emitted when a new token is deployed
    event TokenDeployed(
        address indexed tokenAddress,
        address indexed deployer,
        address indexed beneficiary,
        string name,
        string symbol,
        uint256 initialSupply
    );

}
