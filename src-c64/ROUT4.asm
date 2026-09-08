;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ROUT4"
;; B%=P%
;; [OPT pass

message_loop:
 LDY #$FF
 LDA #0
 STA temp4
 SEC 
 LDX curwave
 INX 
 TXA 
sub10:
 INY 
 CMP #10
 BCC save_wave_text
 SBC #10
 BCS sub10
save_wave_text:
 STY wave_text
 STA wave_text+1
 LDY #6
 JSR prnstr
 CLC 
 JSR completion_message

wait_loop:
 JSR escape
 LDA myst
 BMI esc_exit
 JSR move_my_base
 JSR movestars
 JSR rand
 JSR process_my_bombs
 JSR pause
 LDX #20
 JSR delay2
 DEC temp4
 BNE wait_loop
esc_exit:
 SEC 
 JSR completion_message
 LDY #6
 JMP prnstr

end_message:
;LDY#12 JSRprnstr
 JSR title
 LDY #14
 JSR prnstr
 LDY #10
 JSR prnstr
 LDY #30
 JSR prnstr
 LDY #20
 JMP prnstr

escape:
 LDA demo_flag
 BPL not_demomode
 JSR chk_spc_fire
 BEQ test_if_already_dead
 RTS 
not_demomode:
 LDX #$8F
 JSR check_key
 BNE no_escape
test_if_already_dead:
 LDA myst
 BMI no_escape
 JSR liveson
 LDA #0
 STA lives
 JMP crash
no_escape:
 RTS 

game_over_loop:
 BIT demo_flag
 BMI no_escape
 LDY #14
 JSR StartTune
 LDY #8
 JSR prnstr
;LDA#90 STAcounter
game_over2:
 JSR movestars
 JSR pause
 LDX #25
 JSR delay2
 JSR MusicTest
 BNE game_over2
;DECcounter BNEgame_over2
 LDY #8
 JMP prnstr

chk_spc_fire:
 LDX #$9D
 JSR check_key
 BEQ spc_pressed
 LDX #0
 LDA #$80
 JSR osbyte ; read ADC
 CLC 
 TXA 
 AND #1
 EOR #1
spc_pressed:
 RTS 


completion_message:
 PHP 
 LDA curwave
 TAX 
 AND #$F
 BNE exit_compl
 TXA 
 LSR A
 LSR A
 LSR A
 BEQ exit_compl
 BIT sixteen_flag
 BMI exit_compl
 CLC 
 ADC #20
 TAY 
 CPY #28
 BCS exit_compl
 PLP 
 BCC not_second_call
 LDA #$FF
 STA sixteen_flag
not_second_call:
 JMP prnstr
exit_compl:
 PLP 
 RTS 

;; ]
;; PRINT"Routine 4 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
