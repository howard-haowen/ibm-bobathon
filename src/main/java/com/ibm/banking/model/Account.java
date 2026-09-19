package com.ibm.banking.model;

import java.math.BigDecimal;
import java.time.LocalDate;

public class Account {
    private String accountNumber;
    private String customerName;
    private String accountType; // "S" - Savings, "C" - Checking
    private BigDecimal balance;
    private LocalDate openDate;
    private AccountStatus status;

    public Account(String accountNumber, String customerName, String accountType, BigDecimal balance, LocalDate openDate, AccountStatus status) {
        this.accountNumber = accountNumber;
        this.customerName = customerName;
        this.accountType = accountType;
        this.balance = balance;
        this.openDate = openDate;
        this.status = status;
    }

    public String getAccountNumber() {
        return accountNumber;
    }

    public void setAccountNumber(String accountNumber) {
        this.accountNumber = accountNumber;
    }

    public String getCustomerName() {
        return customerName;
    }

    public void setCustomerName(String customerName) {
        this.customerName = customerName;
    }

    public String getAccountType() {
        return accountType;
    }

    public void setAccountType(String accountType) {
        this.accountType = accountType;
    }

    public BigDecimal getBalance() {
        return balance;
    }

    public void setBalance(BigDecimal balance) {
        this.balance = balance;
    }

    public LocalDate getOpenDate() {
        return openDate;
    }

    public void setOpenDate(LocalDate openDate) {
        this.openDate = openDate;
    }

    public AccountStatus getStatus() {
        return status;
    }

    public void setStatus(AccountStatus status) {
        this.status = status;
    }

    @Override
    public String toString() {
        return "Account{" +
                "accountNumber='" + accountNumber + '\'' +
                ", customerName='" + customerName + '\'' +
                ", accountType='" + accountType + '\'' +
                ", balance=" + balance +
                ", openDate=" + openDate +
                ", status=" + status +
                '}';
    }
}
