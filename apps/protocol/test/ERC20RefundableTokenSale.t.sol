// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20RefundableTokenSale} from "../src/ERC20RefundableTokenSale.sol";
import {ERC20Factory} from "../src/ERC20Factory.sol";
import {MockERC20} from "./mocks/MockERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20RefundableTokenSale} from "../src/interfaces/IERC20RefundableTokenSale.sol";

contract ERC20RefundableTokenSaleTest is Test {
    ERC20Factory public factory;
    ERC20RefundableTokenSale public token;
    MockERC20 public fundingToken;

    address public beneficiary;
    address public owner;
    address public alice;
    address public bob;
    address public carol;

    uint256 public constant MAX_SUPPLY = 1000000 ether;
    uint256 public constant PURCHASE_PRICE = 1; // 1:1 ratio (1 wei of funding token per 1 wei of token)
    uint64 public constant REFUNDABLE_BPS_START = 8000; // 80%
    uint64 public constant REFUNDABLE_DECAY_BLOCK_DELAY = 100;
    uint64 public constant REFUNDABLE_DECAY_BLOCK_DURATION = 200;

    event Refunded(address indexed account, address indexed receiver, uint256 tokenAmount, uint256 fundingTokenAmount);
    event FundsClaimed(uint256 fundingTokenAmount);
    event SaleCreated(uint256 amount, uint256 purchasePrice, uint256 saleStartBlock, uint256 saleEndBlock);
    event Purchased(address indexed buyer, uint256 tokensPurchased, uint256 fundingAmountSpent);

    function setUp() public {
        // Setup accounts
        beneficiary = makeAddr("beneficiary");
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Deploy factory
        factory = new ERC20Factory();

        // Deploy funding token
        fundingToken = new MockERC20("Funding Token", "USDC");

        // Deploy refundable token via factory
        vm.prank(owner);
        address tokenAddress = factory.deployRefundableToken(
            "Refundable Token",
            "RTOKEN",
            MAX_SUPPLY,
            beneficiary,
            address(fundingToken)
        );
        token = ERC20RefundableTokenSale(tokenAddress);

        // Create a sale
        uint256 saleStartBlock = block.number;
        uint256 saleEndBlock = block.number + 1000;
        uint256 saleAmount = 10000 ether;

        vm.prank(owner);
        token.createSale(IERC20RefundableTokenSale.SaleParams({
            saleAmount: saleAmount,
            purchasePrice: PURCHASE_PRICE,
            saleStartBlock: uint64(saleStartBlock),
            saleEndBlock: uint64(saleEndBlock),
            refundableDecayStartBlock: uint64(saleStartBlock + REFUNDABLE_DECAY_BLOCK_DELAY),
            refundableDecayEndBlock: uint64(saleStartBlock + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION),
            refundableBpsAtStart: REFUNDABLE_BPS_START
        }));

        // Mint funding tokens to test users
        fundingToken.mint(alice, 100000 ether);
        fundingToken.mint(bob, 100000 ether);
        fundingToken.mint(carol, 100000 ether);
    }

    // ---------------------------------------------------------------
    // Factory Tests
    // ---------------------------------------------------------------

    function test_FactoryDeployment() public view {
        assertEq(factory.totalTokensDeployed(), 1);
        assertEq(factory.deployedTokens(0), address(token));
        assertTrue(factory.isDeployedToken(address(token)));
    }

    function test_FactoryDeployMultipleTokens() public {
        vm.prank(owner);
        address secondToken = factory.deployRefundableToken(
            "Second Token",
            "SECOND",
            MAX_SUPPLY,
            beneficiary,
            address(fundingToken)
        );

        assertEq(factory.totalTokensDeployed(), 2);
        assertTrue(factory.isDeployedToken(secondToken));
        assertFalse(address(token) == secondToken);
    }

    function test_FactoryTracksDeployerAndBeneficiary() public {
        address[] memory ownerTokens = factory.getTokensByDeployer(owner);
        assertEq(ownerTokens.length, 1);
        assertEq(ownerTokens[0], address(token));

        address[] memory beneficiaryTokens = factory.getTokensByBeneficiary(beneficiary);
        assertEq(beneficiaryTokens.length, 1);
        assertEq(beneficiaryTokens[0], address(token));
    }

    // ---------------------------------------------------------------
    // Token Configuration Tests
    // ---------------------------------------------------------------

    function test_TokenConstants() public view {
        assertEq(token.FUNDING_TOKEN(), address(fundingToken));
        assertEq(token.BENEFICIARY(), beneficiary);
        assertEq(token.refundableBpsAtStart(), REFUNDABLE_BPS_START);
    }

    function test_SaleConfiguration() public view {
        assertEq(token.tokenSalePurchasePrice(), PURCHASE_PRICE);
        assertGt(token.tokenSaleEndBlock(), block.number);
        assertEq(token.remainingTokensForSale(), 10000 ether);
    }

    // ---------------------------------------------------------------
    // Purchase Tests
    // ---------------------------------------------------------------

    function test_Purchase() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);

        vm.expectEmit(true, false, false, true);
        emit Purchased(alice, tokenAmount, fundingAmount);

        uint256 tokensPurchased = token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        assertEq(tokensPurchased, tokenAmount);
        assertEq(token.balanceOf(alice), tokenAmount);
        assertEq(token.refundableBalanceOf(alice), (tokenAmount * REFUNDABLE_BPS_START) / 10000);
    }

    function test_PurchaseRevertsIfSaleNotActive() public {
        // Roll past sale end
        vm.roll(token.tokenSaleEndBlock() + 1);

        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);

        vm.expectRevert(IERC20RefundableTokenSale.SaleNotActive.selector);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();
    }

    function test_PurchaseRevertsIfInsufficientTokensForSale() public {
        uint256 tokenAmount = token.remainingTokensForSale() + 1;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);

        vm.expectRevert(IERC20RefundableTokenSale.InsufficientTokensForSale.selector);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();
    }

    function test_PurchaseRevertsIfMaxFundingExceeded() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;
        uint256 maxFundingAmount = fundingAmount - 1;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);

        vm.expectRevert(IERC20RefundableTokenSale.MaxFundingAmountExceeded.selector);
        token.purchase(tokenAmount, maxFundingAmount);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Refundable Balance Tests
    // ---------------------------------------------------------------

    function test_RefundableBalanceDecaysOverTime() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
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
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        // Alice purchases
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        // Bob purchases
        vm.startPrank(bob);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        uint256 expectedTotal = (tokenAmount * 2 * REFUNDABLE_BPS_START) / 10000;
        assertEq(token.totalRefundableSupply(), expectedTotal);
    }

    // ---------------------------------------------------------------
    // Refund Tests
    // ---------------------------------------------------------------

    function test_Refund() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);

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
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        uint256 bobFundingBefore = fundingToken.balanceOf(bob);

        token.refund(refundableBalance, bob);
        vm.stopPrank();

        assertGt(fundingToken.balanceOf(bob), bobFundingBefore);
    }

    function test_PartialRefund() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);
        uint256 refundAmount = refundableBalance / 2;

        (uint256 refundedTokens,) = token.refund(refundAmount, alice);
        vm.stopPrank();

        assertEq(refundedTokens, refundAmount);
        assertApproxEqAbs(token.refundableBalanceOf(alice), refundableBalance - refundAmount, 1);
    }

    function test_RefundCappedAtRefundableBalance() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);

        uint256 refundableBalance = token.refundableBalanceOf(alice);

        // Try to refund more than refundable balance
        (uint256 refundedTokens,) = token.refund(refundableBalance * 2, alice);
        vm.stopPrank();

        assertEq(refundedTokens, refundableBalance);
    }

    function test_RefundFailsWithNoRefundableBalance() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);

        // Fast forward past decay
        vm.roll(block.number + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION);

        vm.expectRevert("No refundable balance");
        token.refund(tokenAmount, alice);
        vm.stopPrank();
    }

    // ---------------------------------------------------------------
    // Beneficiary Claiming Tests
    // ---------------------------------------------------------------

    function test_ClaimableFunds() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        // Alice purchases
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        // Initially, most funds are locked for refunds
        uint256 claimable = token.claimableFunds();
        assertGt(claimable, 0);
        assertLt(claimable, fundingAmount);
    }

    function test_ClaimableFundsIncreasesAfterDecay() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
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

    function test_ClaimFundsForBeneficiary() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        uint256 claimable = token.claimableFunds();
        uint256 beneficiaryBalanceBefore = fundingToken.balanceOf(beneficiary);

        uint256 claimed = token.claimFundsForBeneficiary();

        assertEq(claimed, claimable);
        assertEq(fundingToken.balanceOf(beneficiary), beneficiaryBalanceBefore + claimed);
    }

    // ---------------------------------------------------------------
    // Sale Management Tests
    // ---------------------------------------------------------------

    function test_CreateSale() public {
        // Deploy a fresh token
        vm.prank(owner);
        address freshTokenAddress = factory.deployRefundableToken(
            "Fresh Token",
            "FRESH",
            MAX_SUPPLY,
            beneficiary,
            address(fundingToken)
        );
        ERC20RefundableTokenSale freshToken = ERC20RefundableTokenSale(freshTokenAddress);

        uint256 saleStartBlock = block.number + 10;
        uint256 saleEndBlock = block.number + 1000;
        uint256 saleAmount = 5000 ether;

        vm.prank(owner);
        vm.expectEmit(false, false, false, true);
        emit SaleCreated(saleAmount, PURCHASE_PRICE, saleStartBlock, saleEndBlock);

        freshToken.createSale(IERC20RefundableTokenSale.SaleParams({
            saleAmount: saleAmount,
            purchasePrice: PURCHASE_PRICE,
            saleStartBlock: uint64(saleStartBlock),
            saleEndBlock: uint64(saleEndBlock),
            refundableDecayStartBlock: uint64(saleStartBlock + REFUNDABLE_DECAY_BLOCK_DELAY),
            refundableDecayEndBlock: uint64(saleStartBlock + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION),
            refundableBpsAtStart: REFUNDABLE_BPS_START
        }));

        assertEq(freshToken.remainingTokensForSale(), saleAmount);
        assertEq(freshToken.tokenSalePurchasePrice(), PURCHASE_PRICE);
    }

    function test_CreateSaleRevertsIfNotOwner() public {
        vm.prank(owner);
        address freshTokenAddress = factory.deployRefundableToken(
            "Fresh Token",
            "FRESH",
            MAX_SUPPLY,
            beneficiary,
            address(fundingToken)
        );
        ERC20RefundableTokenSale freshToken = ERC20RefundableTokenSale(freshTokenAddress);

        vm.prank(alice);
        vm.expectRevert();
        freshToken.createSale(IERC20RefundableTokenSale.SaleParams({
            saleAmount: 5000 ether,
            purchasePrice: PURCHASE_PRICE,
            saleStartBlock: uint64(block.number),
            saleEndBlock: uint64(block.number + 1000),
            refundableDecayStartBlock: uint64(block.number + REFUNDABLE_DECAY_BLOCK_DELAY),
            refundableDecayEndBlock: uint64(block.number + REFUNDABLE_DECAY_BLOCK_DELAY + REFUNDABLE_DECAY_BLOCK_DURATION),
            refundableBpsAtStart: REFUNDABLE_BPS_START
        }));
    }

    function test_EndSale() public {
        uint256 endBlockBefore = token.tokenSaleEndBlock();

        vm.prank(owner);
        token.endSale();

        assertLt(token.tokenSaleEndBlock(), endBlockBefore);
    }

    // ---------------------------------------------------------------
    // Integration Tests
    // ---------------------------------------------------------------

    function test_FullLifecycleScenario() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        // Initial purchase
        vm.startPrank(alice);
        fundingToken.approve(address(token), fundingAmount);
        token.purchase(tokenAmount, fundingAmount);
        vm.stopPrank();

        // Beneficiary claims initial available funds
        uint256 initialClaimable = token.claimableFunds();
        token.claimFundsForBeneficiary();

        // Time passes
        vm.roll(block.number + 50);

        // Alice does partial refund
        uint256 aliceRefundAmount = token.refundableBalanceOf(alice) / 3;
        vm.prank(alice);
        token.refund(aliceRefundAmount, alice);

        // More time passes
        vm.roll(block.number + 100);

        // Beneficiary claims more funds
        uint256 secondClaimable = token.claimableFunds();
        if (secondClaimable > 0) {
            token.claimFundsForBeneficiary();
        }

        // Even more time passes (past decay)
        vm.roll(block.number + 200);

        // Alice can no longer refund
        assertEq(token.refundableBalanceOf(alice), 0);

        // Beneficiary can claim remaining funds
        uint256 finalClaimable = token.claimableFunds();
        if (finalClaimable > 0) {
            token.claimFundsForBeneficiary();
        }

        // Alice still has tokens but they're not refundable
        assertGt(token.balanceOf(alice), 0);
        assertEq(token.refundableBalanceOf(alice), 0);
    }

    function test_MultipleUsersScenario() public {
        uint256 tokenAmount = 100 ether;
        uint256 fundingAmount = tokenAmount * PURCHASE_PRICE;

        // Alice, Bob, and Carol purchase
        address[] memory users = new address[](3);
        users[0] = alice;
        users[1] = bob;
        users[2] = carol;

        for (uint256 i = 0; i < users.length; i++) {
            vm.startPrank(users[i]);
            fundingToken.approve(address(token), fundingAmount);
            token.purchase(tokenAmount, fundingAmount);
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
        assertApproxEqAbs(totalRefundable, token.refundableBalanceOf(bob) + token.refundableBalanceOf(carol), 2);
    }
}
