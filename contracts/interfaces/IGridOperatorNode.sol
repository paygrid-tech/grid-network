// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGridOperatorNode {
    struct OperatorConfig {
        string operatorId;
        string operatorName;
        string operatorUri;
        address treasuryAccount;
        string[] supportedTokens;
        address[] authorizedSignersList;
        mapping(address => bool) authorizedSigners; // by default operator address and proxy endpoint address
        uint256 fee;
        address proxy_endpoint;
    }

    function initialize(
        string memory operatorName,
        string memory operatorUri,
        address treasuryAccount,
        string[] memory supportedTokens,
        uint256 fee
    ) external;

    function isAuthorizedSigner(address operator, address signer) external view returns (bool);

    function updateOperatorConfig(address operator, OperatorConfig calldata config) external;

    function getOperatorNodeConfig(address operator) external view returns (OperatorConfig memory);
}
