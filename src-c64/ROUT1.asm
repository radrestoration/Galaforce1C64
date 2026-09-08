;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ROUT1"
;; B%=P%
;; [OPT pass

check_joy:
 LDA #$80
 JSR osbyte ; buffer status
 CPY #$C0
; was &FF then &E0
 RTS 

check_joy2:
 LDA #$80
 JSR osbyte ; buffer status
 CPY #$40
; was 1 then &20
 ROR A
 EOR #$80
 ROL A
 RTS 

pause4:
 LDX #200

check_key:
 LDA #$81
 LDY #$FF
 JSR osbyte ; key within time
 CPY #$FF
 RTS 

delay:
 LDX #3
delay2:
 LDY #0
delay3:
 DEY 
 BNE delay3
 DEX 
 BNE delay2
nopause:
 RTS 

pause:
 JSR sound_on_off
 JSR pause4
 BNE nopause
 CLC 
 ROR pause_flag
 LDA #15
 LDX #0
 JSR osbyte  ; flush keyboard
pause1:
 JSR pause4
 BEQ pause1
 LDY #0
 JSR prnstr
pause2:
 JSR pause4
 BNE pause2
pause3:
 JSR pause4
 BEQ pause3
 SEC 
 ROR pause_flag
 LDY #0
 JMP prnstr

rstall:
;LDY#process STYaliens TEST!!
;DEY STYaliensm1 TEST!!
 LDA #0
 STA myst
 STA almove
;STAwavoff TEST !!!!
 STA procst
 STA mybullact
 STA albullact
 STA bombdel
 STA initact
 LDY #maxaliens-1
rst1:
 STA alst,Y
 DEY 
 BPL rst1
 LDX #maxpatt-1
rst2:
 STA initst,X
 DEX 
 BPL rst2
 LDY #mymaxbull-1
rst3:
 STA mybullst,Y
 DEY 
 BPL rst3
 LDY #almaxbull-1
rst4:
 STA albullst,Y
 DEY 
 BPL rst4
 LDA #38
 STA myx
 LDA #227
 STA myy
seed_rnd:
 LDA $FE44
 ORA #1
 STA rand1
 LDA $240
 ORA #1
 STA rand1+1
 LDA $FC
 ORA #1
 STA rand1+2
 RTS 

xycalc:
 TXA 
xycalc4:
 CMP #80
 BCC xycalc3
 SBC #80
 JMP xycalc4
xycalc3:
 TAX 
 CPY #23
 BCS xycalc2
 LDA #$C0
 RTS 
xycalc2:
 LDA #0
 STA temp1+1
 TYA 
 AND #7
 STA temp1
 TYA 
 LSR A
 LSR A
 LSR A
 TAY 
 TXA 
 ASL A
 ROL temp1+1
 ASL A
 ROL temp1+1
 ASL A
 ROL temp1+1
 ORA temp1
 ADC line_start,Y
 TAX 
 LDA temp1+1
 ADC line_starth,Y
 RTS 

pokmypos:
 LDX myx
 LDY myy
 JSR xycalc
 STX screen
 STA screen+1
 LDY #myheight
 STY temp1+1
sound_exit:
 RTS 

sound_on_off:
 INC counter_sound
 LDA counter_sound
 AND #$F
 BNE sound_exit
 JSR key_joy
 LDX #$AE
; S key
 JSR check_key
 BNE sound_exit
 JSR display_sound_status
 LDA sound_letter
 EOR #((28 .bitxor 26))
 STA sound_letter
 LDA sound_flag
 EOR #$80
 STA sound_flag
 LDA #15
 LDX #0
 JSR osbyte  ; flush keyboard
display_sound_status:
 LDY #16
; display 'S' or 'Q'
 JMP prnstr

key_joy:
 LDX #$B9
; K key
 JSR check_key
 BNE sound_exit
 JSR display_key_joy_status
 LDA key_joy_letter
 EOR #((19 .bitxor 20))
 STA key_joy_letter
 LDA key_joy_flag
 EOR #$80
key_joy2:
 STA key_joy_flag
display_key_joy_status:
 LDY #18
; display 'K' or 'J'
 JMP prnstr

addrelx:
.byte 0
.byte xstep
.byte 0
.byte (-xstep) & $ff
.byte xstep
.byte xstep
.byte (-xstep) & $ff
.byte (-xstep) & $ff
.byte 0
.byte 2*xstep
.byte 0
.byte (-2*xstep) & $ff
.byte 2*xstep
.byte 2*xstep
.byte (-2*xstep) & $ff
.byte (-2*xstep) & $ff
.byte 0
.byte 3*xstep
.byte 0
.byte (-3*xstep) & $ff
.byte 3*xstep
.byte 3*xstep
.byte (-3*xstep) & $ff
.byte (-3*xstep) & $ff
.byte 0
.byte 4*xstep
.byte 0
.byte (-4*xstep) & $ff
.byte 4*xstep
.byte 4*xstep
.byte (-4*xstep) & $ff
.byte (-4*xstep) & $ff
.byte 0
.byte 5*xstep
.byte 0
.byte (-5*xstep) & $ff
.byte 5*xstep
.byte 5*xstep
.byte (-5*xstep) & $ff
.byte (-5*xstep) & $ff
.byte 0
.byte 6*xstep
.byte 0
.byte (-6*xstep) & $ff
.byte 6*xstep
.byte 6*xstep
.byte (-6*xstep) & $ff
.byte (-6*xstep) & $ff
.byte 2
.byte 2
.byte (-2) & $ff
.byte (-2) & $ff
.byte 2
.byte 2
.byte (-2) & $ff
.byte (-2) & $ff
addrely:
.byte (-ystep) & $ff
.byte 0
.byte ystep
.byte 0
.byte (-ystep) & $ff
.byte ystep
.byte ystep
.byte (-ystep) & $ff
.byte (-2*ystep) & $ff
.byte 0
.byte 2*ystep
.byte 0
.byte (-2*ystep) & $ff
.byte 2*ystep
.byte 2*ystep
.byte (-2*ystep) & $ff
.byte (-3*ystep) & $ff
.byte 0
.byte 3*ystep
.byte 0
.byte (-3*ystep) & $ff
.byte 3*ystep
.byte 3*ystep
.byte (-3*ystep) & $ff
.byte (-4*ystep) & $ff
.byte 0
.byte 4*ystep
.byte 0
.byte (-4*ystep) & $ff
.byte 4*ystep
.byte 4*ystep
.byte (-4*ystep) & $ff
.byte (-5*ystep) & $ff
.byte 0
.byte 5*ystep
.byte 0
.byte (-5*ystep) & $ff
.byte 5*ystep
.byte 5*ystep
.byte (-5*ystep) & $ff
.byte (-6*ystep) & $ff
.byte 0
.byte 6*ystep
.byte 0
.byte (-6*ystep) & $ff
.byte 6*ystep
.byte 6*ystep
.byte (-6*ystep) & $ff
.byte (-16) & $ff
.byte 4
.byte 16
.byte (-4) & $ff
.byte (-4) & $ff
.byte 16
.byte 4
.byte (-16) & $ff


line_start:
.byte $00, $28, $50, $78, $A0, $C8, $F0, $18, $40, $68, $90, $B8, $E0
.byte $08, $30, $58, $80, $A8, $D0, $F8, $20, $45, $6C, $94, $BC

line_starth:
.byte $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05
.byte $06, $06, $06, $06, $06, $06, $06, $07, $07, $07, $07, $07

;; ]
;; PRINT"Routine 1 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
