// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IContinuousClearingAuction} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {LockupCCAFactory} from "../src/strategies/lockups/LockupCCAFactory.sol";
import {LockupCCAInitializer} from "../src/strategies/lockups/LockupCCAInitializer.sol";
import {ILockupCCAInitializer} from "../src/strategies/lockups/interfaces/ILockupCCAInitializer.sol";
import {ILockupBidRouter} from "../src/strategies/lockups/interfaces/ILockupBidRouter.sol";
import {ILockupVault} from "../src/strategies/lockups/interfaces/ILockupVault.sol";
import {ILockupValidationHook} from "../src/strategies/lockups/interfaces/ILockupValidationHook.sol";

import {AuctionParameters} from "lib/cca/interfaces/IContinuousClearingAuction.sol";
import {ConstantsLib} from "lib/cca/libraries/ConstantsLib.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint256 supply) ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }
}

contract LockupStrategyTest is Test {
    uint128 internal constant TOTAL_SUPPLY = 1_000_000 ether;

    address internal alice;

    function test_lockupStrategyFlow() public {
        alice = makeAddr("alice");

        MockERC20 token = new MockERC20("LockToken", "LOCK", TOTAL_SUPPLY);
        AuctionParameters memory auctionParams = AuctionParameters({
            currency: address(0),
            tokensRecipient: address(this),
            fundsRecipient: address(this),
            startBlock: 1,
            endBlock: 2,
            claimBlock: 3,
            tickSpacing: ConstantsLib.MIN_TICK_SPACING,
            validationHook: address(0),
            floorPrice: ConstantsLib.MIN_FLOOR_PRICE,
            requiredCurrencyRaised: 1 ether,
            auctionStepsData: abi.encodePacked(uint24(10_000_000), uint40(1))
        });

        ILockupCCAInitializer.LockupParameters memory lockupParameters = ILockupCCAInitializer.LockupParameters({
            trancheCaps: [uint128(1 ether), 1 ether, 1 ether, 1 ether],
            lockupMonths: [uint32(3), 6, 9, 12],
            seedConfig: ILockupCCAInitializer.SeedConfig({
                poolSeedBps: 0,
                poolSeeder: address(0),
                treasuryRecipient: address(this),
                seedData: ""
            })
        });

        LockupCCAFactory factory = new LockupCCAFactory();
        bytes memory configData = abi.encode(auctionParams, lockupParameters);

        LockupCCAInitializer initializer = LockupCCAInitializer(
            address(factory.initializeDistribution(address(token), TOTAL_SUPPLY, configData, bytes32(0)))
        );

        token.transfer(address(initializer), TOTAL_SUPPLY);
        initializer.onTokensReceived();

        IContinuousClearingAuction auction = initializer.auction();
        ILockupValidationHook hook = initializer.hook();
        ILockupBidRouter router = initializer.router();
        ILockupVault vault = initializer.vault();

        assertEq(address(auction), hook.auction());
        assertEq(address(auction), address(router.auction()));
        assertEq(address(auction), address(vault.auction()));
        assertEq(hook.router(), address(router));
        assertEq(hook.vault(), address(vault));
        assertEq(address(auction.validationHook()), address(hook));

        vm.roll(1);
        vm.deal(alice, 1 ether);
        uint256 maxPrice = ConstantsLib.MIN_FLOOR_PRICE + ConstantsLib.MIN_TICK_SPACING;
        vm.prank(alice);
        uint256 bidId = router.submitBid{value: 0.5 ether}(0, maxPrice, 0.5 ether, alice);

        assertEq(hook.trancheUsed(0), 0.5 ether);
        (address beneficiary, uint8 trancheId, bool exited, bool claimed) = vault.bidInfo(bidId);
        assertEq(beneficiary, alice);
        assertEq(trancheId, 0);
        assertEq(exited, false);
        assertEq(claimed, false);
    }
}
