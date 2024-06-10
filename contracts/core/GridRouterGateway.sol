// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/// @title GridRouterGateway
/// @notice Manages the address of the current GridPaymentCoreV1 implementation
contract GridRouterGateway is Ownable {
    address public implementation;

    event ImplementationUpdated(address newImplementation);

    /// @notice Constructor to set the initial implementation address
    constructor(address initialImplementation) {
        implementation = initialImplementation;
    }

    /// @notice Updates the implementation address
    function updateImplementation(address newImplementation) external onlyOwner {
        implementation = newImplementation;
        emit ImplementationUpdated(newImplementation);
    }

    /// @notice Returns the current implementation address
    function getImplementation() external view returns (address) {
        return implementation;
    }
}
