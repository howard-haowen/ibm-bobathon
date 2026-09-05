      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGACDB01.cbl (IBM COBOL / CICS / DB2 / z/OS)       *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：新增客戶 — DB2 存取層                                   *
      *        取得流水號、INSERT CUSTOMER、呼叫 LGACVS01 + LGACDB02  *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Get Counter     → IS EXTERNAL 共用計數區          *
      *      (GENAcount / GENApool)    手冊 p.90 IS EXTERNAL Clause    *
      *    EXEC CICS LINK Program    → CALL ... USING BY REFERENCE     *
      *                                RETURNING                       *
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
      *    EXEC SQL INCLUDE SQLCA    → COPY "sqlca.def"               *
      *    EXEC SQL INCLUDE LGCMAREA → COPY LGCMAREA                   *
      *      (LINKAGE SECTION)                                         *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *      PIC S9(4) COMP VALUE      手冊 p.34 Level 78 Data Items   *
      *    77 LGACDB02/LGACVS01      → 移除（CALL literal 直接使用）  *
      *                                                                *
      *  ACUCOBOL-GT 特有特性展示：                                     *
      *    特性 B：ACCEPT FROM CENTURY-DATE / TIME（p.190 Format 3）   *
      *    特性 C：ACCEPT FROM ENVIRONMENT（p.190 Format 5）           *
      *    特性 D：Level 78 編譯期常數（p.34）                         *
      *    特性 E：CALL ... USING BY REFERENCE RETURNING（p.217）      *
      *    特性 F：IS EXTERNAL 跨程式共用資料（p.90）                  *
      *            取代 EXEC CICS Get Counter (GENAcount)              *
      *                                                                *
      *  CICS Get Counter 轉換說明：                                    *
      *    原始程式呼叫 EXEC CICS Get Counter(GENACUSTNUM)             *
      *      Pool(GENA) 取得遞增的客戶流水號。                         *
      *    轉置後改為 IS EXTERNAL PIC S9(9) COMP 的共用計數區，        *
      *    由 LGSETUP 初始化，各執行緒透過 IS EXTERNAL 存取相同記憶體。*
      *    WS-RESP 判斷改為：若初始值 = 0 則視為未初始化（NCS 模式）。*
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGACDB01.
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
                                        VALUE 'LGACDB01------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-FILLER                PIC X      VALUE SPACES.
           03 WS-CALEN                 PIC S9(4) COMP VALUE 0.

      *  時間日期暫存
       01  WS-ABSTIME                  PIC S9(8) COMP VALUE +0.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.
       01  WS-DATE                     PIC X(8)   VALUE SPACES.

      *----------------------------------------------------------------*
      *  錯誤訊息結構                                                   *
      *----------------------------------------------------------------*
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)   VALUE SPACES.
           03 FILLER                   PIC X      VALUE SPACES.
           03 EM-TIME                  PIC X(6)   VALUE SPACES.
           03 FILLER                   PIC X(9)   VALUE ' LGACDB01'.
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
      *  CDB2AREA — 呼叫 LGACDB02（客戶秘密資料 DB2 層）              *
      *----------------------------------------------------------------*
       01  CDB2AREA.
           03 D2-REQUEST-ID            PIC X(6).
           03 D2-RETURN-CODE           PIC 9(2).
           03 D2-CUSTOMER-NUM          PIC 9(10).
           03 D2-CUSTSECR-PASS         PIC X(32).
           03 D2-CUSTSECR-COUNT        PIC X(4).
           03 D2-CUSTSECR-STATE        PIC X.
           03 D2-CUSTSECR-DATA         PIC X(32445).

      *----------------------------------------------------------------*
      *  Level 78 編譯期常數                                           *
      *  手冊依據：Reference Manual p.34 Level 78 Data Items          *
      *  轉置說明：取代 WS-COMMAREA-LENGTHS 群組中的執行期常數        *
      *----------------------------------------------------------------*
       78  WS-CA-HEADER-LEN            VALUE 18.

      *  COMMAREA 長度暫存（執行期計算用）
       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *  LGPOLICY copybook 提供 WS-CUSTOMER-LEN 等 Level 78 常數
           COPY LGPOLICY.

      *----------------------------------------------------------------*
      *  IS EXTERNAL 共用計數區                                        *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *  轉置說明：取代 EXEC CICS Get Counter(GENACUSTNUM) Pool(GENA) *
      *                                                                *
      *  原始：CICS Named Counter Service 自動遞增                    *
      *  轉置：IS EXTERNAL 允許多個程式（LGSETUP + LGACDB01）共用      *
      *        同一 PIC S9(9) COMP 記憶體區塊，達到全域計數效果。     *
      *        LGSETUP 負責初始化（從 DB2 取最大客戶號後設定）。      *
      *        LGACDB01 每次呼叫時讀取並遞增。                        *
      *        注意：多執行緒環境需搭配 $SET LOCK 或序列化機制。      *
      *----------------------------------------------------------------*
       01  GENA-CUSTOMER-COUNTER       PIC S9(9) COMP
                                        VALUE 0
                                        IS EXTERNAL.

      *  NCS 模式旗標（CICS Named Counter Service 可用性）
      *  轉置說明：原始 LGAC-NCS 控制是否使用計數器取得的流水號       *
      *  ACUCOBOL 版：'ON' = IS EXTERNAL 計數器就緒；'NO' = 使用 DEFAULT
       01  LGAC-NCS                    PIC X(2)   VALUE 'ON'.
       01  LastCustNum                 PIC S9(9) COMP VALUE 0.

      *  CALL RETURNING 接收子程式回傳碼
       01  WS-DB-RETURN-CODE           PIC 9(2)   VALUE 0.

      *----------------------------------------------------------------*
      *  安全密碼預設值（原樣保留）                                    *
      *----------------------------------------------------------------*
       77  WS-CS-PASSWORD              PIC X(16)  VALUE 'NewPass'.
       77  WS-CS-STATE                 PIC X      VALUE 'N'.
       77  WS-CA-COUNT                 PIC S9(9) COMP VALUE 0.

      *  DB2 宿主變數 — 客戶號整數
       01  DB2-OUT-INTEGERS.
           03 DB2-CUSTOMERNUM-INT      PIC S9(9) COMP VALUE 0.

      *  轉置說明：EXEC SQL INCLUDE SQLCA → COPY "sqlca.def"
           COPY "sqlca.def".

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
                   MOVE 'LGAC' TO WS-TRANSID
           END-ACCEPT

           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION
                   MOVE 'ACU1' TO WS-TERMID
           END-ACCEPT

           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION
                   MOVE 0 TO WS-TASKNUM
           END-ACCEPT

           INITIALIZE DB2-OUT-INTEGERS.

      *  驗證 COMMAREA 已傳入
           IF DFHCOMMAREA = SPACES
               MOVE ' NO COMMAREA RECEIVED' TO EM-VARIABLE
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGACDB01: ABEND - NO COMMAREA RECEIVED'
                   UPON SYSERR
               STOP RUN
           END-IF

           MOVE '00' TO CA-RETURN-CODE

      *  COMMAREA 長度驗證
           ADD WS-CA-HEADER-LEN TO WS-REQUIRED-CA-LEN
           ADD WS-CUSTOMER-LEN  TO WS-REQUIRED-CA-LEN

           IF LENGTH OF DFHCOMMAREA < WS-REQUIRED-CA-LEN
             MOVE '98' TO CA-RETURN-CODE
             GOBACK
           END-IF

      *  取得客戶流水號並新增客戶
           PERFORM Obtain-CUSTOMER-Number
           PERFORM INSERT-CUSTOMER

      *----------------------------------------------------------------*
      *  呼叫 LGACVS01（VSAM 層，保留原始呼叫）                       *
      *  轉置說明：原始此呼叫已標記停用但仍存在                        *
      *    EXEC CICS LINK Program(LGACVS01) → CALL 'LGACVS01'         *
      *    手冊依據：Reference Manual p.217 CALL Statement            *
      *----------------------------------------------------------------*
           CALL 'LGACVS01'
               USING     BY REFERENCE DFHCOMMAREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL

      *  準備 LGACDB02 呼叫參數（客戶安全資料 DB2 層）
           MOVE DB2-CUSTOMERNUM-INT TO D2-CUSTOMER-NUM
           MOVE '02ACUS' TO D2-REQUEST-ID
           MOVE '5732fec825535eeafb8fac50fee3a8aa'
                              TO D2-CUSTSECR-PASS
           MOVE '0000'        TO D2-CUSTSECR-COUNT
           MOVE 'N'           TO D2-CUSTSECR-STATE

      *----------------------------------------------------------------*
      *  呼叫 LGACDB02（客戶安全資料新增）                             *
      *  手冊依據：Reference Manual p.217 CALL Statement              *
      *----------------------------------------------------------------*
           CALL 'LGACDB02'
               USING     BY REFERENCE CDB2AREA
               RETURNING WS-DB-RETURN-CODE
           END-CALL

           IF CA-RETURN-CODE NOT EQUAL 0
             GOBACK
           END-IF

      *  轉置說明：取代 EXEC CICS RETURN
           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  Obtain-CUSTOMER-Number                                        *
      *                                                                *
      *  轉置說明：取代 EXEC CICS Get Counter(GENACUSTNUM) Pool(GENA) *
      *                                                                *
      *  特性 F 展示：IS EXTERNAL 跨程式共用資料                      *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *                                                                *
      *  GENA-CUSTOMER-COUNTER 宣告為 IS EXTERNAL，允許 LGSETUP 和    *
      *  LGACDB01 共用同一記憶體位址。LGSETUP 啟動時讀取 DB2 最大客   *
      *  戶號後設定初始值；LGACDB01 每次呼叫時讀取並遞增一。          *
      *  若初始值 = 0，視為計數器未初始化（NCS 停用模式）。           *
      *================================================================*
       Obtain-CUSTOMER-Number.

      *  讀取 IS EXTERNAL 共用計數區（取代 CICS Get Counter）
           IF GENA-CUSTOMER-COUNTER = 0
      *      計數器未初始化 → NCS 停用模式（使用 DB2 DEFAULT IDENTITY）
               MOVE 'NO' TO LGAC-NCS
               INITIALIZE DB2-CUSTOMERNUM-INT
           ELSE
      *      計數器已就緒 → 取得目前值並遞增
               MOVE GENA-CUSTOMER-COUNTER TO LastCustNum
               ADD 1 TO GENA-CUSTOMER-COUNTER
               MOVE LastCustNum TO DB2-CUSTOMERNUM-INT
           END-IF.

       Obtain-CUSTOMER-Number-EXIT.
           EXIT.

      *================================================================*
      *  INSERT-CUSTOMER                                               *
      *  INSERT INTO CUSTOMER（兩路徑：指定流水號 vs DB2 DEFAULT）    *
      *================================================================*
       INSERT-CUSTOMER.

           MOVE ' INSERT CUSTOMER' TO EM-SQLREQ

           IF LGAC-NCS = 'ON'
      *      使用 IS EXTERNAL 計數器提供的客戶號
             EXEC SQL
               INSERT INTO CUSTOMER
                         ( CUSTOMERNUMBER,
                           FIRSTNAME,
                           LASTNAME,
                           DATEOFBIRTH,
                           HOUSENAME,
                           HOUSENUMBER,
                           POSTCODE,
                           PHONEMOBILE,
                           PHONEHOME,
                           EMAILADDRESS )
                  VALUES ( :DB2-CUSTOMERNUM-INT,
                           :CA-FIRST-NAME,
                           :CA-LAST-NAME,
                           :CA-DOB,
                           :CA-HOUSE-NAME,
                           :CA-HOUSE-NUM,
                           :CA-POSTCODE,
                           :CA-PHONE-MOBILE,
                           :CA-PHONE-HOME,
                           :CA-EMAIL-ADDRESS )
             END-EXEC
             IF SQLCODE NOT EQUAL 0
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
             END-IF
           ELSE
      *      NCS 停用：使用 DB2 IDENTITY DEFAULT 自動產生流水號
             EXEC SQL
               INSERT INTO CUSTOMER
                         ( CUSTOMERNUMBER,
                           FIRSTNAME,
                           LASTNAME,
                           DATEOFBIRTH,
                           HOUSENAME,
                           HOUSENUMBER,
                           POSTCODE,
                           PHONEMOBILE,
                           PHONEHOME,
                           EMAILADDRESS )
                  VALUES ( DEFAULT,
                           :CA-FIRST-NAME,
                           :CA-LAST-NAME,
                           :CA-DOB,
                           :CA-HOUSE-NAME,
                           :CA-HOUSE-NUM,
                           :CA-POSTCODE,
                           :CA-PHONE-MOBILE,
                           :CA-PHONE-HOME,
                           :CA-EMAIL-ADDRESS )
             END-EXEC
             IF SQLCODE NOT EQUAL 0
               MOVE '90' TO CA-RETURN-CODE
               PERFORM WRITE-ERROR-MESSAGE
               GOBACK
             END-IF
      *      取回 DB2 自動產生的客戶號
             EXEC SQL
               SET :DB2-CUSTOMERNUM-INT = IDENTITY_VAL_LOCAL()
             END-EXEC
           END-IF.

           MOVE DB2-CUSTOMERNUM-INT TO CA-CUSTOMER-NUM.

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
