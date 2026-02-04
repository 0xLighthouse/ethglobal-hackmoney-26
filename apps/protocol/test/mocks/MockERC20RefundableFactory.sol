// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MockERC20Refundable.sol";

/// @notice Factory for deploying MockERC20Refundable tokens
contract MockERC20RefundableFactory {
    event TokenDeployed(
        address indexed token, address indexed beneficiary, address indexed fundingToken, string name, string symbol
    );

    struct DeployParams {
        string name;
        string symbol;
        address fundingToken;
        uint64 refundableBpsStart;
        uint64 refundableDecayBlockDelay;
        uint64 refundableDecayBlockDuration;
        address beneficiary;
    }

    address[] public deployedTokens;
    mapping(address => bool) public isDeployedToken;

    function deployToken(DeployParams memory params) external returns (address token) {
        MockERC20Refundable newToken = new MockERC20Refundable(
            params.name,
            params.symbol,
            params.fundingToken,
            params.refundableBpsStart,
            params.refundableDecayBlockDelay,
            params.refundableDecayBlockDuration,
            params.beneficiary
        );

        token = address(newToken);
        deployedTokens.push(token);
        isDeployedToken[token] = true;

        emit TokenDeployed(token, params.beneficiary, params.fundingToken, params.name, params.symbol);
    }

    function getDeployedTokensCount() external view returns (uint256) {
        return deployedTokens.length;
    }

    function getDeployedToken(uint256 index) external view returns (address) {
        require(index < deployedTokens.length, "Index out of bounds");
        return deployedTokens[index];
    }
}
