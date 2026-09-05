      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGDPOL01.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：刪除保單 — 業務邏輯層                                   *
      *        驗證 COMMAREA、Request-ID 驗證、呼叫 DB2 刪除層         *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    EXEC CICS LINK PROGRAM(LGDPDB01) → CALL 'LGDPDB01'          *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除                            *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *                                BY REFERENCE DFHCOMMAREA        *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *    01 LGDPDB01/LGDPVS01      → 移除（CALL literal 直接使用）  *
      *    *DELETE-POLICY-VSAM 段落  → 保留注掉狀態（原樣）           *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGDPOL01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

        01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGDPOL01------WS'.
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
           03 FILLER                   PIC X(9)   VALUE ' LGDPOL01'.
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
               ON EXCEPTION MOVE 'LGDP' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION MOVE 0 TO WS-TASKNUM       END-ACCEPT

           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGDPOL01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE

           IF LENGTH OF DFHCOMMAREA < WS-CA-HEADER-LEN
             MOVE '98' TO CA-RETURN-CODE
             GOBACK
           END-IF

           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM
           MOVE CA-POLICY-NUM   TO EM-POLNUM

      *  Request-ID 大寫正規化（原始邏輯保留）
           MOVE FUNCTION UPPER-CASE(CA-REQUEST-ID) TO CA-REQUEST-ID

           IF ( CA-REQUEST-ID NOT EQUAL TO '01DEND' AND
                CA-REQUEST-ID NOT EQUAL TO '01DMOT' AND
                CA-REQUEST-ID NOT EQUAL TO '01DHOU' AND
                CA-REQUEST-ID NOT EQUAL TO '01DCOM' )
               MOVE '99' TO CA-RETURN-CODE
           ELSE
               PERFORM DELETE-POLICY-DB2-INFO
               IF CA-RETURN-CODE > 0
                 GOBACK
               END-IF
      *        PERFORM DELETE-POLICY-VSAM（原始已注掉，保留狀態）
           END-IF

           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *----------------------------------------------------------------*
       DELETE-POLICY-DB2-INFO.
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGDPDB01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL.
      *  原始程式此處有注掉的 LGASTAT1 LINK，保留狀態：
      *  *  EXEC CICS LINK PROGRAM('LGASTAT1')
      *  *            COMMAREA(DFHCOMMAREA)
      *  *            LENGTH(32500)
      *  *  END-EXEC
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
