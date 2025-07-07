// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";
import "../abstract/PaymentCoreBase.sol";
import "../library/PaymentCore.sol";
import "../interfaces/IGridPaymentGateway.sol";

/// @title GridPaymentGateway
/// @notice Main entry point for payment processing in the Grid Protocol
/// @dev This contract is upgradeable following the UUPS pattern
contract GridPaymentGateway is UUPSUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable, EIP712Upgradeable, PaymentCoreBase {
    using PaymentCore for *;
    using ECDSA for bytes32;

    string private constant SIGNING_DOMAIN = "GRID_PAYMENT_GATEWAY";
    string private constant SIGNATURE_VERSION = "v1.0";
    string private constant GRID_VERSION = "v1.9";

    ExecutionContext private context;
    
    mapping(address => mapping(bytes32 => PaymentIntentRecord)) private payment_intents;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the contract
    // / @param initialOwner The address that will be set as the initial owner
    /// @param _permit2 The address of the Permit2 contract
    /// @param defaultConfig The default gateway configuration
    function initialize(address _permit2, GatewayConfig memory defaultConfig) external initializer {
        __UUPSUpgradeable_init();
        __Ownable_init(_msgSender());
        __ReentrancyGuard_init();
        __EIP712_init(SIGNING_DOMAIN, SIGNATURE_VERSION);

        context = ExecutionContext({
            PERMIT2: _permit2,
            gatewayConfig: defaultConfig
        });
    }

    /// @notice Initiates a new payment intent
    /// @param intent The payment intent
    /// @param config The payment gateway configuration
    /// @param signature The EIP-712 signature
    function initiatePaymentIntent(
        PaymentIntent calldata intent,
        GatewayConfig calldata config,
        bytes calldata signature
    ) external nonReentrant {

        if (!_verifyPaymentIntentSignature(intent, signature)) {
            emit PaymentIntentSignatureInvalid(
                intent.paymentId,
                intent.operator_data.operator,
                intent.source.account,
                intent.destination.account,
                "Invalid payment intent signature"
            );
            revert InvalidPaymentIntentSignature("Invalid payment intent signature");
        }

        (bool valid, string memory reason) = _validatePaymentIntent(intent, config);
        if (!valid) {
            emit PaymentIntentValidationError(
                intent.paymentId,
                intent.operator_data.operator,
                intent.source.account,
                intent.destination.account,
                reason
            );
            revert PaymentIntentValidationFailed(reason);
        }

        GatewayConfig memory effectiveConfig = _getEffectiveConfig(config);

        PaymentExecutionStatus memory initial_status = PaymentExecutionStatus({
            code: PaymentStatus.PROCESSING,
            executed_count: 0,
            last_execution_success: false,
            last_execution_date: block.timestamp,
            next_payment_date: 0
        });

        PaymentCore.logPaymentStatus(
            intent,
            initial_status,
            PaymentCore.REASON_PAYMENT_PROCESSING
        );

        ExecutionContext memory _pi_execution_context = ExecutionContext({
            PERMIT2: context.PERMIT2,
            gatewayConfig: effectiveConfig
        });

        (bool success, PaymentExecutionStatus memory status) = PaymentCore.processPaymentIntent(intent, _pi_execution_context);

        // Store only for recurring payments after processing
        if (intent.payment_type == PaymentType.RECURRING) {
            _storePaymentIntent(intent, status, effectiveConfig);
        }

        emit PaymentIntentInitiated(intent.paymentId, intent.operator_data.operator);
        emit PaymentIntentProcessed(intent.paymentId, intent.operator_data.operator, success);
    }


    /// @dev Processes a payment by its ID and initiator (operator) address.
    /// @param paymentId The ID of the payment to process
    /// @param operator The address of the operator
    /// @notice Edge-case: Looping through missed payments could potentially hit gas limits for long-running recurring payments.

    function processPaymentById(bytes32 paymentId, address operator) external nonReentrant {
        PaymentIntentRecord storage stored_intent = payment_intents[operator][paymentId];
        require(stored_intent.intent.paymentId != bytes32(0), "Payment intent not found");
        
        PaymentExecutionStatus storage status = stored_intent.status;

        /*
        @notice > Handle missed payments
        @notice > While the next payment date is in the past and the payment period has not ended, execute the payment.
        */
        while (status.next_payment_date < block.timestamp && !PaymentCore.isPaymentPeriodEnded(stored_intent.intent.schedule, status.executed_count)) {
            executeAndUpdatePayment(stored_intent, "REASON_MISSED_PAYMENT");
        }

        /*
        @notice > Handle current payment
        @notice > If the next payment date is within the time tolerance and the payment period has not ended, execute the payment.
        */
        if (!PaymentCore.isPaymentPeriodEnded(stored_intent.intent.schedule, status.executed_count) && 
            PaymentCore.isWithinTimeTolerance(status.next_payment_date)) {
            executeAndUpdatePayment(stored_intent, "REASON_CURRENT_SCHEDULED_PAYMENT");
        }
        /*
        @notice > Handle payment period end
        @notice > If the payment period has ended, log the payment status and update the payment status.
        */
        if (PaymentCore.isPaymentPeriodEnded(stored_intent.intent.schedule, status.executed_count)) {
            PaymentCore.logPaymentStatus(
                stored_intent.intent,
                status,
                PaymentCore.REASON_PAYMENT_PERIOD_COMPLETED
            );
        }
    }

    /// @notice Executes and updates a payment
    /// @param stored_intent The stored payment intent record
    /// @param reason_type The type of payment
    function executeAndUpdatePayment(
        PaymentIntentRecord storage stored_intent,
        string memory reason_type
    ) internal {
        ExecutionContext memory executionContext = ExecutionContext({
            PERMIT2: context.PERMIT2,
            gatewayConfig: stored_intent.gatewayConfig
        });

        bool success = PaymentCore._executePayment(stored_intent.intent, executionContext);
        
        if (success) {
            PaymentCore.logPaymentStatus(
                stored_intent.intent,
                stored_intent.status,
                string(abi.encodePacked(reason_type, " | ", PaymentCore.REASON_PAYMENT_EXECUTED))
            );
            PaymentCore.updatePaymentStatus(stored_intent.status, stored_intent.intent.schedule);
        } else {
            PaymentCore.logPaymentStatus(
                stored_intent.intent,
                stored_intent.status,
                string(abi.encodePacked(reason_type, " | ", PaymentCore.REASON_PAYMENT_FAILED))
            );
            revert PaymentExecutionFailed(string(abi.encodePacked(reason_type, " | ", PaymentCore.REASON_PAYMENT_FAILED)));
        }
    }
    

    /// @notice Cancels a recurring payment
    /// @param payment_id The ID of the payment to cancel
    /// @param operator The address of the operator
    function cancelRecurringPayment(bytes32 payment_id, address operator) external {
        PaymentIntentRecord storage stored_intent = payment_intents[operator][payment_id];
        require(stored_intent.intent.paymentId != bytes32(0), "Payment intent not found");
        require(_msgSender() == stored_intent.intent.source.account || _msgSender() == stored_intent.intent.operator_data.operator, "Unauthorized");

        stored_intent.status.code = PaymentStatus.CANCELLED;

        IAllowanceTransfer.TokenSpenderPair[] memory pairs = new IAllowanceTransfer.TokenSpenderPair[](1);
        pairs[0] = IAllowanceTransfer.TokenSpenderPair({
            token: stored_intent.intent.source.payment_token,
            spender: address(this)
        });

        /*
        @notice > Lockdown the payment token to prevent further transfers.
        */
        try IAllowanceTransfer(context.PERMIT2).lockdown(pairs) {
            emit PAYMENT_STATUS_UPDATE(
                stored_intent.intent.paymentId,
                stored_intent.intent.operator_data.operatorId,
                stored_intent.intent.operator_data.operator,
                stored_intent.intent.source.account,
                stored_intent.intent.destination.account,
                stored_intent.intent.amount,
                stored_intent.intent.source.payment_token,
                block.timestamp,
                0,
                PaymentStatus.CANCELLED,
                stored_intent.intent.payment_reference,
                string(stored_intent.intent.metadata),
                PaymentCore.REASON_PAYMENT_CANCELLED
            );
            delete payment_intents[operator][payment_id];
            emit RecurringPaymentCancelled(payment_id, operator);
        } catch {
            revert PaymentCancellationFailed(payment_id, operator);
        }
    }

    /// @notice Verifies the signature of a payment intent
    /// @param intent The payment intent
    /// @param signature The signature to verify
    /// @return bool indicating if the signature is valid
    function _verifyPaymentIntentSignature(PaymentIntent calldata intent, bytes calldata signature) internal view returns (bool) {
        
        bytes32 digest = _hashTypedDataV4(_hashPaymentIntent(intent));
        /*
        @notice > Using ECDSA.tryRecover, which returns both the recovered address and an error code for verification. 
        Cannot use recover() directly with try-catch, syntax reserved for external calls and deployments, not for internal or library functions.
        */
        (address signer, ECDSA.RecoverError error,) = ECDSA.tryRecover(digest, signature);
        
        if (error != ECDSA.RecoverError.NoError) {
            return false;
        }

        (bool isAuthorizedSigner, bool isAuthorizedInitiator) = _checkAuthorization(
            signer,
            _msgSender(),
            intent.operator_data.operator,
            intent.operator_data.authorized_signers
        );

        return isAuthorizedSigner && isAuthorizedInitiator;
    }


    /// @notice _hashPaymentIntent: A helper function that computes the hash of the payment intent.
    function _hashPaymentIntent(PaymentIntent calldata intent) private pure returns (bytes32) {

        bytes32[] memory addressHashes = new bytes32[](intent.operator_data.authorized_signers.length);
        for (uint256 i = 0; i < intent.operator_data.authorized_signers.length; i++) {
            addressHashes[i] = keccak256(abi.encode(intent.operator_data.authorized_signers[i]));
        }
        
        bytes32 authorizedSignersHash = keccak256(abi.encodePacked(addressHashes));
        
        bytes32 operatorURIHash = keccak256(bytes(intent.operator_data.operatorURI));
        bytes32 paymentReferenceHash = keccak256(bytes(intent.payment_reference));
        bytes32 p2SigHash = keccak256(intent.p2_sig);

        bytes32 operatorDataHash = keccak256(abi.encode(
            OPERATOR_DATA_TYPEHASH,
            intent.operator_data.operatorId,
            intent.operator_data.operator,
            authorizedSignersHash,
            intent.operator_data.treasury_account,
            intent.operator_data.fee,
            operatorURIHash
        ));

        bytes32 sourceHash = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            intent.source.account,
            intent.source.network_id,
            intent.source.payment_token
        ));

        bytes32 destinationHash = keccak256(abi.encode(
            DOMAIN_TYPEHASH,
            intent.destination.account,
            intent.destination.network_id,
            intent.destination.payment_token
        ));

        bytes32 scheduleHash = keccak256(abi.encode(
            SCHEDULE_TYPEHASH,
            intent.schedule.intervalUnit,
            intent.schedule.interval_count,
            intent.schedule.iterations,
            intent.schedule.start_date,
            intent.schedule.end_date
        ));

        return keccak256(abi.encode(
            PAYMENT_INTENT_TYPEHASH,
            intent.paymentId,
            intent.payment_type,
            operatorDataHash,
            intent.amount,
            sourceHash,
            destinationHash,
            intent.processing_date,
            intent.expires_at,
            scheduleHash,
            intent.nonce,
            paymentReferenceHash,
            p2SigHash
        ));
    }

    /// @notice Validates a payment intent
    /// @param intent The payment intent to validate
    /// @param config The gateway configuration
    /// @return bool indicating if the intent is valid
    /// @return string with the reason if the intent is invalid
    function _validatePaymentIntent(PaymentIntent calldata intent, GatewayConfig calldata config) internal view returns (bool, string memory) {
        if (intent.payment_type == PaymentType.RECURRING && 
            payment_intents[intent.operator_data.operator][intent.paymentId].intent.paymentId != bytes32(0)) {
            return (false, "Duplicate payment ID for recurring payment intent");
        }
        if (intent.payment_type != PaymentType.ONE_TIME && intent.payment_type != PaymentType.RECURRING) {
            return (false, "Invalid payment type");
        }
        if (intent.operator_data.fee > PaymentCore.MAX_OPERATOR_FEE) {
            return (false, "Operator fee exceeds maximum allowed");
        }
        if (config.fee > PaymentCore.MAX_GATEWAY_FEE) {
            return (false, "Gateway fee exceeds maximum allowed");
        }
        if (intent.operator_data.operator == address(0) || intent.operator_data.treasury_account == address(0)) {
            return (false, "Invalid operator or treasury address");
        }
        if (intent.amount == 0) {
            return (false, "Amount cannot be zero");
        }
        if (intent.source.account == address(0) || intent.destination.account == address(0)) {
            return (false, "Source and destination accounts cannot be zero address");
        }
        if (intent.source.account == intent.destination.account) {
            return (false, "Source and destination accounts cannot be the same");
        }
        if (intent.source.network_id != block.chainid) {
            return (false, "Source network ID must match current chain ID");
        }
        if (intent.processing_date < block.timestamp) {
            return (false, "Processing date cannot be in the past");
        }
        if (intent.expires_at <= block.timestamp) {
            return (false, "Expiration date must be in the future");
        }
        return (true, "");
    }

    /// @notice Stores a payment intent record
    /// @param intent The payment intent to store
    /// @param status The payment execution status
    /// @param config The gateway configuration
    function _storePaymentIntent(
        PaymentIntent memory intent,
        PaymentExecutionStatus memory status,
        GatewayConfig memory config
    ) internal {
        payment_intents[intent.operator_data.operator][intent.paymentId] = PaymentIntentRecord({
            intent: intent,
            status: status,
            gatewayConfig: config
        });
    }

    /// @notice Checks if a signer is authorized for an operator
    /// @param signer The address of the signer
    /// @param initiator The address of the initiator
    /// @param operator The address of the operator
    /// @param authorized_signers The list of authorized signers
    /// @return isAuthorizedSigner Whether the signer is authorized
    /// @return isAuthorizedInitiator Whether the initiator is authorized
    function _checkAuthorization(
        address signer,
        address initiator,
        address operator,
        address[] memory authorized_signers
    ) internal pure returns (bool isAuthorizedSigner, bool isAuthorizedInitiator) {
        isAuthorizedSigner = (signer == operator);
        isAuthorizedInitiator = (initiator == operator);

        if (isAuthorizedSigner && isAuthorizedInitiator) return (true, true);

        for (uint i = 0; i < authorized_signers.length; i++) {
            if (!isAuthorizedSigner && authorized_signers[i] == signer) isAuthorizedSigner = true;
            if (!isAuthorizedInitiator && authorized_signers[i] == initiator) isAuthorizedInitiator = true;
            
            if (isAuthorizedSigner && isAuthorizedInitiator) break;
        }
    }

    /// @notice Gets the effective gateway configuration
    /// @param config The proposed gateway configuration
    /// @return GatewayConfig The effective gateway configuration
    function _getEffectiveConfig(GatewayConfig memory config) internal view returns (GatewayConfig memory) {
        return GatewayConfig({
            relayer_address: config.relayer_address != address(0) ? config.relayer_address : context.gatewayConfig.relayer_address,
            fee: config.fee != 0 ? config.fee : context.gatewayConfig.fee,
            treasury: config.treasury != address(0) ? config.treasury : context.gatewayConfig.treasury
        });
    }

    // /// @notice Updates the default gateway configuration
    // /// @param newConfig The new default gateway configuration
    // function updateDefaultGatewayConfig(GatewayConfig memory newConfig) external onlyOwner {
    //     require(newConfig.fee <= MAX_GATEWAY_FEE, "Gateway fee exceeds maximum allowed");
    //     context.gatewayConfig = newConfig;
    // }

    
    /// @notice Authorizes an upgrade to a new implementation
    /// @param newImplementation Address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function version() external pure returns (string memory) {
        return GRID_VERSION;
    }


}
