// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "../interfaces/IGridOperatorNode.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title GridOperatorRegistry
/// @notice Factory deploying new instances of GridOperatorNode proxies for each operator
contract GridOperatorRegistry is EIP712, Ownable {
    using ECDSA for bytes32;

    mapping(address => address) public operator_nodes;
    address public grid_operator_beacon;
    string private constant SIGNING_DOMAIN = "GRID_OPERATOR_REGISTRY";
    string private constant SIGNATURE_VERSION = "v1.0";

    event OperatorNodeDeployed(address indexed operator, address beacon_proxy);

    /// @notice Constructor to set the GridOperatorNode implementation address
    /// @param _grid_operator_beacon The address of the existing GridOperatorBeacon
    constructor(address _grid_operator_beacon) 
        EIP712(SIGNING_DOMAIN, SIGNATURE_VERSION)
        Ownable(_msgSender()) 
    {
        grid_operator_beacon = _grid_operator_beacon; // new UpgradeableBeacon(_grid_operator_node_impl,_msgSender());
    }

    /// @notice Deploys a new operator node as a BeaconProxy
    /// @param operator The address of the operator
    /// @param config The configuration for the new operator node
    /// @param signature The EIP-712 signature from the operator
    /// @return The address of the deployed BeaconProxy
    function deployOperatorNode(
        address operator,
        IGridOperatorNode.OperatorConfigDTO calldata config,
        bytes calldata signature
    ) external returns (address) {
        require(operator_nodes[operator] == address(0), "Operator node already deployed");

        // Verify operator's signature
        bytes32 digest = _hashTypedDataV4(
            keccak256(
                abi.encode(
                    keccak256("OperatorConfigDTO(string operatorName,string operatorUri,address treasuryAccount,address[] supportedTokens,uint256 fee)"),
                    keccak256(bytes(config.operatorName)),
                    keccak256(bytes(config.operatorUri)),
                    config.treasuryAccount,
                    keccak256(abi.encodePacked(config.supportedTokens)),
                    config.fee
                )
            )
        );
        address signer = digest.recover(signature);
        require(signer == operator, "Invalid operator signature");

        // Deploy the BeaconProxy
        bytes memory data = abi.encodeWithSignature(
            "initialize(address,(string,string,address,address[],uint256,address),address, address)",
            config,
            address(this),  // Passing the registry address as the authorized initializer
            _msgSender()  // Passing the original caller
        );

        BeaconProxy beaconProxy = new BeaconProxy(
            grid_operator_beacon,
            data
        );

        // Transfer ownership of the BeaconProxy to the operator
        Ownable(address(beaconProxy)).transferOwnership(operator);

        // Register the deployed BeaconProxy
        operator_nodes[operator] = address(beaconProxy);

        emit OperatorNodeDeployed(operator, address(beaconProxy));
        return operator_nodes[operator];
    }

    /// @notice Gets the deployed operator node address for a given operator
    /// @param operator The address of the operator
    /// @return The address of the deployed BeaconProxy
    function getOperatorNode(address operator) external view returns (address) {
        return operator_nodes[operator];
    }
}
