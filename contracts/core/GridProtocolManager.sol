// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract GridProtocolManager is Ownable, AccessControl, Initializable {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct ProtocolConfig {
        uint256 protocolFee;
        address treasuryAddress;
        string[] supportedTokens;
        mapping(string => bool) isTokenSupported;
    }

    ProtocolConfig public protocolConfig;

    event ProtocolConfigUpdated(uint256 protocolFee, address treasuryAddress);
    event TokenSupportUpdated(string token, bool isSupported);

    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "Caller is not an admin");
        _;
    }

    function initialize(address admin, uint256 fee, address treasury, string[] memory tokens) external initializer {
        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(ADMIN_ROLE, admin);
        protocolConfig.protocolFee = fee;
        protocolConfig.treasuryAddress = treasury;
        for (uint256 i = 0; i < tokens.length; i++) {
            protocolConfig.supportedTokens.push(tokens[i]);
            protocolConfig.isTokenSupported[tokens[i]] = true;
        }
    }

    function updateProtocolConfig(uint256 fee, address treasury) external onlyAdmin {
        protocolConfig.protocolFee = fee;
        protocolConfig.treasuryAddress = treasury;
        emit ProtocolConfigUpdated(fee, treasury);
    }

    function addSupportedToken(string calldata token) external onlyAdmin {
        require(!protocolConfig.isTokenSupported[token], "Token already supported");
        protocolConfig.supportedTokens.push(token);
        protocolConfig.isTokenSupported[token] = true;
        emit TokenSupportUpdated(token, true);
    }

    function removeSupportedToken(string calldata token) external onlyAdmin {
        require(protocolConfig.isTokenSupported[token], "Token not supported");
        protocolConfig.isTokenSupported[token] = false;
        emit TokenSupportUpdated(token, false);
    }

    function getSupportedTokens() external view returns (string[] memory) {
        return protocolConfig.supportedTokens;
    }
}
