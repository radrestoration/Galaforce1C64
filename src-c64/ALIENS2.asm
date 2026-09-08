;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ALIENS2"
;; B%=P%
;; [OPT pass

process_aliens:
 LDA myst
 BPL process_ok
 LDX #12
 JMP delay2

process_ok:
 LDX #maxpatt-1
proc1:
 LDA initst,X
 BPL proc2
 LDA initcount,X
 BEQ proc6
 DEC initcount,X
proc2:
 DEX 
 BPL proc1
 RTS 

proc6:
 LDA initdel,X
 STA initcount,X
 LDY aliensm1
proc3:
 LDA alst,Y
 BPL proc4
 DEY 
 BPL proc3
 BMI proc2
; MIGHT PUT ALIENS OUT OF SYNC.
proc4:
 LDA #0
 STA alpatoff,Y
 STA almult,Y
 LDA #$80
 STA alst,Y
 LDA initx,X
 STA alx,Y
 PHA 
 LDA inity,X
 STA aly,Y
 LDA initgra,X
 STA algra,Y
 STA temp3
 SEC 
 SBC #12
 LSR A
 STX temp2+1
 TAX 
 LDA alien_hits,X
 STA alcount,Y
 LDX temp2+1
 LDA initpnum,X
 STA alpatreflect,Y
 AND #$7F
 TAX 
 LDA vecpatdl,X
 STA alpatlow,Y
 LDA vecpatdh,X
 STA alpathigh,Y
 PLA 
 TAX 
 JSR rand
 AND #31
 CPX #78
 BEQ alter_start_x
 CPX #79
 BNE use_original_x
 ADC #40
alter_start_x:
 STA alx,Y
use_original_x:
 LDX temp2+1
 INC almove
 DEC initnum,X
 BNE proc5
 LDA #0
 STA initst,X
 DEC initact
proc5:
 CLC 
 LDA initx,X
 ADC initrelx,X
chk_xinit_wrap:
 CMP #80
 BCC no_initx_wrap
 SBC #80
 JMP chk_xinit_wrap
no_initx_wrap:
 STA initx,X
 CLC 
 LDA inity,X
 ADC initrely,X
 STA inity,X

 LDX alx,Y
 LDA aly,Y
 TAY 
 JSR alien_on_off
 LDX temp2+1
 JMP proc2

alien_on_off:
 JSR xycalc
 STA screen+1
 STX screen
 LDA #alheight
 STA temp1+1
 LDA #$C0
 STA screen2+1
 LDX temp3
 LDA graph,X
 LDY graph+1,X
 STY temp1
 JMP sprite

;; ]
;; PRINT"Aliens 2 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
