;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"FLAGS"
;; B%=P%
;; [OPT pass

liveson:
 LDX  lives
 BEQ  noliveson
 LDA  #$7D
 STA  addres+1
 LDA  #$63
 STA  addres
liveon0:
 LDY  #28
liveon1:
 LDA  shipgra,Y
 EOR (addres),Y
 STA (addres),Y
 DEY 
 BPL  liveon1
 LDA addres
 SEC 
 SBC #32
 STA addres
 DEX 
 BNE  liveon0
noliveson:
 RTS 

flagson:
 LDY curwave
 INY 
 STY temp
 LDA #$7B
 STA addres+1
 LDA #0
 STA addres
 LDA #$7D
 STA addres1+1
 LDA #$80
 STA addres1

flag0:
 LDA temp
 BEQ nomoflags
 CMP #10
 BCC flag1
 SEC 
 SBC #10
 STA temp
 LDX #0
flago0:
 LDY #31
flago1:
 LDA flaggra,X
 EOR (addres),Y
 STA (addres),Y
 INX 
 DEY 
 CPY #8
 BNE  flago1
 LDA #51
 EOR (addres1),Y
 STA (addres1),Y
 DEY 
poleon:
 LDA #1
 EOR (addres),Y
 STA (addres),Y
 LDA #1
 EOR (addres1),Y
 STA (addres1),Y
 DEY 
 BPL  poleon
 LDY #9
 LDA flaggra,X
 INX 
 EOR (addres1),Y
 STA (addres1),Y
 LDY #16
 LDA flaggra,X
 INX 
 EOR (addres1),Y
 STA (addres1),Y
 INY 
 LDA flaggra,X
 INX 
 EOR (addres1),Y
 STA (addres1),Y
 LDY #24
 LDA flaggra,X
 EOR (addres1),Y
 STA (addres1),Y
 LDA addres
 CLC 
 ADC #32
 STA addres
 LDA addres+1
 ADC #0
 STA addres+1
 LDA addres1
 CLC 
 ADC #32
 STA addres1
 LDA addres1+1
 ADC #0
 STA addres1+1
 BNE flag0
nomoflags:
 RTS 

flag1:
 CMP #5
 BCC flag2
 SEC 
 SBC #5
 STA temp
 LDX #27
 BNE flago0
flag2:
 SEC 
 SBC #1
 STA temp
 LDX #54
 BNE flago0

flaggra:
.byte 49
.byte 49
.byte 49
.byte 49
.byte 49
.byte 34
.word 0
.byte 48
.byte 49
.byte 49
.byte 49
.byte 48
.byte 51
.byte 34
.byte 0
.byte 49
.byte 49
.byte 49
.byte 49
.byte 49
.byte 51
.byte 51
.byte 51
.byte 51
.byte 34
.byte 34

.byte 0
.byte 34
.byte 34
.byte 34
.dword 0
.byte 49
.byte 49
.byte 49
.byte 51
.byte 49
.byte 34
.word 0
.byte 50
.byte 51
.byte 50
.byte 50
.byte 50
.byte 51
.byte 51
.byte 51
.byte 34
.word 0

.word 0
.byte 34
.dword 0
.byte 0
.byte 34
.byte 51
.byte 51
.byte 51
.byte 34
.word 0
.byte 0
.byte 50
.byte 50
.byte 50
.byte 50
.byte 50
.byte 51
.byte 34
.byte 34
.word 0
.byte 0

shipgra:
.byte 2
.byte 63
.byte 63
.byte 46
.byte 8
.byte 17
.byte 21
.byte 30
.byte 56
.byte 60
.byte 60
.byte 15
.byte 10
.word 0
.byte 10
.byte 40
.byte 61
.byte 61
.byte 14
.byte 10
.word 0
.byte 0
.byte 2
.byte 42
.byte 42
.byte 42
.byte 8

;; ]
;; PRINT"Flags etc. from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
