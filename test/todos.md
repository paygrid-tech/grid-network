## Protocol General tasks

- Define and implement multi-beacon delegation pattern for beacon contracts upgrades: GridOperatorBeacon + GridRouterGateway
- Define main storage layout and operator config and payment transaction intents storage structs and state variables
- Write necessary constants (native assets, max uints, null address, etc) and state variables and structs 
- Implement Access control with a combination of:
    > EIP-712: Best used in GridPaymentCoreV1 and GridOperatorNode for verifying signatures on payment transactions and operator node configuration updates (only write).
    While EIP-712 provides a robust way to authorize actions off-chain, traditional access control mechanisms are still necessary to manage and verify who the authorized operators are. 
        EIP-712 (Off-Chain Signatures):
        • Support more flexible and gasless interactions.
        • Suitable for scenarios where operators can sign messages off-chain, and the actual transaction submission can be handled by a relayer or another party.
        • Provides additional security and flexibility
    > Access Control: Implemented to secure critical functions and ensure only authorized operators/signers can perform read/update actions.
        Traditional Access Control Modifiers:   
        • Operators interact directly with the contract and if simplicity and straightforward on-chain enforcement are priorities.
        • Suitable for scenarios where gasless interactions are not necessary.
- Emit events for all state create and update actions 
- Implement error/exception handling and revert reasons
	•	Use `require` for input validation: require is ideal for checking conditions that are external to the contract, such as user inputs.
	•	Use `assert` for internal checks: assert should be used to ensure the internal consistency of the contract. The conditions checked with assert should never fail.
	•	Use `custom errors` for complex conditions: Custom errors are more gas-efficient and can provide detailed feedback.
- Implement circuit breakers and pausable pattern:
	• Pausable Pattern: Allows stopping and resuming the contract’s functionality in case of emergencies. Includes functions like pause, unpause, and modifiers whenNotPaused, whenPaused.
	• Circuit Breaker: A pattern similar to the Pausable pattern but focused on enabling or disabling specific functions in response to certain conditions, often used as a safety mechanism.
- Use `EnumerableMaps` if needed with mappings to make them enumerable
>>> external override onlyInitializer(initcaller) { // double check for bypass !!!


## Grid Protocol Manager

- The contract owner can grant and revoke the PG_ADMIN_ROLE.
- Non-owners can't grant or revoke roles.
- Protocol operators can add and remove supported tokens.
- Protocol operators can set the protocol fee.
- Protocol operators can set a new treasury wallet.

## Grid Operator Registry

- Implement 


## Grid Operator Node
- OperatorConfig Struct: Defined within the contract to manage operator configurations, including authorized signers.
- State Management: Uses a mapping to store operator configurations, ensuring efficient data access and updates.
- Initialization: The initialize function ensures each operator is set up with a unique configuration, including a generated operator ID.
- Authorization: Functions use the onlyAuthorizedSigner modifier to ensure that only authorized signers can update configurations or access sensitive data.
- Delegation: The delegateToPaymentCore function delegates calls to the GridPaymentCoreV1 implementation, preserving the context of the BeaconProxy.
- Fallback and Receive Functions: These ensure that any call not matched by a function signature is forwarded to the current implementation.







--------------------------------------------------------------------------
--------------------------------------------------------------------------

# Payment Core Contracts TASKS

- Implement Payment Core contract structure and constructors
- Write necessary globals and contract variables and structs (knowing that the contract doesn't store any data)
- Write access control modifiers and ownable necessary functions and initializtion
- Write main function to calculate protocol fees
- Write main function to process payment and transfer token from address > to address; parameters include 
    - address from
    - address to
    - address tokenAddress
    - uint256 amount
- During the payment processing we need to send protocol fees to a treasury wallet
- Implement necessary input validation and exception handling
- Implement PaymentProcessedSuccessfully event 
- Write deployment files with Openzepplin transparent proxy pattern
- Write administration functions to set and remove protocol fees
- Write administration functions to set and remove admins
- Write administration functions to set and remove treasury wallet address
- Write administration functions to set, check and remove supported token addresses


# Tests
## Administration: Tests are added to ensure:

- The contract owner can grant and revoke the PG_ADMIN_ROLE.
- Non-owners can't grant or revoke roles.
- Protocol operators can add and remove supported tokens.
- Protocol operators can set the protocol fee.
- Protocol operators can set a new treasury wallet.
## Payment Processing: 
The tests are extended to:
- Check the process payment function.
- Validate the protocol fee calculation. 
- Floating point value tests for USDC payment
- Add Revert Tests for Core Functionalities: Each main function should have at least one revert test to verify access controls and other conditions.
- Include Test for Removing Supported Tokens.

Hardhat Node:
Account #0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (10000 ETH)
Private Key: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

Account #1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (10000 ETH)
Private Key: 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

Account #2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (10000 ETH)
Private Key: 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a

Account #3: 0x90F79bf6EB2c4f870365E785982E1f101E93b906 (10000 ETH)
Private Key: 0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6

Account #4: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65 (10000 ETH)
Private Key: 0x47e179ec197488593b187f80a00eb0da91f1b9d0b13f8733639f19c30a34926a

Account #5: 0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc (10000 ETH)
Private Key: 0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba

Account #6: 0x976EA74026E726554dB657fA54763abd0C3a0aa9 (10000 ETH)
Private Key: 0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e

Account #7: 0x14dC79964da2C08b23698B3D3cc7Ca32193d9955 (10000 ETH)
Private Key: 0x4bbbf85ce3377467afe5d46f804f221813b2bb87f24d81f60f1fcdbf7cbf4356

Account #8: 0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f (10000 ETH)
Private Key: 0xdbda1821b80551c9d65939329250298aa3472ba22feea921c0cf5d620ea67b97

Account #9: 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 (10000 ETH)
Private Key: 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6

Account #10: 0xBcd4042DE499D14e55001CcbB24a551F3b954096 (10000 ETH)
Private Key: 0xf214f2b2cd398c806f84e317254e0f0b801d0643303237d97a22a48e01628897

Account #11: 0x71bE63f3384f5fb98995898A86B02Fb2426c5788 (10000 ETH)
Private Key: 0x701b615bbdfb9de65240bc28bd21bbc0d996645a3dd57e7b12bc2bdf6f192c82

Account #12: 0xFABB0ac9d68B0B445fB7357272Ff202C5651694a (10000 ETH)
Private Key: 0xa267530f49f8280200edf313ee7af6b827f2a8bce2897751d06a843f644967b1

Account #13: 0x1CBd3b2770909D4e10f157cABC84C7264073C9Ec (10000 ETH)
Private Key: 0x47c99abed3324a2707c28affff1267e45918ec8c3f20b8aa892e8b065d2942dd

Account #14: 0xdF3e18d64BC6A983f673Ab319CCaE4f1a57C7097 (10000 ETH)
Private Key: 0xc526ee95bf44d8fc405a158bb884d9d1238d99f0612e9f33d006bb0789009aaa

Account #15: 0xcd3B766CCDd6AE721141F452C550Ca635964ce71 (10000 ETH)
Private Key: 0x8166f546bab6da521a8369cab06c5d2b9e46670292d85c875ee9ec20e84ffb61

Account #16: 0x2546BcD3c84621e976D8185a91A922aE77ECEc30 (10000 ETH)
Private Key: 0xea6c44ac03bff858b476bba40716402b03e41b8e97e276d1baec7c37d42484a0

Account #17: 0xbDA5747bFD65F08deb54cb465eB87D40e51B197E (10000 ETH)
Private Key: 0x689af8efa8c651a91ad287602527f3af2fe9f6501a7ac4b061667b5a93e037fd

Account #18: 0xdD2FD4581271e230360230F9337D5c0430Bf44C0 (10000 ETH)
Private Key: 0xde9be858da4a475276426320d5e9262ecfc3ba460bfac56360bfa6c4c28b4ee0

Account #19: 0x8626f6940E2eb28930eFb4CeF49B2d1F2C9C1199 (10000 ETH)
Private Key: 0xdf57089febbacf7ba0bc227dafbffa9fc08a93fdc68e1e42411a14efcf23656e