;; C64 startup, title screen, and the minimal playable game loop
;; (splash -> press SPACE/RETURN -> ship + stars + bullets, Z/X/:/​/ to
;; move, RETURN to fire).
;;
;; Everything on screen (text, stars, ship, alien, flags, lives icon,
;; bullets) is plotted as real bitmap pixels in VIC-II MULTICOLOR bitmap
;; mode: bank 1, screen-matrix at $4000 (per-cell colors - hi-nibble and
;; lo-nibble select 2 of the cell's 3 non-background colors, color RAM's
;; low-nibble the 3rd; see clear_screen), bitmap data at $6000 (320x200,
;; 8 bytes/cell, 40x25 cells, 2 bits/pixel = 160 color-pixels wide).
;; Chosen over standard (hi-res) bitmap mode because C64 multicolor's
;; color-pixel grid (160 wide) is dimensionally identical to BBC MODE 2's
;; own pixel grid (also 160 wide, also "fat"/double-width pixels) - real
;; BBC font/graphics data maps at NATIVE width with no stretching, and
;; each cell gets 3 independently-settable colors (not just 1), much
;; closer to BBC MODE 2's real per-pixel color density than hi-res
;; bitmap's "background + 1 foreground per cell" would allow. The cost -
;; shared with every C64 multicolor mode - is half the hi-res horizontal
;; resolution, screen-wide.
;;
;; Only 3 non-background colors exist at once, and they're set the SAME
;; for every plain background cell (clear_screen). Anything needing more
;; colors than that (the ship, alien, lives icon) gets its OWN per-cell
;; screen-matrix/color-RAM override instead of using the shared
;; background palette - see draw_ship/draw_alien/draw_one_lifeicon - and
;; must therefore fully own whichever cells it's drawn into (a moving
;; object's erase step overwrites those cells outright, not XOR, so nothing
;; using the shared background palette - a star, a bullet - can safely
;; share a cell with one of these without the object's next move
;; clobbering it; see fire_bullet_if_requested's comment on the bug this
;; caused once already). Anything that reuses the shared background
;; palette (stars, bullets) draws via XOR instead, needing no per-cell
;; color writes at all, and CAN move through arbitrary cells freely.
;;
;; Moving objects (ship, bullets; aliens once they move) are erased (re-
;; plot the background) at their old position and redrawn at the new one
;; every frame they move - real CPU cost hardware sprites don't charge.
;; Budget for this per-object as more of them appear at once; measured
;; BBC vs. C64 effective speeds are much closer than the raw 2MHz-vs-1MHz
;; clocks suggest once RAM access and badline overhead are accounted for
;; (BBC's 6502A only hits 2MHz for ROM; RAM access is ~1MHz regardless of
;; video mode - see https://www.everygamegoing.com/larticle/speed-the-big-difference-000/52365
;; and https://stardot.org.uk/forums/viewtopic.php?t=11997), but it's
;; still the resource to watch as more systems interact (alien animation,
;; collision detection, more bullets).
;;
;; Keyboard input is read directly through the CIA1 keyboard matrix
;; ($DC00 selects a column by clearing its bit; $DC01 then reads that
;; column's row switches, 0 = pressed) - see check_start_key and
;; handle_ship_input for the specific column/row masks in use.
;;
;; Zero-page scratch usage (see ZPWORK.asm) is shared and reused freely
;; across every routine below, not per-routine private state: temp2/
;; temp3/temp4 are typically source-string/dest-bitmap/dest-screen-matrix
;; pointers during printing, or bitmap/screen-matrix/color-RAM addresses
;; elsewhere; colour holds a plain 0-15 foreground value; length and
;; temp1 are loop counters/scratch bytes reused for whatever the current
;; routine needs (a row index, a column, a countdown) - never assume a
;; value in any of these survives a call to another routine. None of
;; this is used by any other (still-unconverted) BBC-derived system yet.

exec:
    sei

    ; VIC bank 1 ($4000-$7FFF): screen-matrix at $4000 (bank offset 0),
    ; bitmap at $6000 (bank offset $2000, i.e. $D018 bit 3 = 1). MULTICOLOR
    ; bitmap mode: $D011 BMM=1, $D016 MCM=1. Chosen over standard (hi-res)
    ; bitmap mode because C64 multicolor's color-pixel grid (160 wide) is
    ; dimensionally identical to BBC MODE 2's own pixel grid (also 160
    ; wide, also "fat"/double-width pixels) - the real font/graphics data
    ; can map at NATIVE width with no artificial stretching, and each
    ; cell gets 3 independently-settable colors (not just 1), matching
    ; BBC MODE 2's real per-pixel color density far better than hi-res
    ; bitmap did. The cost - shared with every C64 multicolor mode - is
    ; half the hi-res horizontal resolution, screen-wide.
    lda $DD00
    and #$FC
    ora #$02
    sta $DD00
    lda #$08
    sta $D018
    lda #$3B            ; DEN=1,RSEL=1,YSCROLL=3,BMM=1,ECM=0,raster hi=0
    sta $D011
    lda $D016
    ora #$10             ; MCM on
    sta $D016
    lda #$01
    sta $D020            ; border white - shows the visible-area edges
    lda #$00
    sta $D021             ; background black

    jsr clear_screen

    ; --- Title: GALAFORCE, 3x2 cells/letter (double width, double height -
    ; see blit_title_char), red, rows 4-5. 9 letters x 3 cells = 27 cells;
    ; (40-27)/2 = 6 start col, centering it same as before. col*8 (max
    ; 30*8=240) still fits in one byte, and since $6500's low byte is 0,
    ; adding col*8 to it never carries - temp3's high byte stays $65. ---
    ldx #0
draw_title_loop:
    txa
    sta length            ; length = index (temporary)
    asl a                 ; A = index*2
    clc
    adc length             ; A = index*2 + index = index*3
    clc
    adc #6                  ; A = index*3 + 6
    sta length               ; length = col
    lda length
    asl a
    asl a
    asl a
    sta temp3              ; low byte = col*8
    lda #$65
    sta temp3+1
    lda length
    clc
    adc #<($4000+4*40)
    sta temp4
    lda #>($4000+4*40)
    adc #0
    sta temp4+1
    lda colour_title
    sta colour
    txa
    pha                    ; blit_title_char uses X as scratch - preserve
    lda title_letter_codes,x  ; our loop index across the call (X unchanged
    jsr blit_title_char        ; by txa/pha above, so ,x addressing here
    pla                          ; still uses the right index)
    tax
    inx
    cpx #9
    bne draw_title_loop

    jsr draw_score_bar
    jsr draw_body_text

    jsr draw_level_flags

    jsr star_init

; --- Title screen: stars animate, wait for SPACE or RETURN to start. One
; raster-poll per frame (line 250 - below the visible 200 lines, so a
; single 8-bit compare against $D012 is enough). ---
title_wait_loop:
    lda #250
twl_wait_raster:
    cmp $D012
    bne twl_wait_raster
    jsr movestars
    jsr check_start_key
    bne title_wait_loop

; --- Game start: wipe the title text, fresh stars, drop the ship in at
; its start column, and redraw the score bar / level flags / lives icon
; on the now-blank game screen (clear_screen wiped them along with
; everything else). ---
    jsr clear_screen
    jsr star_init
    jsr draw_score_bar
    jsr draw_level_flags
    jsr draw_lives_icons
    jsr draw_alien
    lda #SHIP_START_COL
    sta ship_col
    lda #SHIP_START_ROW
    sta ship_row
    jsr draw_ship

    ; Prime fire_key_prev with RETURN's actual current state, so if the
    ; player started the game by pressing RETURN (still held on this
    ; very first frame), fire_bullet_if_requested's edge trigger sees it
    ; as "already down", not a fresh press, and doesn't fire immediately.
    lda #$FE               ; clear bit0: select column 0 (RETURN's column)
    sta $DC00
    lda $DC01
    and #$02                 ; row bit 1 = RETURN
    beq gs_return_held
    lda #0
    jmp gs_store_fire_prev
gs_return_held:
    lda #1
gs_store_fire_prev:
    sta fire_key_prev

game_loop:
    lda #250
gl_wait_raster:
    cmp $D012
    bne gl_wait_raster
    jsr movestars
    jsr handle_ship_input
    jsr fire_bullet_if_requested
    jsr move_bullets
    jmp game_loop

; check_start_key: returns with the Z flag set (BEQ taken by the caller)
; if SPACE or RETURN is currently held, clear otherwise. See the C64
; keyboard matrix note by handle_ship_input for how CIA1 is used here.
check_start_key:
    lda #$7F              ; clear bit7: select column 7 (SPACE's column)
    sta $DC00
    lda $DC01
    and #$10                ; row bit 4 = SPACE
    beq csk_pressed
    lda #$FE              ; clear bit0: select column 0 (RETURN's column)
    sta $DC00
    lda $DC01
    and #$02                ; row bit 1 = RETURN
    beq csk_pressed
    lda #1
    rts
csk_pressed:
    lda #0
    rts

; handle_ship_input: polls Z/X (left/right) and ":"/"/" (up/down - see
; below) via the CIA1 keyboard matrix ($DC00 selects a column by
; clearing its bit; $DC01 then reads that column's row switches, 0 =
; pressed) and moves the ship one cell per call, throttled to every
; SHIP_MOVE_SLOWDOWN'th call so it doesn't outrun the eye at 50/60 calls
; a second. Erase-then-redraw, same "just overwrite the cells" approach
; as the rest of this file - the ship isn't blended with whatever star
; happened to be under it.
;
; The C64 keyboard has no dedicated unshifted apostrophe key the way a
; PC one does, so "up" is mapped to the physical key that sits in the
; same spot on a real C64 keyboard: ":" (column 5, row bit 5). "/" is a
; real, unshifted C64 key as-is (column 6, row bit 7) and needs no
; substitution. If VICE's keymap sends host "'" somewhere else, this is
; a 2-constant fix (the LDA #$DF / AND #$20 pair below).
SHIP_MOVE_SLOWDOWN = 4

handle_ship_input:
    inc ship_move_count
    lda ship_move_count
    cmp #SHIP_MOVE_SLOWDOWN
    bcc hsi_done
    lda #0
    sta ship_move_count

    lda #$FD               ; clear bit1: select column 1 (Z's column)
    sta $DC00
    lda $DC01
    and #$10                 ; row bit 4 = Z
    bne hsi_check_x
    lda ship_col
    cmp #SHIP_MIN_COL
    beq hsi_check_x
    jsr erase_ship
    dec ship_col
    jsr draw_ship

hsi_check_x:
    lda #$FB               ; clear bit2: select column 2 (X's column)
    sta $DC00
    lda $DC01
    and #$80                 ; row bit 7 = X
    bne hsi_check_up
    lda ship_col
    cmp #SHIP_MAX_COL
    beq hsi_check_up
    jsr erase_ship
    inc ship_col
    jsr draw_ship

hsi_check_up:
    lda #$DF               ; clear bit5: select column 5 (":"'s column)
    sta $DC00
    lda $DC01
    and #$20                  ; row bit 5 = ":"
    bne hsi_check_down
    lda ship_row
    cmp #SHIP_MIN_ROW
    beq hsi_check_down
    jsr erase_ship
    dec ship_row
    jsr draw_ship

hsi_check_down:
    lda #$BF               ; clear bit6: select column 6 ("/"'s column)
    sta $DC00
    lda $DC01
    and #$80                  ; row bit 7 = "/"
    bne hsi_done
    lda ship_row
    cmp #SHIP_MAX_ROW
    beq hsi_done
    jsr erase_ship
    inc ship_row
    jsr draw_ship

hsi_done:
    rts

ship_col:
 .byte 0
ship_row:
 .byte 0
ship_move_count:
 .byte 0

; --- Bullets: decoded from the real BBC data, not invented. BOMBS1.asm's
; move_bomb plots bombgra (EQUB 21,21,21,21,21,21,51,1 - one BBC byte-
; column, 8 scanlines) straight into (screen),Y for Y=7..0, i.e. Y IS the
; scanline offset with no inversion trick (unlike the ship's dual-buffer
; sprite routine, which is what made the ship need flipping) - so this
; decodes directly in top-to-bottom order. BBC MODE 2 colors, decoded
; carefully via the bit formula this time (pixel0=bits7,5,3,1; pixel1=
; bits6,4,2,0) rather than by hand - an earlier pass had this wrong for
; the x6 row (called it yellow+magenta; it's actually black+white,
; which is exactly the "extra yellow shadow" you flagged - that pixel
; should never have been drawn at all): 21($15)=black+white (x6 rows),
; 51($33)=magenta+magenta, 1($01)=black+red.
; BOMBS1.asm also plots one extra lone pixel in the NEXT column over
; (value 34/$22 at Y=14, i.e. that column's row 6, decoding to a lone
; magenta dot with black beside it) - that's the 3rd BBC pixel-pair of
; row 6, landing in this same C64 cell's other half (position 2 of the
; 4 color-pixels a cell holds), so it's included below, not dropped.
;
; 2 BBC pixels wide on its own (rows 0-5 and row 7), row 6 alone reaching
; 3 pixels wide via that extra dot. White isn't one of the 3 available
; colors here (yellow/cyan/magenta), so it's substituted with magenta -
; the only color reduction, not a shape change: the x6 rows' first
; pixel is real background (black), not a substituted color, so it's
; just left as background, no pixel drawn there at all.
;
; A small pool (BULLET_COUNT) replaces the old single-bullet-in-flight
; limit. Movement is a full cell-row per tick (matching BOMBS1.asm's own
; "SBC #8" - it moves 8 BBC scanlines, i.e. one row, per game frame too),
; which is simple: no sub-cell/cell-boundary bookkeeping needed at all,
; just a plain row counter and compute_bullet_addr's row*40+col*8 math.
BULLET_COUNT = 4

bullet_bitmap:
 .byte $30,$30,$30,$30,$30,$30,$fc,$20

bullet_active:
 .res BULLET_COUNT
bullet_row:
 .res BULLET_COUNT
bullet_col:
 .res BULLET_COUNT
fire_key_prev:
 .byte 0

; compute_bullet_addr: X = bullet slot index. Sets temp3 (word) = bitmap
; address of cell (bullet_row[X], bullet_col[X]) - bitmap only, bullets
; need no screen-matrix/color-RAM address (see above).
compute_bullet_addr:
    lda #0
    sta temp3
    sta temp3+1
    lda bullet_row,x
    beq cba_row_done
    sta length              ; length = loop counter (documented scratch,
                             ; free here - see file header)
cba_row_loop:
    lda temp3
    clc
    adc #40
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    dec length
    bne cba_row_loop
cba_row_done:
    lda temp3
    clc
    adc bullet_col,x
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1              ; temp3 = row*40 + col (cell index)
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1              ; temp3 = cell index * 8
    lda temp3
    clc
    adc #<$6000
    sta temp3
    lda temp3+1
    adc #>$6000
    sta temp3+1
    rts

; draw_bullet_x: X = bullet slot index. XOR-plots bullet_bitmap at that
; slot's current cell - also serves as its own erase (calling it twice
; at the same position cancels out), same as movestars/move_ship.
; Preserves X.
draw_bullet_x:
    jsr compute_bullet_addr
    ldy #0
dbx_loop:
    lda bullet_bitmap,y
    eor (temp3),y
    sta (temp3),y
    iny
    cpy #8
    bne dbx_loop
    rts

; fire_bullet_if_requested: RETURN fires, edge-triggered (only on a
; fresh press, not held down) into the first free slot of the pool -
; SPACE is reserved for starting the game and is never read here. The
; edge trigger is also what stops a bullet firing the instant the game
; starts: fire_key_prev is primed with RETURN's actual state right
; before game_loop begins (see there), so "still held from starting the
; game" doesn't look like a new press.
fire_bullet_if_requested:
    lda #$FE               ; clear bit0: select column 0 (RETURN's column)
    sta $DC00
    lda $DC01
    and #$02                 ; row bit 1 = RETURN
    beq fbr_held
    lda #0
    sta fire_key_prev
    rts
fbr_held:
    lda fire_key_prev
    bne fbr_done             ; already down last frame - not a new press
    lda #1
    sta fire_key_prev

    ldx #0
fbr_find_slot:
    lda bullet_active,x
    beq fbr_spawn
    inx
    cpx #BULLET_COUNT
    bne fbr_find_slot
    rts                      ; pool is full - drop this shot
fbr_spawn:
    lda #1
    sta bullet_active,x
    ; Spawn one row ABOVE the ship, never in the ship's own cell: that
    ; cell has the ship's own screen-matrix/color-RAM override (see
    ; SHIP_MATRIX_BYTE), so a bullet XOR'd in there shows the wrong
    ; colors, and worse, erase_ship/draw_ship overwrite it outright
    ; (not XOR) whenever the ship moves, desyncing the bullet's XOR
    ; parity permanently - this was the "stuck single pixel" bug.
    lda ship_row
    beq fbr_row_zero
    sec
    sbc #1
    jmp fbr_row_set
fbr_row_zero:
    lda #0
fbr_row_set:
    sta bullet_row,x
    lda ship_col
    clc
    adc #1                   ; middle of the ship's 3 cells
    sta bullet_col,x
    jsr draw_bullet_x
fbr_done:
    rts

; move_bullets: advances every active bullet one cell-row up per call,
; deactivating instead of wrapping once it passes row 0 (compare
; movestars, which respawns - bullets just vanish off the top).
; Throttled the same way as movestars/handle_ship_input - a full cell-
; row a frame was too fast to actually look at. This slowdown is a
; temporary look-at-it aid, not a final gameplay speed - revisit once
; real play-balance is being tuned. Colors (currently substituted white
; -> magenta, red -> cyan, per the 3-non-black-per-cell budget - see the
; bullet_bitmap note above) are also accepted "for now", not final -
; revisit those too when picking the game's real palette.
BULLET_MOVE_SLOWDOWN = 8
bullet_move_count:
 .byte 0

move_bullets:
    inc bullet_move_count
    lda bullet_move_count
    cmp #BULLET_MOVE_SLOWDOWN
    bcc mbs_rts
    lda #0
    sta bullet_move_count

    ldx #0
mbs_loop:
    lda bullet_active,x
    beq mbs_next
    jsr draw_bullet_x         ; erase at the current position
    lda bullet_row,x
    beq mbs_deactivate
    dec bullet_row,x
    jsr draw_bullet_x         ; redraw at the new position
    jmp mbs_next
mbs_deactivate:
    lda #0
    sta bullet_active,x
mbs_next:
    inx
    cpx #BULLET_COUNT
    bne mbs_loop
mbs_rts:
    rts

; --- Alien (test render, fixed position - "let's put an alien on the
; screen so we can take a look"): decoded from O.GRAPHIC's graphics
; pointer table, entry 6 (BBC address $2BE0, file offset $2BE0-$297A=
; 1638). ALIENS2.asm's alien_on_off reaches this table via "LDA graph,X:
; LDY graph+1,X", X = an alien's initgra value - a byte offset into the
; SAME pointer table the ship's graph+36/37 pointer lives in (see
; ship_bitmap below): entries are 96 bytes apart (alwidth*alheight=6*16,
; CONST.asm), dumping the table's first 19 entries shows 0x29a0, 0x2a00,
; 0x2a60, 0x2ac0, ... up to entry 18 = 0x2fa0, exactly the ship's known
; pointer - confirming the table layout. Same dual-buffer "sprite"
; plotter as the ship, so the same row-reversal applies. Colors (blue 59
; px, cyan 38, white 13, plus 2 stray magenta pixels folded into blue)
; fit the 3-non-black-per-cell budget with almost no loss - unlike the
; ship, nothing major needed substituting away.
ALIEN_ROW = 10
ALIEN_COL = 18
ALIEN_MATRIX_BYTE   = $63   ; hi-nibble=6 (blue, pattern 01), lo-nibble=3 (cyan, pattern 10)
ALIEN_COLORRAM_BYTE = $01   ; white (pattern 11)

alien_bitmap:
 .byte $00,$03,$0f,$0d,$25,$25,$09,$02
 .byte $20,$ef,$ff,$55,$55,$55,$55,$56
 .byte $00,$00,$c0,$c0,$60,$60,$80,$00
 .byte $29,$95,$99,$22,$02,$09,$25,$0a
 .byte $55,$55,$55,$56,$66,$65,$89,$02
 .byte $a0,$58,$98,$20,$00,$80,$60,$80

; draw_alien: fixed position (compile-time constants, no movement yet -
; this is just a test render), so plain absolute,Y addressing works
; directly, no runtime address computation needed.
draw_alien:
    ldx #0
    ldy #0
dal_top:
    lda alien_bitmap,x
    sta $6000+(ALIEN_ROW*40+ALIEN_COL)*8,y
    inx
    iny
    cpy #24
    bne dal_top

    ldy #0
dal_bottom:
    lda alien_bitmap,x
    sta $6000+((ALIEN_ROW+1)*40+ALIEN_COL)*8,y
    inx
    iny
    cpy #24
    bne dal_bottom

    lda #ALIEN_MATRIX_BYTE
    sta $4000+ALIEN_ROW*40+ALIEN_COL+0
    sta $4000+ALIEN_ROW*40+ALIEN_COL+1
    sta $4000+ALIEN_ROW*40+ALIEN_COL+2
    sta $4000+(ALIEN_ROW+1)*40+ALIEN_COL+0
    sta $4000+(ALIEN_ROW+1)*40+ALIEN_COL+1
    sta $4000+(ALIEN_ROW+1)*40+ALIEN_COL+2

    lda #ALIEN_COLORRAM_BYTE
    sta $D800+ALIEN_ROW*40+ALIEN_COL+0
    sta $D800+ALIEN_ROW*40+ALIEN_COL+1
    sta $D800+ALIEN_ROW*40+ALIEN_COL+2
    sta $D800+(ALIEN_ROW+1)*40+ALIEN_COL+0
    sta $D800+(ALIEN_ROW+1)*40+ALIEN_COL+1
    sta $D800+(ALIEN_ROW+1)*40+ALIEN_COL+2
    rts

; --- The player ship: decoded directly from the BBC object file, not
; guessed or sampled from a screenshot. FLAGS.asm's INIT.asm calls
; JSR sprite with a pointer taken from graph+36/37 (graph = &297A, the
; load address of object/O.GRAPHIC - see CONST.asm); that pointer is
; $2FA0, i.e. file offset $2FA0-$297A = 1574, and CONST.asm's mywidth=6/
; myheight=16 give its size: 6 BBC bytes (12 BBC pixels) wide by 16
; scanlines tall - exactly a 3-cell by 2-cell block at native width
; (1 BBC pixel = 1 C64 color-pixel, the same equivalence used for the
; text and flags - see the file header).
;
; The real ship uses all 8 BBC MODE 2 colors; reduced here to white/
; yellow/cyan + black (the 3-non-black-per-cell limit - same tradeoff as
; the star field). Frequency in the real data (black 89, yellow 37,
; white 36, cyan 15, green 8, magenta 3, blue 2, red 2 pixels) picked
; the keepers: white and yellow stay as-is (by far the two biggest
; blocks - hull outline and hull fill), green folds into white (mostly
; adjacent to it, the wingtip outline), and cyan absorbs blue/magenta/
; red (all minor engine/thruster accents already inside the cyan engine
; block). ship_bitmap is 6 cells' worth of C64 multicolor bytes, top row
; (cols 0-2) then bottom row (cols 0-2), 8 bytes/cell, matching how
; compute_ship_addrs/draw_ship walk it.
SHIP_START_ROW  = 20
SHIP_START_COL  = 18
SHIP_MIN_COL    = 0
SHIP_MAX_COL    = 37     ; 40 cells - 3 wide
SHIP_MIN_ROW    = 0
SHIP_MAX_ROW    = 23     ; 25 rows - 2 tall
SHIP_MATRIX_BYTE   = $17 ; hi-nibble=1 (white, pattern 01), lo-nibble=7 (yellow, pattern 10)
SHIP_COLORRAM_BYTE = $03 ; cyan (pattern 11)

; Rows run bottom-to-top in the source data (the BBC plotter counts the
; screen address DOWN as it walks forward through the bytes), so this is
; the decoded data with row order reversed from the first pass - that
; first pass had the engine/exhaust end on top and the nose on the
; bottom, i.e. upside down.
ship_bitmap:
 .byte $00,$00,$00,$03,$01,$01,$02,$c2
 .byte $30,$10,$10,$13,$65,$a9,$ba,$fe
 .byte $00,$00,$00,$00,$00,$00,$00,$0c
 .byte $4a,$69,$65,$61,$69,$66,$91,$40
 .byte $fe,$fd,$fd,$fd,$75,$56,$a9,$88
 .byte $84,$a4,$64,$24,$a4,$64,$18,$04

; compute_ship_addrs: A = leftmost column (0-39) of the ship's 3-cell
; span; ship_row (0-24) = its top row. Sets temp3 (word) = bitmap
; address of cell (ship_row, col), temp4 (word) = screen-matrix address
; of that cell, temp2 (word) = the matching color-RAM address. Row is
; now a variable (up/down movement), so this needs one runtime multiply
; (ship_row*40, via repeated add - ship_row is at most 24, and this only
; runs on an actual move-tick, not every frame) - everything else is
; derived from that same (ship_row*40+col) cell index by shifting (*8
; for the bitmap byte offset) or adding a base page.
compute_ship_addrs:
    sta temp1              ; temp1 = col (see file header on temp1/temp/
                            ; colour aliasing - free here)

    lda #0
    sta temp4
    sta temp4+1
    lda ship_row
    beq csa_row40_done
    sta length              ; length = loop counter (documented scratch,
                             ; free here - see file header)
csa_row40_loop:
    lda temp4
    clc
    adc #40
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1
    dec length
    bne csa_row40_loop
csa_row40_done:
    lda temp4
    clc
    adc temp1
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1              ; temp4 = ship_row*40 + col (no page base yet)

    lda temp4
    sta temp3
    lda temp4+1
    sta temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1              ; temp3 = (ship_row*40+col) * 8
    lda temp3
    clc
    adc #<$6000
    sta temp3
    lda temp3+1
    adc #>$6000
    sta temp3+1              ; temp3 = bitmap address

    lda temp4
    clc
    adc #<$D800
    sta temp2
    lda temp4+1
    adc #>$D800
    sta temp2+1              ; temp2 = color-RAM address

    lda temp4
    clc
    adc #<$4000
    sta temp4
    lda temp4+1
    adc #>$4000
    sta temp4+1              ; temp4 = screen-matrix address
    rts

; draw_ship: draws the ship at column ship_col. The 6 cells' worth of
; bitmap bytes are contiguous per row (temp3+0..23 covers all 3 top-row
; cells, since adjacent C64 cells in a row sit back to back in memory),
; so this is just two 24-byte linear copies rather than 6 separate
; per-cell loops.
draw_ship:
    lda ship_col
    jsr compute_ship_addrs

    ldx #0
    ldy #0
dsh_top:
    lda ship_bitmap,x
    sta (temp3),y
    inx
    iny
    cpy #24
    bne dsh_top

    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1

    ldy #0
dsh_bottom:
    lda ship_bitmap,x
    sta (temp3),y
    inx
    iny
    cpy #24
    bne dsh_bottom

    lda #SHIP_MATRIX_BYTE
    ldy #0
    sta (temp4),y
    ldy #1
    sta (temp4),y
    ldy #2
    sta (temp4),y
    ldy #40
    sta (temp4),y
    ldy #41
    sta (temp4),y
    ldy #42
    sta (temp4),y

    lda #SHIP_COLORRAM_BYTE
    ldy #0
    sta (temp2),y
    ldy #1
    sta (temp2),y
    ldy #2
    sta (temp2),y
    ldy #40
    sta (temp2),y
    ldy #41
    sta (temp2),y
    ldy #42
    sta (temp2),y
    rts

; erase_ship: blanks the ship's current 6 cells back to plain star-field
; background (bitmap 0, screen-matrix/color-RAM back to clear_screen's
; defaults) - any star that happened to be under the ship is lost rather
; than composited back in, an accepted simplification for this pass.
erase_ship:
    lda ship_col
    jsr compute_ship_addrs

    lda #0
    ldy #0
esh_top:
    sta (temp3),y
    iny
    cpy #24
    bne esh_top

    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1

    lda #0
    ldy #0
esh_bottom:
    sta (temp3),y
    iny
    cpy #24
    bne esh_bottom

    lda #$73
    ldy #0
    sta (temp4),y
    ldy #1
    sta (temp4),y
    ldy #2
    sta (temp4),y
    ldy #40
    sta (temp4),y
    ldy #41
    sta (temp4),y
    ldy #42
    sta (temp4),y

    lda #4
    ldy #0
    sta (temp2),y
    ldy #1
    sta (temp2),y
    ldy #2
    sta (temp2),y
    ldy #40
    sta (temp2),y
    ldy #41
    sta (temp2),y
    ldy #42
    sta (temp2),y
    rts

; clear_screen: blanks the bitmap and resets screen-matrix/color RAM to
; the star field's 3 background colors (see STARS.asm) - shared by the
; boot-time title setup and by the transition into the game, since both
; need to start from the same blank state.
clear_screen:
    ; Clear the full bitmap (8000 bytes, 32 pages - a little more than
    ; needed, $6000-$7FFF is exactly 8K).
    lda #<$6000
    sta temp2
    lda #>$6000
    sta temp2+1
    ldx #32
    lda #0
clear_bitmap_page:
    ldy #0
clear_bitmap_byte:
    sta (temp2),y
    iny
    bne clear_bitmap_byte
    inc temp2+1
    dex
    bne clear_bitmap_page

    ; Screen-matrix (1000 bytes, rounded up to 4 pages): default
    ; background cell hi-nibble=7 (yellow), lo-nibble=3 (cyan) - 2 of the
    ; moving star field's 3 colors; the 3rd (color RAM low-nibble) is set
    ; below.
    lda #<$4000
    sta temp2
    lda #>$4000
    sta temp2+1
    ldx #4
    lda #$73
clear_screenmatrix_page:
    ldy #0
clear_screenmatrix_byte:
    sta (temp2),y
    iny
    bne clear_screenmatrix_byte
    inc temp2+1
    dex
    bne clear_screenmatrix_page

    lda #<$D800
    sta temp2
    lda #>$D800
    sta temp2+1
    ldx #4
    lda #4                ; magenta/purple - the star field's 3rd color
                        ; (C64 color 5 is green, not magenta - that was a
                        ; mix-up with the BBC's own palette numbering)
clear_colorram_page:
    ldy #0
clear_colorram_byte:
    sta (temp2),y
    iny
    bne clear_colorram_byte
    inc temp2+1
    dex
    bne clear_colorram_page
    rts

; ROUT3.asm references this during the unfinished game path.
process_demo:
    rts

; --- Level-number flags, bottom-left corner (rows 23-24) - NOT a lives
; display (that's the separate icon below, bottom-right): FLAGS.asm's
; flagson draws this from `temp` = curwave+1, i.e. the wave/level number,
; broken into batches of 10, then 5, then however many 1s are left over
; (see flagson's flag0/flag1/flag2 dispatch, which picks flaggra block
; 0/27/54 accordingly) - like a tally, not a fixed "3 lives" icon set.
; flaggra holds all 3 variants (27 bytes each): block 1 (X=0, "x10"),
; block 2 (X=27, "x5"), block 3 (X=54, "x1" - the one decoded and drawn
; here). Decoded from the REAL BBC source, not sampled from a screenshot
; (addres/addres1 640 bytes apart = one MODE 2 character row, confirmed
; against the Advanced User Guide's Appendix F memory map; flagson's Y
; indices address 4 consecutive 2-pixel-wide byte-columns within that
; row, each byte decoded with the confirmed bit format):
;   . R . . . . . .   (R=red pole, M=magenta body, B=blue stripe)
;   . R M . . . . .
;   . R M M . . . .
;   . R M B M . . .
;   . R M B M M . .
;   . R M B M M M .
;   . R M B M M . .
;   . R M B M . . .
;   . R M M . . . .
;   . R M . . . . .
;   . R . . . . . .   (x6 rows - bare pole)
; This game has no wave/level advancement yet (no aliens, no scoring),
; so level_ones is just a fixed placeholder for now and the x10/x5
; batch icons - needed once a level can reach 10 - aren't decoded yet;
; nothing here can exercise them until that exists.
level_ones:
 .byte 1

; draw_level_flags: draws level_ones (0-9) individual "x1" flags side by
; side from the left edge (cols 0,2,4,...), 2 cells each.
draw_level_flags:
    lda level_ones
    beq dlf_done
    sta length              ; length = remaining count (scratch)
    lda #0
    sta temp1                ; temp1 = flag index (scratch) - see the
                              ; save/restore below; draw_one_flag also
                              ; uses temp1, for its own purpose (column)
dlf_loop:
    lda temp1
    pha
    asl a
    jsr draw_one_flag
    pla
    clc
    adc #1
    sta temp1
    dec length
    bne dlf_loop
dlf_done:
    rts

; draw_one_flag: A = starting column of a 2-cell-wide "x1" flag at the
; fixed rows 23-24 (col*8 done as a single byte add - safe since callers
; only ever pass small columns, well under 32).
draw_one_flag:
    sta temp1

    ; bitmap: compute the top-left cell's address once; the other 3
    ; cells are fixed byte offsets from it (+8 = one cell right, +320 =
    ; one row down), not each independently recomputed from col*8.
    lda temp1
    asl a
    asl a
    asl a
    clc
    adc #<($6000+23*40*8)
    sta temp3
    lda #0
    adc #>($6000+23*40*8)
    sta temp3+1
    ldy #0
dof_tl:
    lda flag_top_left,y
    sta (temp3),y
    iny
    cpy #8
    bne dof_tl

    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    ldy #0
dof_tr:
    lda flag_top_right,y
    sta (temp3),y
    iny
    cpy #8
    bne dof_tr

    lda temp3
    clc
    adc #<(320-8)
    sta temp3
    lda temp3+1
    adc #>(320-8)
    sta temp3+1
    ldy #0
dof_bl:
    lda flag_bottom_left,y
    sta (temp3),y
    iny
    cpy #8
    bne dof_bl

    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    ldy #0
dof_br:
    lda flag_bottom_right,y
    sta (temp3),y
    iny
    cpy #8
    bne dof_br

    ; screen-matrix: same idea - one base (+col, no *8 needed, 1 byte/
    ; cell), then +1/+40/+41 for the other 3 cells.
    lda temp1
    clc
    adc #<($4000+23*40)
    sta temp4
    lda #0
    adc #>($4000+23*40)
    sta temp4+1

    lda #$42
    ldy #0
    sta (temp4),y
    lda #$64
    ldy #1
    sta (temp4),y
    lda #$42
    ldy #40
    sta (temp4),y
    lda #$04
    ldy #41
    sta (temp4),y

    ; color-RAM: only the top-left cell ever draws a "11" pixel pattern,
    ; so it's the only one that needs its color-RAM byte set.
    lda temp1
    clc
    adc #<($D800+23*40)
    sta temp2
    lda #0
    adc #>($D800+23*40)
    sta temp2+1
    lda #6
    ldy #0
    sta (temp2),y
    rts

; --- Lives icon, bottom-right corner - decoded from FLAGS.asm's
; shipgra/liveson, NOT the flags above (those are the level number - see
; above) and not the main ship graphic either (that's a different, much
; bigger block - see ship_bitmap). liveson plots shipgra (29 bytes,
; single buffer - only 1 cell-row tall, unlike the 2-row flag) directly:
; "LDY#28 / LDA shipgra,Y:EOR(addres),Y:STA(addres),Y:DEY:BPL" - Y
; indexes shipgra AND the target offset identically, so (unlike the main
; ship's dual-buffer sprite routine) there's no inversion trick here and
; this decodes in direct, non-flipped order. 4 BBC byte-columns (Y0-7,
; 8-15, 16-23, 24-31, the last only 5 bytes long - untouched scanlines
; default to background) = 2 C64 cells wide, 1 tall. Reduces to the same
; white/yellow/cyan palette the main ship uses (its own top color
; frequencies - white 11, cyan 9, yellow 7 - happen to match exactly),
; so it reuses SHIP_MATRIX_BYTE/SHIP_COLORRAM_BYTE rather than defining
; its own. liveson draws these right-to-left (addres -= 32 per icon, one
; per remaining life) - matched here by stepping the column left by 2
; each time, starting from the right edge.
;
; Least certain of the graphics decoded this session: liveson is the
; only single-buffer (not dual-buffer, not the simple direct one-column
; plot bombgra uses) routine of the three, so if this doesn't look right
; in VICE, the buffer/scanline convention here is the first thing to
; re-check.
LIVES_ROW = 23
LIVES_RIGHT_COL = 38

lives_count:
 .byte 3

; Tip-on-top, position confirmed correct, kept - just the tip's own 3
; rows internally reversed (the wide foot was at the very top with the
; narrow stem below it, backwards; now the stem tapers away from the
; body at the top and the foot sits against the body, same 3 rows, same
; place, just reordered).
lives_bitmap_left:
 .byte $03,$01,$0b,$48,$5a,$5f,$5f,$cf
lives_bitmap_right:
 .byte $00,$00,$80,$84,$94,$d4,$d4,$cc

; draw_lives_icons: draws lives_count (0-8ish) icons right to left from
; LIVES_RIGHT_COL, 2 cells apart.
draw_lives_icons:
    lda lives_count
    beq dli_done
    sta length              ; length = remaining count (scratch)
    lda #LIVES_RIGHT_COL
    sta temp1                ; temp1 = column (scratch) - draw_one_lifeicon
                              ; also uses temp1; save/restore across the call
dli_loop:
    lda temp1
    pha
    jsr draw_one_lifeicon
    pla
    sec
    sbc #2
    sta temp1
    dec length
    bne dli_loop
dli_done:
    rts

; draw_one_lifeicon: A = starting column of a 2-cell-wide life icon at
; the fixed LIVES_ROW.
draw_one_lifeicon:
    sta temp1

    ; col*8 as a proper 16-bit value - unlike draw_one_flag (col capped
    ; at 16, safe as a single byte), this is called with columns up to
    ; LIVES_RIGHT_COL=38, and 38*8=304 overflows a byte: the single-byte
    ; version silently dropped the carry, which is why the icons were
    ; landing at the wrong address entirely (not just off by a bit).
    lda temp1
    sta temp3
    lda #0
    sta temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1              ; temp3(word) = col * 8
    lda temp3
    clc
    adc #<($6000+LIVES_ROW*40*8)
    sta temp3
    lda temp3+1
    adc #>($6000+LIVES_ROW*40*8)
    sta temp3+1
    ldy #0
dol_left:
    lda lives_bitmap_left,y
    sta (temp3),y
    iny
    cpy #8
    bne dol_left

    ; right cell is exactly 8 bytes after the left cell - temp3 is
    ; already a correct full word here, so this add can't overflow the
    ; way the from-scratch column computation did above.
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    ldy #0
dol_right:
    lda lives_bitmap_right,y
    sta (temp3),y
    iny
    cpy #8
    bne dol_right

    lda temp1
    clc
    adc #<($4000+LIVES_ROW*40)
    sta temp4
    lda #0
    adc #>($4000+LIVES_ROW*40)
    sta temp4+1
    lda #SHIP_MATRIX_BYTE
    ldy #0
    sta (temp4),y
    ldy #1
    sta (temp4),y

    lda temp1
    clc
    adc #<($D800+LIVES_ROW*40)
    sta temp2
    lda #0
    adc #>($D800+LIVES_ROW*40)
    sta temp2+1
    lda #SHIP_COLORRAM_BYTE
    ldy #0
    sta (temp2),y
    ldy #1
    sta (temp2),y
    rts

; --- Score bar / body text: both just a list of (string, position,
; color) to print with print_bitmap_line, so both are driven off a
; small table instead of repeating the same 8-line "set 4 registers,
; call" block once per string (10 strings between the two of them).
; Positions measured from the reference screenshot directly (col =
; pixel_x/4/4 - /4 to reach true color-pixel units per the letter-width
; cross-check in print_bitmap_line's history, /4 again for cells), not
; carried over from the old per-letter-width assumptions.
;
; Each table is walked with plain ABSOLUTE,X addressing (X = running
; byte offset), not an indirect pointer: (zp),Y addressing needs the
; pointer IN zero page, and zero page is already full (see stardat's
; note in Master-c64.mak.asm) - a table-name-agnostic shared loop would
; need exactly that, so this is 2 small near-identical loops (one per
; table) instead of 1 shared one. X doesn't survive the jsr
; (print_bitmap_line uses it internally), so it's saved to a plain byte
; around the call rather than the stack, just to keep this readable.
dtt_saved_x:
 .byte 0

draw_score_bar:
    ldx #0
dsb_loop:
    lda score_bar_table,x
    sta temp2
    lda score_bar_table+1,x
    sta temp2+1
    lda score_bar_table+2,x
    sta temp3
    lda score_bar_table+3,x
    sta temp3+1
    lda score_bar_table+4,x
    sta temp4
    lda score_bar_table+5,x
    sta temp4+1
    lda score_bar_table+6,x
    sta colour
    stx dtt_saved_x
    jsr print_bitmap_line
    ldx dtt_saved_x
    txa
    clc
    adc #7
    tax
    cpx #(4*7)
    bne dsb_loop
    rts

; K and S are two separate table entries (two separate strings), not one
; "KS" string, so they can have different colors: with the tight sub-
; cell spacing, letters within ONE string can share a cell (see
; print_bitmap_line), which would force them to the same color. Drawing
; them separately, each starting fresh at color-pixel offset 0, keeps
; their own spacing unchanged - S just starts 2 cells after K (K's own
; span), the minimum gap that avoids sharing a cell, not extra space
; added.
draw_body_text:
    ldx #0
dbt_loop:
    lda body_text_table,x
    sta temp2
    lda body_text_table+1,x
    sta temp2+1
    lda body_text_table+2,x
    sta temp3
    lda body_text_table+3,x
    sta temp3+1
    lda body_text_table+4,x
    sta temp4
    lda body_text_table+5,x
    sta temp4+1
    lda body_text_table+6,x
    sta colour
    stx dtt_saved_x
    jsr print_bitmap_line
    ldx dtt_saved_x
    txa
    clc
    adc #7
    tax
    cpx #(6*7)
    bne dbt_loop
    rts

score_bar_table:
    .word str_scr,      $6000+3*8,          $4000+3
    .byte 4                                              ; magenta
    .word str_score0,   $6000+18*8,         $4000+18
    .byte 7                                              ; yellow
    .word str_hi,       $6000+21*8,         $4000+21
    .byte 4
    .word str_hiscore,  $6000+28*8,         $4000+28
    .byte 7

body_text_table:
    .word str_bykevin,  $6000+(6*40+8)*8,   $4000+6*40+8
    .byte 3                                              ; cyan
    .word str_press,    $6000+(16*40+6)*8,  $4000+16*40+6
    .byte 5                                              ; green
    .word str_toplay,   $6000+(18*40+15)*8, $4000+18*40+15
    .byte 5
    .word str_superior, $6000+(21*40+7)*8,  $4000+21*40+7
    .byte 4                                              ; magenta
    .word str_k,        $6000+(24*40+35)*8, $4000+24*40+35
    .byte 3                                              ; cyan
    .word str_s,        $6000+(24*40+37)*8, $4000+24*40+37
    .byte 2                                              ; red

; Flag icon shifted down 2 scanlines from the unclipped 16-row design (top
; two scanlines of the top cell go blank; the bottom two scanlines of the
; bare pole - which is a uniform repeat of the same pole byte - simply fall
; off the bottom of row 24, the last visible screen row, so the screen edge
; does the cropping instead of an arbitrary byte count).
flag_top_left:
    .byte $00,$00,$20,$24,$25,$27,$27,$27
flag_top_right:
    .byte $00,$00,$00,$00,$00,$80,$A0,$A8
flag_bottom_left:
    .byte $27,$27,$25,$24,$20,$20,$20,$20
flag_bottom_right:
    .byte $A0,$80,$00,$00,$00,$00,$00,$00

; print_bitmap_line: prints a $FF-terminated string of glyph codes (see
; the letter/digit code scheme above str_scr below) as MULTICOLOR bitmap
; glyphs at true BBC letter pitch (measured from the reference: gap is
; ~25% of glyph width, i.e. ~1 color-pixel for a 5-wide glyph - not the
; 3-pixel gap a naive 2-full-cells-per-letter layout gives). temp2 =
; source string ptr, temp3 = dest bitmap ptr (the cell containing this
; letter's first color-pixel), temp4 = matching dest screen-matrix ptr,
; colour = plain 0-15 foreground value.
;
; A 6-color-pixel advance for a 5-wide glyph (1px gap) doesn't land on
; cell boundaries (cells are 4 color-pixels wide), so consecutive
; letters alternate which color-pixel offset they start at within a
; cell - 0, then 2, then 0, then 2... (6 mod 4 = 2). At offset 2, a
; letter's first 2 color-pixels land in the SAME cell the previous
; letter's last color-pixel used, so that shared cell's byte is built
; from both letters' contributions via ORA, not overwritten via STA -
; each letter only ever sets new bits (background is 0), never clears
; the other's. temp1 tracks the alternating state (0/1) across the
; whole string, reset to 0 (offset 0) at the start of each call.
print_bitmap_line:
    lda #0
    sta temp1            ; 0 = next letter at offset 0, 1 = offset 2
pbl_char:
    ldy #0
    lda (temp2),y
    cmp #$FF
    bne pbl_not_done
    jmp pbl_done
pbl_not_done:
    tax                  ; X = glyph code
    lda #0
    sta screen+1
    txa
    asl a
    rol screen+1
    asl a
    rol screen+1
    asl a
    rol screen+1
    clc
    adc #<spfont
    sta screen
    lda screen+1
    adc #>spfont
    sta screen+1

    lda temp1
    bne pbl_offset2

    lda #0
    sta length
pbl_rowloop0:
    ldy length
    lda (screen),y
    lsr a
    lsr a
    lsr a
    tax
    lda LEFT_TABLE,x
    pha
    lda RIGHT_TABLE,x
    tax                  ; X = right-byte result
    ldy length
    pla                  ; A = left-byte result
    ora (temp3),y
    sta (temp3),y
    lda length
    clc
    adc #8
    tay
    txa
    ora (temp3),y
    sta (temp3),y
    inc length
    lda length
    cmp #8
    bne pbl_rowloop0
    jmp pbl_after_rows

pbl_offset2:
    lda #0
    sta length
pbl_rowloop2:
    ldy length
    lda (screen),y
    lsr a
    lsr a
    lsr a
    tax
    lda LEFT_TABLE_2,x
    pha
    lda RIGHT_TABLE_2,x
    tax
    ldy length
    pla
    ora (temp3),y
    sta (temp3),y
    lda length
    clc
    adc #8
    tay
    txa
    ora (temp3),y
    sta (temp3),y
    inc length
    lda length
    cmp #8
    bne pbl_rowloop2

pbl_after_rows:
    lda colour
    ldy #0
    sta (temp4),y
    iny
    sta (temp4),y

    inc temp2
    bne pbl_src_ok
    inc temp2+1
pbl_src_ok:
    lda temp1
    bne pbl_was_offset2

    ; was offset 0 -> next letter shares our 2nd cell (offset 2);
    ; advance by 1 cell only
    clc
    lda temp3
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    clc
    lda temp4
    adc #1
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1
    lda #1
    sta temp1
    jmp pbl_char

pbl_was_offset2:
    ; next letter starts fresh (offset 0); advance past both our cells
    clc
    lda temp3
    adc #16
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    clc
    lda temp4
    adc #2
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1
    lda #0
    sta temp1
    jmp pbl_char

pbl_done:
    rts

; blit_title_char: like print_bitmap_line's per-character work, but for
; one 3x2-cell (double-width AND double-height) title letter - double
; width because a letter doubled in height only, not width, would be
; distorted (tall and thin) rather than uniformly bigger. A = spfont
; glyph code, temp3 = dest bitmap TOP-LEFT cell ptr, temp4 = dest
; screen-matrix TOP-LEFT cell ptr, colour = plain 0-15 foreground value.
; Each source row maps via TITLE_B0/B1/B2 (each of the glyph's 5 real
; columns doubled to 2 color-pixels, matching the 2x vertical doubling -
; 10 color-pixels of glyph + a 2-pixel gap = 12 = exactly 3 cells, no
; remainder, so unlike body text this needs no sub-cell offset
; alternation). Each row's 3 bytes are written twice (rows 0-3 into the
; top cells, rows 4-7 into the bottom cells 320 bitmap-bytes / 40
; screen-matrix-bytes below - one screen row down). Leaves temp3/temp4
; pointing at the bottom-left cell on return; callers must recompute
; fresh for the next letter, not rely on them afterward.
blit_title_char:
    tax
    lda #0
    sta screen+1
    txa
    asl a
    rol screen+1
    asl a
    rol screen+1
    asl a
    rol screen+1
    clc
    adc #<spfont
    sta screen
    lda screen+1
    adc #>spfont
    sta screen+1

    lda colour
    ldy #0
    sta (temp4),y
    iny
    sta (temp4),y
    iny
    sta (temp4),y

    lda #0
    sta length
btc_top:
    ldy length
    lda (screen),y
    lsr a
    lsr a
    lsr a
    tax
    lda TITLE_B1,x
    pha
    lda TITLE_B0,x
    pha
    lda TITLE_B2,x
    tax                  ; X = B2 result
    lda length
    asl a
    tay                  ; Y = 2*length (cell 0)
    pla                  ; A = B0 result
    sta (temp3),y
    iny
    sta (temp3),y
    lda length
    asl a
    clc
    adc #8
    tay                  ; Y = 2*length+8 (cell 1)
    pla                  ; A = B1 result
    sta (temp3),y
    iny
    sta (temp3),y
    lda length
    asl a
    clc
    adc #16
    tay                  ; Y = 2*length+16 (cell 2)
    txa                  ; A = B2 result
    sta (temp3),y
    iny
    sta (temp3),y
    inc length
    lda length
    cmp #4
    bne btc_top

    ; advance to bottom cells (320 bitmap bytes / 40 screen-matrix bytes)
    clc
    lda temp3
    adc #$40
    sta temp3
    lda temp3+1
    adc #$01
    sta temp3+1
    clc
    lda temp4
    adc #40
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1

    lda colour
    ldy #0
    sta (temp4),y
    iny
    sta (temp4),y
    iny
    sta (temp4),y

    lda #4
    sta length
btc_bottom:
    ldy length
    lda (screen),y
    lsr a
    lsr a
    lsr a
    tax
    lda TITLE_B1,x
    pha
    lda TITLE_B0,x
    pha
    lda TITLE_B2,x
    tax                  ; X = B2 result
    lda length
    sec
    sbc #4
    asl a
    tay                  ; Y = 2*(length-4) (cell 0)
    pla                  ; A = B0 result
    sta (temp3),y
    iny
    sta (temp3),y
    lda length
    sec
    sbc #4
    asl a
    clc
    adc #8
    tay                  ; cell 1
    pla                  ; A = B1 result
    sta (temp3),y
    iny
    sta (temp3),y
    lda length
    sec
    sbc #4
    asl a
    clc
    adc #16
    tay                  ; cell 2
    txa                  ; A = B2 result
    sta (temp3),y
    iny
    sta (temp3),y
    inc length
    lda length
    cmp #8
    bne btc_bottom
    rts

; Glyph codes: letter = 10 + alphabet position (A=11..Z=36), digit = 1 +
; digit value (0=1..9=10), 0 = blank/space. Each string ends with $FF.
str_scr:
    .byte 29,13,28,$FF                              ; SCR
str_score0:
    .byte 1,$FF                                     ; "0" (placeholder)
str_hi:
    .byte 18,19,$FF                                 ; HI
str_hiscore:
    .byte 4,1,1,1,1,$FF                             ; "30000" (placeholder)
str_bykevin:
    .byte 12,35,0,21,15,32,19,24,0,15,14,33,11,28,14,29,$FF   ; BY KEVIN EDWARDS
str_press:
    .byte 26,28,15,29,29,0,29,26,11,13,15,0,25,28,0,16,19,28,15,$FF ; PRESS SPACE OR FIRE
str_toplay:
    .byte 30,25,0,26,22,11,35,$FF                   ; TO PLAY
str_superior:
    .byte 29,31,26,15,28,19,25,28,0,29,25,16,30,33,11,28,15,$FF ; SUPERIOR SOFTWARE
str_k:
    .byte 21,$FF                                    ; K
str_s:
    .byte 29,$FF                                    ; S

; LEFT_TABLE/RIGHT_TABLE: indexed by a source glyph row's top 5 bits (its
; 5 real pixel columns, srcbyte>>3, giving an index 0-31), giving the
; left-half and right-half destination bytes for MULTICOLOR bitmap mode,
; for a letter starting at color-pixel offset 0 within its cell. Each of
; the 5 real source columns maps to exactly one 2-bit color-pixel (code
; 10 = screen-matrix low nibble = the text's foreground color; code 00 =
; background) at NATIVE width - no stretching. A cell holds 4 color-
; pixels (2 bits x 4 = 8 bits = the cell's 1 byte for that row): the left
; cell's 4 slots hold source columns 0-3, the right cell's first slot
; holds column 4, leaving that cell's last 3 slots for print_bitmap_line
; to fill with the NEXT letter (see LEFT_TABLE_2/RIGHT_TABLE_2 below) -
; true BBC letter spacing doesn't land on this table alone.
LEFT_TABLE:
    .byte $00,$00,$02,$02,$08,$08,$0A,$0A
    .byte $20,$20,$22,$22,$28,$28,$2A,$2A
    .byte $80,$80,$82,$82,$88,$88,$8A,$8A
    .byte $A0,$A0,$A2,$A2,$A8,$A8,$AA,$AA
RIGHT_TABLE:
    .byte $00,$80,$00,$80,$00,$80,$00,$80
    .byte $00,$80,$00,$80,$00,$80,$00,$80
    .byte $00,$80,$00,$80,$00,$80,$00,$80
    .byte $00,$80,$00,$80,$00,$80,$00,$80

; LEFT_TABLE_2/RIGHT_TABLE_2: same idea, for a letter starting at
; color-pixel offset 2 (the alternate case - see print_bitmap_line's
; comment on why offsets 0/2 alternate). LEFT_TABLE_2's slots 0-1 are
; always 0 (that cell's first 2 slots belong to the PREVIOUS letter,
; combined in via ORA, not this table) and source columns 0-1 land in
; its slots 2-3; RIGHT_TABLE_2 holds source columns 2-4 in slots 0-2,
; leaving slot 3 as this letter's 1-color-pixel trailing gap.
LEFT_TABLE_2:
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $02,$02,$02,$02,$02,$02,$02,$02
    .byte $08,$08,$08,$08,$08,$08,$08,$08
    .byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
RIGHT_TABLE_2:
    .byte $00,$08,$20,$28,$80,$88,$A0,$A8
    .byte $00,$08,$20,$28,$80,$88,$A0,$A8
    .byte $00,$08,$20,$28,$80,$88,$A0,$A8
    .byte $00,$08,$20,$28,$80,$88,$A0,$A8

; TITLE_B0/B1/B2: for the title only (blit_title_char). Same 5-bit source
; index as the tables above, but each of the 5 real columns is doubled
; to 2 color-pixels (not 1), matching the title's 2x vertical doubling -
; 10 color-pixels of glyph + a 2-pixel gap = 12 = exactly 3 cells' worth,
; one table per cell.
TITLE_B0:
    .byte $00,$00,$00,$00,$00,$00,$00,$00
    .byte $0A,$0A,$0A,$0A,$0A,$0A,$0A,$0A
    .byte $A0,$A0,$A0,$A0,$A0,$A0,$A0,$A0
    .byte $AA,$AA,$AA,$AA,$AA,$AA,$AA,$AA
TITLE_B1:
    .byte $00,$00,$0A,$0A,$A0,$A0,$AA,$AA
    .byte $00,$00,$0A,$0A,$A0,$A0,$AA,$AA
    .byte $00,$00,$0A,$0A,$A0,$A0,$AA,$AA
    .byte $00,$00,$0A,$0A,$A0,$A0,$AA,$AA
TITLE_B2:
    .byte $00,$A0,$00,$A0,$00,$A0,$00,$A0
    .byte $00,$A0,$00,$A0,$00,$A0,$00,$A0
    .byte $00,$A0,$00,$A0,$00,$A0,$00,$A0
    .byte $00,$A0,$00,$A0,$00,$A0,$00,$A0

; Real spfont glyph codes for GALAFORCE's 9 letters in order (letter code
; = 10 + alphabet position; A repeats, drawn from the same code twice).
title_letter_codes:
    .byte 17,11,22,11,16,25,28,13,15 ; G A L A F O R C E
colour_title:
    .byte 2                          ; red
