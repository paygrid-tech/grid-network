    // SPDX-License-Identifier: MIT
    pragma solidity ^0.8.0;

    /// @author Moughite El Joaydi (@Stronot)
    /// @title Paygrid Payment Core contract
    /// @dev Payment Core is the payment processor for inbound and outbound transactions 

    import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
    import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

    contract GridPaymentCoreV1 is Initializable, OwnableUpgradeable, AccessControlUpgradeable {
        using SafeERC20Upgradeable for IERC20Upgradeable;

        bytes32 private constant PG_ADMIN_ROLE = keccak256("PG_ADMIN_ROLE");

        address private treasuryWallet;
        uint256 private protocolFee;

        struct TokenInfo {
            bool isSupported;
            string symbol;
        }

        mapping(address => TokenInfo) public supportedTokens;
        address[] public supportedTokenAddresses;

        // Events
        event PaymentProcessedSuccessfully(address indexed from, address indexed to, uint256 amount, address tokenAddress);
        event TokenTransferred(address indexed from, address indexed to, address tokenAddress, uint256 amount);
        
        // Modifiers
        modifier onlyProtocolOperator() {
            require(hasRole(PG_ADMIN_ROLE, _msgSender()), "Access denied: Caller is not a protocol operator");
            _;
        }

        // Replace the constructor with an initializer
        function initialize(address _treasuryWallet) public initializer {
            require(_treasuryWallet != address(0), "Treasury wallet cannot be zero address");
            __AccessControl_init();
            _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
            // Grant the deployer PG_ADMIN_ROLE first
            _setupRole(PG_ADMIN_ROLE, _msgSender());
            __PaymentCore_init(_treasuryWallet);
        }

        function __PaymentCore_init(address _treasuryWallet) internal {
            treasuryWallet = _treasuryWallet;
            protocolFee = 1;
        }
        
        /**
        * @dev Calculate the protocol fees for a given amount.
        * @param _amount The amount for which the fee needs to be calculated.
        * @return Returns the calculated fee.
        */
        function calculateProtocolFees(uint256 _amount) external view returns (uint256) {
            return (_amount * protocolFee) / 100; // divide by 10000 because fee is scaled by 100
        }

        /**
        * @dev Safely transfers tokens from one address to another.
        * @param from Source address.
        * @param to Destination address.
        * @param tokenAddress Address of the token contract.
        * @param amount Amount of tokens to transfer.
        */
        function _transferTokens(
            address from,
            address to,
            address tokenAddress,
            uint256 amount
        )   internal returns (bool) {
            require(amount > 0, "Amount must be greater than 0");
            require(tokenAddress != address(0), "Invalid token: zero address");
            
            IERC20Upgradeable token = IERC20Upgradeable(tokenAddress);
            require(token.balanceOf(from) >= amount, "Not enough fund to transfer from customer wallet");
            require(token.allowance(from, address(this)) >= amount, "Insufficient approval for transfer");
            
            SafeERC20Upgradeable.safeTransferFrom(token, from, to, amount);
            emit TokenTransferred(from, to, tokenAddress, amount);
            return true;
        }

        /**
        * @dev Process a payment, transfers the token after deducting the protocol fee.
        * @param from customer wallet address.
        * @param to merchant treasury/beneficary address.
        * @param tokenAddress Address of the token to be transferred.
        * @param amount Payment amount of tokens to be transferred.
        */
        function processPayment(
            address from,
            address to,
            address tokenAddress,
            uint256 amount
        ) external onlyProtocolOperator {
            require(supportedTokens[tokenAddress].isSupported, "Token not supported");
            
            uint256 fee = this.calculateProtocolFees(amount);
            uint256 paymentAmountAfterFee = amount - fee;

            _transferTokens(from, to, tokenAddress, paymentAmountAfterFee);
            _transferTokens(from, getTreasuryWallet(), tokenAddress, fee);

            emit PaymentProcessedSuccessfully(from, to, paymentAmountAfterFee, tokenAddress);
        }

        // Administration Functions

        /**
        * @dev Add a new token to the supported tokens list.
        * @param _tokenAddress Address of the token to be supported.
        * @param _symbol Symbol of the token to be supported.
        */
        function addSupportedToken(address _tokenAddress, string memory _symbol) external onlyProtocolOperator {
            require(!supportedTokens[_tokenAddress].isSupported, "Token already supported");
            supportedTokens[_tokenAddress] = TokenInfo({ isSupported: true, symbol: _symbol });
            // Push the address to our array
            supportedTokenAddresses.push(_tokenAddress);            
        }

        function isTokenSupported(address _tokenAddress) external view returns (bool) {
            return supportedTokens[_tokenAddress].isSupported;
        }        

        function getSupportedTokens() external view returns (address[] memory) {
            return supportedTokenAddresses;
        }        

        /**
        * @dev Remove a token from the supported tokens list.
        * @param _tokenAddress Address of the token to be removed.
        */
        function removeSupportedToken(address _tokenAddress) external onlyProtocolOperator {
            supportedTokens[_tokenAddress].isSupported = false;
        }

        function setProtocolFee(uint256 _protocolFee) external onlyProtocolOperator {
            protocolFee = _protocolFee;
        }

        /**
        * @dev Set a new treasury wallet address.
        * @param _treasuryWallet Address of the new treasury wallet.
        */
        function setTreasuryWallet(address _treasuryWallet) external onlyProtocolOperator {
            require(_treasuryWallet != address(0), "Treasury wallet cannot be zero address");
            treasuryWallet = _treasuryWallet;
        }

        function grantAdmin(address account) external onlyProtocolOperator {
            grantRole(PG_ADMIN_ROLE, account);
        }

        function revokeAdmin(address account) external onlyProtocolOperator {
            revokeRole(PG_ADMIN_ROLE, account);
        }

        // Getters for private state variables (if necessary)
        function getTreasuryWallet() public view returns (address) {
            return treasuryWallet;
        }

        function getProtocolFee() public view returns (uint256) {
            return protocolFee;
        }
    }
