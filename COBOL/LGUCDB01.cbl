      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGUCDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：更新客戶 — DB2 存取層                                   *
      *        UPDATE CUSTOMER、呼叫 LGUCVS01（VSAM 層）               *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    EXEC CICS LINK Program(LGUCVS01) → CALL 'LGUCVS01'          *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC SQL INCLUDE SQLCA    → COPY "sqlca.def"               *
      *    EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY                   *
      *    EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA                   *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除                            *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *                                BY REFERENCE DFHCOMMAREA        *
      *    77 LGUCVS01               → 移除                            *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGUCDB01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

        01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGUCDB01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.
           03 WS-RETRY                 PIC X      VALUE SPACES.

       01 DB2-IN-INTEGERS.
          03 DB2-CUSTOMERNUM-INT       PIC S9(9) COMP VALUE 0.
          03 DB2-POLICYNUM-INT         PIC S9(9) COMP VALUE 0.
          03 DB2-BROKERID-INT          PIC S9(9) COMP VALUE 0.
          03 DB2-PAYMENT-INT           PIC S9(9) COMP VALUE 0.
          03 DB2-E-TERM-SINT           PIC S9(4) COMP VALUE 0.
          03 DB2-E-SUMASSURED-INT      PIC S9(9) COMP VALUE 0.
          03 DB2-H-BEDROOMS-SINT       PIC S9(4) COMP VALUE 0.
          03 DB2-H-VALUE-INT           PIC S9(9) COMP VALUE 0.
          03 DB2-M-VALUE-INT           PIC S9(9) COMP VALUE 0.
          03 DB2-M-CC-SINT             PIC S9(4) COMP VALUE 0.
          03 DB2-M-PREMIUM-INT         PIC S9(9) COMP VALUE 0.
          03 DB2-M-ACCIDENTS-INT       PIC S9(9) COMP VALUE 0.

       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGUCDB01'.
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

      *  轉置說明：EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY
           COPY LGPOLICY.

      *  轉置說明：EXEC SQL INCLUDE SQLCA → COPY "sqlca.def"
           COPY "sqlca.def".

      *  CALL RETURNING 接收子程式回傳碼
       01  WS-DB-RETURN-CODE           PIC 9(2)   VALUE 0.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

      *  轉置說明：EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA
       01  DFHCOMMAREA.
               COPY LGCMAREA.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

       MAINLINE SECTION.

           INITIALIZE WS-HEADER.
           MOVE SPACES TO WS-RETRY.

           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION MOVE 'LGUC' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION MOVE 0 TO WS-TASKNUM       END-ACCEPT

           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGUCDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE
           MOVE CA-CUSTOMER-NUM TO DB2-CUSTOMERNUM-INT
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM

           PERFORM UPDATE-CUSTOMER-INFO

      *  呼叫 LGUCVS01（VSAM 層，保留原始呼叫）
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGUCVS01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL.

       END-PROGRAM.
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
       UPDATE-CUSTOMER-INFO.
           MOVE ' UPDATE CUST  ' TO EM-SQLREQ
           EXEC SQL
             UPDATE CUSTOMER
               SET
                 FIRSTNAME     = :CA-FIRST-NAME,
                 LASTNAME      = :CA-LAST-NAME,
                 DATEOFBIRTH   = :CA-DOB,
                 HOUSENAME     = :CA-HOUSE-NAME,
                 HOUSENUMBER   = :CA-HOUSE-NUM,
                 POSTCODE      = :CA-POSTCODE,
                 PHONEMOBILE   = :CA-PHONE-MOBILE,
                 PHONEHOME     = :CA-PHONE-HOME,
                 EMAILADDRESS  = :CA-EMAIL-ADDRESS
               WHERE
                   CUSTOMERNUMBER = :DB2-CUSTOMERNUM-INT
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             IF SQLCODE EQUAL 100
               MOVE '02' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.
           EXIT.

      *================================================================*
       WRITE-ERROR-MESSAGE.
           MOVE SQLCODE TO EM-SQLRC
           ACCEPT WS-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME FROM TIME
           MOVE WS-DATE(1:8) TO EM-DATE
           MOVE WS-TIME(1:6) TO EM-TIME
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG END-CALL
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG END-CALL.
           EXIT.
