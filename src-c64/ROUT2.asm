;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ROUT2"

;; B%=P%
;; [OPT pass

collision:
 LDA myst
 BPL collis2
 RTS 

collis2:
 LDX aliensm1
coll1:
 STX temp4
 LDA alst,X
 BMI coll2
coll3:
 LDX temp4
 DEX 
 BPL coll1
 JMP aliensbombs

; Check if an alien has hit me

coll2:
 LSR A
 BCS coll3
 LDA aly,X
 CMP myy
 BCC coll4
 SBC myy
 CMP #alheight
 BCS check_bomb
 BCC coll_xcoord
coll4:
 LDA myy
 ADC #1
 SEC 
 SBC aly,X
 CMP #myheight
 BCS check_bomb

coll_xcoord:
 LDA alx,X
 CMP myx
 BCC coll5
 SBC myx
 CMP #mywidth
 BCS check_bomb
 BCC crash
coll5:
 LDA myx
 SBC alx,X
 CMP #alwidth
 BCS check_bomb

crash:
 SEC 
 ROR myst
 LDY #maxaliens-1
iym_dead1:
 LDA alst,Y
 ORA #1
 STA alst,Y
 DEY 
 BPL iym_dead1
 INC aliens
 INC aliensm1
 LDY aliensm1
 LDA #$81
 STA alst,Y
 LDA myy
 STA aly,Y
 LDA myx
 STA alx,Y
 LDA #36
 STA algra,Y
 JMP expsnd

; Now check if an alien has hit one of my bullets

check_bomb:
 LDA alst,X
 LSR A
 BCS coll3
 LDY #mymaxbull-1
chkalbull:
 STY temp4+1
 LDX temp4
 LDA mybullst,Y
 BMI cab1
cab2:
 LDY temp4+1
 DEY 
 BPL chkalbull
 JMP coll3

cab1:
 LDA aly,X
 CMP mybully,Y
 BCC cab2
 SBC mybully,Y
 CMP #alheight
 BCS cab2
; +bullheight

cab4:
 LDA alx,X
 CMP mybullx,Y
 BCC cab5
 SBC mybullx,Y
 BNE cab2
 BEQ crash2
cab5:
 LDA mybullx,Y
 SEC 
 SBC alx,X
 CMP #alwidth
 BCS cab2

crash2:
 LDA #0
 STA mybullst,Y
 DEC alcount,X
 PHP 
 BNE not_dead
 LDA alst,X
 ORA #1
 STA alst,X
not_dead:
 LDY temp4+1
 LDX mybullx,Y
 LDA mybully,Y
 TAY 
 JSR move_bomb
 DEC mybullact
 PLP 
 BNE not_dead2
 LDX temp4
 JSR add_to_score
 JSR expsnd
not_dead2:
 JMP cab2

; Now check if the alien's bombs have hit my ship

aliensbombs:
 LDY #almaxbull-1
albom1:
 STY temp4+1
 LDA albullst,Y
 BMI albom3
albom2:
 LDY temp4+1
 DEY 
 BPL albom1

; These lines are the protection
; part of the code!!!

; LDA &FE66
; EOR #&DD BEQ keok
; JMP crash
; keok
 RTS 
; This is always required!!

albom3:
 LDA myy
 CMP albully,Y
 BCC albom2
 SBC albully,Y
 CMP #myheight
 BCS albom2
; +bullheight

 LDA myx
 CMP albullx,Y
 BCC albom4
 SBC albullx,Y
 BNE albom2
 BEQ crash3
albom4:
 LDA albullx,Y
 SEC 
 SBC myx
 CMP #mywidth
 BCS albom2

crash3:
 LDA #0
 STA albullst,Y
 LDX albullx,Y
 LDA albully,Y
 TAY 
 JSR disp_bomb
 DEC albullact
 JMP crash

alien_hits:
.byte 1
.byte 1
.byte 1
.byte 1
.byte 1
.byte 10
.byte 2
.byte 5
.byte 5
.byte 2
.byte 2
.byte 2


expsnd:
 LDX #(exps1 .mod 256)
 LDY #(exps1 / 256)
 JSR mksound
 LDX #(exps2 .mod 256)
 LDY #(exps2 / 256)
 JMP mksound

; SOUND data for explosion!

exps1:
.word  $10
.word (-15) & $ffff
.word  7
.word  4

exps2:
.word  $11
.word  1
.word  150
; 200
.word  4

;; ]
;; PRINT"Routine 2 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
