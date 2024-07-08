// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/SignatureChecker.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "../interfaces/IGridOperatorNode.sol";
import "../interfaces/IGridProtocolManager.sol";
import "../library/PaymentCoreV1.sol";
import "../interfaces/IGridOperatorRegistry.sol";

/// @title GridOperatorNode
/// @notice Manages operator state and processes payments using PaymentCoreV1 lib
contract GridOperatorNode is IGridOperatorNode, EIP712, Context, ReentrancyGuard {
    using ECDSA for bytes32;
    using SignatureChecker for address;

    string private constant SIGNING_DOMAIN = "GRID_OPERATOR_NODE";
    string private constant SIGNATURE_VERSION = "v1.0";

    mapping(address => OperatorConfig) private operator_data;
    mapping(address => mapping(bytes32 => PaymentIntent)) private payment_transaction_intents;
    mapping(address => bytes32[]) private operatorPaymentIds;
    address public protocolManager;
    address private initializer;

    constructor(address _protocolManager, address _initializer) 
    EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION){
        protocolManager = _protocolManager;
        initializer = _initializer;
    }

    /// @notice Initializes the operator node with the provided configuration
    /// Only registered operator proxies are allowed to call the initialize function.
    /// @param config The configuration for the new operator node
    // / @param initcaller The address of the authorized initializer caller
    /// @param ogcaller The address of the original msg.sender
    function initialize(
        address operator,
        OperatorConfigDTO calldata config,
        address ogcaller
    ) external override onlyInitializer(operator){
        require(
            !operator_data[operator].initialized, 
            "Operator Node already initialized"
        );
        _setOperatorConfig(operator, config, ogcaller);
        emit OperatorNodeConfigInitialized(operator);
    }

    /// @notice Internal function to set the operator configuration
    /// @param operator The address of the operator
    /// @param config The configuration for the new operator node
    /// @param ogcaller The address of the original msg.sender
    // / @param operatorName The name of the operator
    // / @param operatorUri The URI of the operator
    // / @param treasuryAccount The treasury account of the operator
    // / @param supportedTokens The supported tokens of the operator
    // / @param fee The fee charged by the operator
    function _setOperatorConfig(
        address operator,
        OperatorConfigDTO calldata config,
        address ogcaller
    ) internal {
        OperatorConfig storage _config = operator_data[operator];
        _config.operatorId = generateOperatorId(operator);
        _config.operatorName = config.operatorName;
        _config.operatorUri = config.operatorUri;
        _config.treasuryAccount = config.treasuryAccount;
        _config.supportedTokens = config.supportedTokens;
        _config.fee = config.fee;

        // Operator address as authorized signer
        _config.authorizedSigners[operator] = true; 
        // The original caller who initiated the operator deployment as authorized signer
        _config.authorizedSigners[ogcaller] = true; 
        _config.authorizedSignersList.push(operator);
        _config.authorizedSignersList.push(ogcaller);

        _config.initialized = true;
    }

    /// @notice Checks if the provided signer is authorized for the given operator
    /// @param operator The address of the operator
    /// @param signer The address of the signer
    /// @return bool indicating if the signer is authorized
    function isAuthorizedSigner(address operator, address signer) public view override returns (bool) {
        return operator_data[operator].authorizedSigners[signer];
    }

    /// @notice Updates the operator configuration
    /// @param operator The address of the operator
    /// @param config The configuration for the new operator node
    function updateOperatorConfig(
        address operator,
        OperatorConfigDTO calldata config
    ) external override onlyAuthorizedSigner(operator) {
        OperatorConfig storage _config = operator_data[operator];
        _config.operatorName = config.operatorName;
        _config.operatorUri = config.operatorUri;
        _config.treasuryAccount = config.treasuryAccount;
        _config.supportedTokens = config.supportedTokens;
        _config.fee = config.fee;
        
        emit OperatorNodeUpdated(operator);
    }

    /// @notice Returns the configuration of the given operator
    /// @param operator The address of the operator
    /// @return OperatorConfig The configuration of the operator
    /// @notice Returns the configuration of the given operator
    /// @param operator The address of the operator
    /// @return (string memory, string memory, address, address[], uint256, bool) The configuration of the operator
    function getOperatorNodeConfig(address operator) 
        external view 
        override 
        onlyAuthorizedSigner(operator) 
        returns (
            string memory, 
            string memory, 
            address, 
            address[] memory, 
            uint256, 
            bool
        ) 
    {
        OperatorConfig storage config = operator_data[operator];
        return (
            config.operatorName,
            config.operatorUri,
            config.treasuryAccount,
            config.supportedTokens,
            config.fee,
            config.initialized
        );
    }

    /// @notice Initiate a new payment transaction intent
    /// @param intent The payment transaction intent
    /// @param signature The EIP-712 signature
    function createPaymentTransactionIntent(
        PaymentIntent calldata intent,
        bytes calldata signature
    ) external onlyAuthorizedSigner(intent.operator) nonReentrant{

        if (!_verifyPaymentIntentSignature(intent, signature)) {
            emit InvalidPaymentIntentSignature(
                intent.operator,
                intent.source.account,
                intent.destination.account,
                "Invalid payment intent signature"
            );
            revert("Invalid payment intent signature");
        }

        (bool valid, string memory reason) = _validatePaymentIntent(intent);
        if (!valid) {
            emit PaymentIntentValidationFailed(
                intent.operator,
                intent.source.account,
                intent.destination.account,
                reason
            );
            revert(reason);
        }
        
        bytes32 paymentId = generatePaymentId(intent.operator);

        PaymentIntent memory _paymentInt = intent;
        _paymentInt.paymentId = paymentId;
        _paymentInt.processing_date = block.timestamp;
        _paymentInt.status = PaymentStatus.Processing;

        payment_transaction_intents[_paymentInt.operator][_paymentInt.paymentId] = _paymentInt;

        operatorPaymentIds[_paymentInt.operator].push(_paymentInt.paymentId);


        emit PaymentTransactionInitiated(
            _paymentInt.paymentId,
            _paymentInt.operator,
            _paymentInt.source.account,
            _paymentInt.destination.account,
            _paymentInt.amount,
            _paymentInt.source.payment_token,
            "Processing"
        );

        bool success = PaymentCoreV1.processPayment(
            _paymentInt,
            protocolManager,
            operator_data[_paymentInt.operator].fee,
            operator_data[_paymentInt.operator].treasuryAccount
        );

        if (success) {
            payment_transaction_intents[_paymentInt.operator][_paymentInt.paymentId].status = PaymentStatus.Completed;
            emit PaymentTransactionCompleted(
                _paymentInt.paymentId,
                _paymentInt.operator,
                _paymentInt.source.account,
                _paymentInt.destination.account,
                _paymentInt.amount,
                _paymentInt.source.payment_token,
                operator_data[_paymentInt.operator].fee,
                IGridProtocolManager(protocolManager).getProtocolFee()
            );
        } else {
            payment_transaction_intents[_paymentInt.operator][_paymentInt.paymentId].status = PaymentStatus.Failed;
            emit PaymentTransactionFailed(
                _paymentInt.paymentId,
                _paymentInt.operator,
                _paymentInt.source.account,
                _paymentInt.destination.account,
                "Payment processing failed"
            );
        }
    }

    /// @notice Verifies the EIP-712 signature of the payment intent
    /// @param intent The payment transaction intent
    /// @param signature The EIP-712 signature
    /// @return bool indicating if the signature is valid
    function _verifyPaymentIntentSignature(
        PaymentIntent calldata intent,
        bytes calldata signature
    ) internal view returns (bool) {
        bytes32 digest = _hashTypedDataV4(
            keccak256(abi.encode(
                keccak256("PaymentIntent(address operator,uint256 amount,TransactionEndpoint source,TransactionEndpoint destination,uint256 processing_date,uint256 expires_at)"),
                intent.operator,
                intent.amount,
                keccak256(abi.encode(
                    keccak256("TransactionEndpoint(address account,uint256 network_id,address payment_token)"),
                    intent.source.account,
                    intent.source.network_id,
                    intent.source.payment_token
                )),
                keccak256(abi.encode(
                    keccak256("TransactionEndpoint(address account,uint256 network_id,address payment_token)"),
                    intent.destination.account,
                    intent.destination.network_id,
                    intent.destination.payment_token
                )),
                intent.processing_date,
                intent.expires_at
            ))
        );

        (address signer, ECDSA.RecoverError error, ) = ECDSA.tryRecover(digest, signature);
        if (error != ECDSA.RecoverError.NoError) {
            return false;
        }

        return isAuthorizedSigner(intent.operator, signer);
    }

    /// @notice Validates the payment transaction intent
    /// @param intent The payment transaction intent
    /// @return bool indicating if the intent is valid and reason if not
    function _validatePaymentIntent(PaymentIntent calldata intent) internal view returns (bool, string memory) {
        if (intent.amount == 0) {
            return (false, "Amount cannot be zero");
        }
        if (intent.source.account == address(0) || intent.destination.account == address(0)) {
            return (false, "Source and destination accounts cannot be zero address");
        }
        if (intent.source.account == intent.destination.account) {
            return (false, "Source and destination accounts cannot be the same");
        }
        if (!IGridProtocolManager(protocolManager).isTokenSupported(intent.source.payment_token) ||
            !IGridProtocolManager(protocolManager).isTokenSupported(intent.destination.payment_token)) {
            return (false, "Source or destination payment token not supported");
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

    /// @notice Generates a unique payment ID
    /// @param operator The address of the operator
    /// @return bytes32 The generated payment ID
    function generatePaymentId(address operator) internal view returns (bytes32) {
        return keccak256(abi.encodePacked(operator, block.timestamp, blockhash(block.number - 1)));
    }

    /// @notice Generates a unique operator ID
    /// @param operator The address of the operator
    /// @return bytes32 The generated operator ID
    function generateOperatorId(address operator) private view returns (bytes32) {
        string memory identifier = string(abi.encodePacked(
            "GOPERATOR-",
            operator,
            "-",
            Strings.toString(block.timestamp)
        ));
        return keccak256(abi.encodePacked(identifier));
    }

    modifier onlyAuthorizedSigner(address operator) {
        require(isAuthorizedSigner(operator, _msgSender()), "Not an authorized signer");
        _;
    }

    modifier onlyInitializer(address operator) {
        require(
            _msgSender() == IGridOperatorRegistry(initializer).getOperatorNode(operator),
            "Caller is not the authorized initializer operator node"
        );
        _;
    }

    // modifier onlyInitializer(address caller) {
    //     require(caller == initializer, "Caller is not the authorized initializer address");
    //     _;
    // }

    /// @notice Retrieves a payment intent by ID
    /// @param operator The address of the operator
    /// @param paymentId The ID of the payment intent
    /// @return PaymentIntent The payment transaction intent
    function getPaymentIntentByPaymentId(address operator, bytes32 paymentId) external view returns (PaymentIntent memory) {
        return payment_transaction_intents[operator][paymentId];
    }

    /// @notice Retrieves all payment intents for a given operator
    /// @param operator The address of the operator
    /// @return PaymentIntent[] The list of payment transaction intents
    function getAllPaymentIntentsByOperator(address operator) external view onlyAuthorizedSigner(operator) returns (PaymentIntent[] memory) {
        bytes32[] storage paymentIds = operatorPaymentIds[operator];
        PaymentIntent[] memory intents = new PaymentIntent[](paymentIds.length);
        for (uint256 i = 0; i < paymentIds.length; i++) {
            intents[i] = payment_transaction_intents[operator][paymentIds[i]];
        }
        return intents;
    }

}
