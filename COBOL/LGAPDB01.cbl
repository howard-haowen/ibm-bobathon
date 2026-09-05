      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGAPDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：新增保單 — DB2 存取層                                   *
      *        INSERT POLICY + 各類保單子表（END/HOU/MOT/COM/CLM）     *
      *        呼叫 LGAPVS01（VSAM 層）                                *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Link Program    → CALL ... USING BY REFERENCE     *
      *      (LGAPVS01)               RETURNING                       *
      *                                手冊 p.217 CALL Statement       *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *      ABCODE('LGSQ')            （保單子表新增失敗時）          *
      *    EXEC CICS ASKTIME /       → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME                手冊 p.190 Format 3             *
      *    EIBTRNID/EIBTRMID/        → ACCEPT FROM ENVIRONMENT         *
      *      EIBTASKN                  手冊 p.190 Format 5             *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除（BY REFERENCE 自動處理）  *
      *    EXEC SQL INCLUDE SQLCA    → COPY "sqlca.def"               *
      *    EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY                   *
      *    EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA                   *
      *      (LINKAGE SECTION)                                         *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *      (無 USING)                BY REFERENCE DFHCOMMAREA        *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE      手冊 p.34 Level 78 Data Items   *
      *    01 LGAPVS01 PIC X(8)      → 移除（CALL literal 直接使用）  *
      *                                                                *
      *  ACUCOBOL-GT 特有特性展示：                                     *
      *    特性 B：ACCEPT FROM CENTURY-DATE / TIME（p.190 Format 3）   *
      *    特性 C：ACCEPT FROM ENVIRONMENT（p.190 Format 5）           *
      *    特性 D：Level 78 編譯期常數（p.34）                         *
      *    特性 E：CALL ... USING BY REFERENCE RETURNING（p.217）      *
      *                                                                *
      *  EIBCALEN 在 INSERT-ENDOW 的特殊用途：                         *
      *    原始以 SUBTRACT WS-REQUIRED-CA-LEN FROM EIBCALEN           *
      *    計算 PADDINGDATA VARCHAR 的可用長度。                       *
      *    轉置後改為 SUBTRACT WS-REQUIRED-CA-LEN FROM                *
      *    LENGTH OF DFHCOMMAREA，等效語義。                           *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGAPDB01.
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
                                        VALUE 'LGAPDB01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存
       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGAPDB01'.
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

      *  LGPOLICY copybook 提供 WS-*-LEN Level 78 常數 + DB2 結構
           COPY LGPOLICY.

      *----------------------------------------------------------------*
      *  DB2 宿主變數 — 整數輸入
      *----------------------------------------------------------------*
       01 DB2-IN-INTEGERS.
           03 DB2-CUSTOMERNUM-INT      PIC S9(9) COMP VALUE 0.
           03 DB2-BROKERID-INT         PIC S9(9) COMP VALUE 0.
           03 DB2-PAYMENT-INT          PIC S9(9) COMP VALUE 0.
           03 DB2-E-TERM-SINT          PIC S9(4) COMP VALUE 0.
           03 DB2-E-SUMASSURED-INT     PIC S9(9) COMP VALUE 0.
           03 DB2-E-PADDING-LEN        PIC S9(9) COMP VALUE 0.
           03 DB2-H-BEDROOMS-SINT      PIC S9(4) COMP VALUE 0.
           03 DB2-H-VALUE-INT          PIC S9(9) COMP VALUE 0.
           03 DB2-M-VALUE-INT          PIC S9(9) COMP VALUE 0.
           03 DB2-M-CC-SINT            PIC S9(4) COMP VALUE 0.
           03 DB2-M-PREMIUM-INT        PIC S9(9) COMP VALUE 0.
           03 DB2-M-ACCIDENTS-INT      PIC S9(9) COMP VALUE 0.
           03 DB2-B-FirePeril-Int      PIC S9(4) COMP VALUE 0.
           03 DB2-B-FirePremium-Int    PIC S9(9) COMP VALUE 0.
           03 DB2-B-CrimePeril-Int     PIC S9(4) COMP VALUE 0.
           03 DB2-B-CrimePremium-Int   PIC S9(9) COMP VALUE 0.
           03 DB2-B-FloodPeril-Int     PIC S9(4) COMP VALUE 0.
           03 DB2-B-FloodPremium-Int   PIC S9(9) COMP VALUE 0.
           03 DB2-B-WeatherPeril-Int   PIC S9(4) COMP VALUE 0.
           03 DB2-B-WeatherPremium-Int PIC S9(9) COMP VALUE 0.
           03 DB2-B-Status-Int         PIC S9(4) COMP VALUE 0.
           03 DB2-C-Policynum-Int      PIC S9(9) COMP VALUE 0.
           03 DB2-C-Num-INT            PIC S9(9) COMP VALUE +0.
           03 DB2-C-Paid-INT           PIC S9(9) COMP VALUE 0.
           03 DB2-C-Value-INT          PIC S9(9) COMP VALUE 0.

      *  DB2 宿主變數 — 整數輸出（IDENTITY_VAL_LOCAL 接收保單號）
       01 DB2-OUT-INTEGERS.
           03 DB2-POLICYNUM-INT        PIC S9(9) COMP VALUE +0.

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

           INITIALIZE DB2-IN-INTEGERS.
           INITIALIZE DB2-OUT-INTEGERS.

      *  驗證 COMMAREA 已傳入
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGAPDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE

      *  轉換 COMMAREA 客戶/保單號為 DB2 整數格式
           MOVE CA-CUSTOMER-NUM TO DB2-CUSTOMERNUM-INT
           MOVE CA-POLICY-NUM   TO DB2-C-POLICYNUM-INT
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM

      *  COMMAREA 長度驗證：依保單類型計算最低需求
           ADD WS-CA-HEADER-LEN TO WS-REQUIRED-CA-LEN

           EVALUATE CA-REQUEST-ID

             WHEN '01AEND'
               ADD WS-FULL-ENDOW-LEN TO WS-REQUIRED-CA-LEN
               MOVE 'E' TO DB2-POLICYTYPE

             WHEN '01AHOU'
               ADD WS-FULL-HOUSE-LEN TO WS-REQUIRED-CA-LEN
               MOVE 'H' TO DB2-POLICYTYPE

             WHEN '01AMOT'
               ADD WS-FULL-MOTOR-LEN TO WS-REQUIRED-CA-LEN
               MOVE 'M' TO DB2-POLICYTYPE

             WHEN '01ACOM'
               MOVE 'C' TO DB2-POLICYTYPE

             WHEN '01ACLM'
               MOVE 'X' TO DB2-POLICYTYPE

             WHEN OTHER
               MOVE '99' TO CA-RETURN-CODE
               GOBACK

           END-EVALUATE

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
             MOVE '98' TO CA-RETURN-CODE
             GOBACK
           END-IF

      *  新增 POLICY 主表（理賠例外，理賠不建立新保單記錄）
           IF CA-REQUEST-ID NOT = '01ACLM'
             PERFORM INSERT-POLICY
           END-IF

      *  依保單類型呼叫子表新增段落
           EVALUATE CA-REQUEST-ID

             WHEN '01AEND'
               PERFORM INSERT-ENDOW

             WHEN '01AHOU'
               PERFORM INSERT-HOUSE

             WHEN '01AMOT'
               PERFORM INSERT-MOTOR

             WHEN '01ACOM'
               PERFORM INSERT-COMMERCIAL

             WHEN '01ACLM'
               PERFORM INSERT-CLAIM

             WHEN OTHER
               MOVE '99' TO CA-RETURN-CODE

           END-EVALUATE

      *  呼叫 LGAPVS01（VSAM 層，保留原始呼叫）
      *  手冊依據：Reference Manual p.217 CALL Statement
           CALL 'LGAPVS01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL

      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  INSERT-POLICY                                                 *
      *  INSERT INTO POLICY（DB2 IDENTITY 自動配號）                  *
      *  取回新保單號與 LASTCHANGED 時戳                               *
      *================================================================*
       INSERT-POLICY.

           MOVE CA-BROKERID   TO DB2-BROKERID-INT
           MOVE CA-PAYMENT    TO DB2-PAYMENT-INT

           MOVE ' INSERT POLICY' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO POLICY
                       ( POLICYNUMBER,
                         CUSTOMERNUMBER,
                         ISSUEDATE,
                         EXPIRYDATE,
                         POLICYTYPE,
                         LASTCHANGED,
                         BROKERID,
                         BROKERSREFERENCE,
                         PAYMENT           )
                VALUES ( DEFAULT,
                         :DB2-CUSTOMERNUM-INT,
                         :CA-ISSUE-DATE,
                         :CA-EXPIRY-DATE,
                         :DB2-POLICYTYPE,
                         CURRENT TIMESTAMP,
                         :DB2-BROKERID-INT,
                         :CA-BROKERSREF,
                         :DB2-PAYMENT-INT      )
           END-EXEC

           EVALUATE SQLCODE

             WHEN 0
               MOVE '00' TO CA-RETURN-CODE

             WHEN -530
               MOVE '70' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK

             WHEN OTHER
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK

           END-EVALUATE

      *  取回 DB2 自動產生的保單號
           EXEC SQL
             SET :DB2-POLICYNUM-INT = IDENTITY_VAL_LOCAL()
           END-EXEC
           MOVE DB2-POLICYNUM-INT TO CA-POLICY-NUM
           MOVE CA-POLICY-NUM     TO EM-POLNUM

      *  取回 DB2 設定的 LASTCHANGED 時戳
           EXEC SQL
             SELECT LASTCHANGED
               INTO :CA-LASTCHANGED
               FROM POLICY
               WHERE POLICYNUMBER = :DB2-POLICYNUM-INT
           END-EXEC.

           EXIT.

      *================================================================*
      *  INSERT-ENDOW                                                  *
      *  INSERT INTO ENDOWMENT（含 PADDINGDATA VARCHAR 處理）         *
      *  轉置說明：EIBCALEN 用於計算 VARCHAR 長度                     *
      *    → 改為 LENGTH OF DFHCOMMAREA                               *
      *================================================================*
       INSERT-ENDOW.

           MOVE CA-E-TERM        TO DB2-E-TERM-SINT
           MOVE CA-E-SUM-ASSURED TO DB2-E-SUMASSURED-INT

           MOVE ' INSERT ENDOW ' TO EM-SQLREQ

      *  計算 VARCHAR 欄位可用長度
      *  轉置說明：原始 SUBTRACT WS-REQUIRED-CA-LEN FROM EIBCALEN
      *    → SUBTRACT WS-REQUIRED-CA-LEN FROM LENGTH OF DFHCOMMAREA
           SUBTRACT WS-REQUIRED-CA-LEN FROM LENGTH OF DFHCOMMAREA
               GIVING WS-VARY-LEN

           IF WS-VARY-LEN > 0
      *      COMMAREA 含有 VARCHAR 資料
             MOVE CA-E-PADDING-DATA
                 TO WS-VARY-CHAR(1:WS-VARY-LEN)
             EXEC SQL
               INSERT INTO ENDOWMENT
                         ( POLICYNUMBER,
                           WITHPROFITS,
                           EQUITIES,
                           MANAGEDFUND,
                           FUNDNAME,
                           TERM,
                           SUMASSURED,
                           LIFEASSURED,
                           PADDINGDATA    )
                  VALUES ( :DB2-POLICYNUM-INT,
                           :CA-E-WITH-PROFITS,
                           :CA-E-EQUITIES,
                           :CA-E-MANAGED-FUND,
                           :CA-E-FUND-NAME,
                           :DB2-E-TERM-SINT,
                           :DB2-E-SUMASSURED-INT,
                           :CA-E-LIFE-ASSURED,
                           :WS-VARY-FIELD )
             END-EXEC
           ELSE
      *      無 VARCHAR 資料，省略 PADDINGDATA 欄位
             EXEC SQL
               INSERT INTO ENDOWMENT
                         ( POLICYNUMBER,
                           WITHPROFITS,
                           EQUITIES,
                           MANAGEDFUND,
                           FUNDNAME,
                           TERM,
                           SUMASSURED,
                           LIFEASSURED    )
                  VALUES ( :DB2-POLICYNUM-INT,
                           :CA-E-WITH-PROFITS,
                           :CA-E-EQUITIES,
                           :CA-E-MANAGED-FUND,
                           :CA-E-FUND-NAME,
                           :DB2-E-TERM-SINT,
                           :DB2-E-SUMASSURED-INT,
                           :CA-E-LIFE-ASSURED )
             END-EXEC
           END-IF

           IF SQLCODE NOT EQUAL 0
             MOVE '90' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
      *      轉置說明：取代 EXEC CICS ABEND ABCODE('LGSQ')
      *        ABEND 觸發 DB2 自動回滾（POLICY INSERT 回滾）
             DISPLAY 'LGAPDB01: ABEND - INSERT ENDOW FAILED'
                 UPON SYSERR
             STOP RUN
           END-IF.

           EXIT.

      *================================================================*
      *  INSERT-HOUSE                                                  *
      *  INSERT INTO HOUSE                                             *
      *================================================================*
       INSERT-HOUSE.

           MOVE CA-H-VALUE    TO DB2-H-VALUE-INT
           MOVE CA-H-BEDROOMS TO DB2-H-BEDROOMS-SINT

           MOVE ' INSERT HOUSE ' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO HOUSE
                       ( POLICYNUMBER,
                         PROPERTYTYPE,
                         BEDROOMS,
                         VALUE,
                         HOUSENAME,
                         HOUSENUMBER,
                         POSTCODE          )
                VALUES ( :DB2-POLICYNUM-INT,
                         :CA-H-PROPERTY-TYPE,
                         :DB2-H-BEDROOMS-SINT,
                         :DB2-H-VALUE-INT,
                         :CA-H-HOUSE-NAME,
                         :CA-H-HOUSE-NUMBER,
                         :CA-H-POSTCODE      )
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '90' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
      *      轉置說明：取代 EXEC CICS ABEND ABCODE('LGSQ')
             DISPLAY 'LGAPDB01: ABEND - INSERT HOUSE FAILED'
                 UPON SYSERR
             STOP RUN
           END-IF.

           EXIT.

      *================================================================*
      *  INSERT-MOTOR                                                  *
      *  INSERT INTO MOTOR                                             *
      *================================================================*
       INSERT-MOTOR.

           MOVE CA-M-VALUE     TO DB2-M-VALUE-INT
           MOVE CA-M-CC        TO DB2-M-CC-SINT
           MOVE CA-M-PREMIUM   TO DB2-M-PREMIUM-INT
           MOVE CA-M-ACCIDENTS TO DB2-M-ACCIDENTS-INT

           MOVE ' INSERT MOTOR ' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO MOTOR
                       ( POLICYNUMBER,
                         MAKE,
                         MODEL,
                         VALUE,
                         REGNUMBER,
                         COLOUR,
                         CC,
                         YEAROFMANUFACTURE,
                         PREMIUM,
                         ACCIDENTS )
                VALUES ( :DB2-POLICYNUM-INT,
                         :CA-M-MAKE,
                         :CA-M-MODEL,
                         :DB2-M-VALUE-INT,
                         :CA-M-REGNUMBER,
                         :CA-M-COLOUR,
                         :DB2-M-CC-SINT,
                         :CA-M-MANUFACTURED,
                         :DB2-M-PREMIUM-INT,
                         :DB2-M-ACCIDENTS-INT )
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '90' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
      *      轉置說明：取代 EXEC CICS ABEND ABCODE('LGSQ')
             DISPLAY 'LGAPDB01: ABEND - INSERT MOTOR FAILED'
                 UPON SYSERR
             STOP RUN
           END-IF.

           EXIT.

      *================================================================*
      *  INSERT-COMMERCIAL                                             *
      *  INSERT INTO COMMERCIAL                                        *
      *================================================================*
       INSERT-COMMERCIAL.

           MOVE CA-B-FirePeril       TO DB2-B-FirePeril-Int
           MOVE CA-B-FirePremium     TO DB2-B-FirePremium-Int
           MOVE CA-B-CrimePeril      TO DB2-B-CrimePeril-Int
           MOVE CA-B-CrimePremium    TO DB2-B-CrimePremium-Int
           MOVE CA-B-FloodPeril      TO DB2-B-FloodPeril-Int
           MOVE CA-B-FloodPremium    TO DB2-B-FloodPremium-Int
           MOVE CA-B-WeatherPeril    TO DB2-B-WeatherPeril-Int
           MOVE CA-B-WeatherPremium  TO DB2-B-WeatherPremium-Int
           MOVE CA-B-Status          TO DB2-B-Status-Int

           MOVE ' INSERT COMMER' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO COMMERCIAL
                       (
                         PolicyNumber,
                         RequestDate,
                         StartDate,
                         RenewalDate,
                         Address,
                         Zipcode,
                         LatitudeN,
                         LongitudeW,
                         Customer,
                         PropertyType,
                         FirePeril,
                         FirePremium,
                         CrimePeril,
                         CrimePremium,
                         FloodPeril,
                         FloodPremium,
                         WeatherPeril,
                         WeatherPremium,
                         Status,
                         RejectionReason
                                             )
                VALUES (
                         :DB2-POLICYNUM-INT,
                         :CA-LASTCHANGED,
                         :CA-ISSUE-DATE,
                         :CA-EXPIRY-DATE,
                         :CA-B-Address,
                         :CA-B-Postcode,
                         :CA-B-Latitude,
                         :CA-B-Longitude,
                         :CA-B-Customer,
                         :CA-B-PropType,
                         :DB2-B-FirePeril-Int,
                         :DB2-B-FirePremium-Int,
                         :DB2-B-CrimePeril-Int,
                         :DB2-B-CrimePremium-Int,
                         :DB2-B-FloodPeril-Int,
                         :DB2-B-FloodPremium-Int,
                         :DB2-B-WeatherPeril-Int,
                         :DB2-B-WeatherPremium-Int,
                         :DB2-B-Status-Int,
                         :CA-B-RejectReason
                                             )
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '90' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
      *      轉置說明：取代 EXEC CICS ABEND ABCODE('LGSQ')
             DISPLAY 'LGAPDB01: ABEND - INSERT COMMERCIAL FAILED'
                 UPON SYSERR
             STOP RUN
           END-IF.

           EXIT.

      *================================================================*
      *  INSERT-CLAIM                                                  *
      *  INSERT INTO CLAIM                                             *
      *================================================================*
       INSERT-CLAIM.

           MOVE CA-C-Paid  TO DB2-C-Paid-INT
           MOVE CA-C-Value TO DB2-C-Value-INT

           MOVE ' INSERT CLAIM' TO EM-SQLREQ
           EXEC SQL
             INSERT INTO CLAIM
                       (
                         ClaimNumber,
                         PolicyNumber,
                         ClaimDate,
                         Paid,
                         Value,
                         Cause,
                         Observations
                                             )
                VALUES (
                         :DB2-C-Num-Int,
                         :DB2-C-Policynum-Int,
                         :CA-C-Date,
                         :DB2-C-Paid-Int,
                         :DB2-C-Value-Int,
                         :CA-C-Cause,
                         :CA-C-Observations
                                             )
           END-EXEC

           MOVE DB2-C-Num-Int TO CA-C-Num

           IF SQLCODE NOT EQUAL 0
             MOVE '90' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
      *      轉置說明：取代 EXEC CICS ABEND ABCODE('LGSQ')
             DISPLAY 'LGAPDB01: ABEND - INSERT CLAIM FAILED'
                 UPON SYSERR
             STOP RUN
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
      *================================================================*
       WRITE-ERROR-MESSAGE.
           MOVE SQLCODE TO EM-SQLRC
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
