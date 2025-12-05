// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MultiTap is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    using SafeERC20 for IERC20;

    struct Split {
        address recipient;
        uint256 share; // basis points (10000 = 100%)
    }

    mapping(uint256 => Split[]) public splits;
    uint256 public splitCounter;

    event SplitCreated(uint256 indexed splitId, Split[] splits);
    event SplitExecuted(uint256 indexed splitId, address indexed asset, uint256 totalAmount);

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
    }

    function createSplit(Split[] calldata _splits) external returns (uint256) {
        unchecked {
            ++splitCounter;
        }
        uint256 currentSplitId = splitCounter;
        uint256 totalShare;

        for (uint256 i; i < _splits.length; ) {
            require(_splits[i].recipient != address(0), "Invalid recipient");
            totalShare += _splits[i].share;
            splits[currentSplitId].push(_splits[i]);
            unchecked { ++i; }
        }
        require(totalShare == 10000, "Shares must equal 100%");

        emit SplitCreated(currentSplitId, _splits);
        return currentSplitId;
    }

    function executeSplit(uint256 splitId, address asset, uint256 totalAmount) external {
        require(splits[splitId].length > 0, "Split not found");

        for (uint256 i; i < splits[splitId].length; ) {
            uint256 amount = (totalAmount * splits[splitId][i].share) / 10000;
            IERC20(asset).safeTransferFrom(msg.sender, splits[splitId][i].recipient, amount);
            unchecked { ++i; }
        }

        emit SplitExecuted(splitId, asset, totalAmount);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    uint256[48] private __gap;
}
