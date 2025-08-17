// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface ITapExecutor {
    event BatchExecuted(uint256[] tapIds, address indexed executor);
    
    function executeBatch(uint256[] calldata tapIds) external;
}
