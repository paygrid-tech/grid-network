# **Grid: Payment Intent Protocol**

## Overview

Grid is an open intent-based protocol designed to handle on-chain payment operations. It serves as the on-chain settlement contract for the Paygrid Network. Grid is open-source, permissionless and free to use.

To learn more about Paygrid Network, please refer to [Paygrid Docs](https://docs.paygrid.network/).

## **Protocol Components**

### Chain-abstracted Payment Intent (CAPI)

CAPIs are primitives based on a declarative model that describe self-contained instructions for executing specific payment outcomes. Each `Payment Intent` define parameters such as the source and destination domains, amount, recipient(s), and any conditions or constraints required for execution. These primitives support multi-step or complex transactions, including recurring, batch payments, conditional transfers, and multi-party settlements, allowing for flexible, programmable payment flows. 

Payment Intents streamline transaction logic, reduce execution errors, and provide an auditable trail, enabling automated workflows through integration with smart contracts. The struct specifies the following:

```solidity
/* 
* @notice Struct representing the payment intent, 
* the core primitive for processing payments flows 
*/
struct PaymentIntent {
    bytes32 paymentId; // Payment Intent ID, generated or provided off-chain
    PaymentType payment_type; // Specifies the type of payment: one-time, recurring, etc.
    OperatorData operator_data; // Operator processing this payment (operator details, fees, etc.)
    uint256 amount; // The amount to be transferred
    Domain source; // The source chain, specifying the wallet address, network ID, and payment token for the transfer
    Domain destination; // The destination chain 
    uint256 processing_date; // The date the payment is set to be processed, useful for scheduled payments. If not set, defaults to immediate execution
    uint256 expires_at; // Timestamp indicating when this payment intent expires (used for signature-based payments, e.g., permit2)
    Schedule schedule; // Contains scheduling data if the payment is recurring, such as interval details and repetition count
    bytes p2_sig; // The permit2 signature from the payer, authorizing the payment intent
    uint256 nonce; // A nonce to protect against replay attacks, also used for permit2 signature verification
    string payment_reference; // (Optional) An external reference for off-chain reconciliation or tracking of the payment
    bytes metadata; // Arbitrary metadata field for storing additional intent-type specific information
}

struct OperatorData {
    bytes32 operatorId; // Operator facilitating the payment
    address operator; // The address of the operator
    address[] authorized_signers; // List of authorized delegates to sign or initiate the payment on behalf of the operator
    address treasury_account; // The operator's treasury wallet where the operator's fees will be transferred
    uint256 fee; // The fee percentage deducted from the transfer amount and sent to the operator's treasury (e.g., 2% fee = 200 bp)
    string operatorURI; // A well-known public URL that provides a standardized JSON document with operator config data.
}

struct GatewayConfig {
    address relayer_address; // Address of the relayer or gateway handling the payment execution
    uint256 fee; // Fee charged by the gateway for processing the payment, distinct from the operator fee
    address treasury; // Treasury address for the gateway where the execution fee is sent
}

struct Domain {
    address account; // The wallet address from which the payment is sourced or to which it is sent
    uint256 network_id; // Network ID of the blockchain where the payment will be executed (e.g., Ethereum mainnet, Polygon, etc.)
    address payment_token; // Address of the token being used for the payment (e.g., ERC20 token or native address)
}

struct Schedule {
    IntervalUnit intervalUnit; // Unit of time for the recurring interval (day, week, month, year)
    uint256 interval_count; // Number of interval units between each occurrence (e.g., 2 for bi-weekly if intervalUnit is week)
    uint256 iterations; // Number of iterations the payment should be repeated; if set, end_date should not be used
    uint256 start_date; // The timestamp of when the recurring payments should start
    uint256 end_date; // The timestamp for when the recurring payments should stop (ignored if iterations are set)
}
```
 
> 🔒 Along with these attributes, a **`PaymentIntent`** must be authorized by the operator (or an approved delegate) by producing a EIP-712 or EIP-1271 signature. This allows authentication and for operator to control how and when intent processing happens and be selective about what payments to allow based on their business logic, internal policies, legal requirements, or other reasons. It also ensures that a **`PaymentIntent`** cannot be forged or have its data modified in any way.

----

### **Payment Status Tracking**
  
- **Processing**: The payment transfer intent has been validated and created
- **Completed**: The payment transfer intent has been successfully processed and confirmed. This indicates that the funds have been transferred.
- **Scheduled:** The payment transaction is scheduled for processing at a specific time interval or recurring cycle.
- **Cancelled**: The payment has been cancelled by the operator or either transaction parties
- **Failed**: The payment transaction encountered an error or was reverted for some reason preventing the transaction from being completed.

### Payment Status Update: [IPN Webhooks](https://en.wikipedia.org/wiki/Instant_payment_notification)

IPN is a specific type of webhook typically used in financial or eCommerce contexts to communicate changes in payment status. Payment status events during the payment intent lifecycle are recorded by a **`PAYMENT_STATUS_UPDATE`** event emitted by the protocol:

```solidity
event PAYMENT_STATUS_UPDATE(
    bytes32 indexed paymentID,
    bytes32 indexed operatorID,
    address indexed operator, // 
    address sender,
    address receiver,
    uint256 amount,
    address payment_token,
    uint256 executed_date,
    uint256 next_payment_date,
    PaymentStatus status,
    string payment_reference,
    string metadata,
    string reason
);
```

In the case of errors, a specific error type is returned with details about what went wrong.
### Payment methods supported
Native and ERC-20 token transfers are supported along with cross-chain token settlements where we meet payers at their point of liquidity and guarantee that accounts receive funds in their preferred token(s).


## Repository Structure

```
.
├── README.md         // You are here 
├── config            // Configuration files
├── contracts         // Protocol contracts code 
│   ├── core          // Core protocol logic
│   ├── helpers       // Helper definitions                     
│   ├── interfaces    // Interface definitions
│   ├── library       // Library definitions
│   ├── Proxies                             
│   ├── abstract
├── deployments       // Deployment scripts
├── docs              // Contracts technical docs and arch diagrams (placeholder)
├── scripts           // scripts containing sample calls
├── test              // Contract unit and integration tests

```

## Deployments

The Grid Payment Protocol is live on the following networks. We are continuously expanding to additional networks over time. 

| Network  | Environment  | Address                                    |
| -------- | -------------| ------------------------------------------ |
| POLYGON  | Mainnet      | 0x945366b290db61105B8DbD4D50B1dFDCed7a4342 |
| BASE     | Mainnet      | 0x93F07df792F40693fb9A31e62711aA6AFfe7efc6 |
| ARBITRUM | Mainnet      | 0x4B1d5b0aF5AbAe333C8d2CCa2a346e0D5f68C427 |
| OPTIMISM | Mainnet      | 0x4B1d5b0aF5AbAe333C8d2CCa2a346e0D5f68C427 |
| ETHEREUM | Mainnet      | 0xCF8d61b1fD933aedd5fFBD586A2ECf991f926444 |

- The `GridPaymentGateway` logic contract is upgradeable during the initial phase but will be non-upgradeable upon full release.
- Addresses will be updated when new versions are deployed on mainnets.
- The entry point `GridOperatorProxy` will be using a factory contract for easily deploying contracts to the same address on multiple chains, using [CREATE3](https://github.com/zeframlou/create3-factory).
- Excluded from this repo is a copy of [Uniswap/permit2](https://github.com/Uniswap/permit2), which would be copied to `contracts/permit2` in order to compile.

