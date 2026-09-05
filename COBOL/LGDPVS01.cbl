      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *           Delete Policy  ─  VSAM KSDS 存取層                   *
      *                                                                *
      * 原始程式: LGDPVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 功能說明:                                                       *
      *   依保單類型、客戶號碼、保單號碼組成複合鍵，                        *
      *   從 KSDSPOLY 刪除對應保單記錄                                   *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS Delete File('KSDSPOLY') → DELETE KSDSPOLY-FILE    *
      *   EXEC CICS RETURN → GOBACK                                   *
      *   EIBCALEN → LENGTH OF DFHCOMMAREA                            *
      *   EIBRESP2 → WS-KSDSPOLY-STATUS                               *
      *   EXEC CICS ASKTIME/FORMATTIME → ACCEPT FROM CENTURY-DATE/TIME*
      *   EXEC CICS LINK PROGRAM('LGSTSQ') → CALL 'LGSTSQ'           *
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 B] ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)*
      *   [特性 C] ACCEPT FROM ENVIRONMENT       (手冊 p.190 Format 5)*
      *   [特性 E] CALL...USING BY REFERENCE     (手冊 p.217)         *
      *   [特性 F] FILE CONTROL INDEXED 組織      (手冊 p.73)          *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGDPVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織 DELETE 對應 EXEC CICS Delete File         *
      *   複合鍵: Type(1) + CustomerNum(10) + PolicyNum(10) = 21 bytes *
      *----------------------------------------------------------------*
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KSDSPOLY-FILE
               ASSIGN TO DYNAMIC WS-KSDSPOLY-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS WF-Policy-Key
               FILE STATUS IS WS-KSDSPOLY-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KSDSPOLY-FILE
           RECORD CONTAINS 64 CHARACTERS.
       01  KSDSPOLY-RECORD.
           03 WF-Policy-Key.
             05 WF-Request-ID         PIC X.
             05 WF-Customer-Num       PIC X(10).
             05 WF-Policy-Num         PIC X(10).
           03 FILLER                  PIC X(43).

       WORKING-STORAGE SECTION.

      * 眼睛捕捉字（Eyecatcher）
       77  Eyecatcher                 PIC X(16) VALUE 'Program LGDPVS01'.

       01  WS-RESP                    PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                   PIC S9(8) COMP VALUE 0.
       01  WS-Commarea-Len            PIC S9(4) COMP.

      * 檔案路徑及狀態
       01  WS-KSDSPOLY-PATH           PIC X(256) VALUE SPACES.
       01  WS-KSDSPOLY-STATUS         PIC XX     VALUE SPACES.
           88 KSDSPOLY-OK                        VALUE '00'.

      * [特性 B] 日期時間變數 (手冊 p.190 Format 3)
       01  WS-CENTURY-DATE            PIC 9(8)  VALUE 0.
       01  WS-TIME-OF-DAY             PIC 9(8)  VALUE 0.

      * 錯誤訊息結構
       01  ERROR-MSG.
           03 EM-DATE                 PIC X(8)  VALUE SPACES.
           03 FILLER                  PIC X     VALUE SPACES.
           03 EM-TIME                 PIC X(6)  VALUE SPACES.
           03 FILLER                  PIC X(9)  VALUE ' LGDPVS01'.
           03 EM-VARIABLE.
             05 FILLER                PIC X(6)  VALUE ' PNUM='.
             05 EM-POLNUM             PIC X(10) VALUE SPACES.
             05 FILLER                PIC X(6)  VALUE ' CNUM='.
             05 EM-CUSNUM             PIC X(10) VALUE SPACES.
             05 FILLER                PIC X(21)
                                        VALUE ' Delete file KSDSPOLY'.
             05 FILLER                PIC X(6)  VALUE ' RESP='.
             05 EM-RESPRC             PIC +9(5) USAGE DISPLAY.
             05 FILLER                PIC X(7)  VALUE ' RESP2='.
             05 EM-RESP2RC            PIC +9(5) USAGE DISPLAY.

       01  CA-ERROR-MSG.
           03 FILLER                  PIC X(9)  VALUE 'COMMAREA='.
           03 CA-DATA                 PIC X(90) VALUE SPACES.

      *****************************************************************
      *    L I N K A G E     S E C T I O N
      *****************************************************************
       LINKAGE SECTION.
       01  DFHCOMMAREA.
           COPY LGCMAREA.

      *----------------------------------------------------------------*
      *****************************************************************
       PROCEDURE DIVISION USING BY REFERENCE DFHCOMMAREA.

      *---------------------------------------------------------------*
       MAINLINE SECTION.
      *
      *---------------------------------------------------------------*
           MOVE LENGTH OF DFHCOMMAREA TO WS-Commarea-Len.

      * [特性 C] 取得 VSAM 檔案路徑 (手冊 p.190 Format 5)
           ACCEPT WS-KSDSPOLY-PATH FROM ENVIRONMENT 'GENAPP_KSDSPOLY'
           IF WS-KSDSPOLY-PATH = SPACES
               MOVE '/tmp/KSDSPOLY' TO WS-KSDSPOLY-PATH
           END-IF

      *---------------------------------------------------------------*
      * 組裝複合鍵（與原始相同）
      *---------------------------------------------------------------*
           MOVE CA-Request-ID(4:1) TO WF-Request-ID
           MOVE CA-Policy-Num      TO WF-Policy-Num
           MOVE CA-Customer-Num    TO WF-Customer-Num

      *---------------------------------------------------------------*
      * DELETE 對應 EXEC CICS Delete File('KSDSPOLY')                 *
      *   原始: RIDFLD(WF-Policy-Key) KeyLength(21)                   *
      *   ACUCOBOL: OPEN I-O + READ + DELETE FILE                     *
      *---------------------------------------------------------------*
           OPEN I-O KSDSPOLY-FILE.
           IF NOT KSDSPOLY-OK
               MOVE '81' TO CA-RETURN-CODE
               MOVE 1    TO WS-RESP
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGDPVS01: OPEN I-O KSDSPOLY failed '
                       WS-KSDSPOLY-STATUS UPON SYSERR
               GOBACK
           END-IF.

      *   先讀取以定位記錄，再刪除
           READ KSDSPOLY-FILE WITH LOCK.

           IF NOT KSDSPOLY-OK
               MOVE '81'            TO CA-RETURN-CODE
               MOVE 1               TO WS-RESP
               MOVE WS-KSDSPOLY-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSPOLY-FILE
               GOBACK
           END-IF.

           DELETE KSDSPOLY-FILE RECORD.

           IF NOT KSDSPOLY-OK
               MOVE '81'            TO CA-RETURN-CODE
               MOVE 1               TO WS-RESP
               MOVE WS-KSDSPOLY-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSPOLY-FILE
               GOBACK
           END-IF.

           CLOSE KSDSPOLY-FILE.

      *---------------------------------------------------------------*

       A-EXIT.
           GOBACK.
      *---------------------------------------------------------------*
       WRITE-ERROR-MESSAGE.
      * [特性 B] ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)
           ACCEPT WS-CENTURY-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME-OF-DAY  FROM TIME
           MOVE WS-CENTURY-DATE     TO EM-DATE
           MOVE WS-TIME-OF-DAY(1:6) TO EM-TIME
           MOVE CA-Customer-Num TO EM-CUSNUM
           MOVE CA-Policy-Num   TO EM-POLNUM
           MOVE WS-RESP         TO EM-RESPRC
           MOVE WS-RESP2        TO EM-RESP2RC
      * [特性 E] CALL 取代 EXEC CICS LINK (手冊 p.217)
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG
           EXIT.
