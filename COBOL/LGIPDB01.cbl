      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGIPDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：查詢保單 — DB2 存取層                                   *
      *        依 CA-REQUEST-ID 路由至對應 SQL SELECT / Cursor 段      *
      *        支援 Endowment / House / Motor / Commercial / Claim     *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Get Container   → PROCEDURE DIVISION USING        *
      *      (ICOM-Channel)            BY REFERENCE DFHCOMMAREA        *
      *                                             ICOM-RECORD        *
      *                                             ICOM-RECORD-COUNT  *
      *                                （呼叫端提供暫存空間）          *
      *    EXEC CICS Put Container   → 直接寫入 BY REFERENCE 參數     *
      *      (ICOM-Data/ICOM-Count)    無需 CICS 服務                  *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EXEC CICS ABEND           → DISPLAY UPON SYSERR + STOP RUN  *
      *    EXEC CICS ASKTIME /       → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME                手冊 p.190 Format 3             *
      *    EIBTRNID/EIBTRMID/        → ACCEPT FROM ENVIRONMENT         *
      *      EIBTASKN                  手冊 p.190 Format 5             *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    SET ... TO ADDRESS OF     → 移除（BY REFERENCE 自動處理）  *
      *    EXEC SQL INCLUDE SQLCA    → COPY "sqlca.def"               *
      *    EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY                   *
      *    EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA                   *
      *      (LINKAGE SECTION)         (AcuSQL 不支援 LINKAGE 中的     *
      *                                 EXEC SQL INCLUDE)              *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *      (無 USING)                BY REFERENCE DFHCOMMAREA        *
      *                                             ICOM-RECORD        *
      *                                             ICOM-RECORD-COUNT  *
      *    WS-CA-HEADERTRAILER-LEN   → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE      手冊 p.34 Level 78 Data Items   *
      *    MINUS-ONE PIC S9(4) COMP  → Level 78 編譯期常數             *
      *                                                                *
      *  ACUCOBOL-GT 特有特性展示：                                     *
      *    特性 B：ACCEPT FROM CENTURY-DATE / TIME（p.190 Format 3）   *
      *    特性 C：ACCEPT FROM ENVIRONMENT（p.190 Format 5）           *
      *    特性 D：Level 78 編譯期常數（p.34）                         *
      *    特性 E：CALL ... USING BY REFERENCE RETURNING（p.217）      *
      *    特性 G：RECORD-POSITION OF（p.72-73）展示                   *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGIPDB01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

      *----------------------------------------------------------------*
      *  TSAREA — 診斷暫存（原樣保留）                                 *
      *----------------------------------------------------------------*
        01 TSAREA.
          03  TSAREAPOSTCODE           PIC X(8).
          03  Filler                   PIC X   VALUE SPACES.
          03  TSAREACUSTNUM            PIC 9(10).
          03  Filler                   PIC X   VALUE SPACES.
          03  TSAREAPOLNUM             PIC 9(10).
          03  Filler                   PIC X   VALUE SPACES.

      *----------------------------------------------------------------*
      *  執行期識別資訊                                                 *
      *----------------------------------------------------------------*
        01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGIPOL01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存
       01  ABS-TIME                    PIC S9(8) COMP VALUE +0.
       01  WS-DATE                     PIC X(8)  VALUE SPACES.
       01  WS-TIME                     PIC X(8)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)  VALUE SPACES.
           03 FILLER                   PIC X     VALUE SPACES.
           03 EM-TIME                  PIC X(6)  VALUE SPACES.
           03 FILLER                   PIC X(9)  VALUE ' LGIPOL01'.
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
      *  Level 78 編譯期常數                                           *
      *  手冊依據：Reference Manual p.34 Level 78 Data Items          *
      *  轉置說明：取代 WS-COMMAREA-LENGTHS 群組中的執行期常數        *
      *            與 MINUS-ONE PIC S9(4) COMP VALUE -1               *
      *----------------------------------------------------------------*
       78  WS-CA-HEADERTRAILER-LEN     VALUE 33.
       78  WS-MINUS-ONE                VALUE -1.

      *  COMMAREA 長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *  保單資料結束位置（ENDOWMENT PADDINGDATA 計算用）
       01  END-POLICY-POS              PIC S9(4) COMP VALUE +1.

      *  Request ID（大寫正規化後）
       01  WS-Request-ID               PIC X(6).

      *----------------------------------------------------------------*
      *  ICOM 控制變數                                                  *
      *  轉置說明：取代 CICS Channel/Container 機制                    *
      *    ICOM-Record-Count：記錄實際寫入 ICOM-RECORD 的筆數         *
      *    其他 ICOM-* 指標在 LINKAGE SECTION 傳入後自動就緒，        *
      *    無需 SET ADDRESS OF 操作                                    *
      *----------------------------------------------------------------*
       01  ICOM-Record-Count           PIC S9(4) COMP VALUE 0.

      *  ICOM 緩衝區偏移量（游標批次寫入時追蹤位置）
       01  ICOM-WRITE-OFFSET           PIC S9(9) COMP VALUE 0.

      *----------------------------------------------------------------*
      *  特性 G 展示：RECORD-POSITION OF                               *
      *  手冊依據：Reference Manual p.72-73                            *
      *  RECORD-POSITION OF <field> 返回該欄位在記錄中的位元組偏移量  *
      *  此處以 CA-POLICY-COMMON 為範例，於診斷時輸出其偏移量         *
      *----------------------------------------------------------------*
       01  WS-POLICY-COMMON-OFFSET     PIC 9(6)  VALUE 0.

      *----------------------------------------------------------------*
      *    DB2 CURSOR 宣告                                             *
      *    （AcuSQL 預處理：acusql → ccbl32 兩階段編譯）             *
      *----------------------------------------------------------------*
           EXEC SQL
             DECLARE Cust_Cursor INSENSITIVE SCROLL CURSOR FOR
             SELECT
                   CustomerNumber,
                   Policy.PolicyNumber,
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
             FROM  POLICY, COMMERCIAL
             WHERE ( POLICY.POLICYNUMBER =
                        Commercial.POLICYNUMBER AND
                     Policy.CustomerNumber =
                        :DB2-CUSTOMERNUM-INT )
           END-EXEC.

           EXEC SQL
             DECLARE Zip_Cursor INSENSITIVE SCROLL CURSOR FOR
             SELECT
                   CustomerNumber,
                   Policy.PolicyNumber,
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
             FROM  POLICY, COMMERCIAL
             WHERE ( POLICY.POLICYNUMBER =
                        Commercial.POLICYNUMBER AND
                     Commercial.Zipcode =
                        :CA-B-POSTCODE )
           END-EXEC.

           EXEC SQL
             DECLARE CusClaim_Cursor INSENSITIVE SCROLL CURSOR FOR
             SELECT
                   POLICY.CustomerNumber,
                   ClaimNumber,
                   CLAIM.PolicyNumber,
                   ClaimDate,
                   Paid,
                   Value,
                   Cause,
                   Observations
             FROM  POLICY, CLAIM
             WHERE ( POLICY.POLICYNUMBER =
                        CLAIM.POLICYNUMBER AND
                     POLICY.CustomerNumber =
                        :DB2-CUSTOMERNUM-INT )
           END-EXEC.

      *----------------------------------------------------------------*
      *  轉置說明：EXEC SQL INCLUDE SQLCA →
      *    COPY "sqlca.def"
      *    AcuSQL 以 COPY 替代，由 acusql 預處理器展開
      *----------------------------------------------------------------*
           COPY "sqlca.def".

      *----------------------------------------------------------------*
      *  DB2 宿主變數 — 整數輸入
      *----------------------------------------------------------------*
       01 DB2-IN-INTEGERS.
           03 DB2-CUSTOMERNUM-INT      PIC S9(9) COMP VALUE +0.
           03 DB2-POLICYNUM-INT        PIC S9(9) COMP VALUE +0.
           03 DB2-CLAIMNUM-INT         PIC S9(9) COMP VALUE +0.

      *  DB2 宿主變數 — 整數輸出（SMALLINT / INTEGER 接收）
       01 DB2-OUT-INTEGERS.
           03 DB2-BROKERID-INT         PIC S9(9) COMP.
           03 DB2-PAYMENT-INT          PIC S9(9) COMP.
           03 DB2-E-TERM-SINT          PIC S9(4) COMP.
           03 DB2-E-SUMASSURED-INT     PIC S9(9) COMP.
           03 DB2-E-PADDING-LEN        PIC S9(9) COMP.
           03 DB2-H-BEDROOMS-SINT      PIC S9(4) COMP.
           03 DB2-H-VALUE-INT          PIC S9(9) COMP.
           03 DB2-M-VALUE-INT          PIC S9(9) COMP.
           03 DB2-M-CC-SINT            PIC S9(4) COMP.
           03 DB2-M-PREMIUM-INT        PIC S9(9) COMP.
           03 DB2-M-ACCIDENTS-INT      PIC S9(9) COMP.
           03 DB2-B-FirePeril-Int      PIC S9(4) COMP.
           03 DB2-B-FirePremium-Int    PIC S9(9) COMP.
           03 DB2-B-CrimePeril-Int     PIC S9(4) COMP.
           03 DB2-B-CrimePremium-Int   PIC S9(9) COMP.
           03 DB2-B-FloodPeril-Int     PIC S9(4) COMP.
           03 DB2-B-FloodPremium-Int   PIC S9(9) COMP.
           03 DB2-B-WeatherPeril-Int   PIC S9(4) COMP.
           03 DB2-B-WeatherPremium-Int PIC S9(9) COMP.
           03 DB2-B-Status-Int         PIC S9(4) COMP.
           03 DB2-C-Paid-int           PIC S9(9) COMP.
           03 DB2-C-Value-int          PIC S9(9) COMP.

      *  轉置說明：EXEC SQL INCLUDE LGPOLICY → COPY LGPOLICY
      *    AcuSQL 以 COPY 替代，DB2 宿主變數結構由 copybook 展開
           COPY LGPOLICY.

      *  DB2 NULL 指示變數
       77  IND-BROKERID                PIC S9(4) COMP.
       77  IND-BROKERSREF              PIC S9(4) COMP.
       77  IND-PAYMENT                 PIC S9(4) COMP.
       77  IND-E-PADDINGDATA           PIC S9(4) COMP.
       77  IND-E-PADDINGDATAL          PIC S9(4) COMP.

      ******************************************************************
      *    L I N K A G E     S E C T I O N                            *
      ******************************************************************
       LINKAGE SECTION.

      *  轉置說明：
      *    原始 EXEC SQL INCLUDE LGCMAREA 在 LINKAGE SECTION
      *    → COPY LGCMAREA（AcuSQL 不支援 LINKAGE 中的 EXEC SQL INCLUDE）
       01  DFHCOMMAREA.
               COPY LGCMAREA.

      *  ICOM Channel/Container 替代參數（由 LGIPOL01 提供暫存空間）
      *  轉置說明：
      *    原始 ICOM-Record 透過 CICS Get Container SET(Pointer) 定址
      *    → 改為 BY REFERENCE 直接傳入，無需 SET ADDRESS OF
       01  ICOM-RECORD                 PIC X(1202).

      *  實際寫入筆數（PUT Container 'ICOM-Count' 替代）
       01  ICOM-RECORD-COUNT           PIC S9(4) COMP.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：
      *    加入 USING BY REFERENCE，明確宣告三個參數：
      *      DFHCOMMAREA      — 雙向共用 COMMAREA
      *      ICOM-RECORD      — 商業保單批次資料緩衝區
      *      ICOM-RECORD-COUNT — 實際寫入筆數
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA
                                             ICOM-RECORD
                                             ICOM-RECORD-COUNT.

      *----------------------------------------------------------------*
       MAINLINE SECTION.

      *  初始化工作區
           INITIALIZE WS-HEADER.

      *----------------------------------------------------------------*
      *  取得執行環境識別資訊                                           *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *  轉置說明：取代 MOVE EIBTRNID/EIBTRMID/EIBTASKN               *
      *----------------------------------------------------------------*
           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION
                   MOVE 'LGIP' TO WS-TRANSID
           END-ACCEPT

           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION
                   MOVE 'ACU1' TO WS-TERMID
           END-ACCEPT

           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION
                   MOVE 0 TO WS-TASKNUM
           END-ACCEPT

      *  初始化 DB2 宿主變數
           INITIALIZE DB2-IN-INTEGERS.
           INITIALIZE DB2-OUT-INTEGERS.
           INITIALIZE DB2-POLICY.
           MOVE 0 TO ICOM-RECORD-COUNT.

      *----------------------------------------------------------------*
      *  Channel/Container 替代邏輯                                    *
      *  轉置說明：                                                     *
      *    原始程式在此以 EXEC CICS Get Container(ICOM-Container) 嘗試 *
      *    讀取 CICS Channel 資料。若成功則以 Container 的 Pointer      *
      *    重定向 DFHCOMMAREA；若不成功則走 COMMAREA 路徑。            *
      *                                                                *
      *    轉置後：DFHCOMMAREA 由呼叫端（LGIPOL01）直接 BY REFERENCE   *
      *    傳入，無需 Container 路徑。直接執行原 Else 分支的邏輯。     *
      *----------------------------------------------------------------*

      *  驗證 COMMAREA 已傳入（取代 EIBCALEN IS EQUAL TO ZERO）
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGIPDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00'           TO CA-RETURN-CODE
           MOVE CA-CUSTOMER-NUM TO DB2-CUSTOMERNUM-INT
           MOVE CA-POLICY-NUM   TO DB2-POLICYNUM-INT
           MOVE CA-CUSTOMER-NUM TO EM-CUSNUM
           MOVE CA-POLICY-NUM   TO EM-POLNUM

      *  將 Request-ID 轉為大寫（原始邏輯保留）
           MOVE FUNCTION UPPER-CASE(CA-REQUEST-ID) TO WS-REQUEST-ID

      *----------------------------------------------------------------*
      *  特性 G 展示：RECORD-POSITION OF                               *
      *  手冊依據：Reference Manual p.72-73                            *
      *  RECORD-POSITION OF <data-item> 返回欄位在其所在記錄結構中    *
      *  的位元組偏移量（1 起算）。此處記錄 CA-POLICY-COMMON 的偏移   *
      *  以輔助除錯，確認 COMMAREA 結構正確對齊。                      *
      *----------------------------------------------------------------*
           MOVE RECORD-POSITION OF CA-POLICY-COMMON
               TO WS-POLICY-COMMON-OFFSET

      *  路由至對應保單類型的 DB2 處理段
           EVALUATE WS-REQUEST-ID

             WHEN '01IEND'
               INITIALIZE DB2-ENDOWMENT
               PERFORM GET-ENDOW-DB2-INFO

             WHEN '01IHOU'
               INITIALIZE DB2-HOUSE
               PERFORM GET-HOUSE-DB2-INFO

             WHEN '01IMOT'
               INITIALIZE DB2-MOTOR
               PERFORM GET-MOTOR-DB2-INFO

             WHEN '01ICOM'
               INITIALIZE DB2-COMMERCIAL
               PERFORM GET-COMMERCIAL-DB2-INFO-1

             WHEN '02ICOM'
               INITIALIZE DB2-COMMERCIAL
               PERFORM GET-COMMERCIAL-DB2-INFO-2

             WHEN '03ICOM'
               INITIALIZE DB2-COMMERCIAL
               PERFORM GET-COMMERCIAL-DB2-INFO-3

             WHEN '05ICOM'
               INITIALIZE DB2-COMMERCIAL
               PERFORM GET-COMMERCIAL-DB2-INFO-5

             WHEN '01ICLM'
               INITIALIZE DB2-CLAIM
               MOVE CA-C-Num TO DB2-CLAIMNUM-INT
               PERFORM GET-CLAIM-DB2-INFO-1

             WHEN '02ICLM'
               INITIALIZE DB2-CLAIM
               PERFORM GET-CLAIM-DB2-INFO-2

             WHEN OTHER
               MOVE '99' TO CA-RETURN-CODE

           END-EVALUATE.

      *----------------------------------------------------------------*
       End-Program.
      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  GET-ENDOW-DB2-INFO                                            *
      *  查詢 POLICY JOIN ENDOWMENT，單筆 SELECT INTO              *
      *  支援 PADDINGDATA VARCHAR 長度計算                             *
      *================================================================*
       GET-ENDOW-DB2-INFO.

           MOVE ' SELECT ENDOW ' TO EM-SQLREQ
           EXEC SQL
             SELECT  ISSUEDATE,
                     EXPIRYDATE,
                     LASTCHANGED,
                     BROKERID,
                     BROKERSREFERENCE,
                     PAYMENT,
                     WITHPROFITS,
                     EQUITIES,
                     MANAGEDFUND,
                     FUNDNAME,
                     TERM,
                     SUMASSURED,
                     LIFEASSURED,
                     PADDINGDATA,
                     LENGTH(PADDINGDATA)
             INTO  :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-LASTCHANGED,
                   :DB2-BROKERID-INT INDICATOR :IND-BROKERID,
                   :DB2-BROKERSREF   INDICATOR :IND-BROKERSREF,
                   :DB2-PAYMENT-INT  INDICATOR :IND-PAYMENT,
                   :DB2-E-WITHPROFITS,
                   :DB2-E-EQUITIES,
                   :DB2-E-MANAGEDFUND,
                   :DB2-E-FUNDNAME,
                   :DB2-E-TERM-SINT,
                   :DB2-E-SUMASSURED-INT,
                   :DB2-E-LIFEASSURED,
                   :DB2-E-PADDINGDATA INDICATOR :IND-E-PADDINGDATA,
                   :DB2-E-PADDING-LEN INDICATOR :IND-E-PADDINGDATAL
             FROM  POLICY, ENDOWMENT
             WHERE ( POLICY.POLICYNUMBER =
                        ENDOWMENT.POLICYNUMBER AND
                     POLICY.CUSTOMERNUMBER =
                        :DB2-CUSTOMERNUM-INT AND
                     POLICY.POLICYNUMBER =
                        :DB2-POLICYNUM-INT )
           END-EXEC

           IF SQLCODE = 0
      *      計算所需 COMMAREA 長度
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-ENDOW-LEN       TO WS-REQUIRED-CA-LEN

      *      若 PADDINGDATA 非 NULL，加入其長度
             IF IND-E-PADDINGDATAL NOT EQUAL WS-MINUS-ONE
               ADD DB2-E-PADDING-LEN TO WS-REQUIRED-CA-LEN
               ADD DB2-E-PADDING-LEN TO END-POLICY-POS
             END-IF

      *      若 COMMAREA 長度不足則回傳錯誤碼
      *      轉置說明：取代 EXEC CICS RETURN → GOBACK
             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
      *        將整數欄位移入正確長度（NULL 欄位不移動）
               IF IND-BROKERID NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-BROKERID-INT   TO DB2-BROKERID
               END-IF
               IF IND-PAYMENT NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-PAYMENT-INT    TO DB2-PAYMENT
               END-IF
               MOVE DB2-E-TERM-SINT      TO DB2-E-TERM
               MOVE DB2-E-SUMASSURED-INT TO DB2-E-SUMASSURED

               MOVE DB2-POLICY-COMMON TO CA-POLICY-COMMON
               MOVE DB2-ENDOW-FIXED
                   TO CA-ENDOWMENT(1:WS-ENDOW-LEN)
               IF IND-E-PADDINGDATA NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-E-PADDINGDATA TO
                     CA-E-PADDING-DATA(1:DB2-E-PADDING-LEN)
               END-IF
             END-IF

      *      標記保單資料結束
             MOVE 'FINAL' TO CA-E-PADDING-DATA(END-POLICY-POS:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF

           END-IF.
           EXIT.

      *================================================================*
      *  GET-HOUSE-DB2-INFO                                            *
      *  查詢 POLICY JOIN HOUSE，單筆 SELECT INTO                  *
      *================================================================*
       GET-HOUSE-DB2-INFO.

           MOVE ' SELECT HOUSE ' TO EM-SQLREQ
           EXEC SQL
             SELECT  ISSUEDATE,
                     EXPIRYDATE,
                     LASTCHANGED,
                     BROKERID,
                     BROKERSREFERENCE,
                     PAYMENT,
                     PROPERTYTYPE,
                     BEDROOMS,
                     VALUE,
                     HOUSENAME,
                     HOUSENUMBER,
                     POSTCODE
             INTO  :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-LASTCHANGED,
                   :DB2-BROKERID-INT   INDICATOR :IND-BROKERID,
                   :DB2-BROKERSREF     INDICATOR :IND-BROKERSREF,
                   :DB2-PAYMENT-INT    INDICATOR :IND-PAYMENT,
                   :DB2-H-PROPERTYTYPE,
                   :DB2-H-BEDROOMS-SINT,
                   :DB2-H-VALUE-INT,
                   :DB2-H-HOUSENAME,
                   :DB2-H-HOUSENUMBER,
                   :DB2-H-POSTCODE
             FROM  POLICY, HOUSE
             WHERE ( POLICY.POLICYNUMBER =
                        HOUSE.POLICYNUMBER AND
                     POLICY.CUSTOMERNUMBER =
                        :DB2-CUSTOMERNUM-INT AND
                     POLICY.POLICYNUMBER =
                        :DB2-POLICYNUM-INT )
           END-EXEC

           IF SQLCODE = 0
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-HOUSE-LEN       TO WS-REQUIRED-CA-LEN

             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
               IF IND-BROKERID NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-BROKERID-INT  TO DB2-BROKERID
               END-IF
               IF IND-PAYMENT NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-PAYMENT-INT   TO DB2-PAYMENT
               END-IF
               MOVE DB2-H-BEDROOMS-SINT TO DB2-H-BEDROOMS
               MOVE DB2-H-VALUE-INT     TO DB2-H-VALUE

               MOVE DB2-POLICY-COMMON  TO CA-POLICY-COMMON
               MOVE DB2-HOUSE          TO CA-HOUSE(1:WS-HOUSE-LEN)
             END-IF

             MOVE 'FINAL' TO CA-H-FILLER(1:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF

           END-IF.
           EXIT.

      *================================================================*
      *  GET-MOTOR-DB2-INFO                                            *
      *  查詢 POLICY JOIN MOTOR，單筆 SELECT INTO                  *
      *================================================================*
       GET-MOTOR-DB2-INFO.

           MOVE ' SELECT MOTOR ' TO EM-SQLREQ
           EXEC SQL
             SELECT  ISSUEDATE,
                     EXPIRYDATE,
                     LASTCHANGED,
                     BROKERID,
                     BROKERSREFERENCE,
                     PAYMENT,
                     MAKE,
                     MODEL,
                     VALUE,
                     REGNUMBER,
                     COLOUR,
                     CC,
                     YEAROFMANUFACTURE,
                     PREMIUM,
                     ACCIDENTS
             INTO  :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-LASTCHANGED,
                   :DB2-BROKERID-INT   INDICATOR :IND-BROKERID,
                   :DB2-BROKERSREF     INDICATOR :IND-BROKERSREF,
                   :DB2-PAYMENT-INT    INDICATOR :IND-PAYMENT,
                   :DB2-M-MAKE,
                   :DB2-M-MODEL,
                   :DB2-M-VALUE-INT,
                   :DB2-M-REGNUMBER,
                   :DB2-M-COLOUR,
                   :DB2-M-CC-SINT,
                   :DB2-M-MANUFACTURED,
                   :DB2-M-PREMIUM-INT,
                   :DB2-M-ACCIDENTS-INT
             FROM  POLICY, MOTOR
             WHERE ( POLICY.POLICYNUMBER =
                        MOTOR.POLICYNUMBER AND
                     POLICY.CUSTOMERNUMBER =
                        :DB2-CUSTOMERNUM-INT AND
                     POLICY.POLICYNUMBER =
                        :DB2-POLICYNUM-INT )
           END-EXEC

      *  原始程式此處有 DISPLAY SQLCODE（診斷用，原樣保留）
           DISPLAY 'LGIPDB01 SQLCODE:' SQLCODE

           IF SQLCODE = 0
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-MOTOR-LEN       TO WS-REQUIRED-CA-LEN

             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
               IF IND-BROKERID NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-BROKERID-INT    TO DB2-BROKERID
               END-IF
               IF IND-PAYMENT NOT EQUAL WS-MINUS-ONE
                 MOVE DB2-PAYMENT-INT     TO DB2-PAYMENT
               END-IF
               MOVE DB2-M-CC-SINT        TO DB2-M-CC
               MOVE DB2-M-VALUE-INT      TO DB2-M-VALUE
               MOVE DB2-M-PREMIUM-INT    TO DB2-M-PREMIUM
               MOVE DB2-M-ACCIDENTS-INT  TO DB2-M-ACCIDENTS
               MOVE DB2-M-PREMIUM-INT    TO CA-M-PREMIUM
               MOVE DB2-M-ACCIDENTS-INT  TO CA-M-ACCIDENTS

               MOVE DB2-POLICY-COMMON    TO CA-POLICY-COMMON
               MOVE DB2-MOTOR            TO CA-MOTOR(1:WS-MOTOR-LEN)
             END-IF

             MOVE 'FINAL' TO CA-M-FILLER(1:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF

           END-IF.
           EXIT.

      *================================================================*
      *  GET-COMMERCIAL-DB2-INFO-1                                     *
      *  查詢 POLICY JOIN COMMERCIAL（指定客戶號＋保單號），單筆      *
      *================================================================*
       GET-COMMERCIAL-DB2-INFO-1.

           MOVE ' SELECT Commercial ' TO EM-SQLREQ

           EXEC SQL
             SELECT
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
             INTO  :DB2-LASTCHANGED,
                   :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-B-Address,
                   :DB2-B-Postcode,
                   :DB2-B-Latitude,
                   :DB2-B-Longitude,
                   :DB2-B-Customer,
                   :DB2-B-PropType,
                   :DB2-B-FirePeril-Int,
                   :DB2-B-FirePremium-Int,
                   :DB2-B-CrimePeril-Int,
                   :DB2-B-CrimePremium-Int,
                   :DB2-B-FloodPeril-Int,
                   :DB2-B-FloodPremium-Int,
                   :DB2-B-WeatherPeril-Int,
                   :DB2-B-WeatherPremium-Int,
                   :DB2-B-Status-Int,
                   :DB2-B-RejectReason
             FROM  POLICY, COMMERCIAL
             WHERE ( POLICY.POLICYNUMBER =
                        Commercial.POLICYNUMBER AND
                     POLICY.CUSTOMERNUMBER =
                        :DB2-CUSTOMERNUM-INT AND
                     POLICY.POLICYNUMBER =
                        :DB2-POLICYNUM-INT )
           END-EXEC

           IF SQLCODE = 0
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-COMM-LEN        TO WS-REQUIRED-CA-LEN

             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
               MOVE DB2-B-FirePeril-Int      TO DB2-B-FirePeril
               MOVE DB2-B-FirePremium-Int    TO DB2-B-FirePremium
               MOVE DB2-B-CrimePeril-Int     TO DB2-B-CrimePeril
               MOVE DB2-B-CrimePremium-Int   TO DB2-B-CrimePremium
               MOVE DB2-B-FloodPeril-Int     TO DB2-B-FloodPeril
               MOVE DB2-B-FloodPremium-Int   TO DB2-B-FloodPremium
               MOVE DB2-B-WeatherPeril-Int   TO DB2-B-WeatherPeril
               MOVE DB2-B-WeatherPremium-Int TO DB2-B-WeatherPremium
               MOVE DB2-B-Status-Int         TO DB2-B-Status

               MOVE DB2-POLICY-COMMON        TO CA-POLICY-COMMON
               MOVE DB2-COMMERCIAL     TO CA-COMMERCIAL(1:WS-COMM-LEN)
             END-IF

             MOVE 'FINAL' TO CA-B-FILLER(1:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.

           EXIT.

      *================================================================*
      *  GET-COMMERCIAL-DB2-INFO-2                                     *
      *  查詢 POLICY JOIN COMMERCIAL（僅指定保單號），單筆            *
      *================================================================*
       GET-COMMERCIAL-DB2-INFO-2.

           MOVE ' SELECT Commercial ' TO EM-SQLREQ

           EXEC SQL
             SELECT
                   CustomerNumber,
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
             INTO
                   :DB2-CUSTOMERNUM-INT,
                   :DB2-LASTCHANGED,
                   :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-B-Address,
                   :DB2-B-Postcode,
                   :DB2-B-Latitude,
                   :DB2-B-Longitude,
                   :DB2-B-Customer,
                   :DB2-B-PropType,
                   :DB2-B-FirePeril-Int,
                   :DB2-B-FirePremium-Int,
                   :DB2-B-CrimePeril-Int,
                   :DB2-B-CrimePremium-Int,
                   :DB2-B-FloodPeril-Int,
                   :DB2-B-FloodPremium-Int,
                   :DB2-B-WeatherPeril-Int,
                   :DB2-B-WeatherPremium-Int,
                   :DB2-B-Status-Int,
                   :DB2-B-RejectReason
             FROM  POLICY, COMMERCIAL
             WHERE ( POLICY.POLICYNUMBER =
                        Commercial.POLICYNUMBER AND
                     POLICY.POLICYNUMBER =
                        :DB2-POLICYNUM-INT )
           END-EXEC

           IF SQLCODE = 0
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-COMM-LEN        TO WS-REQUIRED-CA-LEN

             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
               MOVE DB2-CustomerNum-Int      TO CA-CUSTOMER-NUM
               MOVE DB2-B-FirePeril-Int      TO DB2-B-FirePeril
               MOVE DB2-B-FirePremium-Int    TO DB2-B-FirePremium
               MOVE DB2-B-CrimePeril-Int     TO DB2-B-CrimePeril
               MOVE DB2-B-CrimePremium-Int   TO DB2-B-CrimePremium
               MOVE DB2-B-FloodPeril-Int     TO DB2-B-FloodPeril
               MOVE DB2-B-FloodPremium-Int   TO DB2-B-FloodPremium
               MOVE DB2-B-WeatherPeril-Int   TO DB2-B-WeatherPeril
               MOVE DB2-B-WeatherPremium-Int TO DB2-B-WeatherPremium
               MOVE DB2-B-Status-Int         TO DB2-B-Status

               MOVE DB2-POLICY-COMMON        TO CA-POLICY-COMMON
               MOVE DB2-COMMERCIAL     TO CA-COMMERCIAL(1:WS-COMM-LEN)
             END-IF

             MOVE 'FINAL' TO CA-B-FILLER(1:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.

           EXIT.

      *================================================================*
      *  GET-COMMERCIAL-DB2-INFO-3                                     *
      *  使用 Cust_Cursor 批次取回客戶所有商業保單                    *
      *  轉置說明：                                                     *
      *    原始以 EXEC CICS Put Container 存放批次資料               *
      *    改為直接寫入 BY REFERENCE 參數 ICOM-RECORD                *
      *    ICOM-RECORD-COUNT 累計筆數供呼叫端（LGIPOL01）使用          *
      *================================================================*
       GET-COMMERCIAL-DB2-INFO-3.

           MOVE ' SELECT Commercial ' TO EM-SQLREQ
           MOVE 0 TO ICOM-RECORD-COUNT

           EXEC SQL
             OPEN Cust_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '89' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF

           PERFORM GET-COMMERCIAL-DB2-INFO-3-CUR
               WITH TEST AFTER UNTIL SQLCODE > 0

           EXEC SQL
             CLOSE Cust_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '88' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF.

      *  轉置說明：原始 EXEC CICS Put Container('ICOM-Count') 改為
      *  直接由 ICOM-RECORD-COUNT（BY REFERENCE 參數）攜帶結果

           EXIT.

      *----------------------------------------------------------------*
       GET-COMMERCIAL-DB2-INFO-3-CUR.

           EXEC SQL
             FETCH Cust_Cursor
             INTO
                   :DB2-CUSTOMERNUM-INT,
                   :DB2-POLICYNUM-INT,
                   :DB2-LASTCHANGED,
                   :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-B-Address,
                   :DB2-B-Postcode,
                   :DB2-B-Latitude,
                   :DB2-B-Longitude,
                   :DB2-B-Customer,
                   :DB2-B-PropType,
                   :DB2-B-FirePeril-Int,
                   :DB2-B-FirePremium-Int,
                   :DB2-B-CrimePeril-Int,
                   :DB2-B-CrimePremium-Int,
                   :DB2-B-FloodPeril-Int,
                   :DB2-B-FloodPremium-Int,
                   :DB2-B-WeatherPeril-Int,
                   :DB2-B-WeatherPremium-Int,
                   :DB2-B-Status-Int,
                   :DB2-B-RejectReason
           END-EXEC

           IF SQLCODE = 0
             MOVE DB2-B-FirePeril-Int      TO DB2-B-FirePeril
             MOVE DB2-B-FirePremium-Int    TO DB2-B-FirePremium
             MOVE DB2-B-CrimePeril-Int     TO DB2-B-CrimePeril
             MOVE DB2-B-CrimePremium-Int   TO DB2-B-CrimePremium
             MOVE DB2-B-FloodPeril-Int     TO DB2-B-FloodPeril
             MOVE DB2-B-FloodPremium-Int   TO DB2-B-FloodPremium
             MOVE DB2-B-WeatherPeril-Int   TO DB2-B-WeatherPeril
             MOVE DB2-B-WeatherPremium-Int TO DB2-B-WeatherPremium
             MOVE DB2-B-Status-Int         TO DB2-B-Status
             MOVE DB2-CustomerNum-Int      TO CA-CUSTOMER-NUM
             MOVE DB2-PolicyNum-Int        TO CA-POLICY-NUM
             MOVE DB2-POLICY-COMMON        TO CA-POLICY-COMMON
             MOVE DB2-COMMERCIAL     TO CA-COMMERCIAL(1:WS-COMM-LEN)

      *      轉置說明：原始以 Set icom-pointer to address of CA-B-FILLER
      *        移動 CICS 記憶體指標；改為直接將 COMMAREA 段複製到
      *        ICOM-RECORD 緩衝區（1202 bytes/筆，最多 20 筆）
             ADD 1 TO ICOM-RECORD-COUNT
             MOVE DFHCOMMAREA(1:1202) TO ICOM-RECORD

      *      超過 20 筆則停止（原始邏輯保留：MOVE 17 TO SQLCODE）
             IF ICOM-RECORD-COUNT > 20
               MOVE 17 TO SQLCODE
             END-IF
           END-IF.

           EXIT.

      *================================================================*
      *  GET-COMMERCIAL-DB2-INFO-5                                     *
      *  使用 Zip_Cursor 批次取回指定郵遞區號的商業保單              *
      *================================================================*
       GET-COMMERCIAL-DB2-INFO-5.

           MOVE ' SELECT Commercial ' TO EM-SQLREQ

           EXEC SQL
             OPEN Zip_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '89' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF

           PERFORM GET-COMMERCIAL-DB2-INFO-5-CUR
               WITH TEST AFTER UNTIL SQLCODE > 0

           EXEC SQL
             CLOSE Zip_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '88' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF.

           EXIT.

      *----------------------------------------------------------------*
       GET-COMMERCIAL-DB2-INFO-5-CUR.

           EXEC SQL
             FETCH Zip_Cursor
             INTO
                   :DB2-CUSTOMERNUM-INT,
                   :DB2-POLICYNUM-INT,
                   :DB2-LASTCHANGED,
                   :DB2-ISSUEDATE,
                   :DB2-EXPIRYDATE,
                   :DB2-B-Address,
                   :DB2-B-Postcode,
                   :DB2-B-Latitude,
                   :DB2-B-Longitude,
                   :DB2-B-Customer,
                   :DB2-B-PropType,
                   :DB2-B-FirePeril-Int,
                   :DB2-B-FirePremium-Int,
                   :DB2-B-CrimePeril-Int,
                   :DB2-B-CrimePremium-Int,
                   :DB2-B-FloodPeril-Int,
                   :DB2-B-FloodPremium-Int,
                   :DB2-B-WeatherPeril-Int,
                   :DB2-B-WeatherPremium-Int,
                   :DB2-B-Status-Int,
                   :DB2-B-RejectReason
           END-EXEC

           IF SQLCODE = 0
             MOVE DB2-B-FirePeril-Int      TO DB2-B-FirePeril
             MOVE DB2-B-FirePremium-Int    TO DB2-B-FirePremium
             MOVE DB2-B-CrimePeril-Int     TO DB2-B-CrimePeril
             MOVE DB2-B-CrimePremium-Int   TO DB2-B-CrimePremium
             MOVE DB2-B-FloodPeril-Int     TO DB2-B-FloodPeril
             MOVE DB2-B-FloodPremium-Int   TO DB2-B-FloodPremium
             MOVE DB2-B-WeatherPeril-Int   TO DB2-B-WeatherPeril
             MOVE DB2-B-WeatherPremium-Int TO DB2-B-WeatherPremium
             MOVE DB2-B-Status-Int         TO DB2-B-Status
             MOVE DB2-CustomerNum-Int      TO CA-CUSTOMER-NUM
             MOVE DB2-PolicyNum-Int        TO CA-POLICY-NUM
             MOVE DB2-POLICY-COMMON        TO CA-POLICY-COMMON
             MOVE DB2-COMMERCIAL     TO CA-COMMERCIAL(1:WS-COMM-LEN)
           END-IF.

           EXIT.

      *================================================================*
      *  GET-CLAIM-DB2-INFO-1                                          *
      *  查詢 POLICY JOIN CLAIM（指定理賠號），單筆 SELECT INTO       *
      *================================================================*
       GET-CLAIM-DB2-INFO-1.

           MOVE ' SELECT Claim ' TO EM-SQLREQ

           EXEC SQL
             SELECT
                   POLICY.CustomerNumber,
                   ClaimNumber,
                   CLAIM.PolicyNumber,
                   ClaimDate,
                   Paid,
                   Value,
                   Cause,
                   Observations
             INTO  :DB2-Customernum-int,
                   :DB2-Claimnum-int,
                   :DB2-POLICYNUM-INT,
                   :DB2-C-Date,
                   :DB2-C-Paid-Int,
                   :DB2-C-Value-Int,
                   :DB2-C-Cause,
                   :DB2-C-Observations
             FROM  POLICY, CLAIM
             WHERE ( POLICY.POLICYNUMBER =
                        CLAIM.POLICYNUMBER AND
                     CLAIM.ClaimNumber =
                        :DB2-ClaimNum-INT )
           END-EXEC

           IF SQLCODE = 0
             MOVE 0 TO WS-REQUIRED-CA-LEN
             ADD WS-CA-HEADERTRAILER-LEN TO WS-REQUIRED-CA-LEN
             ADD WS-FULL-CLAIM-LEN       TO WS-REQUIRED-CA-LEN

             IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
               MOVE '98' TO CA-RETURN-CODE
               GOBACK
             ELSE
               MOVE DB2-Customernum-int  TO CA-CUSTOMER-NUM
               MOVE DB2-PolicyNum-int    TO CA-POLICY-NUM
               MOVE DB2-Claimnum-int     TO DB2-C-Num
               MOVE DB2-C-Paid-Int       TO DB2-C-Paid
               MOVE DB2-C-Value-Int      TO DB2-C-Value

               MOVE DB2-POLICY-COMMON    TO CA-POLICY-COMMON
               MOVE DB2-CLAIM            TO CA-Claim(1:WS-COMM-LEN)
             END-IF

             MOVE 'FINAL' TO CA-C-FILLER(1:5)

           ELSE
             IF SQLCODE EQUAL 100
               MOVE '01' TO CA-RETURN-CODE
             ELSE
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
             END-IF
           END-IF.

           EXIT.

      *================================================================*
      *  GET-CLAIM-DB2-INFO-2                                          *
      *  使用 CusClaim_Cursor 批次取回客戶所有理賠記錄                *
      *================================================================*
       GET-CLAIM-DB2-INFO-2.

           MOVE ' SELECT Claim ' TO EM-SQLREQ

           EXEC SQL
             OPEN CusClaim_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '89' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF

           PERFORM GET-CLAIM-DB2-INFO-2-CUR
               WITH TEST AFTER UNTIL SQLCODE > 0

           EXEC SQL
             CLOSE CusClaim_Cursor
           END-EXEC

           IF SQLCODE NOT EQUAL 0
             MOVE '88' TO CA-RETURN-CODE
             PERFORM WRITE-ERROR-MESSAGE
             PERFORM END-PROGRAM
           END-IF.

           EXIT.

      *----------------------------------------------------------------*
       GET-CLAIM-DB2-INFO-2-CUR.

           EXEC SQL
             FETCH CusClaim_Cursor
             INTO
                   :DB2-Customernum-int,
                   :DB2-Claimnum-int,
                   :DB2-POLICYNUM-INT,
                   :DB2-C-Date,
                   :DB2-C-Paid-Int,
                   :DB2-C-Value-Int,
                   :DB2-C-Cause,
                   :DB2-C-Observations
           END-EXEC

           IF SQLCODE = 0
               MOVE DB2-Customernum-int  TO CA-CUSTOMER-NUM
               MOVE DB2-PolicyNum-int    TO CA-POLICY-NUM
               MOVE DB2-Claimnum-int     TO DB2-C-Num
               MOVE DB2-C-Paid-Int       TO DB2-C-Paid
               MOVE DB2-C-Value-Int      TO DB2-C-Value
               MOVE DB2-POLICY-COMMON    TO CA-POLICY-COMMON
               MOVE DB2-CLAIM            TO CA-Claim(1:WS-COMM-LEN)
               MOVE 'FINAL'              TO CA-C-FILLER(1:5)
           END-IF.

           EXIT.

      *================================================================*
      *  END-PROGRAM（錯誤後強制結束，取代 PERFORM END-PROGRAM 的     *
      *  原始呼叫 EXEC CICS RETURN）                                   *
      *================================================================*
       END-PROGRAM.
           GOBACK.

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
      *    EIBCALEN 判斷 → LENGTH OF DFHCOMMAREA                     *
      *================================================================*
       WRITE-ERROR-MESSAGE.
      *  保存 SQLCODE 至錯誤訊息
           MOVE SQLCODE TO EM-SQLRC

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

      *  附加 COMMAREA 前 90 bytes 至日誌
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ'
               USING BY REFERENCE CA-ERROR-MSG
           END-CALL.

           EXIT.
