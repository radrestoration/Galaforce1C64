;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"BOMBS1"
;; B%=P%
;; [OPT pass

process_my_bombs:
 LDA bombdel
 BEQ procmybmb
 DEC bombdel
procmybmb:
 LDA mybullact
 BEQ bomb10
 LDX #mymaxbull-1
bomb6:
 STX temp2
 LDA mybullst,X
 BMI bomb7
bomb9:
 LDX temp2
 DEX 
 BPL bomb6
 BMI bomb5

bomb7:
 LDY mybully,X
 LDA mybullx,X
 TAX 
 JSR move_bomb
 LDX temp2
 LDA mybully,X
 SEC 
 SBC #8
 STA mybully,X
 BNE bomb8
 DEC mybullact
 LDA #0
 STA mybullst,X
 BEQ bomb9
bomb8:
 TAY 
 LDA mybullx,X
 TAX 
 JSR move_bomb
 JMP bomb9

bomb5:
 LDA mybullact
bomb10:
 CMP #mymaxbull
 BEQ bomb1
 LDA myst
 BMI bomb1
 LDA demo_flag
 BMI bomb11
 BIT key_joy_flag
 BMI kbd_fire
 LDA #$80
 LDX #0
 JSR osbyte ; Read ADC channel
 TXA 
 LSR A
 BCC not_button
 BCS bomb11
kbd_fire:
 LDX #$B6
 JSR check_key
 BEQ bomb11
not_button:
 LDA #0
 STA bombdel
 BEQ bomb1
bomb11:
 LDA bombdel
 BNE bomb1
 LDX #mymaxbull-1
bomb2:
 LDA mybullst,X
 BPL bomb3
 DEX 
 BPL bomb2

bomb1:
 RTS 

bomb3:
 LDA #$FF
 STA mybullst,X
 LDA #7
 STA bombdel
; WAS 3!
 STX temp2
 INC mybullact
 LDA myx
 CLC 
 ADC #2
 STA mybullx,X
 STA temp1
 LDA myy
 SEC 
 SBC #23
 AND #$F8
 STA mybully,X
 TAY 
 LDX temp1
 JSR move_bomb
 LDX #(firesnd .mod 256)
 LDY #(firesnd / 256)
 JMP mksound

move_bomb:
 JSR xycalc2
 STA screen+1
 STX screen
 LDY #7
bomb4:
 LDA bombgra,Y
 EOR (screen),Y
 STA (screen),Y
 DEY 
 BPL bomb4
 LDA #34
 LDY #$E
 EOR (screen),Y
 STA (screen),Y
mks2:
 RTS 

bombgra:
.byte 21
.byte 21
.byte 21
.byte 21
.byte 21
.byte 21
.byte 51
.byte 1

firesnd:
.word  $12
.word  2
.word  115
.word  4

mksound:
 BIT sound_flag
 BPL mks2
 BIT demo_flag
 BMI mks2
 LDA #7

 JMP osword; sound https://tobylobster.github.io/mos/mos/S-s15.html#SP31

;; ]
;; PRINT"Bombs 1 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
