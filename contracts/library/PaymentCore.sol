// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../abstract/PaymentCoreBase.sol";
import {IAllowanceTransfer, ISignatureTransfer} from "../helpers/Permit2/src/interfaces/IPermit2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title PaymentCore
/// @notice Core payment processing logic library responsible for validating, processing and executing the payment transfers.
library PaymentCore{

    string private constant LIB_VERSION = "1.0.0";

    uint256 private constant MAX_EXPIRATION = type(uint48).max;
    uint256 private constant TOLERANCE = 10 hours;
    uint256 private constant SIG_DEADLINE_DURATION = 1 days;
    uint256 private constant BASIS_POINTS = 10000;

    uint256 public constant MAX_OPERATOR_FEE = 1000; // 10% in basis points
    uint256 public constant MAX_GATEWAY_FEE = 50; // 0.5% in basis points

    // Predefined reasons
    string public constant REASON_PAYMENT_PROCESSING = "Payment intent processing initiated";
    string public constant REASON_PAYMENT_EXECUTED = "Payment completed successfully";
    string public constant REASON_PAYMENT_FAILED = "Payment processing failed, flagged for retry in the next cycle.";
    string public constant REASON_PAYMENT_SCHEDULED = "Payment scheduled for next execution";
    string public constant REASON_PAYMENT_CANCELLED = "Recurring payment canceled by payer or operator";
    string public constant REASON_PAYMENT_PERIOD_COMPLETED = "Recurring payment period completed";
    // string public constant REASON_PAYMENT_MISSED = "Missed payment, flagged for retry in the next cycle.";
    // string public constant REASON_PAYMENT_CURRENT = "Current scheduled payment executed";

    /**
     * @dev Processes a payment intent.
     * @param intent The payment intent to process.
     * @param context The instance context (payment gateway configuration, permit2)
     * @return success indicating if the payment was successful
     * @return status The execution status of the payment.
     */
    function processPaymentIntent(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool success, PaymentCoreBase.PaymentExecutionStatus memory status) {
        if (intent.payment_type == PaymentCoreBase.PaymentType.ONE_TIME) {
            return _executeOneTimePayment(intent, context);
        } else if (intent.payment_type == PaymentCoreBase.PaymentType.RECURRING){
            return _executeRecurringPayment(intent, context);
        } else {
            revert("Invalid payment type");
        }
    }

    /**
     * @dev Executes a one-time payment.
     * @param intent The payment intent.
     * @param context The instance context (payment gateway configuration + permit2)
     * @return bool indicating if the payment was successful.
     * @return paymentExecutionStatus indicating the payment status details.
     */
    function _executeOneTimePayment(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool, PaymentCoreBase.PaymentExecutionStatus memory) {
        PaymentCoreBase.TransferAmounts memory amounts = calculateTransferAmounts(intent, context.gatewayConfig);
        bool execution_success = _executeSignatureTransfer(intent, amounts, context);
        
        PaymentCoreBase.PaymentExecutionStatus memory status = PaymentCoreBase.PaymentExecutionStatus({
            code: execution_success ? PaymentCoreBase.PaymentStatus.COMPLETED : PaymentCoreBase.PaymentStatus.FAILED,
            executed_count: execution_success ? 1 : 0,
            last_execution_success: execution_success,
            last_execution_date: execution_success ? block.timestamp : 0,
            next_payment_date: 0
        });

        logPaymentStatus(
            intent,
            status,
            execution_success ? REASON_PAYMENT_EXECUTED : REASON_PAYMENT_FAILED
        );

        // For one-time payments, we don't store the payment intent
        // We only return the execution status

        return (execution_success, status);
    }

    /**
     * @dev Validates the payment schedule.
     * @param schedule The payment schedule to validate.
     */
    function validateSchedule(PaymentCoreBase.Schedule memory schedule) internal view {
        require(schedule.interval_count > 0, "Interval count must be greater than zero");
        require(schedule.start_date > block.timestamp, "Start date must be in the future");
        require(schedule.iterations == 0 || schedule.end_date == 0, "Cannot set both iterations and end_date");
        if (schedule.end_date > 0) {
            require(schedule.end_date > schedule.start_date, "End date must be after start date");
        }
    }

    /**
     * @dev Executes a recurring payment.
     * @param intent The payment intent.
     * @param context The instance context (payment gateway configuration, permit2)
     * @return bool indicating if the payment was successful.
     */
    function _executeRecurringPayment(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool, PaymentCoreBase.PaymentExecutionStatus memory) {
        
        // validate payment intent schedule config 
        validateSchedule(intent.schedule); 

        bool permit_success = setupPermitAllowance(intent, context);
        require(permit_success, "Recurring Permit Allowance Setup Failed");

        // Step 3: Calculate next payment date or set to start date if failed       
        bool execution_success = false;
        uint256 next_payment_date = intent.schedule.start_date;
        PaymentCoreBase.PaymentStatus status_code;
        string memory reason;

        if (isWithinTimeTolerance(intent.schedule.start_date)) {
            execution_success = _executePayment(intent, context);
            if (execution_success) {
                status_code = PaymentCoreBase.PaymentStatus.COMPLETED;
                next_payment_date = scheduleNextPaymentDate(intent.schedule, intent.schedule.start_date);
                reason = REASON_PAYMENT_EXECUTED;
            } else {
                status_code = PaymentCoreBase.PaymentStatus.FAILED;
                reason = REASON_PAYMENT_FAILED;
            }
        } else {
            status_code = PaymentCoreBase.PaymentStatus.SCHEDULED;
            reason = REASON_PAYMENT_SCHEDULED;
        }
        // Step 4: Set recurring payment execution status
        PaymentCoreBase.PaymentExecutionStatus memory status = PaymentCoreBase.PaymentExecutionStatus({
            code: status_code,
            executed_count: execution_success ? 1 : 0,
            last_execution_success: execution_success,
            last_execution_date: execution_success ? block.timestamp : 0,
            next_payment_date: next_payment_date
        });

        logPaymentStatus(intent, status, reason);

        return (execution_success, status);
    }

    function _executeSignatureTransfer(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.TransferAmounts memory amounts,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool) {

        (ISignatureTransfer.PermitBatchTransferFrom memory permit, 
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails) = _prepareP2TransferPayload(intent, amounts, context.gatewayConfig);

        bytes32 witness = _constructWitness(intent);
        string memory witnessTypeString = _getWitnessTypeString();

        try ISignatureTransfer(context.PERMIT2).permitWitnessTransferFrom(
            permit,
            transferDetails,
            intent.source.account,
            witness,
            witnessTypeString,
            intent.p2_sig
        ) {
            return true;
        } catch {
            return false;
        }
    }

    function _prepareP2TransferPayload(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.TransferAmounts memory amounts,
        PaymentCoreBase.GatewayConfig memory gatewayConfig
    ) private pure returns (
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        ISignatureTransfer.SignatureTransferDetails[] memory transferDetails
    ) {

        // Define transfer data
        (address[] memory recipients, uint256[] memory transferAmounts) = getTransferData(intent, amounts, gatewayConfig);

        permit = ISignatureTransfer.PermitBatchTransferFrom({
            permitted: new ISignatureTransfer.TokenPermissions[](3),
            nonce: intent.nonce,
            deadline: intent.expires_at
        });

        transferDetails = new ISignatureTransfer.SignatureTransferDetails[](3);
        
        // Populate arrays dynamically
        for (uint256 i = 0; i < recipients.length; i++) {
            permit.permitted[i] = ISignatureTransfer.TokenPermissions({
                token: intent.source.payment_token,
                amount: transferAmounts[i]
            });
            transferDetails[i] = ISignatureTransfer.SignatureTransferDetails({
                to: recipients[i],
                requestedAmount: transferAmounts[i]
            });
        }
    }

    function _getWitnessTypeString() private pure returns (string memory) {
        return "PaymentIntent witness)PaymentIntent(bytes32 paymentId,uint8 payment_type,OperatorData operator_data,uint256 amount,Domain source,Domain destination,uint256 processing_date,uint256 expires_at,uint256 nonce,string payment_reference)OperatorData(bytes32 operatorId,address operator,address treasury_account,uint256 fee,string operatorURI)Domain(address account,uint256 network_id,address payment_token)TokenPermissions(address token,uint256 amount)";
        // string memory witnessTypeString = "PaymentIntent witness)PaymentIntent(bytes32 paymentId,uint8 payment_type,OperatorData operator_data,uint256 amount,Domain source,Domain destination,uint256 processing_date,uint256 expires_at,Schedule schedule,uint256 nonce,string payment_reference,bytes metadata)TokenPermissions(address token,uint256 amount)OperatorData(bytes32 operatorId,address operator,address[] authorized_signers,address treasury_account,uint256 fee,string operatorURI)Domain(address account,uint256 network_id,address payment_token)Schedule(uint8 intervalUnit,uint256 interval_count,uint256 iterations,uint256 start_date,uint256 end_date)";
    }

    /**
     * @dev Executes a payment.
     * @param intent The payment intent.
     * @param context The execution context.
     * @return bool indicating if the payment was successful.
     */    
    function _executePayment(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool) {
        if (IERC20(intent.source.payment_token).balanceOf(intent.source.account) < intent.amount) {
            revert PaymentCoreBase.InsufficientFunds("Not enough funds to transfer from sender wallet");
        }

        PaymentCoreBase.TransferAmounts memory amounts = calculateTransferAmounts(intent, context.gatewayConfig);
        return executeBatchedTransfer(intent, amounts, context);
    }

    function getTransferData(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.TransferAmounts memory amounts,
        PaymentCoreBase.GatewayConfig memory pwg
    ) internal pure returns (address[] memory recipients, uint256[] memory transferAmounts) {
        recipients = new address[](3);
        transferAmounts = new uint256[](3);

        recipients[0] = intent.destination.account;
        recipients[1] = intent.operator_data.treasury_account;
        recipients[2] = pwg.treasury;

        transferAmounts[0] = amounts.payee_amount;
        transferAmounts[1] = amounts.operator_fee;
        transferAmounts[2] = amounts.gateway_fee;

        return (recipients, transferAmounts);
    }

    /**
     * @dev Executes a batched transfer using Permit2.
     * @param intent The payment intent.
     * @param amounts The transfer amounts.
     * @param context The instance context (payment gateway configuration, permit2)
     * @return bool indicating if the transfer was successful.
     */
    function executeBatchedTransfer(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.TransferAmounts memory amounts,
        PaymentCoreBase.ExecutionContext memory context
    ) internal returns (bool) {
        IAllowanceTransfer.AllowanceTransferDetails[] memory transferDetails = new IAllowanceTransfer.AllowanceTransferDetails[](3);

        transferDetails[0] = IAllowanceTransfer.AllowanceTransferDetails({
            from: intent.source.account,
            to: intent.destination.account,
            amount: uint160(amounts.payee_amount),
            token: intent.source.payment_token
        });

        transferDetails[1] = IAllowanceTransfer.AllowanceTransferDetails({
            from: intent.source.account,
            to: intent.operator_data.treasury_account,
            amount: uint160(amounts.operator_fee),
            token: intent.source.payment_token
        });


        if (amounts.gateway_fee > 0) {
            transferDetails[2] = IAllowanceTransfer.AllowanceTransferDetails({
                from: intent.source.account,
                to: context.gatewayConfig.treasury,
                amount: uint160(amounts.gateway_fee),
                token: intent.source.payment_token
            });
        }

        try IAllowanceTransfer(context.PERMIT2).transferFrom(transferDetails) {
            return true;
        } catch {
            return false;
        }
    }
   
    /**
     * @dev Sets up the permit allowance for a payment.
     * @param intent The payment intent.
     * @param context The instance context (payment gateway configuration and permit2)
     * @return bool indicating if the setup was successful.
     */
    function setupPermitAllowance(
        PaymentCoreBase.PaymentIntent memory intent, 
        PaymentCoreBase.ExecutionContext memory context
        ) internal returns (bool) {
        (uint160 amount, uint48 expiration) = constructPermitParams(intent);

        IAllowanceTransfer.PermitSingle memory permitSingle = IAllowanceTransfer.PermitSingle({
            details: IAllowanceTransfer.PermitDetails({
                token: intent.source.payment_token,
                amount: amount,
                expiration: expiration,
                nonce: uint48(intent.nonce)
            }),
            spender: address(this),
            sigDeadline: block.timestamp + SIG_DEADLINE_DURATION
        });

        try IAllowanceTransfer(context.PERMIT2).permit(intent.source.account, permitSingle, intent.p2_sig) {
            emit PaymentCoreBase.RECURRING_PAYMENT_AUTHORIZATION(
                intent.paymentId,
                intent.operator_data.operatorId,
                intent.operator_data.operator,
                intent.payment_type,
                intent.source.account,
                intent.source.account,
                amount,
                intent.source.payment_token,
                expiration,
                "CONFIRMED"
            );
            return true;
        } catch {
            emit PaymentCoreBase.RECURRING_PAYMENT_AUTHORIZATION(
                intent.paymentId,
                intent.operator_data.operatorId,
                intent.operator_data.operator,
                intent.payment_type,
                intent.source.account,
                intent.source.account,
                amount,
                intent.source.payment_token,
                expiration,
                "REJECTED"
            );
            return false;
        }
    }
    
    /**
     * @dev Constructs permit parameters for a payment intent.
     * @param intent The payment intent.
     * @return totalAmount The total amount for the permit.
     * @return expiration The expiration timestamp for the permit.
     */
    function constructPermitParams(PaymentCoreBase.PaymentIntent memory intent) 
        internal pure returns (uint160 totalAmount, uint48 expiration) {
        uint256 numberOfPayments;
        PaymentCoreBase.Schedule memory schedule = intent.schedule;

        uint256 intervalInSeconds = getIntervalInSeconds(schedule.intervalUnit, schedule.interval_count);

        if (schedule.end_date > 0) {
            numberOfPayments = (schedule.end_date - schedule.start_date) / intervalInSeconds + 1;
            expiration = uint48(schedule.end_date);
        } else if (schedule.iterations > 0) {
            numberOfPayments = schedule.iterations;
            expiration = uint48(schedule.start_date + intervalInSeconds * schedule.iterations);
        } else {
            // Open-ended recurring payment
            return (type(uint160).max, uint48(MAX_EXPIRATION));
        }

        expiration = expiration > MAX_EXPIRATION ? uint48(MAX_EXPIRATION) : expiration;
        
        totalAmount = uint160(intent.amount * numberOfPayments);
    }
    /**
     * @dev Calculates the transfer amounts for a payment.
     * @param intent The payment intent.
     * @param pwg The payment gateway configuration.
     * @return TransferAmounts The calculated transfer amounts.
     */
    function calculateTransferAmounts(
        PaymentCoreBase.PaymentIntent memory intent, 
        PaymentCoreBase.GatewayConfig memory pwg
    ) internal pure returns (PaymentCoreBase.TransferAmounts memory) {
        uint256 operatorFee = (intent.amount * intent.operator_data.fee) / BASIS_POINTS;
        uint256 gatewayFee = (intent.amount * pwg.fee) / BASIS_POINTS;
        
        require(operatorFee + gatewayFee < intent.amount, "Operator or Gateway fees exceed total gross amount");
        
        uint256 payeeAmount = intent.amount - operatorFee - gatewayFee;

        return PaymentCoreBase.TransferAmounts({
            payee_amount: payeeAmount,
            operator_fee: operatorFee,
            gateway_fee: gatewayFee
        });
    }

    /**
     * @dev Checks if a date is within the time tolerance.
     * @param targetDate The target date to check.
     * @return bool indicating if the current time is within tolerance of the target date.
     */
    function isWithinTimeTolerance(uint256 targetDate) internal view returns (bool) {
        return (block.timestamp >= targetDate) && (block.timestamp <= (targetDate + TOLERANCE));
    }

    /**
     * @dev Calculates the next payment date for a recurring payment.
     * @param schedule The payment schedule.
     * @param lastPaymentDate The date of the last payment.
     * @return uint256 The next payment date.
     */
    function scheduleNextPaymentDate(PaymentCoreBase.Schedule memory schedule, uint256 lastPaymentDate) internal pure returns (uint256) {
        uint256 intervalInSeconds = getIntervalInSeconds(schedule.intervalUnit, schedule.interval_count);
        uint256 nextDate = lastPaymentDate + intervalInSeconds;

        if (schedule.end_date > 0) {
            return nextDate > schedule.end_date ? 0 : nextDate;
        } else if (schedule.iterations > 0) {
            uint256 totalDuration = intervalInSeconds * schedule.iterations;
            return nextDate > (schedule.start_date + totalDuration) ? 0 : nextDate;
        }

        return nextDate; // For open-ended schedules
    }

    /**
     * @dev Checks if the payment period has ended.
     * @param schedule The payment schedule.
     * @param executedCount The number of executed payments.
     * @return bool indicating if the payment period has ended.
     */
    function isPaymentPeriodEnded(PaymentCoreBase.Schedule memory schedule, uint256 executedCount) internal view returns (bool) {
        if (schedule.end_date > 0) {
            return block.timestamp > schedule.end_date;
        } else if (schedule.iterations > 0) {
            return executedCount >= schedule.iterations;
        }
        return false;
    }

     /**
     * @dev Calculates the interval in seconds based on the interval unit and count.
     * @param intervalUnit The interval unit (DAY, WEEK, MONTH, YEAR).
     * @param intervalCount The number of intervals.
     * @return uint256 The interval in seconds.
     */
    function getIntervalInSeconds(PaymentCoreBase.IntervalUnit intervalUnit, uint256 intervalCount) internal pure returns (uint256) {
        if (intervalUnit == PaymentCoreBase.IntervalUnit.DAY) return intervalCount * 1 days;
        if (intervalUnit == PaymentCoreBase.IntervalUnit.WEEK) return intervalCount * 1 weeks;
        if (intervalUnit == PaymentCoreBase.IntervalUnit.MONTH) return intervalCount * 30 days; // Approximation
        if (intervalUnit == PaymentCoreBase.IntervalUnit.YEAR) return intervalCount * 365 days; // Approximation
        revert("Invalid interval unit");
    }

    function _constructWitness(PaymentCoreBase.PaymentIntent memory intent) 
        internal pure returns (bytes32) {
        bytes32 PAYMENT_INTENT_TYPEHASH = keccak256("PaymentIntent(bytes32 paymentId,uint8 payment_type,OperatorData operator_data,uint256 amount,Domain source,Domain destination,uint256 processing_date,uint256 expires_at,uint256 nonce,string payment_reference)OperatorData(bytes32 operatorId,address operator,address treasury_account,uint256 fee,string operatorURI)Domain(address account,uint256 network_id,address payment_token)");
        
        return keccak256(abi.encode(
            PAYMENT_INTENT_TYPEHASH,
            intent.paymentId,
            intent.payment_type,
            keccak256(abi.encode(
                intent.operator_data.operatorId,
                intent.operator_data.operator,
                intent.operator_data.treasury_account,
                intent.operator_data.fee,
                keccak256(bytes(intent.operator_data.operatorURI))
            )),
            intent.amount,
            keccak256(abi.encode(
                intent.source.account,
                intent.source.network_id,
                intent.source.payment_token
            )),
            keccak256(abi.encode(
                intent.destination.account,
                intent.destination.network_id,
                intent.destination.payment_token
            )),
            intent.processing_date,
            intent.expires_at,
            intent.nonce,
            keccak256(bytes(intent.payment_reference))
        ));
    }

    /// @notice Updates the payment status after a successful execution
    /// @param status The payment intent record execution status to update
    /// @param schedule The payment schedule
    function updatePaymentStatus(
        PaymentCoreBase.PaymentExecutionStatus storage status,
        PaymentCoreBase.Schedule memory schedule
    ) internal {
        status.executed_count++;
        status.last_execution_success = true;
        status.last_execution_date = block.timestamp;

        uint256 _next_payment_date = PaymentCore.scheduleNextPaymentDate(schedule, status.last_execution_date);
        
        if (_next_payment_date == 0) {
            status.code = PaymentCoreBase.PaymentStatus.COMPLETED;
            status.next_payment_date = 0;
        } else {
            status.code = PaymentCoreBase.PaymentStatus.SCHEDULED;
            status.next_payment_date = _next_payment_date;
        }
    }

    /**
     * @dev Logs the payment status.
     * @param intent The payment intent.
     * @param status The payment execution status.
     * @param reason The reason for the status update.
     */
    function logPaymentStatus(
        PaymentCoreBase.PaymentIntent memory intent,
        PaymentCoreBase.PaymentExecutionStatus memory status,
        string memory reason
    ) internal {
        emit PaymentCoreBase.PAYMENT_STATUS_UPDATE(
            intent.paymentId,
            intent.operator_data.operatorId,
            intent.operator_data.operator,
            intent.source.account,
            intent.destination.account,
            intent.amount,
            intent.source.payment_token,
            status.last_execution_date,
            status.next_payment_date,
            status.code,
            intent.payment_reference,
            string(intent.metadata),
            reason
        );
    }

    function version() public pure returns (string memory) {
        return LIB_VERSION;
    }
}