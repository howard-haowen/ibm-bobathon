      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *              ADD Customer  ─  VSAM KSDS 存取層                 *
      *                                                                *
      * 原始程式: LGACVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS Write File('KSDSCUST') → WRITE 陳述式             *
      *   EXEC CICS ABEND  → DISPLAY UPON SYSERR + STOP RUN           *
      *   EIBCALEN         → LENGTH OF DFHCOMMAREA                    *
      *   EXEC CICS RETURN → GOBACK                                   *
      *   EXEC CICS LINK PROGRAM('LGSTSQ') → CALL 'LGSTSQ'           *
      *   EXEC CICS ASKTIME/FORMATTIME → ACCEPT FROM CENTURY-DATE/TIME*
      *                                                                *
      * ACUCOBOL-GT 特性:                                              *
      *   [特性 B] ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)*
      *   [特性 C] ACCEPT FROM ENVIRONMENT       (手冊 p.190 Format 5)*
      *   [特性 E] CALL...USING BY REFERENCE     (手冊 p.217)         *
      *   [特性 F] FILE CONTROL INDEXED 組織      (手冊 p.73)          *
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. LGACVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織對應 z/OS VSAM KSDS                       *
      *   KSDSCUST 檔名由環境變數 GENAPP_KSDSCUST 取得                  *
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

      * 檔案路徑（由環境變數提供）
       01  WS-KSDSCUST-PATH            PIC X(256) VALUE SPACES.
       01  WS-KSDSCUST-STATUS          PIC XX     VALUE SPACES.
           88 KSDSCUST-OK                         VALUE '00'.
           88 KSDSCUST-DUP-KEY                    VALUE '22'.

       01  WS-RESP                     PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                    PIC S9(8) COMP VALUE 0.
       01  WS-Commarea-Len             PIC S9(4) COMP.

      * [特性 B] 日期時間變數 (手冊 p.190 Format 3)
       01  WS-CENTURY-DATE             PIC 9(8)  VALUE 0.
       01  WS-TIME-OF-DAY              PIC 9(8)  VALUE 0.
       01  WS-DATE                     PIC X(8)  VALUE SPACES.
       01  WS-TIME                     PIC X(8)  VALUE SPACES.

      * 錯誤訊息結構
       01  ERROR-MSG.
           03 EM-DATE                  PIC X(8)  VALUE SPACES.
           03 FILLER                   PIC X     VALUE SPACES.
           03 EM-TIME                  PIC X(6)  VALUE SPACES.
           03 FILLER                   PIC X(9)  VALUE ' LGACVS01'.
           03 EM-VARIABLE.
             05 FILLER                 PIC X(6)  VALUE ' CNUM='.
             05 EM-CUSNUM              PIC X(10) VALUE SPACES.
             05 FILLER                 PIC X(20)
                                         VALUE ' Write file KSDSCUST'.
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
      * [特性 C] 取得 VSAM 檔案路徑 (手冊 p.190 Format 5)
           ACCEPT WS-KSDSCUST-PATH FROM ENVIRONMENT 'GENAPP_KSDSCUST'
           IF WS-KSDSCUST-PATH = SPACES
               MOVE '/tmp/KSDSCUST' TO WS-KSDSCUST-PATH
           END-IF

           MOVE LENGTH OF DFHCOMMAREA TO WS-Commarea-Len.

           OPEN OUTPUT KSDSCUST-FILE.
           IF NOT KSDSCUST-OK
               MOVE '80' TO CA-RETURN-CODE
               MOVE 1    TO WS-RESP
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGACVS01: OPEN KSDSCUST failed '
                       WS-KSDSCUST-STATUS UPON SYSERR
               STOP RUN
           END-IF.

      *---------------------------------------------------------------*
      * WRITE 對應 EXEC CICS Write File('KSDSCUST')                   *
      *   原始以 CA-Customer-Num 作為 RIDFLD（記錄鍵值）               *
      *---------------------------------------------------------------*
           MOVE CA-Customer-Num TO WS-KSDSCUST-KEY.
           MOVE DFHCOMMAREA     TO KSDSCUST-RECORD.

           WRITE KSDSCUST-RECORD.

           IF NOT KSDSCUST-OK
               MOVE '80' TO CA-RETURN-CODE
               MOVE 1    TO WS-RESP
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSCUST-FILE
               DISPLAY 'LGACVS01: WRITE KSDSCUST failed '
                       WS-KSDSCUST-STATUS UPON SYSERR
               STOP RUN
           END-IF.

           CLOSE KSDSCUST-FILE.

      *---------------------------------------------------------------*

       A-EXIT.
           GOBACK.
      *---------------------------------------------------------------*
       WRITE-ERROR-MESSAGE.
      * [特性 B] 使用 ACCEPT FROM CENTURY-DATE/TIME (手冊 p.190 Format 3)
      *   取代 EXEC CICS ASKTIME / FORMATTIME
           ACCEPT WS-CENTURY-DATE FROM CENTURY-DATE
           ACCEPT WS-TIME-OF-DAY  FROM TIME
           MOVE WS-CENTURY-DATE   TO EM-DATE
           MOVE WS-TIME-OF-DAY(1:6) TO EM-TIME
      *
           MOVE CA-Customer-Num TO EM-CUSNUM
           MOVE WS-RESP         TO EM-RESPRC
           MOVE WS-RESP2        TO EM-RESP2RC
      * [特性 E] CALL 取代 EXEC CICS LINK (手冊 p.217)
           CALL 'LGSTSQ' USING BY REFERENCE ERROR-MSG
           MOVE DFHCOMMAREA(1:90)   TO CA-DATA
           CALL 'LGSTSQ' USING BY REFERENCE CA-ERROR-MSG
           EXIT.
