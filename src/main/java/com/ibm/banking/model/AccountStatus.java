package com.ibm.banking.model;

public enum AccountStatus {
    ACTIVE("A", "Active"),
    FROZEN("F", "Frozen"),
    CLOSED("X", "Closed");

    private final String code;
    private final String description;

    AccountStatus(String code, String description) {
        this.code = code;
        this.description = description;
    }

    public String getCode() {
        return code;
    }

    public String getDescription() {
        return description;
    }

    public static AccountStatus fromCode(String code) {
        for (AccountStatus status : values()) {
            if (status.code.equalsIgnoreCase(code)) {
                return status;
            }
        }
        throw new IllegalArgumentException("Unknown status code: " + code);
    }
}
