;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"ABSWORK"
;; P%=&400
;; P%=&400BGI%=P%
;; P%=&400BGI%=P%O%=&3000
;; [OPT 6

;; Map normal ASCII
;.charmap ' ','Z', 32


.org  $400
.segment "DATA"


alst:
  .res maxaliens
algra:
  .res maxaliens
alpatlow:
  .res maxaliens
alpathigh:
  .res maxaliens
alpatoff:
  .res maxaliens
alcount:
  .res maxaliens
almult:
  .res maxaliens
aldirect:
  .res maxaliens
alx:
  .res maxaliens
aly:
  .res maxaliens
al_loop_count:
  .res maxaliens
al_loop_start:
  .res maxaliens
alpatreflect:
  .res maxaliens

mybullx:
  .res mymaxbull
mybully:
  .res mymaxbull
mybullst:
  .res mymaxbull

albullx:
  .res almaxbull
albully:
    .res almaxbull
albullst:
    .res almaxbull
albullspeed:
.res almaxbull

lives:
  .byte  0
myx:
  .byte  0
myy:
  .byte  0
myst:
  .byte  0
score_base:
myscore:
    .res 7
hiscore:
    .res 7

wavoff:
  .byte  0
almove:
  .byte  0
curwave:
  .byte  0
procst:
  .byte  0
mybullact:
  .byte  0
albullact:
  .byte  0
initact:
  .byte  0
bombdel:
  .byte  0
dem_section:
  .byte  0

sound_flag:
  .byte  0
key_joy_flag:
  .byte  0
demo_flag:
  .byte  0
demo_count:
  .byte  0
demo_direction:
  .byte  0
counter_sound:
  .byte  0
extra_life_flag:
  .byte  0
sixteen_flag:
  .byte  0
pause_flag:
  .byte  0

hstxt:
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
.byte "1234567890"
hsnum:
.byte "1234567"
.byte "1234567"
.byte "1234567"
.byte "1234567"
.byte "1234567"
.byte "1234567"
.byte "1234567"
.byte "1234567"



;; PRINT "hstxt ", ~hstxt
;; PRINT "hsnum ", ~hsnum

;; ]
;; PRINT"General workspace from &";~BGI%;" to &";~P%-1
;; PAGE=&5800
;; RETURN

;; DEFFNres(gap%)
;; P%=P%+gap%
;; P%=P%+gap%O%=O%+gap%
;; =6
