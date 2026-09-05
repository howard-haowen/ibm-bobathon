      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGICUS01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：查詢客戶 — 業務邏輯層                                   *
      *        驗證 COMMAREA、處理 MQ 路由旗標、呼叫 DB2 存取層       *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS LINK PROGRAM    → CALL ... USING BY REFERENCE     *
      *      COMMAREA LENGTH           RETURNING                       *
      *                                手冊 p.217 CALL Statement       *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC CICS ASKTIME /       → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME                手冊 p.190 Format 3             *
      *    EXEC CICS ReadQ TS        → ACCEPT FROM ENVIRONMENT         *
      *      (MQ 路由旗標讀取)         手冊 p.190 Format 5             *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    EIBTRNID/EIBTRMID/        → ACCEPT FROM ENVIRONMENT         *
      *      EIBTASKN                  手冊 p.190 Format 5             *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *      (無 USING)                BY REFERENCE DFHCOMMAREA        *
      *    WS-ADDR-DFHCOMMAREA /     → 移除（BY REFERENCE 自動處理）  *
      *      SET ... TO ADDRESS OF                                      *
      *    $IF 條件編譯              → ACUCOBOL 特有特性展示            *
      *                                手冊 p.30 Conditional Compilation*
      *    Level 78 常數             → ACUCOBOL 特有特性展示            *
      *                                手冊 p.34 $SET CONSTANT          *
      *                                                                *
      *  MQ 路由旗標說明：                                              *
      *    原始程式讀取 CICS TS Queue 'GENAWMQC' 判斷是否啟用 MQ 路由  *
      *    轉置後改為讀取環境變數 GENAPP_MQ_HIT                        *
      *    若值為 'MQHIT=1' 則路由至替代程式 AAAAAAAA                  *
      *    若未設定或值為其他，則正常呼叫 LGICDB01                     *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGICUS01.
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
                                        VALUE 'LGICUS01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存（ACCEPT FROM CENTURY-DATE / TIME 使用）
       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構（與原始格式一致，方便 LGSTSQ 日誌程式處理）     *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGICUS01'.
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
      *  MQ 路由控制                                                   *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *            ACCEPT dest FROM ENVIRONMENT env-name              *
      *  轉置說明：原始程式讀取 CICS TS Queue 'GENAWMQC' 的 MQ 旗標  *
      *            改為讀取環境變數 GENAPP_MQ_HIT                     *
      *----------------------------------------------------------------*
       01  MQ-ENV-FLAG                 PIC X(10)  VALUE SPACES.
       01  MQ-Hit                      PIC S9(4)  COMP VALUE 0.

      *  CALL RETURNING 接收 DB2 層回傳碼
       01  WS-DB-RETURN-CODE           PIC 9(2)   VALUE 0.

      *  LGPOLICY copybook 提供 WS-CUSTOMER-LEN 等 Level 78 常數
           COPY LGPOLICY.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

      *  轉置說明：原始以 DFHCOMMAREA + COPY LGCMAREA 宣告            *
      *  ACUCOBOL 以 BY REFERENCE 傳遞，PROCEDURE DIVISION USING 宣告 *
       01  DFHCOMMAREA.
               COPY LGCMAREA.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：加入 USING BY REFERENCE，明確宣告參數介面           *
      *  原始 IBM 版本依賴 CICS 隱性傳遞 DFHCOMMAREA                  *
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
      *  驗證 COMMAREA 已傳入（取代 EIBCALEN = ZERO 判斷）            *
      *  轉置說明：BY REFERENCE 確保非空，但仍保留防禦性檢查          *
      *----------------------------------------------------------------*
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
      *         轉置說明：取代 EXEC CICS ABEND ABCODE('LGCA')         *
               DISPLAY 'LGICUS01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

      *  初始化回傳碼
           MOVE '00' TO CA-RETURN-CODE
           MOVE '00' TO CA-NUM-POLICIES

      *----------------------------------------------------------------*
      *  COMMAREA 長度驗證                                             *
      *  轉置說明：WS-CUSTOMER-LEN 現為 Level 78 編譯期常數           *
      *            WS-CA-HEADER-LEN 亦為 Level 78 編譯期常數          *
      *----------------------------------------------------------------*
           COMPUTE WS-REQUIRED-CA-LEN =
               WS-CUSTOMER-LEN + WS-CA-HEADER-LEN

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
           END-IF

           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM

           PERFORM GET-CUSTOMER-INFO.

      *----------------------------------------------------------------*
      *  END PROGRAM                                                   *
      *----------------------------------------------------------------*
       MAINLINE-END.
      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *----------------------------------------------------------------*
      *  GET-CUSTOMER-INFO                                             *
      *                                                                *
      *  轉置說明：                                                     *
      *    原始以 EXEC CICS ReadQ TS 讀取 GENAWMQC 佇列判斷 MQ 旗標   *
      *    改為讀取環境變數 GENAPP_MQ_HIT                              *
      *    手冊依據：Reference Manual p.190 Format 5                  *
      *             ACCEPT dest FROM ENVIRONMENT env-name            *
      *                                                                *
      *    原始以 EXEC CICS LINK PROGRAM(LGICDB01) 呼叫 DB2 層       *
      *    改為 CALL 'LGICDB01' USING BY REFERENCE RETURNING         *
      *    手冊依據：Reference Manual p.217 CALL Statement           *
      *----------------------------------------------------------------*
       GET-CUSTOMER-INFO.

      *  讀取 MQ 路由旗標（取代 ReadQ TS GENAWMQC）
      *  手冊依據：Reference Manual p.190 Format 5
           MOVE SPACES TO MQ-ENV-FLAG
           ACCEPT MQ-ENV-FLAG FROM ENVIRONMENT 'GENAPP_MQ_HIT'
               ON EXCEPTION
                   MOVE SPACES TO MQ-ENV-FLAG
           END-ACCEPT

           MOVE 0 TO MQ-Hit
           IF MQ-ENV-FLAG(1:6) = 'MQHIT='
               MOVE 1 TO MQ-Hit
           END-IF

      *  路由邏輯（與原始行為一致）
           IF MQ-Hit = 0
      *         正常路徑：呼叫 DB2 存取層
      *         手冊依據：Reference Manual p.217 CALL Statement
      *                   BY REFERENCE 確保 COMMAREA 雙向共用
               CALL 'LGICDB01'
                   USING     BY REFERENCE DFHCOMMAREA
                   RETURNING WS-DB-RETURN-CODE
               END-CALL
           ELSE
      *         MQ 路由路徑：呼叫替代程式（保留原始行為）
      *         原始程式呼叫 'AAAAAAAA'（預留的 MQ 整合程式名稱）
               CALL 'AAAAAAAA'
                   USING     BY REFERENCE DFHCOMMAREA
                   RETURNING WS-DB-RETURN-CODE
               END-CALL
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
