      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGUPDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：更新保單 — DB2 存取層                                   *
      *        POLICY_CURSOR FOR UPDATE、UPDATE ENDOW/HOUSE/MOTOR       *
      *        呼叫 LGUPVS01（VSAM 層）                                *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    EXEC CICS LINK Program(LGUPVS01) → CALL 'LGUPVS01'          *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC CICS SYNCPOINT ROLLBACK → EXEC SQL ROLLBACK             *
      *                                （手冊 AcuSQL 支援 ROLLBACK）   *
      *    EXEC SQL INCLUDE SQLCA    → COPY "sqlca.def"               *
      *    EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY                   *
      *    EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA                   *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除                            *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *                                BY REFERENCE DFHCOMMAREA        *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *    77 LGUPVS01               → 移除                            *
      *                                                                *
      *  EIBCALEN 在 UPDATE-ENDOW 的特殊用途：                         *
      *    原始以 SUBTRACT WS-REQUIRED-CA-LEN FROM EIBCALEN 計算        *
      *    PADDINGDATA VARCHAR 長度。轉置後改為 LENGTH OF DFHCOMMAREA。 *
      *    注意：原始程式 UPDATE ENDOW 的 PADDINGDATA 欄位被注掉       *
      *    （STEW 標記），已原樣保留。                                  *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGUPDB01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

        01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGUPDB01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.
           03 WS-RETRY                 PIC X      VALUE SPACES.

       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGUPDB01'.
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

       01 WS-VARY-FIELD.
          49 WS-VARY-LEN               PIC S9(4) COMP.
          49 WS-VARY-CHAR              PIC X(3900).

      *  DB2 宿主變數
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

      *  轉置說明：EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY
           COPY LGPOLICY.

      *  NULL 指示變數
       77  IND-BROKERID                PIC S9(4) COMP.
       77  IND-BROKERSREF              PIC S9(4) COMP.
       77  IND-PAYMENT                 PIC S9(4) COMP.

      *  轉置說明：EXEC SQL INCLUDE SQLCA → COPY "sqlca.def"
           COPY "sqlca.def".

      *----------------------------------------------------------------*
      *  POLICY_CURSOR FOR UPDATE（保留原始邏輯）                      *
      *----------------------------------------------------------------*
           EXEC SQL
             DECLARE POLICY_CURSOR CURSOR WITH HOLD FOR
               SELECT ISSUEDATE,
                      EXPIRYDATE,
                      LASTCHANGED,
                      BROKERID,
                      BROKERSREFERENCE
               FROM POLICY
               WHERE ( CUSTOMERNUMBER = :DB2-CUSTOMERNUM-INT AND
                       POLICYNUMBER = :DB2-POLICYNUM-INT )
               FOR UPDATE OF ISSUEDATE,
                             EXPIRYDATE,
                             LASTCHANGED,
                             BROKERID,
                             BROKERSREFERENCE
           END-EXEC.

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
           INITIALIZE DB2-POLICY.
           INITIALIZE DB2-IN-INTEGERS.

           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION MOVE 'LGUP' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION MOVE 0 TO WS-TASKNUM       END-ACCEPT

           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGUPDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE
           MOVE CA-CUSTOMER-NUM TO DB2-CUSTOMERNUM-INT
           MOVE CA-POLICY-NUM   TO DB2-POLICYNUM-INT
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM
           MOVE CA-POLICY-NUM   TO EM-POLNUM

           PERFORM UPDATE-POLICY-DB2-INFO

      *  呼叫 LGUPVS01（VSAM 層，保留原始呼叫）
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGUPVS01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL.

       END-PROGRAM.
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
       FETCH-DB2-POLICY-ROW.
           MOVE ' FETCH  ROW   ' TO EM-SQLREQ
           EXEC SQL
             FETCH POLICY_CURSOR
             INTO  :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-LASTCHANGED,
                   :DB2-BROKERID-INT INDICATOR :IND-BROKERID,
                   :DB2-BROKERSREF   INDICATOR :IND-BROKERSREF,
                   :DB2-PAYMENT-INT  INDICATOR :IND-PAYMENT
           END-EXEC
           EXIT.

      *================================================================*
       UPDATE-POLICY-DB2-INFO.

           MOVE ' OPEN   PCURSOR ' TO EM-SQLREQ
           EXEC SQL
             OPEN POLICY_CURSOR
           END-EXEC

           EVALUATE SQLCODE
             WHEN 0
               MOVE '00' TO CA-RETURN-CODE
             WHEN -913
               MOVE '02' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
             WHEN OTHER
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
           END-EVALUATE

           PERFORM FETCH-DB2-POLICY-ROW

           IF SQLCODE = 0
             IF CA-LASTCHANGED EQUAL TO DB2-LASTCHANGED

               EVALUATE CA-REQUEST-ID
                 WHEN '01UEND'
                   PERFORM UPDATE-ENDOW-DB2-INFO
                 WHEN '01UHOU'
                   PERFORM UPDATE-HOUSE-DB2-INFO
                 WHEN '01UMOT'
                   PERFORM UPDATE-MOTOR-DB2-INFO
               END-EVALUATE

               IF CA-RETURN-CODE NOT EQUAL '00'
                 PERFORM CLOSE-PCURSOR
                 GOBACK
               END-IF

               MOVE CA-BROKERID  TO DB2-BROKERID-INT
               MOVE CA-PAYMENT   TO DB2-PAYMENT-INT

               MOVE ' UPDATE POLICY  ' TO EM-SQLREQ
               EXEC SQL
                 UPDATE POLICY
                   SET ISSUEDATE        = :CA-ISSUE-DATE,
                       EXPIRYDATE       = :CA-EXPIRY-DATE,
                       LASTCHANGED      = CURRENT TIMESTAMP,
                       BROKERID         = :DB2-BROKERID-INT,
                       BROKERSREFERENCE = :CA-BROKERSREF
                   WHERE CURRENT OF POLICY_CURSOR
               END-EXEC

               EXEC SQL
                 SELECT LASTCHANGED
                   INTO :CA-LASTCHANGED
                   FROM POLICY
                   WHERE POLICYNUMBER = :DB2-POLICYNUM-INT
               END-EXEC

               IF SQLCODE NOT EQUAL 0
      *          轉置說明：取代 EXEC CICS SYNCPOINT ROLLBACK
                 EXEC SQL ROLLBACK END-EXEC
                 MOVE '90' TO CA-RETURN-CODE
                 PERFORM WRITE-ERROR-MESSAGE
               END-IF

             ELSE
               MOVE '02' TO CA-RETURN-CODE
             END-IF

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.
           PERFORM CLOSE-PCURSOR.

       CLOSE-PCURSOR.
           MOVE ' CLOSE  PCURSOR' TO EM-SQLREQ
           EXEC SQL
             CLOSE POLICY_CURSOR
           END-EXEC

           EVALUATE SQLCODE
             WHEN 0
               MOVE '00' TO CA-RETURN-CODE
             WHEN -501
               MOVE '00' TO CA-RETURN-CODE
               MOVE '-501 detected c' TO EM-SQLREQ
               GOBACK
             WHEN OTHER
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
           END-EVALUATE.
           EXIT.

      *================================================================*
       UPDATE-ENDOW-DB2-INFO.

           MOVE CA-E-TERM        TO DB2-E-TERM-SINT
           MOVE CA-E-SUM-ASSURED TO DB2-E-SUMASSURED-INT

           MOVE ' UPDATE ENDOW ' TO EM-SQLREQ

      *  轉置說明：SUBTRACT WS-REQUIRED-CA-LEN FROM EIBCALEN
      *    → SUBTRACT WS-REQUIRED-CA-LEN FROM LENGTH OF DFHCOMMAREA
           SUBTRACT WS-REQUIRED-CA-LEN FROM LENGTH OF DFHCOMMAREA
               GIVING WS-VARY-LEN

           IF WS-VARY-LEN > 0
             MOVE CA-E-PADDING-DATA
                 TO WS-VARY-CHAR(1:WS-VARY-LEN)
             EXEC SQL
               UPDATE ENDOWMENT
                 SET
                   WITHPROFITS   = :CA-E-WITH-PROFITS,
                     EQUITIES    = :CA-E-EQUITIES,
                     MANAGEDFUND = :CA-E-MANAGED-FUND,
                     FUNDNAME    = :CA-E-FUND-NAME,
                     TERM        = :DB2-E-TERM-SINT,
                     SUMASSURED  = :DB2-E-SUMASSURED-INT,
                     LIFEASSURED = :CA-E-LIFE-ASSURED
      *--->  原始程式：PADDINGDATA = :WS-VARY-FIELD 被 STEW 標記注掉
      *               此處原樣保留（不更新 PADDINGDATA）
                 WHERE
                     POLICYNUMBER = :DB2-POLICYNUM-INT
             END-EXEC
           ELSE
             EXEC SQL
               UPDATE ENDOWMENT
                 SET
                   WITHPROFITS   = :CA-E-WITH-PROFITS,
                     EQUITIES    = :CA-E-EQUITIES,
                     MANAGEDFUND = :CA-E-MANAGED-FUND,
                     FUNDNAME    = :CA-E-FUND-NAME,
                     TERM        = :DB2-E-TERM-SINT,
                     SUMASSURED  = :DB2-E-SUMASSURED-INT,
                     LIFEASSURED = :CA-E-LIFE-ASSURED
                 WHERE
                     POLICYNUMBER = :DB2-POLICYNUM-INT
             END-EXEC
           END-IF

           IF SQLCODE NOT EQUAL 0
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.
           EXIT.

      *================================================================*
       UPDATE-HOUSE-DB2-INFO.

           MOVE CA-H-BEDROOMS    TO DB2-H-BEDROOMS-SINT
           MOVE CA-H-VALUE       TO DB2-H-VALUE-INT

           MOVE ' UPDATE HOUSE ' TO EM-SQLREQ
           EXEC SQL
             UPDATE HOUSE
               SET
                    PROPERTYTYPE = :CA-H-PROPERTY-TYPE,
                    BEDROOMS     = :DB2-H-BEDROOMS-SINT,
                    VALUE        = :DB2-H-VALUE-INT,
                    HOUSENAME    = :CA-H-HOUSE-NAME,
                    HOUSENUMBER  = :CA-H-HOUSE-NUMBER,
                    POSTCODE     = :CA-H-POSTCODE
               WHERE
                    POLICYNUMBER = :DB2-POLICYNUM-INT
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             IF SQLCODE = 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '01' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.
           EXIT.

      *================================================================*
       UPDATE-MOTOR-DB2-INFO.

           MOVE CA-M-CC          TO DB2-M-CC-SINT
           MOVE CA-M-VALUE       TO DB2-M-VALUE-INT
           MOVE CA-M-PREMIUM     TO DB2-M-PREMIUM-INT
           MOVE CA-M-ACCIDENTS   TO DB2-M-ACCIDENTS-INT

           MOVE ' UPDATE MOTOR ' TO EM-SQLREQ
           EXEC SQL
             UPDATE MOTOR
               SET
                    MAKE              = :CA-M-MAKE,
                    MODEL             = :CA-M-MODEL,
                    VALUE             = :DB2-M-VALUE-INT,
                    REGNUMBER         = :CA-M-REGNUMBER,
                    COLOUR            = :CA-M-COLOUR,
                    CC                = :DB2-M-CC-SINT,
                    YEAROFMANUFACTURE = :CA-M-MANUFACTURED,
                    PREMIUM           = :DB2-M-PREMIUM-INT,
                    ACCIDENTS         = :DB2-M-ACCIDENTS-INT
               WHERE
                    POLICYNUMBER      = :DB2-POLICYNUM-INT
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
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
