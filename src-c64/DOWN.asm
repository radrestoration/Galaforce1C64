;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE":2.DOWN"
;; MODE7
;; MODE7HIMEM=&4000

osbyte=$FFF4
HIMEM		= $4000
downaddr	= HIMEM

;; REM These may change !!
hstxt		= $64D
hsnum		= $69D

;; FORpass=0TO2STEP2
;; FORpass=0TO2STEP2P%=HIMEM
;; B%=P%
;; [OPT pass

.org  downaddr

; download routine

download:
 LDA #$8C
 JSR osbyte; tape filing system
 LDA #4
 LDX #1
 JSR osbyte ; cursor editing
 LDX #$9F
 LDA #0
killzp:
 STA 0,X
 DEX 
 BNE killzp
 STA 0
dowfont:
 LDA #0
 STA $400,X
 STA $500,X
 STA $600,X
 LDA $1900,X
 STA $700,X
 INX 
 BNE dowfont
 LDY #$27
download2:
 LDA $1A00,X
 STA $A00,X
 INX 
 BNE download2
 INC download2+2
 INC download2+5
 DEY 
 BNE download2

 LDY #8*7-1
coph2:
 LDA highval,Y
 STA hsnum,Y
 DEY 
 BPL coph2
 LDY #8*10-1
coph3:
 LDA highname,Y
 STA hstxt,Y
 DEY 
 BPL coph3

 LDX #$F
 LDA #0
killsroms:
 STA $2A1,X
 DEX 
 BPL killsroms

 JMP  $BEF
; MAY CHANGE!!

highval:
.byte 0
.byte 0
.byte 3
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 2
.byte 5
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 2
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 1
.byte 5
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 1
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 5
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 3
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 0
.byte 1
.byte 0
.byte 0
.byte 0

highname:
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38
.byte 28
.byte 30
.byte 25
.byte 14
.byte 27
.byte 18
.byte 24
.byte 27
.byte 38
.byte 38

;; ]NEXT
;; PRINT"Down from &";~B%;" to &";~P%-1;" (";P%-B%;")"
