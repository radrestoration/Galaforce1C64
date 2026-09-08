;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;;REM SAVE"WAVE"

;;B%=P%

;;[OPT pass

wave0:
.byte 10
.byte 0
.byte 2
.byte 43
.byte 1
.byte 11
.byte 10
.byte $FF
wave1:
.byte 8
.byte 6
.byte 7
.byte 6
.byte 7
.byte 4
.byte $FF
wave2:
.byte 10
.byte 5
.byte 8
.byte 9
.byte 13
.byte 14
.byte $FF
wave3:
.byte 8
.byte 10
.byte 11
.byte 23
.byte 24
.byte 2
.byte 3
.byte 45
.byte $FF
wave4:
.byte 10
.byte 16
.byte 17
.byte 18
.byte 15
.byte 5
.byte 27
.byte $FF
wave5:
.byte 10
.byte 6
.byte 7
.byte 6
.byte 7
.byte 12
.byte 19
.byte 20
.byte $FF
wave6:
.byte 8
.byte 10
.byte 11
.byte 10
.byte 11
.byte 2
.byte 3
.byte $FF
wave7:
.byte 8
.byte 13
.byte 14
.byte 21
.byte 22
.byte 23
.byte 24
.byte 45
.byte $FF
wave8:
.byte 10
.byte 4
.byte 4
.byte 0
.byte 1
.byte 5
.byte 17
.byte 18
.byte $FF
wave9:
.byte 7
.byte 8
.byte 9
.byte 12
.byte 44
.byte 2
.byte $FF
wave10:
.byte 8
.byte 25
.byte 26
.byte 15
.byte 16
.byte 29
.byte $FF
wave11:
.byte 10
.byte 27
.byte 28
.byte 12
.byte 37
.byte 38
.byte 28
.byte 45
.byte $FF
wave12:
.byte 10
.byte 29
.byte 30
.byte 8
.byte 9
.byte 31
.byte 32
.byte $FF
wave13:
.byte 8
.byte 33
.byte 34
.byte 15
.byte 16
.byte 25
.byte 26
.byte $FF
wave14:
.byte 8
.byte 23
.byte 24
.byte 35
.byte 36
.byte 21
.byte 22
.byte $FF
wave15:
.byte 8
.byte 39
.byte 40
.byte 3
.byte 10
.byte 11
.byte 41
.byte 42
.byte 45
.byte $FF

;;]
;; PRINT"Wave from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;;RETURN
