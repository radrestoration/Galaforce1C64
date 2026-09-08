;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"PATT"
;; B%=P%
;; [OPT pass

patt0:
.byte 1
.byte 0
.byte 50
.byte 5
.byte 20
.byte 0
.byte 5
.byte 12
.byte 0

patt1:
.byte 1
.byte 73
.byte 50
.byte 5
.byte 20
.byte 0
.byte 5
.byte 12
.byte 0+$80

patt2:
.byte 1
.byte 12
.byte 24
.byte 4
.byte 30
.byte 0
.byte 0
.byte 18
.byte 1

patt3:
.byte 1
.byte 62
.byte 24
.byte 4
.byte 30
.byte 0
.byte 0
.byte 18
.byte 1+$80

patt4:
.byte 2
; init 2 patterns
.byte 0
.byte 255
.byte 20
.byte 2
.byte 8
.byte (-24) & $ff
.byte 20
.byte 2
; 2nd half
.byte 74
.byte 255
.byte 20
.byte 2
.byte (-8) & $ff
.byte (-24) & $ff
.byte 20
.byte 2+$80

patt5:
.byte 1
.byte 6
.byte 40
.byte 50
.byte 4
.byte 0
.byte 16
.byte 24
.byte 4

patt6:
.byte 2
.byte 0
.byte 231
.byte 8
.byte 10
.byte 0
.byte 0
.byte 24
.byte 5
; 2nd part
.byte 7
.byte 231
.byte 8
.byte 10
.byte 0
.byte 0
.byte 20
.byte 5

patt7:
.byte 2
.byte 73
.byte 231
.byte 8
.byte 10
.byte 0
.byte 0
.byte 24
.byte 5+$80
; 2nd part
.byte 66
.byte 231
.byte 8
.byte 10
.byte 0
.byte 0
.byte 20
.byte 5+$80

patt8:
.byte 1
.byte 36
.byte 32
.byte 6
.byte 15
.byte 0
.byte 0
.byte 20
.byte 6

patt9:
.byte 1
.byte 38
.byte 32
.byte 6
.byte 15
.byte 0
.byte 0
.byte 20
.byte 6+$80

patt10:
.byte 1
.byte 0
.byte 32
.byte 5
.byte 8
.byte 0
.byte 0
.byte 16
.byte 7

patt11:
.byte 1
.byte 73
.byte 32
.byte 5
.byte 8
.byte 0
.byte 0
.byte 16
.byte 7+$80

patt12:
.byte 2
.byte 33
.byte 32
.byte 6
.byte 12
.byte 0
.byte 0
.byte 30
; WAS 20
.byte 8
; 2nd part
.byte 41
.byte 32
.byte 6
.byte 12
.byte 0
.byte 0
.byte 30
; WAS 20
.byte 8+$80

patt13:
.byte 1
.byte 0
.byte 130
.byte 6
.byte 16
.byte 0
.byte 0
.byte 12
.byte 9

patt14:
.byte 1
.byte 74
.byte 130
.byte 6
.byte 16
.byte 0
.byte 0
.byte 12
.byte 9+$80

patt15:
.byte 1
.byte 0
.byte 210
.byte 5
.byte 12
.byte 0
.byte 0
.byte 18
.byte 10

patt16:
.byte 1
.byte 74
.byte 210
.byte 5
.byte 12
.byte 0
.byte 0
.byte 18
.byte 10+$80

patt17:
.byte 1
.byte 0
.byte 32
.byte 7
.byte 12
.byte 0
.byte 0
.byte 14
.byte 11

patt18:
.byte 1
.byte 74
.byte 32
.byte 7
.byte 12
.byte 0
.byte 0
.byte 14
.byte 11+$80

patt19:
.byte 1
.byte 48
.byte 32
.byte 5
.byte 10
.byte 0
.byte 0
.byte 16
.byte 13

patt20:
.byte 1
.byte 27
.byte 32
.byte 5
.byte 10
.byte 0
.byte 0
.byte 16
.byte 13+$80

patt21:
.byte 1
.byte 0
.byte 32
.byte 5
.byte 8
.byte 0
.byte 0
.byte 20
.byte 14

patt22:
.byte 1
.byte 74
.byte 32
.byte 5
.byte 8
.byte 0
.byte 0
.byte 20
.byte 14+$80

patt23:
.byte 1
.byte 2
.byte 255
.byte 3
.byte 20
.byte 0
.byte 0
.byte 20
.byte 15

patt24:
.byte 1
.byte 72
.byte 255
.byte 3
.byte 20
.byte 0
.byte 0
.byte 20
.byte 15+$80

patt25:
.byte 1
.byte 6
.byte 255
.byte 3
.byte 16
.byte 0
.byte 0
.byte 16
.byte 16

patt26:
.byte 1
.byte 69
.byte 255
.byte 3
.byte 16
.byte 0
.byte 0
.byte 16
.byte 16+$80

patt27:
.byte 1
.byte 0
.byte 32
.byte 4
.byte 14
.byte 0
.byte 0
.byte 18
.byte 17

patt28:
.byte 1
.byte 74
.byte 32
.byte 4
.byte 14
.byte 0
.byte 0
.byte 18
.byte 17+$80

patt29:
.byte 1
.byte 0
.byte 32
.byte 2
.byte 21
.byte 3
.byte 0
.byte 20
.byte 18

patt30:
.byte 1
.byte 74
.byte 32
.byte 2
.byte 21
.byte (-3) & $ff
.byte 0
.byte 20
.byte 18+$80

patt31:
.byte 1
.byte 73
.byte 32
.byte 4
.byte 12
.byte 0
.byte 0
.byte 32
.byte 19

patt32:
.byte 1
.byte 1
.byte 32
.byte 4
.byte 12
.byte 0
.byte 0
.byte 32
.byte 19+$80

patt33:
.byte 1
.byte 78
.byte 32
.byte 8
.byte 20
.byte 0
.byte 0
.byte 18
.byte 20

patt34:
.byte 1
.byte 79
.byte 32
.byte 8
.byte 20
.byte 0
.byte 0
.byte 18
.byte 20+$80

patt35:
.byte 1
.byte 74
.byte 32
.byte 4
.byte 14
.byte 0
.byte 0
.byte 34
.byte 21

patt36:
.byte 1
.byte 0
.byte 32
.byte 4
.byte 14
.byte 0
.byte 0
.byte 34
.byte 21+$80

patt37:
.byte 1
.byte 2
.byte 32
.byte 4
.byte 18
.byte 0
.byte 0
.byte 16
.byte 22

patt38:
.byte 1
.byte 72
.byte 32
.byte 4
.byte 18
.byte 0
.byte 0
.byte 16
.byte 22+$80

patt39:
.byte 1
.byte 78
.byte 32
.byte 5
.byte 12
.byte 0
.byte 0
.byte 20
.byte 23

patt40:
.byte 1
.byte 79
.byte 32
.byte 5
.byte 12
.byte 0
.byte 0
.byte 20
.byte 23+$80

patt41:
.byte 1
.byte 0
.byte 32
.byte 4
.byte 19
.byte 2
.byte 0
.byte 12
.byte 24

patt42:
.byte 1
.byte 74
.byte 32
.byte 4
.byte 19
.byte (-2) & $ff
.byte 0
.byte 12
.byte 24+$80

patt43:
.byte 2
.byte 78
.byte 32
.byte 16
.byte 20
.byte 0
.byte 0
.byte 16
.byte 25
; 2nd part
.byte 79
.byte 32
.byte 14
.byte 20
.byte 0
.byte 0
.byte 16
.byte 25+$80

patt44:
.byte 2
.byte 78
.byte 32
.byte 8
.byte 20
.byte 0
.byte 0
.byte 18
.byte 26
; part2
.byte 79
.byte 32
.byte 8
.byte 20
.byte 0
.byte 0
.byte 18
.byte 26+$80

patt45:
.byte 3
.byte 0
.byte 40
.byte 1
.byte 1
.byte 0
.byte 0
.byte 22
.byte 29
; part 2
.byte 0
.byte 72
.byte 4
.byte 16
.byte 0
.byte 0
.byte 26
.byte 27
; part 3
.byte 0
.byte 96
.byte 4
.byte 15
.byte 0
.byte 0
.byte 28
.byte 28

;; ]
;; PRINT"Patterns from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
