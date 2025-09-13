// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBatchOperations {
    struct BatchTapParams {
        address recipient;
        address asset;
        uint256 amount;
        uint256 cooldown;
        uint256 dailyLimit;
        bool singleUse;
    }

    function batchCreateTaps(BatchTapParams[] calldata params) external returns (uint256[] memory);
}
