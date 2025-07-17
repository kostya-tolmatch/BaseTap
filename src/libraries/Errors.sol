// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

library Errors {
    error InvalidRecipient();
    error InvalidAsset();
    error InvalidAmount();
    error Unauthorized();
    error TapNotActive();
    error CooldownActive();
    error DailyLimitReached();
    error AlreadyDeactivated();
}
