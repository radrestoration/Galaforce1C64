;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ALIENS1"
;; B%=P%
;; [OPT pass

init_new_aliens:
 LDA myst
 BPL init_new_al2
 RTS 

init_new_al2:

 LDA initact
 ORA almove
 ORA albullact
 BNE alien1
 LDY wavoff
 BNE inital1
 LDA (wavbase),Y
 STA aliens
 STY procst
; start alien=0 !!!
 SEC 
 SBC #1
 STA aliensm1
 INC wavoff
 INY 

inital1:
 INC wavoff
 LDA (wavbase),Y
 BPL alien2
 JSR flagson
 INC curwave
 LDA #0
 STA sixteen_flag
 JSR flagson
 BIT demo_flag
 BMI init_snd
 LDY #7
 LDA curwave
 BEQ nt_zone16
 AND #$F
 BNE nt_zone16
 LDY #35
nt_zone16:
 JSR StartTune
init_snd:
 JSR message_loop
 LDA curwave
 AND #15
 TAY 
; wrap around !!!
 LDX #0
 STX wavoff
 LDA vecwavl,Y
 STA wavbase
 LDA vecwavh,Y
 STA wavbase+1
alien1:
 RTS 

alien2:
 CMP #45
 BNE special
 LDX #33
 STX aliens
 DEX 
 STX aliensm1
special:
 TAY 
 LDA vecpatl,Y
 STA temp1
 LDA vecpath,Y
 STA temp1+1
 LDY #0
 LDA (temp1),Y
 STA temp2
 INY 
alien4:
 LDX #0
alien5:
 LDA initst,X
 BPL alien6
 INX 
 CPX #maxpatt
 BNE alien5
 BEQ process_aliens
alien6:
 LDA (temp1),Y
 BPL normal_process
 AND #$7F
 BPL alien2
normal_process:
 INY 
 STA initx,X
 LDA (temp1),Y
 INY 
 STA inity,X
 LDA (temp1),Y
 INY 
 STA initdel,X
 STA initcount,X
 LDA (temp1),Y
 INY 
 STA initnum,X
 LDA (temp1),Y
 INY 
 STA initrelx,X
 LDA (temp1),Y
 INY 
 STA initrely,X
 LDA (temp1),Y
 INY 
 STA initgra,X
 LDA (temp1),Y
 INY 
 STA initpnum,X
 LDA #$80
 STA initst,X
 INC initact
 DEC temp2
 BNE alien4
 RTS 

;; ]
;; PRINT"Aliens 1 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
