package com.ibm.banking.service;

import com.ibm.banking.model.Account;
import com.ibm.banking.model.AccountStatus;
import com.ibm.banking.repository.AccountRepository;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.util.Optional;

public class AccountService {
    private final AccountRepository accountRepository;

    public AccountService(AccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    public Account openAccount(String accountNumber, String customerName, String accountType, BigDecimal initialDeposit) {
        if (accountNumber == null || accountNumber.trim().isEmpty()) {
            throw new IllegalArgumentException("Account number cannot be empty");
        }
        if (customerName == null || customerName.trim().isEmpty()) {
            throw new IllegalArgumentException("Customer name cannot be empty");
        }
        if (accountRepository.findByAccountNumber(accountNumber).isPresent()) {
            throw new IllegalArgumentException("Account already exists: " + accountNumber);
        }
        BigDecimal deposit = initialDeposit != null ? initialDeposit : BigDecimal.ZERO;
        if (deposit.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException("Initial deposit cannot be negative");
        }

        Account account = new Account(
                accountNumber.trim(),
                customerName.trim(),
                accountType != null ? accountType.trim() : "S",
                deposit,
                LocalDate.now(),
                AccountStatus.ACTIVE
        );
        accountRepository.save(account);
        return account;
    }

    public Optional<Account> getAccount(String accountNumber) {
        return accountRepository.findByAccountNumber(accountNumber);
    }
}
