// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IValidationHook} from "lib/cca/interfaces/IValidationHook.sol";
import {ValidationHookIntrospection} from "lib/cca/periphery/validationHooks/ValidationHookIntrospection.sol";
import {ILockupValidationHook} from "./interfaces/ILockupValidationHook.sol";

/// @title LockupValidationHook
/// @notice Enforces reserve price, tranche caps, and router/vault usage for lockup offerings
/// @dev Tranche caps are enforced on bid currency amounts (not token amounts)
contract LockupValidationHook is ValidationHookIntrospection, ILockupValidationHook {

    address public auction;
    address public router;
    address public vault;
    address public immutable owner;
    bool public initialized;
    uint256 public immutable reservePriceX96;

    uint128[4] public trancheCaps;
    uint128[4] public trancheUsed;

    constructor(uint256 _reservePriceX96, uint128[4] memory _trancheCaps) {
        owner = msg.sender;
        reservePriceX96 = _reservePriceX96;
        trancheCaps = _trancheCaps;
    }

    /// @inheritdoc ILockupValidationHook
    function initialize(address _auction, address _router, address _vault) external {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        if (initialized) revert AlreadyInitialized();
        if (_auction == address(0) || _router == address(0) || _vault == address(0)) {
            revert InvalidAddress();
        }
        auction = _auction;
        router = _router;
        vault = _vault;
        initialized = true;
    }

    /// @inheritdoc IValidationHook
    function validate(
        uint256 maxPrice,
        uint128 amount,
        address owner_,
        address sender,
        bytes calldata hookData
    ) external override {
        if (!initialized) revert NotInitialized();
        if (msg.sender != auction) revert OnlyAuction(msg.sender);
        if (sender != router) revert OnlyRouter(sender);
        if (owner_ != vault) revert InvalidOwner(owner_);
        if (maxPrice < reservePriceX96) revert ReservePriceNotMet(maxPrice, reservePriceX96);

        (uint8 trancheId, address beneficiary) = abi.decode(hookData, (uint8, address));
        if (beneficiary == address(0)) revert BeneficiaryCannotBeZeroAddress();
        if (trancheId >= 4) revert InvalidTranche(trancheId);

        uint128 newUsed = trancheUsed[trancheId] + amount;
        if (newUsed > trancheCaps[trancheId]) revert TrancheCapExceeded(trancheId, newUsed, trancheCaps[trancheId]);
        trancheUsed[trancheId] = newUsed;
    }
}
