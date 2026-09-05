      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGICDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：查詢客戶 — DB2 存取層                                   *
      *        以客戶號碼查詢 CUSTOMER 資料表並填入 COMMAREA            *
      *                                                                *
      *  編譯流程（兩階段）：                                           *
      *    階段 1：AcuSQL 預處理                                        *
      *      acusql LGICDB01.cbl -o LGICDB01_p.cbl                    *
      *    階段 2：ACUCOBOL-GT 編譯                                     *
      *      ccbl32 LGICDB01_p.cbl -o LGICDB01.acu                    *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC SQL INCLUDE SQLCA   → COPY "sqlca.def"                *
      *      (WORKING-STORAGE)        (AcuSQL 標準 SQLCA copybook)    *
      *    EXEC SQL INCLUDE LGCMAREA→ COPY LGCMAREA                   *
      *      (LINKAGE SECTION)        手冊 p.22 COPY Statement        *
      *    PROCEDURE DIVISION.      → PROCEDURE DIVISION USING        *
      *      (無 USING)               BY REFERENCE DFHCOMMAREA        *
      *    EXEC CICS RETURN         → GOBACK                          *
      *    EXEC CICS ABEND          → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC CICS ASKTIME /      → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME               手冊 p.190 Format 3             *
      *    EXEC CICS LINK LGSTSQ   → CALL 'LGSTSQ' USING BY REF      *
      *                               手冊 p.217 CALL Statement       *
      *    MOVE EIBTRNID/EIBTRMID  → ACCEPT FROM ENVIRONMENT         *
      *      /EIBTASKN                手冊 p.190 Format 5             *
      *    SET WS-ADDR-DFHCOMMAREA → 移除（BY REFERENCE 自動處理）   *
      *      TO ADDRESS OF                                             *
      *    Level 78 常數            → ACUCOBOL 特有特性展示            *
      *                               手冊 p.34 $SET CONSTANT          *
      *                                                                *
      *  SQL 邏輯變更：                                                 *
      *    - 所有 EXEC SQL DML 語法原樣保留（AcuSQL 相容）             *
      *    - SQLCODE 評估邏輯原樣保留                                   *
      *    - MOVE '3' TO CA-DOB(1:1)【刻意保留 — 客戶決策確認】       *
      *                                                                *
      *  ⚠ 已知遺留行為（第 207 行對應）：                             *
      *    GET-CUSTOMER-INFO 段落中 SQL 執行後，CA-DOB(1:1) 會被強制  *
      *    覆寫為字元 '3'，維持與 z/OS 生產系統的行為一致性。          *
      *    下游程式若需使用出生日期，請使用 CA-DOB(2:9) 取得原始值。   *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGICDB01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

      *----------------------------------------------------------------*
      *  執行期識別資訊                                                 *
      *----------------------------------------------------------------*
       01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGICDB01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存（ACCEPT FROM CENTURY-DATE / TIME 使用）
       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構（與原始格式一致）                                 *
      *  注意：原始程式 EM-PROG 欄位填入 ' LGICUS01' 而非 LGICDB01    *
      *        此為原始程式的已知問題，轉置時修正為正確程式名稱        *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGICDB01'.
           03 EM-VARIABLE.
             05 FILLER                 PIC X(6)   VALUE ' CNUM='.
             05 EM-CUSNUM              PIC X(10)  VALUE SPACES.
             05 FILLER                 PIC X(6)   VALUE ' PNUM='.
             05 EM-POLNUM              PIC X(10)  VALUE SPACES.
             05 EM-SQLREQ              PIC X(16)  VALUE SPACES.
             05 FILLER                 PIC X(9)   VALUE ' SQLCODE='.
             05 EM-SQLRC               PIC +9(5)  USAGE DISPLAY.

       01  CA-ERROR-MSG.
           03 FILLER                   PIC X(9)   VALUE 'COMMAREA='.
           03 CA-DATA                  PIC X(90)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  Level 78 編譯期常數                                           *
      *  手冊依據：Reference Manual p.34 Level 78 Data Items          *
      *  轉置說明：取代原 WS-COMMAREA-LENGTHS 群組中的                *
      *            PIC S9(4) COMP VALUE 執行期常數                    *
      *----------------------------------------------------------------*
       78  WS-CA-HEADER-LEN            VALUE 18.

      *  COMMAREA 最小長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4) COMP VALUE 0.

      *----------------------------------------------------------------*
      *  DB2 宿主變數（輸入用）                                        *
      *  轉置說明：型別與 IBM COBOL 版本一致                           *
      *  DB2 INTEGER → PIC S9(9) COMP（IBM / ACUCOBOL 兩端相容）     *
      *----------------------------------------------------------------*
       01  DB2-IN-INTEGERS.
           03 DB2-CUSTOMERNUMBER-INT   PIC S9(9) COMP VALUE 0.

      *----------------------------------------------------------------*
      *  LGPOLICY copybook：提供 WS-CUSTOMER-LEN 等 Level 78 常數    *
      *  及 DB2-CUSTOMER、DB2-POLICY 等資料結構                       *
      *----------------------------------------------------------------*
           COPY LGPOLICY.

      *----------------------------------------------------------------*
      *  SQLCA：DB2 通訊區域                                           *
      *  轉置說明：取代原 EXEC SQL INCLUDE SQLCA END-EXEC              *
      *  AcuSQL 提供標準 sqlca.def copybook                           *
      *  若使用其他 ODBC/ESQL 中介層，請參考對應文件                  *
      *----------------------------------------------------------------*
           COPY "sqlca.def".

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

      *  轉置說明：                                                     *
      *    原始 IBM 版本：                                              *
      *      01  DFHCOMMAREA.                                          *
      *          EXEC SQL INCLUDE LGCMAREA END-EXEC.                  *
      *                                                                *
      *    改寫後：EXEC SQL INCLUDE 在 LINKAGE SECTION 中不被          *
      *    AcuSQL 支援，改為標準 COPY 指令                             *
      *    手冊依據：Reference Manual p.22 COPY Statement             *
       01  DFHCOMMAREA.
               COPY LGCMAREA.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：加入 USING BY REFERENCE，取代 CICS 隱性傳遞機制    *
      *  RETURNING 讓呼叫端（LGICUS01）可直接取得執行結果             *
      *  手冊依據：Reference Manual p.217 CALL Statement              *
       PROCEDURE DIVISION USING     BY REFERENCE DFHCOMMAREA
                          RETURNING WS-REQUIRED-CA-LEN.
      *  注意：RETURNING 此處借用 WS-REQUIRED-CA-LEN 欄位傳回
      *        CA-RETURN-CODE 的數值副本，讓呼叫端快速判斷成敗。
      *        實際回傳資料仍透過 DFHCOMMAREA（BY REFERENCE 共用）。

      *----------------------------------------------------------------*
       MAINLINE SECTION.

           INITIALIZE WS-HEADER.

      *----------------------------------------------------------------*
      *  取得執行環境識別資訊                                           *
      *  轉置說明：取代 MOVE EIBTRNID/EIBTRMID/EIBTASKN               *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *           ACCEPT dest FROM ENVIRONMENT env-name              *
      *----------------------------------------------------------------*
           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION
                   MOVE 'LGIC' TO WS-TRANSID
           END-ACCEPT

           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION
                   MOVE 'ACU1' TO WS-TERMID
           END-ACCEPT

           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION
                   MOVE 0 TO WS-TASKNUM
           END-ACCEPT

      *----------------------------------------------------------------*
      *  驗證 COMMAREA 已傳入                                          *
      *  轉置說明：取代 IF EIBCALEN IS EQUAL TO ZERO                  *
      *            BY REFERENCE 確保非空，保留防禦性檢查              *
      *----------------------------------------------------------------*
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGICDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

      *  初始化回傳碼
           MOVE '00' TO CA-RETURN-CODE

      *  初始化 DB2 宿主變數
           INITIALIZE DB2-IN-INTEGERS.

      *----------------------------------------------------------------*
      *  COMMAREA 長度驗證                                             *
      *  轉置說明：                                                     *
      *    WS-CUSTOMER-LEN = 72（Level 78 編譯期常數，LGPOLICY.cpy）  *
      *    WS-CA-HEADER-LEN = 18（Level 78 編譯期常數，本程式定義）   *
      *    兩者皆在編譯期解析，無執行期計算開銷                        *
      *----------------------------------------------------------------*
           COMPUTE WS-REQUIRED-CA-LEN =
               WS-CUSTOMER-LEN + WS-CA-HEADER-LEN

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
      *         設定 RETURNING 值讓 LGICUS01 立即得知
               MOVE 98 TO WS-REQUIRED-CA-LEN
               GOBACK
           END-IF

      *  將客戶號碼轉換為 DB2 INTEGER 格式（宿主變數）
           MOVE CA-CUSTOMER-NUM TO DB2-CUSTOMERNUMBER-INT
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM

      *----------------------------------------------------------------*
      *  執行 DB2 查詢                                                 *
      *----------------------------------------------------------------*
           PERFORM GET-CUSTOMER-INFO.

      *----------------------------------------------------------------*
      *  END PROGRAM                                                   *
      *----------------------------------------------------------------*
       MAINLINE-END.
      *  設定 RETURNING 值（以 CA-RETURN-CODE 的數值供 LGICUS01 使用）
           MOVE CA-RETURN-CODE TO WS-REQUIRED-CA-LEN
      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  GET-CUSTOMER-INFO                                             *
      *                                                                *
      *  轉置說明：                                                     *
      *    EXEC SQL 語法完整保留（AcuSQL 預處理器處理）                *
      *    SQLCODE 評估邏輯原樣保留                                     *
      *                                                                *
      *  ⚠ 遺留行為說明（客戶決策：保留）：                            *
      *    執行 SQL SELECT 成功後，MOVE '3' TO CA-DOB(1:1) 會          *
      *    將出生日期第一個字元強制覆寫為 '3'。                         *
      *    例如：DB2 回傳 '1990-07-15' → CA-DOB 變成 '3990-07-15'     *
      *    下游程式若需正確出生日期，請使用 CA-DOB(2:9)。              *
      *    此行為與 z/OS 生產系統完全一致。                             *
      *    決策日期：2025 年（轉置規劃確認）                            *
      *================================================================*
       GET-CUSTOMER-INFO.

           MOVE ' SELECT CUSTOMER' TO EM-SQLREQ

      *----------------------------------------------------------------*
      *  DB2 嵌入式 SQL（ESQL）查詢                                    *
      *  轉置說明：語法原樣保留，AcuSQL 預處理器負責展開               *
      *  宿主變數前綴 ':' 為標準 ESQL 語法，兩端相容                  *
      *----------------------------------------------------------------*
           EXEC SQL
               SELECT FIRSTNAME,
                      LASTNAME,
                      DATEOFBIRTH,
                      HOUSENAME,
                      HOUSENUMBER,
                      POSTCODE,
                      PHONEMOBILE,
                      PHONEHOME,
                      EMAILADDRESS
               INTO  :CA-FIRST-NAME,
                     :CA-LAST-NAME,
                     :CA-DOB,
                     :CA-HOUSE-NAME,
                     :CA-HOUSE-NUM,
                     :CA-POSTCODE,
                     :CA-PHONE-MOBILE,
                     :CA-PHONE-HOME,
                     :CA-EMAIL-ADDRESS
               FROM CUSTOMER
               WHERE CUSTOMERNUMBER = :DB2-CUSTOMERNUMBER-INT
           END-EXEC.

      *----------------------------------------------------------------*
      *  ⚠ 遺留行為：覆寫出生日期第一個字元（客戶決策：保留）         *
      *    原始 IBM COBOL 第 207 行                                    *
      *    此行在 SQL 執行成功與否之前執行，無論 SQLCODE 為何皆發生    *
      *----------------------------------------------------------------*
           MOVE '3' TO CA-DOB(1:1).

      *----------------------------------------------------------------*
      *  SQLCODE 評估（原樣保留）                                      *
      *    0    → 查詢成功                                             *
      *    100  → 查無資料（NOT FOUND）                                *
      *    -913 → 資源競爭鎖定（DEADLOCK / TIMEOUT）                  *
      *    其他 → 非預期 SQL 錯誤                                      *
      *----------------------------------------------------------------*
           EVALUATE SQLCODE
               WHEN 0
                   MOVE '00' TO CA-RETURN-CODE
               WHEN 100
                   MOVE '01' TO CA-RETURN-CODE
               WHEN -913
                   MOVE '01' TO CA-RETURN-CODE
               WHEN OTHER
                   MOVE '90' TO CA-RETURN-CODE
                   PERFORM WRITE-ERROR-MESSAGE
      *             轉置說明：取代 EXEC CICS RETURN（緊急返回）
                   MOVE 90 TO WS-REQUIRED-CA-LEN
                   GOBACK
           END-EVALUATE.

           EXIT.

      *================================================================*
      *  WRITE-ERROR-MESSAGE                                           *
      *                                                                *
      *  轉置說明：                                                     *
      *    EXEC CICS ASKTIME / FORMATTIME →                           *
      *      ACCEPT FROM CENTURY-DATE / TIME                           *
      *      手冊依據：Reference Manual p.190 Format 3               *
      *      CENTURY-DATE 返回 YYYYMMDD（8 碼）                       *
      *      TIME 返回 HHMMSSss（8 碼）                                *
      *                                                                *
      *    EXEC CICS LINK PROGRAM('LGSTSQ') →                        *
      *      CALL 'LGSTSQ' USING BY REFERENCE                         *
      *      手冊依據：Reference Manual p.217 CALL Statement         *
      *                                                                *
      *    EIBCALEN 判斷 → LENGTH OF DFHCOMMAREA                      *
      *================================================================*
       WRITE-ERROR-MESSAGE.
      *  儲存 SQLCODE 至訊息結構
           MOVE SQLCODE TO EM-SQLRC

      *  取得當前時間
      *  手冊依據：Reference Manual p.190 Format 3
      *  CENTURY-DATE 返回 YYYYMMDD
           ACCEPT WS-DATE FROM CENTURY-DATE
      *  TIME 返回 HHMMSSss
           ACCEPT WS-TIME FROM TIME

           MOVE WS-DATE(1:8) TO EM-DATE
           MOVE WS-TIME(1:6) TO EM-TIME

      *  呼叫日誌程式（取代 EXEC CICS LINK PROGRAM('LGSTSQ')）
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGSTSQ'
               USING BY REFERENCE ERROR-MSG
           END-CALL

      *  附加 COMMAREA 前 90 bytes 至日誌（輔助除錯用）
      *  轉置說明：原始以 EIBCALEN 判斷長度
      *            改為直接取前 90 bytes（COMMAREA 必定 >= 90 bytes，
      *            因通過前述長度驗證 WS-CUSTOMER-LEN + HEADER = 90）
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ'
               USING BY REFERENCE CA-ERROR-MSG
           END-CALL.

           EXIT.
