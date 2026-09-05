      ******************************************************************
      *                                                                *
      * 批次匯入工具  ─  從循序檔讀入客戶資料並 INSERT 進 DB2             *
      *                                                                *
      * 原始程式: NEWCUST.cbl (獨立批次程式)                             *
      * 轉置目標: ACUCOBOL-GT v11.0 (AcuSQL 兩階段編譯)                 *
      *                                                                *
      * 功能說明:                                                       *
      *   1. 開啟循序輸入檔（INFILE）                                    *
      *   2. 讀取一筆客戶記錄（140 bytes）                               *
      *   3. INSERT 進 DB2 CUSTOMER 資料表                             *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC SQL INCLUDE CUSTOMER  → COPY "CUSTOMER.def"            *
      *     （AcuSQL 預處理器將 CUSTOMER 宣告展開為 DCLCUSTOMER）        *
      *   EXEC SQL INCLUDE SQLCA     → COPY "sqlca.def"               *
      *   RECORDING MODE IS F / LABEL RECORDS STANDARD                *
      *     → 移除（ACUCOBOL 不支援 z/OS 特定子句）                      *
      *   BLOCK CONTAINS 0 RECORDS   → 移除（同上）                    *
      *   GOBACK                     → 保留（ACUCOBOL 支援）            *
      *                                                                *
      * 注意：本程式需 AcuSQL 預處理                                      *
      *   步驟一: acusql NEWCUST.cbl NEWCUST.cbl.i                    *
      *   步驟二: ccbl32 -Da4 NEWCUST.cbl.i                           *
      *                                                                *
      * 執行方式:                                                       *
      *   設定環境變數 INFILE 指向輸入資料檔，例如：                        *
      *   export INFILE=/data/newcust.dat && acurun NEWCUST            *
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 C] ACCEPT FROM ENVIRONMENT (手冊 p.190 Format 5)      *
      *     ─ 可用 GENAPP_DB_SERVER 等覆蓋 DB2 連線參數                 *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. NEWCUST.

       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
      *----------------------------------------------------------------*
      * 循序輸入檔
      *   原始: ASSIGN TO INFILE
      *   ACUCOBOL: 執行時由環境變數 INFILE 指定路徑
      *----------------------------------------------------------------*
           SELECT INPUT01-FILE ASSIGN TO INFILE
               ORGANIZATION IS SEQUENTIAL
               ACCESS MODE IS SEQUENTIAL
               FILE STATUS IS FS-INPUT01.

       DATA DIVISION.
       FILE SECTION.
      *----------------------------------------------------------------*
      * 移除 z/OS 特定子句:
      *   RECORDING MODE IS F  → 不適用（ACUCOBOL 不支援）
      *   LABEL RECORDS STANDARD → 不適用
      *   BLOCK CONTAINS 0 RECORDS → 不適用
      *   DATA RECORD IS IN-REC  → 保留（ACUCOBOL 支援但可省略）
      *----------------------------------------------------------------*
       FD  INPUT01-FILE
           RECORD CONTAINS 140 CHARACTERS.
       01 IN-REC                                PIC X(140).

       WORKING-STORAGE SECTION.

       01 FS-FILE-STATUS.
          05 FS-INPUT01                         PIC X(02) VALUE SPACES.
             88 INP-OK                                    VALUE '00'.

       01 WS-SWITCHES.
          05 WS-EOF-INP                         PIC X(01) VALUE ' '.
            88 END-OF-INP                                 VALUE 'Y'.

       01 WS-IN-REC.
          05 IN-CUST-NUMBER                     PIC 9(10).
          05 IN-CUST-FNAME                      PIC X(10) VALUE SPACES.
          05 IN-CUST-LNAME                      PIC X(10) VALUE SPACES.
          05 IN-CUST-DOB                        PIC X(10) VALUE SPACES.
          05 IN-CUST-HOUSENAME                  PIC X(20) VALUE SPACES.
          05 IN-CUST-HOUSENBR                   PIC X(04) VALUE SPACES.
          05 IN-CUST-POSTCODE                   PIC X(08) VALUE SPACES.
          05 IN-CUST-PHONEHOME                  PIC X(10) VALUE SPACES.
          05 IN-CUST-PHONEMOBILE                PIC X(10) VALUE SPACES.
          05 IN-CUST-EMAIL                      PIC X(40) VALUE SPACES.
          05 FILLER                             PIC X(08) VALUE SPACES.

       01 WS-DISPLAY-STATUS-PGM                 PIC X(08) VALUE 'DISPSTAT'.
       01 WS-STATUS-CODE                        PIC 9(04) VALUE 0000.

      *----------------------------------------------------------------*
      * AcuSQL: COPY "CUSTOMER.def" 取代 EXEC SQL INCLUDE CUSTOMER
      *   AcuSQL 預處理後產生 DCLCUSTOMER 結構，程式直接引用
      *   DCL-CUSTOMERNUMBER, DCL-FIRSTNAME ... 等 Host Variable
      *----------------------------------------------------------------*
           COPY "CUSTOMER.def".

      *----------------------------------------------------------------*
      * AcuSQL: COPY "sqlca.def" 取代 EXEC SQL INCLUDE SQLCA
      *----------------------------------------------------------------*
           COPY "sqlca.def".

       PROCEDURE DIVISION.
       0001-MAIN.

           DISPLAY 'START OF PROGRAM'
           PERFORM 1000-INITIALIZATION
              THRU 1000-EXIT
           PERFORM 1500-READ-INPUT
              THRU 1500-EXIT

           IF NOT END-OF-INP
              PERFORM 2000-MAIN-PARA
                 THRU 2000-EXIT
           END-IF

           PERFORM 9000-END-PARA
           .
       0001-MAIN-EXIT.
           EXIT.

       1000-INITIALIZATION.
           INITIALIZE WS-SWITCHES
           PERFORM 1100-OPEN-FILES
              THRU 1100-EXIT
           .
       1000-EXIT.
           EXIT.

       1100-OPEN-FILES.

           OPEN INPUT INPUT01-FILE

           IF NOT INP-OK
              DISPLAY '1100-OPEN-FILES:'
              DISPLAY 'INVALID FILE STATUS ON OPEN INPUT:' FS-INPUT01
              PERFORM 9000-END-PARA
           END-IF
           .
       1100-EXIT.
           EXIT.

       1500-READ-INPUT.

           READ INPUT01-FILE INTO WS-IN-REC
                AT END SET END-OF-INP TO TRUE.

           IF NOT INP-OK AND NOT END-OF-INP
              DISPLAY 'INVALID FILE STATUS ON READ:' FS-INPUT01
              PERFORM 9000-END-PARA
           END-IF
           .
       1500-EXIT.
           EXIT.

       2000-MAIN-PARA.

           INITIALIZE DCLCUSTOMER.
           MOVE IN-CUST-NUMBER   TO DCL-CUSTOMERNUMBER
           MOVE IN-CUST-FNAME    TO DCL-FIRSTNAME
           MOVE IN-CUST-LNAME    TO DCL-LASTNAME
           MOVE IN-CUST-DOB      TO DCL-DATEOFBIRTH
           MOVE IN-CUST-HOUSENAME
                                 TO DCL-HOUSENAME
           MOVE IN-CUST-HOUSENBR TO DCL-HOUSENUMBER
           MOVE IN-CUST-POSTCODE TO DCL-POSTCODE
           MOVE IN-CUST-PHONEHOME
                                 TO DCL-PHONEHOME
           MOVE IN-CUST-PHONEMOBILE
                                 TO DCL-PHONEMOBILE
           MOVE IN-CUST-EMAIL    TO DCL-EMAILADDRESS
      *
      *   原始注解中的 POSTCODE 修改邏輯（保留原始注解）:
      *   IF DCL-POSTCODE (1:2) = 'GB'
      *      MOVE '44' TO  DCL-HOUSENUMBER(1:4)
      *   END-IF
      *
      *   原始注解中的 Bug 注入程式碼（保留原始注解）:
      *   MOVE 99 TO DCL-CUSTOMERNUMBER
      *
           PERFORM 3000-INS-CUST-DETAILS
              THRU 3000-EXIT
            .
       2000-EXIT.
           EXIT.

       3000-INS-CUST-DETAILS.
           DISPLAY 'IN 3000:'

           EXEC SQL
               INSERT INTO CUSTOMER
               (CUSTOMERNUMBER
               ,FIRSTNAME
               ,LASTNAME
               ,DATEOFBIRTH
               ,HOUSENAME
               ,HOUSENUMBER
               ,POSTCODE
               ,PHONEHOME
               ,PHONEMOBILE
               ,EMAILADDRESS)
               VALUES (
                     :DCL-CUSTOMERNUMBER
                    ,:DCL-FIRSTNAME
                    ,:DCL-LASTNAME
                    ,:DCL-DATEOFBIRTH
                    ,:DCL-HOUSENAME
                    ,:DCL-HOUSENUMBER
                    ,:DCL-POSTCODE
                    ,:DCL-PHONEHOME
                    ,:DCL-PHONEMOBILE
                    ,:DCL-EMAILADDRESS)
           END-EXEC.

           DISPLAY 'SQLCODE:' SQLCODE
           EVALUATE SQLCODE
             WHEN 0
               DISPLAY 'SUCCESSFUL INSERT'
             WHEN OTHER
               MOVE 0001 TO WS-STATUS-CODE
               DISPLAY 'INVALID SQLCODE:' SQLCODE
               PERFORM 9000-END-PARA
           END-EVALUATE.

       3000-EXIT.
           EXIT.

       9000-END-PARA.

           GOBACK
           .
       9000-EXIT.
           EXIT.
