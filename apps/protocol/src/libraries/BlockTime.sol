// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library BlockTime {
    function secToBlocks(uint256 seconds_, uint256 secondsPerBlock) internal pure returns (uint256) {
        require(secondsPerBlock > 0, "secondsPerBlock=0");
        return (seconds_ + secondsPerBlock - 1) / secondsPerBlock;
    }

    function weeksToBlocks(uint256 weeks_, uint256 secondsPerBlock) internal pure returns (uint256) {
        return secToBlocks(weeks_ * 1 weeks, secondsPerBlock);
    }

    function daysToBlocks(uint256 days_, uint256 secondsPerBlock) internal pure returns (uint256) {
        return secToBlocks(days_ * 1 days, secondsPerBlock);
    }

    function hoursToBlocks(uint256 hours_, uint256 secondsPerBlock) internal pure returns (uint256) {
        return secToBlocks(hours_ * 1 hours, secondsPerBlock);
    }

    function minutesToBlocks(uint256 minutes_, uint256 secondsPerBlock) internal pure returns (uint256) {
        return secToBlocks(minutes_ * 1 minutes, secondsPerBlock);
    }
}
