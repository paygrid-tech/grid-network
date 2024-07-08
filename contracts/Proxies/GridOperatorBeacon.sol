// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title GridOperatorBeacon
/// @notice Beacon contract for managing GridOperatorNode implementations
contract GridOperatorBeacon is UpgradeableBeacon {

    event OpBeaconImplementationUpdated(address indexed newImplementation);

    /// @notice Constructor to initialize the beacon with the initial implementation
    /// @param initialImplementation The initial implementation address for GridOperatorNode
    constructor(address initialImplementation) UpgradeableBeacon(initialImplementation,_msgSender()) {
        emit OpBeaconImplementationUpdated(initialImplementation);
    }

    /// @notice Updates the implementation address of the beacon
    /// @param newImplementation The new implementation address for GridOperatorNode
    function updateImplementation(address newImplementation) external onlyOwner {
        upgradeTo(newImplementation);
        emit OpBeaconImplementationUpdated(newImplementation);
    }
}
