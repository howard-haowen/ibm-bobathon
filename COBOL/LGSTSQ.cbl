      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGSTSQ.cbl (IBM COBOL / CICS / z/OS)               *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：接收錯誤訊息並寫入日誌檔（取代 CICS TDQ/TSQ 輸出）     *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                → ACUCOBOL-GT 替代                  *
      *    ─────────────────────────────────────────────────────────  *
      *    EXEC CICS ASSIGN SYSID  → ACCEPT FROM ENVIRONMENT           *
      *      / INVOKINGPROG / etc.   手冊 p.190 Format 5              *
      *    EXEC CICS WRITEQ TD     → WRITE 循序日誌檔                 *
      *    EXEC CICS WRITEQ TS     → WRITE 循序日誌檔（同一目標）     *
      *    EXEC CICS RECEIVE       → ACCEPT（移除，本版本僅支援       *
      *                              CALL 呼叫模式，非終端輸入）       *
      *    EXEC CICS SEND TEXT     → DISPLAY WINDOW ERASE              *
      *                              手冊 p.239 DISPLAY WINDOW         *
      *    EXEC CICS RETURN        → GOBACK                            *
      *                                                                *
      *  呼叫介面：                                                     *
      *    CALL 'LGSTSQ' USING BY REFERENCE LOG-MESSAGE                *
      *    其中 LOG-MESSAGE 為 PIC X(90) 的訊息字串                   *
      *                                                                *
      *  日誌檔路徑由環境變數 GENAPP_LOG_FILE 控制                    *
      *  預設值：genapp.log（位於執行目錄）                            *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGSTSQ.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      *----------------------------------------------------------------*
      *  日誌檔定義（LINE SEQUENTIAL = 文字模式，跨平台相容）          *
      *----------------------------------------------------------------*
           SELECT LOG-FILE
               ASSIGN TO DYNAMIC WS-LOG-PATH
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-LOG-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  LOG-FILE.
       01  LOG-RECORD                  PIC X(100).

       WORKING-STORAGE SECTION.

       01  WS-LOG-PATH                 PIC X(256) VALUE 'genapp.log'.
       01  WS-LOG-STATUS               PIC XX     VALUE SPACES.
       01  WS-SYSID                    PIC X(4)   VALUE SPACES.
       01  WS-INVOKEPROG               PIC X(8)   VALUE SPACES.
       01  WS-TIMESTAMP                PIC X(26)  VALUE SPACES.
       01  WS-DATE-8                   PIC X(8)   VALUE SPACES.
       01  WS-TIME-8                   PIC X(8)   VALUE SPACES.
      *
      *  輸出記錄格式：[日期 時間] [呼叫程式 ] 訊息內容
       01  WS-LOG-ENTRY.
           03 WS-LE-DATE               PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 WS-LE-TIME               PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 WS-LE-PROG               PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 WS-LE-MSG                PIC X(90)  VALUE SPACES.
      *
       01  WS-OPEN-FLAG                PIC X      VALUE 'N'.
           88  LOG-IS-OPEN             VALUE 'Y'.
           88  LOG-IS-CLOSED           VALUE 'N'.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.
      *  呼叫端傳入 90 bytes 訊息（與原 CICS COMMAREA 尺寸一致）
       01  DFHCOMMAREA.
           03  COMMA-DATA              PIC X(90).

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

       MAINLINE SECTION.
      *----------------------------------------------------------------*
      *  步驟 1：取得執行環境資訊                                      *
      *  手冊依據：Reference Manual p.190 Format 5                     *
      *           ACCEPT dest FROM ENVIRONMENT env-name               *
      *----------------------------------------------------------------*
           MOVE SPACES TO WS-SYSID
           MOVE SPACES TO WS-INVOKEPROG

           ACCEPT WS-SYSID FROM ENVIRONMENT 'GENAPP_SYSID'
               ON EXCEPTION
                   MOVE 'SYS1' TO WS-SYSID
           END-ACCEPT

           ACCEPT WS-INVOKEPROG FROM ENVIRONMENT 'GENAPP_INVOKING_PROG'
               ON EXCEPTION
                   MOVE 'UNKNOWN ' TO WS-INVOKEPROG
           END-ACCEPT

      *  讀取日誌檔路徑（可由環境變數覆蓋預設值）
           ACCEPT WS-LOG-PATH FROM ENVIRONMENT 'GENAPP_LOG_FILE'
               ON EXCEPTION
                   MOVE 'genapp.log' TO WS-LOG-PATH
           END-ACCEPT

      *----------------------------------------------------------------*
      *  步驟 2：取得當前時間戳記                                      *
      *  手冊依據：Reference Manual p.190 Format 3                     *
      *           ACCEPT dest FROM CENTURY-DATE / TIME                *
      *----------------------------------------------------------------*
      *  CENTURY-DATE 返回 YYYYMMDD（8 碼）
           ACCEPT WS-DATE-8 FROM CENTURY-DATE
      *  TIME 返回 HHMMSSss（8 碼）
           ACCEPT WS-TIME-8 FROM TIME

      *----------------------------------------------------------------*
      *  步驟 3：組裝日誌記錄                                          *
      *----------------------------------------------------------------*
           MOVE WS-DATE-8    TO WS-LE-DATE
           MOVE WS-TIME-8    TO WS-LE-TIME
           MOVE WS-INVOKEPROG TO WS-LE-PROG
           MOVE COMMA-DATA   TO WS-LE-MSG

      *----------------------------------------------------------------*
      *  步驟 4：開啟日誌檔並寫入（EXTEND = 附加模式）                *
      *----------------------------------------------------------------*
           OPEN EXTEND LOG-FILE
           IF WS-LOG-STATUS NOT = '00'
               OPEN OUTPUT LOG-FILE
           END-IF

           MOVE WS-LOG-ENTRY TO LOG-RECORD
           WRITE LOG-RECORD
           CLOSE LOG-FILE

      *----------------------------------------------------------------*
      *  步驟 5：若為獨立呼叫模式（非 CALL），清除螢幕                *
      *  手冊依據：Reference Manual p.239 DISPLAY WINDOW              *
      *           （保留原 EXEC CICS SEND TEXT ERASE 的語意）         *
      *----------------------------------------------------------------*
           IF WS-INVOKEPROG = SPACES OR WS-INVOKEPROG = 'UNKNOWN '
               DISPLAY WINDOW ERASE
           END-IF

       MAINLINE-END.
           GOBACK.

       A-EXIT.
           EXIT.
