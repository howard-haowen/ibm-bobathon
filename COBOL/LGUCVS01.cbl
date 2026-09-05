      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *           Update Customer  ─  VSAM KSDS 存取層                 *
      *                                                                *
      * 原始程式: LGUCVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 功能說明:                                                       *
      *   1. READ … WITH LOCK（對應 EXEC CICS Read File Update）       *
      *   2. REWRITE（對應 EXEC CICS ReWrite File）                    *
      *   步驟需連續，檔案保持開啟以維持鎖定                               *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS Read  File Update → READ KSDSCUST WITH LOCK       *
      *   EXEC CICS ReWrite File      → REWRITE KSDSCUST-RECORD       *
      *   EXEC CICS ABEND ABCODE('LGV1') → DISPLAY UPON SYSERR + STOP *
      *   EXEC CICS ABEND ABCODE('LGV2') → DISPLAY UPON SYSERR + STOP *
      *   EIBCALEN                        → LENGTH OF DFHCOMMAREA     *
      *   EIBRESP2                        → WS-KSDSCUST-STATUS        *
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
       PROGRAM-ID. LGUCVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織對應 z/OS VSAM KSDS KSDSCUST              *
      *   READ WITH LOCK + REWRITE 維持原子性更新                       *
      *----------------------------------------------------------------*
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT KSDSCUST-FILE
               ASSIGN TO DYNAMIC WS-KSDSCUST-PATH
               ORGANIZATION IS INDEXED
               ACCESS MODE IS RANDOM
               RECORD KEY IS WS-KSDSCUST-KEY
               FILE STATUS IS WS-KSDSCUST-STATUS.

       DATA DIVISION.
       FILE SECTION.
       FD  KSDSCUST-FILE
           RECORD CONTAINS 1024 CHARACTERS.
       01  KSDSCUST-RECORD.
           03 WS-KSDSCUST-KEY          PIC X(10).
           03 WS-KSDSCUST-DATA         PIC X(1014).

       WORKING-STORAGE SECTION.

       01  WS-RESP                     PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                    PIC S9(8) COMP VALUE 0.
       01  WS-Commarea-Len             PIC S9(4) COMP.
       01  WS-Commarea-LenF            PIC S9(4) COMP.
       01  WS-Customer-Area            PIC X(1024) VALUE SPACES.

      * 檔案路徑及狀態
       01  WS-KSDSCUST-PATH            PIC X(256) VALUE SPACES.
       01  WS-KSDSCUST-STATUS          PIC XX     VALUE SPACES.
           88 KSDSCUST-OK                         VALUE '00'.

      * [特性 B] 日期時間變數 (手冊 p.190 Format 3)
       01  WS-CENTURY-DATE             PIC 9(8)  VALUE 0.
       01  WS-TIME-OF-DAY              PIC 9(8)  VALUE 0.

      * 錯誤訊息結構
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)  VALUE SPACES.
           03 FILLER                   PIC X     VALUE SPACES.
           03 EM-TIME                  PIC X(6)  VALUE SPACES.
           03 FILLER                   PIC X(9)  VALUE ' LGUCVS01'.
           03 EM-VARIABLE.
             05 FILLER                 PIC X(6)  VALUE ' CNUM='.
             05 EM-CUSNUM              PIC X(10) VALUE SPACES.
             05 FILLER                 PIC X(20)
                                         VALUE ' Re-write  KSDSCUST '.
             05 FILLER                 PIC X(6)  VALUE ' RESP='.
             05 EM-RESPRC              PIC +9(5) USAGE DISPLAY.
             05 FILLER                 PIC X(7)  VALUE ' RESP2='.
             05 EM-RESP2RC             PIC +9(5) USAGE DISPLAY.

       01  CA-ERROR-MSG.
           03 FILLER                   PIC X(9)  VALUE 'COMMAREA='.
           03 CA-DATA                  PIC X(90) VALUE SPACES.

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
           MOVE LENGTH OF DFHCOMMAREA TO WS-Commarea-LenF.

      * [特性 C] 取得 VSAM 檔案路徑 (手冊 p.190 Format 5)
           ACCEPT WS-KSDSCUST-PATH FROM ENVIRONMENT 'GENAPP_KSDSCUST'
           IF WS-KSDSCUST-PATH = SPACES
               MOVE '/tmp/KSDSCUST' TO WS-KSDSCUST-PATH
           END-IF

      *---------------------------------------------------------------*
      * READ … WITH LOCK 對應 EXEC CICS Read File Update              *
      *   持有鎖定直到 REWRITE，模擬 CICS 樂觀鎖定語意                   *
      *---------------------------------------------------------------*
           OPEN I-O KSDSCUST-FILE.
           IF NOT KSDSCUST-OK
               MOVE '81' TO CA-RETURN-CODE
               MOVE 1    TO WS-RESP
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGUCVS01: OPEN I-O KSDSCUST failed '
                       WS-KSDSCUST-STATUS UPON SYSERR
               STOP RUN
           END-IF.

           MOVE CA-Customer-Num TO WS-KSDSCUST-KEY.
           READ KSDSCUST-FILE WITH LOCK.

           IF NOT KSDSCUST-OK
               MOVE '81'            TO CA-RETURN-CODE
               MOVE 1               TO WS-RESP
               MOVE WS-KSDSCUST-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSCUST-FILE
               DISPLAY 'LGUCVS01: READ WITH LOCK failed ABCODE=LGV1 '
                       WS-KSDSCUST-STATUS UPON SYSERR
               STOP RUN
           END-IF.

      *---------------------------------------------------------------*
      * REWRITE 對應 EXEC CICS ReWrite File                           *
      *   將 COMMAREA 內容（從 CA-Customer-Num 開始）回寫               *
      *---------------------------------------------------------------*
           MOVE CA-Customer-Num TO WS-KSDSCUST-KEY.
           MOVE DFHCOMMAREA     TO KSDSCUST-RECORD.

           REWRITE KSDSCUST-RECORD.

           IF NOT KSDSCUST-OK
               MOVE '82'            TO CA-RETURN-CODE
               MOVE 2               TO WS-RESP
               MOVE WS-KSDSCUST-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSCUST-FILE
               DISPLAY 'LGUCVS01: REWRITE KSDSCUST failed ABCODE=LGV2 '
                       WS-KSDSCUST-STATUS UPON SYSERR
               STOP RUN
           END-IF.

           CLOSE KSDSCUST-FILE.

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
           MOVE WS-RESP         TO EM-RESPRC
           MOVE WS-RESP2        TO EM-RESP2RC
      * [特性 E] CALL 取代 EXEC CICS LINK (手冊 p.217)
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG
           MOVE DFHCOMMAREA(1:90) TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG
           EXIT.
