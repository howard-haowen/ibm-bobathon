      ******************************************************************
      *                                                                *
      *  GENAPP - ACUCOBOL-GT v11.0 轉置版本                           *
      *  原始程式：LGWEBST5.cbl (IBM COBOL / CICS / z/OS)             *
      *  轉置依據：extend Interoperability Suite 11.0.0                *
      *            ACUCOBOL-GT Reference Manual (Rocket Software,2026) *
      *                                                                *
      *  功能：統計輸出 — C$SLEEP 背景服務                             *
      *        每分鐘從 IS EXTERNAL 計數陣列讀取統計資料並輸出         *
      *        永久迴圈 + ACCEPT FROM ENVIRONMENT 優雅停止            *
      *                                                                *
      *  轉置變更摘要：                                                 *
      *    IBM 原始                  → ACUCOBOL-GT 替代                *
      *    ───────────────────────────────────────────────────────────*
      *    EXEC CICS Start Transid   → C$SLEEP 60 永久迴圈             *
      *      ('SSST') After Minutes(1)  手冊 p.190 Format 3           *
      *                                （已確認的客戶決策）            *
      *    EXEC CICS Query Counter   → 讀取 IS EXTERNAL 計數陣列       *
      *      (GENAcount/GENACNT*)      手冊 p.90                       *
      *    EXEC CICS ReadQ TS        → 暫存陣列（WS-TSQ-STORE）       *
      *    EXEC CICS WriteQ TS       → 暫存陣列更新                    *
      *    EXEC CICS DeleteQ TS      → 陣列清除                        *
      *    EXEC CICS ASSIGN APPLID   → ACCEPT FROM ENVIRONMENT         *
      *                                'GENAPP_APPLID'                 *
      *    EXEC CICS ASKTIME /       → ACCEPT FROM CENTURY-DATE / TIME *
      *      FORMATTIME                手冊 p.190 Format 3             *
      *    EIBTRNID/EIBTRMID/EIBTASKN → ACCEPT FROM ENVIRONMENT        *
      *    PROCEDURE DIVISION.       → PROCEDURE DIVISION（無 USING）  *
      *      (無 USING)               LGWEBST5 為背景獨立服務          *
      *    EXEC CICS RETURN          → GOBACK（但永久迴圈不退出）      *
      *                                                                *
      *  C$SLEEP 背景服務設計（客戶確認）：                             *
      *    原始以 EXEC CICS Start Transid('SSST') After Minutes(1)     *
      *    在 CICS 中實現週期觸發，每分鐘啟動一次。                    *
      *    ACUCOBOL 改為永久迴圈 + C$SLEEP 60（秒）模擬相同行為。     *
      *    優雅停止：每次迴圈前檢查環境變數 GENAPP_STOP_LGWEBST5，    *
      *              若值為 'STOP' 則正常退出。                        *
      *                                                                *
      *  IS EXTERNAL 計數陣列說明：                                    *
      *    與 LGSETUP / LGASTAT1 共用 GENA-COUNTERS IS EXTERNAL。     *
      *    GENA-CUSTNUM   = 客戶流水號計數器                           *
      *    GENA-CNT(1-26) = 各操作成功/失敗計數                       *
      *                                                                *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGWEBST5.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
       DATA DIVISION.

       WORKING-STORAGE SECTION.

      *  統計計數器暫存
       01  CountVal                    PIC S9(8) COMP  VALUE 0.
       01  CountSuccess                PIC S9(9) COMP  VALUE 0.
       01  CountErrors                 PIC S9(8) COMP  VALUE 0.
       01  CountInq                    PIC S9(8) COMP  VALUE 0.
       01  CountAdd                    PIC S9(8) COMP  VALUE 0.
       01  CountUpd                    PIC S9(8) COMP  VALUE 0.
       01  CountDel                    PIC S9(8) COMP  VALUE 0.

      *  速率計算暫存（取代 TS Queue 速率機制）
       01  DRateVal                    PIC 9(9)  VALUE 0.
       01  NRateVal                    PIC 9(9)  VALUE 0.
       01  ORateVal                    PIC 9(9)  VALUE 0.
       01  ICountVal                   PIC 9(6)  VALUE 0.
       01  OCountVal                   PIC 9(6)  VALUE 0.
       01  NCountVal                   PIC 9(6)  VALUE 0.
       01  HHval                       PIC 9(6)  VALUE 0.
       01  MMval                       PIC 9(6)  VALUE 0.
       01  SSval                       PIC 9(6)  VALUE 0.

      *  時間日期暫存
       01  WS-DATE                     PIC X(8)  VALUE SPACES.
       01  WS-TIME                     PIC X(8)  VALUE SPACES.
       01  WS-HHMMSS.
           03  WS-HH                   PIC X(2)  VALUE '00'.
           03  WS-MM                   PIC X(2)  VALUE '00'.
           03  WS-SS                   PIC X(2)  VALUE '00'.
       01  WS-OLDV.
           02 WS-OLDVHH                PIC X(2)  VALUE '00'.
           02 WS-OLDVMM                PIC X(2)  VALUE '00'.
           02 WS-OLDVSS                PIC X(2)  VALUE '00'.
       01  WS-NEWV                     PIC X(6)  VALUE SPACES.

      *  應用系統 ID（取代 EXEC CICS ASSIGN APPLID）
       01  WS-APPLID                   PIC X(8)  VALUE SPACES.

      *  優雅停止旗標（客戶確認的設計）
       01  WS-STOP-FLAG                PIC X(4)  VALUE SPACES.

      *  執行環境識別
       01  WS-HEADER.
           03 WS-EYECATCHER            PIC X(16)
                                        VALUE 'LGWEBST5------WS'.
           03 WS-TRANSID               PIC X(4)  VALUE SPACES.
           03 WS-TERMID                PIC X(4)  VALUE SPACES.
           03 WS-TASKNUM               PIC 9(7)  VALUE 0.
           03 WS-CALEN                 PIC 9(7)  VALUE 0.

      *  統計輸出暫存（對應原始 SymbList 中的 S* 欄位）
       01  GENAcount-V                 PIC 9(9)  VALUE 0.
       01  GENACNT100-V                PIC 9(9)  VALUE 0.
       01  GENACNT199-V                PIC 9(9)  VALUE 0.
       01  GENACNT200-V                PIC 9(9)  VALUE 0.
       01  GENACNT299-V                PIC 9(9)  VALUE 0.
       01  GENACNT300-V                PIC 9(9)  VALUE 0.
       01  GENACNT399-V                PIC 9(9)  VALUE 0.
       01  GENACNT400-V                PIC 9(9)  VALUE 0.
       01  GENACNT499-V                PIC 9(9)  VALUE 0.
       01  GENACNT500-V                PIC 9(9)  VALUE 0.
       01  GENACNT599-V                PIC 9(9)  VALUE 0.
       01  GENACNT600-V                PIC 9(9)  VALUE 0.
       01  GENACNT699-V                PIC 9(9)  VALUE 0.
       01  GENACNT700-V                PIC 9(9)  VALUE 0.
       01  GENACNT799-V                PIC 9(9)  VALUE 0.
       01  GENACNT800-V                PIC 9(9)  VALUE 0.
       01  GENACNT899-V                PIC 9(9)  VALUE 0.
       01  GENACNT900-V                PIC 9(9)  VALUE 0.
       01  GENACNT999-V                PIC 9(9)  VALUE 0.
       01  GENACNTA00-V                PIC 9(9)  VALUE 0.
       01  GENACNTA99-V                PIC 9(9)  VALUE 0.
       01  GENACNTB00-V                PIC 9(9)  VALUE 0.
       01  GENACNTB99-V                PIC 9(9)  VALUE 0.
       01  GENACNTC00-V                PIC 9(9)  VALUE 0.
       01  GENACNTC99-V                PIC 9(9)  VALUE 0.
       01  GENACNTD00-V                PIC 9(9)  VALUE 0.
       01  GENACNTD99-V                PIC 9(9)  VALUE 0.
       01  GENAsucces-V                PIC 9(9)  VALUE 0.
       01  GENAerrors-V                PIC 9(9)  VALUE 0.

      *  速率歷史暫存（取代 TS Queue 速率存儲）
       01  WS-PREV-HHMMSS              PIC X(6)  VALUE '000000'.

      *----------------------------------------------------------------*
      *  IS EXTERNAL 計數陣列                                          *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *  與 LGSETUP / LGASTAT1 共用同一記憶體                         *
      *----------------------------------------------------------------*
       01  GENA-COUNTERS               IS EXTERNAL.
           03 GENA-CUSTNUM             PIC S9(9) COMP VALUE 0.
           03 GENA-CNT                 OCCURS 26 TIMES
                                        PIC S9(9) COMP VALUE 0.

      ******************************************************************
      *    P R O C E D U R E     D I V I S I O N                      *
      ******************************************************************
      *  轉置說明：LGWEBST5 為獨立背景服務，無 COMMAREA 傳入
       PROCEDURE DIVISION.

       MAINLINE SECTION.

           INITIALIZE WS-HEADER.

           ACCEPT WS-TRANSID FROM ENVIRONMENT 'GENAPP_TRANSID'
               ON EXCEPTION MOVE 'SSST' TO WS-TRANSID END-ACCEPT
           ACCEPT WS-TERMID  FROM ENVIRONMENT 'GENAPP_TERMID'
               ON EXCEPTION MOVE 'ACU1' TO WS-TERMID  END-ACCEPT

      *  取得應用系統 ID（取代 EXEC CICS ASSIGN APPLID）
      *  手冊依據：Reference Manual p.190 Format 5
           ACCEPT WS-APPLID FROM ENVIRONMENT 'GENAPP_APPLID'
               ON EXCEPTION
                   MOVE 'GENAPP01' TO WS-APPLID
           END-ACCEPT

           DISPLAY 'LGWEBST5: 背景統計服務啟動 APPLID=' WS-APPLID

      *================================================================*
      *  永久統計迴圈（客戶確認的設計）                                *
      *  轉置說明：取代 EXEC CICS Start Transid('SSST') After Min(1)   *
      *    原始每次執行完成後，啟動一個新的 SSST 交易（1 分鐘後）。   *
      *    轉置後改為永久迴圈 + C$SLEEP 60（每分鐘執行一次）。        *
      *                                                                *
      *  優雅停止機制：每次迴圈開始前讀取環境變數                     *
      *    GENAPP_STOP_LGWEBST5，若為 'STOP' 則正常退出。             *
      *  手冊依據：Reference Manual p.190 Format 5                    *
      *================================================================*
       STATS-LOOP.

      *  檢查停止旗標（優雅停止）
           ACCEPT WS-STOP-FLAG FROM ENVIRONMENT 'GENAPP_STOP_LGWEBST5'
               ON EXCEPTION
                   MOVE SPACES TO WS-STOP-FLAG
           END-ACCEPT

           IF WS-STOP-FLAG = 'STOP'
               DISPLAY 'LGWEBST5: 收到停止旗號，正常退出'
               GOBACK
           END-IF

      *----------------------------------------------------------------*
      *  取得當前時間                                                   *
      *  手冊依據：Reference Manual p.190 Format 3                    *
      *  CENTURY-DATE 返回 YYYYMMDD；TIME 返回 HHMMSSss               *
      *----------------------------------------------------------------*
           ACCEPT WS-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME FROM TIME

           MOVE WS-TIME(1:2) TO WS-HH
           MOVE WS-TIME(3:2) TO WS-MM
           MOVE WS-TIME(5:2) TO WS-SS
           MOVE WS-HHMMSS    TO WS-NEWV

      *  計算時間間隔（取代 TS Queue Tran-Rate-Interval 機制）
           PERFORM Tran-Rate-Interval

      *----------------------------------------------------------------*
      *  讀取 IS EXTERNAL 計數陣列（取代大量 EXEC CICS Query Counter） *
      *  手冊依據：Reference Manual p.90 IS EXTERNAL Clause           *
      *----------------------------------------------------------------*
           MOVE GENA-CUSTNUM    TO CountVal
           MOVE CountVal        TO GENAcount-V

           MOVE GENA-CNT(1)     TO CountVal
           MOVE CountVal        TO CountSuccess
           MOVE CountVal        TO CountInq
           MOVE CountVal        TO GENACNT100-V

           MOVE GENA-CNT(2)     TO CountVal
           MOVE CountVal        TO CountErrors
           MOVE CountVal        TO GENACNT199-V

           MOVE GENA-CNT(3)     TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           MOVE CountVal        TO CountAdd
           MOVE CountVal        TO GENACNT200-V

           MOVE GENA-CNT(4)     TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT299-V

           MOVE GENA-CNT(5)     TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountInq = CountInq + CountVal
           MOVE CountVal        TO GENACNT300-V

           MOVE GENA-CNT(6)     TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT399-V

           MOVE GENA-CNT(7)     TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountAdd = CountAdd + CountVal
           MOVE CountVal        TO GENACNT400-V

           MOVE GENA-CNT(8)     TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT499-V

           MOVE GENA-CNT(9)     TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           MOVE CountVal        TO CountDel
           MOVE CountVal        TO GENACNT500-V

           MOVE GENA-CNT(10)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT599-V

           MOVE GENA-CNT(11)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           MOVE CountVal        TO CountUpd
           MOVE CountVal        TO GENACNT600-V

           MOVE GENA-CNT(12)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT699-V

           MOVE GENA-CNT(13)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountInq = CountInq + CountVal
           MOVE CountVal        TO GENACNT700-V

           MOVE GENA-CNT(14)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT799-V

           MOVE GENA-CNT(15)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountAdd = CountAdd + CountVal
           MOVE CountVal        TO GENACNT800-V

           MOVE GENA-CNT(16)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT899-V

           MOVE GENA-CNT(17)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountDel = CountDel + CountVal
           MOVE CountVal        TO GENACNT900-V

           MOVE GENA-CNT(18)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNT999-V

           MOVE GENA-CNT(19)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountUpd = CountUpd + CountVal
           MOVE CountVal        TO GENACNTA00-V

           MOVE GENA-CNT(20)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNTA99-V

           MOVE GENA-CNT(21)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountInq = CountInq + CountVal
           MOVE CountVal        TO GENACNTB00-V

           MOVE GENA-CNT(22)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNTB99-V

           MOVE GENA-CNT(23)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountAdd = CountAdd + CountVal
           MOVE CountVal        TO GENACNTC00-V

           MOVE GENA-CNT(24)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNTC99-V

           MOVE GENA-CNT(25)    TO CountVal
           COMPUTE CountSuccess = CountSuccess + CountVal
           COMPUTE CountDel = CountDel + CountVal
           MOVE CountVal        TO GENACNTD00-V

           MOVE GENA-CNT(26)    TO CountVal
           COMPUTE CountErrors = CountErrors + CountVal
           MOVE CountVal        TO GENACNTD99-V

           MOVE CountSuccess    TO GENAsucces-V
           MOVE CountErrors     TO GENAerrors-V

      *  輸出統計摘要
           DISPLAY 'LGWEBST5: 統計時間=' WS-DATE ' ' WS-TIME
           DISPLAY '  客戶流水號:  ' GENAcount-V
           DISPLAY '  查詢成功:    ' GENACNT100-V '  失敗: ' GENACNT199-V
           DISPLAY '  新增客戶成功:' GENACNT200-V '  失敗: ' GENACNT299-V
           DISPLAY '  查詢汽車成功:' GENACNT300-V '  失敗: ' GENACNT399-V
           DISPLAY '  總成功:      ' GENAsucces-V
           DISPLAY '  總失敗:      ' GENAerrors-V
           DISPLAY '  查詢筆數:    ' CountInq
           DISPLAY '  新增筆數:    ' CountAdd
           DISPLAY '  更新筆數:    ' CountUpd
           DISPLAY '  刪除筆數:    ' CountDel
           DISPLAY '  APPLID:      ' WS-APPLID

      *----------------------------------------------------------------*
      *  等待 60 秒後進入下一輪迴圈                                    *
      *  轉置說明：取代 EXEC CICS Start Transid('SSST') After Min(1)   *
      *    C$SLEEP 參數為毫秒，60*1000 = 60000 毫秒 = 60 秒          *
      *  手冊依據：ACUCOBOL-GT Library Routines（C$SLEEP）             *
      *----------------------------------------------------------------*
           CALL 'C$SLEEP' USING 60000
           END-CALL

           GO TO STATS-LOOP.

       A-EXIT.
           EXIT.
           GOBACK.

      *================================================================*
      *  Tran-Rate-Interval                                            *
      *  計算時間間隔（取代 TS Queue 時間差計算）                      *
      *  原始以 ReadQ TS 取得上次時間，再以 WriteQ TS 更新。          *
      *  轉置後使用 WS-PREV-HHMMSS 暫存上次時間（同一執行期有效）。   *
      *================================================================*
       Tran-Rate-Interval.

           MOVE WS-OLDV TO WS-PREV-HHMMSS

           MOVE WS-HH   TO HHVal
           MOVE WS-MM   TO MMVal
           MOVE WS-SS   TO SSVal
           COMPUTE NCountVal = (HHVal * 3600) +
                               (MMVal * 60)   +
                                SSVal
           MOVE WS-OLDVHH TO HHVal
           MOVE WS-OLDVMM TO MMVal
           MOVE WS-OLDVSS TO SSVal
           COMPUTE OCountVal = (HHVal * 3600) +
                               (MMVal * 60)   +
                                SSVal
           COMPUTE ICountVal = NCountVal - OCountVal
           MOVE WS-HHMMSS TO WS-OLDV.

           EXIT.

      *================================================================*
      *  Tran-Rate-Counts                                              *
      *  計算交易速率差值（原始邏輯原樣保留，TS Queue 改為暫存變數）  *
      *================================================================*
       Tran-Rate-Counts.

           MOVE NRateVal  TO ORateVal
           COMPUTE DRateVal = NRateVal - ORateVal.

           EXIT.
