;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE"CHARP"
;; B%=P%
;; [OPT pass

;; The original BBC routine draws 5x7 glyph pixels directly into a bitmap.
;; The C64 routine below is different: it writes character codes to screen
;; RAM. It cannot reproduce arbitrary BBC pixels or the BBC star field.
;; Keep bitmap/star rendering separate from this text-mode path.
;;


.proc prnstr_c64_text
    lda strdat,y
    sta data
    lda strdat+1,y
    sta data+1

    ; 1. Resolve Destination Screen Row from BBC Address Vector
    ldy #1
    lda (data),y        ; Fetch high byte of BBC target memory address
    and #$0F            ; Mask out high page boundaries to isolate row position
    tay                 ; Y = Computed C64 screen row table index

    lda c64_lines_low,y
    sta screen
    lda c64_lines_high,y
    sta screen+1

    ; 2. Adjust for Column Placement Offset
    ldy #0
    lda (data),y        ; Fetch low byte of BBC target memory address
    lsr a               ; Compress 80 columns down to fit 40 columns
    clc
    adc screen
    sta screen
    bcc :+
    inc screen+1        ; Handle 16-bit page cross if column pushes boundary
:

    ; 3. Dynamically Parse Variable Header Lengths
    ldy #2              ; Index 2 holds the data length indicator
    lda (data),y
    sta temp4           ; temp4 will act as our downward character counter

    ; Skip the color byte at index 3 and begin printing at index 4
    ldy #4

print_character_loop:
    lda temp4           ; Check if our character print budget is empty
    beq text_printing_finished_label

    lda (data),y        ; Fetch original character index code

    ; 4. Convert Original Font Indices to C64 Character Mappings
    ; For example: If code is 'A' (10), shift it down to align with C64 layout
    cmp #10
    bcc write_to_matrix
    sec
    sbc #9              ; Shift index down so 'A' maps cleanly to character slot 1

write_to_matrix:
    sty savey           ; Protect our current string parsing index
    ldy #0
    sta (screen),y      ; Commit character index directly to C64 Screen RAM
    ldy savey           ; Restore string parsing index

    ; Step cursor forward 1 column position
    inc screen
    bne :+
    inc screen+1
:
    dec temp4           ; Subtract 1 character from our remaining counter budget
    iny                 ; Advance reading pointer to the next byte in the data string
    jmp print_character_loop

text_printing_finished_label:
    rts
.endproc

; C64 40-Column Address Lookup Matrix Pointers
c64_lines_low:
    .byte $00, $28, $50, $78, $A0, $C8, $F0, $18, $40, $68, $90, $B8, $E0
    .byte $08, $30, $58, $80, $A8, $D0, $F8, $20, $45, $6C, $94, $BC
c64_lines_high:
    .byte $04, $04, $04, $04, $04, $04, $04, $05, $05, $05, $05, $05, $05
    .byte $06, $06, $06, $06, $06, $06, $06, $07, $07, $07, $07, $07





prnstr:
  
; LDA  strdat,Y    ; Low address
; STA  data
; LDA  strdat+1,Y  ; High address
; STA  data+1
; LDY  #0
; LDA  (data),Y    ; BBC Screen address low
; STA  addres
; STA  VERA_addr_low

; INY 
; LDA  (data),Y    ; BBC Screen address high
; STA  addres+1
; STA  VERA_addr_high

; LDA  #$10
; STA  VERA_addr_bank

; INY 
; LDA  (data),Y    ; Length
; STA  length
; INY 
 ;LDA  (data),Y    ; Color
 LDA #0
 STA  colour
nxtchr:
 ;LDA  colour
 ;AND  #$AA
; STA  pixcolu+6    ; Modify ASL instruction?
 INY 

prnchr:
 LDA  (data),Y     ; Count down Y, get byte
 STY  savey        ; Store pixel value
 STA  temp         ; Store color
 ASL  A
 ASL  A
 ADC  temp         ; 5 bytes per character

 ;LDX  length       ; Decrement over characters

; TAX
; LDA  #5           ; 5 pixels wide
; STA  width

;pixrow:

;pixcolum:
; LDY  #2; #7           ; 7 rows
;pixrow:


 ; Draw all the characters (5 pixels plus 1), row by row, increasing VERA addresses, then
 ; Reset to start of next line - 7 rows.
 ; The bitmask is shifted per row, to compare with each font data byte vs pixel.


 LDY  #7           ; 7 rows
 LDA  #$80         ; Mask -> rotate down through bits
 STA  bitmask

 LDA  $700,X
 STA  temp         ; Address of character set (spacey)


pixcol:
 LDX length
pixrow:



;pixcolu:

 ;lda #0; colour

 ; pixel = 0
 ; bit = temp[0]
 ; if (bit & (1 << y)) pixel = color
 ; bit = temp[1]
 ; if (bit & (1 << y)) pixel = color | (color << 4)

 ; First 2 pixels
 ;ldx #$ee

 lda #0
 sta colour

 lda (temp),y
 and bitmask
 beq nopix0
 lda #$0e
 ora colour
 sta colour

nopix0:
 inc temp
 lda (temp),y
 and bitmask
 beq nopix1
 lda #$e0
 ora colour

nopix1:
; sta VERA_data0


 lda #0
 sta colour

 inc temp
 lda (temp),y
 and bitmask
 beq nopix2
 lda #$0e
 ora colour
 sta colour

nopix2:
 inc temp
 lda (temp),y
 and bitmask
 beq nopix3
 lda #$e0
 ora colour

nopix3:
; sta VERA_data0
 inc temp
 lda (temp),y
 and bitmask
 beq nopix4
 lda #$0e
 ;lda #$0e
; sta VERA_data0
nopix4:

 dec temp
 dec temp
 dec temp
 dec temp

 dex
 bne pixrow

 ror bitmask


 clc
 lda addres
 adc #160
 sta addres
; sta VERA_addr_low

 lda addres+1
 adc #0
 sta addres+1
; sta VERA_addr_high


 dey
 bne pixcol

 rts

; dec length
; bne nxtchr
 ;rts


;pixcolu:
 ;lda addres
; clc
; adc (addres),y
; sta VERA_addr_low

; adc (addres+1)
; sta VERA_addr_high

; LDA VERA_data0
; EOR  #0
; LDA #0
 ; colour bits
; ASL  temp
 ;BCC  pixcol0

; EOR  (addres),Y ; Get/Set Pixel
; STA  (addres),Y ; set Pixel
 ;EOR VERA_data0
 ;EOR
 ;STA VERA_data0

 ;EOR (VERA_data0),Y
 ;STA (VERA_data0),Y
;pixcol0:
; DEY
; BPL  pixcolu

 ;INX
 ;DEC  width
 ;BEQ  chrdun
 ;LDA  pixcolu+1
 ;EOR  colour
 ;STA  pixcolu+1
 ;AND  #$AA
 ;BEQ  pixcolum
 ;LDA  addres   ; Get Pixel address
 ;CLC
 ;ADC  #8
 ;STA  addres   ; Set Pixel address
 ;BCC  pixcolum
 ;INC  addres+1
 ;BNE  pixcolum

;chrdun:
 ;LDA  addres
 ;CLC
 ;ADC  #8
 ;STA  addres   ; Get Pixel address
 ;BCC  lab1
 ;INC  addres+1 ; set Pixel address
;lab1:
 ;LDY  savey
 ;DEC  length
 ;BNE  nxtchr
 ;RTS

strdat:
.word  testtxt
.word  paustxt
.word  SCRtext
.word  HItext
.word  entering_wave
.word  gameover
.word  pressspace
.word  galaforce
.word  myname
.word  letter_S_Q
.word  letter_K_J
.word  pressspace2
.word  finish1
.word  finish2
.word  finish3
.word  finish4
.word  copyr
.word  za
.word  zb
.word  zc

testtxt:
.word $2000
.byte 10
.byte 11
.byte 11
.byte 12
.byte 13
.byte 14
.byte 15
.byte 16
.byte 17
.byte 18
.byte 19
.byte 25

paustxt:
.word  $7FE8 ; address
.byte 1      ; count
.byte 60     ; 'p'
.byte 25     ; colour?

SCRtext:
.word  $3030
.byte  3
.byte  51
.byte 28
.byte 12
.byte 27
; 'SCR'

HItext:
.word  $3150
.byte  2
.byte  51
.byte 17
.byte 18
; 'HI'

entering_wave:
.word  $5108
.byte  16
.byte  63
.byte 14
.byte 23
.byte 29
.byte 14
; ENTE
.byte 27
.byte 18
.byte 23
.byte 16
; RING
.byte 38
.byte 35
.byte 24
.byte 23
; ZON
.byte 14
.byte 38
wave_text:
.byte 38
.byte 38
gameover:
.word  $4C58
.byte  9
.byte  60
.byte 16
.byte 10
.byte 22
.byte 14
; GAME
.byte 38
.byte 24
.byte 31
.byte 14
; OVE
.byte 27
; R

pressspace:
.word  $6760
.byte  19
.byte  12
.byte 25
.byte 27
.byte 14
.byte 28
; PRES
.byte 28
.byte 38
.byte 28
.byte 25
; S SP
.byte 10
.byte 12
.byte 14
.byte 38
; ACE
.byte 24
.byte 27
.byte 38
.byte 15
; OR F
.byte 18
.byte 27
.byte 14
; IRE

pressspace2:
.word  $6CF0
.byte  7
.byte  12
.byte 29
.byte 24
.byte 38
.byte 25
; TO P
.byte 21
.byte 10
.byte 34
; LAY

galaforce:
.word  $3FD8
.byte  9
.byte  $F
.byte 16
.byte 10
.byte 21
.byte 10
; GALA
.byte 15
.byte 24
.byte 27
.byte 12
.byte 14
; FORCE

myname:
.word  $4488
.byte  16
.byte  60
.byte 11
.byte 34
.byte 38
.byte 20
; BY K
.byte 14
.byte 31
.byte 18
.byte 23
; EVIN
.byte 38
.byte 14
.byte 13
.byte 32
; EDW
.byte 10
.byte 27
.byte 13
.byte 28
; ARDS

letter_S_Q:
.word  $7FD0
.byte  1
.byte  3
sound_letter:
.byte  28

letter_K_J:
.word  $7FB8
.byte  1
.byte  60
key_joy_letter:
.byte  20

finish1:
.word $5900
.byte  6
.byte  $C3
.byte 28
.byte 10
.byte 29
.byte 30
; SATU
.byte 27
.byte 23
; RN

finish2:
.word $58F0
.byte  7
.byte  $C3
.byte 11
.byte 10
.byte 29
.byte 29
; BATT
.byte 14
.byte 27
.byte 34
; ERY

finish3:
.word $5910
.byte  5
.byte  $C3
.byte 29
.byte 30
.byte 27
.byte 11
; TURB
.byte 24
; 0

finish4:

copyr:
.word $7678
.byte  17
.byte  51
.byte 28
.byte 30
.byte 25
.byte 14
;SUPE
.byte 27
.byte 18
.byte 24
.byte 27
;RIOR
.byte 38
.byte 28
.byte 24
.byte 15
; SOF
.byte 29
.byte 32
.byte 10
.byte 27
;TWAR
.byte 14
; E

za:
.word  $FFFF
.byte  1
.byte  3
zs:
.byte  $FF

zb:
.word  $FFFF
.byte  21
.byte  3
zt:
.byte  0
; 1 to 8
.byte  38
; space
.byte  "1234567"
; Score
.byte  38
.byte 38
; Spaces
.byte  "1234567890"
; Name

zc:
.word  $3D00
.byte  15
.byte  60
.byte 14
.byte 23
.byte 29
.byte 14
.byte 27
.byte 38
; ENTER
.byte 34
.byte 24
.byte 30
.byte 27
.byte 38
; YOUR
.byte 23
.byte 10
.byte 22
.byte 14
; NAME

;; ]
;; PRINT"Char print from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; PAGE=&5800RETURN

;; REM 012345
;; DATA &7F,&41,&41,&79,&7F
;; DATA &00,&78,&7F,&00,&00
;; DATA &79,&79,&49,&49,&4F
;; DATA &63,&49,&49,&7F,&78
;; DATA &1F,&11,&71,&7F,&10
;; DATA &6F,&49,&49,&79,&79
;; REM 6789
;; DATA &7F,&49,&49,&49,&7B
;; DATA &01,&01,&01,&79,&7F
;; DATA &78,&4F,&49,&7F,&78
;; DATA &0F,&09,&09,&79,&7F
;; REM ABCDEF
;; DATA &78,&7F,&09,&0F,&78
;; DATA &7F,&79,&49,&4F,&78
;; DATA &7F,&79,&41,&41,&63
;; DATA &7F,&79,&41,&41,&7F
;; DATA &7F,&79,&49,&49,&49
;; DATA &7F,&79,&09,&09,&09
;; REM GHIJKL
;; DATA &7F,&79,&41,&49,&7B
;; DATA &7F,&78,&08,&08,&7F
;; DATA &00,&7F,&78,&00,&00
;; DATA &70,&40,&40,&7F,&78
;; DATA &7F,&78,&08,&0F,&78
;; DATA &7F,&78,&40,&40,&40
;; REM MNOPQR
;; DATA &7F,&01,&7F,&01,&7F
;; DATA &7F,&79,&01,&01,&7F
;; DATA &7F,&41,&41,&43,&7F
;; DATA &7F,&79,&09,&09,&0F
;; DATA &7F,&41,&61,&61,&7F
;; DATA &7F,&79,&09,&0F,&78
;; REM STUVWX
;; DATA &4F,&49,&49,&79,&79
;; DATA &01,&01,&7F,&79,&01
;; DATA &7F,&78,&40,&40,&7F
;; DATA &0F,&7F,&40,&70,&0F
;; DATA &7F,&40,&7F,&40,&7F
;; DATA &77,&78,&08,&08,&77
;; REM YZ.-(space)
;; DATA &0F,&08,&78,&08,&0F
;; DATA &7B,&79,&49,&49,&6F
;; DATA &00,&00,&60,&00,&00
;; DATA &08,&08,&08,&08,&08
;; DATA &00,&00,&00,&00,&00
;; REM ()
;; DATA &00,&18,&66,&81,&00
;; DATA &00,&81,&66,&18,&00
