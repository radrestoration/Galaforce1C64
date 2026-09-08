;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"MUSIC1"
;; B%=P%

D1=0*64
D2=1*64
D3=2*64
D4=3*64
Rest=63

;; [ OPT pass

;===================================================================
StartTune:
 RTS
 SEI 
 STY  WK
 LDA  LT+0,Y
 STA  get+1
 LDA  LT+1,Y
 STA  get+2
 LDA  #0
 STA  IX+0
 LDA  LT+2,Y
 STA  IX+1
 LDA  LT+3,Y
 STA  IX+2
 LDX  LT+4,Y
 LDY  #3
SL1:
 LDA  SPT,X
 STA  SPD,Y
 DEX 
 DEY 
 BPL  SL1
 LDY  WK
 LDX  LT+5,Y
 LDY  #2
EL:
 LDA  ENVTAB,X
 STA  ENV,Y
 LDA  #1
 STA  CNT,Y
 DEX 
 DEY 
 BPL  EL
 LDY  WK
 LDX  LT+6,Y
 LDY  #2
DL:
 LDA  DURATAB,X
 STA  DUR,Y
 DEX 
 DEY 
 BPL  DL
 CLI 
 RTS 

Refresh:
 LDX  #2
 STX  WK
RL:
 LDX  WK
 DEC  CNT,X
 BNE  NOC
 LDY  IX,X
get:
 LDA  $DDDD,Y
 BEQ  NOC
 INC  IX,X
 PHA 
 AND  #Rest
 CMP  #Rest
 BEQ  ST
 PLA 
 PHA 
 ASL  A
 ASL  A
 STA  SND+4
 TXA 
 CLC 
 ADC  #$11
 STA  SND+0
 LDA  ENV,X
 STA  SND+2
 LDA  DUR,X
 STA  SND+6
 BIT  sound_flag
 BPL  ST
 LDX  #(SND .mod 256)
 LDY  #(SND / 256)
 LDA  #7
 JSR  $FFF1
ST:
 PLA 
 ROL  A
 ROL  A
 ROL  A
 AND  #3
 TAX 
 LDA  SPD,X
 LDX  WK
 STA  CNT,X
NOC:
 DEC  WK
 BPL  RL
 RTS 

MusicTest:
 LDA  get+1
 STA  dat+1
 LDA  get+2
 STA  dat+2
 LDX  #2
 LDA  #0
 PHP 
ML:
 LDY  IX,X
 PLP 
dat:
 ORA  $FFFF,Y
 PHP 
 DEX 
 BPL  ML
 PLP 
 RTS 

Stop:
 RTS ; Avoid music

 LDX  #(HAL .mod 256)
 LDY  #(HAL / 256)
 STX  get+1
 STY  get+2
 LDA  #0
 LDX  #3
SL2:
 STA  IX-1,X
 DEX 
 BNE  SL2
 LDA  #15
 JMP  $FFF4

;====================================================================

SND:
.dword  $00DD00DD
.dword  $00DD00DD
WK:
 .byte  0
CNT:
.byte  "012"
IX:
 .byte  "012"
SPD:
.byte  "0123"
SPT:
.byte  5
.byte  10
.byte  15
.byte  20;Lost a Life
.byte  100
.byte  96
.byte  93
.byte  1;In Between Levels
.byte  7
.byte  14
.byte  21
.byte  28;Game Over
.byte  8
.byte  16
.byte  24
.byte  32
.byte  9
.byte  18
.byte  27
.byte  36
.byte  4
.byte  8
.byte  12
.byte  16;Game Start
.byte  3
.byte  6
.byte  9
.byte  12;Demo Music Section "a"
ENV:
.byte  "012"
ENVTAB:
.byte  5
.byte  6
.byte  7;Lost a Life
.byte  6
.byte  6
.byte  6;Game Start
.byte  4
.byte  4
.byte  4;In Between Levels
.byte  8
.byte  8
.byte  8;Game Over
.byte  6
.byte  6
.byte  5;Demo Music Section "a"
DUR:
.byte  "012"
DURATAB:
.byte  10
.byte  1
.byte  1;Lost a Life
.byte  5
.byte  3
.byte  2;Game Start, Game Over
.byte  50
.byte  50
.byte  50;In Between Levels
.byte  1
.byte  3
.byte  10;Demo Music Section "a"
.byte  2
.byte  3
.byte  14;Demo Music Section "d"

;Data Look-up Table
;Contains all the gen pertaining to each individual tune.

;Order is as follows
;Order is as follows

;Address of channel 1 data. 2
;Offset from ch. 1 to ch. 2 data. 1
;Offset from ch. 1 to ch. 3 data. 1
;Index into speeds table 1
;Index into envelopes table 1
;Index into durations table 1

; Addr1 Index2 Index3 Speed Env Dur
;Game Over Music & also Lost a Life Music

LOST1:
.byte  51+D2
.byte  52+D2
.byte  51+D2
.byte  49+D2
.byte  51+D2
.byte  49+D2
.byte  47+D2
.byte  46+D2
.byte  44+D4
.byte  39+D4
.byte  32+D1
HAL:
.byte  0
OVER1:
.byte  Rest+D2
OVER2:
.byte  Rest+D2
OVER3:
LOST2:
.byte  51+D1
.byte  47+D1
.byte  44+D1
.byte  39+D1
.byte  47+D1
.byte  44+D1
.byte  39+D1
.byte  35+D1
.byte  44+D1
.byte  39+D1
.byte  35+D1
.byte  32+D1
.byte  39+D1
.byte  35+D1
.byte  32+D1
.byte  27+D1
.byte  35+D1
.byte  32+D1
.byte  27+D1
.byte  23+D1
.byte  27+D1
.byte  25+D1
.byte  23+D1
.byte  22+D1
.byte  20+D1
.byte  8+D1
.byte  8+D1
.byte  8+D1
.byte  8+D1
.byte  0
LOST3:
.byte  8+D4
.byte  20+D4
.byte  8+D2
.byte  8+D2
.byte  20+D4
.byte  8+D2
.byte  8+D2
.byte  20+D2
.byte  8+D2
.byte  8+D2
.byte  0

;Between Levels Music

BETW1:
.byte  00+D4
.byte  01+D4
.byte  02+D4
.byte  03+D4
.byte  04+D4
.byte  05+D4
.byte  06+D4
.byte  07+D4
.byte  08+D4
.byte  09+D4
.byte  10+D4
.byte  11+D4
.byte  12+D4
.byte  13+D4
.byte  14+D4
.byte  15+D4
.byte  16+D4
.byte  17+D4
.byte  18+D4
.byte  19+D4
.byte  20+D1
.byte  21+D4
.byte  0
BETW2:
.byte  00+D4
.byte  01+D4
.byte  02+D4
.byte  03+D4
.byte  04+D4
.byte  05+D4
.byte  06+D4
.byte  07+D4
.byte  08+D4
.byte  09+D4
.byte  10+D4
.byte  11+D4
.byte  12+D4
.byte  13+D4
.byte  14+D4
.byte  15+D4
.byte  16+D4
.byte  17+D4
.byte  18+D4
.byte  19+D4
.byte  20+D4
.byte  21+D4
.byte  22+D4
.byte  23+D4
.byte  24+D2
.byte  25+D4
.byte  0
BETW3:
.byte  00+D4
.byte  01+D4
.byte  02+D4
.byte  03+D4
.byte  04+D4
.byte  05+D4
.byte  06+D4
.byte  07+D4
.byte  08+D4
.byte  09+D4
.byte  10+D4
.byte  11+D4
.byte  12+D4
.byte  13+D4
.byte  14+D4
.byte  15+D4
.byte  16+D4
.byte  17+D4
.byte  18+D4
.byte  19+D4
.byte  20+D4
.byte  21+D4
.byte  22+D4
.byte  23+D4
.byte  24+D4
.byte  25+D4
.byte  26+D4
.byte  27+D3
.byte  28+D4
.byte  0

;; ]
;; PRINT"Music 1 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
