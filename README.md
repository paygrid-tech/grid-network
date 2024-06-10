# Grid Payment Protocol Overview

Grid is a payment protocol designed to provide payment operators with a standard framework and modular architecture to build, automate, and process cross-chain payment workflows. At its core, it consists of modules that define operations for compliance and different payment models, from basic one-time and recurring to usage-based and streaming payments. This level of abstraction is the foundation for creating context-aware payment transactions tailored to each outbound or inbound payment model and use case.

The protocol design builds upon the concepts of interoperability, composability, self-custody and capabilities of programmable payments and modular smart contract accounts. Integrating and managing the end-to-end payment life-cycle, including authorizing payments, routing transactions, and handling settlements. 

Instead of reinventing the wheel and setting a yet another standard to follow, Grid protocol extends the ISO20022 financial messaging standard to support blockchain payments context, facilitating interoperable payment data transfer across blockchain and traditional fiat systems.

### Grid Operator Registry (Factory)

This contract is based on the factory pattern and responsible for creating new beacon proxy instances of payment operator nodes. An entry point to facilitate payment operators onboarding and maintains a registry mapping of operators and their operator nodes addresses. They are responsible for setting up account endpoints (not in V1 scope) with the protocol and providing an integration layer and/or DApps for their users.

- Responsible for deploying new operator nodes
- Store a mapping for all operators and their operator nodes.
- Facilitate permissionless access and onboarding for new payment operators.


### Grid Operator Node (Beacon Proxy)

This contract is the operator payment routing gateway of the protocol. Each payment operator interfacing with the protocol has a dedicated beacon proxy contract deployed by the operator factory at registration. It serves as a state storage and entry point to all protocol operations. 

- Delegates calls to implementation contract **`GridPaymentCoreV1`**
- Operators access control is enforced here and only authorized signers are allowed to read or modify operator data.
- Store a mapping registry for all operators and their configuration data

**NOTE: The operator node is not a classical beacon proxy but it slightly different since it holds operator config state variables and logic to read and update them**

### Grid Payment Core V1

Core logic contract responsible for executing the payment transaction, 

- The **`Operator Node`** proxy ****contract calls the  **`Grid Payment Core V1`**to initiate a payment transaction intent.
- The **`Grid Payment Core V1`** verifies if operator is authorized by using an Operator node modifier and passing the msg sender then checks validity of payment details.
    - An EIP-712 signature check is included here for every payment transaction intent
- The **`Grid Payment Core V1`** execute the transaction and transfers the payment amount in tokens from source to destination minus the fees sent to the operator treasury account.
- The **`Grid Payment Core V1`** records the successful completed payment details and stores a payment transaction intent associated with the calling operator.
- Emits a payment transaction event with status and other details

**NOTE: This contract can read and probably update the operator config data by interacting with the `Operator Node`  using a redirection mechanism for the original msg.sender for authorization checks.**

## **Payment Transaction Intents**

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