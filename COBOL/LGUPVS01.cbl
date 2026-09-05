      ******************************************************************
      *                                                                *
      * LICENSED MATERIALS - PROPERTY OF IBM                           *
      *                                                                *
      * CB12                                                           *
      *                                                                *
      * (C) COPYRIGHT IBM CORP. 2011, 2013 ALL RIGHTS RESERVED         *
      *                                                                *
      *                                                                *
      *           Update Policy  ─  VSAM KSDS 存取層                   *
      *                                                                *
      * 原始程式: LGUPVS01.cbl (CICS/VSAM)                             *
      * 轉置目標: ACUCOBOL-GT v11.0                                    *
      *                                                                *
      * 功能說明:                                                       *
      *   依保單類型（C/E/H/M）組裝 WF-Policy-Info，然後：               *
      *   1. READ KSDSPOLY … WITH LOCK（對應 EXEC CICS Read File Update）*
      *   2. REWRITE（對應 EXEC CICS ReWrite File）                    *
      *                                                                *
      * 轉置摘要:                                                       *
      *   EXEC CICS Read  File Update → READ WITH LOCK                *
      *   EXEC CICS ReWrite File      → REWRITE KSDSPOLY-RECORD       *
      *   EXEC CICS ABEND ABCODE('LGV3') → DISPLAY UPON SYSERR + STOP *
      *   EXEC CICS ABEND ABCODE('LGV4') → DISPLAY UPON SYSERR + STOP *
      *   EIBCALEN                        → LENGTH OF DFHCOMMAREA     *
      *   EIBRESP2                        → WS-KSDSPOLY-STATUS        *
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
       PROGRAM-ID. LGUPVS01.
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
      *
      *----------------------------------------------------------------*
      * [特性 F] INDEXED 組織 + READ WITH LOCK + REWRITE               *
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
           03 WF-Policy-Data          PIC X(43).
           03 WF-C-Policy-Data REDEFINES WF-Policy-Data.
             05 WF-B-Postcode         PIC X(8).
             05 WF-B-Status           PIC 9(4).
             05 WF-B-Customer         PIC X(31).
           03 WF-E-Policy-Data REDEFINES WF-Policy-Data.
             05 WF-E-WITH-PROFITS     PIC X.
             05 WF-E-EQUITIES         PIC X.
             05 WF-E-MANAGED-FUND     PIC X.
             05 WF-E-FUND-NAME        PIC X(10).
             05 WF-E-LIFE-ASSURED     PIC X(30).
           03 WF-H-Policy-Data REDEFINES WF-Policy-Data.
             05 WF-H-PROPERTY-TYPE    PIC X(15).
             05 WF-H-BEDROOMS         PIC 999.
             05 WF-H-VALUE            PIC 9(8).
             05 WF-H-POSTCODE         PIC X(8).
             05 WF-H-HOUSE-NAME       PIC X(9).
           03 WF-M-Policy-Data REDEFINES WF-Policy-Data.
             05 WF-M-MAKE             PIC X(15).
             05 WF-M-MODEL            PIC X(15).
             05 WF-M-VALUE            PIC 9(6).
             05 WF-M-REGNUMBER        PIC X(7).

       WORKING-STORAGE SECTION.

      * 眼睛捕捉字（Eyecatcher）
       77  Eyecatcher                 PIC X(16) VALUE 'Program LGUPVS01'.

      * 固定長度常數（原始以 COMP VALUE 64 宣告）
       01  WS-Commarea-Len            PIC S9(4) COMP VALUE 64.
       01  WS-Commarea-LenF           PIC S9(4) COMP VALUE 64.

       01  WS-RESP                    PIC S9(8) COMP VALUE 0.
       01  WS-RESP2                   PIC S9(8) COMP VALUE 0.
       01  WS-FileIn                  PIC X(1024)   VALUE SPACES.

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
           03 FILLER                  PIC X(9)  VALUE ' LGUPVS01'.
           03 EM-VARIABLE.
             05 FILLER                PIC X(6)  VALUE ' PNUM='.
             05 EM-POLNUM             PIC X(10) VALUE SPACES.
             05 FILLER                PIC X(6)  VALUE ' CNUM='.
             05 EM-CUSNUM             PIC X(10) VALUE SPACES.
             05 FILLER                PIC X(20)
                                        VALUE ' Re-write  KSDSPOLY '.
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
      * 組裝保單記錄鍵值及對應欄位
      *---------------------------------------------------------------*
           MOVE CA-Request-ID(4:1) TO WF-Request-ID
           MOVE CA-Policy-Num      TO WF-Policy-Num
           MOVE CA-Customer-Num    TO WF-Customer-Num

           EVALUATE WF-Request-ID

             WHEN 'C'
               MOVE CA-B-Postcode  TO WF-B-Postcode
               MOVE CA-B-Status    TO WF-B-Status
               MOVE CA-B-Customer  TO WF-B-Customer

             WHEN 'E'
               MOVE CA-E-WITH-PROFITS TO WF-E-WITH-PROFITS
               MOVE CA-E-EQUITIES     TO WF-E-EQUITIES
               MOVE CA-E-MANAGED-FUND TO WF-E-MANAGED-FUND
               MOVE CA-E-FUND-NAME    TO WF-E-FUND-NAME
               MOVE CA-E-LIFE-ASSURED TO WF-E-LIFE-ASSURED

             WHEN 'H'
               MOVE CA-H-PROPERTY-TYPE TO WF-H-PROPERTY-TYPE
               MOVE CA-H-BEDROOMS      TO WF-H-BEDROOMS
               MOVE CA-H-VALUE         TO WF-H-VALUE
               MOVE CA-H-POSTCODE      TO WF-H-POSTCODE
               MOVE CA-H-HOUSE-NAME    TO WF-H-HOUSE-NAME

             WHEN 'M'
               MOVE CA-M-MAKE          TO WF-M-MAKE
               MOVE CA-M-MODEL         TO WF-M-MODEL
               MOVE CA-M-VALUE         TO WF-M-VALUE
               MOVE CA-M-REGNUMBER     TO WF-M-REGNUMBER

             WHEN OTHER
               MOVE SPACES TO WF-Policy-Data
           END-EVALUATE

           MOVE CA-Policy-Num TO WF-Policy-Num

      *---------------------------------------------------------------*
      * READ … WITH LOCK 對應 EXEC CICS Read File Update              *
      *---------------------------------------------------------------*
           OPEN I-O KSDSPOLY-FILE.
           IF NOT KSDSPOLY-OK
               MOVE '81' TO CA-RETURN-CODE
               MOVE 1    TO WS-RESP
               PERFORM WRITE-ERROR-MESSAGE
               DISPLAY 'LGUPVS01: OPEN I-O KSDSPOLY failed '
                       WS-KSDSPOLY-STATUS UPON SYSERR
               STOP RUN
           END-IF.

           READ KSDSPOLY-FILE WITH LOCK.

           IF NOT KSDSPOLY-OK
               MOVE '81'            TO CA-RETURN-CODE
               MOVE 1               TO WS-RESP
               MOVE WS-KSDSPOLY-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSPOLY-FILE
               DISPLAY 'LGUPVS01: READ WITH LOCK failed ABCODE=LGV3 '
                       WS-KSDSPOLY-STATUS UPON SYSERR
               STOP RUN
           END-IF.

      *---------------------------------------------------------------*
      * REWRITE 對應 EXEC CICS ReWrite File                           *
      *---------------------------------------------------------------*
           REWRITE KSDSPOLY-RECORD.

           IF NOT KSDSPOLY-OK
               MOVE '82'            TO CA-RETURN-CODE
               MOVE 2               TO WS-RESP
               MOVE WS-KSDSPOLY-STATUS TO WS-RESP2
               PERFORM WRITE-ERROR-MESSAGE
               CLOSE KSDSPOLY-FILE
               DISPLAY 'LGUPVS01: REWRITE KSDSPOLY failed ABCODE=LGV4 '
                       WS-KSDSPOLY-STATUS UPON SYSERR
               STOP RUN
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
