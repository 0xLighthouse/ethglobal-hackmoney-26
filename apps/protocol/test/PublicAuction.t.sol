// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {IContinuousClearingAuctionFactory} from "lib/cca/interfaces/IContinuousClearingAuctionFactory.sol";

contract PublicAuctionTest is Test {
    // Base Sepolia CCA Factory
    address internal constant CCA_FACTORY_ADDRESS = 0xCCccCcCAE7503Cac057829BF2811De42E16e0bD5;

    function setUp() public {
        string memory rpcUrl = vm.envString("BASE_SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);      
    }

    function test_CCAFactoryExists() public view {
      IContinuousClearingAuctionFactory ccaFactory = IContinuousClearingAuctionFactory(CCA_FACTORY_ADDRESS);
      assertGt(address(ccaFactory).code.length, 0);
    }

    
}
