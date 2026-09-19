package com.ibm.banking.model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class TransactionRecord {
    private String transactionId;
    private String operation; // XFER, DEPO, WITH
    private String sourceAccountNumber;
    private String targetAccountNumber;
    private BigDecimal amount;
    private LocalDateTime timestamp;
    private String returnCode;
    private String returnMessage;

    public TransactionRecord(String transactionId, String operation, String sourceAccountNumber, String targetAccountNumber, BigDecimal amount, LocalDateTime timestamp, String returnCode, String returnMessage) {
        this.transactionId = transactionId;
        this.operation = operation;
        this.sourceAccountNumber = sourceAccountNumber;
        this.targetAccountNumber = targetAccountNumber;
        this.amount = amount;
        this.timestamp = timestamp;
        this.returnCode = returnCode;
        this.returnMessage = returnMessage;
    }

    public String getTransactionId() {
        return transactionId;
    }

    public String getOperation() {
        return operation;
    }

    public String getSourceAccountNumber() {
        return sourceAccountNumber;
    }

    public String getTargetAccountNumber() {
        return targetAccountNumber;
    }

    public BigDecimal getAmount() {
        return amount;
    }

    public LocalDateTime getTimestamp() {
        return timestamp;
    }

    public String getReturnCode() {
        return returnCode;
    }

    public String getReturnMessage() {
        return returnMessage;
    }

    @Override
    public String toString() {
        return "TransactionRecord{" +
                "transactionId='" + transactionId + '\'' +
                ", operation='" + operation + '\'' +
                ", sourceAccountNumber='" + sourceAccountNumber + '\'' +
                ", targetAccountNumber='" + targetAccountNumber + '\'' +
                ", amount=" + amount +
                ", timestamp=" + timestamp +
                ", returnCode='" + returnCode + '\'' +
                ", returnMessage='" + returnMessage + '\'' +
                '}';
    }
}
