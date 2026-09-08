;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"SPRITES"
;; B%=P%
;; [OPT pass

; A = $C0 (screen2+1)
; X = graph+36
; temp1 = graph+37

sprite:
 STA gra1+1
 STA gra2+1
 STA gra3+1
 STA gra4+1
 STA gra5+1
 STA gra6+1
 STX gra21+1
 STX gra22+1
 STX gra23+1
 STX gra24+1
 STX gra25+1
 STX gra26+1
 LDA temp1
 STA gra1+2
 STA gra2+2
 STA gra3+2
 STA gra4+2
 STA gra5+2
 STA gra6+2
 STY gra21+2
 STY gra22+2
 STY gra23+2
 STY gra24+2
 STY gra25+2
 STY gra26+2
 LDX #0
display:
 LDY #0
gra1:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y  ; #0
gra21:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #1
 INX 
 LDY #8
gra2:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y ;  #2
gra22:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #3
 INX 
 LDY #$10
gra3:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y  ; #4
gra23:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #5
 INX 
 LDY #$18
gra4:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y  ; #6
gra24:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #7
 INX 
 LDY #$20
gra5:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y ; #8
gra25:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #9
 INX 
 LDY #$28
gra6:
 LDA $FFFF,X
 EOR (screen),Y
 STA (screen),Y ; #10
gra26:
 LDA $FFFF,X
 EOR (screen2),Y
 STA (screen2),Y ; #11
 INX 
 LDA screen
 AND #7
 BEQ nxt_char_row
 DEC screen
check_second:
 LDA screen2
 AND #7
 BEQ nxt_char_row2
 DEC screen2
 DEC temp1+1
 BNE display
 JMP the_end
 RTS 
nxt_char_row:
 SEC 
 LDA screen
 SBC #$79
 STA screen
 LDA screen+1
 SBC #2
 STA screen+1
 JMP check_second
nxt_char_row2:
 SEC 
 LDA screen2
 SBC #$79
 STA screen2
 LDA screen2+1
 SBC #2
 STA screen2+1
 DEC temp1+1
 BEQ the_end
 JMP display
the_end:
 RTS 

;; ]
;; PRINT"Sprites from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
