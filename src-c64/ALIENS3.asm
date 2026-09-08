;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ALIENS3"
;; B%=P%
;; [OPT pass

move_the_aliens:
 LDA #process
 STA temp4
 LDX procst
move_aliens:
 LDA alst,X
 BMI move2
 JSR delay
move5:
 INC procst
 LDX procst
 CPX aliens
 BNE move3
 JSR process_aliens
 JSR pause
 LDX #0
 STX procst
 INC expldelay
move3:
 DEC temp4
 BNE move_aliens
 RTS 

move2:
 LSR A
 BCC move7
 JSR explosion
 JMP move5
move7:
 LDA almult,X
 BNE move4
 LDA alpatlow,X
 STA temp2
 LDA alpathigh,X
 STA temp2+1
 LDY alpatoff,X
 INC alpatoff,X
 LDA (temp2),Y
 BMI branch_wont_reach
 JMP move6
branch_wont_reach:
 AND #$7F
 STA almult,X
 INY 
 INC alpatoff,X
 LDA (temp2),Y
 LDY alpatreflect,X
 BPL not_reverse
 CMP #48
 BCS flip_acute_angle
 TAY 
 AND #$F8
 STA temp1
 TYA 
 AND #7
 TAY 
 LDA flip_table,Y
 ORA temp1
flip_acute_angle:
 EOR #7
not_reverse:
 STA aldirect,X

move4:
 LDA alx,X
 LDY aly,X
 TAX 
 JSR xycalc
 STA screen+1
 STX screen
 LDX procst
 DEC almult,X
 LDY aldirect,X
 CPY #$40
 BCC moving_alien
 JSR delay
 JMP move5

moving_alien:
 CLC 
 LDA alx,X
 ADC addrelx,Y
check_x_wrap:
 CMP #80
 BCC x_not_wrapped
 SBC #80
 JMP check_x_wrap
x_not_wrapped:
 STA alx,X
 CLC 
 LDA aly,X
 ADC addrely,Y
 STA aly,X
 TAY 
 LDA alx,X
dalg:
 TAX 
 JSR xycalc
 STA screen2+1
 STX screen2
 LDA #alheight
 STA temp1+1
 LDX procst
 LDY algra,X
 LDX graph,Y
 LDA graph+1,Y
 STA temp1
 TAY 
 TXA 
 JSR sprite
 JMP move5

move6:
 INY 
 STY temp3+1
 TAY 
 LDA actiontab,Y
 STA temp1
 LDA actiontab+1,Y
 STA temp1+1
 LDY temp3+1
 JMP (temp1)

explosion:
 LDA expldelay
 AND #1
 BNE expl4
 LDA alx,X
 LDY aly,X
 TAX 
 JSR xycalc
 STA screen+1
 STX screen
 STA screen2+1
 STX screen2
 LDA #alheight
 STA temp1+1
 LDX procst
 LDY algra,X
 LDA graph+1,Y
 STA temp1
 LDA graph,Y
 STA temp3
 CPY #12
 BCC expl2
 LDA #0
 STA algra,X
 TAY 
 BEQ expl3
expl2:
 INY 
 INY 
 TYA 
 STA algra,X
 CPY #12
 BCC expl3
 LDA #$C0
 STA screen2+1
 LDA #0
 STA alst,X
 DEC almove
expl3:
 LDX graph,Y
 LDA graph+1,Y
 TAY 
 LDA temp3
 JMP sprite
expl4:
 RTS 


; Flip table for reverse patterns
; Values EORed because of EOR#7
; which is used after to flip
; the acute angled 'climbs'.

flip_table:
.byte  (0 .bitxor 7)
.byte  (3 .bitxor 7)
.byte  (2 .bitxor 7)
.byte  (1 .bitxor 7)
.byte  (7 .bitxor 7)
.byte  (6 .bitxor 7)
.byte  (5 .bitxor 7)
.byte  (4 .bitxor 7)

;; ]
;; PRINT"Aliens 3 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
