// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IGridOperatorNode.sol";

interface IGridOperatorRegistry {
    /// @notice Event emitted when an operator node is deployed
    /// @param operator The address of the operator
    /// @param beaconProxy The address of the deployed BeaconProxy
    event OperatorNodeDeployed(address indexed operator, address indexed beaconProxy);

    /// @notice Deploys a new operator node as a BeaconProxy
    /// @param operator The address of the operator
    /// @param config The configuration for the new operator node
    /// @param signature The EIP-712 signature from the operator
    /// @return The address of the deployed BeaconProxy
    function deployOperatorNode(
        address operator,
        IGridOperatorNode.OperatorConfigDTO calldata config,
        bytes calldata signature
    ) external returns (address);

    /// @notice Gets the deployed operator node address for a given operator
    /// @param operator The address of the operator
    /// @return The address of the deployed BeaconProxy
    function getOperatorNode(address operator) external view returns (address);

    /// @notice Checks if a BeaconProxy is registered for the given operator
    /// @param operator The address of the operator
    /// @return The address of the registered BeaconProxy
    function operator_nodes(address operator) external view returns (address);
}
