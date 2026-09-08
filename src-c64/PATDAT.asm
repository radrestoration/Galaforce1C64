;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"PATDAT"
;; B%=P%
;; [OPT pass

patdat0:
.byte $86
.byte 9
.byte $83
.byte 12
.byte 10
.byte 1
.byte $86
.byte 13
.byte $86
.byte 12
.byte 12
.byte $83
.byte 13
.byte 6

patdat1:
.byte $97
.byte 13
.byte $94
.byte 11
.byte $98
.byte 12
.byte 6

patdat2:
.byte $88
.byte 12
.byte $88
.byte 15
.byte $88
.byte 12
.byte 10
.byte 100
.byte $84
.byte 1
.byte 4
.byte 3
.byte $84
.byte 3
.byte 12
.byte 6

patdat3:
.byte $88
.byte 9
.byte $83
.byte 10
.byte $88
.byte 11
.byte $83
.byte 10
.byte 0
.byte 0

patdat4:
.byte 10
.byte 2
.byte $87
.byte 9
.byte 4
.byte 12
.byte 12
.byte $87
.byte 9
.byte $87
.byte 11
.byte 10
.byte 2
.byte 4
.byte 12
.byte $87
.byte 11
.byte 12
.byte 0
.byte 0

patdat5:
.byte $8D
.byte 12
.byte $88
.byte 0
.byte $84
.byte 3
.byte $88
.byte 6
.byte $88
.byte 5
.byte $8D
.byte 20
.byte 6

patdat6:
.byte $84
.byte 18
.byte $85
.byte 9
.byte $86
.byte 18
.byte $88
.byte 9
.byte $85
.byte 18
.byte $86
.byte 9
.byte 6

patdat7:
.byte $93
.byte 13
.byte $88
.byte 9
.byte $82
.byte 4
.byte $87
.byte 7
.byte $86
.byte 15
.byte $87
.byte 23
.byte 6

patdat8:
.byte $88
.byte 10
.byte $84
.byte 21
.byte $86
.byte 10
.byte $84
.byte 5
.byte $82
.byte 1
.byte $84
.byte 4
.byte $88
.byte 12
.byte $84
.byte 8
.byte $8B
.byte 15
.byte 6

patdat9:
.byte $85
.byte 9
.byte $85
.byte 12
.byte $85
.byte 8
.byte $85
.byte 7
.byte $85
.byte 3
.byte $87
.byte 6
.byte $86
.byte 2
.byte $8E
.byte 13
.byte $89
.byte 17
.byte $8A
.byte 13
.byte 6

patdat10:
.byte $83
.byte 20
.byte $83
.byte 24
.byte $84
.byte 16
.byte $84
.byte 8
.byte $84
.byte 4
.byte $84
.byte 1
.byte $82
.byte 9
.byte $88
.byte 5
.byte $8A
.byte 13
.byte $87
.byte 21
.byte $85
.byte 10
.byte 6

patdat11:
.byte $86
.byte 13
.byte $84
.byte 5
.byte $85
.byte 9
.byte $86
.byte 52
.byte $89
.byte 9
.byte $89
.byte 49
.byte $84
.byte 10
.byte $84
.byte 14
.byte $85
.byte 54
.byte $87
.byte 11
.byte $93
.byte 51
.byte 6

patdat12:
.byte $88
.byte 6
.byte $85
.byte 1
.byte $8F
.byte 5
.byte $8F
.byte 6
.byte $88
.byte 5
.byte $85
.byte 3
.byte 0
.byte 0

patdat13:
.byte $88
.byte 14
.byte $85
.byte 54
.byte $85
.byte 11
.byte $84
.byte 51
.byte $85
.byte 8
.byte $85
.byte 52
.byte $83
.byte 9
.byte $87
.byte 13
.byte $85
.byte 21
.byte $87
.byte 29
.byte 6

patdat14:
.byte 10
.byte 1
.byte $8C
.byte 13
.byte $83
.byte 49
.byte $82
.byte 9
.byte $82
.byte 52
.byte $81
.byte 11
.byte $82
.byte 48
.byte $81
.byte 8
.byte $82
.byte 55
.byte $82
.byte 15
.byte $83
.byte 11
.byte $82
.byte 54
.byte $81
.byte 14
.byte $82
.byte 50
.byte $82
.byte 53
.byte 12
.byte $87
.byte 13
.byte 6

patdat15:
.byte $87
.byte 16
.byte $85
.byte 48
.byte $83
.byte 12
.byte $85
.byte 52
.byte $86
.byte 17
.byte $85
.byte 49
.byte $83
.byte 13
.byte $85
.byte 53
.byte $88
.byte 18
.byte 6

patdat16:
.byte $8D
.byte 48
.byte $82
.byte 52
.byte $82
.byte 9
.byte $82
.byte 49
.byte $82
.byte 13
.byte $82
.byte 53
.byte $82
.byte 10
.byte $82
.byte 50
.byte $82
.byte 14
.byte $82
.byte 54
.byte $82
.byte 11
.byte $82
.byte 51
.byte $82
.byte 15
.byte $82
.byte 55
.byte $82
.byte 8
.byte $82
.byte 48
.byte $82
.byte 12
.byte $82
.byte 52
.byte $82
.byte 9
.byte $82
.byte 49
.byte $8E
.byte 53
.byte 6

patdat17:
.byte $8D
.byte 21
.byte $83
.byte 49
.byte $84
.byte 9
.byte $85
.byte 12
.byte $84
.byte 8
.byte $83
.byte 15
.byte $83
.byte 23
.byte $84
.byte 15
.byte $83
.byte 11
.byte $84
.byte 14
.byte $83
.byte 22
.byte $83
.byte 14
.byte $84
.byte 10
.byte $85
.byte 13
.byte $84
.byte 9
.byte $83
.byte 52
.byte $8D
.byte 20
.byte $82
.byte 8
.byte 6

patdat18:
.byte $86
.byte 13
.byte $86
.byte 14
.byte 0
.byte 0

patdat19:
.byte 10
.byte 3
.byte $83
.byte 18
.byte $81
.byte 50
.byte 12
.byte $85
.byte 54
.byte $84
.byte 11
.byte $96
.byte $40
.byte 10
.byte 1
.byte $85
.byte 15
.byte $84
.byte 8
.byte $84
.byte 12
.byte $83
.byte 52
.byte $83
.byte 9
.byte $83
.byte 13
.byte $83
.byte 10
.byte $83
.byte 14
.byte $84
.byte 54
.byte $88
.byte 11
.byte 12
.byte $83
.byte 15
.byte $84
.byte 55
.byte $8C
.byte 8
.byte 6

patdat20:
.byte $8C
.byte 10
.byte 10
.byte 3
.byte $81
.byte $40
.byte 8
.byte $81
.byte $40
.byte 12
.byte $89
.byte 20
.byte 6

patdat21:
.byte $94
.byte 14
.byte $84
.byte 54
.byte $85
.byte 11
.byte $83
.byte 15
.byte $83
.byte 55
.byte $84
.byte 8
.byte $82
.byte 48
.byte $84
.byte 12
.byte $82
.byte 52
.byte $8C
.byte 9
.byte $84
.byte 49
.byte $83
.byte 13
.byte $83
.byte 53
.byte $83
.byte 10
.byte $83
.byte 50
.byte $84
.byte 14
.byte $83
.byte 54
.byte $86
.byte 19
.byte $84
.byte 51
.byte $86
.byte 19
.byte 6

patdat22:
.byte $87
.byte 18
.byte $85
.byte 53
.byte $83
.byte 13
.byte $85
.byte 49
.byte $86
.byte 17
.byte $85
.byte 52
.byte $83
.byte 12
.byte $85
.byte 48
.byte $88
.byte 16
.byte 6

patdat23:
.byte $9D
.byte 5
.byte $86
.byte 9
.byte $9D
.byte 6
.byte $86
.byte 11
.byte 0
.byte 0

patdat24:
.byte $82
.byte 10
.byte $83
.byte 13
.byte $8D
.byte 49
.byte $83
.byte 13
.byte $82
.byte 10
.byte $83
.byte 14
.byte $8D
.byte 54
.byte $83
.byte 14
.byte 0
.byte 0

patdat25:
.byte $90
.byte 2
.byte $83
.byte 9
.byte $A0
.byte 2
.byte $8D
.byte 48
.byte 6


patdat26:
.byte $A5
.byte 5
.byte $90
.byte 6
.byte $84
.byte 1
.byte $90
.byte 4
.byte $A8
.byte 7
.byte 6

patdat27:
.byte $A4
.byte 9
.byte $83
.byte 10
.byte $A4
.byte 11
patdat28:
.byte $83
.byte 10
.byte $A4
.byte 9
.byte $83
.byte 10
.byte $A4
.byte 11
.byte 14
.byte 2
.byte 27

patdat29:
.byte $C5
.byte 1
.byte $C5
.byte 3
.byte 0
.byte 0

;; ]
;; PRINT"Pattern dt from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
