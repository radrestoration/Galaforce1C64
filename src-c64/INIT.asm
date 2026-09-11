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
    jsr draw_title_screen
    jsr star_init

; --- Title / high-score / demo cycle: matches INIT.asm's wait_for_space/
; hsclp/into_demo - title waits up to 256 frames for SPACE or RETURN; on
; timeout, shows the high-score table and waits up to 256 MORE frames; on
; a second timeout, starts the demo. A keypress during either wait starts
; a normal game. Frame counting uses the same "INC, BNE loops, falls
; through on wraparound" trick the BBC source uses (counter is a byte;
; BEQ after 256 increments is a natural wraparound check, no separate
; compare needed) - see title_frame_count. One raster-poll per frame
; (line 250 - below the visible 200 lines, so a single 8-bit compare
; against $D012 is enough) throughout. ---
; title_wait_loop is entered fresh at boot (lives_count/level_ones/score
; are already at their correct defaults then) AND re-entered after a
; game (via check_escape_key or a real game over) - now that gameplay
; mutates lives_count/level_ones/score_digits, they need resetting here
; too, or show_high_scores (which draws them) would show whatever the
; just-finished game ended on instead of the attract-mode defaults.
title_wait_loop:
    lda #3
    sta lives_count
    lda #1
    sta level_ones
    lda #0
    sta score_digits
    sta score_digits+1
    sta score_digits+2
    sta score_digits+3
    lda #1
    sta score_glyphs
    sta score_glyphs+1
    sta score_glyphs+2
    sta score_glyphs+3

    lda #0
    sta title_frame_count
twl_loop:
    lda #250
twl_wait_raster:
    cmp $D012
    bne twl_wait_raster
    jsr movestars
    jsr refresh_music
    jsr check_space_key    ; TEMPORARY: space -> demo directly, see the
    beq start_demo           ; note above check_space_key
    jsr check_return_key
    beq manual_game_start
    inc title_frame_count
    bne twl_loop

; --- High scores: same idle-timeout structure as the title wait above,
; on its own fresh screen (own star field too, matching srlp/movestars
; being called throughout the BBC's hsclp loop, not just the title). ---
show_high_scores:
    jsr clear_screen
    jsr draw_high_score_table
    jsr draw_score_bar
    jsr draw_ks_indicator
    jsr draw_level_flags
    jsr draw_lives_icons
    jsr star_init
    lda #0
    sta title_frame_count
hs_loop:
    lda #250
hs_wait_raster:
    cmp $D012
    bne hs_wait_raster
    jsr movestars
    jsr refresh_music
    jsr check_space_key    ; TEMPORARY: space -> demo directly, see the
    beq start_demo           ; note above check_space_key
    jsr check_return_key
    beq manual_game_start
    inc title_frame_count
    bne hs_loop

; --- Demo: marks demo_flag and drops straight into game_start - real
; input is simulated instead of read (see process_demo, demo_process_fire,
; and handle_ship_input's demo branch), so this plays itself the same way
; a keypress-started game runs, just driven by demo_direction instead of
; the keyboard. into_demo's real starting-wave logic (rand() AND 7)
; belongs here once there's more than the fixed wave-0 spawn table
; (init_alien_wave) to select from. ---
start_demo:
    lda #1
    sta demo_flag
    lda #255                ; matches INIT.asm's own "LDX#&FF:STXdemo_count"
    sta demo_count           ; - forces process_demo to pick a fresh random
    jmp game_start            ; direction/count on its first call, not carry
                               ; over whatever demo_count was left at before

; manual_game_start: a keypress during the title or high-score wait -
; real play, not demo. game_start itself doesn't touch demo_flag (it's
; also entered from start_demo, which needs it left set to 1).
manual_game_start:
    lda #0
    sta demo_flag

; --- Game start: wipe the screen, fresh stars, drop the ship in at its
; start column, and draw the score bar / level flags / lives icon on the
; now-blank game screen (clear_screen wiped them along with everything
; else). ---
game_start:
    jsr clear_screen
    jsr star_init

    lda #3
    sta lives_count
    lda #1
    sta level_ones
    lda #0
    sta c64_curwave
    sta game_state
    sta score_digits
    sta score_digits+1
    sta score_digits+2
    sta score_digits+3
    lda #1
    sta score_glyphs
    sta score_glyphs+1
    sta score_glyphs+2
    sta score_glyphs+3

    jsr draw_score_bar
    jsr draw_ks_indicator
    jsr draw_level_flags
    jsr draw_lives_icons
    jsr init_alien_wave
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

    lda #0                  ; tune 0 - placeholder until real tune data exists
    jsr start_tune

game_loop:
    lda #250
gl_wait_raster:
    cmp $D012
    bne gl_wait_raster
    jsr movestars
    jsr refresh_music
    jsr check_escape_key
    beq game_loop_escape

    lda game_state
    cmp #GS_SHIP_EXPLODING
    beq gl_exploding

    jsr process_demo
    jsr handle_ship_input
    jsr fire_bullet_if_requested
    jsr demo_process_fire
    jsr move_bullets
    jsr move_alien_bullets
    jsr process_alien_spawns
    jsr alien_move_tick
    jsr check_bullet_alien_collisions
    jsr check_alien_bullet_ship_collision
    jsr check_alien_ship_collision

    ; A collision just above may have called ship_crash, which sets
    ; game_state to GS_SHIP_EXPLODING mid-frame - skip check_wave_clear in
    ; that case (it would otherwise see the just-cleared alien pool as a
    ; finished wave and advance/repopulate it while the ship's explosion
    ; is still playing, before it's even respawned).
    lda game_state
    cmp #GS_PLAYING
    bne game_loop_no_wave_check
    jsr check_wave_clear
game_loop_no_wave_check:
    jmp game_loop
gl_exploding:
    jsr ship_explode_tick_throttled
    lda game_state
    cmp #GS_GAME_OVER
    beq game_loop_escape
    jmp game_loop
game_loop_escape:
    jmp title_wait_loop

; title_frame_count was previously declared inline between game_start's
; last jsr and game_loop:, with no branch/jump separating them - since
; game_start falls straight through into game_loop (no rts), the CPU was
; executing this byte's VALUE (0) as an instruction on every single
; entry into gameplay: opcode $00 is BRK, a software interrupt that
; fires unconditionally (the SEI at the top of exec masks hardware IRQs,
; not BRK) and jumps through the IRQ/BRK vector - landing in KERNAL code
; never written to expect it. This is very likely the real cause of the
; "freezes immediately on entering gameplay" reports. Relocated here,
; well clear of any fall-through path (this is only ever reached via the
; jmp above, never by falling off the end of something).
title_frame_count:
 .byte 0

; check_escape_key: RUN/STOP, checked each frame in game_loop to bail
; back to the title - a TEMPORARY stand-in (you flagged the real key as
; probably different, TBD) for whatever quits play on the real hardware.
; Returns with the Z flag set (BEQ taken by the caller) if held, same
; convention as check_start_key.
check_escape_key:
    lda #$7F               ; clear bit7: select column 7 (same column as SPACE)
    sta $DC00
    lda $DC01
    and #$80                 ; row bit 7 = RUN/STOP
    rts

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

; check_space_key/check_return_key: same column/row masks as
; check_start_key, split apart so title_wait_loop/show_high_scores can
; currently tell SPACE and RETURN apart - TEMPORARY: for now SPACE jumps
; straight into the demo and RETURN starts a real game, so the demo
; doesn't need the full idle-timeout wait to reach for testing.
; check_start_key above is unused while this is wired in, not removed -
; this is meant to come back out once the demo's been looked at.
check_space_key:
    lda #$7F              ; clear bit7: select column 7 (SPACE's column)
    sta $DC00
    lda $DC01
    and #$10                ; row bit 4 = SPACE
    rts

check_return_key:
    lda #$FE              ; clear bit0: select column 0 (RETURN's column)
    sta $DC00
    lda $DC01
    and #$02                ; row bit 1 = RETURN
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
    bcs hsi_slowdown_ok    ; routine's grown too big for a direct branch
    jmp hsi_done            ; to hsi_done, so invert-and-jump instead
hsi_slowdown_ok:
    lda #0
    sta ship_move_count

    ; Demo mode reads no keys at all (ROUT3.asm's ok_to_move: real input
    ; is entirely skipped via "BITdemo_flag:BPLmanual_control" when demo
    ; is active) - it's driven purely by demo_direction (see process_demo)
    ; and is left/right only, same as the source (the up/down half of its
    ; movement decision, temp3+1, is never touched in the demo branch).
    lda demo_flag
    bne hsi_demo_move

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

; "Up" accepts either of two keys, both in C64 keyboard column 6:
; ";" (bit2) - the physically correct key on a real C64 keyboard, and
; "=" (bit5) - where VICE's default keymap tends to land a host
; apostrophe press, going by physical keyboard position (right of ";"
; on both a PC and a C64 keyboard).
hsi_check_up:
    lda #$BF               ; clear bit6: select column 6 (";" and "="'s column)
    sta $DC00
    lda $DC01
    and #$04                  ; row bit 2 = ";"
    beq hsi_up_pressed
    lda $DC01
    and #$20                  ; row bit 5 = "="
    bne hsi_check_down
hsi_up_pressed:
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

    jmp hsi_done

; hsi_demo_move: demo_direction's sign is the whole decision (BBC checks
; it with BMI/BPL; bit7 here is the same check) - negative drifts left,
; positive drifts right. Bounces off either edge by flipping
; demo_direction instead of moving, matching ROUT3.asm's
; "ship_hasnt_moved: EOR#&80" (there, that's reached when xycalc finds
; the ship's new screen position unchanged; here, the clamp itself is
; the "didn't move" signal, so the flip happens at the same spot).
hsi_demo_move:
    lda demo_direction
    bmi hsi_demo_left
    lda ship_col
    cmp #SHIP_MAX_COL
    beq hsi_demo_flip
    jsr erase_ship
    inc ship_col
    jsr draw_ship
    jmp hsi_done
hsi_demo_left:
    lda ship_col
    cmp #SHIP_MIN_COL
    beq hsi_demo_flip
    jsr erase_ship
    dec ship_col
    jsr draw_ship
    jmp hsi_done
hsi_demo_flip:
    lda demo_direction
    eor #$80
    sta demo_direction

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
; Pool size matches CONST.asm's mymaxbull (3), not an arbitrary "a few" -
; that's the real BBC cap on simultaneous player bullets. Movement is a
; full cell-row per tick (matching BOMBS1.asm's own "SBC #8" - it moves
; 8 BBC scanlines, i.e. one row, per game frame too), which is simple:
; no sub-cell/cell-boundary bookkeeping needed at all, just a plain row
; counter and compute_bullet_addr's row*40+col*8 math.
BULLET_COUNT = 3

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
; fire_bullet_if_requested: the manual (real key) path - edge-detects
; RETURN, then calls spawn_player_bullet. During demo, demo_process_fire
; (see below) calls spawn_player_bullet directly on its own timer,
; bypassing the key check entirely - matches BOMBS1.asm's own
; "LDAdemo_flag:BMIbomb11" (demo mode skips the key/joystick read and
; just tries to fire whenever off cooldown).
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
    jsr spawn_player_bullet
fbr_done:
    rts

; spawn_player_bullet: finds the first free slot in the player bullet
; pool and fires into it, or does nothing if the pool's full. Preserves
; nothing in particular - callers don't rely on any register after.
spawn_player_bullet:
    ldx #0
spb_find_slot:
    lda bullet_active,x
    beq spb_spawn
    inx
    cpx #BULLET_COUNT
    bne spb_find_slot
    rts                      ; pool is full - drop this shot
spb_spawn:
    lda #1
    sta bullet_active,x
    ; Spawn one row ABOVE the ship, never in the ship's own cell: that
    ; cell has the ship's own screen-matrix/color-RAM override (see
    ; SHIP_MATRIX_BYTE), so a bullet XOR'd in there shows the wrong
    ; colors, and worse, erase_ship/draw_ship overwrite it outright
    ; (not XOR) whenever the ship moves, desyncing the bullet's XOR
    ; parity permanently - this was the "stuck single pixel" bug.
    lda ship_row
    beq spb_row_zero
    sec
    sbc #1
    jmp spb_row_set
spb_row_zero:
    lda #0
spb_row_set:
    sta bullet_row,x
    lda ship_col
    clc
    adc #1                   ; middle of the ship's 3 cells
    sta bullet_col,x
    jsr draw_bullet_x
    lda #0                  ; sound 0 - placeholder until real effect data exists
    jsr mk_sound
    rts

; move_bullets: advances every active bullet one cell-row up per call,
; deactivating instead of wrapping once it passes row 0 (compare
; movestars, which respawns - bullets just vanish off the top). BBC
; moves bullets a full row EVERY frame, untouched - our own throttle
; was slowing that down 8x just to make it easier to eyeball; brought
; down to a still-visible-but-real 3x instead of the untouched 1x since
; there's nothing on screen to shoot at yet to judge full speed against
; (revisit once aliens exist - phase 5). Colors (currently substituted
; white -> magenta, red -> cyan, per the 3-non-black-per-cell budget -
; see the bullet_bitmap note above) are also accepted "for now", not
; final - revisit those too when picking the game's real palette.
BULLET_MOVE_SLOWDOWN = 3
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

    ; A bullet flies from the ship all the way to row 0 on every single
    ; shot, so unlike aliens/stars (kept off row 3/23/24 by not letting
    ; them go there at all) a bullet genuinely has to cross row 3 (the
    ; score bar) - it's XOR-drawn, and print_bitmap_line's text there is
    ; ORA-only/never erased, so a bullet whose XOR toggle lands mid-
    ; transit at the exact frame a score redraw happens can bake a wrong
    ; bit in permanently (this was the remaining source of "still
    ; corrupted" after the star/alien fixes - those closed the
    ; continuous-exposure paths, not the fast one-frame flyby). Fix:
    ; just don't XOR-draw a bullet while it's on a protected row - one
    ; invisible frame passing through is a fair trade for never
    ; touching that memory at all. is_row_protected is STARS.asm's same
    ; row-3/23/24 check already used for stars - reused here rather than
    ; duplicated.
    lda bullet_row,x
    sta temp1
    jsr is_row_protected
    lda star_row_protected
    bne mbs_erase_skip
    jsr draw_bullet_x         ; erase at the current position
mbs_erase_skip:
    lda bullet_row,x
    beq mbs_deactivate
    dec bullet_row,x

    lda bullet_row,x
    sta temp1
    jsr is_row_protected
    lda star_row_protected
    bne mbs_next
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

; --- Alien bullets: a second, separate pool sized to CONST.asm's
; almaxbull (6), mirroring the player pool above but moving down instead
; of up. Nothing spawns into this yet - aliens don't fire until they
; exist (see the plan's phase 5) - but the pool, draw and move mechanics
; are built now so alien work doesn't have to bolt bullets on afterward.
; move_alien_bullets is already called from game_loop; with every slot
; inactive it's just a cheap no-op pass over 6 flags.
;
; The graphic below is a PLACEHOLDER, not a decode: BOMBS2.asm's real
; alien bomb (.albomb, 10 bytes) is plotted through xycalc2 at an
; arbitrary (non cell-aligned) pixel row, and its last 2 bytes land in
; the scanlines of the NEXT cell down - properly decoding that needs
; xycalc2's addressing worked out first, which isn't needed until
; something actually fires one of these. Reusing the player bullet's
; shape here is an explicit stand-in, not a guess at the real graphic.
ALIEN_BULLET_COUNT = 6

alien_bullet_active:
 .res ALIEN_BULLET_COUNT
alien_bullet_row:
 .res ALIEN_BULLET_COUNT
alien_bullet_col:
 .res ALIEN_BULLET_COUNT

; compute_alien_bullet_addr: X = alien-bullet slot index. Same row*40+
; col*8 math as compute_bullet_addr, kept as its own copy rather than
; parameterized - 6502 has no cheap way to pass "which array" into a
; shared routine without self-modifying code, same tradeoff already
; noted for draw_score_bar/draw_body_text's table loops.
compute_alien_bullet_addr:
    lda #0
    sta temp3
    sta temp3+1
    lda alien_bullet_row,x
    beq caba_row_done
    sta length
caba_row_loop:
    lda temp3
    clc
    adc #40
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    dec length
    bne caba_row_loop
caba_row_done:
    lda temp3
    clc
    adc alien_bullet_col,x
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    lda temp3
    clc
    adc #<$6000
    sta temp3
    lda temp3+1
    adc #>$6000
    sta temp3+1
    rts

; draw_alien_bullet_x: X = alien-bullet slot index. XOR-plots the
; placeholder shape at that slot's current cell - also its own erase,
; same as draw_bullet_x. Preserves X.
draw_alien_bullet_x:
    jsr compute_alien_bullet_addr
    ldy #0
dabx_loop:
    lda bullet_bitmap,y
    eor (temp3),y
    sta (temp3),y
    iny
    cpy #8
    bne dabx_loop
    rts

; move_alien_bullets: mirrors move_bullets, downward - advances every
; active alien bullet one cell-row per call, deactivating past row 24
; (the last row) instead of wrapping.
ALIEN_BULLET_MOVE_SLOWDOWN = 3
alien_bullet_move_count:
 .byte 0

move_alien_bullets:
    inc alien_bullet_move_count
    lda alien_bullet_move_count
    cmp #ALIEN_BULLET_MOVE_SLOWDOWN
    bcc mabs_rts
    lda #0
    sta alien_bullet_move_count

    ldx #0
mabs_loop:
    lda alien_bullet_active,x
    beq mabs_next

    ; Same reasoning as move_bullets above - an alien bullet reaching
    ; row 23/24 on its way to deactivating at the bottom would XOR
    ; straight through the flags/lives icons (own-palette overwrite
    ; objects, same corruption risk as the score bar text).
    lda alien_bullet_row,x
    sta temp1
    jsr is_row_protected
    lda star_row_protected
    bne mabs_erase_skip
    jsr draw_alien_bullet_x    ; erase at the current position
mabs_erase_skip:
    lda alien_bullet_row,x
    cmp #24
    beq mabs_deactivate
    inc alien_bullet_row,x

    lda alien_bullet_row,x
    sta temp1
    jsr is_row_protected
    lda star_row_protected
    bne mabs_next
    jsr draw_alien_bullet_x    ; redraw at the new position
    jmp mabs_next
mabs_deactivate:
    lda #0
    sta alien_bullet_active,x
mabs_next:
    inx
    cpx #ALIEN_BULLET_COUNT
    bne mabs_loop
mabs_rts:
    rts

; --- Aliens: decoded from O.GRAPHIC's graphics pointer table, same table
; the ship's graph+36/37 pointer lives in (entries 96 bytes apart =
; alwidth*alheight=6*16, CONST.asm) and the same dual-buffer "sprite"
; plotter, so the same row-reversal applies. Which entries to decode
; isn't a guess: ALIENS1.asm's spawn-group records (see alien_spawn_table
; below) each carry a raw `initgra` byte, and ALIENS2.asm reads it as
; "LDY algra,X : LDX graph,Y : LDA graph+1,Y" - Y indexes BYTES into a
; table of 2-byte pointers, so the real entry index is initgra/2. Wave
; 0's groups (patt0/2/43/1/11/10 in PATT.asm) use initgra 12, 18 and 16 -
; entries 6, 9 and 8 - all three decode as clean, symmetric, distinct
; shapes with this correction, which is what confirms it rather than
; just fitting numerically.
;
; Colors reduced per-type (each type's own dominant colors, not a shared
; palette): type 0/entry 6 keeps blue/cyan/white (nothing major needed
; substituting away); type 1/entry 9 keeps red/blue/magenta (yellow and
; cyan were 2-3 stray pixels each, folded into the nearest); type 2/
; entry 8 keeps blue/cyan/magenta (2 stray red pixels folded into
; magenta).
ALIEN_MATRIX_0   = $63  ; hi=6 blue (01), lo=3 cyan (10)
ALIEN_COLORRAM_0 = $01  ; white (11)
ALIEN_MATRIX_1   = $26  ; hi=2 red (01), lo=6 blue (10)
ALIEN_COLORRAM_1 = $04  ; magenta (11)
ALIEN_MATRIX_2   = $63  ; hi=6 blue (01), lo=3 cyan (10)
ALIEN_COLORRAM_2 = $04  ; magenta (11)

alien_bitmap_0:
 .byte $00,$03,$0f,$0d,$25,$25,$09,$02
 .byte $20,$ef,$ff,$55,$55,$55,$55,$56
 .byte $00,$00,$c0,$c0,$60,$60,$80,$00
 .byte $29,$95,$99,$22,$02,$09,$25,$0a
 .byte $55,$55,$55,$56,$66,$65,$89,$02
 .byte $a0,$58,$98,$20,$00,$80,$60,$80

alien_bitmap_1:
 .byte $00,$03,$0d,$35,$d6,$36,$0d,$35
 .byte $cc,$77,$55,$99,$96,$5a,$55,$65
 .byte $00,$00,$c0,$70,$5c,$70,$c0,$70
 .byte $d5,$36,$0d,$35,$d5,$35,$0d,$03
 .byte $a9,$aa,$a9,$65,$55,$75,$cd,$03
 .byte $5c,$70,$c0,$70,$5c,$70,$c0,$00

alien_bitmap_2:
 .byte $00,$02,$02,$02,$02,$00,$00,$00
 .byte $aa,$96,$d7,$55,$55,$96,$28,$28
 .byte $00,$80,$80,$80,$80,$00,$00,$00
 .byte $00,$00,$02,$28,$d6,$d5,$35,$0f
 .byte $28,$aa,$aa,$aa,$28,$82,$c3,$00
 .byte $00,$00,$80,$28,$97,$57,$5c,$f0

; compute_alien_addr: X = alien slot index. Sets temp3 (word) = bitmap
; address of cell (alien_row[X], alien_col[X]), temp4 (word) = screen-
; matrix address, temp2 (word) = color-RAM address - identical math to
; compute_ship_addrs, just against the alien arrays; kept as its own
; copy rather than shared for the same reason compute_bullet_addr/
; compute_alien_bullet_addr are separate (no cheap way to pass "which
; array" into shared code on 6502 without self-modifying code).
compute_alien_addr:
    lda alien_disp_col,x
    sta temp1
    lda #0
    sta temp4
    sta temp4+1
    lda alien_disp_row,x
    beq caa_row_done
    sta length
caa_row_loop:
    lda temp4
    clc
    adc #40
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1
    dec length
    bne caa_row_loop
caa_row_done:
    lda temp4
    clc
    adc temp1
    sta temp4
    lda temp4+1
    adc #0
    sta temp4+1              ; temp4 = row*40 + col (no page base yet)

    lda temp4
    sta temp3
    lda temp4+1
    sta temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1
    asl temp3
    rol temp3+1              ; temp3 = (row*40+col) * 8
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

; draw_alien_x: X = alien slot index. Plain overwrite (STA, not XOR) at
; the cell(s) it occupies, same reasoning as draw_ship: an alien owns a
; per-cell screen-matrix/color-RAM override, so XORing its bitmap bits
; against whatever background (or star) was already there would produce
; wrong colors, not a clean toggle - see the file header's note on
; shared-palette (XOR-safe) vs. own-palette (must-own-the-cell)
; objects. Dispatches on alien_type,X to one of 3 fixed-shape draw
; routines (temp3/temp4/temp2 already point at the right cell by the
; time they run - compute_alien_addr is only called once here, not
; inside each). Preserves X.
;
; Two overlapping own-palette objects still color-clash where they share
; a cell (whichever draws most recently wins that cell's bitmap AND
; colors outright, erase_alien_x/erase_ship just guard against either of
; them wiping the other's cells on the way OUT - see erase_alien_x).
; Tried blending the bitmap via ORA instead, so a background gap in one
; alien's shape would let the other show through - reverted: the erase-
; side bookkeeping it required (redraw the surviving object from scratch
; whenever a shared cell's occupants changed) made overlaps look
; messier, not cleaner, and cost enough extra per-cell work to be
; noticeably slower.
draw_alien_x:
    jsr compute_alien_addr
    lda alien_type,x
    cmp #0
    beq dax_t0
    cmp #1
    beq dax_t1
    jmp draw_alien_bitmap_2
dax_t0:
    jmp draw_alien_bitmap_0
dax_t1:
    jmp draw_alien_bitmap_1

; draw_alien_bitmap_0/1/2: the 6-cells-worth-per-type copy + per-cell
; color set, same "2 linear 24-byte rows, +320 between them" shortcut
; draw_ship uses (adjacent cells in a row sit back to back in memory).
draw_alien_bitmap_0:
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range      ; evict any star this cell-band is about to
                               ; overwrite - see STARS.asm's file header
                               ; note by star_evict_range
    ldy #0
dab0_top:
    lda alien_bitmap_0,y
    sta (temp3),y
    iny
    cpy #24
    bne dab0_top
    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
dab0_bottom:
    lda alien_bitmap_0+24,y
    sta (temp3),y
    iny
    cpy #24
    bne dab0_bottom
    lda #ALIEN_MATRIX_0
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
    lda #ALIEN_COLORRAM_0
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

draw_alien_bitmap_1:
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
dab1_top:
    lda alien_bitmap_1,y
    sta (temp3),y
    iny
    cpy #24
    bne dab1_top
    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
dab1_bottom:
    lda alien_bitmap_1+24,y
    sta (temp3),y
    iny
    cpy #24
    bne dab1_bottom
    lda #ALIEN_MATRIX_1
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
    lda #ALIEN_COLORRAM_1
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

draw_alien_bitmap_2:
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
dab2_top:
    lda alien_bitmap_2,y
    sta (temp3),y
    iny
    cpy #24
    bne dab2_top
    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
dab2_bottom:
    lda alien_bitmap_2+24,y
    sta (temp3),y
    iny
    cpy #24
    bne dab2_bottom
    lda #ALIEN_MATRIX_2
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
    lda #ALIEN_COLORRAM_2
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

; --- Alien/ship "burst" explosion - the REAL BBC explosion sequence
; (ALIENS3.asm's `.explosion`), decoded from O.GRAPHIC's graph-table
; entries 0-5 the same way the alien/ship sprites were (row-reversed,
; 4-bit-nibble dual-buffer format - see the alien graphics section
; above) and pixel-verified before trusting it on new data: the same
; transform applied to entries 6/8/9 reproduces alien_bitmap_0/2/1
; exactly (192/192 cells each), including the same stray-pixel counts
; already documented for those three, before being applied to entries
; 0-5. A hand-invented "burst" bitmap was tried twice before this (a
; uniform fill that read as two flat rectangles, then a corner-blob
; layout that read as 4 unrelated diamonds) - designing new multicolor
; pixel data blind, with no way to preview it before a real VICE run,
; isn't reliable, so this replaces both with the real decode instead of
; a third guess.
;
; The real BBC animation dual-buffer-XOR-composites each frame with the
; next as algra advances (see ALIENS3.asm); this port draws each frame
; as a plain overwrite instead (see draw_alien_x's own note on why
; blending was tried elsewhere and reverted) - still the real 6-frame
; sequence, just not XOR-composited between frames. Each frame keeps its
; own 2-color palette (all 6 land on a fire palette - yellow/red/white -
; with no frame needing a 4th color folded in).
;
; draw_explosion_here: temp3/temp4/temp2 already point at the target
; cell (same convention as draw_alien_bitmap_0/1/2). explosion_frame_num
; (0-5) selects which real frame to show - set by alien_explode_tick/
; ship_explode_tick, which advance it once per tick through the cycle.
; Doesn't touch X (the alien-slot index in alien_explode_tick's caller
; ma_loop must survive this call) - only Y, for the frame-table lookup
; and the two band copy loops.
explosion_frame_num:
 .byte 0
explosion_matrix_cur:
 .byte 0
explosion_colorram_cur:
 .byte 0

explosion_frame_lo:
 .byte <explosion_frame_0,<explosion_frame_1,<explosion_frame_2
 .byte <explosion_frame_3,<explosion_frame_4,<explosion_frame_5
explosion_frame_hi:
 .byte >explosion_frame_0,>explosion_frame_1,>explosion_frame_2
 .byte >explosion_frame_3,>explosion_frame_4,>explosion_frame_5
explosion_matrix_tab:
 .byte $71,$72,$71,$72,$72,$72
explosion_colorram_tab:
 .byte $02,$01,$02,$01,$01,$01

explosion_frame_0:                  ; hi=yellow(7) lo=white(1) colorram=red(2)
 .byte $00,$00,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$00,$40,$71,$65,$42
 .byte $00,$00,$00,$00,$00,$00,$00,$00
 .byte $0d,$00,$00,$00,$00,$00,$00,$00
 .byte $81,$59,$14,$10,$00,$00,$00,$00
 .byte $40,$70,$00,$00,$00,$00,$00,$00

explosion_frame_1:                  ; hi=yellow(7) lo=red(2) colorram=white(1)
 .byte $00,$00,$00,$00,$00,$00,$00,$05
 .byte $00,$00,$80,$42,$51,$55,$4c,$40
 .byte $00,$00,$00,$00,$00,$00,$40,$c0
 .byte $25,$01,$00,$00,$00,$00,$00,$00
 .byte $00,$c3,$85,$54,$10,$20,$00,$00
 .byte $60,$54,$00,$00,$00,$00,$00,$00

explosion_frame_2:                  ; hi=yellow(7) lo=white(1) colorram=red(2)
 .byte $03,$01,$01,$01,$01,$01,$06,$d4
 .byte $00,$41,$41,$51,$15,$08,$00,$28
 .byte $00,$00,$c0,$40,$40,$40,$40,$50
 .byte $54,$05,$01,$00,$00,$00,$00,$00
 .byte $88,$00,$81,$49,$44,$54,$14,$30
 .byte $14,$97,$50,$00,$00,$00,$00,$00

explosion_frame_3:                  ; hi=yellow(7) lo=red(2) colorram=white(1)
 .byte $02,$01,$01,$01,$01,$01,$04,$90
 .byte $41,$41,$11,$04,$00,$10,$10,$34
 .byte $00,$80,$40,$40,$40,$40,$40,$20
 .byte $40,$14,$02,$00,$00,$00,$00,$00
 .byte $cd,$30,$00,$41,$44,$44,$14,$20
 .byte $04,$01,$58,$00,$00,$00,$00,$00

explosion_frame_4:                  ; hi=yellow(7) lo=red(2) colorram=white(1)
                                      ; (red/white tied 4px each - the
                                      ; one genuine judgment call across
                                      ; all 6 frames, kept consistent
                                      ; with frames 1/3/5)
 .byte $02,$00,$00,$04,$00,$01,$00,$43
 .byte $00,$00,$04,$40,$41,$34,$00,$00
 .byte $40,$00,$00,$20,$40,$40,$00,$41
 .byte $84,$00,$04,$00,$00,$00,$00,$00
 .byte $00,$4d,$10,$04,$04,$40,$02,$00
 .byte $d0,$00,$00,$10,$00,$00,$00,$00

explosion_frame_5:                  ; hi=yellow(7) lo=red(2) colorram=white(1)
                                      ; (colorram slot unused this frame
                                      ; - 0 pixels use it - kept for
                                      ; table consistency)
 .byte $08,$06,$00,$04,$00,$00,$00,$90
 .byte $00,$00,$41,$00,$00,$00,$00,$00
 .byte $00,$60,$20,$00,$40,$00,$00,$00
 .byte $80,$04,$00,$00,$00,$00,$00,$00
 .byte $00,$00,$00,$01,$40,$84,$00,$20
 .byte $04,$02,$08,$00,$00,$00,$00,$00

draw_explosion_here:
    ldy explosion_frame_num
    lda explosion_frame_lo,y
    sta screen
    lda explosion_frame_hi,y
    sta screen+1
    lda explosion_matrix_tab,y
    sta explosion_matrix_cur
    lda explosion_colorram_tab,y
    sta explosion_colorram_cur

    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
deh_top:
    lda (screen),y
    sta (temp3),y
    iny
    cpy #24
    bne deh_top
    lda screen
    clc
    adc #24
    sta screen
    lda screen+1
    adc #0
    sta screen+1
    lda temp3
    clc
    adc #<320
    sta temp3
    lda temp3+1
    adc #>320
    sta temp3+1
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range
    ldy #0
deh_bottom:
    lda (screen),y
    sta (temp3),y
    iny
    cpy #24
    bne deh_bottom
    lda explosion_matrix_cur
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
    lda explosion_colorram_cur
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

; is_cell_covered: cell_check_col/row/exclude_kind/exclude_idx are inputs
; (exclude_kind: 0 = the ship itself is asking, 1 = an alien slot is
; asking, using exclude_idx as that slot so it never counts itself).
; Returns via cell_check_result (1/0), not a register - erase_alien_x/
; erase_ship call this X-slot-indexed, and returning through a register
; would race against the X/Y restore below on the way out. An exploding
; alien still counts as covering its cells (it's still visually there
; mid-burst, occupying the same footprint it always did).
cell_check_col:
 .byte 0
cell_check_row:
 .byte 0
cell_check_exclude_kind:
 .byte 0
cell_check_exclude_idx:
 .byte 0
cell_check_result:
 .byte 0

is_cell_covered:
    txa
    pha
    tya
    pha

    lda #0
    sta cell_check_result

    lda cell_check_exclude_kind
    beq icc_skip_ship          ; kind 0 - the ship is asking, don't check
                                ; the ship against itself
    lda cell_check_col
    cmp ship_col
    bcc icc_skip_ship
    sec
    sbc ship_col
    cmp #3
    bcs icc_skip_ship
    lda cell_check_row
    cmp ship_row
    bcc icc_skip_ship
    sec
    sbc ship_row
    cmp #2
    bcs icc_skip_ship
    lda #1
    sta cell_check_result
    jmp icc_done
icc_skip_ship:
    ldx #0
icc_alien_loop:
    lda cell_check_exclude_kind
    cmp #1
    bne icc_check_alien
    cpx cell_check_exclude_idx
    beq icc_next_alien          ; this IS the asking alien - skip self
icc_check_alien:
    lda alien_active,x
    beq icc_next_alien
    lda cell_check_col
    cmp alien_disp_col,x
    bcc icc_next_alien
    sec
    sbc alien_disp_col,x
    cmp #3
    bcs icc_next_alien
    lda cell_check_row
    cmp alien_disp_row,x
    bcc icc_next_alien
    sec
    sbc alien_disp_row,x
    cmp #2
    bcs icc_next_alien
    lda #1
    sta cell_check_result
    jmp icc_done
icc_next_alien:
    inx
    cpx #ALIEN_COUNT
    bne icc_alien_loop
icc_done:
    pla
    tay
    pla
    tax
    rts

; erase_alien_x: X = alien slot index. Per-cell guarded erase, not a
; blanket 2x24-byte reset - for each of the 6 cells this alien occupies,
; only resets it to background if no OTHER active hard object (ship or
; another alien) still covers that exact cell (is_cell_covered); a
; covered cell is left completely untouched, since the other object still
; needs it - this is the fix for the alien-overlap flicker/black-
; rectangle bug (the old blanket erase would blindly wipe out whatever
; the other object had drawn there). A cell that genuinely IS erased also
; gets star_restore_range'd for its own 8-byte range, redrawing any star
; that had been evicted from it (see star_evict_range in STARS.asm) - the
; fix for stuck stars. X survives every jsr below untouched: both
; is_cell_covered and star_restore_range fully preserve X/Y internally
; (see their own headers), so alien_disp_col,x/alien_disp_row,x stay
; correctly indexed by the ORIGINAL alien slot through all 6 cells with
; no extra save/restore needed here.
;
; Drawing over another alien still color-clashes where they overlap
; (whichever draws most recently wins that cell's colors AND bitmap
; outright) - see draw_alien_x's header on why blending was tried and
; reverted.
erase_alien_x:
    jsr compute_alien_addr

    ; cell 0: top-left (disp_col+0, disp_row+0), temp3+0, matrix/color y=0
    lda alien_disp_col,x
    sta cell_check_col
    lda alien_disp_row,x
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c0_skip
    ldy #0
eax_c0_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c0_erase
    lda #$73
    ldy #0
    sta (temp4),y
    lda #4
    ldy #0
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c0_skip:

    ; cell 1: top-mid (disp_col+1, disp_row+0), temp3+8, matrix/color y=1
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda alien_disp_col,x
    clc
    adc #1
    sta cell_check_col
    lda alien_disp_row,x
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c1_skip
    ldy #0
eax_c1_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c1_erase
    lda #$73
    ldy #1
    sta (temp4),y
    lda #4
    ldy #1
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c1_skip:

    ; cell 2: top-right (disp_col+2, disp_row+0), temp3+16, y=2
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda alien_disp_col,x
    clc
    adc #2
    sta cell_check_col
    lda alien_disp_row,x
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c2_skip
    ldy #0
eax_c2_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c2_erase
    lda #$73
    ldy #2
    sta (temp4),y
    lda #4
    ldy #2
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c2_skip:

    ; cell 3: bottom-left (disp_col+0, disp_row+1), temp3+320, y=40
    lda temp3
    clc
    adc #<304
    sta temp3
    lda temp3+1
    adc #>304
    sta temp3+1
    lda alien_disp_col,x
    sta cell_check_col
    lda alien_disp_row,x
    clc
    adc #1
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c3_skip
    ldy #0
eax_c3_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c3_erase
    lda #$73
    ldy #40
    sta (temp4),y
    lda #4
    ldy #40
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c3_skip:

    ; cell 4: bottom-mid (disp_col+1, disp_row+1), temp3+328, y=41
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda alien_disp_col,x
    clc
    adc #1
    sta cell_check_col
    lda alien_disp_row,x
    clc
    adc #1
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c4_skip
    ldy #0
eax_c4_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c4_erase
    lda #$73
    ldy #41
    sta (temp4),y
    lda #4
    ldy #41
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c4_skip:

    ; cell 5: bottom-right (disp_col+2, disp_row+1), temp3+336, y=42
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda alien_disp_col,x
    clc
    adc #2
    sta cell_check_col
    lda alien_disp_row,x
    clc
    adc #1
    sta cell_check_row
    lda #1
    sta cell_check_exclude_kind
    stx cell_check_exclude_idx
    jsr is_cell_covered
    lda cell_check_result
    bne eax_c5_skip
    ldy #0
eax_c5_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne eax_c5_erase
    lda #$73
    ldy #42
    sta (temp4),y
    lda #4
    ldy #42
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
eax_c5_skip:
    rts

ALIEN_COUNT = 8
ALIEN_SPAWN_GROUPS = 7

alien_active:
 .res ALIEN_COUNT
alien_type:
 .res ALIEN_COUNT
; alien_disp_col/row: the cell position currently RENDERED - separate
; from alien_x/alien_y (below), which track the alien's real BBC-scale
; position (color-pixel column, scanline). Redraw only happens when the
; derived cell (x/4, y/8) actually changes - see alien_refresh_display.
alien_disp_col:
 .res ALIEN_COUNT
alien_disp_row:
 .res ALIEN_COUNT
alien_x:
 .res ALIEN_COUNT
alien_y:
 .res ALIEN_COUNT
; Per-alien pattern-interpreter state - see alien_exec_instr.
alien_pat_lo:
 .res ALIEN_COUNT
alien_pat_hi:
 .res ALIEN_COUNT
alien_pat_off:
 .res ALIEN_COUNT
alien_pat_reflect:
 .res ALIEN_COUNT
alien_direct:
 .res ALIEN_COUNT
alien_mult:
 .res ALIEN_COUNT
alien_loop_count:
 .res ALIEN_COUNT
alien_loop_start:
 .res ALIEN_COUNT

; --- Collision/death bookkeeping. alien_hit_points/alien_score are
; simplified from ROUT2.asm's alien_hits/ROUT3.asm's alien_score - both
; real BBC tables are indexed by a value derived from the alien's exact
; graph-table entry (12-15+ distinct alien types); we only have 3 types
; (alien_bitmap_0/1/2), so rather than re-derive that indexing for just
; these 3, each gets its own flat per-type entry below. alien_score's
; values happen to trace to the same source number (2, i.e. 20 points)
; for all three of our actual entries (6/8/9) - not a simplification,
; that's what the real table says for exactly these three - so
; ALIEN_SCORE_0/1/2 being equal is real, not a placeholder. Hit points
; ARE a simplification (the real table's spread, by graph-table index,
; isn't re-traced here): 1/2/1, giving type 1 a LITTLE more durability,
; not an exact source value.
ALIEN_HP_0 = 1
ALIEN_HP_1 = 2
ALIEN_HP_2 = 1
alien_score_table:
 .byte 2, 2, 2              ; source's alien_score units (x10 = real points)

alien_hp:
 .res ALIEN_COUNT
alien_exploding:
 .res ALIEN_COUNT
alien_explode_timer:
 .res ALIEN_COUNT
EXPLOSION_FRAME_COUNT = 6   ; explosion_frame_0..5 - see draw_explosion_here

; init_alien_hp: X = alien slot (alien_type,X already set). Sets
; alien_hp,X from the per-type table above and clears alien_exploding,X -
; shared by pas_spawn and asc_spawn, both of which need identical fresh-
; spawn bookkeeping. A 3-way dispatch, not an indexed table lookup - X is
; already busy holding the pool slot and there's no free index register
; to also index alien_score_table with, same reasoning as draw_alien_x's
; own type dispatch.
init_alien_hp:
    lda #0
    sta alien_exploding,x
    lda alien_type,x
    cmp #0
    beq iah_t0
    cmp #1
    beq iah_t1
    lda #ALIEN_HP_2
    jmp iah_store
iah_t0:
    lda #ALIEN_HP_0
    jmp iah_store
iah_t1:
    lda #ALIEN_HP_1
iah_store:
    sta alien_hp,x
    rts

; alien_explode_tick: X = alien slot, already known to be exploding.
; alien_explode_timer,X counts UP as a frame index (0..5) through the
; real 6-frame explosion sequence - each draw is a full overwrite (see
; draw_alien_x's header on why draw isn't blended), so no erase is
; needed between frames, only once at the very end. Deactivates the slot
; for real once all 6 frames have shown.
alien_explode_tick:
    lda alien_explode_timer,x
    cmp #EXPLOSION_FRAME_COUNT
    bcs aet_finish
    sta explosion_frame_num
    jsr compute_alien_addr
    jsr draw_explosion_here
    inc alien_explode_timer,x
    rts
aet_finish:
    lda #0
    sta alien_active,x
    sta alien_exploding,x
    jsr erase_alien_x
    rts

; alien_spawn_table: wave 0's 7 real spawn-group entries (PATT.asm's
; patt0, patt2, patt43's 2 sub-entries, patt1, patt11, patt10 - the
; groups WAVE.asm's wave0 byte list 0,2,43,1,11,10 selects), not
; invented placement. Columns: spawn col, spawn row, type (0/1/2 into
; the alien_bitmap_N above), delay, count, pattern selector - straight
; from each patt entry's x/y/initdel/initnum/initpnum fields. x
; converted BBC-byte-columns -> C64 cells (1 BBC byte = 2 BBC pixels =
; half a C64 cell, so col = BBC x/2); y converted BBC-scanlines -> C64
; rows (row = BBC y/8). patt43's x=78/79 would put a 3-cell-wide
; alien's right edge off the 40-column screen, so clamped to 37 (40-3),
; the same edge clamp draw_ship/the lives icons already use. Pattern
; selector is initpnum as-is: bit7 = reflect (see alien_select_pattern),
; bits0-6 = which patdat block (0-29, pattern_table below).
alien_spawn_table:
 .byte 0,  6, 0, 5, 20,  0      ; patt0  (type 0/entry 6, pattern 0)
 .byte 6,  4, 1, 4, 30,  1      ; patt2  (type 1/entry 9, pattern 1) - real
                                  ; row is 3 (PATT.asm's y=24 -> 24/8=3),
                                  ; clamped to 4 for the same reason
                                  ; patt43's column was clamped below: row
                                  ; 3 is the score bar, and (like the
                                  ; column clamp) this alien's own
                                  ; own-palette erase can't safely share a
                                  ; cell with static HUD text - see
                                  ; alien_apply_move's matching floor.
 .byte 37, 4, 2, 16, 20, 25     ; patt43 part 1 (type 2/entry 8, pattern 25)
 .byte 37, 4, 2, 14, 20, 153    ; patt43 part 2 (PATT.asm: EQUB25+&80 -
                                  ; REFLECTED, unlike part 1 - transcribed
                                  ; as plain 25 here before, which is why
                                  ; this half of patt43's spawns kept
                                  ; sweeping further right instead of
                                  ; mirroring back onto the screen)
 .byte 36, 6, 0, 5, 20,  128    ; patt1  (type 0, pattern 0 reflected)
 .byte 36, 4, 2, 5, 8,   135    ; patt11 (type 2, pattern 7 reflected)
 .byte 0,  4, 2, 5, 8,   7      ; patt10 (type 2, pattern 7)

alien_spawn_delay_left:
 .res ALIEN_SPAWN_GROUPS
alien_spawn_count_left:
 .res ALIEN_SPAWN_GROUPS

; init_alien_wave: clears the alien pool and (re)loads the spawn
; engine's per-group countdowns from alien_spawn_table. Wave-0-only for
; now - selecting a real wave's own byte list from WAVE.asm instead of
; this fixed table is later work, once wave advancement means something.
init_alien_wave:
    ldx #0
iaw_clear:
    lda #0
    sta alien_active,x
    inx
    cpx #ALIEN_COUNT
    bne iaw_clear

    ldy #0
iaw_spawn_init:
    jsr alien_spawn_table_offset  ; temp1 = group index * 6
    ldx temp1
    lda alien_spawn_table+3,x
    sta alien_spawn_delay_left,y
    lda alien_spawn_table+4,x
    sta alien_spawn_count_left,y
    iny
    cpy #ALIEN_SPAWN_GROUPS
    bne iaw_spawn_init
    rts

; alien_spawn_table_offset: Y = spawn group index (0-6). Sets temp1 =
; Y*6 (the table's per-entry stride) - shared by init_alien_wave and
; process_alien_spawns instead of each recomputing it separately.
; Preserves Y.
alien_spawn_table_offset:
    tya
    asl a
    asl a
    sta temp1               ; temp1 = Y*4
    tya
    asl a
    clc
    adc temp1
    sta temp1                ; temp1 = Y*2 + Y*4 = Y*6
    rts

; process_alien_spawns: called once per frame (no throttle - delay
; values are real per-frame BBC countdowns, not something to slow
; further). For each spawn group with any spawns left: counts its delay
; down, and on reaching 0, spawns one alien into the first free pool
; slot (dropping the spawn if the pool's full) and reloads the delay.
pas_group:
 .byte 0

process_alien_spawns:
    lda #0
    sta pas_group
pas_loop:
    ldy pas_group
    lda alien_spawn_count_left,y
    beq pas_next
    lda alien_spawn_delay_left,y   ; DEC has no absolute,Y mode - do it
    sec                             ; as a plain load/subtract/store
    sbc #1
    sta alien_spawn_delay_left,y
    bne pas_next

    jsr alien_spawn_table_offset   ; temp1 = group offset (Y*6)
    ldx temp1
    lda alien_spawn_table+3,x
    sta alien_spawn_delay_left,y
    lda alien_spawn_count_left,y   ; DEC has no absolute,Y mode
    sec
    sbc #1
    sta alien_spawn_count_left,y

    ldx #0
pas_find_slot:
    lda alien_active,x
    beq pas_spawn
    inx
    cpx #ALIEN_COUNT
    bne pas_find_slot
    jmp pas_next             ; pool full - drop this spawn
pas_spawn:
    lda #1
    sta alien_active,x
    ldy temp1
    lda alien_spawn_table+0,y
    sta alien_disp_col,x
    asl a
    asl a
    sta alien_x,x            ; alien_x = col*4 (color-pixels)
    lda alien_spawn_table+1,y
    sta alien_disp_row,x
    asl a
    asl a
    asl a
    sta alien_y,x            ; alien_y = row*8 (scanlines)
    lda alien_spawn_table+2,y
    sta alien_type,x
    jsr init_alien_hp
    lda #0
    sta alien_mult,x         ; forces an immediate pattern-read on this
                              ; alien's first tick, not a move first
    lda alien_spawn_table+5,y
    jsr alien_select_pattern
    jsr draw_alien_x
pas_next:
    inc pas_group
    lda pas_group
    cmp #ALIEN_SPAWN_GROUPS
    bne pas_loop
    rts

; c64_curwave: advances every time the current wave's spawn groups are all
; exhausted AND the pool is empty (checked by check_wave_clear, called
; once per game_loop frame). There's still only one real spawn table
; (wave 0's, decoded from PATT.asm/WAVE.asm - see alien_spawn_table)
; - decoding the rest of WAVE.asm's per-wave byte lists into their own
; tables is later work, same as init_alien_wave's own header note - so
; this reloads the SAME table for now. level_ones (the flag count)
; tracks it 1:1, capped at 8 so the flag row can't run off the right
; edge; draw_level_flags only ever needs to draw NEW flags further right
; (never clear old ones - see redraw_lives_after_loss for the opposite,
; shrinking case), so no erase is needed here.
c64_curwave:
 .byte 0

check_wave_clear:
    ldy #0
cwc_groups:
    lda alien_spawn_count_left,y
    bne cwc_done
    iny
    cpy #ALIEN_SPAWN_GROUPS
    bne cwc_groups

    ldx #0
cwc_aliens:
    lda alien_active,x
    bne cwc_done
    inx
    cpx #ALIEN_COUNT
    bne cwc_aliens

    inc c64_curwave
    lda #1                      ; tune 1 = Zone/wave music
    jsr start_tune
    lda level_ones
    cmp #8
    bcs cwc_advance
    inc level_ones
    jsr draw_level_flags
cwc_advance:
    jsr init_alien_wave
cwc_done:
    rts

; --- Alien flight patterns (phase 5b): a real interpreter for
; ALIENS3.asm/ALIENS4.asm's pattern bytecode, not the phase 5a
; placeholder drift. Traced end to end against the source:
;
; Each pattern (c64_patdat0-29, PATDAT.asm) is a byte stream read one
; instruction at a time (alien_pat_off). A byte with bit7 SET is a
; (magnitude, direction) pair: AND $7F is how many ticks to keep moving
; in the SAME direction (alien_mult) before reading another instruction,
; and the next byte is the direction - an index into the 56-entry
; addrelx_tab/addrely_tab compass (8 directions x 6 speeds, plus 2
; special high-arc rows; see ROUT1.asm's addrelx/addrely, xstep=1/
; ystep=4). A byte with bit7 CLEAR is a command, dispatched through
; ALIENS4.asm's actiontab: values are already *2 (byte offsets into a
; table of 2-byte pointers, same convention as the graph/initgra table
; - see the alien graphics note above), which is why DAT_LOOP etc. below
; are even numbers, not 0-7.
;
; Reflection (alien_pat_reflect, from the spawn table's pattern-selector
; bit7 - see alien_select_pattern): mirrors the direction horizontally.
; ALIENS3.asm's flip_table is stored pre-XORed with 7 because the code
; unconditionally EORs its result by 7 again afterward; flip_table_net
; below is the two XORs already cancelled out, so it's used directly -
; EXCEPT the "acute angle" case (direction >= 48, the special rows,
; skipped past the table entirely) still needs a real "EOR #7", which
; is not cancelled by anything - see aei_direction.
DAT_LOOP     = 0
DAT_NEWPAT   = 2
DAT_NEWALIEN = 4
DAT_DIE      = 6
DAT_DROPBOMB = 8
DAT_FOR_LOOP = 10
DAT_NEXT     = 12
DAT_MVE      = 14

addrelx_tab:
 .byte $00,$02,$00,$fe,$02,$02,$fe,$fe
 .byte $00,$04,$00,$fc,$04,$04,$fc,$fc
 .byte $00,$06,$00,$fa,$06,$06,$fa,$fa
 .byte $00,$08,$00,$f8,$08,$08,$f8,$f8
 .byte $00,$0a,$00,$f6,$0a,$0a,$f6,$f6
 .byte $00,$0c,$00,$f4,$0c,$0c,$f4,$f4
 .byte $04,$04,$fc,$fc,$04,$04,$fc,$fc
addrely_tab:
 .byte $fc,$00,$04,$00,$fc,$04,$04,$fc
 .byte $f8,$00,$08,$00,$f8,$08,$08,$f8
 .byte $f4,$00,$0c,$00,$f4,$0c,$0c,$f4
 .byte $f0,$00,$10,$00,$f0,$10,$10,$f0
 .byte $ec,$00,$14,$00,$ec,$14,$14,$ec
 .byte $e8,$00,$18,$00,$e8,$18,$18,$e8
 .byte $f0,$04,$10,$fc,$fc,$10,$04,$f0
flip_table_net:
 .byte 0,3,2,1,7,6,5,4

; c64_patdat0/1/7/25: the 4 real flight patterns wave 0 actually uses
; (decoded above). pattern_table_lo/hi (further below) is a 30-entry
; table matching vecpatdl/vecpatdh's real size, but only indices 0, 1,
; 7 and 25 are decoded - everything else falls back to c64_patdat0 (a real,
; working pattern, not fabricated data) until more waves are added and
; need their own.
c64_patdat0:
 .byte $86,9,$83,12,10,1,$86,13,$86,12,12,$83,13,6
c64_patdat1:
 .byte $97,13,$94,11,$98,12,6
c64_patdat7:
 .byte $93,13,$88,9,$82,4,$87,7,$86,15,$87,23,6
c64_patdat25:
 .byte $90,2,$83,9,$a0,2,$8d,48,6

pattern_table_lo:
 .byte <c64_patdat0,<c64_patdat1,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat7
 .byte <c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0
 .byte <c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0
 .byte <c64_patdat0,<c64_patdat25,<c64_patdat0,<c64_patdat0,<c64_patdat0,<c64_patdat0
pattern_table_hi:
 .byte >c64_patdat0,>c64_patdat1,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat7
 .byte >c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0
 .byte >c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0
 .byte >c64_patdat0,>c64_patdat25,>c64_patdat0,>c64_patdat0,>c64_patdat0,>c64_patdat0

; alien_select_pattern: X = alien slot, A = pattern selector (bit7 =
; reflect, bits0-6 = pattern_table index). Points alien_pat_lo/hi,X at
; that pattern and resets alien_pat_off,X to 0 - used both at spawn and
; by DAT_NEWPAT mid-pattern. Preserves X.
alien_select_pattern:
    sta alien_pat_reflect,x
    and #$7F
    tay
    lda pattern_table_lo,y
    sta alien_pat_lo,x
    lda pattern_table_hi,y
    sta alien_pat_hi,x
    lda #0
    sta alien_pat_off,x
    rts

; alien_read_byte: X = alien slot. Returns the current pattern byte in
; A and advances alien_pat_off,X. Preserves X.
alien_read_byte:
    lda alien_pat_lo,x
    sta temp3
    lda alien_pat_hi,x
    sta temp3+1
    ldy alien_pat_off,x
    lda (temp3),y
    pha
    inc alien_pat_off,x
    pla
    rts

; alien_exec_instr: X = alien slot. Reads and executes instructions
; until one leaves a move ready to apply: a (magnitude,direction) pair
; (sets amp_should_move=1, alien_mult/alien_direct,X), DAT_DIE
; (deactivates - caller checks alien_active), DAT_NEWALIEN (spawns a
; child, sets amp_should_move=0 - the parent doesn't move this tick,
; matching the source's JMPmove5), or DAT_MVE (repositions directly and
; redraws itself, also amp_should_move=0). DAT_LOOP/DAT_NEWPAT/
; DAT_FOR_LOOP/DAT_NEXT/DAT_DROPBOMB all adjust state and loop back for
; the next instruction immediately (no tick cost), same as the source's
; "JMPmove7" endings.
amp_should_move:
 .byte 0

alien_exec_instr:
    jsr alien_read_byte
    bmi aei_direction
    cmp #DAT_LOOP
    beq aei_loop
    cmp #DAT_NEWPAT
    beq aei_newpat
    cmp #DAT_NEWALIEN
    bne aei_not_newalien
    jmp aei_newalien
aei_not_newalien:
    cmp #DAT_DIE
    bne aei_not_die
    jmp aei_die
aei_not_die:
    cmp #DAT_DROPBOMB
    beq aei_dropbomb
    cmp #DAT_FOR_LOOP
    beq aei_for_loop
    cmp #DAT_NEXT
    beq aei_next
    jmp aei_mve              ; DAT_MVE, or any unrecognized byte

aei_direction:
    and #$7F
    sta alien_mult,x
    jsr alien_read_byte
    ldy alien_pat_reflect,x
    bpl aei_not_reflected
    cmp #48
    bcs aei_flip_acute
    pha
    and #$F8
    sta temp1                ; temp1 = speed-group bits (untouched by
                              ; the mirror - only the within-group
                              ; direction, bits 0-2, actually flips)
    pla
    and #7
    tay
    lda flip_table_net,y
    ora temp1                ; recombine with the speed-group bits -
                              ; missing this dropped them entirely,
                              ; corrupting the direction of any
                              ; reflected alien above the slowest speed
    jmp aei_not_reflected     ; net table already accounts for the EOR 7
aei_flip_acute:
    eor #7
aei_not_reflected:
    sta alien_direct,x
    rts

aei_loop:
    jsr alien_read_byte
    sta alien_pat_off,x
    jmp alien_exec_instr

aei_newpat:
    jsr alien_read_byte
    jsr alien_select_pattern
    jmp alien_exec_instr

aei_for_loop:
    jsr alien_read_byte
    sta alien_loop_count,x
    lda alien_pat_off,x
    sta alien_loop_start,x
    jmp alien_exec_instr

aei_next:
    lda alien_loop_count,x
    sec
    sbc #1
    sta alien_loop_count,x
    bmi aei_end_loop
    lda alien_loop_start,x
    sta alien_pat_off,x
aei_end_loop:
    jmp alien_exec_instr

aei_dropbomb:
    jsr alien_fire_bomb
    jmp alien_exec_instr

; alien_fire_bomb: X = firing alien's slot (preserved). Spawns into the
; alien bullet pool at a cell just below the alien's current footprint,
; centered on it - same free-slot-search-or-drop pattern as
; spawn_player_bullet. Drops the shot instead of firing if the target
; cell would land at row 23+ (the flags/lives status area): alien
; bullets are XOR-drawn, and those rows' icons are own-palette overwrite
; objects, so XORing a bullet into one of those cells would desync
; exactly like the ship-adjacent bullet spawn bug already fixed in
; spawn_player_bullet.
afb_target_row:
 .byte 0
afb_target_col:
 .byte 0
afb_saved_x:
 .byte 0

alien_fire_bomb:
    stx afb_saved_x
    lda alien_disp_row,x
    clc
    adc #2
    cmp #23
    bcs afb_drop
    sta afb_target_row
    lda alien_disp_col,x
    clc
    adc #1
    sta afb_target_col

    ldx #0
afb_find_slot:
    lda alien_bullet_active,x
    beq afb_spawn
    inx
    cpx #ALIEN_BULLET_COUNT
    bne afb_find_slot
    jmp afb_drop              ; pool full
afb_spawn:
    lda #1
    sta alien_bullet_active,x
    lda afb_target_row
    sta alien_bullet_row,x
    lda afb_target_col
    sta alien_bullet_col,x
    jsr draw_alien_bullet_x
afb_drop:
    ldx afb_saved_x
    rts

aei_die:
    lda #0
    sta alien_active,x
    jsr erase_alien_x
    rts

aei_newalien:
    jsr alien_read_byte       ; A = child's pattern selector
    jsr alien_spawn_child
    lda #0
    sta amp_should_move
    rts

aei_mve:
    ; Resets to a fresh top-of-screen position (source: aly=72 BBC
    ; scanlines, alx=0) rather than a compass step - 72 kept as-is
    ; (scanline units need no rescaling, same reasoning as addrely_tab).
    lda #0
    sta alien_x,x
    lda #72
    sta alien_y,x
    jsr alien_refresh_display
    lda #0
    sta amp_should_move
    rts

; alien_spawn_child: X = parent alien slot (preserved), A = child's
; pattern selector byte. Finds a free pool slot and spawns a child
; there: parent's type, a position 8 scanlines below the parent
; (matches ALIENS4.asm's "LDAaly,X:ADC#8"), the given pattern.
; Simplified from the source's exact graphic-randomization/alien_hits
; bookkeeping (collision/scoring infrastructure this port doesn't have
; yet), but the spawn itself - position, pattern, a live pool slot - is
; real, not a placeholder.
asc_pattern:
 .byte 0
asc_parent:
 .byte 0

alien_spawn_child:
    sta asc_pattern
    stx asc_parent
    ldx #0
asc_find_slot:
    lda alien_active,x
    beq asc_spawn
    inx
    cpx #ALIEN_COUNT
    bne asc_find_slot
    ldx asc_parent
    rts                        ; pool full - drop the spawn
asc_spawn:
    lda #1
    sta alien_active,x
    ldy asc_parent
    lda alien_type,y
    sta alien_type,x
    jsr init_alien_hp
    lda alien_x,y
    sta alien_x,x
    lda alien_disp_col,y
    sta alien_disp_col,x
    lda alien_y,y
    clc
    adc #8
    cmp #185                  ; same footprint-aware bound as
    bcc asc_y_ok               ; alien_apply_move - clamp rather than
    lda #184                    ; deactivate here, a freshly-spawned
asc_y_ok:                        ; child has nothing to deactivate FROM
    sta alien_y,x
    lsr a
    lsr a
    lsr a
    sta alien_disp_row,x      ; derived from the real (post-clamp) Y,
                               ; not copied from the parent's own row
    lda #0
    sta alien_mult,x
    lda asc_pattern
    jsr alien_select_pattern
    jsr draw_alien_x
    ldx asc_parent
    rts

; alien_refresh_display: X = alien slot. Redraws (erase old cell, draw
; new) only if alien_x/alien_y's derived cell (x/4, y/8) differs from
; what's currently rendered (alien_disp_col/row,X) - shared by
; alien_apply_move (after a compass step) and aei_mve (direct
; reposition).
; ard_new_col/ard_new_row are dedicated, not the usual length/temp1
; scratch: erase_alien_x (below) calls compute_alien_addr, which uses
; BOTH length (its row-multiply loop counter) and temp1 (its col
; holder) internally - saving the new position in either of those and
; then calling erase_alien_x would get it clobbered before it was read
; back. This was the actual cause of the corruption: alien_disp_col/row
; were ending up set from whatever compute_alien_addr's loop happened
; to leave behind, not the real new position, so aliens drew at wrong
; cells while their old position was left un-erased.
ard_new_col:
 .byte 0
ard_new_row:
 .byte 0

alien_refresh_display:
    lda alien_x,x
    lsr a
    lsr a
    sta ard_new_col
    lda alien_y,x
    lsr a
    lsr a
    lsr a
    sta ard_new_row

    lda ard_new_col
    cmp alien_disp_col,x
    bne ard_redraw
    lda ard_new_row
    cmp alien_disp_row,x
    beq ard_done
ard_redraw:
    jsr erase_alien_x
    lda ard_new_col
    sta alien_disp_col,x
    lda ard_new_row
    sta alien_disp_row,x
    jsr draw_alien_x
ard_done:
    rts

; alien_apply_move: X = alien slot. Applies one compass step
; (addrelx_tab/addrely_tab[alien_direct,X]) to alien_x/alien_y,
; deactivating if it would go off any edge - the source instead wraps X
; and lets Y wander indefinitely; deactivating here is a deliberate
; simplification (there's no collision/scoring system yet to make
; "wrap around forever" meaningful), not a guess at the source's own
; behavior.
; Bounds are the screen size MINUS the alien's own 12x16-pixel
; footprint (149/185, not 160/200) - checking against the full screen
; size let alien_x/alien_y reach positions whose 3x2-cell footprint
; ran past column 39 or row 24, wrapping into the next row's bitmap/
; screen-matrix/color-RAM data (the buffers are flat arrays, so
; "column 40" is really the start of the next row) - that's what showed
; up as heavy on-screen corruption. 148/184 are the same max col/row
; (37/23) SHIP_MAX_COL/SHIP_MAX_ROW already use, for the same reason.
;
; Decrements alien_mult,X itself (matching move4's "LDXprocst:
; DECalmult,X", which runs on EVERY call including the one right after
; a fresh magnitude is set, not just later repeats) - alien_tick_one
; used to also decrement before calling this, which double-counted the
; first move of each direction (7 applications of a magnitude-6
; instruction instead of 6).
alien_apply_move:
    dec alien_mult,x
    ldy alien_direct,x
    lda alien_x,x
    clc
    adc addrelx_tab,y
    cmp #149
    bcs aam_deactivate
    sta alien_x,x
    lda alien_y,x
    clc
    adc addrely_tab,y
    cmp #176                 ; keeps the alien's bottom row off row 23
    bcs aam_deactivate         ; (the flags/lives HUD) - also catches
    cmp #32                    ; the "went negative" wraparound, which
    bcc aam_deactivate          ; comes back as a large value (>=176).
    sta alien_y,x              ; Floor raised from row 1 (Y>=8) to row 4
                                 ; (Y>=32): row 1-3 still let an alien's
                                 ; TOP overlap row 0-2, but its erase on
                                 ; the way back out has no idea a score-
                                 ; bar letter lives there (is_cell_covered
                                 ; only knows about other hard objects,
                                 ; not static text) and would reset those
                                 ; cells to plain background, permanently
                                 ; wiping part of the score bar - the
                                 ; actual cause of the score-corruption
                                 ; reports surviving the star-row fix.
                                 ; "status area" is both ends, not just
                                 ; the bottom.
    jmp alien_refresh_display
aam_deactivate:
    lda #0
    sta alien_active,x
    jsr erase_alien_x
    rts

; alien_tick_one: X = alien slot (already confirmed active by the
; caller). If alien_mult,X is still counting down, just applies the
; current direction again (matches move4's fast path - no pattern byte
; is read). Otherwise runs the interpreter for one instruction-chain and
; applies whatever it leaves ready, unless a death/spawn/reposition
; already handled everything (amp_should_move=0).
alien_tick_one:
    lda alien_mult,x
    beq atx_read
    jmp alien_apply_move     ; alien_apply_move itself decrements
                              ; alien_mult now (see its own comment) -
                              ; doing it here too double-counted the
                              ; first move after a fresh direction read
atx_read:
    lda #1
    sta amp_should_move
    jsr alien_exec_instr
    lda alien_active,x
    beq atx_done
    lda amp_should_move
    beq atx_done
    jmp alien_apply_move
atx_done:
    rts

; alien_move_tick: called once per frame per active alien (throttled -
; the pattern magnitudes are tuned to the source's own frame-rate
; assumptions, and this is the closest we track to that). Named
; alien_move_tick rather than move_aliens - ALIENS3.asm (still-
; unconverted legacy source, assembled but not called) already defines
; .move_aliens, and this file's ca65 build shares one global symbol
; namespace with it.
ALIEN_MOVE_SLOWDOWN = 6
alien_move_count:
 .byte 0

alien_move_tick:
    inc alien_move_count
    lda alien_move_count
    cmp #ALIEN_MOVE_SLOWDOWN
    bcc ma_rts
    lda #0
    sta alien_move_count

    ldx #0
ma_loop:
    lda alien_active,x
    beq ma_next
    lda alien_exploding,x
    bne ma_explode
    jsr alien_tick_one
    jmp ma_next
ma_explode:
    jsr alien_explode_tick
ma_next:
    inx
    cpx #ALIEN_COUNT
    bne ma_loop
ma_rts:
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
; Vertical range confined to a lower band, not the full screen - real
; BBC data, not a guess: ROUT3.asm clamps myy to 165-234 (out of 256
; scanlines), the bottom ~27% of the screen. Same proportion applied to
; C64's 200 scanlines/25 rows: 165/256=64% -> row16, 234/256=91% ->
; row22, and since the ship is 2 rows tall, its TOP row has to stop one
; short of that (21, not 22) to keep its BOTTOM row off row23 (the
; flags/lives HUD). This also frees the whole upper 2/3 of the screen
; for aliens - "maximize play area vs BBC" - rather than the ship being
; able to wander anywhere onscreen.
SHIP_START_ROW  = 20
SHIP_START_COL  = 18
SHIP_MIN_COL    = 0
SHIP_MAX_COL    = 37     ; 40 cells - 3 wide
SHIP_MIN_ROW    = 16
SHIP_MAX_ROW    = 21     ; ship's bottom row stays off row 23 (flags/lives)
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

    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range      ; preserves X - dsh_top/dsh_bottom below
                               ; share one running index (0-47) through X,
                               ; which must survive this call untouched

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

    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #24
    sta sce_range_len
    jsr star_evict_range

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

; erase_ship: per-cell guarded erase, same reasoning/structure as
; erase_alien_x above (exclude_kind=0 - the ship itself - so
; is_cell_covered checks aliens only, never the ship against itself;
; exclude_idx is unused/irrelevant when exclude_kind=0).
erase_ship:
    lda ship_col
    jsr compute_ship_addrs

    ; cell 0: top-left (ship_col+0, ship_row+0), temp3+0, y=0
    lda ship_col
    sta cell_check_col
    lda ship_row
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c0_skip
    ldy #0
esh_c0_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c0_erase
    lda #$73
    ldy #0
    sta (temp4),y
    lda #4
    ldy #0
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c0_skip:

    ; cell 1: top-mid (ship_col+1, ship_row+0), temp3+8, y=1
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda ship_col
    clc
    adc #1
    sta cell_check_col
    lda ship_row
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c1_skip
    ldy #0
esh_c1_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c1_erase
    lda #$73
    ldy #1
    sta (temp4),y
    lda #4
    ldy #1
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c1_skip:

    ; cell 2: top-right (ship_col+2, ship_row+0), temp3+16, y=2
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda ship_col
    clc
    adc #2
    sta cell_check_col
    lda ship_row
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c2_skip
    ldy #0
esh_c2_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c2_erase
    lda #$73
    ldy #2
    sta (temp4),y
    lda #4
    ldy #2
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c2_skip:

    ; cell 3: bottom-left (ship_col+0, ship_row+1), temp3+320, y=40
    lda temp3
    clc
    adc #<304
    sta temp3
    lda temp3+1
    adc #>304
    sta temp3+1
    lda ship_col
    sta cell_check_col
    lda ship_row
    clc
    adc #1
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c3_skip
    ldy #0
esh_c3_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c3_erase
    lda #$73
    ldy #40
    sta (temp4),y
    lda #4
    ldy #40
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c3_skip:

    ; cell 4: bottom-mid (ship_col+1, ship_row+1), temp3+328, y=41
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda ship_col
    clc
    adc #1
    sta cell_check_col
    lda ship_row
    clc
    adc #1
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c4_skip
    ldy #0
esh_c4_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c4_erase
    lda #$73
    ldy #41
    sta (temp4),y
    lda #4
    ldy #41
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c4_skip:

    ; cell 5: bottom-right (ship_col+2, ship_row+1), temp3+336, y=42
    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda ship_col
    clc
    adc #2
    sta cell_check_col
    lda ship_row
    clc
    adc #1
    sta cell_check_row
    lda #0
    sta cell_check_exclude_kind
    jsr is_cell_covered
    lda cell_check_result
    bne esh_c5_skip
    ldy #0
esh_c5_erase:
    lda #0
    sta (temp3),y
    iny
    cpy #8
    bne esh_c5_erase
    lda #$73
    ldy #42
    sta (temp4),y
    lda #4
    ldy #42
    sta (temp2),y
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #8
    sta sce_range_len
    jsr star_restore_range
esh_c5_skip:
    rts

; --- Ship death - ROUT2.asm's .crash: erase the ship, lose a life, kill
; every active alien and bullet outright (no per-alien explosion cascade
; on top of the ship's own - matches the source's "mark them all dead",
; kept simple rather than layering two explosion animations at once),
; then run the ship's own burst before either respawning or, out of
; lives, returning to the title. game_state gates game_loop: normal play
; only runs while GS_PLAYING; the explosion and its aftermath run on
; their own while GS_SHIP_EXPLODING, so a stray alien/bullet collision
; can't fire again mid-explosion.
GS_PLAYING        = 0
GS_SHIP_EXPLODING = 1
GS_GAME_OVER       = 2
game_state:
 .byte GS_PLAYING
ship_explode_timer:
 .byte 0
SHIP_EXPLODE_SLOWDOWN = 4
ship_explode_count:
 .byte 0

ship_crash:
    jsr erase_ship
    dec lives_count

    ldx #0
sc_clear_aliens:
    lda alien_active,x
    beq sc_ca_next
    jsr erase_alien_x
    lda #0
    sta alien_active,x
    sta alien_exploding,x
sc_ca_next:
    inx
    cpx #ALIEN_COUNT
    bne sc_clear_aliens

    ldx #0
sc_clear_bullets:
    lda bullet_active,x
    beq sc_cb_next
    jsr draw_bullet_x
    lda #0
    sta bullet_active,x
sc_cb_next:
    inx
    cpx #BULLET_COUNT
    bne sc_clear_bullets

    ldx #0
sc_clear_abullets:
    lda alien_bullet_active,x
    beq sc_cab_next
    jsr draw_alien_bullet_x
    lda #0
    sta alien_bullet_active,x
sc_cab_next:
    inx
    cpx #ALIEN_BULLET_COUNT
    bne sc_clear_abullets

    jsr redraw_lives_after_loss

    lda #2                      ; tune 2 = Lost a Life
    jsr start_tune

    lda #0
    sta ship_explode_count
    sta ship_explode_timer      ; frame index, counts UP - see ship_explode_tick
    lda #GS_SHIP_EXPLODING
    sta game_state
    rts

; ship_explode_tick_throttled: called every game_loop frame while
; GS_SHIP_EXPLODING - throttles the raw flicker (see alien_explode_tick,
; same idea) so it's visible rather than a single-frame blur, then, once
; ship_explode_tick has decided the animation is over, leaves game_state
; at either GS_PLAYING (respawned) or GS_GAME_OVER for game_loop itself
; to act on (game_loop does the "jmp title_wait_loop" - see
; game_loop_escape - keeping this call one JSR level shallower than a
; jump-away-from-here would, so the stack stays balanced across many
; games in one sitting).
ship_explode_tick_throttled:
    inc ship_explode_count
    lda ship_explode_count
    cmp #SHIP_EXPLODE_SLOWDOWN
    bcc sett_rts
    lda #0
    sta ship_explode_count
    jsr ship_explode_tick
sett_rts:
    rts

ship_explode_tick:
    lda ship_explode_timer
    cmp #EXPLOSION_FRAME_COUNT
    bcs she_finish
    sta explosion_frame_num
    lda ship_col
    jsr compute_ship_addrs
    jsr draw_explosion_here
    inc ship_explode_timer
    rts
she_finish:
    jsr erase_ship
    lda lives_count
    beq she_over
    lda #SHIP_START_COL
    sta ship_col
    lda #SHIP_START_ROW
    sta ship_row
    jsr draw_ship
    jsr init_alien_wave
    lda #GS_PLAYING
    sta game_state
    rts
she_over:
    lda #3                      ; tune 3 = Game Over
    jsr start_tune
    lda #GS_GAME_OVER
    sta game_state
    rts

; --- Collision detection. All three checks work in cell coordinates -
; the same grid alien_disp_col/row, ship_col/row and bullet_row/col are
; already drawn from, not a separate physics space - so a future pass
; that needs real per-cell ownership (to also fix the deferred stuck-star
; and alien-overlap-flicker bugs) can build on these exact box tests
; rather than a new coordinate system.
;
; check_bullet_alien_collisions: each active player bullet (a single
; cell) against each active, not-already-exploding alien's 3-wide x
; 2-tall footprint (alien_disp_col/row - the DISPLAYED position, matching
; what's actually on screen). On a hit: erase the bullet, dock one
; alien_hp; at 0, award alien_score_table[type] and start the alien's own
; explosion (see alien_explode_tick) rather than deactivating outright.
check_bullet_alien_collisions:
    ldx #0
cbac_bullet_loop:
    lda bullet_active,x
    beq cbac_next_bullet
    ldy #0
cbac_alien_loop:
    lda alien_active,y
    beq cbac_next_alien
    lda alien_exploding,y
    bne cbac_next_alien

    lda bullet_col,x
    cmp alien_disp_col,y
    bcc cbac_next_alien
    sec
    sbc alien_disp_col,y
    cmp #3
    bcs cbac_next_alien

    lda bullet_row,x
    cmp alien_disp_row,y
    bcc cbac_next_alien
    sec
    sbc alien_disp_row,y
    cmp #2
    bcs cbac_next_alien

    sty cbac_saved_y         ; draw_bullet_x uses Y as its own 0-7 byte-
    jsr draw_bullet_x         ; loop counter and never restores it - left
    ldy cbac_saved_y          ; uncorrected, every alien_hp/alien_exploding/
                               ; alien_type write just below would land on
                               ; whatever slot Y=8 happens to be (one past
                               ; the end of these ALIEN_COUNT=8 arrays),
                               ; corrupting adjacent memory on every kill
    lda #0
    sta bullet_active,x
    lda alien_hp,y          ; DEC has no absolute,Y mode - load/sub/store
    sec
    sbc #1
    sta alien_hp,y
    bne cbac_next_bullet

    lda #1
    sta alien_exploding,y
    lda #0
    sta alien_explode_timer,y   ; frame index, counts UP - see alien_explode_tick

    stx cbac_saved_x
    lda alien_type,y
    tax
    lda alien_score_table,x
    jsr add_score
    ldx cbac_saved_x
    jmp cbac_next_bullet

cbac_next_alien:
    iny
    cpy #ALIEN_COUNT
    bne cbac_alien_loop
cbac_next_bullet:
    inx
    cpx #BULLET_COUNT
    bne cbac_bullet_loop
    rts
cbac_saved_x:
 .byte 0
cbac_saved_y:
 .byte 0

; check_alien_bullet_ship_collision: each active alien bullet (a single
; cell) against the ship's 3x2 footprint. On a hit, erases the bullet and
; hands off to ship_crash - stops scanning immediately after (ship_crash
; already cleared this whole pool anyway).
check_alien_bullet_ship_collision:
    ldx #0
cabs_loop:
    lda alien_bullet_active,x
    beq cabs_next
    lda alien_bullet_col,x
    cmp ship_col
    bcc cabs_next
    sec
    sbc ship_col
    cmp #3
    bcs cabs_next
    lda alien_bullet_row,x
    cmp ship_row
    bcc cabs_next
    sec
    sbc ship_row
    cmp #2
    bcs cabs_next
    jsr draw_alien_bullet_x
    lda #0
    sta alien_bullet_active,x
    jsr ship_crash
    rts
cabs_next:
    inx
    cpx #ALIEN_BULLET_COUNT
    bne cabs_loop
    rts

; check_alien_ship_collision: direct alien-vs-ship contact, each active,
; not-already-exploding alien's 3x2 footprint against the ship's own
; (both the same size, so a plain absolute-difference test on each axis
; is enough - see the two negate-if-negative blocks below).
check_alien_ship_collision:
    ldx #0
cas_loop:
    lda alien_active,x
    beq cas_next
    lda alien_exploding,x
    bne cas_next

    lda alien_disp_col,x
    sec
    sbc ship_col
    bcs cas_col_pos
    eor #$FF
    clc
    adc #1
cas_col_pos:
    cmp #3
    bcs cas_next

    lda alien_disp_row,x
    sec
    sbc ship_row
    bcs cas_row_pos
    eor #$FF
    clc
    adc #1
cas_row_pos:
    cmp #2
    bcs cas_next

    jsr ship_crash
    rts
cas_next:
    inx
    cpx #ALIEN_COUNT
    bne cas_loop
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

    ; star_hidden must also reset here: a star evicted (hidden) by a ship/
    ; alien that was still on screen the moment clear_screen ran would
    ; otherwise stay marked hidden forever after - nothing else ever
    ; clears it (star_restore_range only fires when the object that
    ; covered it erases a now-uncovered cell, and after a full screen
    ; wipe there's no object left to do that) - so movestars would skip
    ; drawing that star for the rest of the program's life. A fresh
    ; screen has nothing covering anything, so every star starts unhidden.
    lda #0
    ldx #0
csh_loop:
    sta star_hidden,x
    inx
    cpx #(3*31)
    bne csh_loop
    rts

; process_demo: matches ROUT3.asm's own process_demo - only does anything
; while demo_flag is set, and even then only every demo_count frames:
; picks a fresh random left/right direction (demo_direction, its bit7 -
; checked the same way BBC checks BMI/BPL - is all handle_ship_input's
; demo branch below reads) and a new randomized count (10-25) until the
; next change, straight from "LDArand1+1:STAdemo_direction /
; AND#15:ADC#10:STAdemo_count" - reusing rand1+1 directly rather than a
; fresh JSR rand call, same as the source.
process_demo:
    lda demo_flag
    beq pd_done
    dec demo_count
    bne pd_done
    lda rand1+1
    sta demo_direction
    and #15
    clc
    adc #10
    sta demo_count
pd_done:
    rts

; demo_fire_count/demo_process_fire: demo mode has no key to edge-detect
; (BOMBS1.asm's demo branch skips the key/joystick read entirely and
; just fires whenever off cooldown), so this just tries to spawn a
; bullet every DEMO_FIRE_INTERVAL frames while demo_flag is set -
; spawn_player_bullet itself is a no-op if the pool's already full, same
; as the real cooldown BOMBS1.asm's bombdel provides.
DEMO_FIRE_INTERVAL = 20
demo_fire_count:
 .byte 0

demo_process_fire:
    lda demo_flag
    beq dpf_done
    inc demo_fire_count
    lda demo_fire_count
    cmp #DEMO_FIRE_INTERVAL
    bcc dpf_done
    lda #0
    sta demo_fire_count
    jsr spawn_player_bullet
dpf_done:
    rts

; --- Music: real BBC tune data (Martin Galway - also a well-known C64
; SID composer), ported to actual SID playback. BBC call sites traced
; directly: StartTune/Refresh/MusicTest (src/MUSIC1.asm), mksound (not
; decoded this pass - see mk_sound below). The BBC engine is entirely
; OS-mediated (OSWORD calls into a software envelope player); SID has no
; such OS, so this is a real from-scratch 3-voice player, but the DATA
; driving it - which notes, which tempo, which envelope shape - is the
; real thing, not invented:
;
; - Note streams (c64_strt1-3/c64_zone1-3/c64_lost1-3/c64_over1-2, below)
;   are byte-for-byte the same encoding BBC uses (bits 0-5 = pitch index
;   0-62, 63=rest; bits 6-7 = a 2-bit "duration class" selecting one of
;   4 tune-specific tempo values) - transcribed directly from
;   src/MUSIC1-3.asm's EQUB data (Dn/Rest constants expanded via a
;   script, not by hand, to avoid transcription slips), covering Game
;   Start, Zone/wave, Lost a Life and Game Over (the 4 tunes reachable
;   right now - Between Levels and the demo-section tunes are real data
;   too, just not wired to a call site yet).
; - Each tune's real tempo (music_spd), envelope choice (music_env) and
;   note-duration (music_dur) were read off by tracing src/MUSIC1.asm's
;   StartTune loop instruction-by-instruction against src/MUSIC3.asm's
;   .LT table (which byte-offset window each tune's stored index
;   actually selects), not assumed from the source's own comments -
;   those turned out to disagree in places (e.g. "Game Over"'s speed
;   index really selects the row commented "Game Start", and Zone reuses
;   Lost-a-Life's tempo) - the code's actual behavior wins over the
;   comment every time here.
; - music_env_ad/music_env_sr map each of the 9 real envelope numbers
;   (src's ENVELOPE statements, found in bas_extra/LOADER.bas.txt - a
;   file not touched until this pass) to SID Attack/Decay/Sustain/
;   Release nibbles: computed each envelope's real attack/decay/release
;   time in milliseconds from its amplitude rate+target parameters
;   (verified against BBC BASIC's own ENVELOPE parameter semantics),
;   then picked the closest matching SID 6581 hardware rate (its own
;   documented Attack/Decay-Release tables). This maps the AMPLITUDE
;   side of each envelope only - all 9 also have a real, non-zero PITCH
;   envelope (a pitch-bend component BBC's engine applies independently
;   of the note's own pitch) that isn't implemented yet; every envelope
;   here plays as a plain ADSR shape at the note's own fixed pitch.
; - music_freq_lo/hi (pitch index 0-62 -> SID 16-bit frequency register)
;   comes from BBC's own documented SOUND behavior (pitch 53 = middle C,
;   4 units = 1 semitone; the game scales each note by 4 before it would
;   reach SOUND, so a raw note index is directly a linear semitone
;   count) combined with standard equal-temperament tuning and the
;   standard SID PAL frequency-register formula - no BBC-specific
;   guessing needed for this table, just verified formulas. Indices
;   60-62 would overflow the 16-bit register and are clamped to $FFFF;
;   none of the 4 ported tunes reach past note 52, so this never
;   triggers yet.
;
; mk_sound (one-off effects - fire/explosion) is NOT decoded from real
; data this pass (that's BOMBS1.asm/ROUT2.asm/ROUT3.asm's own mksound
; call sites and effect tables - out of scope here, same as the BBC
; explosion graphic was before it got a real decode) and is currently a
; no-op, not an approximate blip - an earlier version played a fixed
; blip on channel 2, but firing that on every shot retriggered channel
; 2's envelope constantly, hijacking that channel's actual music part
; and contributing real audible clicking - see mk_sound's own comment.

MUSIC_CHANNELS = 3

music_pat_lo:
 .res MUSIC_CHANNELS
music_pat_hi:
 .res MUSIC_CHANNELS
music_pat_off:
 .res MUSIC_CHANNELS
music_cnt:
 .res MUSIC_CHANNELS
music_env:
 .res MUSIC_CHANNELS
music_dur:
 .res MUSIC_CHANNELS
music_gate_cnt:
 .res MUSIC_CHANNELS
music_stopped:
 .res MUSIC_CHANNELS
music_spd:
 .res 4
music_tune_off:
 .byte 0
music_last_byte:
 .byte 0
music_note_chan:
 .byte 0
music_note_freq_lo:
 .byte 0
music_note_freq_hi:
 .byte 0
music_voice_lo:
 .byte 0
music_voice_hi:
 .byte 0

music_voice_base_lo:
 .byte <$D400,<$D407,<$D40E
music_voice_base_hi:
 .byte >$D400,>$D407,>$D40E

; music_env_ad/sr: envelope N is stored at index N-1 (envelopes are
; numbered 1-9 in the source). hi nibble=Attack, lo nibble=Decay (AD);
; hi nibble=Sustain level 0-15, lo nibble=Release (SR).
music_env_ad:
 .byte $00,$18,$56,$99,$28,$00,$49,$38,$35
music_env_sr:
 .byte $00,$21,$B9,$8A,$A9,$70,$58,$48,$B7

; music_freq_lo/hi: pitch index 0-62 -> SID frequency register (PAL).
; See the file header above for the derivation.
music_freq_lo:
 .byte $18,$94,$16,$A0,$33,$CE,$73,$21,$DA,$9D,$6D,$48,$31,$27,$2C,$41
 .byte $66,$9D,$E6,$42,$B3,$3B,$D9,$90,$61,$4E,$59,$82,$CC,$39,$CB,$84
 .byte $67,$75,$B2,$20,$C3,$9D,$B1,$04,$98,$72,$96,$08,$CD,$EA,$64,$41
 .byte $86,$3A,$63,$08,$30,$E5,$2C,$11,$9B,$D5,$C9,$82,$FF,$FF,$FF
music_freq_hi:
 .byte $08,$08,$09,$09,$0A,$0A,$0B,$0C,$0C,$0D,$0E,$0F,$10,$11,$12,$13
 .byte $14,$15,$16,$18,$19,$1B,$1C,$1E,$20,$22,$24,$26,$28,$2B,$2D,$30
 .byte $33,$36,$39,$3D,$40,$44,$48,$4D,$51,$56,$5B,$61,$66,$6C,$73,$7A
 .byte $81,$89,$91,$9A,$A3,$AC,$B7,$C2,$CD,$D9,$E6,$F4,$FF,$FF,$FF

; music_tune_table: 4 tunes x 16 bytes (ch0 lo/hi, ch1 lo/hi, ch2 lo/hi,
; spd[0-3], env[0-2], dur[0-2]) - see start_tune for the layout, and the
; file header above for where each value came from.
MUSIC_TUNE_STRIDE = 16
music_tune_table:
; tune 0: Game Start
 .word c64_strt1, c64_strt2, c64_strt3
 .byte 4,8,12,16
 .byte 6,6,6
 .byte 5,3,2
; tune 1: Zone/wave
 .word c64_zone1, c64_zone2, c64_zone3
 .byte 5,10,15,20
 .byte 6,6,6
 .byte 5,3,2
; tune 2: Lost a Life
 .word c64_lost1, c64_lost2, c64_lost3
 .byte 5,10,15,20
 .byte 5,6,7
 .byte 10,1,1
; tune 3: Game Over
 .word c64_over1, c64_over2, c64_lost2
 .byte 4,8,12,16
 .byte 8,8,8
 .byte 5,3,2

c64_strt1:
 .byte $88,$08,$48,$88,$08,$C8,$48,$48,$48,$48,$48,$8B
 .byte $0B,$4B,$8B,$0B,$CB,$4D,$4D,$4D,$4D,$4D,$08,$00
c64_strt2:
 .byte $8B,$0B,$4B,$8B,$0B,$CB,$4B,$4B,$4B,$4B,$4B,$8F
 .byte $0F,$4F,$8F,$0F,$CF,$51,$51,$51,$51,$51,$0B,$00
c64_strt3:
 .byte $8F,$0F,$4F,$8F,$0F,$CF,$4F,$4F,$4F,$4F,$4F,$92
 .byte $12,$52,$92,$12,$D2,$54,$54,$54,$54,$54,$0F,$00

c64_zone1:
 .byte $48,$48,$14,$48,$08,$48,$48,$14,$48,$08,$4B,$4B
 .byte $12,$4B,$0B,$4B,$4B,$12,$4B,$0B,$4D,$4D,$14,$4D
 .byte $0D,$4D,$4D,$14,$4D,$0D,$50,$50,$14,$50,$10,$50
 .byte $50,$14,$50,$10,$00
c64_zone2:
 .byte $03,$08,$0B,$0F,$14,$0F,$0B,$08,$03,$08,$0B,$0F
 .byte $14,$0F,$0B,$08,$03,$06,$0B,$0F,$12,$0F,$0B,$06
 .byte $03,$06,$0B,$0F,$12,$0F,$0B,$06,$04,$08,$0D,$10
 .byte $14,$10,$0D,$08,$04,$08,$0D,$10,$14,$10,$0D,$08
 .byte $04,$08,$0B,$10,$14,$10,$0B,$08,$04,$08,$0B,$10
 .byte $14,$10,$0B,$08,$3F,$00
c64_zone3:
 .byte $60,$A0,$60,$1E,$60,$A0,$1B,$1E,$20,$63,$A3,$63
 .byte $1E,$63,$A3,$1E,$20,$23,$65,$A5,$65,$25,$65,$A5
 .byte $65,$24,$63,$A3,$63,$22,$63,$23,$22,$23,$25,$23
 .byte $22,$00

c64_lost1:
 .byte $73,$74,$73,$71,$73,$71,$6F,$6E,$EC,$E7,$20,$00
c64_lost2:
 .byte $33,$2F,$2C,$27,$2F,$2C,$27,$23,$2C,$27,$23,$20
 .byte $27,$23,$20,$1B,$23,$20,$1B,$17,$1B,$19,$17,$16
 .byte $14,$08,$08,$08,$08,$00
c64_lost3:
 .byte $C8,$D4,$48,$48,$D4,$48,$48,$54,$48,$48,$00

c64_over1:
 .byte $7F,$00
c64_over2:
 .byte $7F,$00

; start_tune: A = tune index (0-3). Resets all 3 channels to the start
; of the chosen tune's note streams, loads its tempo/envelope/duration
; values, silences all 3 SID voices, and sets a fixed pulse waveform
; width + master volume (idempotent - harmless to redo on every call).
start_tune:
    asl a
    asl a
    asl a
    asl a
    sta music_tune_off

    ldy music_tune_off
    lda music_tune_table,y
    sta music_pat_lo+0
    iny
    lda music_tune_table,y
    sta music_pat_hi+0
    iny
    lda music_tune_table,y
    sta music_pat_lo+1
    iny
    lda music_tune_table,y
    sta music_pat_hi+1
    iny
    lda music_tune_table,y
    sta music_pat_lo+2
    iny
    lda music_tune_table,y
    sta music_pat_hi+2
    iny
    lda music_tune_table,y
    sta music_spd+0
    iny
    lda music_tune_table,y
    sta music_spd+1
    iny
    lda music_tune_table,y
    sta music_spd+2
    iny
    lda music_tune_table,y
    sta music_spd+3
    iny
    lda music_tune_table,y
    sta music_env+0
    iny
    lda music_tune_table,y
    sta music_env+1
    iny
    lda music_tune_table,y
    sta music_env+2
    iny
    lda music_tune_table,y
    sta music_dur+0
    iny
    lda music_tune_table,y
    sta music_dur+1
    iny
    lda music_tune_table,y
    sta music_dur+2

    ldx #0
stt_reset_loop:
    lda #0
    sta music_pat_off,x
    sta music_stopped,x
    sta music_gate_cnt,x
    lda #1
    sta music_cnt,x            ; forces an immediate note read on this
                                 ; channel's first refresh_music tick
    inx
    cpx #MUSIC_CHANNELS
    bne stt_reset_loop

    lda #0
    sta $D404
    sta $D40B
    sta $D412
    lda #$08
    sta $D402
    sta $D409
    sta $D410
    lda #$0F
    sta $D418
    rts

; refresh_music: called once per game_loop frame. Per channel: counts
; down any note currently sounding to its release point (music_gate_cnt,
; from the tune's own DURATAB-derived value), then counts down to the
; next note read (music_cnt, from the tune's own tempo table via each
; note's 2-bit duration class) - matches src/MUSIC1.asm's .Refresh
; structure (two independent countdowns per channel, not one).
refresh_music:
    ldx #0
rm_chan_loop:
    lda music_stopped,x
    bne rm_next_chan

    lda music_gate_cnt,x
    beq rm_check_note
    dec music_gate_cnt,x
    bne rm_check_note
    jsr music_gate_off

rm_check_note:
    dec music_cnt,x
    bne rm_next_chan

    jsr music_read_note
    lda music_stopped,x
    bne rm_next_chan

    lda music_last_byte
    and #$3F
    cmp #63
    beq rm_reschedule           ; a rest - no sound, just reschedule below
    jsr music_note_on

rm_reschedule:
    lda music_last_byte
    rol a
    rol a
    rol a
    and #3
    tay
    lda music_spd,y
    sta music_cnt,x

rm_next_chan:
    inx
    cpx #MUSIC_CHANNELS
    bne rm_chan_loop
    rts

; music_read_note: X = channel. Reads the next byte from that channel's
; note stream into music_last_byte and advances music_pat_off,X: a 0
; byte means the stream has ended (matches the source - it just goes
; silent and stays there, no auto-loop), setting music_stopped,X instead
; of advancing further. Preserves X.
music_read_note:
    lda music_pat_lo,x
    sta screen
    lda music_pat_hi,x
    sta screen+1
    ldy music_pat_off,x
    lda (screen),y
    beq mrn_stop
    sta music_last_byte
    inc music_pat_off,x
    rts
mrn_stop:
    lda #1
    sta music_stopped,x
    rts

; music_note_on: X = channel, A = pitch index (0-62). Writes this
; channel's SID voice frequency, ADSR (from its tune-assigned envelope),
; and gates the note on; reloads music_gate_cnt,X from music_dur,X (the
; tune's own fixed note-length). Preserves X (via music_note_chan).
music_note_on:
    stx music_note_chan
    tay
    lda music_freq_lo,y
    sta music_note_freq_lo
    lda music_freq_hi,y
    sta music_note_freq_hi

    ldx music_note_chan
    lda music_voice_base_lo,x
    sta music_voice_lo
    sta screen
    lda music_voice_base_hi,x
    sta music_voice_hi
    sta screen+1

    ldy #0
    lda music_note_freq_lo
    sta (screen),y
    ldy #1
    lda music_note_freq_hi
    sta (screen),y

    ldx music_note_chan
    lda music_env,x
    sec
    sbc #1
    tay
    lda music_env_ad,y
    pha
    lda music_env_sr,y
    tax
    ldy #5
    pla
    sta (screen),y
    ldy #6
    txa
    sta (screen),y

    ; Gate off THEN on, always - a note's own music_gate_cnt duration is
    ; often shorter than the tune's tempo (the next note is frequently
    ; due before the previous one's release finished), so the gate can
    ; already be high when this runs. SID only restarts the attack phase
    ; on a real 0->1 transition; writing $41 unconditionally when it was
    ; already 1 is a no-op for the envelope (only the frequency would
    ; actually change), which is most of what the reported "clicks and
    ; pops" were - not a clean new note each time, just the previous
    ; one's envelope carrying on under a jumped pitch.
    ldy #4
    lda #$40                    ; pulse waveform, gate off
    sta (screen),y
    lda #$41                    ; same waveform, gate on
    sta (screen),y

    ldx music_note_chan
    lda music_dur,x
    sta music_gate_cnt,x
    rts

; music_gate_off: X = channel. Clears the gate bit only (same waveform),
; triggering the SID envelope's release phase. Preserves X.
music_gate_off:
    lda music_voice_base_lo,x
    sta screen
    lda music_voice_base_hi,x
    sta screen+1
    lda #$40
    ldy #4
    sta (screen),y
    rts

; mk_sound: NOT decoded from real BBC effect data this pass (see the
; file header above) - a small fixed blip on channel 2, borrowing it
; briefly from whatever music note is playing there, so bullet-fire has
; some audible feedback. A is accepted but unused for now (reserved for
; a future per-effect table).
; mk_sound: back to a no-op for now. It was previously a fixed blip on
; channel 2, but firing on every single shot (demo mode's auto-fire
; alone is ~3/sec) meant it was retriggering channel 2's envelope that
; often too, constantly hijacking that channel's actual music part -
; a real, understood contributor to "clicks and pops" on top of the
; gate-retrigger bug fixed above. Since it was never claiming to be
; real decoded data anyway (see the file header), silence is more
; honest than noise that fights the music - revisit once BOMBS1.asm's
; real effect data gets the same treatment the tunes did.
mk_sound:
    rts

; music_test: Z flag clear (BNE taken by caller) while any channel is
; still playing; Z set once all 3 have hit their stream's end.
music_test:
    lda music_stopped+0
    beq mt_playing
    lda music_stopped+1
    beq mt_playing
    lda music_stopped+2
    beq mt_playing
    lda #0
    rts
mt_playing:
    lda #1
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

; clear_one_lifeicon: A = starting column of a 2-cell-wide life icon,
; reset to plain star-field background - same addressing as
; draw_one_lifeicon, just background values instead of the graphic.
; draw_lives_icons only ever draws lives_count icons from LIVES_RIGHT_COL
; leftward, so a life lost only ever needs the ONE icon that just fell
; off the drawn range cleared (see redraw_lives_after_loss) - the
; opposite of draw_level_flags below, which only ever grows and so never
; needs clearing at all.
clear_one_lifeicon:
    sta temp1

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

    lda #0
    ldy #0
col_left:
    sta (temp3),y
    iny
    cpy #8
    bne col_left

    lda temp3
    clc
    adc #8
    sta temp3
    lda temp3+1
    adc #0
    sta temp3+1
    lda #0
    ldy #0
col_right:
    sta (temp3),y
    iny
    cpy #8
    bne col_right

    lda temp1
    clc
    adc #<($4000+LIVES_ROW*40)
    sta temp4
    lda #0
    adc #>($4000+LIVES_ROW*40)
    sta temp4+1
    lda #$73
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
    lda #4
    ldy #0
    sta (temp2),y
    ldy #1
    sta (temp2),y
    rts

; redraw_lives_after_loss: called right after lives_count has been
; decremented - blanks the one icon draw_lives_icons no longer draws.
; Icons are drawn right-to-left from LIVES_RIGHT_COL, 2 cells apart, so
; the icon at index lives_count (0-based from the right) is the one that
; just dropped out of range; its column is LIVES_RIGHT_COL - 2*lives_count
; using the POST-decrement count - this also correctly handles the
; last-life-lost case (lives_count=0 -> column = LIVES_RIGHT_COL, the
; icon that WAS the last one showing).
redraw_lives_after_loss:
    lda #LIVES_RIGHT_COL
    sec
    sbc lives_count
    sec
    sbc lives_count
    jsr clear_one_lifeicon
    rts

; draw_title_screen: the full title screen's text content (GALAFORCE
; letters, score bar, body text, KS indicator, level flags) - NOT stars
; (star_init is a separate call at each use site, since the high-score
; cycle re-inits stars fresh too rather than carrying the title's over)
; and NOT clear_screen (callers clear first). Factored out of exec so
; the title-wait/high-score/demo cycle (see title_wait_loop) can redraw
; the title after cycling back from the high-score screen, not just once
; at boot.
draw_title_screen:
    ; GALAFORCE, 3x2 cells/letter (double width, double height - see
    ; blit_title_char), red, rows 4-5. 9 letters x 3 cells = 27 cells;
    ; (40-27)/2 = 6 start col, centering it same as before. col*8 (max
    ; 30*8=240) still fits in one byte, and since $6500's low byte is 0,
    ; adding col*8 to it never carries - temp3's high byte stays $65.
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
    jsr draw_ks_indicator
    jsr draw_level_flags
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

; --- Live scoring ---
; score_digits: unpacked decimal digits, index 0 = TENS place, index 1 =
; hundreds, index 2 = thousands, index 3 = ten-thousands. ROUT3.asm's own
; alien_score table is documented "divided by ten" - every alien's award
; is a multiple of ten, so there's no real units digit to track; it's
; just always displayed as a fixed trailing "0" (see score_glyphs below).
; Column layout: SCORE_VALUE_COL/HI_COL/HISCORE_COL below replace the
; original score_bar_table's tighter spacing (that had only a 1-char
; placeholder where the real 5-char field now goes).
score_digits:
 .byte 0,0,0,0
score_glyphs:
 .byte 1,1,1,1,1,$FF       ; "00000" initially - kept in sync with
                             ; score_digits by add_score, not .res'd zero
                             ; (glyph code 0 is blank, not the digit "0")

SCORE_VALUE_COL = 8
HI_COL          = 17
HISCORE_COL     = 22

; add_score: A = an alien_score_table value (0-9, source's own "divided
; by ten" units) to add. Ripples a carry through score_digits like a
; plain 4-digit decimal counter (capping rather than wrapping if it ever
; overflows - out of display room, not a real game-breaking case), then
; rebuilds score_glyphs and redraws just that fixed-position/fixed-width
; field - no erase needed, unlike a moving object.
add_score:
    clc
    adc score_digits
    cmp #10
    bcc as_store0
    sbc #10
    sta score_digits
    inc score_digits+1
    lda score_digits+1
    cmp #10
    bcc as_rebuild
    lda #0
    sta score_digits+1
    inc score_digits+2
    lda score_digits+2
    cmp #10
    bcc as_rebuild
    lda #0
    sta score_digits+2
    inc score_digits+3
    lda score_digits+3
    cmp #10
    bcc as_rebuild
    lda #9
    sta score_digits+3
    jmp as_rebuild
as_store0:
    sta score_digits
as_rebuild:
    lda score_digits+3
    clc
    adc #1
    sta score_glyphs
    lda score_digits+2
    clc
    adc #1
    sta score_glyphs+1
    lda score_digits+1
    clc
    adc #1
    sta score_glyphs+2
    lda score_digits
    clc
    adc #1
    sta score_glyphs+3
    jmp redraw_score

redraw_score:
    lda #<score_glyphs
    sta temp2
    lda #>score_glyphs
    sta temp2+1
    lda #<($6000+SCORE_VALUE_COL*8)
    sta temp3
    lda #>($6000+SCORE_VALUE_COL*8)
    sta temp3+1
    lda #<($4000+SCORE_VALUE_COL)
    sta temp4
    lda #>($4000+SCORE_VALUE_COL)
    sta temp4+1
    lda #7                   ; yellow, matches the old placeholder's color
    sta colour
    jmp print_bitmap_line

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
    cpx #(4*7)
    bne dbt_loop
    rts

; draw_ks_indicator: the "K"/"S" key-or-joystick hint, title screen AND
; gameplay (BBC shows it during play too - see display_key_joy_status).
; K and S are two separate table entries (two separate strings), not one
; "KS" string, so they can have different colors: with the tight sub-
; cell spacing, letters within ONE string can share a cell (see
; print_bitmap_line), which would force them to the same color. Drawing
; them separately, each starting fresh at color-pixel offset 0, keeps
; their own spacing unchanged - S just starts 2 cells after K (K's own
; span), the minimum gap that avoids sharing a cell, not extra space
; added.
draw_ks_indicator:
    ldx #0
dks_loop:
    lda ks_table,x
    sta temp2
    lda ks_table+1,x
    sta temp2+1
    lda ks_table+2,x
    sta temp3
    lda ks_table+3,x
    sta temp3+1
    lda ks_table+4,x
    sta temp4
    lda ks_table+5,x
    sta temp4+1
    lda ks_table+6,x
    sta colour
    stx dtt_saved_x
    jsr print_bitmap_line
    ldx dtt_saved_x
    txa
    clc
    adc #7
    tax
    cpx #(2*7)
    bne dks_loop
    rts

; draw_high_score_table: the placeholder table (see str_hs_title/str_hs1-5
; above) - callers clear_screen first, same convention as draw_title_screen.
draw_high_score_table:
    ldx #0
dhs_loop:
    lda high_score_table,x
    sta temp2
    lda high_score_table+1,x
    sta temp2+1
    lda high_score_table+2,x
    sta temp3
    lda high_score_table+3,x
    sta temp3+1
    lda high_score_table+4,x
    sta temp4
    lda high_score_table+5,x
    sta temp4+1
    lda high_score_table+6,x
    sta colour
    stx dtt_saved_x
    jsr print_bitmap_line
    ldx dtt_saved_x
    txa
    clc
    adc #7
    tax
    cpx #(6*7)
    bne dhs_loop
    rts

; Positions below (rows 6/9/11/13/15/17, cols 12-14) are a first guess,
; not measured against anything - confirmed needing adjustment once
; there's a look at it alongside the score bar/flags/lives it now shares
; the screen with.
high_score_table:
    .word str_hs_title, $6000+(6*40+14)*8,  $4000+6*40+14
    .byte 7                                              ; yellow
    .word str_hs1,       $6000+(9*40+12)*8,  $4000+9*40+12
    .byte 3                                              ; cyan
    .word str_hs2,       $6000+(11*40+12)*8, $4000+11*40+12
    .byte 3
    .word str_hs3,       $6000+(13*40+12)*8, $4000+13*40+12
    .byte 3
    .word str_hs4,       $6000+(15*40+12)*8, $4000+15*40+12
    .byte 3
    .word str_hs5,       $6000+(17*40+12)*8, $4000+17*40+12
    .byte 3

score_bar_table:
    .word str_scr,      $6000+3*8,               $4000+3
    .byte 4                                              ; magenta
    .word score_glyphs, $6000+SCORE_VALUE_COL*8,  $4000+SCORE_VALUE_COL
    .byte 7                                              ; yellow
    .word str_hi,       $6000+HI_COL*8,           $4000+HI_COL
    .byte 4
    .word str_hiscore,  $6000+HISCORE_COL*8,      $4000+HISCORE_COL
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

ks_table:
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

    ; Evict any star from the 2 cells this letter is about to ORA bits
    ; into (temp3 = current cell, temp3+8 = next cell - see the file
    ; header above on why letters ORA rather than overwrite). Text is
    ; drawn with ORA, never erased/reset the way a moving object is, so
    ; without this a star wandering through (stars cover the whole
    ; screen, including the HUD rows - see STARS.asm's own header) would
    ; get an odd bit permanently ORA'd into the letter every time it
    ; happened to be there, which is what was making repeated digits
    ; (e.g. the score's "00000") look different from each other instead
    ; of identical. A star evicted here stays hidden until the next
    ; clear_screen (text never moves away to naturally uncover it, same
    ; as a fixed HUD element) - see clear_screen's own star_hidden reset.
    lda temp3
    sta sce_range_lo
    lda temp3+1
    sta sce_range_hi
    lda #16
    sta sce_range_len
    jsr star_evict_range

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

; Placeholder high-score table text - HIGH.asm's real one (hsnum/hstxt,
; up to 10-char names + 7-digit scores, ahigh/pht) reads and writes
; persistent score data we don't have yet ("no persistent storage yet -
; separate concern" per the demo-mode plan). These are fixed strings
; standing in for that until scoring itself exists.
str_hs_title:
    .byte 18,19,17,18,0,29,13,25,28,15,29,$FF        ; HIGH SCORES
str_hs1:
    .byte 2,0,21,15,32,0,2,1,1,1,1,1,$FF              ; 1 KEV 100000
str_hs2:
    .byte 3,0,29,31,26,0,1,9,1,1,1,1,$FF              ; 2 SUP 080000
str_hs3:
    .byte 4,0,13,7,5,0,1,7,1,1,1,1,$FF                ; 3 C64 060000
str_hs4:
    .byte 5,0,11,11,11,0,1,5,1,1,1,1,$FF              ; 4 AAA 040000
str_hs5:
    .byte 6,0,12,12,12,0,1,3,1,1,1,1,$FF              ; 5 BBB 020000

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
