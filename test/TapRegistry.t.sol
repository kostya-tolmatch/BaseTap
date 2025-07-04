// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import "../src/TapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

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
    address public owner = address(1);
    address public user = address(2);
    address public recipient = address(3);

    function setUp() public {
        TapRegistry implementation = new TapRegistry();
        bytes memory initData = abi.encodeWithSelector(
            TapRegistry.initialize.selector,
            owner
        );
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        registry = TapRegistry(address(proxy));

        token = new MockERC20();
        token.mint(user, 1000e18);

        vm.prank(user);
        token.approve(address(registry), type(uint256).max);
    }

    function testCreateTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);
        assertEq(tapId, 1);
        assertEq(registry.tapOwners(tapId), user);
    }

    function testExecuteTap() public {
        vm.prank(user);
        uint256 tapId = registry.createTap(recipient, address(token), 100e18, 0, 0, false);

        uint256 balanceBefore = token.balanceOf(recipient);

        vm.prank(user);
        registry.executeTap(tapId);

        assertEq(token.balanceOf(recipient), balanceBefore + 100e18);
    }
}
