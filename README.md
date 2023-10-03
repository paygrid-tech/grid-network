# Paygrid Payment Core Contract

## Overview
The Payment Core Contract serves as the payment processor for inbound and outbound transactions on EVM blockchains. This contract provides a seamless way to process payments while ensuring the protocol fees are correctly implemented and transferred to the designated treasury wallet.

## Features
- Allows the integration of various tokens for payment processing.
- Deducts a protocol fee for each payment processed.
- All processed payments and token transfers emit events for transparency and traceability.
- Administration functions to manage protocol settings and supported tokens.

## Setup
1. Ensure that you have [Hardhat](https://hardhat.org/getting-started/) set up.
2. Install required OpenZeppelin contracts and other dependencies:
   ```
   npm install @openzeppelin/contracts-upgradeable
   ```

3. Deploy the `PaymentCore` contract using your preferred development environment.

## Usage

### Initialization
To initialize the contract, provide the treasury wallet address during the deployment phase:

```solidity
function initialize(address _treasuryWallet) public initializer;
```

### Administration Functions
Administrative functions provide control over the contract's settings and allow the addition/removal of supported tokens:

- `addSupportedToken(address _tokenAddress, string memory _symbol)`: Add a token to the list of supported tokens.
- `removeSupportedToken(address _tokenAddress)`: Remove a token from the list of supported tokens.
- `setProtocolFee(uint256 _protocolFee)`: Set the protocol fee.
- `setTreasuryWallet(address _treasuryWallet)`: Set the treasury wallet address.
- `grantAdmin(address account)`: Grant an address the PG_ADMIN_ROLE.
- `revokeAdmin(address account)`: Revoke the PG_ADMIN_ROLE from an address.

### Payment Processing

To process a payment:

```solidity
function processPayment(
    address from,
    address to,
    address tokenAddress,
    uint256 amount
) external onlyProtocolOperator;
```

Ensure that the token is supported, and the sender has approved sufficient funds to the contract.

## Events

- `PaymentProcessedSuccessfully`: Emits when a payment is successfully processed.
- `TokenTransferred`: Emits when a token is transferred.

## Dependencies
The contract utilizes OpenZeppelin's upgradeable contracts to ensure safety and upgradability:

- `OwnableUpgradeable`: Provides basic authorization control functions.
- `AccessControlUpgradeable`: Provides a more flexible approach to permissions.
- `IERC20Upgradeable` and `SafeERC20Upgradeable`: ERC20 interfaces and utility functions.