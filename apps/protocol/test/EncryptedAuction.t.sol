// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";

import {EncryptedAuction} from "../src/EncryptedAuction.sol";
import {InEuint64} from "cofhe-contracts/FHE.sol";
import {FHEHarness} from "./utils/FHEHarness.sol";

contract EncryptedAuctionTest is FHEHarness {
    EncryptedAuction public auction;
    address internal auctioneer;
    address internal alice;
    address internal bob;

    function setUp() public override {
        super.setUp();

        auctioneer = makeAddr("auctioneer");
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        auction = new EncryptedAuction(auctioneer);

        vm.label(auctioneer, "auctioneer");
        vm.label(alice, "alice");
        vm.label(bob, "bob");
        vm.label(address(auction), "EncryptedAuction");
    }

    function test_placeBid_setsHighestBidAndBidder() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(100, alice);
        vm.expectEmit(true, false, false, false);
        emit EncryptedAuction.BidPlaced(alice);
        vm.prank(alice);
        auction.placeBid(encryptedBid);

        CFT.assertHashValue(auction.highestBid(), 100);
        assertEq(auction.highestBidder(), alice);
    }

    function test_placeBid_updatesHighestBidWhenHigher() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(100, alice);
        vm.prank(alice);
        auction.placeBid(encryptedBid);

        InEuint64 memory higherBid = CFT.createInEuint64(150, bob);
        vm.prank(bob);
        auction.placeBid(higherBid);

        CFT.assertHashValue(auction.highestBid(), 150);
        assertEq(auction.highestBidder(), bob);
    }

    function test_placeBid_keepsHighestBidWhenLower() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(100, alice);
        vm.prank(alice);
        auction.placeBid(encryptedBid);

        InEuint64 memory lowerBid = CFT.createInEuint64(90, bob);
        vm.prank(bob);
        auction.placeBid(lowerBid);

        CFT.assertHashValue(auction.highestBid(), 100);
    }

    function test_placeBid_revertsWhenClosed() public {
        vm.prank(auctioneer);
        auction.closeBidding();

        InEuint64 memory encryptedBid = CFT.createInEuint64(100, alice);
        vm.expectRevert("Auction is closed");
        vm.prank(alice);
        auction.placeBid(encryptedBid);
    }

    function test_closeBidding_onlyAuctioneer() public {
        vm.expectRevert("Only auctioneer can call this");
        vm.prank(alice);
        auction.closeBidding();
    }

    function test_closeBidding_setsClosedAndEmits() public {
        vm.expectEmit(false, false, false, false);
        emit EncryptedAuction.AuctionClosed();
        vm.prank(auctioneer);
        auction.closeBidding();

        assertTrue(auction.auctionClosed());
    }

    function test_closeBidding_revertsWhenAlreadyClosed() public {
        vm.prank(auctioneer);
        auction.closeBidding();

        vm.expectRevert("Auction already closed");
        vm.prank(auctioneer);
        auction.closeBidding();
    }

    function test_safelyRevealWinner_requiresClosed() public {
        vm.expectRevert("Auction must be closed first");
        vm.prank(auctioneer);
        auction.safelyRevealWinner();
    }

    function test_safelyRevealWinner_revertsWhenNotReady() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(120, alice);
        vm.prank(alice);
        auction.placeBid(encryptedBid);

        vm.prank(auctioneer);
        auction.closeBidding();

        vm.expectRevert("Bid not yet decrypted - please try again later");
        vm.prank(auctioneer);
        auction.safelyRevealWinner();
    }

    function test_safelyRevealWinner_setsWinningBidWhenReady() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(200, alice);
        vm.prank(alice);
        auction.placeBid(encryptedBid);

        vm.prank(auctioneer);
        auction.closeBidding();

        bool success = false;
        uint8 count = 0;
        vm.startPrank(auctioneer);
        while (!success && count < 20) {
            try auction.safelyRevealWinner() {
                success = true;
            } catch {
                vm.warp(block.timestamp + 1);
                count += 1;
            }
        }
        vm.stopPrank();

        assertTrue(success);
        assertEq(auction.winningBid(), 200);
    }

    function test_unsafeRevealWinner_setsWinningBidWhenReady() public {
        InEuint64 memory encryptedBid = CFT.createInEuint64(180, bob);
        vm.prank(bob);
        auction.placeBid(encryptedBid);

        vm.prank(auctioneer);
        auction.closeBidding();

        bool success = false;
        uint8 count = 0;
        vm.startPrank(auctioneer);
        while (!success && count < 20) {
            try auction.unsafeRevealWinner() {
                success = true;
            } catch {
                vm.warp(block.timestamp + 1);
                count += 1;
            }
        }
        vm.stopPrank();

        assertTrue(success);
        assertEq(auction.winningBid(), 180);
    }
}
