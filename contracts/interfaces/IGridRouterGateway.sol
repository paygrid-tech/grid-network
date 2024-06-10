// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGridRouterGateway {
    function updateImplementation(address newImplementation) external;

    function getImplementation() external view returns (address);
}
