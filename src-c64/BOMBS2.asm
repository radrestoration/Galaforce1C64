;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"BOMBS2"
;; B%=P%
;; [OPT pass

process_aliens_bombs:

; Try to init a bomb (random)

 LDA albullact
 CMP #almaxbull
 BEQ nobomb
 LDA aliensm1
 CMP #20
 BCC prb2
 LDA algra+32
 CMP #22
 BNE prb2
 LDA rand1+1
 AND #$F
 BNE prb2
 LDA #32
 BNE prb
prb2:
 JSR rand
bombrate:
 AND #15
 BNE nobomb
 LDA rand1+1
 AND #63
 CMP aliens
 BCS nobomb
prb:
 TAX 
 LDA alst,X
 BPL nobomb
 LSR A
 BCS nobomb
 JSR init_bomb

; Process the alien bombs

nobomb:
 LDA albullact
 BEQ none_move
 LDX #almaxbull-1
malbomb:
 STX temp2
 LDA albullst,X
 BMI malbomb2
malbomb3:
 LDX temp2
 DEX 
 BPL malbomb
none_move:
 RTS 

malbomb2:
 LDA albullspeed,X
 BMI always_move
 LDA #1
 BIT counter
 BNE malbomb3
always_move:
 LDY albully,X
 LDA albullx,X
 TAX 
 STX temp2+1
 JSR disp_bomb
 LDX temp2
 LDA albully,X
 CLC 
 ADC #8
 STA albully,X
 BCC malbomb4
 LDA #0
 STA albullst,X
 DEC albullact
 JMP malbomb3

malbomb4:
 TAY 
 LDA aliensm1
 CMP #20
 BCS malbomb5
 LDA curwave
 CMP #13
 BCC malbomb5
; Homing bombs
 CMP #29
 BCS homi1
 LDA albullspeed,X
 BMI malbomb5
homi1:
 LDA rand1+1
 BMI malbomb5
 LDA myx
 CLC 
 ADC #2
 CMP albullx,X
 BEQ malbomb5
 BCS malbomb6
 DEC temp2+1
 DEC albullx,X
 JMP malbomb5
malbomb6:
 INC temp2+1
 INC albullx,X
malbomb5:
 LDX temp2+1
 JSR disp_bomb
 JMP malbomb3

; Subroutine to init a bomb
; if possible!

init_bomb:
 LDA curwave
 CMP #3
 BCC no_bomb_allowed
 LDY #almaxbull-1
dropb1:
 LDA albullst,Y
 BPL dropb2
 DEY 
 BPL dropb1
no_bomb_allowed:
 RTS 

dropb2:
 LDA aly,X
 CMP #24
 BCC no_bomb_allowed
 CMP #240
 BCS no_bomb_allowed
 ADC #8
 AND #$F8
 STA albully,Y
 STA temp2
 CMP #80
 BCC any_speed
 AND #$7F
 BCS slow_only
any_speed:
 JSR rand
slow_only:
 STA albullspeed,Y
 LDA #$FF
 STA albullst,Y
 INC albullact
 LDA alx,X
 CLC 
 ADC #2
 STA albullx,Y
 TAX 
 LDY temp2

; Subroutine to display/erase
; a bomb.

disp_bomb:
 JSR xycalc2
 STA screen+1
 STX screen
 LDY #9
disp_b2:
 LDA albomb,Y
 EOR (screen),Y
 STA (screen),Y
 DEY 
 BPL disp_b2
 RTS 

albomb:
.byte 8
.byte 12
.byte 20
.byte 20
.byte 20
.byte 20
.byte 20
.byte 20
.byte 8
.byte 8

;; ]
;; PRINT"Bombs 2 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
