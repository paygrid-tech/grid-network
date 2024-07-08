// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol"; 
import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";

contract GridProtocolManager is Initializable, OwnableUpgradeable, AccessControlEnumerableUpgradeable {
    using ERC165Checker for address;

    bytes32 public constant G_PROTOCOL_OPERATOR = keccak256("G_PROTOCOL_OPERATOR");

    address internal constant NULL_ADDRESS = address(0);
    /// @dev All native assets use the empty address for their asset id by convention
    address internal constant NATIVE_ASSETID = NULL_ADDRESS; // address(0)

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

    ProtocolConfig private protocolConfig;

    event ProtocolTreasuryUpdated(address indexed newProtocolTreasury);
    event ProtocolFeeUpdated(uint256 newProtocolFee);
    event TokenAdded(address indexed tokenAddress, string symbol);
    event TokenRemoved(address indexed tokenAddress);
    event ProtocolOperatorGranted(address indexed account);
    event ProtocolOperatorRevoked(address indexed account);

    /// @notice Initializes the GridProtocolManager contract with initial protocol treasury and fee
    /// @param _protocolTreasury The initial address for the protocol treasury
    /// @param _protocolFee The initial protocol fee
    function initialize(address _protocolTreasury, uint256 _protocolFee) public initializer {
        require(_protocolTreasury != address(0), "Protocol treasury cannot be zero address");
        require(_protocolFee > 0, "Protocol fee must be greater than zero");

        __Ownable_init(_msgSender());
        __AccessControlEnumerable_init();

        _setupRoles(_msgSender());
        __ProtocolConfig_init(_protocolTreasury, _protocolFee);
    }

    /// @notice Internal function to setup roles
    /// @param admin The address of the admin
    function _setupRoles(address admin) internal {
        _setRoleAdmin(G_PROTOCOL_OPERATOR, DEFAULT_ADMIN_ROLE);
        grantRole(DEFAULT_ADMIN_ROLE, admin);
        grantRole(G_PROTOCOL_OPERATOR, admin);
    }

    /// @notice Internal function to initialize the protocol configuration
    /// @param _protocolTreasury The address for the protocol treasury
    /// @param _protocolFee The protocol fee
    function __ProtocolConfig_init(address _protocolTreasury, uint256 _protocolFee) internal {
        protocolConfig.protocolTreasury = _protocolTreasury;
        protocolConfig.protocolFee = _protocolFee;
    }

    modifier onlyProtocolOperator() {
        require(hasRole(G_PROTOCOL_OPERATOR, _msgSender()), "Access denied: Caller is not a protocol operator");
        _;
    }

    /// @notice Grants the Protocol Operator role to an account
    /// @param account The account to be granted the Protocol Operator role
    function grantProtocolOperatorRole(address account) external onlyOwner {
        grantRole(G_PROTOCOL_OPERATOR, account);
        emit ProtocolOperatorGranted(account);
    }

    /// @notice Revokes the Protocol Operator role from an account
    /// @param account The account to be revoked from the Protocol Operator role
    function revokeProtocolOperatorRole(address account) external onlyOwner {
        revokeRole(G_PROTOCOL_OPERATOR, account);
        emit ProtocolOperatorRevoked(account);
    }

    /// @notice Returns the list of protocol operators
    /// @return An array of addresses of protocol operators
    function getProtocolOperatorList() external view onlyOwner returns (address[] memory) {
        uint256 count = this.getRoleMemberCount(G_PROTOCOL_OPERATOR);
        address[] memory operators = new address[](count);

        for (uint256 i = 0; i < count; i++) {
            operators[i] = this.getRoleMember(G_PROTOCOL_OPERATOR, i);
        }

        return operators;
    }

    /// @notice Adds a supported token to the protocol configuration
    /// @param _tokenAddress The address of the token to be added (zero address for native tokens)
    /// @param _symbol The symbol of the token to be added
    function addSupportedToken(address _tokenAddress, string memory _symbol) external onlyProtocolOperator {
        if (!isNativeAsset(_tokenAddress)) {
            require(_tokenAddress.supportsInterface(type(IERC20).interfaceId), "Invalid ERC20 token address");
        }
        require(!this.isTokenSupported(_tokenAddress), "Token already supported");

        protocolConfig.supportedTokens[_tokenAddress] = TokenInfo({
            isSupported: true,
            symbol: _symbol
        });
        protocolConfig.supportedTokenAddresses.push(_tokenAddress);

        emit TokenAdded(_tokenAddress, _symbol);
    }

    /// @notice Removes a supported token from the protocol configuration
    /// @param _tokenAddress The address of the token to be removed
    function removeSupportedToken(address _tokenAddress) external onlyProtocolOperator {
        require(this.isTokenSupported(_tokenAddress), "Token not supported");

        protocolConfig.supportedTokens[_tokenAddress].isSupported = false;

        emit TokenRemoved(_tokenAddress);
    }

    /// @notice Sets the protocol fee
    /// @param _protocolFee The new protocol fee
    function setProtocolFee(uint256 _protocolFee) external onlyProtocolOperator {
        require(_protocolFee > 1, "Protocol fee must be less than 1%");
        protocolConfig.protocolFee = _protocolFee;

        emit ProtocolFeeUpdated(_protocolFee);
    }

    /// @notice Sets the protocol treasury address
    /// @param _protocolTreasury The new address for the protocol treasury
    function setProtocolTreasury(address _protocolTreasury) external onlyProtocolOperator {
        require(_protocolTreasury != address(0), "Protocol treasury cannot be zero address");
        protocolConfig.protocolTreasury = _protocolTreasury;

        emit ProtocolTreasuryUpdated(_protocolTreasury);
    }

    /// @notice Returns the protocol treasury address
    /// @return The address of the protocol treasury
    function getProtocolTreasury() external view returns (address) {
        return protocolConfig.protocolTreasury;
    }

    /// @notice Returns the protocol fee
    /// @return The protocol fee
    function getProtocolFee() external view returns (uint256) {
        return protocolConfig.protocolFee;
    }

    /// @notice Checks if a token is supported
    /// @param _tokenAddress The address of the token
    /// @return True if the token is supported, false otherwise
    function isTokenSupported(address _tokenAddress) external view returns (bool) {
        return protocolConfig.supportedTokens[_tokenAddress].isSupported;
    }

    /// @notice Returns the list of supported tokens
    /// @return An array of addresses of supported tokens
    function getSupportedTokens() external view returns (address[] memory) {
        return protocolConfig.supportedTokenAddresses;
    }

    /// @notice Determines whether the given assetId is the native asset
    /// @param assetId The asset identifier to evaluate
    /// @return Boolean indicating if the asset is the native asset
    function isNativeAsset(address assetId) internal pure returns (bool) {
        return assetId == NATIVE_ASSETID;
    }
}
