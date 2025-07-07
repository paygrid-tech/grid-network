// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../abstract/PaymentCoreBase.sol";

interface IGridPaymentGateway {

    /// @notice Initializes the contract
    /// @param _permit2 The address of the Permit2 contract
    /// @param defaultConfig The default gateway configuration
    function initialize(address _permit2, PaymentCoreBase.GatewayConfig memory defaultConfig) external;

    /// @notice Initiates a new payment intent
    /// @param intent The payment intent
    /// @param config The payment gateway configuration
    /// @param signature The EIP-712 signature
    function initiatePaymentIntent(
        PaymentCoreBase.PaymentIntent calldata intent,
        PaymentCoreBase.GatewayConfig calldata config,
        bytes calldata signature
    ) external;

    /// @notice Processes a payment by its ID
    /// @param paymentId The ID of the payment to process
    /// @param operator The address of the operator
    function processPaymentById(bytes32 paymentId, address operator) external;

    /// @notice Cancels a recurring payment
    /// @param payment_id The ID of the payment to cancel
    /// @param operator The address of the operator
    function cancelRecurringPayment(bytes32 payment_id, address operator) external;

    /// @notice Retrieves a payment intent record
    /// @param operator The address of the operator
    /// @param paymentId The ID of the payment intent
    /// @return The payment intent record
    function getPaymentIntentById(address operator, bytes32 paymentId) 
        external view returns (PaymentCoreBase.PaymentIntentRecord memory);

    function version() external pure returns (string memory);

    // Events
    event PaymentIntentInitiated(bytes32 indexed paymentId, address indexed operator);
    event PaymentIntentProcessed(bytes32 indexed paymentId, address indexed operator, bool success);
    event RecurringPaymentCancelled(bytes32 indexed paymentId, address indexed operator);
    event PaymentIntentSignatureInvalid(
        bytes32 indexed paymentId,
        address indexed operator,
        address indexed source,
        address destination,
        string reason
    );

    event PaymentIntentValidationError(
        bytes32 indexed paymentId,
        address indexed operator,
        address indexed source,
        address destination,
        string reason
    );
}