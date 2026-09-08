;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ALIENS4"
;; B%=P%
;; [OPT pass

actiontab:
.word  dat_loop
.word  dat_newpat
.word  dat_newalien
.word  dat_die
.word  dat_dropbomb
.word  dat_for_loop
.word  dat_next
.word  mve

dat_loop:
 INC alpatoff,X
 LDA (temp2),Y
 STA alpatoff,X
 JMP move7

dat_newpat:
 INC alpatoff,X
 LDA (temp2),Y
 TAY 
 LDA vecpatdl,Y
 STA alpatlow,X
 LDA vecpatdh,Y
 STA alpathigh,X
 LDA #0
 STA alpatoff,X
 JMP move7

dat_newalien:
 INC alpatoff,X
 LDA (temp2),Y
 STA temp1
 LDY aliensm1
dat_newal2:
 LDA alst,Y
 BPL dat_newal3
 DEY 
 BPL dat_newal2
 BMI dat_newal4

dat_newal3:
 LDA #$80
 STA alst,Y
 ASL A
 STA almult,Y
 STA alpatoff,Y
 JSR rand
 AND #2
 STA temp1+1
 CLC 
 ADC #12
 STA algra,Y
 STA temp3
 LDA alpatreflect,X
 STA alpatreflect,Y
 LDA alx,X
 PHA 
 STA alx,Y
 LDA aly,X
 ADC #8
 STA aly,Y
 PHA 
 LDX temp1
 LDA vecpatdl,X
 STA alpatlow,Y
 LDA vecpatdh,X
 STA alpathigh,Y
 LDA temp1+1
 LSR A
 TAX 
 LDA alien_hits,X
 STA alcount,Y
 PLA 
 TAY 
 PLA 
 TAX 
 INC almove
 JSR alien_on_off
 LDX procst
dat_newal4:
 JMP move5

dat_die:
 LDA alst,X
 ORA #1
 STA alst,X
 JMP move5

dat_dropbomb:
 JSR rand
 AND #3
 BNE not_allowed
 JSR init_bomb
 LDX procst
not_allowed:
 JMP move7

dat_for_loop:
 INC alpatoff,X
 LDA (temp2),Y
 STA al_loop_count,X
 INY 
 TYA 
 STA al_loop_start,X
 JMP move7

dat_next:
 DEC al_loop_count,X
 BMI end_of_loop
 LDA al_loop_start,X
 STA alpatoff,X
end_of_loop:
 JMP move7

mve:
 LDA alx,X
 LDY aly,X
 TAX 
 JSR xycalc
 STA screen+1
 STX screen
 LDX procst
 LDA #72
 STA aly,X
 TAY 
 LDA #0
 STA alx,X
 JMP dalg

;; ]
;; PRINT"Aliens 4 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
