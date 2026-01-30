// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {CoFheTest} from "lib/cofhe-mock-contracts/src/CoFheTest.sol";
import {FHE, InEuint32, euint32} from "@fhenixprotocol/cofhe-contracts/FHE.sol";

contract TestBed {
    euint32 public eNumber;

    function setNumber(InEuint32 memory inNumber) public {
        eNumber = FHE.asEuint32(inNumber);
        FHE.allowThis(eNumber);
        FHE.allowSender(eNumber);
    }
}

contract FhenixTest is Test {
    TestBed private testbed;
    CoFheTest private cft;

    address private user = makeAddr("user");

    function setUp() public {
        cft = new CoFheTest(true);
        testbed = new TestBed();
    }

    function testSetNumber() public {
        uint32 n = 10;
        InEuint32 memory number = cft.createInEuint32(n, user);

        // must be the user who sends transaction
        // or else invalid permissions from fhe allow
        vm.prank(user);
        testbed.setNumber(number);

        cft.assertHashValue(testbed.eNumber(), n);
    }
}
