// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface PaymentCoreBase {

    struct PaymentIntent {
        bytes32 paymentId;
        string payment_type; // one-time or recurring
        address operator;
        uint256 amount;
        TransactionEndpoint source;
        TransactionEndpoint destination;
        uint256 processing_date;
        uint256 expires_at;
        SchedulingDetails schedule;
        string metadata;
        PaymentStatus status;
        string payment_reference;
    }

    struct TransactionEndpoint {
        address account;
        uint256 network_id;
        address payment_token;
    }

    struct SchedulingDetails {
        uint256 interval; // time unit: hour, day, week, month, year
        uint256 interval_count; // recurrence 
        uint256 iterations;
        uint256 start_date;
        uint256 end_date;
    }

    enum PaymentStatus {
        Processing,
        Completed,
        Scheduled,
        Cancelled,
        Failed
    }
}
