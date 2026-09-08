;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE":2.TITLE"
;; B%=P%

titcol=3

;; [OPT pass

title:
 LDA #$70
 STA temp2
 LDA #$F0
 STA temp3
 LDA #$3A
 STA temp2+1
 LDA #$3C
 STA temp3+1
 LDX #0
 STX temp4+1
gchr:
 LDX temp4+1
 LDA titnam,X
 BMI tit6
 STA temp1
 ASL A
 ASL A
 CLC 
 ADC temp1
 TAX 
 LDA #5
 STA temp4
tit1:
 LDA $700,X
 STA temp1
 LDA #4
 STA temp1+1
 LDY #0
tit2:
 LSR temp1
 BCC tit3
 LDA #titcol
 EOR (temp2),Y
 STA (temp2),Y
 INY 
 LDA #titcol
 EOR (temp2),Y
 STA (temp2),Y
 DEY 
tit3:
 LDA #8
 AND temp1
 BEQ tit4
 LDA #titcol
 EOR (temp3),Y
 STA (temp3),Y
 INY 
 LDA #titcol
 EOR (temp3),Y
 STA (temp3),Y
 DEY 
tit4:
 INY 
 INY 
 DEC temp1+1
 BNE tit2
 JSR titrig
 INX 
 DEC temp4
 BNE tit1
 JSR titrig
 INC temp4+1
 BNE gchr
; always

titrig:
 LDA temp2
 CLC 
 ADC #8
 STA temp2
 BCC tit5
 INC temp2+1
tit5:
 LDA temp3
 CLC 
 ADC #8
 STA temp3
 BCC tit6
 INC temp3+1
tit6:
 RTS 

titnam:
.byte 16
.byte 10
.byte 21
.byte 10
;GALA
.byte 15
.byte 24
.byte 27
.byte 12
;FORC
.byte 14
.byte $FF
;E

;; ]
;; PRINT"Title from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; PAGE=&5800RETURN
