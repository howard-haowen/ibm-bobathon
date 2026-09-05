      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *           Inquire Policy  ─  VSAM KSDS 隨機查詢                *
      *                                                                *
      * 原始程式: LGIPVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 功能說明:                                                       *
      *   依保單類型以 GTEQ 方式從 KSDSPOLY 取得第一筆符合的保單號碼，    *
      *   回傳給呼叫者（COMMAREA 模式）                                  *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS ASSIGN SYSID/STARTCODE/Invokingprog                *
      *     → ACCEPT FROM ENVIRONMENT                                 *
      *   EXEC CICS Read File GTEQ Generic → READ ... KEY + NEXT      *
      *   EXEC CICS SEND TEXT → DISPLAY                               *
      *   EXEC CICS RETURN → GOBACK                                   *
      *   COPY NewCopy → 直接展開                                      *
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 C] ACCEPT FROM ENVIRONMENT  (手冊 p.190 Format 5)     *
      *   [特性 F] FILE CONTROL INDEXED 組織 (手冊 p.73)               *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGIPVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織對應 z/OS VSAM KSDS KSDSPOLY              *
      *   複合鍵: Type(1) + CustomerNum(10) + PolicyNum(10) = 21 bytes *
      *   ACCESS MODE IS DYNAMIC 支援 GTEQ + Generic 語意              *
      *----------------------------------------------------------------*
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KSDSPOLY-FILE
               ASSIGN TO DYNAMIC WS-KSDSPOLY-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS DYNAMIC
               RECORD KEY IS PART-KEY
               FILE STATUS IS WS-KSDSPOLY-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KSDSPOLY-FILE
           RECORD CONTAINS 64 CHARACTERS.
       01  KSDSPOLY-RECORD.
           03 PART-KEY.
             05 PART-KEY-Type         PIC X.
             05 PART-KEY-Num          PIC 9(10).
             05 FILLER                PIC X(10).
           03 CA-POLICY-TYPE REDEFINES PART-KEY-Type
                                      PIC X.
           03 FILLER                  PIC X(53).

       WORKING-STORAGE SECTION.

      *================================================================*
      * 展開 NewCopy.cpy 內容（需要的欄位子集）                          *
      *================================================================*
       01  WS-FLAG                   PIC X.
       01  WS-RESP                   PIC S9(8) COMP.
       01  WS-STARTCODE              PIC XX    VALUE SPACES.
       01  WS-SYSID                  PIC X(4)  VALUE SPACES.
       01  WS-Invokeprog             PIC X(8)  VALUE SPACES.
       01  WS-COMMAREA               PIC X(80).
       01  WS-RECV.
           03 WS-RECV-TRANID         PIC X(5).
           03 WS-RECV-DATA           PIC X(74).
       01  WS-RECV-LEN               PIC S9(4) COMP VALUE 80.

      * 工作用變數
       01  WS-KSDSPOLY-PATH          PIC X(256) VALUE SPACES.
       01  WS-KSDSPOLY-STATUS        PIC XX     VALUE SPACES.
           88 KSDSPOLY-OK                       VALUE '00'.

      * 寫入訊息（回傳結果用）
       01  WRITE-MSG.
           03 WRITE-MSG-Text         PIC X(11)  VALUE 'Policy Key='.
           03 WRITE-MSG-Key.
             05 WRITE-Msg-Type       PIC X      VALUE 'X'.
             05 WRITE-Msg-CustNum    PIC 9(10).
             05 WRITE-Msg-PolNum     PIC 9(10).
           03 FILLER                 PIC X(48)  VALUE SPACES.

      * COMMAREA 區域（暫存輸入資料）
       01  CA-AREA.
           03 CA-POLICY-TYPE-IN      PIC X.
           03 CA-CUSTOMER-NUM        PIC X(10).
           03 CA-POLICY-NUM          PIC X(10).
           03 FILLER                 PIC X(43).

      *****************************************************************
      *    L I N K A G E     S E C T I O N
      *****************************************************************
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           03 COMMA-DATA.
             05 Comma-Data-Text      PIC X(11).
             05 Comma-Data-Key       PIC X(21).
             05 FILLER               PIC X(58).

      *----------------------------------------------------------------*
      *****************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *---------------------------------------------------------------*
       MAINLINE SECTION.
      *
      *---------------------------------------------------------------*
      * [特性 C] 取得執行環境資訊 (手冊 p.190 Format 5)
           ACCEPT WS-SYSID        FROM ENVIRONMENT 'GENAPP_SYSID'
           ACCEPT WS-STARTCODE    FROM ENVIRONMENT 'GENAPP_STARTCODE'
           ACCEPT WS-Invokeprog   FROM ENVIRONMENT 'GENAPP_INVOKINGPROG'

           IF WS-STARTCODE(1:1) = 'D' OR
              WS-Invokeprog NOT = SPACES
               MOVE 'C'         TO WS-FLAG
               MOVE COMMA-DATA  TO WS-COMMAREA
               MOVE 11          TO WS-RECV-LEN
               SUBTRACT 1 FROM WS-RECV-LEN
           ELSE
               MOVE 'C'         TO WS-FLAG
               MOVE COMMA-DATA  TO WS-COMMAREA
               MOVE 10          TO WS-RECV-LEN
           END-IF.

      * [特性 C] 取得 VSAM 檔案路徑
           ACCEPT WS-KSDSPOLY-PATH FROM ENVIRONMENT 'GENAPP_KSDSPOLY'
           IF WS-KSDSPOLY-PATH = SPACES
               MOVE '/tmp/KSDSPOLY' TO WS-KSDSPOLY-PATH
           END-IF

      *---------------------------------------------------------------*
      * 從 COMMAREA 取得搜尋鍵值
      *   WS-COMMAREA(1:1) = 保單類型
      *   WS-COMMAREA(2:WS-RECV-LEN) = 部分客戶號
      *---------------------------------------------------------------*
           MOVE SPACES                       TO CA-AREA
           MOVE WS-COMMAREA(1:1)             TO PART-KEY-Type
           MOVE WS-COMMAREA(2:WS-RECV-LEN)   TO PART-KEY-Num

      *---------------------------------------------------------------*
      * READ ... GTEQ Generic                                          *
      *   原始: EXEC CICS Read File('KSDSPOLY') GTEQ Generic          *
      *   Generic 表示只比對鍵值的前綴（Type+CustomerNum = 11 bytes）   *
      *   ACUCOBOL 的 DYNAMIC ACCESS + START + READ NEXT 實現相同語意  *
      *---------------------------------------------------------------*
           OPEN INPUT KSDSPOLY-FILE
           IF NOT KSDSPOLY-OK
               MOVE 'Policy Bad='   TO WRITE-Msg-Text
               MOVE 13              TO WRITE-Msg-CustNum
               MOVE 13              TO WRITE-Msg-PolNum
               GO TO SEND-RESULT
           END-IF

           START KSDSPOLY-FILE
               KEY NOT LESS THAN PART-KEY
           IF KSDSPOLY-OK
               READ KSDSPOLY-FILE NEXT
               IF KSDSPOLY-OK AND
                  PART-KEY-Type = WS-COMMAREA(1:1)
                   MOVE KSDSPOLY-RECORD(1:21) TO WRITE-MSG-Key
               ELSE
                   MOVE 'Policy Bad='   TO WRITE-Msg-Text
                   MOVE 13              TO WRITE-Msg-CustNum
                   MOVE 13              TO WRITE-Msg-PolNum
               END-IF
           ELSE
               MOVE 'Policy Bad='   TO WRITE-Msg-Text
               MOVE 13              TO WRITE-Msg-CustNum
               MOVE 13              TO WRITE-Msg-PolNum
           END-IF

           CLOSE KSDSPOLY-FILE.

      *---------------------------------------------------------------*
       SEND-RESULT.
           IF WS-FLAG = 'R' THEN
      *       終端機模式：DISPLAY 取代 EXEC CICS SEND TEXT
               DISPLAY WRITE-MSG
           ELSE
      *       COMMAREA 模式：回寫結果
               MOVE SPACES         TO COMMA-DATA
               MOVE WRITE-Msg-Text TO COMMA-Data-Text
               MOVE WRITE-MSG-Key  TO COMMA-Data-Key
           END-IF.

       A-EXIT.
           GOBACK.
