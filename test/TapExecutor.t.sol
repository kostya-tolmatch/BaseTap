// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/TapExecutor.sol";
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

contract TapExecutorTest is Test {
    TapExecutor public executor;
    TapRegistry public registry;
    MockERC20 public token;
    MockUSDC public usdc;

    address public owner = address(1);
    address public user = address(2);
    address public recipient1 = address(3);
    address public recipient2 = address(4);
    address public recipient3 = address(5);

    function setUp() public {
        // Deploy TapRegistry
        TapRegistry registryImpl = new TapRegistry();
        bytes memory registryInitData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            owner
        );
        ERC1967Proxy registryProxy = new ERC1967Proxy(address(registryImpl), registryInitData);
        registry = TapRegistry(payable(address(registryProxy)));

        // Deploy TapExecutor
        TapExecutor executorImpl = new TapExecutor();
        bytes memory executorInitData = abi.encodeWithSelector(
            TapExecutor.initialize.selector,
            owner,
            address(registry)
        );
        ERC1967Proxy executorProxy = new ERC1967Proxy(address(executorImpl), executorInitData);
        executor = TapExecutor(address(executorProxy));

        // Setup tokens
        token = new MockERC20();
        usdc = new MockUSDC();

        token.mint(user, 10000e18);
        usdc.mint(user, 10000e6);

        vm.startPrank(user);
        token.approve(address(registry), type(uint256).max);
        usdc.approve(address(registry), type(uint256).max);
        vm.stopPrank();
    }

    function testInitialize() public {
        assertEq(executor.owner(), owner);
        assertEq(address(executor.registry()), address(registry));
    }

    function testExecuteBatch() public {
        // Create multiple taps
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient1, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient2, address(token), 200e18, 0, 0, false);
        uint256 tap3 = registry.createTap(recipient3, address(token), 300e18, 0, 0, false);
        vm.stopPrank();

        uint256[] memory tapIds = new uint256[](3);
        tapIds[0] = tap1;
        tapIds[1] = tap2;
        tapIds[2] = tap3;

        uint256 balanceBefore1 = token.balanceOf(recipient1);
        uint256 balanceBefore2 = token.balanceOf(recipient2);
        uint256 balanceBefore3 = token.balanceOf(recipient3);

        vm.prank(user);
        executor.executeBatch(tapIds);

        assertEq(token.balanceOf(recipient1), balanceBefore1 + 100e18);
        assertEq(token.balanceOf(recipient2), balanceBefore2 + 200e18);
        assertEq(token.balanceOf(recipient3), balanceBefore3 + 300e18);
    }

    function testExecuteBatchEmpty() public {
        uint256[] memory tapIds = new uint256[](0);

        vm.prank(user);
        executor.executeBatch(tapIds);
    }

    function testExecuteBatchPartialFail() public {
        // Create taps with cooldown
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient1, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient2, address(token), 200e18, 1 hours, 0, false);
        vm.stopPrank();

        // Execute tap2 first to activate cooldown
        vm.prank(user);
        registry.executeTap(tap2);

        uint256[] memory tapIds = new uint256[](2);
        tapIds[0] = tap1;
        tapIds[1] = tap2; // This will fail due to cooldown

        vm.prank(user);
        vm.expectRevert("Cooldown period active");
        executor.executeBatch(tapIds);
    }

    function testExecuteBatchSingleUse() public {
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient1, address(token), 100e18, 0, 0, true); // Single use
        vm.stopPrank();

        uint256[] memory tapIds = new uint256[](1);
        tapIds[0] = tap1;

        // First execution should succeed
        vm.prank(user);
        executor.executeBatch(tapIds);

        // Second execution should fail
        vm.prank(user);
        vm.expectRevert("Tap not active");
        executor.executeBatch(tapIds);
    }

    function testExecuteBatchMultipleTokens() public {
        // Create taps with different tokens
        vm.startPrank(user);
        uint256 tap1 = registry.createTap(recipient1, address(token), 100e18, 0, 0, false);
        uint256 tap2 = registry.createTap(recipient2, address(usdc), 50e6, 0, 0, false);
        vm.stopPrank();

        uint256[] memory tapIds = new uint256[](2);
        tapIds[0] = tap1;
        tapIds[1] = tap2;

        uint256 tokenBalanceBefore = token.balanceOf(recipient1);
        uint256 usdcBalanceBefore = usdc.balanceOf(recipient2);

        vm.prank(user);
        executor.executeBatch(tapIds);

        assertEq(token.balanceOf(recipient1), tokenBalanceBefore + 100e18);
        assertEq(usdc.balanceOf(recipient2), usdcBalanceBefore + 50e6);
    }
}
