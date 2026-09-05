      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGACUS01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：新增客戶 — 業務邏輯層                                   *
      *        驗證 COMMAREA、執行郵遞區號與詐欺檢查、呼叫 DB2 新增層  *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS LINK PROGRAM    → CALL ... USING BY REFERENCE     *
      *                                RETURNING                       *
      *                                手冊 p.217 CALL Statement       *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC CICS ASKTIME /       → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME                手冊 p.190 Format 3             *
      *    EIBTRNID/EIBTRMID/        → ACCEPT FROM ENVIRONMENT         *
      *      EIBTASKN                  手冊 p.190 Format 5             *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除（BY REFERENCE 自動處理）  *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *      (無 USING)                BY REFERENCE DFHCOMMAREA        *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE      手冊 p.34 Level 78 Data Items   *
      *    77 LGACDB01/LGACVS01/     → 移除（CALL literal 直接使用）  *
      *       ATRANID                                                   *
      *    CALL JAVA USING LGACJV01  → 純 COBOL 手機號碼長度檢查       *
      *      (詐欺檢查)                移除 Java interop                *
      *    CALL JAVA USING LGACJV02  → CHECK-FIRST-COBOL（已存在）     *
      *      (郵遞區號 Java 版)        Java 版本完整移除                *
      *                                                                *
      *  ACUCOBOL-GT 特有特性展示：                                     *
      *    特性 A：$IF/$SET/$END 條件編譯（p.30-34）                   *
      *            用於切換詐欺檢查模式（COBOL / 外部服務預留）         *
      *    特性 B：ACCEPT FROM CENTURY-DATE / TIME（p.190 Format 3）   *
      *    特性 C：ACCEPT FROM ENVIRONMENT（p.190 Format 5）           *
      *    特性 D：Level 78 編譯期常數（p.34）                         *
      *    特性 E：CALL ... USING BY REFERENCE RETURNING（p.217）      *
      *                                                                *
      *  Java Interop 說明：                                            *
      *    原始程式有兩處 CALL JAVA：                                   *
      *      1. LGACJV01：手機號碼詐欺檢查                             *
      *         轉置後：純 COBOL 實作（檢查長度 >= 7）                 *
      *      2. LGACJV02：郵遞區號格式檢查（Java 版）                  *
      *         原始已有 CHECK-FIRST-COBOL 備選版本                    *
      *         轉置後：CHECK-FIRST-JAVA 段落整個移除，                *
      *         直接呼叫 CHECK-FIRST-COBOL 版本                        *
      *    $IF FRAUD-COBOL-MODE 旗標可切換詐欺檢查實作路徑             *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGACUS01.
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
                                        VALUE 'LGACUS01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存（ACCEPT FROM CENTURY-DATE / TIME 使用）
       01  WS-ABSTIME                  PIC S9(8) COMP VALUE +0.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.
       01  WS-DATE                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGACUS01'.
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
      *  轉置說明：取代 WS-COMMAREA-LENGTHS 群組中的執行期常數        *
      *----------------------------------------------------------------*
       78  WS-CA-HEADER-LEN            VALUE 18.

      *  COMMAREA 長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *  LGPOLICY copybook 提供 WS-CUSTOMER-LEN 等 Level 78 常數
           COPY LGPOLICY.

      *----------------------------------------------------------------*
      *  業務邏輯回應結構                                               *
      *----------------------------------------------------------------*
       01  WS-RESPONSE.
           03 WS-RESPONSE-CODE         PIC 9(2)   VALUE 0.
           03 WS-RESPONSE-MESSAGE      PIC X(78)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  詐欺檢查旗標                                                   *
      *  轉置說明：取代 CALL JAVA USING LGACJV01 的 WS-STATUS 欄位    *
      *  原始回傳值 'valid' / 'error'，改為 PIC X(5)                  *
      *----------------------------------------------------------------*
       01  WS-STATUS                   PIC X(5)   VALUE SPACES.

      *  CALL RETURNING 接收 DB2 層回傳碼
       01  WS-DB-RETURN-CODE           PIC 9(2)   VALUE 0.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

       01  DFHCOMMAREA.
               COPY LGCMAREA.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：加入 USING BY REFERENCE
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *----------------------------------------------------------------*
       MAINLINE SECTION.

           INITIALIZE WS-HEADER.

      *----------------------------------------------------------------*
      *  取得執行環境識別資訊                                           *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *----------------------------------------------------------------*
           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION
                   MOVE 'LGAC' TO WS-TRANSID
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
      *  驗證 COMMAREA 已傳入（取代 EIBCALEN IS EQUAL TO ZERO）       *
      *----------------------------------------------------------------*
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGACUS01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

      *  初始化回傳碼
           MOVE '00' TO CA-RETURN-CODE
           MOVE '00' TO CA-NUM-POLICIES

      *----------------------------------------------------------------*
      *  COMMAREA 長度驗證                                             *
      *  WS-CUSTOMER-LEN 與 WS-CA-HEADER-LEN 皆為 Level 78 編譯期常數 *
      *----------------------------------------------------------------*
           ADD WS-CA-HEADER-LEN TO WS-REQUIRED-CA-LEN
           ADD WS-CUSTOMER-LEN  TO WS-REQUIRED-CA-LEN

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
             MOVE '98' TO CA-RETURN-CODE
             GOBACK
           END-IF

      *----------------------------------------------------------------*
      *  步驟 1：郵遞區號格式檢查                                      *
      *  轉置說明：原始 CHECK-FIRST 可呼叫 COBOL 或 Java 版本          *
      *    CHECK-FIRST-JAVA（CALL JAVA USING LGACJV02）→ 完整移除      *
      *    CHECK-FIRST-COBOL 已有完整純 COBOL 實作 → 直接 PERFORM      *
      *----------------------------------------------------------------*
           PERFORM CHECK-FIRST
           IF WS-RESPONSE-CODE > 0
             MOVE WS-RESPONSE-CODE TO CA-RETURN-CODE
             DISPLAY WS-RESPONSE-MESSAGE
             GOBACK
           END-IF

      *----------------------------------------------------------------*
      *  步驟 2：詐欺檢查（手機號碼驗證）                              *
      *  轉置說明：取代 CALL JAVA USING LGACJV01 + WS-STATUS 回傳     *
      *  改為純 COBOL 實作（手機號碼長度 >= 7 視為有效）               *
      *  $IF 條件編譯用於示範如何切換實作路徑（特性 A）               *
      *----------------------------------------------------------------*
           PERFORM FRAUD-CHECK
           IF WS-STATUS NOT = 'valid'
             MOVE '81' TO CA-RETURN-CODE
             GOBACK
           END-IF

      *----------------------------------------------------------------*
      *  步驟 3：新增客戶至 DB2                                        *
      *----------------------------------------------------------------*
           PERFORM INSERT-CUSTOMER
           IF CA-RETURN-CODE > 0
             GOBACK
           END-IF

      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  FRAUD-CHECK                                                   *
      *                                                                *
      *  轉置說明：取代 CALL JAVA USING LGACJV01                      *
      *    原始：呼叫 Java 程式以手機號碼進行詐欺黑名單查詢            *
      *    轉置：純 COBOL 實作，以號碼長度作為基本有效性判斷           *
      *                                                                *
      *  特性 A 展示：$IF/$SET/$END 條件編譯                           *
      *  手冊依據：Reference Manual p.30-34                           *
      *  $SET FRAUD-COBOL-MODE 以 ccbl32 -Dconstant=value 設定。      *
      *    若未定義（預設）→ 執行純 COBOL 手機號碼長度檢查             *
      *    若定義為 'EXT' → 可替換為外部 REST 服務呼叫（預留擴展點）  *
      *================================================================*
       FRAUD-CHECK.
      *----------------------------------------------------------------*
      $IF FRAUD-COBOL-MODE NOT DEFINED
      *  預設模式：純 COBOL 手機號碼基本驗證
      *  邏輯：去除空白後長度 >= 7 視為有效
           IF FUNCTION LENGTH(
                   FUNCTION TRIM(CA-PHONE-MOBILE LEADING)) >= 7
               MOVE 'valid' TO WS-STATUS
           ELSE
               MOVE 'error' TO WS-STATUS
               DISPLAY 'LGACUS01: FRAUD-CHECK FAILED - '
                       'PHONE TOO SHORT: ' CA-PHONE-MOBILE
           END-IF
      $ELSE
      *  擴展模式：預留外部詐欺檢查服務呼叫點
      *  轉置說明：此路徑於生產前可替換為 REST/gRPC 服務介面
           MOVE 'valid' TO WS-STATUS
      $END
      *----------------------------------------------------------------*
       FRAUD-CHECK-EXIT.
           EXIT.

      *================================================================*
      *  CHECK-FIRST                                                   *
      *  郵遞區號格式檢查路由（原始邏輯保留）                          *
      *  轉置說明：CHECK-FIRST-JAVA 段落已移除（Java interop 移除）   *
      *    直接呼叫 CHECK-FIRST-COBOL                                  *
      *================================================================*
       CHECK-FIRST.
      *  轉置說明：原始 PERFORM CHECK-FIRST-JAVA 已移除
      *            直接呼叫純 COBOL 版本
           PERFORM CHECK-FIRST-COBOL.
       CHECK-FIRST-EXIT.
           EXIT.

      *================================================================*
      *  CHECK-FIRST-COBOL                                             *
      *  郵遞區號格式驗證（純 COBOL 實作，原始邏輯原樣保留）          *
      *  支援 GB / US / UK / DN 前綴                                   *
      *================================================================*
       CHECK-FIRST-COBOL.
           MOVE '00' TO WS-RESPONSE-CODE
           MOVE SPACES TO WS-RESPONSE-MESSAGE
           IF FUNCTION UPPER-CASE (CA-POSTCODE(1:2)) = 'GB'
               CONTINUE
           ELSE IF FUNCTION UPPER-CASE (CA-POSTCODE(1:2)) = 'US'
               CONTINUE
           ELSE IF FUNCTION UPPER-CASE (CA-POSTCODE(1:2)) = 'UK'
               CONTINUE
           ELSE IF FUNCTION UPPER-CASE (CA-POSTCODE(1:2)) = 'DN'
               CONTINUE
           ELSE
               MOVE '82' TO WS-RESPONSE-CODE
               STRING 'Invalid postcode: ' CA-POSTCODE
                DELIMITED BY SIZE INTO WS-RESPONSE-MESSAGE
           END-IF.
       CHECK-FIRST-COBOL-EXIT.
           EXIT.

      *================================================================*
      *  INSERT-CUSTOMER                                               *
      *  呼叫 DB2 新增層（LGACDB01）                                   *
      *  轉置說明：                                                     *
      *    原始僅在 WS-STATUS = 'valid' 時執行 CICS LINK              *
      *    WS-STATUS = 'error' 時 ABEND                                *
      *    轉置後：FRAUD-CHECK 已確保 WS-STATUS 為 'valid'             *
      *    （error 在 MAINLINE 已 GOBACK）                             *
      *    故此段落直接執行 CALL，ABEND 轉為 DISPLAY + STOP RUN       *
      *================================================================*
       INSERT-CUSTOMER.
           IF WS-STATUS = 'valid'
      *         手冊依據：Reference Manual p.217 CALL Statement
               CALL 'LGACDB01'
                   USING     BY REFERENCE DFHCOMMAREA
                   RETURNING WS-DB-RETURN-CODE
               END-CALL
           ELSE IF WS-STATUS = 'error'
      *         轉置說明：取代 EXEC CICS ABEND ABCODE('CUSE')
               DISPLAY 'LGACUS01: ABEND - FRAUD STATUS ERROR'
                   UPON SYSERR
               STOP RUN
           END-IF.
           EXIT.

      *================================================================*
      *  WRITE-ERROR-MESSAGE                                           *
      *                                                                *
      *  轉置說明：                                                     *
      *    EXEC CICS ASKTIME / FORMATTIME →                           *
      *      ACCEPT FROM CENTURY-DATE / TIME                           *
      *      手冊依據：Reference Manual p.190 Format 3               *
      *                                                                *
      *    EXEC CICS LINK PROGRAM('LGSTSQ') →                        *
      *      CALL 'LGSTSQ' USING BY REFERENCE                         *
      *      手冊依據：Reference Manual p.217 CALL Statement         *
      *================================================================*
       WRITE-ERROR-MESSAGE.
      *  手冊依據：Reference Manual p.190 Format 3
           ACCEPT WS-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME FROM TIME

           MOVE WS-DATE(1:8) TO EM-DATE
           MOVE WS-TIME(1:6) TO EM-TIME

      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGSTSQ'
               USING BY REFERENCE ERROR-MSG
           END-CALL

           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ'
               USING BY REFERENCE CA-ERROR-MSG
           END-CALL.

           EXIT.
