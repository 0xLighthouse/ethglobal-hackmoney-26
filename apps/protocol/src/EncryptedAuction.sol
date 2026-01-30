// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import {CoFheTest} from "lib/cofhe-mock-contracts/src/CoFheTest.sol";
import "@fhenixprotocol/cofhe-contracts/FHE.sol";

contract EncryptedAuction {
    euint64 public highestBid;
    address public highestBidder;
    address public auctioneer;
    bool public auctionClosed;
    uint64 public winningBid;

    event BidPlaced(address indexed bidder);
    event AuctionClosed();
    event RevealedWinningBid(address indexed winner, uint64 amount);

    modifier onlyAuctioneer() {
        require(msg.sender == auctioneer, "Only auctioneer can call this");
        _;
    }

    constructor(address _auctioneer) {
        auctioneer = _auctioneer;
    }

    // Place an encrypted bid
    function placeBid(InEuint64 memory encryptedBid) external {
        require(!auctionClosed, "Auction is closed");

        euint64 bid = FHE.asEuint64(encryptedBid);
        ebool isHigher = bid.gt(highestBid);

        // Update highest bid if this bid is higher
        euint64 newHighestBid = FHE.select(isHigher, bid, highestBid);
        FHE.allowThis(newHighestBid);

        highestBid = newHighestBid;
        highestBidder = msg.sender;

        emit BidPlaced(msg.sender);
    }

    // Close the auction and request decryption
    function closeBidding() external onlyAuctioneer {
        require(!auctionClosed, "Auction already closed");

        FHE.decrypt(highestBid);
        auctionClosed = true;

        emit AuctionClosed();
    }

    // Safe method: Reveal winner with readiness check
    function safelyRevealWinner() external onlyAuctioneer {
        require(auctionClosed, "Auction must be closed first");

        (uint64 bidValue, bool bidReady) = FHE.getDecryptResultSafe(highestBid);
        require(bidReady, "Bid not yet decrypted - please try again later");

        winningBid = bidValue;
        emit RevealedWinningBid(highestBidder, bidValue);
    }

    // Unsafe method: Reveal winner (reverts if not ready)
    function unsafeRevealWinner() external onlyAuctioneer {
        require(auctionClosed, "Auction must be closed first");

        uint64 bidValue = FHE.getDecryptResult(highestBid);

        winningBid = bidValue;
        emit RevealedWinningBid(highestBidder, bidValue);
    }
}