// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/MultiTap.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./mocks/MockUSDC.sol";

contract MockERC20 is IERC20 {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    function mint(address to, uint256 amount) external {
        _balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _balances[msg.sender] -= amount;
        _balances[to] += amount;
        return true;
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        _allowances[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        _allowances[from][msg.sender] -= amount;
        _balances[from] -= amount;
        _balances[to] += amount;
        return true;
    }

    function totalSupply() external pure returns (uint256) {
        return 0;
    }
}

contract MultiTapTest is Test {
    MultiTap public multiTap;
    MockERC20 public token;
    MockUSDC public usdc;

    address public user = address(1);
    address public recipient1 = address(2);
    address public recipient2 = address(3);
    address public recipient3 = address(4);

    function setUp() public {
        multiTap = new MultiTap();
        token = new MockERC20();
        usdc = new MockUSDC();

        token.mint(user, 10000e18);
        usdc.mint(user, 10000e6);

        vm.startPrank(user);
        token.approve(address(multiTap), type(uint256).max);
        usdc.approve(address(multiTap), type(uint256).max);
        vm.stopPrank();
    }

    function testCreateSplit() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](3);
        splits[0] = MultiTap.Split({recipient: recipient1, share: 5000}); // 50%
        splits[1] = MultiTap.Split({recipient: recipient2, share: 3000}); // 30%
        splits[2] = MultiTap.Split({recipient: recipient3, share: 2000}); // 20%

        vm.prank(user);
        uint256 splitId = multiTap.createSplit(splits);

        assertEq(splitId, 1);
    }

    function testCreateSplitInvalidShares() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](2);
        splits[0] = MultiTap.Split({recipient: recipient1, share: 5000}); // 50%
        splits[1] = MultiTap.Split({recipient: recipient2, share: 4000}); // 40% - Total 90%

        vm.prank(user);
        vm.expectRevert("Shares must equal 100%");
        multiTap.createSplit(splits);
    }

    function testCreateSplitZeroRecipient() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](2);
        splits[0] = MultiTap.Split({recipient: address(0), share: 5000});
        splits[1] = MultiTap.Split({recipient: recipient2, share: 5000});

        vm.prank(user);
        vm.expectRevert("Invalid recipient");
        multiTap.createSplit(splits);
    }

    function testExecuteSplit() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](3);
        splits[0] = MultiTap.Split({recipient: recipient1, share: 5000}); // 50%
        splits[1] = MultiTap.Split({recipient: recipient2, share: 3000}); // 30%
        splits[2] = MultiTap.Split({recipient: recipient3, share: 2000}); // 20%

        vm.prank(user);
        uint256 splitId = multiTap.createSplit(splits);

        uint256 totalAmount = 1000e18;

        uint256 balanceBefore1 = token.balanceOf(recipient1);
        uint256 balanceBefore2 = token.balanceOf(recipient2);
        uint256 balanceBefore3 = token.balanceOf(recipient3);

        vm.prank(user);
        multiTap.executeSplit(splitId, address(token), totalAmount);

        assertEq(token.balanceOf(recipient1), balanceBefore1 + 500e18); // 50%
        assertEq(token.balanceOf(recipient2), balanceBefore2 + 300e18); // 30%
        assertEq(token.balanceOf(recipient3), balanceBefore3 + 200e18); // 20%
    }

    function testExecuteSplitNotFound() public {
        vm.prank(user);
        vm.expectRevert("Split not found");
        multiTap.executeSplit(999, address(token), 1000e18);
    }

    function testExecuteSplitWithUSDC() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](2);
        splits[0] = MultiTap.Split({recipient: recipient1, share: 6000}); // 60%
        splits[1] = MultiTap.Split({recipient: recipient2, share: 4000}); // 40%

        vm.prank(user);
        uint256 splitId = multiTap.createSplit(splits);

        uint256 totalAmount = 1000e6; // 1000 USDC

        uint256 balanceBefore1 = usdc.balanceOf(recipient1);
        uint256 balanceBefore2 = usdc.balanceOf(recipient2);

        vm.prank(user);
        multiTap.executeSplit(splitId, address(usdc), totalAmount);

        assertEq(usdc.balanceOf(recipient1), balanceBefore1 + 600e6); // 60%
        assertEq(usdc.balanceOf(recipient2), balanceBefore2 + 400e6); // 40%
    }

    function testMultipleSplits() public {
        // Create first split
        MultiTap.Split[] memory splits1 = new MultiTap.Split[](2);
        splits1[0] = MultiTap.Split({recipient: recipient1, share: 5000});
        splits1[1] = MultiTap.Split({recipient: recipient2, share: 5000});

        vm.prank(user);
        uint256 splitId1 = multiTap.createSplit(splits1);

        // Create second split
        MultiTap.Split[] memory splits2 = new MultiTap.Split[](3);
        splits2[0] = MultiTap.Split({recipient: recipient1, share: 3333});
        splits2[1] = MultiTap.Split({recipient: recipient2, share: 3333});
        splits2[2] = MultiTap.Split({recipient: recipient3, share: 3334});

        vm.prank(user);
        uint256 splitId2 = multiTap.createSplit(splits2);

        assertEq(splitId1, 1);
        assertEq(splitId2, 2);

        // Execute both splits
        vm.startPrank(user);
        multiTap.executeSplit(splitId1, address(token), 1000e18);
        multiTap.executeSplit(splitId2, address(token), 1000e18);
        vm.stopPrank();
    }

    function testCreateSplitSingleRecipient() public {
        MultiTap.Split[] memory splits = new MultiTap.Split[](1);
        splits[0] = MultiTap.Split({recipient: recipient1, share: 10000}); // 100%

        vm.prank(user);
        uint256 splitId = multiTap.createSplit(splits);

        vm.prank(user);
        multiTap.executeSplit(splitId, address(token), 1000e18);

        assertEq(token.balanceOf(recipient1), 1000e18);
    }
}
