;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;;REM SAVE"ZPWORK"

;;P%=0
;;P%=0O%=&3000

;;[OPT 6

;;.segment "ZEROPAGE"
.zeropage

.res $22

colour:
  .byte 0
screen:
  .word 0
savey:
  .byte  0

data:
  .byte 0
  .byte 0

temp:
temp1:
  .byte  0
length:
  .byte  0

width:
temp2:
  .word  0

addres:
temp3:
  .word 0
addres1:
temp4:
wavbase:
  .word  0
;bitmask:

;stardat:
;.res 3 * 31
rand1:
  .res 3
counter:
  .byte 0
expldelay:
  .byte 0


src_col0 = temp+2
src_col1 = temp+3
src_col2 = temp+4
src_col3 = temp+5
src_col4 = temp+6

.segment "ZP2" : zeropage
screen2:
  .byte  0
  .byte  0

.segment "ZEROPAGE"
initst:
  .res maxpatt
initx:
  .res maxpatt
inity:
  .res maxpatt
initdel:
  .res maxpatt
initcount:
  .res maxpatt
initnum:
  .res maxpatt
initrelx:
  .res maxpatt
initrely:
  .res maxpatt
initgra:
  .res maxpatt
initpnum:
  .res maxpatt

.org $A9
.segment "ZP2" : zeropage

aliens:
  .byte  0
aliensm1:
  .byte  0
bitmask:
  .byte  0



;; ]
;; PRINT'"Zero page from 0 to &";~P%-1
;; PAGE=&5800
;;RETURN

;; DEFFNres2(gap%)
;; P%=P%+gap%
;; P%=P%+gap%O%=O%+gap%
;; =6
