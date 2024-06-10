// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "../interfaces/IGridOperatorNode.sol";

/// @title GridOperatorRegistry
/// @notice Factory deploying new instances of GridOperatorNode proxies for each operator
contract GridOperatorRegistry{

    mapping(address => address) public operator_nodes;
    UpgradeableBeacon public grid_router_gateway;

    event OperatorNodeDeployed(address indexed operator, address beaconProxy);

    constructor(address _grid_router_gatewayImpl) {
        grid_router_gateway = new UpgradeableBeacon(_grid_router_gatewayImpl);
    }

    /// @notice Deploys a new operator node as a BeaconProxy
    /// @param operator The address of the operator
    /// @param config The configuration for the new operator node
    /// @return The address of the deployed BeaconProxy
    function deployOperatorNode(address operator, OperatorConfig calldata config) external returns (address) {
        require(operator_nodes[operator] == address(0), "Operator node already deployed");

        bytes memory data = abi.encodeWithSignature(
            "initialize(string,string,address,string[],uint256)",
            config.operatorName,
            config.operatorUri,
            config.treasuryAccount,
            config.supportedTokens,
            config.fee
        );

        BeaconProxy beaconProxy = new BeaconProxy(
            grid_router_gateway,
            data
        );
        operator_nodes[operator] = address(beaconProxy);
        emit OperatorNodeDeployed(operator, address(beaconProxy));
        return address(beaconProxy);
    }
}