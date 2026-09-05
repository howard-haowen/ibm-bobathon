      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGPOLICY.cpy (IBM COBOL / z/OS)                    *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  轉置變更：                                                     *
      *    - WS-POLICY-LENGTHS 群組項目中的 PIC S9(4) COMP VALUE 常數  *
      *      改寫為 Level 78 編譯期常數                                 *
      *      依據：手冊 p.34 $SET CONSTANT / Level 78 data items        *
      *      原因：Level 78 為編譯期解析，無執行期記憶體配置，           *
      *            消除原群組項目 WS-POLICY-LENGTHS 的存在必要性        *
      *    - DB2-* 資料結構原樣保留（ESQL 路徑維持不變）               *
      *                                                                *
      ******************************************************************
      *
      *================================================================*
      *  長度常數定義 (Level 78 編譯期常數)                             *
      *  手冊依據：Reference Manual p.34 $SET CONSTANT                 *
      *           / Level 78 Data Item                                 *
      *================================================================*
       78  WS-CUSTOMER-LEN          VALUE 72.
       78  WS-POLICY-LEN            VALUE 72.
       78  WS-ENDOW-LEN             VALUE 52.
       78  WS-HOUSE-LEN             VALUE 58.
       78  WS-MOTOR-LEN             VALUE 65.
       78  WS-COMM-LEN              VALUE 1102.
       78  WS-CLAIM-LEN             VALUE 546.
       78  WS-FULL-ENDOW-LEN        VALUE 124.
       78  WS-FULL-HOUSE-LEN        VALUE 130.
       78  WS-FULL-MOTOR-LEN        VALUE 137.
       78  WS-FULL-COMM-LEN         VALUE 1174.
       78  WS-FULL-CLAIM-LEN        VALUE 618.
       78  WS-SUMRY-ENDOW-LEN       VALUE 25.
      *
      *================================================================*
      *  DB2 宿主變數結構 (原樣保留，ESQL 路徑使用)                    *
      *================================================================*
       01  DB2-CUSTOMER.
           03 DB2-FIRSTNAME            PIC X(10).
           03 DB2-LASTNAME             PIC X(20).
           03 DB2-DATEOFBIRTH          PIC X(10).
           03 DB2-HOUSENAME            PIC X(20).
           03 DB2-HOUSENUMBER          PIC X(4).
           03 DB2-POSTCODE             PIC X(8).
           03 DB2-PHONE-MOBILE         PIC X(20).
           03 DB2-PHONE-HOME           PIC X(20).
           03 DB2-EMAIL-ADDRESS        PIC X(100).

       01  DB2-POLICY.
           03 DB2-POLICYTYPE           PIC X.
           03 DB2-POLICYNUMBER         PIC 9(10).
           03 DB2-POLICY-COMMON.
              05 DB2-ISSUEDATE         PIC X(10).
              05 DB2-EXPIRYDATE        PIC X(10).
              05 DB2-LASTCHANGED       PIC X(26).
              05 DB2-BROKERID          PIC 9(10).
              05 DB2-BROKERSREF        PIC X(10).
              05 DB2-PAYMENT           PIC 9(6).

       01  DB2-ENDOWMENT.
           03 DB2-ENDOW-FIXED.
              05 DB2-E-WITHPROFITS      PIC X.
              05 DB2-E-EQUITIES         PIC X.
              05 DB2-E-MANAGEDFUND      PIC X.
              05 DB2-E-FUNDNAME         PIC X(10).
              05 DB2-E-TERM             PIC 9(2).
              05 DB2-E-SUMASSURED       PIC 9(6).
              05 DB2-E-LIFEASSURED      PIC X(31).
           03 DB2-E-PADDINGDATA         PIC X(32611).

       01  DB2-HOUSE.
           03 DB2-H-PROPERTYTYPE       PIC X(15).
           03 DB2-H-BEDROOMS           PIC 9(3).
           03 DB2-H-VALUE              PIC 9(8).
           03 DB2-H-HOUSENAME          PIC X(20).
           03 DB2-H-HOUSENUMBER        PIC X(4).
           03 DB2-H-POSTCODE           PIC X(8).

       01  DB2-MOTOR.
           03 DB2-M-MAKE               PIC X(15).
           03 DB2-M-MODEL              PIC X(15).
           03 DB2-M-VALUE              PIC 9(6).
           03 DB2-M-REGNUMBER          PIC X(7).
           03 DB2-M-COLOUR             PIC X(8).
           03 DB2-M-CC                 PIC 9(4).
           03 DB2-M-MANUFACTURED       PIC X(10).
           03 DB2-M-PREMIUM            PIC 9(6).
           03 DB2-M-ACCIDENTS          PIC 9(6).

       01  DB2-COMMERCIAL.
           03 DB2-B-Address            PIC X(255).
           03 DB2-B-Postcode           PIC X(8).
           03 DB2-B-Latitude           PIC X(11).
           03 DB2-B-Longitude          PIC X(11).
           03 DB2-B-Customer           PIC X(255).
           03 DB2-B-PropType           PIC X(255).
           03 DB2-B-FirePeril          PIC 9(4).
           03 DB2-B-FirePremium        PIC 9(8).
           03 DB2-B-CrimePeril         PIC 9(4).
           03 DB2-B-CrimePremium       PIC 9(8).
           03 DB2-B-FloodPeril         PIC 9(4).
           03 DB2-B-FloodPremium       PIC 9(8).
           03 DB2-B-WeatherPeril       PIC 9(4).
           03 DB2-B-WeatherPremium     PIC 9(8).
           03 DB2-B-Status             PIC 9(4).
           03 DB2-B-RejectReason       PIC X(255).

       01  DB2-CLAIM.
           03 DB2-C-Num                PIC 9(10).
           03 DB2-C-Date               PIC X(10).
           03 DB2-C-Paid               PIC 9(8).
           03 DB2-C-Value              PIC 9(8).
           03 DB2-C-Cause              PIC X(255).
           03 DB2-C-Observations       PIC X(255).
