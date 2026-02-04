// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {MockERC20Refundable} from "./mocks/MockERC20Refundable.sol";
import {MockERC20RefundableFactory} from "./mocks/MockERC20RefundableFactory.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract ERC20RefundableTest is Test {
    MockERC20RefundableFactory public factory;
    MockERC20Refundable public token;
    MockERC20 public fundingToken;

    address public beneficiary;
    address public alice;
    address public bob;
    address public carol;

    uint64 public constant REFUNDABLE_BPS_START = 8000; // 80%
    uint64 public constant REFUNDABLE_DECAY_BLOCK_DELAY = 100;
    uint64 public constant REFUNDABLE_DECAY_BLOCK_DURATION = 200;

    event Refunded(
        address indexed account,
        address indexed receiver,
        uint256 tokenAmount,
        uint256 fundingTokenAmount
    );

    event FundsClaimed(uint256 fundingTokenAmount);

    function setUp() public {
        // Setup accounts
        beneficiary = makeAddr("beneficiary");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Deploy factory
        factory = new MockERC20RefundableFactory();

        // Deploy funding token
        fundingToken = new MockERC20("Funding Token", "FUND");

        // Deploy refundable token via factory
        MockERC20RefundableFactory.DeployParams memory params = MockERC20RefundableFactory.DeployParams({
            name: "Refundable Token",
            symbol: "RTOKEN",
            fundingToken: address(fundingToken),
            refundableBpsStart: REFUNDABLE_BPS_START,
            refundableDecayBlockDelay: REFUNDABLE_DECAY_BLOCK_DELAY,
            refundableDecayBlockDuration: REFUNDABLE_DECAY_BLOCK_DURATION,
            beneficiary: beneficiary
        });

        address tokenAddress = factory.deployToken(params);
        token = MockERC20Refundable(tokenAddress);

        // Mint funding tokens to test users
        fundingToken.mint(alice, 10000 ether);
        fundingToken.mint(bob, 10000 ether);
        fundingToken.mint(carol, 10000 ether);
    }

    // ---------------------------------------------------------------
    // Factory Tests
    // ---------------------------------------------------------------

    function test_FactoryDeployment() public view {
        assertEq(factory.getDeployedTokensCount(), 1);
        assertEq(factory.getDeployedToken(0), address(token));
        assertTrue(factory.isDeployedToken(address(token)));
    }

    function test_FactoryDeployMultipleTokens() public {
        MockERC20RefundableFactory.DeployParams memory params = MockERC20RefundableFactory.DeployParams({
            name: "Second Token",
            symbol: "SECOND",
            fundingToken: address(fundingToken),
            refundableBpsStart: REFUNDABLE_BPS_START,
            refundableDecayBlockDelay: REFUNDABLE_DECAY_BLOCK_DELAY,
            refundableDecayBlockDuration: REFUNDABLE_DECAY_BLOCK_DURATION,
            beneficiary: beneficiary
        });

        address secondToken = factory.deployToken(params);

        assertEq(factory.getDeployedTokensCount(), 2);
        assertTrue(factory.isDeployedToken(secondToken));
        assertFalse(address(token) == secondToken);
    }

    // ---------------------------------------------------------------
    // Constants Tests
    // ---------------------------------------------------------------

    function test_TokenConstants() public view {
        assertEq(token.FUNDING_TOKEN(), address(fundingToken));
        assertEq(token.REFUNDABLE_BPS_START(), REFUNDABLE_BPS_START);
        assertEq(token.REFUNDABLE_DECAY_BLOCK_DELAY(), REFUNDABLE_DECAY_BLOCK_DELAY);
        assertEq(token.REFUNDABLE_DECAY_BLOCK_DURATION(), REFUNDABLE_DECAY_BLOCK_DURATION);
        assertEq(token.BENEFICIARY(), beneficiary);
    }

    // ---------------------------------------------------------------
    // Purchase & Balance Tests
    // ---------------------------------------------------------------

    function test_Purchase() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        assertEq(token.balanceOf(alice), tokenAmount);
        assertEq(token.refundableBalanceOf(alice), (tokenAmount * REFUNDABLE_BPS_START) / 10000);
    }

    function test_RefundableBalanceDecaysOverTime() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 expectedRefundable = (tokenAmount * REFUNDABLE_BPS_START) / 10000;
        assertEq(token.refundableBalanceOf(alice), expectedRefundable);

        // Fast forward before decay starts
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DELAY - 1);
        assertEq(token.refundableBalanceOf(alice), expectedRefundable);

        // Fast forward to middle of decay
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DURATION / 2 + 1);
        uint256 midDecayBalance = token.refundableBalanceOf(alice);
        assertLt(midDecayBalance, expectedRefundable);
        assertGt(midDecayBalance, 0);

        // Fast forward past decay end
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DURATION);
        assertEq(token.refundableBalanceOf(alice), 0);
    }

    function test_TotalRefundableSupply() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        // Alice purchases
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        // Bob purchases
        vm.startPrank(bob);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(bob, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 expectedTotal = (tokenAmount * 2 * REFUNDABLE_BPS_START) / 10000;
        assertEq(token.totalRefundableSupply(), expectedTotal);
    }

    // ---------------------------------------------------------------
    // Refund Tests
    // ---------------------------------------------------------------

    function test_Refund() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        uint256 aliceFundingBefore = fundingToken.balanceOf(alice);
        uint256 aliceTokenBefore = token.balanceOf(alice);

        vm.expectEmit(true, true, false, false);
        emit Refunded(alice, alice, refundableBalance, 0);

        (uint256 refundedTokens, uint256 fundingReceived) = token.refund(refundableBalance, alice);
        vm.stopPrank();

        assertEq(refundedTokens, refundableBalance);
        assertGt(fundingReceived, 0);
        assertEq(token.balanceOf(alice), aliceTokenBefore - refundedTokens);
        assertEq(fundingToken.balanceOf(alice), aliceFundingBefore + fundingReceived);
        assertEq(token.refundableBalanceOf(alice), 0);
    }

    function test_RefundToDifferentReceiver() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        uint256 bobFundingBefore = fundingToken.balanceOf(bob);

        token.refund(refundableBalance, bob);
        vm.stopPrank();

        assertGt(fundingToken.balanceOf(bob), bobFundingBefore);
    }

    function test_PartialRefund() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        uint256 refundAmount = refundableBalance / 2;

        (uint256 refundedTokens, ) = token.refund(refundAmount, alice);
        vm.stopPrank();

        assertEq(refundedTokens, refundAmount);
        assertApproxEqAbs(token.refundableBalanceOf(alice), refundableBalance - refundAmount, 1);
    }

    function test_RefundCappedAtRefundableBalance() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);

        // Try to refund more than refundable balance
        (uint256 refundedTokens, ) = token.refund(refundableBalance * 2, alice);
        vm.stopPrank();

        assertEq(refundedTokens, refundableBalance);
    }

    function test_RefundFailsWithNoRefundableBalance() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        // Fast forward past decay
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION);

        vm.expectRevert("No refundable balance");
        token.refund(tokenAmount, alice);
        vm.stopPrank();
    }

    function test_MultipleRefunds() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);

        // First refund
        token.refund(refundableBalance / 3, alice);

        // Second refund
        token.refund(refundableBalance / 3, alice);

        // Third refund
        uint256 remainingRefundable = token.refundableBalanceOf(alice);
        token.refund(remainingRefundable, alice);
        vm.stopPrank();

        assertEq(token.refundableBalanceOf(alice), 0);
    }

    // ---------------------------------------------------------------
    // Agent Claiming Tests
    // ---------------------------------------------------------------

    function test_ClaimableFunds() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        // Alice purchases
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        // Initially, most funds are locked for refunds
        uint256 claimable = token.claimableFunds();
        assertGt(claimable, 0);
        assertLt(claimable, fundingAmount);
    }

    function test_ClaimableFundsIncreasesAfterDecay() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 claimableBefore = token.claimableFunds();

        // Fast forward to middle of decay
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION / 2);

        uint256 claimableDuringDecay = token.claimableFunds();
        assertGt(claimableDuringDecay, claimableBefore);

        // Fast forward past decay
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DURATION);

        uint256 claimableAfterDecay = token.claimableFunds();
        assertGt(claimableAfterDecay, claimableDuringDecay);
    }

    function test_ClaimFunds() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 claimable = token.claimableFunds();
        uint256 beneficiaryBalanceBefore = fundingToken.balanceOf(beneficiary);

        vm.expectEmit(false, false, false, true);
        emit FundsClaimed(claimable);

        vm.prank(beneficiary);
        uint256 claimed = token.claimFundsForBeneficiary();

        assertEq(claimed, claimable);
        assertEq(fundingToken.balanceOf(beneficiary), beneficiaryBalanceBefore + claimed);
    }

    function test_ClaimFundsFailsForNonAgent() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        vm.expectRevert("Only beneficiary can claim");
        token.claimFundsForBeneficiary();
        vm.stopPrank();
    }

    function test_ClaimFundsCappedAtAvailable() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 claimable = token.claimableFunds();

        vm.prank(beneficiary);
        uint256 claimed = token.claimFundsForBeneficiary();

        assertEq(claimed, claimable);
    }

    function test_ClaimFundsFailsWhenNoFundsAvailable() public {
        vm.prank(beneficiary);
        vm.expectRevert("No funds available");
        token.claimFundsForBeneficiary();
    }

    // ---------------------------------------------------------------
    // Integration Tests
    // ---------------------------------------------------------------

    function test_RefundAndClaimInteraction() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        // Alice purchases
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 claimableBeforeRefund = token.claimableFunds();

        // Alice refunds half
        vm.startPrank(alice);
        uint256 refundableBalance = token.refundableBalanceOf(alice);
        token.refund(refundableBalance / 2, alice);
        vm.stopPrank();

        // Claimable should decrease after refund
        uint256 claimableAfterRefund = token.claimableFunds();
        assertLt(claimableAfterRefund, claimableBeforeRefund);
    }

    function test_MultipleUsersRefundScenario() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        // Alice, Bob, and Carol purchase
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            fundingToken.approve(address(token), fundingAmount);
            token.purchase(users[i], fundingAmount, tokenAmount);
            vm.stopPrank();
        }

        // Each user refunds different amounts
        uint256 aliceRefund = token.refundableBalanceOf(alice);
        vm.prank(alice);
        token.refund(aliceRefund, alice);

        uint256 bobRefund = token.refundableBalanceOf(bob) / 2;
        vm.prank(bob);
        token.refund(bobRefund, bob);

        // Carol doesn't refund

        // Check total refundable supply
        uint256 totalRefundable = token.totalRefundableSupply();
        assertGt(totalRefundable, 0);
        assertApproxEqAbs(
            totalRefundable,
            token.refundableBalanceOf(bob) + token.refundableBalanceOf(carol),
            2
        );
    }

    function test_FullLifecycleScenario() public {
        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        // Initial purchase
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        // Agent claims initial available funds
        uint256 initialClaimable = token.claimableFunds();
        vm.prank(beneficiary);
        token.claimFundsForBeneficiary();

        // Time passes
        vm.roll(block.number + 50);

        // Alice does partial refund
        uint256 aliceRefundAmount = token.refundableBalanceOf(alice) / 3;
        vm.prank(alice);
        token.refund(aliceRefundAmount, alice);

        // More time passes
        vm.roll(block.number + 100);

        // Agent claims more funds
        uint256 secondClaimable = token.claimableFunds();
        if (secondClaimable > 0) {
            vm.prank(beneficiary);
            token.claimFundsForBeneficiary();
        }

        // Even more time passes (past decay)
        vm.roll(block.number + 200);

        // Alice can no longer refund
        assertEq(token.refundableBalanceOf(alice), 0);

        // Agent can claim remaining funds
        uint256 finalClaimable = token.claimableFunds();
        if (finalClaimable > 0) {
            vm.prank(beneficiary);
            token.claimFundsForBeneficiary();
        }

        // Alice still has tokens but they're not refundable
        assertGt(token.balanceOf(alice), 0);
        assertEq(token.refundableBalanceOf(alice), 0);
    }

    // ---------------------------------------------------------------
    // Fuzz Tests
    // ---------------------------------------------------------------

    function testFuzz_PurchaseAndRefund(uint96 fundingAmount, uint96 tokenAmount) public {
        vm.assume(fundingAmount > 10000 && fundingAmount < 1000000 ether);
        vm.assume(tokenAmount > 10000 && tokenAmount < 1000000 ether);

        fundingToken.mint(alice, fundingAmount);

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        if (refundableBalance > 0) {
            (uint256 refundedTokens, uint256 fundingReceived) = token.refund(refundableBalance, alice);
            assertEq(refundedTokens, refundableBalance);
            assertGt(fundingReceived, 0);
        }
        vm.stopPrank();
    }

    function testFuzz_DecayCalculation(uint64 blockDelay) public {
        vm.assume(blockDelay <= REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION);

        uint256 fundingAmount = 1000 ether;
        uint256 tokenAmount = 100 ether;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(alice, fundingAmount, tokenAmount);
        vm.stopPrank();

        uint256 initialRefundable = token.refundableBalanceOf(alice);

        vm.roll(block.number + blockDelay);

        uint256 refundableAfterDelay = token.refundableBalanceOf(alice);

        if (blockDelay <= REFUNDABLE_DECAY_BLOCK_DELAY) {
            assertEq(refundableAfterDelay, initialRefundable);
        } else if (blockDelay >= REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION) {
            assertEq(refundableAfterDelay, 0);
        } else {
            assertLt(refundableAfterDelay, initialRefundable);
            assertGt(refundableAfterDelay, 0);
        }
    }
}
