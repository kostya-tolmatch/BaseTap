// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract BaseTapRegistry is
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable
{
    enum PaymentStatus {
        Pending,
        Paid,
        Cancelled
    }

    struct PaymentSession {
        bytes32 sessionId;
        address creator;
        address recipient;
        uint256 amount;
        address asset;
        uint256 createdAt;
        uint256 paidAt;
        string paymentId;
        PaymentStatus status;
        string metadata;
    }

    mapping(bytes32 => PaymentSession) private sessions;
    mapping(bytes32 => bool) private sessionExists;
    mapping(string => bytes32) private paymentIdToSession;

    uint256 private sessionCounter;

    event SessionCreated(
        bytes32 indexed sessionId,
        address indexed creator,
        address indexed recipient,
        uint256 amount,
        address asset,
        string metadata
    );

    event SessionPaid(
        bytes32 indexed sessionId,
        string paymentId,
        uint256 timestamp
    );

    event SessionCancelled(
        bytes32 indexed sessionId,
        uint256 timestamp
    );

    error SessionAlreadyExists();
    error SessionNotFound();
    error SessionAlreadyPaid();
    error SessionAlreadyCancelled();
    error InvalidRecipient();
    error InvalidAmount();
    error PaymentIdAlreadyUsed();
    error UnauthorizedCancellation();

    function initialize(address initialOwner) external initializer {
        __Ownable_init(initialOwner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
    }

    function createSession(
        address recipient,
        uint256 amount,
        address asset,
        string calldata metadata
    ) external returns (bytes32 sessionId) {
        if (recipient == address(0)) revert InvalidRecipient();
        if (amount == 0) revert InvalidAmount();

        sessionId = keccak256(
            abi.encodePacked(
                msg.sender,
                recipient,
                amount,
                asset,
                block.timestamp,
                sessionCounter++
            )
        );

        if (sessionExists[sessionId]) revert SessionAlreadyExists();

        sessions[sessionId] = PaymentSession({
            sessionId: sessionId,
            creator: msg.sender,
            recipient: recipient,
            amount: amount,
            asset: asset,
            createdAt: block.timestamp,
            paidAt: 0,
            paymentId: "",
            status: PaymentStatus.Pending,
            metadata: metadata
        });

        sessionExists[sessionId] = true;

        emit SessionCreated(
            sessionId,
            msg.sender,
            recipient,
            amount,
            asset,
            metadata
        );

        return sessionId;
    }

    function markPaid(
        bytes32 sessionId,
        string calldata paymentId
    ) external nonReentrant {
        if (!sessionExists[sessionId]) revert SessionNotFound();

        PaymentSession storage session = sessions[sessionId];

        if (session.status == PaymentStatus.Paid) {
            revert SessionAlreadyPaid();
        }
        if (session.status == PaymentStatus.Cancelled) {
            revert SessionAlreadyCancelled();
        }

        bytes memory paymentIdBytes = bytes(paymentId);
        if (paymentIdBytes.length > 0) {
            if (paymentIdToSession[paymentId] != bytes32(0)) {
                revert PaymentIdAlreadyUsed();
            }
            paymentIdToSession[paymentId] = sessionId;
        }

        session.status = PaymentStatus.Paid;
        session.paidAt = block.timestamp;
        session.paymentId = paymentId;

        emit SessionPaid(sessionId, paymentId, block.timestamp);
    }

    function cancelSession(bytes32 sessionId) external {
        if (!sessionExists[sessionId]) revert SessionNotFound();

        PaymentSession storage session = sessions[sessionId];

        if (msg.sender != session.creator && msg.sender != owner()) {
            revert UnauthorizedCancellation();
        }

        if (session.status == PaymentStatus.Paid) {
            revert SessionAlreadyPaid();
        }
        if (session.status == PaymentStatus.Cancelled) {
            revert SessionAlreadyCancelled();
        }

        session.status = PaymentStatus.Cancelled;

        emit SessionCancelled(sessionId, block.timestamp);
    }

    function getSession(bytes32 sessionId)
        external
        view
        returns (PaymentSession memory)
    {
        if (!sessionExists[sessionId]) revert SessionNotFound();
        return sessions[sessionId];
    }

    function getSessionByPaymentId(string calldata paymentId)
        external
        view
        returns (PaymentSession memory)
    {
        bytes32 sessionId = paymentIdToSession[paymentId];
        if (sessionId == bytes32(0)) revert SessionNotFound();
        return sessions[sessionId];
    }

    function isSessionPaid(bytes32 sessionId) external view returns (bool) {
        if (!sessionExists[sessionId]) return false;
        return sessions[sessionId].status == PaymentStatus.Paid;
    }

    function getSessionStatus(bytes32 sessionId)
        external
        view
        returns (PaymentStatus)
    {
        if (!sessionExists[sessionId]) revert SessionNotFound();
        return sessions[sessionId].status;
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    uint256[44] private __gap;
}
