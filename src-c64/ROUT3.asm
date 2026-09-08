;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ROUT3"
;; B%=P%
;; [OPT pass

move_my_base:
 LDA myst
 BPL ok_to_move
 RTS 

ok_to_move:
 JSR process_demo
 LDY #0
 STY temp3+1
 STY temp3
 BIT demo_flag
 BPL manual_control
 INY 
 BIT demo_direction
 BPL dem_right
 INY 
dem_right:
 STY temp3
 JMP possible_move

manual_control:

; Protection code follows

; LDA &FE67 CLC ADC #&A2
; BEQ keo2
; JMP ship_hasnt_moved
; keo2

 BIT key_joy_flag
 BMI use_keyboard

 LDX #1
 JSR check_joy
 ROL temp3
 LDX #1
 JSR check_joy2
 ROL temp3
 LDX #2
 JSR check_joy
 ROL temp3+1
 LDX #2
 JSR check_joy2
 ROL temp3+1
 JMP possible_move

use_keyboard:
 LDX #$9E
 JSR check_key
; Z key
 ROL temp3
 LDX #$BD
 JSR check_key
; X key
 ROL temp3
 LDX #$B7
 JSR check_key
; colon key
 ROL temp3+1
 LDX #$97
 JSR check_key
; / key
 ROL temp3+1

possible_move:
 JSR pokmypos
 LDY temp3
 LDA key_press_relx,Y
 CLC 
 ADC myx
 CMP #75
 BCS bad_x_position
 STA myx
bad_x_position:
 LDY temp3+1
 LDA key_press_rely,Y
 CLC 
 ADC myy
 CMP #165
 BCC bad_y_pos
 CMP #235
 BCS bad_y_pos
good_y_pos:
 STA myy
bad_y_pos:
 LDY myy
 LDX myx
 JSR xycalc
 STA screen2+1
 STX screen2
 EOR screen+1
 BNE ship_has_moved
 TXA 
 EOR screen
 BEQ ship_hasnt_moved
ship_has_moved:
 LDA #myheight
 STA temp1+1
 LDA graph+36
 TAX 
 LDY graph+37
 STY temp1
 JMP sprite

ship_hasnt_moved:
 LDA demo_direction
 EOR #$80
 STA demo_direction
 JMP delay

key_press_rely:
.byte 0
.byte 3
.byte (-3) & $ff
.byte 0
key_press_relx:
.byte 0
.byte 1
.byte $FF
.byte 0

;------------------------------


print_scores:
 STX temp1
pscore3:
 LDY score_base,X
 LDX mult24tab,Y
 STX pscore1+1
 LDY #23
pscore1:
 LDA $A00,Y ; Digit graphics
 STA (screen),Y
 DEY 
 BPL pscore1
 LDX temp1
 RTS 

init_score:
 JSR reset_score_to_0
poke_hi_scr:
 LDA #$98
 STA screen
 LDX #7
 STX temp2
inscr1:
 LDA score_base,X
 BNE inscr2
 LDY temp2
 BNE inscr3
inscr2:
 LDA #0
 STA temp2
 JSR print_scores
inscr3:
 LDA screen
 CLC 
 ADC #24
 STA screen
 BCC inscr4
 INC screen+1
inscr4:
 INX 
 CPX #14
 BNE inscr1
 RTS 

add_to_score:
 LDA #$20
 STA screen
 LDA #$31
 STA screen+1
 LDA algra,X
 SEC 
 SBC #12
 LSR A
 TAX 
 LDA alien_score,X
 LDX #5
addscr2:
 STA temp1
 LDA screen
 SEC 
 SBC #24
 STA screen
 BCS addscr4
 DEC screen+1
addscr4:
 LDA temp1
 CLC 
 ADC myscore,X
 CMP #10
 BCC addscr3
 SBC #10
 STA myscore,X
 JSR print_scores
 LDA #1
 DEX 
 BPL addscr2
 JMP reset_score_to_0
addscr3:
 STA myscore,X
 CPX #2
 BNE not_ten_thousands
 BIT extra_life_flag
 BMI not_ten_thousands
 CMP #2
 BNE not_ten_thousands
; extra life at >=20000
 SEC 
 ROR extra_life_flag
 TXA 
 PHA 
 JSR liveson
 INC lives
 JSR liveson
 LDX #(xlife .mod 256)
 LDY #(xlife / 256)
 JSR mksound
 PLA 
 TAX 
not_ten_thousands:
 JMP print_scores

xlife:
.word  $13
.word  3
.word  129
.word  30

mult24tab:
.byte  0*24
.byte  1*24
.byte  2*24
.byte  3*24
.byte  4*24
.byte  5*24
.byte  6*24
.byte  7*24
.byte  8*24
.byte  9*24

check_new_high:
 BIT demo_flag
 BMI not_new_high
 LDX #$FF
new_high1:
 INX 
 CPX #7
 BEQ not_new_high
new_high2:
 LDA myscore,X
 CMP hiscore,X
 BEQ new_high1
 BCC not_new_high
copy_to_high:
 LDA myscore,X
 STA hiscore,X
 INX 
 CPX #7
 BCC copy_to_high
not_new_high:
 RTS 

reset_score_to_0:
 LDY #6
 LDA #0
zero_my_score:
 STA myscore,Y
 DEY 
 BPL zero_my_score
 LDX #24*6+1
clr_score_screen:
 STA $308F,X
 DEX 
 BNE clr_score_screen
 LDA #$20
 STA screen
 LDA #$31
 STA screen+1
 LDX #6
 JMP print_scores

toggle_demo_direct:
 LDA demo_direction
 EOR #$80
 STA demo_direction
 RTS 

; Points awarded for aliens
; (divided by ten)

alien_score:
.byte 2
.byte 2
.byte 2
.byte 2
.byte 4
.byte 8
.byte 4
.byte 4
.byte 6
.byte 8
.byte 8
.byte 8

;; ]
;; PRINT"Routine 3 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
