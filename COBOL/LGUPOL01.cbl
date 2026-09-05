      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGUPOL01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：更新保單 — 業務邏輯層                                   *
      *        驗證 COMMAREA 長度（依保單類型）、呼叫 DB2 更新層       *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    EXEC CICS LINK Program(LGUPDB01) → CALL 'LGUPDB01'          *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除                            *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *                                BY REFERENCE DFHCOMMAREA        *
      *    WS-POLICY-LENGTHS 群組    → COPY LGPOLICY（Level 78 常數）  *
      *    01 LGUPDB01 PIC X(8)      → 移除（CALL literal 直接使用）  *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE                                       *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGUPOL01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

        01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGUPOL01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGUPOL01'.
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
      *----------------------------------------------------------------*
       78  WS-CA-HEADER-LEN            VALUE 28.

       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *  VARCHAR 暫存（保留，供子程式相容）
       01 WS-VARY-FIELD.
          49 WS-VARY-LEN               PIC S9(4) COMP.
          49 WS-VARY-CHAR              PIC X(3900).

      *  NULL 指示變數
       77  IND-BROKERID                PIC S9(4) COMP.
       77  IND-BROKERSREF              PIC S9(4) COMP.
       77  IND-PAYMENT                 PIC S9(4) COMP.

      *  轉置說明：WS-POLICY-LENGTHS 群組 → COPY LGPOLICY
           COPY LGPOLICY.

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
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

       MAINLINE SECTION.

           INITIALIZE WS-HEADER.

           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION MOVE 'LGUP' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION MOVE 0 TO WS-TASKNUM       END-ACCEPT

           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGUPOL01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM
           MOVE CA-POLICY-NUM   TO EM-POLNUM

      *  依保單類型驗證 COMMAREA 長度
           EVALUATE CA-REQUEST-ID

             WHEN '01UEND'
               ADD WS-CA-HEADER-LEN  TO WS-REQUIRED-CA-LEN
               ADD WS-FULL-ENDOW-LEN TO WS-REQUIRED-CA-LEN
               IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
                 MOVE '98' TO CA-RETURN-CODE
                 GOBACK
               END-IF

             WHEN '01UHOU'
               ADD WS-CA-HEADER-LEN  TO WS-REQUIRED-CA-LEN
               ADD WS-FULL-HOUSE-LEN TO WS-REQUIRED-CA-LEN
               IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
                 MOVE '98' TO CA-RETURN-CODE
                 GOBACK
               END-IF

             WHEN '01UMOT'
               ADD WS-CA-HEADER-LEN  TO WS-REQUIRED-CA-LEN
               ADD WS-FULL-MOTOR-LEN TO WS-REQUIRED-CA-LEN
               IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
                 MOVE '98' TO CA-RETURN-CODE
                 GOBACK
               END-IF

             WHEN OTHER
               MOVE '99' TO CA-RETURN-CODE
           END-EVALUATE

           PERFORM UPDATE-POLICY-DB2-INFO.

       END-PROGRAM.
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
       UPDATE-POLICY-DB2-INFO.
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGUPDB01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL.
           EXIT.

      *================================================================*
       WRITE-ERROR-MESSAGE.
           ACCEPT WS-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME FROM TIME
           MOVE WS-DATE(1:8) TO EM-DATE
           MOVE WS-TIME(1:6) TO EM-TIME
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG END-CALL
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG END-CALL.
           EXIT.
