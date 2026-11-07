;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;
;; C64 port - hardware sprites for the aliens: a Y-sorted raster-IRQ multiplexer (8 sprites, any number of
;; aliens). Developed and checked headless in spritetest/sprtest.s + tools/test_sprtest.py (see there for
;; how the schedule was derived); this is the same engine reading the game's own alien arrays.
;;
;; The game keeps alien_x (colour pixels, 0-159) and alien_y (the BBC's own scanline, 0-255). spr_build,
;; called once a frame, turns every active alien into an object - hardware X = 24 + 2*alien_x, Y = 50 +
;; spr_ymap[alien_y] (the 256-line BBC screen scaled onto the 200-line one), shape = its type, or the
;; explosion frame while it is exploding - sorts them by Y and builds the next frame's list. The raster IRQ
;; at SPR_TOP_LINE swaps it in, programs the first 8 objects, and chains one IRQ per further object, each
;; just early enough to be done before the object's Y and not before the sprite it re-uses has finished
;; its 16 lines of data. An object that cannot be fitted in is moved down a few lines (never dropped, apart
;; from those that would overlap the score bar or the flags/lives rows, which the old bitmap drawing also
;; kept clear of).
;;
;; Sprite shapes live at $4400 (VIC bank 1, pointer value $10 + shape), the pointers at $43F8, the
;; tables beside them and its variables in SPRVAR (galaforce1-c64.cfg). The shared colours, shapes and tables are generated into gen/
;; by tools/make_sprtest.py.
;;
;; The swarm waves (spawn group 45: 32 aliens in 4 rows 19 lines apart) do not fit a multiplexer; they keep
;; the old bitmap drawing, selected by swarm_flag (INIT.asm), and spr_build then shows no aliens.

.reloc
.segment "SPRTAB"
.include "src-c64/gen/tables.inc"

; (.reloc above: Master-c64.mak.asm's ".org $80D" makes ca65 assemble in absolute mode, where a label is the
; running code address whatever segment it is in - wrong for the segments the linker puts at $4400 and up.)

SPR_PTRS      = $43F8
SPR_N         = 7            ; sprites used for aliens (0-6); sprite 7 is the player's ship
SPR_MAXRAW    = 16           ; objects per frame (the largest normal wave has 10 aliens)
SPR_TOP_LINE  = 30
SPR_HC        = 3            ; lines one handler run is assumed to take
SPR_DONE      = 17           ; first line after a sprite's 16 lines of data
SPR_DMA_END   = 22           ; first line a sprite's Y may match again (its DMA runs 21 lines)
SPR_YOFF      = 50           ; sprite Y of the first screen line
SPR_MINLINE   = 8            ; objects above this screen line would cover the score bar
SPR_MAXLINE   = 168          ; objects below this would cover the flags/lives rows (184 - 16)
SPR_YMAX      = SPR_YOFF + SPR_MAXLINE

.segment "ZP2": zeropage
sz_front:      .res 1        ; 0 or 16: base of the buffer the IRQ reads
sz_fcount:     .res 1
sz_bcount:     .res 1
sz_back_ready: .res 1
sz_bbase:      .res 1
sz_phase:      .res 1
sz_sp:         .res 1        ; sprite to program next
sz_tk:         .res 1        ; rank of the next object to program
sz_ncount:     .res 1
sz_rn:         .res 1
sz_oc:         .res 1
sz_oi:         .res 1
sz_key:        .res 1
sz_keyy:       .res 1
sz_rw:         .res 1
sz_ty:         .res 1
sz_th:         .res 1
sz_tsh:        .res 1
sz_tt:         .res 1
sz_tmp2:       .res 1
sz_pu:         .res 1

.segment "SPRVAR"
sz_ship_on: .res 1           ; $80 while the ship sprite is shown, else 0
sz_ship_x:  .res 1
sz_ship_xh: .res 1           ; $80 if the ship's hardware X has its 9th bit
sz_ship_y:  .res 1
so_ysp:    .res 32
so_x:      .res 32
so_xhi:    .res 32
so_ptr:    .res 32
so_col:    .res 32
so_irq:    .res 32
sr_y:      .res SPR_MAXRAW
sr_xlo:    .res SPR_MAXRAW
sr_xhi:    .res SPR_MAXRAW
sr_ptr:    .res SPR_MAXRAW
sr_col:    .res SPR_MAXRAW
s_idx:     .res SPR_MAXRAW

.segment "SPRITES"
.incbin "src-c64/gen/shapes.bin"

.segment "CODE"

spr_enmask: .byte 0,1,3,7,15,31,63,127,255
spr_bitm:   .byte 1,2,4,8,16,32,64,128
spr_bitn:   .byte $FE,$FD,$FB,$F7,$EF,$DF,$BF,$7F

; spr_init: once, at start-up. Takes the raster interrupt (through the KERNAL's $0314 vector) and turns the
; CIA1 timer interrupt off - the KERNAL's keyboard scan it drives would otherwise write $DC00 behind the
; game's own direct keyboard reads. Leaves interrupts enabled.
spr_init:
    sei
    lda #$7F
    sta $DC0D
    lda $DC0D
    lda #<spr_irq
    sta $0314
    lda #>spr_irq
    sta $0315
    lda #$FF
    sta $D01C               ; multicolour
    lda #0
    sta $D01B               ; in front of the bitmap
    sta $D017
    sta $D01D
    sta $D010
    sta $D015
    lda #SPR_SHARED_A
    sta $D025
    lda #SPR_SHARED_B
    sta $D026
    lda #$10+SPR_SHAPE_SHIP
    sta SPR_PTRS+7
    ldy #SPR_SHAPE_SHIP
    lda spr_own_col,y
    sta $D02E
    jsr spr_reset
    lda #SPR_TOP_LINE
    sta $D012
    lda #1
    sta $D019
    sta $D01A
    cli
    rts

; spr_reset: no aliens on screen (title, high scores, a new game).
spr_reset:
    lda #0
    sta sz_front
    sta sz_fcount
    sta sz_bcount
    sta sz_back_ready
    sta sz_phase
    sta sz_ship_on
    sta $D015
    rts

; spr_ship_show: the ship sprite at the cell the game keeps in ship_col/ship_row (hardware X = 24 + 8*col,
; Y = 50 + 8*row). The raster IRQ copies these to the VIC at the top of each frame.
spr_ship_show:
    lda #0
    sta sz_th
    lda ship_col
    asl
    rol sz_th
    asl
    rol sz_th
    asl
    rol sz_th
    clc
    adc #24
    sta sz_ty
    lda sz_th
    adc #0
    lsr                     ; 9th bit -> carry -> bit 7
    lda #0
    ror
    sta sz_th
    lda ship_row
    asl
    asl
    asl
    clc
    adc #SPR_YOFF
    php
    sei                     ; the three values must reach the IRQ together
    sta sz_ship_y
    lda sz_ty
    sta sz_ship_x
    lda sz_th
    sta sz_ship_xh
    lda #$80
    sta sz_ship_on
    plp
    rts

spr_ship_hide:
    lda #0
    sta sz_ship_on
    rts

; spr_build: once a frame. Preserves nothing.
spr_build:
    lda #0
    sta sz_back_ready       ; the buffer being written is no longer ready: a swap now must keep the front one
    sta sz_rn
    lda swarm_flag
    beq :+
    jmp sb_empty            ; the swarm is drawn in the bitmap
:   ldx #0
sb_loop:
    cpx alien_pool_max
    bcs sb_sort
    lda alien_active,x
    beq sb_next
    ldy alien_y,x
    lda spr_ymap,y
    cmp #SPR_MINLINE
    bcc sb_next
    cmp #SPR_MAXLINE+1
    bcs sb_next
    clc
    adc #SPR_YOFF
    sta sz_ty
    lda alien_exploding,x
    beq sb_alive
    lda alien_explode_timer,x
    cmp #EXPLOSION_FRAME_COUNT
    bcc :+
    lda #EXPLOSION_FRAME_COUNT-1
:   clc
    adc #12                 ; shapes 12-17: the explosion frames
    jmp sb_shape
sb_alive:
    lda alien_type,x
sb_shape:
    sta sz_tsh
    ldy sz_rn
    cpy #SPR_MAXRAW
    bcs sb_next
    lda sz_ty
    sta sr_y,y
    lda alien_x,x
    asl                     ; x2: colour pixels -> hardware pixels (9 bits)
    sta sz_ty
    lda #0
    rol
    sta sz_th
    lda sz_ty
    clc
    adc #24                 ; the left edge of the 320-pixel screen
    sta sr_xlo,y
    lda sz_th
    adc #0
    sta sr_xhi,y
    lda sz_tsh
    clc
    adc #$10                ; sprite pointer: shapes start at $4400
    sta sr_ptr,y
    ldy sz_tsh
    lda spr_own_col,y
    ldy sz_rn
    sta sr_col,y
    inc sz_rn
sb_next:
    inx
    jmp sb_loop
sb_empty:
sb_sort:
    lda sz_rn
    sta sz_ncount

    ; s_idx = 0..n-1, then insertion sort by sr_y
    ldx #0
:   cpx sz_ncount
    bcs sb_sinit
    txa
    sta s_idx,x
    inx
    bne :-
sb_sinit:
    lda #1
    sta sz_oi
sb_so:
    lda sz_oi
    cmp sz_ncount
    bcs sb_sdone
    tax
    lda s_idx,x
    sta sz_key
    tax
    lda sr_y,x
    sta sz_keyy
    ldy sz_oi
sb_si:
    cpy #0
    beq sb_place
    ldx s_idx-1,y
    lda sr_y,x
    cmp sz_keyy
    bcc sb_place
    beq sb_place
    txa
    sta s_idx,y
    dey
    jmp sb_si
sb_place:
    lda sz_key
    sta s_idx,y
    inc sz_oi
    jmp sb_so
sb_sdone:

    ; final Y (moved down where the sprite or the handler would not be ready), in rank order, into the back buffer
    lda sz_front
    eor #16
    sta sz_bbase
    lda #0
    sta sz_oc
    tay                     ; Y = input rank
sb_fl:
    cpy sz_ncount
    bcc :+
    jmp sb_filled
:   sty sz_oi
    ldx s_idx,y
    stx sz_rw
    lda sr_y,x
    sta sz_ty
    lda sz_oc
    beq sb_fs1              ; first object: nothing before it
    clc
    adc sz_bbase
    tax
    lda so_ysp-1,x          ; never earlier than the object before (keeps the IRQ chain in order)
    cmp sz_ty
    bcc sb_fs1
    beq sb_fs1
    sta sz_ty
sb_fs1:
    lda sz_oc
    cmp #SPR_N
    bcc sb_fs2              ; the first 8 objects have a sprite to themselves (programmed at the top of the frame)
    clc
    adc sz_bbase
    sec
    sbc #SPR_N
    sta sz_pu               ; the object that used this sprite last
    tax
    lda so_ysp,x
    clc
    adc #SPR_DONE           ; its data is finished here: the earliest the sprite may be re-programmed
    sta sz_tt
    lda sz_oc
    clc
    adc sz_bbase
    tax
    lda so_irq-1,x          ; and not before the previous handler has finished
    clc
    adc #SPR_HC
    cmp sz_tt
    bcc :+
    sta sz_tt
:   lda sz_tt
    clc
    adc #SPR_HC+1           ; earliest Y: this handler done, plus a line
    bcs sb_fdrop
    sta sz_tmp2
    ldx sz_pu
    lda so_ysp,x
    clc
    adc #SPR_DMA_END        ; and not while the sprite's DMA is still running
    bcs sb_fdrop
    cmp sz_tmp2
    bcc :+
    sta sz_tmp2
:   lda sz_tmp2
    cmp sz_ty
    bcc sb_fs2
    beq sb_fs2
    sta sz_ty               ; moved down to fit
sb_fs2:
    lda sz_ty
    cmp #SPR_YMAX+1
    bcs sb_fdrop
    lda sz_bbase
    clc
    adc sz_oc
    tay
    ldx sz_rw
    lda sz_ty
    sta so_ysp,y
    lda sz_oc
    cmp #SPR_N
    lda #0
    bcc :+
    lda sz_ty
    sec
    sbc #SPR_HC+1
:   sta so_irq,y
    lda sr_xlo,x
    sta so_x,y
    lda sr_xhi,x
    sta so_xhi,y
    lda sr_ptr,x
    sta so_ptr,y
    lda sr_col,x
    sta so_col,y
    inc sz_oc
sb_fdrop:
    ldy sz_oi
    iny
    jmp sb_fl
sb_filled:
    lda sz_oc
    sta sz_bcount
    lda #1
    sta sz_back_ready
    rts

; ---- raster interrupt (entered through the KERNAL's IRQ routine, which has pushed A, X and Y) ------------
spr_irq:
    cld
    lda #1
    sta $D019
    lda sz_phase
    bne si_chain

    ; top of frame
    lda sz_back_ready
    beq si_nosw
    lda sz_front
    eor #16
    sta sz_front
    lda sz_bcount
    sta sz_fcount
    lda #0
    sta sz_back_ready
si_nosw:
    ldx sz_fcount
    cpx #SPR_N+1
    bcc :+
    ldx #SPR_N
:   lda spr_enmask,x
    ora sz_ship_on
    sta $D015
    lda #$10+SPR_SHAPE_SHIP ; the ship: sprite 7 (its pointer every frame: clear_screen fills $4000-$43FF)
    sta SPR_PTRS+7
    lda sz_ship_x
    sta $D00E
    lda sz_ship_y
    sta $D00F
    lda $D010
    and #$7F
    ora sz_ship_xh
    sta $D010
    lda #0
    sta sz_sp
    sta sz_tk
si_pt:
    lda sz_tk
    cmp sz_fcount
    bcs si_ptdone
    cmp #SPR_N
    bcs si_ptdone
    clc
    adc sz_front
    tax
    jsr spr_program
    inc sz_sp
    inc sz_tk
    jmp si_pt
si_ptdone:
    lda sz_fcount
    cmp #SPR_N+1
    bcc si_out              ; nothing more to multiplex: the next IRQ is the next top of frame
    lda #0
    sta sz_sp
    lda #SPR_N
    sta sz_tk
    lda #1
    sta sz_phase
    lda sz_front
    clc
    adc #SPR_N
    tax
    lda so_irq,x
    sta $D012
    jmp si_out

si_chain:
si_cl:
    lda sz_tk
    clc
    adc sz_front
    tax
    jsr spr_program
    inc sz_sp
    lda sz_sp
    cmp #SPR_N
    bcc :+
    lda #0
    sta sz_sp
:   inc sz_tk
    lda sz_tk
    cmp sz_fcount
    bcs si_cdone
    clc
    adc sz_front
    tax
    lda $D012               ; already due (or within 2 lines of it): do it now rather than risk missing the line
    clc
    adc #2
    cmp so_irq,x
    bcs si_cl
    lda so_irq,x
    sta $D012
    jmp si_out
si_cdone:
    lda #0
    sta sz_phase
    lda #SPR_TOP_LINE
    sta $D012
si_out:
    pla
    tay
    pla
    tax
    pla
    rti

; X = index of the object, sz_sp = the sprite
spr_program:
    lda sz_sp
    asl
    tay
    lda so_ysp,x
    sta $D001,y
    lda so_x,x
    sta $D000,y
    ldy sz_sp
    lda so_xhi,x
    beq :+
    lda $D010
    ora spr_bitm,y
    bne :++
:   lda $D010
    and spr_bitn,y
:   sta $D010
    lda so_ptr,x
    sta SPR_PTRS,y
    lda so_col,x
    sta $D027,y
    rts
