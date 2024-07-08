// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title GridRouterGateway
/// @notice Manages the implementation address for GridPaymentCoreV1
contract GridRouterGateway is UpgradeableBeacon {
    
    event RGImplementationUpdated(address indexed newImplementation);

    /// @notice Constructor to initialize the beacon with the initial implementation
    /// @param initialImplementation The initial implementation address for GridPaymentCoreV1
    constructor(address initialImplementation) UpgradeableBeacon(initialImplementation, _msgSender()) {
        emit RGImplementationUpdated(initialImplementation);
    }

    // /// @notice Sets the implementation address
    // /// @param newImplementation The new implementation address
    // function setImplementation(address newImplementation) external onlyOwner {
    //     implementation = newImplementation;
    //     emit ImplementationUpdated(newImplementation);
    // }

    // /// @notice Gets the current implementation address
    // /// @return The current implementation address
    // function getImplementation() external view returns (address) {
    //     return implementation;
    // }
}