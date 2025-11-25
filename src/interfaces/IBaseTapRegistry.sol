// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

interface IBaseTapRegistry {
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

    function createSession(
        address recipient,
        uint256 amount,
        address asset,
        string calldata metadata
    ) external returns (bytes32 sessionId);

    function markPaid(
        bytes32 sessionId,
        string calldata paymentId
    ) external;

    function cancelSession(bytes32 sessionId) external;

    function getSession(bytes32 sessionId)
        external
        view
        returns (PaymentSession memory);

    function getSessionByPaymentId(string calldata paymentId)
        external
        view
        returns (PaymentSession memory);

    function isSessionPaid(bytes32 sessionId) external view returns (bool);

    function getSessionStatus(bytes32 sessionId)
        external
        view
        returns (PaymentStatus);
}
