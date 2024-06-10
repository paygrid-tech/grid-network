// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IGridOperatorNode.sol";

/// @title GridOperatorNode
/// @notice Manages operator state and delegates calls to GridPaymentCoreV1
contract GridOperatorNode is Ownable, IGridOperatorNode {
    mapping(address => OperatorConfig) private operator_data;
    address public gridRouterGateway;

    event OperatorNodeUpdated(address indexed operator);

    /// @notice Constructor to set the GridRouterGateway address
    constructor(address _gridRouterGateway) {
        gridRouterGateway = _gridRouterGateway;
    }

    /// @notice Initializes the operator node with the provided configuration
    /// @param operatorName The name of the operator
    /// @param operatorUri The URI of the operator
    /// @param treasuryAccount The treasury account of the operator
    /// @param supportedTokens The supported tokens of the operator
    /// @param fee The fee charged by the operator
    function initialize(
        string memory operatorName,
        string memory operatorUri,
        address treasuryAccount,
        string[] memory supportedTokens,
        uint256 fee
    ) external override {
        require(bytes(operator_data[msg.sender].operatorId).length == 0, "Already initialized");

        OperatorConfig storage config = operator_data[msg.sender];
        config.operatorId = generateOperatorId();
        config.operatorName = operatorName;
        config.operatorUri = operatorUri;
        config.treasuryAccount = treasuryAccount;
        config.supportedTokens = supportedTokens;
        config.fee = fee;

        config.authorizedSigners[msg.sender] = true;
        config.authorizedSigners[address(this)] = true;
        config.authorizedSignersArray.push(msg.sender);
        config.authorizedSignersArray.push(address(this));
    }

    /// @notice Checks if the provided signer is authorized for the given operator
    function isAuthorizedSigner(address operator, address signer) public view override returns (bool) {
        return operator_data[operator].authorizedSigners[signer];
    }

    /// @notice Updates the operator configuration
    function updateOperatorConfig(address operator, OperatorConfig calldata config) external override onlyAuthorizedSigner(operator) {
        operator_data[operator] = config;
        emit OperatorNodeUpdated(operator);
    }

    /// @notice Returns the configuration of the given operator
    function getOperatorNodeConfig(address operator) external view override onlyAuthorizedSigner(operator) returns (OperatorConfig memory) {
        return operator_data[operator];
    }

    /// @notice Delegates calls to GridPaymentCoreV1
    function delegateToPaymentCore(bytes memory data) public {
        address implementation = _implementation();
        (bool success, ) = implementation.delegatecall(data);
        require(success, "Delegate call failed");
    }

    function _delegate(address implementation) internal {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())

            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    fallback() external payable {
        _delegate(_implementation());
    }

    receive() external payable {
        _delegate(_implementation());
    }

    function _implementation() internal view returns (address) {
        (bool success, bytes memory data) = gridRouterGateway.staticcall(abi.encodeWithSignature("getImplementation()"));
        require(success, "Failed to get implementation");
        return abi.decode(data, (address));
    }

    modifier onlyAuthorizedSigner(address operator) {
        require(isAuthorizedSigner(operator, msg.sender), "Not an authorized signer");
        _;
    }

    function generateOperatorId() private view returns (string memory) {
        return string(abi.encodePacked("GOPERATOR-", address(this)));
    }
}

