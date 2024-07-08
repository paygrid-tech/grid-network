// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../interfaces/IGridProtocolManager.sol";
import "../interfaces/PaymentCoreBase.sol";

library PaymentCoreV1{
    using SafeERC20 for IERC20;

    event TransferProcessedSuccessfully(
        bytes32 indexed paymentId,
        address indexed from,
        address indexed to,
        uint256 amount,
        address tokenAddress,
        uint256 operatorFee,
        uint256 protocolFee
    );
    
    event TransferFailed(
        bytes32 indexed paymentId,
        address indexed from,
        address indexed to,
        string reason
    );

    /// @notice Processes a payment transaction
    /// @param intent The payment transaction intent
    /// @param protocolManager The protocol manager contract
    /// @param operatorFee The operator fee
    /// @param operatorTreasury The treasury account of the operator
    /// @return bool indicating if the payment processing was successful
    function processPayment(
        PaymentCoreBase.PaymentIntent memory intent,
        address protocolManager,
        uint256 operatorFee,
        address operatorTreasury
    ) internal returns (bool) {
        uint256 protocolFee = IGridProtocolManager(protocolManager).getProtocolFee();

        uint256 totalFee = protocolFee + operatorFee;
        uint256 paymentAmountAfterFee = intent.amount - totalFee;

        _transferTokens(intent.source.account, intent.destination.account, intent.source.payment_token, paymentAmountAfterFee);
        _transferTokens(intent.source.account, operatorTreasury, intent.source.payment_token, operatorFee);
        _transferTokens(intent.source.account, IGridProtocolManager(protocolManager).getProtocolTreasury(), intent.source.payment_token, protocolFee);
        //     emit TransferFailed(intent.paymentId, intent.source.account, intent.destination.account, "Failed to transfer payment amount");
        //     return false;
        // }

        emit TransferProcessedSuccessfully(
            intent.paymentId,
            intent.source.account,
            intent.destination.account,
            paymentAmountAfterFee,
            intent.source.payment_token,
            operatorFee,
            protocolFee
        );

        return true;
    }

    /// @notice Safely transfers tokens from one address to another
    /// @param from Source address
    /// @param to Destination address
    /// @param tokenAddress Address of the token contract
    /// @param amount Amount of tokens to transfer
    // / @param paymentId Unique identifier for the payment
    function _transferTokens(
        address from,
        address to,
        address tokenAddress,
        uint256 amount
        // bytes32 paymentId
    ) internal {
        require(amount > 0, "Amount must be greater than 0");
        require(tokenAddress != address(0), "Invalid token: zero address");
        
        IERC20 token = IERC20(tokenAddress);
        require(token.balanceOf(from) >= amount, "Not enough fund to transfer from sender wallet");
        require(token.allowance(from, address(this)) >= amount, "Insufficient allowance approval for transfer");

        // Use SafeERC20's safeTransferFrom to handle the transfer
        token.safeTransferFrom(from, to, amount);
    }
}