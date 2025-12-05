// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {BaseTapRegistry} from "../src/BaseTapRegistry.sol";
import {IBaseTapRegistry} from "../src/interfaces/IBaseTapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BaseTapRegistryFuzzTest is Test {
    BaseTapRegistry public registry;
    address public owner = address(0x1);

    function setUp() public {
        BaseTapRegistry implementation = new BaseTapRegistry();

        bytes memory initData = abi.encodeWithSelector(
            BaseTapRegistry.initialize.selector,
            owner
        );

        ERC1967Proxy proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );

        registry = BaseTapRegistry(address(proxy));
    }

    function testFuzzCreateSession(
        address creator,
        address recipient,
        uint256 amount,
        address asset
    ) public {
        vm.assume(creator != address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);
        vm.assume(amount < type(uint128).max);

        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            "fuzz test"
        );

        assertTrue(sessionId != bytes32(0));

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertEq(session.creator, creator);
        assertEq(session.recipient, recipient);
        assertEq(session.amount, amount);
        assertEq(session.asset, asset);
    }

    function testFuzzMarkPaid(
        address creator,
        address recipient,
        uint256 amount,
        string calldata paymentId
    ) public {
        vm.assume(creator != address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);
        vm.assume(amount < type(uint128).max);
        vm.assume(bytes(paymentId).length > 0);
        vm.assume(bytes(paymentId).length < 256);

        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            address(0),
            "test"
        );

        vm.prank(owner);
        registry.markPaid(sessionId, paymentId);

        assertTrue(registry.isSessionPaid(sessionId));

        BaseTapRegistry.PaymentSession memory session = registry
            .getSessionByPaymentId(paymentId);

        assertEq(session.sessionId, sessionId);
    }

    function testFuzzCancelSession(
        address creator,
        address recipient,
        uint256 amount
    ) public {
        vm.assume(creator != address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);
        vm.assume(amount < type(uint128).max);

        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            address(0),
            "test"
        );

        vm.prank(creator);
        registry.cancelSession(sessionId);

        BaseTapRegistry.PaymentStatus status = registry.getSessionStatus(
            sessionId
        );

        assertTrue(status == BaseTapRegistry.PaymentStatus.Cancelled);
    }

    function testFuzzMultipleSessions(
        address creator,
        uint8 sessionCount
    ) public {
        vm.assume(creator != address(0));
        vm.assume(sessionCount > 0 && sessionCount < 50);

        vm.startPrank(creator);

        bytes32[] memory sessionIds = new bytes32[](sessionCount);

        for (uint256 i = 0; i < sessionCount; i++) {
            sessionIds[i] = registry.createSession(
                address(uint160(i + 1)),
                (i + 1) * 1 ether,
                address(0),
                "session"
            );

            assertTrue(sessionIds[i] != bytes32(0));

            for (uint256 j = 0; j < i; j++) {
                assertTrue(sessionIds[i] != sessionIds[j]);
            }

            vm.warp(block.timestamp + 1);
        }

        vm.stopPrank();
    }

    function testFuzzInvalidRecipient(
        address creator,
        uint256 amount
    ) public {
        vm.assume(creator != address(0));
        vm.assume(amount > 0);

        vm.prank(creator);
        vm.expectRevert(IBaseTapRegistry.InvalidRecipient.selector);
        registry.createSession(address(0), amount, address(0), "test");
    }

    function testFuzzUnauthorizedCancellation(
        address creator,
        address unauthorized,
        address recipient,
        uint256 amount
    ) public {
        vm.assume(creator != address(0));
        vm.assume(unauthorized != address(0));
        vm.assume(recipient != address(0));
        vm.assume(amount > 0);
        vm.assume(creator != unauthorized);
        vm.assume(unauthorized != owner);

        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            address(0),
            "test"
        );

        vm.prank(unauthorized);
        vm.expectRevert(
            IBaseTapRegistry.UnauthorizedCancellation.selector
        );
        registry.cancelSession(sessionId);
    }

    function testFuzzMetadata(
        address creator,
        address recipient,
        string calldata metadata
    ) public {
        vm.assume(creator != address(0));
        vm.assume(recipient != address(0));
        vm.assume(bytes(metadata).length < 1024);

        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            1 ether,
            address(0),
            metadata
        );

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertEq(session.metadata, metadata);
    }
}
