// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ISignatureTransfer} from "../helpers/Permit2/src/interfaces/IPermit2.sol";

abstract contract PaymentCoreBase {
    enum IntervalUnit { DAY, WEEK, MONTH, YEAR }
    enum PaymentStatus { PROCESSING, SCHEDULED, COMPLETED, FAILED, CANCELLED }
    enum PaymentType { ONE_TIME, RECURRING }

    // Type hashes
    bytes32 public constant PAYMENT_INTENT_TYPEHASH = keccak256(
        "PaymentIntent(bytes32 paymentId,uint8 payment_type,OperatorData operator_data,uint256 amount,Domain source,Domain destination,uint256 processing_date,uint256 expires_at,Schedule schedule,uint256 nonce,string payment_reference,bytes p2_sig)"
    );
    
    bytes32 public constant OPERATOR_DATA_TYPEHASH = keccak256(
        "OperatorData(bytes32 operatorId,address operator,bytes32 authorized_signers,address treasury_account,uint256 fee,string operatorURI)"
    );
    
    bytes32 public constant DOMAIN_TYPEHASH = keccak256(
        "Domain(address account,uint256 network_id,address payment_token)"
    );
    
    bytes32 public constant SCHEDULE_TYPEHASH = keccak256(
        "Schedule(uint8 intervalUnit,uint256 interval_count,uint256 iterations,uint256 start_date,uint256 end_date)"
    );

    bytes32 public constant WITNESS_TYPEHASH = keccak256(
        "PaymentIntent(bytes32 paymentId,uint8 payment_type,OperatorData operator_data,uint256 amount,Domain source,Domain destination,uint256 processing_date,uint256 expires_at)OperatorData(bytes32 operatorId,address operator,address treasury_account,uint256 fee)Domain(address account,uint256 network_id,address payment_token)"
    );

    struct PaymentIntent {
        bytes32 paymentId;
        PaymentType payment_type;
        OperatorData operator_data;
        uint256 amount;
        Domain source;
        Domain destination;
        uint256 processing_date;
        uint256 expires_at;
        Schedule schedule;
        bytes p2_sig;
        uint256 nonce;
        string payment_reference;
        bytes metadata;
    }

    struct PaymentIntentRecord {
        PaymentIntent intent;
        PaymentExecutionStatus status;
        GatewayConfig gatewayConfig;
    }

    struct ExecutionContext {
        address PERMIT2;
        GatewayConfig gatewayConfig;
    }

    struct OperatorData {
        bytes32 operatorId;
        address operator;
        address[] authorized_signers;
        address treasury_account;
        uint256 fee;
        string operatorURI;
    }

    struct GatewayConfig {
        address relayer_address;
        uint256 fee;
        address treasury;
    }

    struct Domain {
        address account;
        uint256 network_id;
        address payment_token;
    }

    struct Schedule {
        IntervalUnit intervalUnit;
        uint256 interval_count;
        uint256 iterations;
        uint256 start_date;
        uint256 end_date;
    }

    struct PaymentExecutionStatus {
        PaymentStatus code;
        uint256 executed_count;
        bool last_execution_success;
        uint256 last_execution_date;
        uint256 next_payment_date;
    }

    struct TransferAmounts {
        uint256 payee_amount;
        uint256 operator_fee;
        uint256 gateway_fee;
    }

    struct PermitParams {
        ISignatureTransfer.TokenPermissions[] permitted;
        uint256 nonce;
        uint256 deadline;
        ISignatureTransfer.SignatureTransferDetails[] transferDetails;
        bytes32 witness;
        string witnessTypeString;
        uint256[3] amounts;
    }

    event PAYMENT_STATUS_UPDATE(
        bytes32 indexed paymentID,
        bytes32 indexed operatorID,
        address indexed operator,
        address sender,
        address receiver,
        uint256 amount,
        address payment_token,
        uint256 executed_date,
        uint256 next_payment_date,
        PaymentStatus status,
        string payment_reference,
        string metadata,
        string reason
    );

    event RECURRING_PAYMENT_AUTHORIZATION(
        bytes32 indexed paymentID,
        bytes32 indexed operatorID,
        address indexed operator,
        PaymentType payment_type,
        address payer,
        address signer,
        uint256 amount,
        address payment_token,
        uint256 expiration,
        string status
    );

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

    event PERMIT2_ERROR(
        bytes32 indexed paymentId,
        string errorType,
        string reason
    );

    error InsufficientFunds(string);
    error PaymentExecutionFailed(string);
    error InvalidPaymentIntentSignature(string);
    error PaymentIntentValidationFailed(string);
    error PaymentCancellationFailed(bytes32, address);

}