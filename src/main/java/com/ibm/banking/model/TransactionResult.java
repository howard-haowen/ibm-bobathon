package com.ibm.banking.model;

public class TransactionResult {
    private final String returnCode;
    private final String message;

    public TransactionResult(String returnCode, String message) {
        this.returnCode = returnCode;
        this.message = message;
    }

    public static TransactionResult success(String message) {
        return new TransactionResult("00", message);
    }

    public static TransactionResult failure(String returnCode, String message) {
        return new TransactionResult(returnCode, message);
    }

    public boolean isSuccess() {
        return "00".equals(returnCode);
    }

    public String getReturnCode() {
        return returnCode;
    }

    public String getMessage() {
        return message;
    }

    @Override
    public String toString() {
        return "[" + returnCode + "] " + message;
    }
}
