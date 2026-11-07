;; Galaforce 1 C64 - sprite multiplexer test.
;;
;; Replays alien positions recorded from the real BBC game (tools/bbc_trace.sh, tools/make_sprtest.py) as
;; hardware sprites over the multicolour bitmap, to see how a Y-sorted raster-IRQ multiplexer copes with the
;; game's own waves. Sprite 7 is the ship (fixed); the aliens rotate through sprites 0-6.
;;
;; BBC coordinates in, screen out: alx (0-79, bytes of 2 pixels) -> sprite X = 24 + 4*alx, aly (0-255)
;; -> sprite Y = 50 + ymap[aly] (ymap scales 256 lines to 200).
;;
;; Per frame, main() builds the next frame's object list into the back buffer (sorted by Y); the raster IRQ at
;; TOP_LINE swaps it in, programs the first 7 objects, and then chains one IRQ per further object, a few lines
;; before its Y, re-using the sprite whose previous object has finished. An object whose Y is closer than
;; the previous use of the same sprite, or to the handler before it, is moved down to fit (counted in nslip); one past YMAX
;; is dropped (ndrop).

.segment "RODATA"
.include "build/sprtest/tables.inc"

.export start, shown, nbuilt, nslip, ndrop, maxobj, nframes, build, front

SPR_PTRS  = $43F8
NSPR      = 7            ; multiplexed sprites (0-6)
MAXOBJ    = 15
TOP_LINE  = 30
HC        = 3            ; lines one handler run is assumed to take (about 130 cycles + interrupt entry, with DMA stealing some)
DONE      = 17           ; first line after a sprite's 16 lines of data (the 5 below are blank)
DMA_END   = 22           ; first line a sprite's Y may match again (its DMA runs 21 lines)
YOFF      = 50           ; sprite Y of the first screen line
YMAX      = 235          ; later objects are dropped (they would run into the bottom border)
SHIP_COL  = 38           ; BBC alx / aly of the ship
SHIP_ROW  = 227

.segment "ZEROPAGE"
rp:       .res 2
tick:     .res 1
vsync:    .res 1
front:    .res 1         ; 0 or 16: base of the buffer the IRQ reads
fcount:   .res 1
bcount:   .res 1
back_ready: .res 1
bbase:    .res 1
phase:    .res 1
sp:       .res 1         ; sprite to program next
tk:       .res 1         ; rank of the next object to program
ncount:   .res 1
oc:       .res 1
oi:       .res 1
key:      .res 1
keyy:     .res 1
rw:       .res 1
ty:       .res 1
tx:       .res 1
tg:       .res 1
th:       .res 1
rcount:   .res 1
lfsr:     .res 2
sptr:     .res 2
tt:       .res 1
tmp2:     .res 1
pu:       .res 1

.segment "BSS"
o_ysp:    .res 32
o_x:      .res 32
o_xhi:    .res 32
o_ptr:    .res 32
o_col:    .res 32
o_irq:    .res 32
r_y:      .res 16
r_xlo:    .res 16
r_xhi:    .res 16
r_ptr:    .res 16
r_col:    .res 16
idx:      .res 16
nslip:    .res 1
ndrop:    .res 1
nframes:  .res 1
maxobj:   .res 1
nbuilt:   .res 1         ; replay frames built so far (for tools/test_sprtest.py)
shown:    .res 1         ; nbuilt at the last swap: which frame is on screen

.segment "SPRITES"
.incbin "build/sprtest/shapes.bin"

.segment "REPLAY"
replay:
.incbin "build/sprtest/replay.bin"

.segment "RODATA"
enmask:   .byte 0,1,3,7,15,31,63,127
bitm:     .byte 1,2,4,8,16,32,64,128
bitn:     .byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F
starpat:  .byte $40,$10,$04,$01

.segment "CODE"
    jmp start

start:
    sei
    lda #$7F
    sta $DC0D
    sta $DD0D
    lda $DC0D
    lda $DD0D
    lda #$35
    sta $01
    lda #<irq
    sta $FFFE
    lda #>irq
    sta $FFFF
    lda #<nmi
    sta $FFFA
    lda #>nmi
    sta $FFFB

    ; VIC bank 1, matrix $4000, bitmap $6000, multicolour bitmap
    lda $DD00
    and #$FC
    ora #$02
    sta $DD00
    lda #$08
    sta $D018
    lda #$3B
    sta $D011
    lda #$D8
    sta $D016
    lda #0
    sta $D020
    sta $D021

    ; screen matrix: pixel value 01 = white; colour RAM 0
    lda #<$4000
    sta sptr
    lda #>$4000
    sta sptr+1
    ldx #4
    ldy #0
fm: lda #$10
    sta (sptr),y
    iny
    bne fm
    inc sptr+1
    dex
    bne fm
    lda #<$D800
    sta sptr
    lda #>$D800
    sta sptr+1
    ldx #4
    ldy #0
fc: lda #0
    sta (sptr),y
    iny
    bne fc
    inc sptr+1
    dex
    bne fc

    ; a few stars in the bitmap, so the sprites have something to be in front of
    lda #$E1
    sta lfsr
    lda #$AC
    sta lfsr+1
    ldx #200
stl:
    lsr lfsr+1
    ror lfsr
    bcc :+
    lda lfsr+1
    eor #$B4
    sta lfsr+1
:   lda lfsr+1
    and #$1F
    cmp #$1F
    bcs stn
    ora #$60
    sta sptr+1
    lda lfsr
    sta sptr
    lda lfsr
    and #3
    tay
    lda starpat,y
    ldy #0
    ora (sptr),y
    sta (sptr),y
stn:
    dex
    bne stl

    ; sprites: multicolour, in front, no expansion
    lda #$FF
    sta $D01C
    lda #0
    sta $D01B
    sta $D017
    sta $D01D
    sta $D010
    lda #SPR_SHARED_A
    sta $D025
    lda #SPR_SHARED_B
    sta $D026

    ; the ship: sprite 7, fixed
    lda #SHIP_COL*4+24
    sta $D00E
    lda #SHIP_ROW
    tay
    lda spr_ymap,y
    clc
    adc #YOFF
    sta $D00F
    lda #$10+SPR_SHAPE_SHIP
    sta SPR_PTRS+7
    lda spr_own_col+SPR_SHAPE_SHIP
    sta $D027+7
    lda #$80
    sta $D015

    lda #0
    sta front
    sta fcount
    sta bcount
    sta back_ready
    sta phase
    sta tick
    sta vsync
    sta nslip
    sta ndrop
    sta nframes
    sta maxobj
    sta nbuilt
    sta shown
    lda #<replay
    sta rp
    lda #>replay
    sta rp+1

    lda #TOP_LINE
    sta $D012
    lda #1
    sta $D01A
    cli

main:
    lda vsync
    beq main
    lda #0
    sta vsync
    inc tick
    lda tick
    and #1                  ; a new replay frame every other screen frame (25 Hz)
    bne main
    jsr build
    jmp main

nmi:
    rti

;; ---- build the back buffer from the next replay frame ---------------------------------------------------
build:
    ldy #0
    lda (rp),y
    cmp #$FF
    bne :+
    lda #<replay
    sta rp
    lda #>replay
    sta rp+1
    lda (rp),y
:   sta rcount
    inc rp
    bne :+
    inc rp+1
:   inc nframes
    ldx #0                  ; raw objects kept
    lda rcount
    beq bsort0
brd:
    ldy #0
    lda (rp),y
    sta tx
    iny
    lda (rp),y
    sta ty
    iny
    lda (rp),y
    sta tg
    lda rp
    clc
    adc #3
    sta rp
    bcc :+
    inc rp+1
:   cpx #16
    bcs bnext               ; more than 16: ignore the rest
    ldy ty
    lda spr_ymap,y
    clc
    adc #YOFF
    cmp #YMAX+1
    bcs bdrop
    sta r_y,x
    lda tx
    lsr
    lsr
    lsr
    lsr
    lsr
    lsr
    sta th
    lda tx
    asl
    asl
    clc
    adc #24
    sta r_xlo,x
    lda th
    adc #0
    sta r_xhi,x
    lda tg
    lsr
    tay
    lda spr_gra2shape,y
    tay
    clc
    adc #$10
    sta r_ptr,x
    lda spr_own_col,y
    sta r_col,x
    inx
    jmp bnext
bdrop:
    inc ndrop
bnext:
    dec rcount
    bne brd
bsort0:
    stx ncount

    ; idx = 0..n-1, then insertion sort by r_y
    ldx #0
:   cpx ncount
    bcs sinit
    txa
    sta idx,x
    inx
    bne :-
sinit:
    lda #1
    sta oi
so: lda oi
    cmp ncount
    bcs sdone
    tax
    lda idx,x
    sta key
    tax
    lda r_y,x
    sta keyy
    ldy oi
si: cpy #0
    beq sp_
    ldx idx-1,y
    lda r_y,x
    cmp keyy
    bcc sp_
    beq sp_
    txa
    sta idx,y
    dey
    jmp si
sp_:
    lda key
    sta idx,y
    inc oi
    jmp so
sdone:

    ; final Y (slipped where a sprite would be re-used too soon), in rank order, into the back buffer
    lda front
    eor #16
    sta bbase
    lda #0
    sta oc
    tay                     ; Y = input rank
fl: cpy ncount
    bcc :+
    jmp filled
:   sty oi
    ldx idx,y
    stx rw
    lda r_y,x
    sta ty
    lda oc
    beq fs1                 ; first object: nothing before it
    clc
    adc bbase
    tax
    lda o_ysp-1,x           ; never earlier than the object before (keeps the IRQ chain in order)
    cmp ty
    bcc fs1
    beq fs1
    sta ty
    inc nslip
fs1:
    lda oc
    cmp #NSPR
    bcc fs2                 ; the first 7 objects have a sprite to themselves (programmed at the top of the frame)
    clc
    adc bbase
    sec
    sbc #NSPR
    sta pu                  ; the object that used this sprite last
    tax
    lda o_ysp,x
    clc
    adc #DONE               ; its data is finished here: the earliest the sprite may be re-programmed
    sta tt
    lda oc
    clc
    adc bbase
    tax
    lda o_irq-1,x           ; and not before the previous handler has finished
    clc
    adc #HC
    cmp tt
    bcc :+
    sta tt
:   lda tt
    clc
    adc #HC+1               ; earliest Y: this handler done, plus a line
    bcs fdrop
    sta tmp2
    ldx pu
    lda o_ysp,x
    clc
    adc #DMA_END            ; and not while the sprite's DMA is still running
    bcs fdrop
    cmp tmp2
    bcc :+
    sta tmp2
:   lda tmp2
    cmp ty
    bcc fs2
    beq fs2
    sta ty                  ; moved down to fit
    inc nslip
fs2:
    lda ty
    cmp #YMAX+1
    bcs fdrop
    lda bbase
    clc
    adc oc
    tay
    ldx rw
    lda ty
    sta o_ysp,y
    lda oc
    cmp #NSPR
    lda #0
    bcc :+
    lda ty
    sec
    sbc #HC+1
:   sta o_irq,y
    lda r_xlo,x
    sta o_x,y
    lda r_xhi,x
    sta o_xhi,y
    lda r_ptr,x
    sta o_ptr,y
    lda r_col,x
    sta o_col,y
    inc oc
    jmp fnext
fdrop:
    inc ndrop
fnext:
    ldy oi
    iny
    jmp fl
filled:
    lda oc
    sta bcount
    cmp maxobj
    bcc :+
    sta maxobj
:   inc nbuilt
    lda #1
    sta back_ready
    rts

;; ---- raster interrupt -----------------------------------------------------------------------------------
irq:
    pha
    txa
    pha
    tya
    pha
    lda #1
    sta $D019
    lda phase
    bne chain

    ; top of frame
    inc vsync
    lda back_ready
    beq nosw
    lda front
    eor #16
    sta front
    lda bcount
    sta fcount
    lda #0
    sta back_ready
    lda nbuilt
    sta shown
nosw:
    ldx fcount
    cpx #NSPR+1
    bcc :+
    ldx #NSPR
:   lda enmask,x
    ora #$80
    sta $D015
    lda #0
    sta sp
    sta tk
pt: lda tk
    cmp fcount
    bcs ptdone
    cmp #NSPR
    bcs ptdone
    clc
    adc front
    tax
    jsr program
    inc sp
    inc tk
    jmp pt
ptdone:
    lda fcount
    cmp #NSPR+1
    bcc out                 ; nothing more to multiplex: the next IRQ is the next top of frame
    lda #0
    sta sp
    lda #NSPR
    sta tk
    lda #1
    sta phase
    lda front
    clc
    adc #NSPR
    tax
    lda o_irq,x
    sta $D012
    jmp out

chain:
cl: lda tk
    clc
    adc front
    tax
    jsr program
    inc sp
    lda sp
    cmp #NSPR
    bcc :+
    lda #0
    sta sp
:   inc tk
    lda tk
    cmp fcount
    bcs cdone
    clc
    adc front
    tax
    lda $D012               ; already due (or within 2 lines of it): do it now rather than risk missing the line
    clc
    adc #2
    cmp o_irq,x
    bcs cl
    lda o_irq,x
    sta $D012
    jmp out
cdone:
    lda #0
    sta phase
    lda #TOP_LINE
    sta $D012
out:
    pla
    tay
    pla
    tax
    pla
    rti

;; X = index of the object, sp = the sprite
program:
    lda sp
    asl
    tay
    lda o_ysp,x
    sta $D001,y
    lda o_x,x
    sta $D000,y
    ldy sp
    lda o_xhi,x
    beq :+
    lda $D010
    ora bitm,y
    bne :++
:   lda $D010
    and bitn,y
:   sta $D010
    lda o_ptr,x
    sta SPR_PTRS,y
    lda o_col,x
    sta $D027,y
    rts
