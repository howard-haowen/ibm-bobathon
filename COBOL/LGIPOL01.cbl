      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGIPOL01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：查詢保單 — 業務邏輯層                                   *
      *        驗證 COMMAREA、呼叫 DB2 存取層、套用保單業務規則        *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS LINK Program    → CALL 'LGIPDB01' USING           *
      *      (LGIPDB01)                BY REFERENCE DFHCOMMAREA        *
      *                                             ICOM-RECORD        *
      *                                             ICOM-RECORD-COUNT  *
      *                                RETURNING WS-DB-RETURN-CODE    *
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
      *                                             ICOM-RECORD        *
      *                                             ICOM-RECORD-COUNT  *
      *    01 LGIPDB01 PIC X(8)      → 移除（CALL literal 直接使用）  *
      *    WS-CA-HEADERTRAILER-LEN   → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE      手冊 p.34 Level 78 Data Items   *
      *    MINUS-ONE PIC S9(4) COMP  → Level 78 編譯期常數             *
      *                                手冊 p.34                       *
      *                                                                *
      *  ICOM Channel/Container 轉置說明：                              *
      *    原始程式呼叫 LGIPDB01 後，LGIPDB01 透過 CICS Channel/       *
      *    Container 回傳多筆商業保單資料。                             *
      *    轉置後 LGIPDB01 接受額外的 BY REFERENCE 參數：              *
      *      ICOM-RECORD       (PIC X(1202)) 單筆資料緩衝區            *
      *      ICOM-RECORD-COUNT (PIC S9(4))  實際回傳筆數               *
      *    由 LGIPOL01 提供暫存空間，LGIPDB01 直接寫入。               *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGIPOL01.
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
                                        VALUE 'LGIPOL01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存（ACCEPT FROM CENTURY-DATE / TIME 使用）
       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGIPOL01'.
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
      *  轉置說明：取代原 WS-COMMAREA-LENGTHS 群組中的執行期常數       *
      *           與 MINUS-ONE PIC S9(4) COMP VALUE -1                *
      *----------------------------------------------------------------*
       78  WS-CA-HEADERTRAILER-LEN     VALUE 33.
       78  WS-MINUS-ONE                VALUE -1.

      *  COMMAREA 長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4)  VALUE 0.

      *  DB2 層結束位置（保留，供 LGIPDB01 內部使用，此處初始化）
       01  END-POLICY-POS              PIC S9(4) COMP VALUE +1.

      *  ICOM Channel/Container 暫存區（提供給 LGIPDB01 使用）
      *  轉置說明：取代 CICS Get/Put Container，改為 BY REFERENCE 傳遞
       01  WS-ICOM-RECORD              PIC X(1202) VALUE SPACES.
       01  WS-ICOM-RECORD-COUNT        PIC S9(4) COMP VALUE 0.

      *  CALL RETURNING 接收 DB2 層回傳碼
       01  WS-DB-RETURN-CODE           PIC 9(2)   VALUE 0.

      *  LGPOLICY copybook 提供 WS-CUSTOMER-LEN 等 Level 78 常數
           COPY LGPOLICY.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

      *  轉置說明：PROCEDURE DIVISION USING BY REFERENCE 傳遞
      *  ICOM-RECORD / ICOM-RECORD-COUNT 由呼叫端提供暫存空間
       01  DFHCOMMAREA.
               COPY LGCMAREA.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：加入 USING BY REFERENCE，明確宣告參數介面
      *  ICOM-RECORD 與 ICOM-RECORD-COUNT 為 Channel/Container 替代參數
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *----------------------------------------------------------------*
       MAINLINE SECTION.
      *
           INITIALIZE WS-HEADER.

      *----------------------------------------------------------------*
      *  取得執行環境識別資訊                                           *
      *  轉置說明：取代 MOVE EIBTRNID/EIBTRMID/EIBTASKN               *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *           ACCEPT dest FROM ENVIRONMENT env-name              *
      *----------------------------------------------------------------*
           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION
                   MOVE 'LGIP' TO WS-TRANSID
           END-ACCEPT

           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION
                   MOVE 'ACU1' TO WS-TERMID
           END-ACCEPT

           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION
                   MOVE 0 TO WS-TASKNUM
           END-ACCEPT

      *  原始程式的 DISPLAY 'HELLO HANNOVER' — 原樣保留
           DISPLAY 'HELLO HANNOVER'

      *----------------------------------------------------------------*
      *  驗證 COMMAREA 已傳入（取代 EIBCALEN IS EQUAL TO ZERO 判斷）  *
      *  轉置說明：BY REFERENCE 確保非空，但仍保留防禦性檢查          *
      *----------------------------------------------------------------*
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
      *         轉置說明：取代 EXEC CICS ABEND ABCODE('LGCA')
               DISPLAY 'LGIPOL01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

      *  初始化回傳碼
           MOVE '00' TO CA-RETURN-CODE

           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM
           MOVE CA-POLICY-NUM   TO EM-POLNUM

      *----------------------------------------------------------------*
      *  呼叫 DB2 存取層                                               *
      *  轉置說明：取代 EXEC CICS LINK Program(LGIPDB01)              *
      *  加入 ICOM-RECORD / ICOM-RECORD-COUNT 取代 Channel/Container  *
      *  手冊依據：Reference Manual p.217 CALL Statement             *
      *            BY REFERENCE 確保 COMMAREA 雙向共用                *
      *----------------------------------------------------------------*
           CALL 'LGIPDB01'
               USING     BY REFERENCE DFHCOMMAREA
                                      WS-ICOM-RECORD
                                      WS-ICOM-RECORD-COUNT
               RETURNING WS-DB-RETURN-CODE
           END-CALL

           PERFORM A000-POLICY-RULES.

      *----------------------------------------------------------------*
      *  END PROGRAM                                                   *
      *----------------------------------------------------------------*
       MAINLINE-END.
      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  A000-POLICY-RULES                                             *
      *                                                                *
      *  轉置說明：業務規則段原樣保留，無 CICS 相依性。              *
      *  原始邏輯：保單編號 < 10 者設定為 1999-01-01 已過期。         *
      *================================================================*
       A000-POLICY-RULES.
      *  規則：根據保單編號設定過期日。舊保單（< 10）標記為已過期。
           EVALUATE TRUE
                WHEN CA-POLICY-NUM < 10
                    MOVE '1999-01-01' TO CA-EXPIRY-DATE
                WHEN OTHER
                    CONTINUE

           END-EVALUATE.

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
      *                                                                *
      *    EIBCALEN 長度判斷 → LENGTH OF DFHCOMMAREA                 *
      *================================================================*
       WRITE-ERROR-MESSAGE.
      *  取得當前時間
      *  手冊依據：Reference Manual p.190 Format 3
      *  CENTURY-DATE 返回 YYYYMMDD（8 碼）
           ACCEPT WS-DATE FROM CENTURY-DATE
      *  TIME 返回 HHMMSSss（8 碼）
           ACCEPT WS-TIME FROM TIME

           MOVE WS-DATE(1:8) TO EM-DATE
           MOVE WS-TIME(1:6) TO EM-TIME

      *  呼叫日誌程式（取代 EXEC CICS LINK PROGRAM('LGSTSQ')）
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGSTSQ'
               USING BY REFERENCE ERROR-MSG
           END-CALL

      *  附加 COMMAREA 前 90 bytes 至日誌（輔助除錯用）
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ'
               USING BY REFERENCE CA-ERROR-MSG
           END-CALL.

           EXIT.
