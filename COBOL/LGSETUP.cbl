      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGSETUP.cbl (IBM COBOL / CICS / z/OS)              *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：環境初始化                                               *
      *        初始化客戶流水號計數器、所有統計計數器、日誌 TS Queue   *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS RECEIVE INTO   → ACCEPT FROM ENVIRONMENT          *
      *      (取得初始客戶號)         'GENAPP_INITIAL_CUSTNUM'         *
      *    EXEC CICS DeleteQ TS     → 循序日誌檔清除（跳過，啟動時    *
      *      (STSQ-ERRS/STRT/STAT)    重新開啟日誌檔即可）            *
      *    EXEC CICS WriteQ TS      → LINE SEQUENTIAL WRITE            *
      *      (STSQ-NAME)                                               *
      *    EXEC CICS Delete/Define  → 初始化 IS EXTERNAL 計數陣列     *
      *      Counter（26 組）         手冊 p.90 IS EXTERNAL Clause     *
      *    EXEC CICS SEND TEXT      → DISPLAY                          *
      *    EXEC CICS RETURN         → STOP RUN                         *
      *    PROCEDURE DIVISION.      → PROCEDURE DIVISION（無 USING）  *
      *      (無 USING)               LGSETUP 為頂層初始化程式         *
      *                                                                *
      *  IS EXTERNAL 計數陣列設計：                                    *
      *    原始程式以 CICS Named Counter Service（NCS）維護 27 個計數器*
      *    （GENACUSTNUM + GENACNT100~GENACNTI99）。                   *
      *    轉置後改為 IS EXTERNAL 的計數陣列，由 LGSETUP 初始化，     *
      *    LGASTAT1 / LGWEBST5 讀取，LGACDB01 遞增客戶號計數器。      *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGSETUP.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      *  轉置說明：取代 CICS WriteQ TS QUEUE(STSQ-NAME) 日誌寫入
           SELECT GENAPP-LOG ASSIGN TO ENVIRONMENT 'GENAPP_LOG_FILE'
               ORGANIZATION IS LINE SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD GENAPP-LOG.
       01 LOG-RECORD                   PIC X(80).

       WORKING-STORAGE SECTION.

       01  WS-FILE-STATUS              PIC X(2)   VALUE '00'.

      *  環境初始化輸入（取代 EXEC CICS RECEIVE）
       01  WS-RECV-DATA                PIC X(74)  VALUE SPACES.

      *  統計 Queue 暫存區（原始邏輯保留）
       01  WS-QAREA.
           03  WS-AREA-D               PIC X(8)   VALUE SPACES.
           03  FILLER                  PIC XX     VALUE SPACES.
           03  WS-AREA-T               PIC X(6)   VALUE SPACES.

      *  日誌輸出訊息
       01  WRITE-MSG.
           03 WRITE-MSG-E              PIC X(20) VALUE '**** GENAPP CNTL'.
           03 WRITE-MSG-L              PIC X(13) VALUE 'LOW CUSTOMER='.
           03 WRITE-MSG-LOW            PIC 9(10).
           03 FILLER                   PIC X.
           03 WRITE-MSG-H              PIC X(14) VALUE 'HIGH CUSTOMER='.
           03 WRITE-MSG-HIGH           PIC 9(10).
           03 FILLER                   PIC X(60).

       01  FrstCustNum                 PIC S9(8)  VALUE +1.
       01  LastCustNum                 PIC S9(8)  VALUE +11 COMP.

       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  IS EXTERNAL 計數陣列                                          *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *  轉置說明：取代 27 組 EXEC CICS Delete/Define Counter         *
      *                                                                *
      *  索引對應（與 LGWEBST5 的 GENACNT* 名稱一致）：              *
      *    (1)  GENA-CUSTNUM      ← GENACUSTNUM（客戶流水號）         *
      *    (2)  GENACNT100        ← GENA01ICUS00（查詢客戶成功）     *
      *    (3)  GENACNT199        ← GENA01ICUS99（查詢客戶失敗）     *
      *    (4)  GENACNT200        ← GENA01ACUS00（新增客戶成功）     *
      *    (5)  GENACNT299        ← GENA01ACUS99（新增客戶失敗）     *
      *    (6)  GENACNT300        ← GENA01IMOT00（查詢汽車成功）     *
      *    (7)  GENACNT399        ← GENA01IMOT99（查詢汽車失敗）     *
      *    (8)  GENACNT400        ← GENA01AMOT00（新增汽車成功）     *
      *    (9)  GENACNT499        ← GENA01AMOT99（新增汽車失敗）     *
      *    (10) GENACNT500        ← GENA01DMOT00（刪除汽車成功）     *
      *    (11) GENACNT599        ← GENA01DMOT99（刪除汽車失敗）     *
      *    (12) GENACNT600        ← GENA01UMOT00（更新汽車成功）     *
      *    (13) GENACNT699        ← GENA01UMOT99（更新汽車失敗）     *
      *    (14) GENACNT700        ← GENA01IEND00（查詢壽險成功）     *
      *    (15) GENACNT799        ← GENA01IEND99（查詢壽險失敗）     *
      *    (16) GENACNT800        ← GENA01AEND00（新增壽險成功）     *
      *    (17) GENACNT899        ← GENA01AEND99（新增壽險失敗）     *
      *    (18) GENACNT900        ← GENA01DEND00（刪除壽險成功）     *
      *    (19) GENACNT999        ← GENA01DEND99（刪除壽險失敗）     *
      *    (20) GENACNTA00        ← GENA01UEND00（更新壽險成功）     *
      *    (21) GENACNTA99        ← GENA01UEND99（更新壽險失敗）     *
      *    (22) GENACNTB00        ← GENA01IHOU00（查詢房屋成功）     *
      *    (23) GENACNTB99        ← GENA01IHOU99（查詢房屋失敗）     *
      *    (24) GENACNTC00        ← GENA01AHOU00（新增房屋成功）     *
      *    (25) GENACNTC99        ← GENA01AHOU99（新增房屋失敗）     *
      *    (26) GENACNTD00        ← GENA01DHOU00（刪除房屋成功）     *
      *    (27) GENACNTD99        ← GENA01DHOU99（刪除房屋失敗）     *
      *----------------------------------------------------------------*
       01  GENA-COUNTERS               IS EXTERNAL.
           03 GENA-CUSTNUM             PIC S9(9) COMP VALUE 0.
           03 GENA-CNT                 OCCURS 26 TIMES
                                        PIC S9(9) COMP VALUE 0.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           03  COMMA-DATA.
             05 Comma-Data-H           PIC X(14).
             05 Comma-Data-High        PIC 9(10).
             05 FILLER                 PIC X(60).

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：LGSETUP 為頂層初始化程式（獨立執行），無 COMMAREA
       PROCEDURE DIVISION.

       MAINLINE SECTION.

      *----------------------------------------------------------------*
      *  取得初始客戶號                                                 *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *  轉置說明：取代 EXEC CICS RECEIVE INTO(WS-RECV)               *
      *    原始透過 CICS RECEIVE 取得終端機輸入的客戶號上限            *
      *    轉置後改為讀取環境變數                                       *
      *----------------------------------------------------------------*
           ACCEPT WS-RECV-DATA FROM ENVIRONMENT 'GENAPP_INITIAL_CUSTNUM'
               ON EXCEPTION
                   MOVE '         11' TO WS-RECV-DATA
           END-ACCEPT

           MOVE FUNCTION NUMVAL(
               FUNCTION TRIM(WS-RECV-DATA)) TO LastCustNum

      *----------------------------------------------------------------*
      *  取得當前時間（取代 EXEC CICS ASKTIME + FORMATTIME）          *
      *  手冊依據：Reference Manual p.190 Format 3                    *
      *----------------------------------------------------------------*
           ACCEPT WS-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME FROM TIME

           MOVE WS-DATE(1:8) TO WS-AREA-D
           MOVE WS-TIME(1:6) TO WS-AREA-T

      *----------------------------------------------------------------*
      *  開啟日誌檔（取代 CICS WriteQ TS QUEUE 初始化操作）           *
      *----------------------------------------------------------------*
           OPEN OUTPUT GENAPP-LOG

           MOVE WRITE-MSG-E TO LOG-RECORD
           WRITE LOG-RECORD

           MOVE FrstCustNum TO WRITE-MSG-LOW
           MOVE LastCustNum TO WRITE-MSG-HIGH
           MOVE WRITE-MSG   TO LOG-RECORD
           WRITE LOG-RECORD

           MOVE WS-QAREA TO LOG-RECORD
           WRITE LOG-RECORD

           CLOSE GENAPP-LOG

      *----------------------------------------------------------------*
      *  初始化 IS EXTERNAL 計數陣列                                   *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *  轉置說明：取代 27 組 EXEC CICS Delete Counter + Define Counter*
      *                                                                *
      *  GENA-CUSTNUM 設為 LastCustNum（客戶流水號起點）               *
      *  其餘 26 個統計計數器全部歸零                                  *
      *----------------------------------------------------------------*
           MOVE LastCustNum TO GENA-CUSTNUM
           INITIALIZE GENA-CNT

           DISPLAY 'LGSETUP: 初始化完成 客戶號起點=' GENA-CUSTNUM
           DISPLAY 'LGSETUP: 低=' FrstCustNum ' 高=' LastCustNum

           STOP RUN.

       A-EXIT.
           EXIT.
           GOBACK.
