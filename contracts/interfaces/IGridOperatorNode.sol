// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/PaymentCoreBase.sol";

interface IGridOperatorNode is PaymentCoreBase{

    struct OperatorConfig {
        bytes32 operatorId;
        string operatorName;
        string operatorUri;
        address treasuryAccount;
        address[] supportedTokens;
        address[] authorizedSignersList;
        mapping(address => bool) authorizedSigners; // by default operator address and proxy endpoint address
        uint256 fee;
        bool initialized;
        // address proxy_endpoint;
    }

    struct OperatorConfigDTO {
        bytes32 operatorId;
        string operatorName;
        string operatorUri;
        address treasuryAccount;
        address[] supportedTokens;
        // address[] authorizedSignersList;
        uint256 fee;
    }

    function initialize(
        // string memory operatorName,
        // string memory operatorUri,
        // address treasuryAccount,
        // address[] memory supportedTokens,
        // uint256 fee,
        // address operator,
        address operator,
        OperatorConfigDTO calldata config,
        address ogcaller
    ) external;

    function isAuthorizedSigner(address operator, address signer) external view returns (bool);

    function updateOperatorConfig(
        address operator,
        OperatorConfigDTO calldata config
    ) external;

    function getOperatorNodeConfig(address operator) 
        external view 
        returns (
            string memory, 
            string memory, 
            address, 
            address[] memory, 
            uint256, 
            bool
        );

    function createPaymentTransactionIntent(
        PaymentIntent calldata intent,
        bytes calldata signature
    ) external;

    function getPaymentIntentByPaymentId(address operator, bytes32 paymentId) external view returns (PaymentIntent memory);

    function getAllPaymentIntentsByOperator(address operator) external view returns (PaymentIntent[] memory);

    event OperatorNodeUpdated(address indexed operator);
    event OperatorNodeConfigInitialized(address indexed operator);
    event PaymentTransactionInitiated(
        bytes32 indexed paymentId,
        address indexed operator,
        address sourceAccount,
        address destinationAccount,
        uint256 amount,
        address paymentToken,
        string status
    );
    event PaymentTransactionCompleted(
        bytes32 indexed paymentId,
        address indexed operator,
        address sourceAccount,
        address destinationAccount,
        uint256 amount,
        address paymentToken,
        uint256 operatorFee,
        uint256 protocolFee
    );
    event PaymentIntentValidationFailed(
        // bytes32 indexed paymentId,
        address indexed operator,
        address indexed sourceAccount,
        address indexed destinationAccount,
        string reason
    );
    event PaymentTransactionFailed(
        bytes32 indexed paymentId,
        address indexed operator,
        address sourceAccount,
        address destinationAccount,
        string reason
    );
    event InvalidPaymentIntentSignature(
        // bytes32 indexed paymentId,
        address indexed operator,
        address indexed sourceAccount,
        address indexed destinationAccount,
        string reason
    );
}
