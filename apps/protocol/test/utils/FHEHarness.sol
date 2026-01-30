// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Foundry Imports
import "forge-std/Test.sol";

// FHE Imports
import {FHE, InEuint64, InEuint8, InEuint128, euint64, euint8} from "@fhenixprotocol/cofhe-contracts/FHE.sol";
import {CoFheTest} from "lib/cofhe-mock-contracts/src/CoFheTest.sol";

abstract contract FHEHarness is Test {
    // Test instance with useful utilities for testing FHE contracts locally
    CoFheTest CFT;

    function setUp() public virtual {
        
        // Initialize new CoFheTest instance with logging turned off
        CFT = new CoFheTest(false);
    }
    
}
