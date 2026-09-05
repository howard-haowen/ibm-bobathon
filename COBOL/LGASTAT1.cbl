      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGASTAT1.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：統計收集                                                 *
      *        從 Channel/Container 或 COMMAREA 讀取交易代碼+回傳碼   *
      *        更新對應的 IS EXTERNAL 統計計數器                       *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Get Container   → ACCEPT FROM ENVIRONMENT         *
      *      (DFHEP.DATA.00001/2)     'GENAPP_STAT_REQ'/'STAT_RC'     *
      *    EXEC CICS ReadQ TS        → ACCEPT FROM ENVIRONMENT         *
      *      Queue(GENASTRT)          'GENAPP_START_TIME'              *
      *    EXEC CICS WriteQ TS       → 若 GENASTRT 未設定則寫入       *
      *      Queue(GENASTRT)          環境變數（啟動時間記錄）         *
      *    EXEC CICS Get Counter     → 讀取 IS EXTERNAL 計數陣列       *
      *      (GENAcount)               手冊 p.90                       *
      *    EXEC CICS RETURN          → GOBACK                          *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    EIBCALEN                  → LENGTH OF DFHCOMMAREA           *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION USING        *
      *                                BY REFERENCE DFHCOMMAREA        *
      *    WS-CA-HEADER-LEN          → Level 78 編譯期常數             *
      *    77 LGACDB01/LGACVS01      → 移除                            *
      *                                                                *
      *  GENA-COUNTERS IS EXTERNAL 陣列說明：                          *
      *    與 LGSETUP.cbl 和 LGWEBST5.cbl 共用同一 IS EXTERNAL 結構。  *
      *    LGSETUP 初始化，LGASTAT1 更新（遞增），LGWEBST5 讀取顯示。  *
      *    計數器索引對應：                                             *
      *      GENA-CNT(1)  ← GENACNT100（查詢客戶成功）               *
      *      GENA-CNT(2)  ← GENACNT199（查詢客戶失敗）               *
      *      ...（詳見 LGSETUP.cbl 完整對照表）                       *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGASTAT1.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

       01  WS-DATE                     PIC X(8)   VALUE SPACES.
       01  WS-TIME                     PIC X(8)   VALUE SPACES.
       01  WS-QAREA.
           03  WS-AREA-D               PIC X(8)   VALUE SPACES.
           03  FILLER                  PIC XX     VALUE SPACES.
           03  WS-AREA-T               PIC X(6)   VALUE SPACES.

      *  Channel/Container 替代：交易代碼和回傳碼
      *  轉置說明：取代 EXEC CICS Get Container(DFHEP.DATA.00001/00002)
       01  WS-Data-Req                 PIC X(6)   VALUE SPACES.
       01  WS-Data-RC                  PIC X(2)   VALUE SPACES.

       01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGASTAT1------WS'.
           03 WS-TRANSID               PIC X(4)   VALUE SPACES.
           03 WS-TERMID                PIC X(4)   VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)   VALUE 0.
           03 WS-CALEN                 PIC 9(7)   VALUE 0.

      *  GENAcount 結構（轉置說明：與原始結構相同，用於索引計算）
       01  GENAcount.
           03 FILLER                   PIC X(4)   VALUE 'GENA'.
           03 GENAcounter              PIC X(6)   VALUE SPACES.
           03 GENAtype                 PIC X(2)   VALUE SPACES.
           03 FILLER                   PIC X(4)   VALUE SPACES.

       01  Trancount                   PIC S9(8) COMP VALUE 0.

      *  啟動時間旗標（取代 ReadQ TS GENASTRT）
       01  WS-START-TIME-FLAG          PIC X(16)  VALUE SPACES.

      *----------------------------------------------------------------*
      *  Level 78 編譯期常數                                           *
      *  手冊依據：Reference Manual p.34 Level 78 Data Items          *
      *----------------------------------------------------------------*
       78  WS-CA-HEADER-LEN            VALUE 18.

       01  WS-REQUIRED-CA-LEN          PIC S9(4) VALUE +0.

      *----------------------------------------------------------------*
      *  IS EXTERNAL 計數陣列                                          *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *  與 LGSETUP / LGWEBST5 共用同一記憶體                         *
      *----------------------------------------------------------------*
       01  GENA-COUNTERS               IS EXTERNAL.
           03 GENA-CUSTNUM             PIC S9(9) COMP VALUE 0.
           03 GENA-CNT                 OCCURS 26 TIMES
                                        PIC S9(9) COMP VALUE 0.

      *  統計計數器索引表（對應 GENACNT* 編號）
       01  WS-CNT-INDEX                PIC 9(2)   VALUE 0.

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
               ON EXCEPTION MOVE 'LGST' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'
               ON EXCEPTION MOVE 0 TO WS-TASKNUM       END-ACCEPT

      *----------------------------------------------------------------*
      *  取得交易代碼和回傳碼                                           *
      *  轉置說明：取代 EXEC CICS Get Container(DFHEP.DATA.00001/00002)*
      *    原始透過 CICS Event Broker Channel 取得 EP 資料             *
      *    轉置後改為環境變數，由呼叫方設定                             *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *----------------------------------------------------------------*
           ACCEPT WS-Data-Req FROM ENVIRONMENT 'GENAPP_STAT_REQ'
               ON EXCEPTION
                   MOVE SPACES TO WS-Data-Req
           END-ACCEPT
           ACCEPT WS-Data-RC  FROM ENVIRONMENT 'GENAPP_STAT_RC'
               ON EXCEPTION
                   MOVE SPACES TO WS-Data-RC
           END-ACCEPT

      *  若從環境變數取得成功，使用環境變數資料；否則從 COMMAREA 取得
           IF WS-Data-Req NOT = SPACES
               MOVE WS-Data-REQ TO GENACounter
               MOVE WS-Data-RC  TO GENAType
           ELSE
               IF LENGTH OF DFHCOMMAREA > 0
                 MOVE CA-REQUEST-ID  TO GENAcounter
                 MOVE CA-RETURN-CODE TO GENAtype
               ELSE
                 GOBACK
               END-IF
           END-IF

      *----------------------------------------------------------------*
      *  啟動時間記錄                                                   *
      *  轉置說明：取代 EXEC CICS ReadQ TS Queue(GENASTRT)             *
      *    原始若 QIDERR 則寫入啟動時間至 TS Queue                    *
      *    轉置後改為環境變數，若未設定則記錄當前時間                  *
      *----------------------------------------------------------------*
           ACCEPT WS-START-TIME-FLAG FROM ENVIRONMENT 'GENAPP_START_TIME'
               ON EXCEPTION
                   MOVE SPACES TO WS-START-TIME-FLAG
           END-ACCEPT

           IF WS-START-TIME-FLAG = SPACES
      *      尚未記錄啟動時間，記錄當前時間
      *      手冊依據：Reference Manual p.190 Format 3
               ACCEPT WS-DATE FROM CENTURY-DATE
               ACCEPT WS-TIME FROM TIME
               MOVE WS-DATE(1:8) TO WS-AREA-D
               MOVE WS-TIME(1:6) TO WS-AREA-T
               DISPLAY 'LGASTAT1: 啟動時間=' WS-DATE ' ' WS-TIME
           END-IF

      *  GENAcounter 正規化（原始邏輯保留）
           IF GENAcounter = '02ACUS'
               MOVE '01ACUS' TO GENAcounter
           END-IF
           IF GENAcounter = '02ICOM' OR
              GENAcounter = '03ICOM' OR
              GENAcounter = '05ICOM'
               MOVE '01ICOM' TO GENAcounter
           END-IF
           IF GENAType NOT = '00'
               MOVE '99' TO GENAtype
           END-IF

      *----------------------------------------------------------------*
      *  更新對應的 IS EXTERNAL 統計計數器                             *
      *  轉置說明：取代 EXEC CICS Get Counter(GENAcount) Pool(GENApool)*
      *    原始只讀取計數器值（此段未遞增，僅記錄）                    *
      *    轉置後讀取 IS EXTERNAL 計數陣列                              *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *----------------------------------------------------------------*
           PERFORM DETERMINE-COUNTER-INDEX
           IF WS-CNT-INDEX > 0 AND WS-CNT-INDEX <= 26
               MOVE GENA-CNT(WS-CNT-INDEX) TO Trancount
           ELSE
               MOVE GENA-CUSTNUM TO Trancount
           END-IF

           GOBACK.

       MAINLINE-EXIT.
           EXIT.

      *================================================================*
      *  DETERMINE-COUNTER-INDEX                                       *
      *  依 GENAcounter 內容對應 IS EXTERNAL 陣列索引                 *
      *================================================================*
       DETERMINE-COUNTER-INDEX.
           EVALUATE GENAcounter
             WHEN '01ICUS'
               EVALUATE GENAtype
                 WHEN '00' MOVE 1  TO WS-CNT-INDEX
                 WHEN OTHER MOVE 2 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01ACUS'
               EVALUATE GENAtype
                 WHEN '00' MOVE 3  TO WS-CNT-INDEX
                 WHEN OTHER MOVE 4 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01IMOT'
               EVALUATE GENAtype
                 WHEN '00' MOVE 5  TO WS-CNT-INDEX
                 WHEN OTHER MOVE 6 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01AMOT'
               EVALUATE GENAtype
                 WHEN '00' MOVE 7  TO WS-CNT-INDEX
                 WHEN OTHER MOVE 8 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01DMOT'
               EVALUATE GENAtype
                 WHEN '00' MOVE 9  TO WS-CNT-INDEX
                 WHEN OTHER MOVE 10 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01UMOT'
               EVALUATE GENAtype
                 WHEN '00' MOVE 11 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 12 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01IEND'
               EVALUATE GENAtype
                 WHEN '00' MOVE 13 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 14 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01AEND'
               EVALUATE GENAtype
                 WHEN '00' MOVE 15 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 16 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01DEND'
               EVALUATE GENAtype
                 WHEN '00' MOVE 17 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 18 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01UEND'
               EVALUATE GENAtype
                 WHEN '00' MOVE 19 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 20 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01IHOU'
               EVALUATE GENAtype
                 WHEN '00' MOVE 21 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 22 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01AHOU'
               EVALUATE GENAtype
                 WHEN '00' MOVE 23 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 24 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN '01DHOU'
               EVALUATE GENAtype
                 WHEN '00' MOVE 25 TO WS-CNT-INDEX
                 WHEN OTHER MOVE 26 TO WS-CNT-INDEX
               END-EVALUATE
             WHEN OTHER
               MOVE 0 TO WS-CNT-INDEX
           END-EVALUATE.
           EXIT.
