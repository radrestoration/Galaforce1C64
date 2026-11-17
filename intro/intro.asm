;; Galaforce 1 (C64 port) - the loading screens, a program of its own that loads the game.
;;
;; The original disc's front end (BBC) shows its MODE 7 instruction pages, then the MODE 5 loading picture while the game
;; loads. This does the same: the pages in C64 text mode (SPACE or joystick fire for the next one, RUN/STOP skips them), then
;; the picture (multicolour bitmap, bank 3) which stays on screen while the game's file loads over this program.
;; The data (picture, pages, block graphics) is made from the disc by tools/make_intro.py.

.setcpu "6502"
.export wait_key               ; (for the label file, tools/test_intro.py)

ptr     = $fb               ; 2
dst     = $fd               ; 2
cdst    = $f9               ; 2
tmp     = $f7
pg      = $f6               ; the page being shown
phase   = $f5               ; flashing text: 0 = shown, 1 = hidden
frames  = $f4
wmode   = $f3               ; 0 = draw the page, 1 = recolour its flashing runs
runcol  = $f2

CHARSET = $3800
BITMAP  = $e000
PICSCR  = $cc00

.segment "LOADADDR"
    .word $0801
.segment "STUB"
    .word @next
    .word 10
    .byte $9e, "2064", 0
@next:
    .word 0

.segment "CODE"
start:
    sei
    lda #$35
    sta $01
    lda #$7f
    sta $dc0d
    sta $dd0d
    lda $dc0d
    lda $dd0d
    lda #0
    sta $d01a
    sta $d015
    lda $ba
    cmp #8
    bcc @default
    cmp #12
    bcc @save
@default:
    lda #8                      ; (a PRG autostart may not leave a disk device in $ba)
@save:
    sta loader_src              ; its first byte: the device the game is loaded from
    jsr make_charset
    ; ---- text mode, VIC bank 0 ----
    lda $dd00
    ora #3
    sta $dd00
    lda #$1e                    ; screen $0400, characters $3800
    sta $d018
    lda #$c8
    sta $d016
    lda #$1b
    sta $d011
    lda #0
    sta $d020
    sta $d021
    sta pg
@pages:
    jsr show_page
    jsr wait_key
    and #2
    bne @picture                ; RUN/STOP: skip the rest
    inc pg
    lda pg
    cmp #N_PAGES
    bne @pages
@picture:
    jsr show_picture
    ; ---- the loader goes to $0334 (the game's file does not cover it), then runs ----
    ldx #loader_end - loader_src - 1
@copy:
    lda loader_src,x
    sta $0334,x
    dex
    bpl @copy
    jmp $0334 + 1               ; (past the device number)

; (runs at $0334)
loader_src:
    .byte 8
    lda #$37
    sta $01
    lda $0334
    sta $ba
    lda #4
    ldx #<($0334 + (loader_name - loader_src))
    ldy #>($0334 + (loader_name - loader_src))
    jsr $ffbd                   ; SETNAM
    lda #1
    ldx $ba
    ldy #1                      ; load where the file says
    jsr $ffba                   ; SETLFS
    lda #0
    jsr $ffd5                   ; LOAD
    bcs @error
    lda $dc0d                   ; the machine as BASIC leaves it for RUN: the timer interrupt enabled
    lda #$81
    sta $dc0d
    jmp $080d                   ; the game's entry
@error:
    lda #2
    sta $d020                   ; red border and stop
    jmp *
loader_name:
    .byte $47, $41, $4d, $45     ; GAME in PETSCII (the c64 target would convert a string)
loader_end:
    .assert loader_end - loader_src <= 128, error, "relocated loader exceeds the copy loop"

; make_charset: the lower case character set from the ROM (codes 0-127) at CHARSET, and the 64 block graphics at 128-191.
make_charset:
    lda #$33
    sta $01                     ; character ROM in place of I/O
    lda #<$d800
    sta ptr
    lda #>$d800
    sta ptr+1
    lda #<CHARSET
    sta dst
    lda #>CHARSET
    sta dst+1
    ldx #4
    jsr copy_pages
    lda #$35
    sta $01
    lda #<sixel_font
    sta ptr
    lda #>sixel_font
    sta ptr+1
    ldx #2
    ; falls into copy_pages (dst continues at CHARSET + $400)

; copy_pages: X pages from ptr to dst
copy_pages:
    ldy #0
@l: lda (ptr),y
    sta (dst),y
    iny
    bne @l
    inc ptr+1
    inc dst+1
    dex
    bne @l
    rts

; show_page: clear the screen and draw page pg
show_page:
    lda #32
    ldx #0
@s: sta $0400,x
    sta $0500,x
    sta $0600,x
    sta $0700,x
    inx
    bne @s
    lda #1
@c: sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne @c
    lda #0
    sta wmode
    ; falls into walk

; walk: run through page pg's runs: wmode 0 draws them, 1 recolours the flashing ones (hidden, or as they are)
walk:
    lda pg
    asl a
    tax
    lda page_table,x
    sta ptr
    lda page_table+1,x
    sta ptr+1
@run:
    ldy #1
    lda (ptr),y
    cmp #$ff
    beq @end
    pha
    dey
    lda (ptr),y
    sta dst
    sta cdst
    pla
    tax
    clc
    adc #>$0400
    sta dst+1
    txa
    clc
    adc #>$d800
    sta cdst+1
    ldy #2
    lda (ptr),y
    sta runcol
    iny
    lda (ptr),y
    sta tmp                     ; length
    lda ptr
    clc
    adc #4
    sta ptr                     ; (now at the screen codes)
    bcc @h
    inc ptr+1
@h: lda wmode
    bne @recolour
    ldy #0
@d: lda (ptr),y
    sta (dst),y
    lda runcol
    and #$0f
    sta (cdst),y
    iny
    cpy tmp
    bne @d
    beq @next
@recolour:
    lda runcol
    bpl @next                   ; (not a flashing run)
    and #$0f
    ldx phase
    beq @shown
    lda #0
@shown:
    ldy #0
@r: sta (cdst),y
    iny
    cpy tmp
    bne @r
@next:
    lda ptr
    clc
    adc tmp
    sta ptr
    bcc @run
    inc ptr+1
    jmp @run
@end:
    rts

; read_keys: A = bit 0 if SPACE or the joystick (port 2) fire is down, bit 1 if RUN/STOP is
read_keys:
    ldx #0
    lda #$7f
    sta $dc00
    lda $dc01
    tay
    and #$10
    bne @nospace
    ldx #1
@nospace:
    tya
    and #$80
    bne @nostop
    txa
    ora #2
    tax
@nostop:
    lda #$ff
    sta $dc00
    lda $dc00
    and #$10
    bne @nofire
    txa
    ora #1
    tax
@nofire:
    txa
    rts

; wait_key: wait for the keys to be let go, then for one to be pressed (flashing text flashes meanwhile); A = read_keys
wait_key:
@release:
    jsr read_keys
    bne @release
    lda #0
    sta phase
    sta frames
@wait:
    lda $d011                   ; one frame: the raster counter's bit 8 goes up and down
    bpl @wait
@low:
    lda $d011
    bmi @low
    inc frames
    lda frames
    and #$1f
    bne @keys
    lda phase
    eor #1
    sta phase
    lda #1
    sta wmode
    jsr walk
@keys:
    jsr read_keys
    beq @wait
    rts

; show_picture: the loading picture, in VIC bank 3
show_picture:
    lda #$0b
    sta $d011                   ; (screen off while it is made)
    lda $dd00
    and #$fc
    sta $dd00
    lda #$38                    ; screen $cc00, bitmap $e000
    sta $d018
    lda #$18
    sta $d016
    ; the colours: 01 = red and 10 = yellow from the screen RAM, 11 = white from the colour RAM
    ldx #0
@s: lda #$27
    sta PICSCR,x
    sta PICSCR+$100,x
    sta PICSCR+$200,x
    sta PICSCR+$300,x
    lda #1
    sta $d800,x
    sta $d900,x
    sta $da00,x
    sta $db00,x
    inx
    bne @s
    ; the bitmap: a byte stands for itself, a 0 is followed by a count of zero bytes (0 = 256)
    lda #<pic_rle
    sta ptr
    lda #>pic_rle
    sta ptr+1
    lda #<BITMAP
    sta dst
    lda #>BITMAP
    sta dst+1
@next:
    ldy #0
    lda (ptr),y
    inc ptr
    bne @got
    inc ptr+1
@got:
    cmp #0
    bne @lit
    lda (ptr),y                 ; the count
    inc ptr
    bne @cnt
    inc ptr+1
@cnt:
    tax
    lda #0
@z: sta (dst),y
    inc dst
    bne @zn
    inc dst+1
@zn:dex
    bne @z
    beq @check
@lit:
    sta (dst),y
    inc dst
    bne @check
    inc dst+1
@check:
    lda dst+1
    cmp #>(BITMAP + PIC_SIZE)
    bne @next
    lda dst
    cmp #<(BITMAP + PIC_SIZE)
    bne @next
    lda #$3b
    sta $d011
    rts

.segment "RODATA"
.include "../build/intro_data.inc"
