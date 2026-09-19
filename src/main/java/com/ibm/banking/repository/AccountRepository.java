package com.ibm.banking.repository;

import com.ibm.banking.model.Account;
import com.ibm.banking.model.AccountStatus;
import com.ibm.banking.model.TransactionRecord;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

public class AccountRepository {
    private final Map<String, Account> accounts = new ConcurrentHashMap<>();
    private final List<TransactionRecord> transactionHistory = new ArrayList<>();

    public AccountRepository() {
        initSampleData();
    }

    private void initSampleData() {
        save(new Account("ACCT000001", "ALICE SMITH", "S", new BigDecimal("10000.00"), LocalDate.of(2023, 1, 15), AccountStatus.ACTIVE));
        save(new Account("ACCT000002", "BOB JONES", "C", new BigDecimal("5000.00"), LocalDate.of(2023, 3, 20), AccountStatus.ACTIVE));
        save(new Account("ACCT000003", "CHARLIE BROWN", "S", new BigDecimal("1200.00"), LocalDate.of(2023, 6, 10), AccountStatus.FROZEN));
        save(new Account("ACCT000004", "DAVID LEE", "C", new BigDecimal("0.00"), LocalDate.of(2022, 11, 5), AccountStatus.CLOSED));
    }

    public Optional<Account> findByAccountNumber(String accountNumber) {
        if (accountNumber == null) {
            return Optional.empty();
        }
        return Optional.ofNullable(accounts.get(accountNumber.trim()));
    }

    public void save(Account account) {
        accounts.put(account.getAccountNumber(), account);
    }

    public void logTransaction(TransactionRecord record) {
        synchronized (transactionHistory) {
            transactionHistory.add(record);
        }
    }

    public List<TransactionRecord> getTransactionHistory() {
        synchronized (transactionHistory) {
            return new ArrayList<>(transactionHistory);
        }
    }

    public List<Account> findAll() {
        return new ArrayList<>(accounts.values());
    }
}
