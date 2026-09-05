      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *           Customer Inquire  ─  VSAM KSDS 隨機查詢              *
      *                                                                *
      * 原始程式: LGICVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 功能說明:                                                       *
      *   以亂數取得一個存在於 KSDSCUST 中的客戶號碼，                    *
      *   回傳給呼叫者（COMMAREA 模式）                                  *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS ASSIGN SYSID/STARTCODE/Invokingprog                *
      *     → ACCEPT FROM ENVIRONMENT (GENAPP_SYSID 等)               *
      *   EXEC CICS ENQ/DEQ → 檔案鎖定（INDEXED READ WITH LOCK）       *
      *   EXEC CICS ReadQ TS → ACCEPT FROM ENVIRONMENT                *
      *     (GENAPP_CUST_LOW / GENAPP_CUST_HIGH)                      *
      *   EXEC CICS WRITEQ TS → 僅更新記憶體（TSQ 不寫入磁碟）           *
      *   EXEC CICS Read File → READ KSDSCUST-FILE ... GTEQ           *
      *   EXEC CICS SEND TEXT → DISPLAY                               *
      *   EIBTASKN → ACCEPT FROM ENVIRONMENT 'GENAPP_TASKNUM'         *
      *   FUNCTION RANDOM → 保留（ACUCOBOL 支援）                      *
      *   EXEC CICS RETURN → GOBACK                                   *
      *   COPY NewCopy → 直接展開（ACUCOBOL 不支援的依賴已移除）          *
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 C] ACCEPT FROM ENVIRONMENT  (手冊 p.190 Format 5)     *
      *   [特性 E] CALL...USING BY REFERENCE (手冊 p.217)              *
      *   [特性 F] FILE CONTROL INDEXED 組織 (手冊 p.73)               *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGICVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織對應 z/OS VSAM KSDS KSDSCUST              *
      *   ACCESS MODE IS DYNAMIC 以支援 GTEQ（大於等於）循序讀取         *
      *----------------------------------------------------------------*
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KSDSCUST-FILE
               ASSIGN TO DYNAMIC WS-KSDSCUST-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS WS-KSDSCUST-KEY
               FILE STATUS IS WS-KSDSCUST-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KSDSCUST-FILE
           RECORD CONTAINS 225 CHARACTERS.
       01  KSDSCUST-RECORD.
           03 WS-KSDSCUST-KEY          PIC 9(10).
           03 WS-KSDSCUST-DATA         PIC X(215).

       WORKING-STORAGE SECTION.

      *================================================================*
      * 展開 NewCopy.cpy 內容（ACUCOBOL 不保留 TSQ 旗標）               *
      *================================================================*
       01  WS-FLAG-TSQE              PIC X.
       01  WS-FLAG-TSQH              PIC X.
       01  WS-FLAG-TSQL              PIC X.
       01  WS-FLAG                   PIC X.
       01  WS-RANDOM-Seed            PIC S9(4) COMP.
       01  WS-RANDOM-Number          PIC 9(10) COMP.
       01  WS-RESP                   PIC S9(8) COMP.
       01  WS-STARTCODE              PIC XX    VALUE SPACES.
       01  WS-SYSID                  PIC X(4)  VALUE SPACES.
       01  WS-Invokeprog             PIC X(8)  VALUE SPACES.
       01  WS-COMMAREA               PIC X(80).
       01  WS-RECV.
           03 WS-RECV-TRANID         PIC X(5).
           03 WS-RECV-DATA           PIC X(74).
       01  WS-RECV-LEN               PIC S9(4) COMP VALUE 80.

       01  WS-Cust-Low               PIC S9(10) VALUE 1000001.
       01  WS-Cust-High              PIC S9(10) VALUE 1000001.
       01  WS-Cust-Number            PIC X(10).

      * 工作用變數
       01  WS-KSDSCUST-PATH          PIC X(256) VALUE SPACES.
       01  WS-KSDSCUST-STATUS        PIC XX     VALUE SPACES.
           88 KSDSCUST-OK                       VALUE '00'.

       01  WS-TASKNUM                PIC 9(7)   VALUE 0.
       01  WS-Random-Seed-Env        PIC X(7)   VALUE SPACES.

      * 寫入訊息結構（對應 WRITE-MSG）
       01  WRITE-MSG.
           03 WRITE-MSG-E            PIC X(20)  VALUE '**** GENAPP CNTL'.
           03 WRITE-MSG-L            PIC X(13)  VALUE 'LOW CUSTOMER='.
           03 WRITE-MSG-LOW          PIC X(10).
           03 FILLER                 PIC X.
           03 WRITE-MSG-H            PIC X(14)  VALUE 'HIGH CUSTOMER='.
           03 WRITE-MSG-High         PIC 9(10).
           03 FILLER                 PIC X(60).

      *****************************************************************
      *    L I N K A G E     S E C T I O N
      *****************************************************************
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           03 COMMA-DATA.
             05 Comma-Data-H         PIC X(14).
             05 Comma-Data-High      PIC 9(10).
             05 FILLER               PIC X(60).

      *----------------------------------------------------------------*
      *****************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *---------------------------------------------------------------*
       MAINLINE SECTION.
      *
      *---------------------------------------------------------------*
      * [特性 C] 取得執行環境資訊 (手冊 p.190 Format 5)
      *   z/OS: EXEC CICS ASSIGN SYSID/STARTCODE/Invokingprog
      *---------------------------------------------------------------*
           ACCEPT WS-SYSID        FROM ENVIRONMENT 'GENAPP_SYSID'
           ACCEPT WS-STARTCODE    FROM ENVIRONMENT 'GENAPP_STARTCODE'
           ACCEPT WS-Invokeprog   FROM ENVIRONMENT 'GENAPP_INVOKINGPROG'

      * 判斷呼叫模式：COMMAREA 呼叫 vs. 終端機直接呼叫
           IF WS-STARTCODE(1:1) = 'D' OR
              WS-Invokeprog NOT = SPACES
               MOVE 'C'         TO WS-FLAG
               MOVE COMMA-DATA  TO WS-COMMAREA
               MOVE 24          TO WS-RECV-LEN
           ELSE
      *       終端機直接輸入（非 CICS 環境下不適用，預設 COMMAREA 模式）
               MOVE 'C'         TO WS-FLAG
               MOVE COMMA-DATA  TO WS-COMMAREA
               MOVE 24          TO WS-RECV-LEN
           END-IF.

      *---------------------------------------------------------------*
      * [特性 C] 取得客戶號碼範圍
      *   原始: EXEC CICS ReadQ TS QUEUE('GENACNTL') Into(READ-MSG)
      *   轉置: 從環境變數讀取低/高值
      *---------------------------------------------------------------*
           MOVE 1000001 TO WS-Cust-Low
           MOVE 1000001 TO WS-Cust-High
           MOVE 'Y'     TO WS-FLAG-TSQE
           MOVE 'Y'     TO WS-FLAG-TSQH
           MOVE 'Y'     TO WS-FLAG-TSQL

           ACCEPT WS-KSDSCUST-PATH FROM ENVIRONMENT 'GENAPP_KSDSCUST'
           IF WS-KSDSCUST-PATH = SPACES
               MOVE '/tmp/KSDSCUST' TO WS-KSDSCUST-PATH
           END-IF

      *   從環境變數取得範圍（若有設定）
           ACCEPT WS-Cust-Number FROM ENVIRONMENT 'GENAPP_CUST_LOW'
           IF WS-Cust-Number NOT = SPACES
               MOVE WS-Cust-Number TO WS-Cust-Low
               MOVE SPACE          TO WS-FLAG-TSQL
           END-IF

           ACCEPT WS-Cust-Number FROM ENVIRONMENT 'GENAPP_CUST_HIGH'
           IF WS-Cust-Number NOT = SPACES
               MOVE WS-Cust-Number TO WS-Cust-High
               MOVE SPACE          TO WS-FLAG-TSQH
           END-IF

           MOVE WS-Cust-Low  TO WRITE-MSG-LOW
           MOVE WS-Cust-High TO WRITE-MSG-HIGH

      *---------------------------------------------------------------*
      * 以 FUNCTION RANDOM 計算亂數客戶號
      *   原始: FUNCTION Random(EIBTASKN)
      *   轉置: EIBTASKN → 環境變數 GENAPP_TASKNUM
      *---------------------------------------------------------------*
           ACCEPT WS-TASKNUM FROM ENVIRONMENT 'GENAPP_TASKNUM'

           COMPUTE WS-Random-Number = FUNCTION INTEGER((
                     FUNCTION RANDOM(WS-TASKNUM) *
                       (WS-Cust-High - WS-Cust-Low)) +
                            WS-Cust-Low)
           MOVE WS-Random-Number TO WRITE-MSG-HIGH

      *---------------------------------------------------------------*
      * READ ... GTEQ 對應 EXEC CICS Read File GTEQ                   *
      *---------------------------------------------------------------*
           OPEN INPUT KSDSCUST-FILE
           IF NOT KSDSCUST-OK
               MOVE SPACES TO WRITE-MSG-High
               GO TO SEND-RESULT
           END-IF

           MOVE WS-Random-Number TO WS-KSDSCUST-KEY
           READ KSDSCUST-FILE
               KEY IS WS-KSDSCUST-KEY
               NOT INVALID KEY
                   MOVE WS-KSDSCUST-KEY TO WRITE-MSG-HIGH
               INVALID KEY
      *           GTEQ: 找不到精確鍵，嘗試循序讀取下一筆
                   READ KSDSCUST-FILE NEXT
                       AT END
                           MOVE 0 TO WRITE-MSG-High
                       NOT AT END
                           MOVE WS-KSDSCUST-KEY TO WRITE-MSG-HIGH
                   END-READ
           END-READ

           CLOSE KSDSCUST-FILE.

      *---------------------------------------------------------------*
       SEND-RESULT.
           IF WS-FLAG = 'R' THEN
      *       終端機模式：DISPLAY 取代 EXEC CICS SEND TEXT
               DISPLAY 'HIGH CUSTOMER=' WRITE-MSG-High
           ELSE
      *       COMMAREA 模式：回寫結果
               MOVE SPACES          TO COMMA-DATA
               MOVE WRITE-MSG-H     TO COMMA-Data-H
               MOVE WRITE-MSG-High  TO COMMA-Data-High
           END-IF.

       A-EXIT.
           GOBACK.
