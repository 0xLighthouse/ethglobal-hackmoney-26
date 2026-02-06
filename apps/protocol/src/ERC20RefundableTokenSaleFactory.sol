// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20RefundableTokenSale.sol";
import "./interfaces/IERC20RefundableTokenSaleFactory.sol";

/// @notice Factory contract for deploying ERC20RefundableTokenSale contracts
contract ERC20RefundableTokenSaleFactory is IERC20RefundableTokenSaleFactory {
    // ---------------------------------------------------------------
    // State Variables
    // ---------------------------------------------------------------

    /// @notice Address of the pool abd positionmanager
    address public poolManager;
    address public positionManager;

    /// @notice Array of all deployed token addresses
    address[] private _deployedTokens;

    /// @notice Mapping to check if an address is a deployed token
    mapping(address => bool) private _isDeployedToken;

    /// @notice Mapping from deployer address to their deployed tokens
    mapping(address => address[]) private _tokensByDeployer;

    /// @notice Mapping from beneficiary address to their tokens
    mapping(address => address[]) private _tokensByBeneficiary;

    /// @notice Constructor to store the pool manager address for the chain we are using
    constructor(address poolManager_, address positionManager_) {
        poolManager = poolManager_;
        positionManager = positionManager_;
    }

    // ---------------------------------------------------------------
    // View Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function totalTokensDeployed() external view returns (uint256) {
        return _deployedTokens.length;
    }

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function deployedTokens(uint256 index) external view returns (address) {
        require(index < _deployedTokens.length, "Index out of bounds");
        return _deployedTokens[index];
    }

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function isDeployedToken(address token) external view returns (bool) {
        return _isDeployedToken[token];
    }

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function getTokensByDeployer(address deployer) external view returns (address[] memory) {
        return _tokensByDeployer[deployer];
    }

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function getTokensByBeneficiary(address beneficiary) external view returns (address[] memory) {
        return _tokensByBeneficiary[beneficiary];
    }

    // ---------------------------------------------------------------
    // Deployment Functions
    // ---------------------------------------------------------------

    /// @inheritdoc IERC20RefundableTokenSaleFactory
    function deployRefundableToken(
        string calldata name,
        string calldata symbol,
        uint256 maxSupply,
        address beneficiary,
        address fundingToken
    ) external returns (address token) {
        // Validate inputs
        require(bytes(name).length > 0, "Name cannot be empty");
        require(bytes(symbol).length > 0, "Symbol cannot be empty");
        require(maxSupply > 0, "Max supply must be greater than 0");
        require(beneficiary != address(0), "Beneficiary cannot be zero address");
        require(fundingToken != address(0), "Funding token cannot be zero address");

        // Deploy new ERC20RefundableTokenSale contract
        ERC20RefundableTokenSale newToken = new ERC20RefundableTokenSale(
            name, symbol, maxSupply, fundingToken, beneficiary, poolManager, positionManager
        );

        token = address(newToken);

        // Transfer ownership to the deployer
        newToken.transferOwnership(msg.sender);

        // Register the token
        _deployedTokens.push(token);
        _isDeployedToken[token] = true;
        _tokensByDeployer[msg.sender].push(token);
        _tokensByBeneficiary[beneficiary].push(token);

        // Emit event
        emit RefundableTokenDeployed(token, msg.sender, beneficiary, name, symbol, maxSupply);

        return token;
    }
}
