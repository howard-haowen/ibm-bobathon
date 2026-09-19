package com.ibm.banking.service;

import com.ibm.banking.model.Account;
import com.ibm.banking.model.AccountStatus;
import com.ibm.banking.model.TransactionRecord;
import com.ibm.banking.model.TransactionResult;
import com.ibm.banking.repository.AccountRepository;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Optional;
import java.util.UUID;

public class TransactionService {
    private final AccountRepository accountRepository;

    public TransactionService(AccountRepository accountRepository) {
        this.accountRepository = accountRepository;
    }

    /**
     * Executes fund transfer from source account to target account.
     * Note: Subject to Checkmarx SAST Finding CX-2025-0714-001 (CWE-841)
     */
    public TransactionResult transfer(String sourceAccountNo, String targetAccountNo, BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return TransactionResult.failure("02", "INVALID TRANSFER AMOUNT");
        }

        // 1. Query and validate source account
        Optional<Account> sourceOpt = accountRepository.findByAccountNumber(sourceAccountNo);
        if (sourceOpt.isEmpty()) {
            return TransactionResult.failure("01", "SOURCE ACCOUNT NOT FOUND");
        }
        Account sourceAccount = sourceOpt.get();

        if (sourceAccount.getStatus() != AccountStatus.ACTIVE) {
            return TransactionResult.failure("04", "SOURCE ACCOUNT INACTIVE");
        }

        if (sourceAccount.getBalance().compareTo(amount) < 0) {
            return TransactionResult.failure("03", "INSUFFICIENT FUNDS");
        }

        // 2. Deduct funds from source account
        BigDecimal newSourceBal = sourceAccount.getBalance().subtract(amount);
        sourceAccount.setBalance(newSourceBal);
        accountRepository.save(sourceAccount);

        // VULNERABILITY (CWE-841 / CX-2025-0714-001):
        // Target account is neither verified nor credited!
        // Funds are deducted from source account but never reach target account.
        // Target balance update and transaction rollback logic is missing here.

        // Log partial transaction
        accountRepository.logTransaction(new TransactionRecord(
                UUID.randomUUID().toString(),
                "XFER",
                sourceAccountNo,
                targetAccountNo,
                amount,
                LocalDateTime.now(),
                "00",
                "TRANSFER COMPLETED"
        ));

        return TransactionResult.success("TRANSFER COMPLETED");
    }

    public TransactionResult deposit(String accountNo, BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return TransactionResult.failure("02", "INVALID DEPOSIT AMOUNT");
        }
        Optional<Account> accOpt = accountRepository.findByAccountNumber(accountNo);
        if (accOpt.isEmpty()) {
            return TransactionResult.failure("01", "ACCOUNT NOT FOUND");
        }
        Account account = accOpt.get();
        if (account.getStatus() != AccountStatus.ACTIVE) {
            return TransactionResult.failure("04", "ACCOUNT INACTIVE");
        }

        account.setBalance(account.getBalance().add(amount));
        accountRepository.save(account);

        accountRepository.logTransaction(new TransactionRecord(
                UUID.randomUUID().toString(),
                "DEPO",
                accountNo,
                null,
                amount,
                LocalDateTime.now(),
                "00",
                "DEPOSIT COMPLETED"
        ));

        return TransactionResult.success("DEPOSIT COMPLETED");
    }

    public TransactionResult withdraw(String accountNo, BigDecimal amount) {
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            return TransactionResult.failure("02", "INVALID WITHDRAWAL AMOUNT");
        }
        Optional<Account> accOpt = accountRepository.findByAccountNumber(accountNo);
        if (accOpt.isEmpty()) {
            return TransactionResult.failure("01", "ACCOUNT NOT FOUND");
        }
        Account account = accOpt.get();
        if (account.getStatus() != AccountStatus.ACTIVE) {
            return TransactionResult.failure("04", "ACCOUNT INACTIVE");
        }
        if (account.getBalance().compareTo(amount) < 0) {
            return TransactionResult.failure("03", "INSUFFICIENT FUNDS");
        }

        account.setBalance(account.getBalance().subtract(amount));
        accountRepository.save(account);

        accountRepository.logTransaction(new TransactionRecord(
                UUID.randomUUID().toString(),
                "WITH",
                accountNo,
                null,
                amount,
                LocalDateTime.now(),
                "00",
                "WITHDRAWAL COMPLETED"
        ));

        return TransactionResult.success("WITHDRAWAL COMPLETED");
    }
}
