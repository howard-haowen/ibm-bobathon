      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGAPOL01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：新增保單 — 業務邏輯層                                   *
      *        驗證 COMMAREA、套用業務規則（可選）、呼叫 DB2 新增層    *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Link Program    → CALL ... USING BY REFERENCE     *
      *      (LGAPDB01 / LGAPBR01)    RETURNING                       *
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
      *    01 LGAPDB01/LGAPBR01/     → 移除（CALL literal 直接使用）  *
      *       LGAPVS01                                                  *
      *                                                                *
      *  ACUCOBOL-GT 特有特性展示：                                     *
      *    特性 B：ACCEPT FROM CENTURY-DATE / TIME（p.190 Format 3）   *
      *    特性 C：ACCEPT FROM ENVIRONMENT（p.190 Format 5）           *
      *    特性 D：Level 78 編譯期常數（p.34）                         *
      *    特性 E：CALL ... USING BY REFERENCE RETURNING（p.217）      *
      *                                                                *
      *  ODM 業務規則說明：                                             *
      *    原始程式可呼叫 LGAPBR01（IBM ODM 業務規則引擎）             *
      *    預設 IN-STANDARD-MODE = 'N'，即不啟用 ODM                  *
      *    轉置後保留 88-level 控制旗標，改為 CALL 'LGAPBR01'          *
      *    LGAPBR01 本身的轉置由 Phase 4 處理                          *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGAPOL01.
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
                                        VALUE 'LGAPOL01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存
       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  業務規則模式旗標（原始邏輯原樣保留）                          *
      *  預設 'N' = 標準模式（不呼叫 ODM）                             *
      *  設為 'Y' = 業務規則模式（呼叫 LGAPBR01）                     *
      *----------------------------------------------------------------*
       01  BUSINESS-RULES              PIC X      VALUE 'N'.
           88  IN-STANDARD-MODE        VALUE 'N'.
           88  IN-RULES-MODE           VALUE 'Y'.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGAPOL01'.
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
       78  WS-CA-HEADER-LEN            VALUE 28.

      *  COMMAREA 長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *  VARCHAR 欄位長度暫存（ENDOWMENT PADDINGDATA）
       01  WS-VARY-FIELD.
           49 WS-VARY-LEN              PIC S9(4) COMP.
           49 WS-VARY-CHAR             PIC X(3900).

      *  CALL RETURNING 接收子程式回傳碼
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
                   MOVE 'LGAP' TO WS-TRANSID
           END-ACCEPT

           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION
                   MOVE 'ACU1' TO WS-TERMID
           END-ACCEPT

           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION
                   MOVE 0 TO WS-TASKNUM
           END-ACCEPT

      *  驗證 COMMAREA 已傳入（取代 EIBCALEN IS EQUAL TO ZERO）
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGAPOL01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM

      *----------------------------------------------------------------*
      *  COMMAREA 長度驗證                                             *
      *  WS-CA-HEADER-LEN 為 Level 78 編譯期常數（值=28）             *
      *----------------------------------------------------------------*
           ADD WS-CA-HEADER-LEN TO WS-REQUIRED-CA-LEN

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
             MOVE '98' TO CA-RETURN-CODE
             GOBACK
           END-IF

      *----------------------------------------------------------------*
      *  業務規則處理（ODM，可選）                                     *
      *  轉置說明：取代 EXEC CICS Link Program(LGAPBR01)               *
      *    IN-RULES-MODE 預設為 'N'，即不執行此段                     *
      *    若需啟用：MOVE 'Y' TO BUSINESS-RULES                       *
      *  手冊依據：Reference Manual p.217 CALL Statement              *
      *----------------------------------------------------------------*
           IF IN-RULES-MODE AND CA-REQUEST-ID = '01AEND'
               CALL 'LGAPBR01'
                   USING     BY REFERENCE DFHCOMMAREA
                   RETURNING WS-DB-RETURN-CODE
               END-CALL
           END-IF

      *----------------------------------------------------------------*
      *  呼叫 DB2 新增層（LGAPDB01）                                   *
      *  手冊依據：Reference Manual p.217 CALL Statement              *
      *----------------------------------------------------------------*
           CALL 'LGAPDB01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL

           IF CA-RETURN-CODE > 0
             GOBACK
           END-IF

      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
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
