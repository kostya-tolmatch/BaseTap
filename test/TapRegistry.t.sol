// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/TapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
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

contract TapRegistryTest is Test {
    TapRegistry public registry;
    MockERC20 public token;
    MockUSDC public usdc;
    address public owner = address(1);
    address public user = address(2);
    address public recipient = address(3);
    address public feeCollector = address(4);

    function setUp() public {
        TapRegistry implementation = new TapRegistry();
        bytes memory initData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        registry = TapRegistry(payable(address(proxy)));

        token = new MockERC20();
        usdc = new MockUSDC();

        token.mint(user, 1000e18);
        usdc.mint(user, 1000e6);

        vm.prank(user);
        token.approve(address(registry), type(uint256).max);

        vm.prank(user);
        usdc.approve(address(registry), type(uint256).max);
    }

    function testInitialize() public {
        assertEq(registry.owner(), owner);
        assertFalse(registry.paused());
    }

    function testCreateTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        assertEq(tapId, 1);
        assertEq(registry.tapOwners(tapId), user);
    }

    function testCreateTapZeroRecipient() public {
        vm.prank(user);
        vm.expectRevert("Invalid recipient");
        registry.createTap(address(0), address(token), 100e18, 0, 0, false);
    }

    function testCreateTapZeroAsset() public {
        vm.prank(user);
        vm.expectRevert("Invalid asset");
        registry.createTap(recipient, address(0), 100e18, 0, 0, false);
    }

    function testCreateTapZeroAmount() public {
        vm.prank(user);
        vm.expectRevert("Invalid amount");
        registry.createTap(recipient, address(token), 0, 0, 0, false);
    }

    function testExecuteTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        uint256 balanceBefore = token.balanceOf(recipient);

        vm.prank(user);
        registry.executeTap(tapId);

        assertEq(token.balanceOf(recipient), balanceBefore + 100e18);
    }

    function testExecuteTapInsufficientBalance() public {
        address poorUser = address(100);

        vm.prank(poorUser);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(poorUser);
        token.approve(address(registry), type(uint256).max);

        vm.prank(poorUser);
        vm.expectRevert();
        registry.executeTap(tapId);
    }

    function testExecuteTapInsufficientAllowance() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        token.approve(address(registry), 0);

        vm.prank(user);
        vm.expectRevert();
        registry.executeTap(tapId);
    }

    function testExecuteTapNotActive() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.deactivateTap(tapId);

        vm.prank(user);
        vm.expectRevert("Tap not active");
        registry.executeTap(tapId);
    }

    function testUpdateTapNotOwner() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        address attacker = address(999);
        vm.prank(attacker);
        vm.expectRevert("Not tap owner");
        registry.updateTap(tapId, 200e18, 1 hours);
    }

    function testDeactivateTapNotOwner() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        address attacker = address(999);
        vm.prank(attacker);
        vm.expectRevert("Not tap owner");
        registry.deactivateTap(tapId);
    }

    function testDeactivateTapAlreadyDeactivated() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.deactivateTap(tapId);

        vm.prank(user);
        vm.expectRevert("Already deactivated");
        registry.deactivateTap(tapId);
    }

    function testTransferOwnership() public {
        address newOwner = address(500);

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.transferTapOwnership(tapId, newOwner);

        assertEq(registry.tapOwners(tapId), newOwner);
    }

    function testTransferOwnershipNotOwner() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        address attacker = address(999);
        vm.prank(attacker);
        vm.expectRevert("Not owner");
        registry.transferTapOwnership(tapId, attacker);
    }

    function testTransferOwnershipZeroAddress() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        vm.expectRevert("Invalid new owner");
        registry.transferTapOwnership(tapId, address(0));
    }

    function testSetMetadata() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.setTapMetadata(tapId, "Coffee Payment", "Pay for daily coffee");

        (string memory label, string memory description) = registry.getTapMetadata(tapId);
        assertEq(label, "Coffee Payment");
        assertEq(description, "Pay for daily coffee");
    }

    function testSetMetadataNotOwner() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        address attacker = address(999);
        vm.prank(attacker);
        vm.expectRevert("Not owner");
        registry.setTapMetadata(tapId, "Malicious", "Attack");
    }

    function testCanExecute() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 1 hours, 2, false);

        assertTrue(registry.canExecute(tapId));

        vm.prank(user);
        registry.executeTap(tapId);

        assertFalse(registry.canExecute(tapId)); // Cooldown active

        vm.warp(block.timestamp + 1 hours);
        assertTrue(registry.canExecute(tapId));

        vm.prank(user);
        registry.executeTap(tapId);
        assertFalse(registry.canExecute(tapId)); // Daily limit reached
    }

    function testGetUserTaps() public {
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient, address(token), 200e18, 0, 0, false);
        uint256 tap3 = registry.createTap(recipient, address(token), 300e18, 0, 0, false);
        vm.stopPrank();

        uint256[] memory userTaps = registry.getUserTaps(user);
        assertEq(userTaps.length, 3);
        assertEq(userTaps[0], tap1);
        assertEq(userTaps[1], tap2);
        assertEq(userTaps[2], tap3);
    }

    function testGetActiveTaps() public {
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient, address(token), 200e18, 0, 0, false);
        uint256 tap3 = registry.createTap(recipient, address(token), 300e18, 0, 0, false);

        registry.deactivateTap(tap2);
        vm.stopPrank();

        uint256[] memory activeTaps = registry.getActiveTaps(user);
        assertEq(activeTaps.length, 2);
        assertEq(activeTaps[0], tap1);
        assertEq(activeTaps[1], tap3);
    }

    function testGetExecutionHistory() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(user);
        registry.executeTap(tapId);

        TapRegistry.ExecutionHistory[] memory history = registry.getExecutionHistory(tapId);
        assertEq(history.length, 2);
        assertEq(history[0].executor, user);
        assertEq(history[1].executor, user);
    }

    function testProtocolFee() public {
        vm.prank(owner);
        registry.setFeeCollector(feeCollector);

        vm.prank(owner);
        registry.setProtocolFee(500); // 5%

        assertEq(registry.protocolFeePercent(), 500);
        assertEq(registry.feeCollector(), feeCollector);
    }

    function testSetProtocolFeeNotOwner() public {
        address attacker = address(999);
        vm.prank(attacker);
        vm.expectRevert();
        registry.setProtocolFee(500);
    }

    function testSetProtocolFeeTooHigh() public {
        vm.prank(owner);
        vm.expectRevert("Fee too high");
        registry.setProtocolFee(1001); // > 10%
    }

    function testEmergencyWithdrawNotPaused() public {
        vm.prank(owner);
        vm.expectRevert("Must be paused");
        registry.emergencyWithdrawToken(address(token), 100e18, owner);
    }

    function testEmergencyWithdrawToken() public {
        // Send tokens to registry
        token.mint(address(registry), 500e18);

        vm.prank(owner);
        registry.pause();

        uint256 balanceBefore = token.balanceOf(owner);

        vm.prank(owner);
        registry.emergencyWithdrawToken(address(token), 100e18, owner);

        assertEq(token.balanceOf(owner), balanceBefore + 100e18);
    }

    function testPauseUnpause() public {
        assertFalse(registry.paused());

        vm.prank(owner);
        registry.pause();

        assertTrue(registry.paused());

        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.prank(user);
        vm.expectRevert();
        registry.executeTap(tapId);

        vm.prank(owner);
        registry.unpause();

        assertFalse(registry.paused());

        vm.prank(user);
        registry.executeTap(tapId);
    }
}


contract CooldownTest is TapRegistryTest {
    function testCooldownEnforced() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, 1 hours, 0, false);

        vm.prank(user);
        registry.executeTap(tapId);

        vm.expectRevert("Cooldown period active");
        vm.prank(user);
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(user);
        registry.executeTap(tapId);
    }
}


contract DailyLimitTest is TapRegistryTest {
    function testDailyLimitEnforced() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 10e18, 0, 2, false);

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);

        vm.expectRevert("Daily limit reached");
        registry.executeTap(tapId);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.prank(user);
        registry.executeTap(tapId);
    }
}


contract SingleUseTest is TapRegistryTest {
    function testSingleUseTapDeactivates() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, true);

        vm.prank(user);
        registry.executeTap(tapId);

        vm.expectRevert("Tap not active");
        vm.prank(user);
        registry.executeTap(tapId);
    }
}


contract UpdateDeactivateTest is TapRegistryTest {
    function testUpdateTap() public {
        vm.startPrank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        registry.updateTap(tapId, 200e18, 1 hours);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, 200e18);
        assertEq(tap.cooldown, 1 hours);
        vm.stopPrank();
    }

    function testDeactivateTap() public {
        vm.startPrank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        registry.deactivateTap(tapId);

        vm.expectRevert("Tap not active");
        registry.executeTap(tapId);
        vm.stopPrank();
    }
}

contract GlobalCapTest is TapRegistryTest {
    function testCreateTapWithGlobalCap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            300e18,
            false
        );

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(registry.getGlobalCap(tapId), 300e18);
        assertEq(tap.amount, 100e18);
    }

    function testUpdateTapAmountExceedsRemainingCap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            300e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);
        vm.stopPrank();

        assertEq(registry.getTotalExecuted(tapId), 200e18);

        vm.prank(user);
        vm.expectRevert("Amount exceeds remaining global cap");
        registry.updateTap(tapId, 150e18, 0);
    }

    function testUpdateTapAmountWithinRemainingCap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            300e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 100e18);

        registry.updateTap(tapId, 200e18, 0);
        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, 200e18);

        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 300e18);

        tap = registry.getTap(tapId);
        assertFalse(tap.active);
        vm.stopPrank();
    }

    function testUpdateTapReduceAmount() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            500e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 100e18);

        registry.updateTap(tapId, 50e18, 0);
        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, 50e18);

        for (uint256 i = 0; i < 8; i++) {
            registry.executeTap(tapId);
        }
        assertEq(registry.getTotalExecuted(tapId), 500e18);

        tap = registry.getTap(tapId);
        assertFalse(tap.active);
        vm.stopPrank();
    }

    function testUpdateTapNoGlobalCapAllowsAnyAmount() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        vm.startPrank(user);
        for (uint256 i = 0; i < 5; i++) {
            registry.executeTap(tapId);
        }

        token.mint(user, 10000e18);

        registry.updateTap(tapId, 1000e18, 0);
        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, 1000e18);

        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 1500e18);
        vm.stopPrank();
    }

    function testGlobalCapEnforcement() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            250e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 100e18);

        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 200e18);

        vm.expectRevert("Global cap reached");
        registry.executeTap(tapId);
        vm.stopPrank();
    }

    function testGlobalCapAutoDeactivation() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            200e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertTrue(tap.active);

        registry.executeTap(tapId);
        tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 200e18);

        vm.expectRevert("Tap not active");
        registry.executeTap(tapId);
        vm.stopPrank();
    }

    function testGlobalCapWithCooldown() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            1 hours,
            0,
            300e18,
            false
        );

        vm.prank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 100e18);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 200e18);

        vm.warp(block.timestamp + 1 hours + 1);

        vm.prank(user);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 300e18);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
    }

    function testGlobalCapInvalidCreation() public {
        vm.prank(user);
        vm.expectRevert("Global cap must be >= amount");
        registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            50e18,
            false
        );
    }

    function testGlobalCapETH() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETHWithCap(
            recipient,
            0.1 ether,
            0,
            0,
            0.3 ether,
            false
        );

        vm.startPrank(user);
        registry.executeTap{value: 0.1 ether}(tapId);
        assertEq(registry.getTotalExecuted(tapId), 0.1 ether);

        registry.executeTap{value: 0.1 ether}(tapId);
        assertEq(registry.getTotalExecuted(tapId), 0.2 ether);

        registry.executeTap{value: 0.1 ether}(tapId);
        assertEq(registry.getTotalExecuted(tapId), 0.3 ether);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        vm.stopPrank();
    }

    function testGlobalCapZeroAllowed() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            0,
            false
        );

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(registry.getGlobalCap(tapId), 0);

        vm.startPrank(user);
        for (uint256 i = 0; i < 10; i++) {
            registry.executeTap(tapId);
        }
        vm.stopPrank();

        assertEq(registry.getTotalExecuted(tapId), 1000e18);
        assertTrue(registry.getTap(tapId).active);
    }
}

contract NativeETHTest is TapRegistryTest {
    function testCreateETHTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 0, false);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.recipient, recipient);
        assertEq(tap.asset, address(0));
        assertEq(tap.amount, 0.1 ether);
        assertTrue(tap.active);
    }

    function testExecuteETHTap() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 0, false);

        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(user);
        registry.executeTap{value: 0.1 ether}(tapId);

        assertEq(recipient.balance, recipientBalanceBefore + 0.1 ether);
    }

    function testExecuteETHTapWithCooldown() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 1 hours, 0, false);

        vm.startPrank(user);
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.expectRevert("Cooldown period active");
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.warp(block.timestamp + 1 hours);
        registry.executeTap{value: 0.1 ether}(tapId);
        vm.stopPrank();

        assertEq(registry.getTotalExecuted(tapId), 0.2 ether);
    }

    function testExecuteETHTapWithDailyLimit() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 3, false);

        vm.startPrank(user);
        registry.executeTap{value: 0.1 ether}(tapId);
        registry.executeTap{value: 0.1 ether}(tapId);
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.expectRevert("Daily limit reached");
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.warp(block.timestamp + 1 days);
        registry.executeTap{value: 0.1 ether}(tapId);
        vm.stopPrank();

        assertEq(registry.getTotalExecuted(tapId), 0.4 ether);
    }

    function testExecuteETHTapWithGlobalCap() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETHWithCap(recipient, 0.1 ether, 0, 0, 0.3 ether, false);

        vm.startPrank(user);
        registry.executeTap{value: 0.1 ether}(tapId);
        registry.executeTap{value: 0.1 ether}(tapId);
        registry.executeTap{value: 0.1 ether}(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 0.3 ether);
        vm.stopPrank();
    }

    function testExecuteETHTapWithAllLimits() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETHWithCap(
            recipient,
            0.1 ether,
            30 minutes,
            2,
            1 ether,
            false
        );

        vm.startPrank(user);
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.expectRevert("Cooldown period active");
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.warp(block.timestamp + 30 minutes);
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.warp(block.timestamp + 30 minutes);
        vm.expectRevert("Daily limit reached");
        registry.executeTap{value: 0.1 ether}(tapId);

        vm.warp(block.timestamp + 1 days);
        for (uint256 i = 0; i < 8; i++) {
            registry.executeTap{value: 0.1 ether}(tapId);
            if (i < 7) {
                vm.warp(block.timestamp + 30 minutes);
            }
        }

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 1 ether);
        vm.stopPrank();
    }

    function testETHTapInsufficientValue() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 0, false);

        vm.prank(user);
        vm.expectRevert("Insufficient ETH");
        registry.executeTap{value: 0.05 ether}(tapId);
    }

    function testETHTapRefundsExcess() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 0, false);

        uint256 userBalanceBefore = user.balance;
        uint256 recipientBalanceBefore = recipient.balance;

        vm.prank(user);
        registry.executeTap{value: 0.2 ether}(tapId);

        assertEq(recipient.balance, recipientBalanceBefore + 0.1 ether);
        assertEq(user.balance, userBalanceBefore - 0.1 ether);
    }

    function testETHTapSingleUse() public {
        vm.deal(user, 10 ether);

        vm.prank(user);
        uint256 tapId = registry.createTapETH(recipient, 0.1 ether, 0, 0, true);

        vm.prank(user);
        registry.executeTap{value: 0.1 ether}(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);

        vm.prank(user);
        vm.expectRevert("Tap not active");
        registry.executeTap{value: 0.1 ether}(tapId);
    }
}

contract ComplexEdgeCaseTest is TapRegistryTest {
    function testGlobalCapReachedBeforeDailyLimitReset() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            5,
            300e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);
        registry.executeTap(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 300e18);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert("Tap not active");
        registry.executeTap(tapId);
        vm.stopPrank();
    }

    function testDailyLimitResetWithGlobalCapRemaining() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            2,
            1000e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 200e18);

        vm.expectRevert("Daily limit reached");
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 days);

        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 300e18);
        assertTrue(registry.getTap(tapId).active);
        vm.stopPrank();
    }

    function testCooldownWithDailyLimitAndGlobalCap() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            1 hours,
            3,
            600e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 hours);
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 hours);
        registry.executeTap(tapId);

        assertEq(registry.getTotalExecuted(tapId), 300e18);

        vm.warp(block.timestamp + 1 hours);
        vm.expectRevert("Daily limit reached");
        registry.executeTap(tapId);

        vm.warp(block.timestamp + 1 days);

        registry.executeTap(tapId);
        vm.warp(block.timestamp + 1 hours);
        registry.executeTap(tapId);
        vm.warp(block.timestamp + 1 hours);
        registry.executeTap(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 600e18);
        vm.stopPrank();
    }

    function testUpdateAmountAfterPartialExecution() public {
        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            500e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);
        assertEq(registry.getTotalExecuted(tapId), 200e18);

        registry.updateTap(tapId, 75e18, 0);

        registry.executeTap(tapId);
        registry.executeTap(tapId);
        registry.executeTap(tapId);
        registry.executeTap(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);
        assertEq(registry.getTotalExecuted(tapId), 500e18);
        vm.stopPrank();
    }

    function testDeactivateTapWithPendingCooldown() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 1 hours, 0, false);

        vm.startPrank(user);
        registry.executeTap(tapId);

        assertFalse(registry.canExecute(tapId));

        registry.deactivateTap(tapId);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertFalse(tap.active);

        vm.warp(block.timestamp + 1 hours);

        vm.expectRevert("Tap not active");
        registry.executeTap(tapId);
        vm.stopPrank();
    }

    function testTransferOwnershipMidExecution() public {
        address newOwner = address(999);

        vm.prank(user);
        uint256 tapId = registry.createTapWithCap(
            recipient,
            address(token),
            100e18,
            0,
            0,
            500e18,
            false
        );

        vm.startPrank(user);
        registry.executeTap(tapId);
        registry.executeTap(tapId);

        registry.transferTapOwnership(tapId, newOwner);
        vm.stopPrank();

        assertEq(registry.tapOwners(tapId), newOwner);

        vm.prank(user);
        vm.expectRevert("Not tap owner");
        registry.updateTap(tapId, 150e18, 0);

        vm.prank(newOwner);
        registry.updateTap(tapId, 150e18, 0);

        TapRegistry.TapPreset memory tap = registry.getTap(tapId);
        assertEq(tap.amount, 150e18);
    }
}
