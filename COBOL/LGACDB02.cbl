      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *  ADD Customer Security  ─  DB2 存取層                           *
      *                                                                *
      * 原始程式: LGACDB02.cbl (CICS/DB2)                              *
      * 轉置目標: ACUCOBOL-GT v11.0 (AcuSQL 兩階段編譯)                 *
      *                                                                *
      * 功能說明:                                                       *
      *   呼叫 02ACUS 時將新客戶的密碼資料 INSERT 進 CUSTOMER_SECURE 表  *
      *   由 LGACDB01 在新增客戶後呼叫                                   *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC SQL INCLUDE SQLCA        → COPY "sqlca.def"            *
      *   EXEC SQL INCLUDE LGPOLICY     → COPY LGPOLICY               *
      *   EIBTRNID/EIBTRMID/EIBTASKN   → ACCEPT FROM ENVIRONMENT     *
      *   EIBCALEN                      → LENGTH OF DFHCOMMAREA       *
      *   SET WS-ADDR-DFHCOMMAREA       → 移除（BY REFERENCE 自動處理） *
      *   EXEC CICS ASKTIME/FORMATTIME → ACCEPT FROM CENTURY-DATE/TIME*
      *   EXEC CICS LINK PROGRAM('LGSTSQ') → CALL 'LGSTSQ'           *
      *   EXEC CICS ABEND ABCODE('LGCA') → DISPLAY UPON SYSERR + STOP *
      *   EXEC CICS RETURN              → GOBACK                      *
      *   COPY LGPOLICY（WS-CA-HEADER-LEN）→ Level 78 常數            *
      *                                                                *
      * 注意：本程式需 AcuSQL 預處理                                      *
      *   步驟一: acusql LGACDB02.cbl LGACDB02.cbl.i                  *
      *   步驟二: ccbl32 -Da4 LGACDB02.cbl.i                          *
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 B] ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)*
      *   [特性 C] ACCEPT FROM ENVIRONMENT       (手冊 p.190 Format 5)*
      *   [特性 D] Level 78 編譯期常數（COPY LGPOLICY）(手冊 p.34)      *
      *   [特性 E] CALL...USING BY REFERENCE     (手冊 p.217)         *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGACDB02.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

      *----------------------------------------------------------------*
      * 執行時除錯資訊
      *----------------------------------------------------------------*
       01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGACDB02------WS'.
           03 WS-TRANSID               PIC X(4).
           03 WS-TERMID                PIC X(4).
           03 WS-TASKNUM               PIC 9(7).
           03 WS-FILLER                PIC X.
      *   WS-ADDR-DFHCOMMAREA 已移除：BY REFERENCE 自動處理位址傳遞
           03 WS-CALEN                 PIC S9(4) COMP.

       01  WS-RESP                     PIC S9(8) COMP.
       01  LastCustNum                 PIC S9(8) COMP.

      * [特性 B] 日期時間變數 (手冊 p.190 Format 3)
       01  WS-CENTURY-DATE             PIC 9(8)  VALUE 0.
       01  WS-TIME-OF-DAY              PIC 9(8)  VALUE 0.

      * 錯誤訊息結構
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)  VALUE SPACES.
           03 FILLER                   PIC X     VALUE SPACES.
           03 EM-TIME                  PIC X(6)  VALUE SPACES.
           03 FILLER                   PIC X(9)  VALUE ' LGACDB02'.
           03 EM-VARIABLE.
             05 FILLER                 PIC X(6)  VALUE ' CNUM='.
             05 EM-CUSNUM              PIC X(10) VALUE SPACES.
             05 FILLER                 PIC X(6)  VALUE ' PNUM='.
             05 EM-POLNUM              PIC X(10) VALUE SPACES.
             05 EM-SQLREQ              PIC X(16) VALUE SPACES.
             05 FILLER                 PIC X(9)  VALUE ' SQLCODE='.
             05 EM-SQLRC               PIC +9(5) USAGE DISPLAY.

       01  CA-ERROR-MSG.
           03 FILLER                   PIC X(9)  VALUE 'COMMAREA='.
           03 CA-DATA                  PIC X(90) VALUE SPACES.

      *----------------------------------------------------------------*
       77  WS-CS-PASSWORD              PIC X(16) VALUE 'NewPass'.
       77  WS-CS-STATE                 PIC X     VALUE 'N'.
       77  WS-CA-COUNT                 PIC S9(9) COMP VALUE 0.

      *----------------------------------------------------------------*
      * 長度檢核（WS-CA-HEADER-LEN 沿用 Level 78 源自 LGPOLICY）        *
      *----------------------------------------------------------------*
       01  WS-COMMAREA-LENGTHS.
           03 WS-CA-HEADER-LEN         PIC S9(4) COMP VALUE +18.
           03 WS-REQUIRED-CA-LEN       PIC S9(4)      VALUE +0.

      * [特性 D] COPY LGPOLICY 引入 Level 78 編譯期長度常數 (手冊 p.34)
           COPY LGPOLICY.

      *----------------------------------------------------------------*
      * DB2 Host Variables
      *----------------------------------------------------------------*
       01  DB2-OUT-INTEGERS.
           03 DB2-CUSTOMERNUM-INT      PIC S9(9) COMP.
           03 DB2-CUSTOMERCNT-INT      PIC S9(9) COMP.

      *----------------------------------------------------------------*
      * AcuSQL: COPY "sqlca.def" 取代 EXEC SQL INCLUDE SQLCA          *
      *----------------------------------------------------------------*
           COPY "sqlca.def".

      ******************************************************************
      *    L I N K A G E     S E C T I O N
      ******************************************************************
       LINKAGE SECTION.

      * 本程式使用自訂 COMMAREA（非標準 LGCMAREA）
       01  DFHCOMMAREA.
           03 D2-REQUEST-ID            PIC X(6).
           03 D2-RETURN-CODE           PIC 9(2).
           03 D2-CUSTOMER-NUM          PIC 9(10).
           03 D2-CUSTSECR-PASS         PIC X(32).
           03 D2-CUSTSECR-COUNT        PIC X(4).
           03 D2-CUSTSECR-STATE        PIC X.
           03 D2-CUSTSECR-DATA         PIC X(32445).

      ******************************************************************
      *    P R O C E D U R E S
      ******************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *----------------------------------------------------------------*
       MAINLINE SECTION.

      *----------------------------------------------------------------*
      * 初始化 Header 並取得執行環境資訊
      *----------------------------------------------------------------*
           INITIALIZE WS-HEADER.
      * [特性 C] 取代 EIBTRNID/EIBTRMID/EIBTASKN (手冊 p.190 Format 5)
           ACCEPT WS-TRANSID  FROM ENVIRONMENT 'GENAPP_TRNID'
           ACCEPT WS-TERMID   FROM ENVIRONMENT 'GENAPP_TERMID'
           ACCEPT WS-TASKNUM  FROM ENVIRONMENT 'GENAPP_TASKNUM'

      *----------------------------------------------------------------*
      * COMMAREA 長度檢核
      *   原始: IF EIBCALEN IS EQUAL TO ZERO → ABEND
      *   轉置: LENGTH OF DFHCOMMAREA，不得為零（呼叫者責任）
      *----------------------------------------------------------------*
           MOVE LENGTH OF DFHCOMMAREA TO WS-CALEN.
           IF WS-CALEN IS EQUAL TO ZERO
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGACDB02: ABEND LGCA - No COMMAREA'
                       UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO D2-RETURN-CODE.

      *----------------------------------------------------------------*
      * 依 REQUEST-ID 分派處理
      *----------------------------------------------------------------*
           EVALUATE D2-REQUEST-ID
      *       新增客戶密碼
             WHEN '02ACUS'
               MOVE D2-CUSTOMER-NUM   TO DB2-CUSTOMERNUM-INT
               MOVE D2-CUSTSECR-COUNT TO DB2-CUSTOMERCNT-INT
               PERFORM INSERT-CUSTOMER-PASSWORD
             WHEN OTHER
               MOVE '99' TO D2-RETURN-CODE
               GOBACK
           END-EVALUATE

           GOBACK.

       MAINLINE-EXIT.
           EXIT.
      *----------------------------------------------------------------*
      *================================================================*
       INSERT-CUSTOMER-PASSWORD.
      *================================================================*
      * INSERT 客戶密碼資料至 CUSTOMER_SECURE 資料表
      *================================================================*
           MOVE ' INSERT SECURITY' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO CUSTOMER_SECURE
                       ( customerNumber,
                         customerPass,
                         state_indicator,
                         pass_changes   )
                VALUES ( :DB2-CUSTOMERNUM-INT,
                         :D2-CUSTSECR-PASS,
                         :D2-CUSTSECR-STATE,
                         :DB2-CUSTOMERCNT-INT)
           END-EXEC

           IF SQLCODE NOT EQUAL 0
               MOVE '98' TO D2-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
           END-IF

           EXIT.

      *================================================================*
      * 錯誤訊息輸出
      *================================================================*
       WRITE-ERROR-MESSAGE.
           MOVE SQLCODE TO EM-SQLRC
      * [特性 B] ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)
           ACCEPT WS-CENTURY-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME-OF-DAY  FROM TIME
           MOVE WS-CENTURY-DATE     TO EM-DATE
           MOVE WS-TIME-OF-DAY(1:6) TO EM-TIME
      * [特性 E] CALL 取代 EXEC CICS LINK (手冊 p.217)
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG
           EXIT.
