// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Test.sol";
import {BaseTapRegistry} from "../src/BaseTapRegistry.sol";
import {IBaseTapRegistry} from "../src/interfaces/IBaseTapRegistry.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract BaseTapRegistryTest is Test {
    BaseTapRegistry public registry;
    BaseTapRegistry public implementation;

    address public owner = address(0x1);
    address public creator = address(0x2);
    address public recipient = address(0x3);
    address public unauthorized = address(0x4);

    address public asset = address(0x5);
    uint256 public amount = 100 ether;
    string public metadata = "test donation";

    function setUp() public {
        implementation = new BaseTapRegistry();

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

    function testInitialization() public view {
        assertEq(registry.owner(), owner);
    }

    function testCreateSession() public {
        vm.prank(creator);

        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        assertTrue(sessionId != bytes32(0));

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertEq(session.creator, creator);
        assertEq(session.recipient, recipient);
        assertEq(session.amount, amount);
        assertEq(session.asset, asset);
        assertEq(session.createdAt, block.timestamp);
        assertEq(session.paidAt, 0);
        assertEq(session.paymentId, "");
        assertTrue(
            session.status == BaseTapRegistry.PaymentStatus.Pending
        );
        assertEq(session.metadata, metadata);
    }

    function testCreateSessionInvalidRecipient() public {
        vm.prank(creator);
        vm.expectRevert(IBaseTapRegistry.InvalidRecipient.selector);
        registry.createSession(address(0), amount, asset, metadata);
    }

    function testCreateSessionZeroAmount() public {
        vm.prank(creator);
        vm.expectRevert(IBaseTapRegistry.InvalidAmount.selector);
        registry.createSession(recipient, 0, asset, metadata);
    }

    function testMarkPaid() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        string memory paymentId = "base_pay_12345";

        vm.expectEmit(true, true, true, true);
        emit IBaseTapRegistry.SessionPaid(
            sessionId,
            paymentId,
            block.timestamp
        );

        vm.prank(owner);
        registry.markPaid(sessionId, paymentId);

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertTrue(
            session.status == BaseTapRegistry.PaymentStatus.Paid
        );
        assertEq(session.paymentId, paymentId);
        assertEq(session.paidAt, block.timestamp);

        assertTrue(registry.isSessionPaid(sessionId));
    }

    function testMarkPaidSessionNotFound() public {
        bytes32 fakeSessionId = keccak256("fake");

        vm.prank(owner);
        vm.expectRevert(IBaseTapRegistry.SessionNotFound.selector);
        registry.markPaid(fakeSessionId, "payment_123");
    }

    function testMarkPaidAlreadyPaid() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(owner);
        registry.markPaid(sessionId, "payment_1");

        vm.prank(owner);
        vm.expectRevert(IBaseTapRegistry.SessionAlreadyPaid.selector);
        registry.markPaid(sessionId, "payment_2");
    }

    function testMarkPaidDuplicatePaymentId() public {
        vm.prank(creator);
        bytes32 sessionId1 = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.warp(block.timestamp + 1);

        vm.prank(creator);
        bytes32 sessionId2 = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        string memory paymentId = "payment_same";

        vm.prank(owner);
        registry.markPaid(sessionId1, paymentId);

        vm.prank(owner);
        vm.expectRevert(IBaseTapRegistry.PaymentIdAlreadyUsed.selector);
        registry.markPaid(sessionId2, paymentId);
    }

    function testCancelSession() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.expectEmit(true, true, true, true);
        emit IBaseTapRegistry.SessionCancelled(
            sessionId,
            block.timestamp
        );

        vm.prank(creator);
        registry.cancelSession(sessionId);

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertTrue(
            session.status == BaseTapRegistry.PaymentStatus.Cancelled
        );
    }

    function testCancelSessionByOwner() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(owner);
        registry.cancelSession(sessionId);

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertTrue(
            session.status == BaseTapRegistry.PaymentStatus.Cancelled
        );
    }

    function testCancelSessionUnauthorized() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(unauthorized);
        vm.expectRevert(
            IBaseTapRegistry.UnauthorizedCancellation.selector
        );
        registry.cancelSession(sessionId);
    }

    function testCancelSessionAlreadyPaid() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(owner);
        registry.markPaid(sessionId, "payment_123");

        vm.prank(creator);
        vm.expectRevert(IBaseTapRegistry.SessionAlreadyPaid.selector);
        registry.cancelSession(sessionId);
    }

    function testCancelSessionAlreadyCancelled() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(creator);
        registry.cancelSession(sessionId);

        vm.prank(creator);
        vm.expectRevert(
            IBaseTapRegistry.SessionAlreadyCancelled.selector
        );
        registry.cancelSession(sessionId);
    }

    function testGetSessionByPaymentId() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        string memory paymentId = "payment_unique";

        vm.prank(owner);
        registry.markPaid(sessionId, paymentId);

        BaseTapRegistry.PaymentSession memory session = registry
            .getSessionByPaymentId(paymentId);

        assertEq(session.sessionId, sessionId);
        assertEq(session.paymentId, paymentId);
    }

    function testGetSessionByPaymentIdNotFound() public {
        vm.expectRevert(IBaseTapRegistry.SessionNotFound.selector);
        registry.getSessionByPaymentId("nonexistent");
    }

    function testGetSessionStatus() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        BaseTapRegistry.PaymentStatus status = registry.getSessionStatus(
            sessionId
        );
        assertTrue(status == BaseTapRegistry.PaymentStatus.Pending);

        vm.prank(owner);
        registry.markPaid(sessionId, "payment_123");

        status = registry.getSessionStatus(sessionId);
        assertTrue(status == BaseTapRegistry.PaymentStatus.Paid);
    }

    function testIsSessionPaidNonexistent() public view {
        bytes32 fakeId = keccak256("fake");
        assertFalse(registry.isSessionPaid(fakeId));
    }

    function testMultipleSessions() public {
        vm.startPrank(creator);

        bytes32 session1 = registry.createSession(
            recipient,
            100 ether,
            asset,
            "donation 1"
        );

        vm.warp(block.timestamp + 1);

        bytes32 session2 = registry.createSession(
            recipient,
            200 ether,
            asset,
            "donation 2"
        );

        assertTrue(session1 != session2);

        BaseTapRegistry.PaymentSession memory s1 = registry.getSession(
            session1
        );
        BaseTapRegistry.PaymentSession memory s2 = registry.getSession(
            session2
        );

        assertEq(s1.amount, 100 ether);
        assertEq(s2.amount, 200 ether);

        vm.stopPrank();
    }

    function testMarkPaidWithEmptyPaymentId() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(owner);
        registry.markPaid(sessionId, "");

        BaseTapRegistry.PaymentSession memory session = registry.getSession(
            sessionId
        );

        assertTrue(
            session.status == BaseTapRegistry.PaymentStatus.Paid
        );
        assertEq(session.paymentId, "");
    }

    function testReentrancyProtection() public {
        vm.prank(creator);
        bytes32 sessionId = registry.createSession(
            recipient,
            amount,
            asset,
            metadata
        );

        vm.prank(owner);
        registry.markPaid(sessionId, "payment_123");
    }
}
