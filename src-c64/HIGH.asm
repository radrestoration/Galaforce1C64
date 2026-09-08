;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE":2.HIGH"
;; B%=P%
;; [OPT pass

ahigh:
 BIT demo_flag
 BMI ahdem
 LDX #0
 STX temp1
ah1:
 LDA ti10,X
 STA temp2
 LDY ti7,X
 STY temp1+1
 LDX #$FF
ah2:
 INY 
 INX 
 CPX #7
 BEQ ah4
 LDA myscore,X
 AND #$7F
 CMP hsnum,Y
 BEQ ah2
 BCC ah3
 BNE ah4
ah3:
 INC temp1
 LDX temp1
 CPX #8
 BCC ah1
ahdem:
 RTS 

ah4:
 LDA temp1+1
 CMP #7*7-1
 BEQ ah5
 LDY #7*7-1
ah6:
 LDA hsnum,Y
 STA hsnum+7,Y
 DEY 
 CPY temp1+1
 BNE ah6

 LDY #10*7-1
ah7:
 LDA hstxt,Y
 STA hstxt+10,Y
 DEY 
 CPY temp2
 BNE ah7

ah5:
 LDX #0
 LDY temp1+1
 INY 
ah8:
 LDA myscore,X
 AND #$7F
 STA hsnum,Y
 INY 
 INX 
 CPX #7
 BNE ah8
 LDX #9
 LDY temp2
 INY 
 TYA 
 PHA 
 LDA #38
; My space character
ah9:
 STA hstxt,Y
 INY 
 DEX 
 BPL ah9
 LDA temp1
 ASL A
 ASL A
 ASL A
 ASL A
 CLC 
 ADC #9*8
 PHA 
 JSR pht
 LDY #36
 JSR prnstr
 PLA 
 TAY 
 LDX #41
 JSR xycalc2
 STA za+1
 STX za
 PLA 
 TAX 
 JSR gnam
 LDY #36
 JSR prnstr
 JMP pht

pht:
 LDA #0
 STA wavbase
 LDA #$46
 STA zb+1
 LDA #$C0
 STA zb
ai1:
 LDX wavbase
 INX 
 STX zt
 DEX 
 LDY ti7,X
 INY 
 LDX #0
 STX wavbase+1
ai2:
 LDA hsnum,Y
 BNE ph2
 CMP wavbase+1
 BNE ph2
 LDA #38
 BNE ph3
ph2:
 SEC 
 ROR wavbase+1
ph3:
 STA zt+2,X
 INY 
 INX 
 CPX #7
 BNE ai2
 LDX wavbase
 LDY ti10,X
 INY 
 LDX #0
ai3:
 LDA hstxt,Y
 STA zt+11,X
 INY 
 INX 
 CPX #10
 BNE ai3
 LDY #34
 JSR prnstr
 LDA zb+1
 CLC 
 ADC #5
 STA zb+1
 INC wavbase
 LDA wavbase
 CMP #8
 BCC ai1
 RTS 

gnam:
 LDY #10
 BNE gn1
gn3:
 LDA #7
 JSR oswrch ; write character - beep?
gn1:
 STX wavbase
 STY wavbase+1
 LDA #21
 LDX #0
 ; Flush keyboard buffer - https://tobylobster.github.io/mos/mos/S-s17.html#SP29
 JSR osbyte ; flush keyboard
gn6:
 JSR movestars
 LDA #$7E
 JSR osbyte ; acknowledge escape
 LDA #$81
 LDX #2
 LDY #0
 JSR osbyte ; read inkey -2
 BCS gn6
 TXA 
 LDX wavbase
 LDY wavbase+1
 CMP #$D
 BEQ gn2
 CMP #$7F
 BEQ hdel
 CPY #0
 BEQ gn3
 CMP #' '
 BNE gn7
 LDA #38
 BNE gn8
gn7:
 CMP #'A'
 BCC gn9
 CMP #'Z'+1
 BCS gn3
 SBC #54
 BNE gn8
gn9:
 CMP #'0'
 BCC gn3
 CMP #'9'+1
 BCS gn3
 SBC #'0'-1
gn8:
 STA zs
 STA hstxt,X
 JSR pit
 LDA za
 CLC 
 ADC #24
 STA za
 BCC gn4
 INC za+1
gn4:
 INX 
 DEY 
 BPL gn1
gn2:
 RTS 

hdel:
 CPY #10
 BEQ gn3
 LDA za
 SEC 
 SBC #24
 STA za
 BCS gn5
 DEC za+1
gn5:
 INY 
 DEX 
 LDA hstxt,X
 STA zs
 JSR pit
 LDA #38
; space
 STA hstxt,X
 JMP gn1

pit:
 TXA 
 PHA 
 TYA 
 PHA 
 LDY #32
 JSR prnstr
 PLA 
 TAY 
 PLA 
 TAX 
 RTS 

ti7:
.byte (0-1) & $ff
.byte (7-1) & $ff
.byte (14-1) & $ff
.byte (21-1) & $ff
.byte (28-1) & $ff
.byte (35-1) & $ff
.byte (42-1) & $ff
.byte (49-1) & $ff

ti10:
.byte (0-1) & $ff
.byte (10-1) & $ff
.byte (20-1) & $ff
.byte (30-1) & $ff
.byte (40-1) & $ff
.byte (50-1) & $ff
.byte (60-1) & $ff
.byte (70-1) & $ff

;; ]
;; PRINT"High from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; PAGE=&5800RETURN
