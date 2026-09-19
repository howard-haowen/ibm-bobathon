# Minimal Banking System (Java Edition)

本系統為 IBM Bob 工作坊設計的極簡核心銀行系統（Java 現代化版本），用以替換傳統 Enterprise COBOL 示範，提供清楚易讀的 Java 物件導向與服務架構。

---

## 系統模組架構

```
src/main/java/com/ibm/banking/
├── BankingApplication.java              # 系統啟動與展示入口
├── model/
│   ├── Account.java                    # 帳戶實體模型 (帳號、戶名、餘額、狀態等)
│   ├── AccountStatus.java              # 帳戶狀態 (ACTIVE, FROZEN, CLOSED)
│   ├── TransactionRecord.java          # 交易日誌記錄
│   └── TransactionResult.java          # 交易返回結果 (00: 成功, 其他: 失敗碼與訊息)
├── repository/
│   └── AccountRepository.java          # 記憶體資料存取層 (取代傳統 DB2 SQL)
└── service/
    ├── AccountService.java             # 帳戶管理業務 (開戶、查詢)
    ├── InterestRateService.java        # 利率計算業務 (年利息、每日利息、閏年判斷)
    └── TransactionService.java         # 交易處理業務 (轉帳、存款、提款)
```

---

## 提供之銀行業務功能

| 業務代碼 | 業務名稱 | 對應 Java 方法 | 說明 |
|---|---|---|---|
| `CACCT` | 開立新帳戶 | `AccountService.openAccount(...)` | 建立新帳戶並記錄初始存款 |
| `QACCT` | 帳戶查詢 | `AccountService.getAccount(...)` | 依帳號查詢帳戶基本資料與餘額 |
| `XFER` | 帳戶間轉帳 | `TransactionService.transfer(...)` | 跨帳戶轉帳（含弱點情境） |
| `DEPO` | 存款 | `TransactionService.deposit(...)` | 存入指定金額至帳戶 |
| `WITH` | 提款 | `TransactionService.withdraw(...)` | 自指定帳戶提領金額 |
| `RATE` | 利息計算 | `InterestRateService.calculateAnnualInterest(...)` | 計算年利息與每日利息 |

---

## 刻意埋入的資安弱點 (SAST 演練)

- **檔案**：`src/main/java/com/ibm/banking/service/TransactionService.java`
- **弱點類型**：Incomplete Transaction / Workflow Inconsistency (**CWE-841**)
- **嚴重等級**：**Critical** (Checkmarx SAST 報告編號: `CX-2025-0714-001`)
- **說明**：在 `transfer()` 方法中，系統成功自來源帳戶扣款，但漏寫了目標帳戶的查詢驗證與金額存入邏輯，且缺少交易事務回滾機制，導致轉帳資金自系統中憑空消失。

---

## 如何在 macOS / Linux / Windows 執行

本系統使用標準 Java 17+ 開發，不依賴任何外部框架或資料庫。

### 1. 編譯
```bash
mkdir -p bin
javac -d bin $(find src/main/java -name "*.java")
```

### 2. 執行主程式
```bash
java -cp bin com.ibm.banking.BankingApplication
```
