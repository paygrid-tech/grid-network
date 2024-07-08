// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGridProtocolManager {
    // Events
    event ProtocolTreasuryUpdated(address indexed newProtocolTreasury);
    event ProtocolFeeUpdated(uint256 newProtocolFee);
    event TokenAdded(address indexed tokenAddress, string symbol);
    event TokenRemoved(address indexed tokenAddress);
    event ProtocolOperatorGranted(address indexed account);
    event ProtocolOperatorRevoked(address indexed account);

    // Structs
    struct TokenInfo {
        bool isSupported;
        string symbol;
    }

    struct ProtocolConfig {
        address protocolTreasury;
        uint256 protocolFee;
        mapping(address => TokenInfo) supportedTokens;
        address[] supportedTokenAddresses;
    }

    // Function to initialize the contract
    function initialize(address _protocolTreasury, uint256 _protocolFee) external;

    // Function to grant protocol operator role
    function grantProtocolOperatorRole(address account) external;

    // Function to revoke protocol operator role
    function revokeProtocolOperatorRole(address account) external;

    // Function to get the list of protocol operators
    function getProtocolOperatorList() external view returns (address[] memory);

    // Function to add a supported token
    function addSupportedToken(address _tokenAddress, string memory _symbol) external;

    // Function to remove a supported token
    function removeSupportedToken(address _tokenAddress) external;

    // Function to set the protocol fee
    function setProtocolFee(uint256 _protocolFee) external;

    // Function to set the protocol treasury address
    function setProtocolTreasury(address _protocolTreasury) external;

    // Function to get the protocol treasury address
    function getProtocolTreasury() external view returns (address);

    // Function to get the protocol fee
    function getProtocolFee() external view returns (uint256);

    // Function to check if a token is supported
    function isTokenSupported(address _tokenAddress) external view returns (bool);

    // Function to get the list of supported tokens
    function getSupportedTokens() external view returns (address[] memory);

    // Function to determine if an asset is the native asset
    function isNativeAsset(address assetId) external pure returns (bool);
}
