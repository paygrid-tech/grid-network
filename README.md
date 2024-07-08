# Grid Payment Protocol

## Intro

Grid is a network-agnostic payment protocol designed to provide developers and payment operators with a secure and modular standard framework to build, automate, and process cross-chain payment workflows. 

At its core, it consists of modules that define operations for different payment models and agreements, from basic one-time and recurring to usage-based and streaming payments. This level of abstraction is the foundation for creating context-rich payment transactions tailored to each outbound or inbound payment flow and use case.

The protocol design builds upon the concepts of interoperability, composability, self-custody and capabilities of programmable payments and smart contract accounts. Integrating and managing the end-to-end payment life-cycle, including authorizing payments, routing transactions, and handling settlements. 

Instead of reinventing the wheel and setting a yet another standard to follow, Grid protocol extends the ISO20022 financial messaging standard to support blockchain payments context, facilitating interoperable payment data transfer across blockchain and traditional fiat systems.


## Architecture Overview
![Alt text](./docs/Grid-architecture.png)

The architecture of the Grid Protocol consists of several key components:

### Grid Operator Registry (Factory)

This contract is based on the factory pattern and responsible for creating new beacon proxy instances of payment operator nodes Operators can begin facilitating payments after completing registration and integration. They are responsible for providing an integration layer and/or DApps for both payers and payees to interact with. Operator onboarding is permissionless, and Paygrid is the first operator in the network.

- Responsible for deploying new operator nodes
- Store a list for all operators and their operator nodes.
- Facilitate permissionless access and onboarding for new payment operators.


### Grid Operator Node

This is the operator payment gateway. Each payment operator interfacing with the protocol has a dedicated proxy deployed by the operator factory at registration. It serves as the entry point to all protocol operations. 

- Manage operator configurations and processes payment intents.

## Grid Protocol Manager
A transparent proxy contract that manages protocol configurations such as supported tokens, protocol fees, and treasury addresses.

### Payment Core V1

Core logic library for processing payments, including token transfers and fee calculations.

### Payment Modules

- **Operator Payment Task Scheduler:** Schedules automated payment tasks using the Gelato protocol.
- **XCRouter**: Supports cross-chain transfers and liquidity aggregation.

## Payment Transaction Intents

Each payment transfer use a primitive with the name **`PaymentIntent`**. This struct specifies the following:

- A unique identifier for payment transaction
- Payment type (one-time, recurring)
- The address of operator who is facilitating the payment processing
- The operator's signature
- Fiat currency
- Amount
- The source object:
    - Account address
    - Network ID
    - Payment token
- The destination object:
    - Account address
    - Network ID
    - Payment token
- Processing date
- The payment expiration timestamp
- Recurring paramaters:
    - interval
    - interval count
    - iterations count
    - start date
    - end date
- Payment metadata
- Status
- End-to-end reference

Along with these attributes, a `PaymentIntent` must be signed by the operator using EIP-712. This allows an operator to control how and when transaction processing happens and be selective about what payments to allow based on their backend business logic, internal policies, legal requirements, or other reasons. It also ensures that a `PaymentIntent` cannot be forged or have its data modified in any way.

### Payment Status Tracking

- **Processing**: The payment transaction intent has been validated and created
- **Completed**: The payment transaction intent has been successfully processed and confirmed. This indicates that the funds have been transferred.
- **Scheduled:** The payment transaction is scheduled for processing at a specific time interval or recurring billing cycle.
    - E.g monthly transfer of 10 USDC from A to B.
    - E.g A one-time transfer of 3190 USDC executed on 01/04/2025 at 10:30AM 🕥
- **Cancelled**:  The payment request has been cancelled by the operator or either transaction parties
- **Failed**: The payment transaction encountered an error or was reverted for some reason preventing the transaction from being completed.
    
    **Possible Transitions:**
    
    - **`Processing → Completed`**
    - **`Processing → Failed`**
    - **`Processing → Cancelled`**
    - **`Scheduled → Cancelled`**
    - **`Scheduled → Completed`**

### Payment methods supported

Native and ERC-20 token transfers are supported along with cross-chain token settlements where we meet payers at their point of liquidity and guarantee that accounts receive funds in their preferred token(s).

### **Security Considerations**

- **Role-Based Access Control:** RBAC is implemented to authorize and restrict access to certain functions and data within the protocol to users based on their assigned role. Roles are defined (e.g. Operator, Account Endpoint) and permissions are assigned respectively with modifiers.
- **Authorization Management:** Its purpose is to ensure that all transactions and operations are performed by authenticated and authorized entities by implementing signature verification and allowance checks for transactions. Each operation, especially those involving fund transfers, should require authorization from the involved parties.
- **Self-Custody:** Ensuring that all parties involved in transactions maintain control over their funds which are never locked in the protocol at any time. This minimizes the risk of draining attacks and breaches from a central point of failure. Ensuring that agreements and transactions require explicit user approval via signatures schemes helps enforce this principle.

----

Grid protocol is permisionless and free to use, experiment and build on top of. Reach out to us if you're interested to contribute to the future of payment technology.