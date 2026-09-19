package com.ibm.banking;

import com.ibm.banking.model.Account;
import com.ibm.banking.model.TransactionResult;
import com.ibm.banking.repository.AccountRepository;
import com.ibm.banking.service.AccountService;
import com.ibm.banking.service.InterestRateService;
import com.ibm.banking.service.TransactionService;

import java.math.BigDecimal;

public class BankingApplication {
    public static void main(String[] args) {
        System.out.println("=================================================");
        System.out.println("        IBM Minimal Banking System (Java)        ");
        System.out.println("=================================================");

        AccountRepository accountRepository = new AccountRepository();
        AccountService accountService = new AccountService(accountRepository);
        TransactionService transactionService = new TransactionService(accountRepository);
        InterestRateService interestRateService = new InterestRateService();

        System.out.println("\n[1] 初始帳戶狀態：");
        for (Account acc : accountRepository.findAll()) {
            System.out.println("  - " + acc.getAccountNumber() + " (" + acc.getCustomerName() + "): 餘額 = $" + acc.getBalance() + " [" + acc.getStatus() + "]");
        }

        System.out.println("\n[2] 執行轉帳操作 (Alice -> Bob: $2000.00)...");
        TransactionResult result = transactionService.transfer("ACCT000001", "ACCT000002", new BigDecimal("2000.00"));
        System.out.println("  - 交易結果: " + result);

        System.out.println("\n[3] 轉帳後帳戶狀態 (展示 CWE-841 弱點現象)：");
        Account alice = accountService.getAccount("ACCT000001").orElseThrow();
        Account bob = accountService.getAccount("ACCT000002").orElseThrow();
        System.out.println("  - 來源帳戶 Alice: 餘額 = $" + alice.getBalance() + " (已扣除 $2000.00)");
        System.out.println("  - 目標帳戶 Bob  : 餘額 = $" + bob.getBalance() + " (金額未增加！未入帳！)");

        System.out.println("\n[4] 利息計算測試 (本金 $10000, 年利率 3.5%):");
        BigDecimal annualInterest = interestRateService.calculateAnnualInterest(new BigDecimal("10000"), new BigDecimal("3.5"));
        BigDecimal dailyInterest = interestRateService.calculateDailyInterest(new BigDecimal("10000"), new BigDecimal("3.5"), 2024);
        System.out.println("  - 年利息: $" + annualInterest);
        System.out.println("  - 每日利息 (閏年 366 天): $" + dailyInterest);

        System.out.println("\n=================================================");
        System.out.println("  模擬完成！請使用 Checkmarx SAST 報告進行弱點修補。");
        System.out.println("=================================================");
    }
}
