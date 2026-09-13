;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;
;; C64 port - moving star field for the C64 multicolor bitmap screen (see INIT.asm's
;; file header for the overall bitmap-mode architecture).
;;
;; This is NOT a line-by-line port of the BBC routine below it used to be.
;; The original BBC code addresses screen memory via 6502 indexed-indirect
;; ((stardat,X)) addressing, which requires the stardat pointer table to
;; live in zero page - noted back when stardat was first declared here as
;; not fitting in zero page on the C64 (see Master-c64.mak.asm). Without
;; that trick the BBC address-arithmetic (the EOR #$40 / ADC #$79 / AND
;; #$F8 dance in its old movestars) doesn't carry over either - that was
;; exploiting specifics of BBC MODE 2's screen address layout. The C64's
;; bitmap layout is simpler (flat $6000-$7F3F, 8 bytes/cell, 40 cells/row,
;; row stride 320 bytes), so the replacement logic below is more direct.
;;
;; Each star is (screen address lo/hi, XOR-plot byte) in stardat, same
;; layout BBC used, but dereferenced via a zero-page scratch pointer
;; (temp3) copied in per star rather than requiring stardat itself to be
;; zero page. Falling is a screen-address walk: +1 per frame (one
;; scanline down within the current 8-scanline column-block), or +313
;; when the low 3 bits of the address hit 7 (bottom of the block) to jump
;; to the same column one character-row down (320 - 7 = 313). A parallel
;; star_rowcnt byte per star (reusing the same 3-slot stride as stardat,
;; for simplicity) counts rows moved since spawn so movestars knows when
;; a star has fallen through the bottom of the band and should respawn at
;; the top, without ever having to decode a row/column back out of a raw
;; address.
;;
;; Only 3 non-background colors are available at once (screen-matrix
;; hi-nibble/lo-nibble + color RAM low-nibble - see the background-clear
;; setup in INIT.asm's exec), so each star occupies one fixed pixel slot
;; within its byte (0-3, i.e. one of the 4 color-pixels a byte holds -
;; chosen once at spawn and kept for the star's whole life, see
;; star_pick_slot/star_slot) and shows a color PATTERN there that is
;; re-rolled periodically (star_pick_pattern), including going to 0
;; (black/background - a "twinkle off"). Keeping the slot fixed and only
;; changing the pattern is what keeps a falling star's on-screen column
;; steady - re-picking the slot every frame is what earlier made stars
;; visibly jump sideways as they fell.
;;
;; rand (below) is the same generator BOMBS/ALIENS use elsewhere and is
;; left untouched, but on its own it produces a visibly correlated
;; sequence here: interrupts are off for the whole of exec (see INIT.asm),
;; so the "EOR $FC" it reads from zero page never changes run to run, and
;; calling it several times in a tight, fixed instruction sequence (as
;; star_init/movestars do, once per star) means consecutive draws stay
;; close together in its state - visible as the stars starting out in a
;; diagonal line. Rather than touch the shared generator (other systems
;; depend on its exact behavior), every draw here is additionally EOR'd
;; with $D012 (the VIC raster line) - a free-running hardware counter
;; that keeps moving regardless of interrupts and has advanced by a
;; different, code-flow-independent amount at each call site - see
;; star_rand_mask.
;;
;; Full screen (rows 0-24): this deliberately overlaps the title, score
;; bar, flags etc., which will get their pixels/cells disturbed by
;; passing stars - accepted tradeoff, not a bug.

STAR_COUNT   = 24
BAND_MIN_ROW = 0
BAND_ROWS    = 25

; Stars advance once every STAR_SLOWDOWN calls to movestars (~1/3 speed
; at a 1-call/frame cadence). Color only changes once every
; STAR_COLOR_SLOWDOWN of THOSE moves, i.e. noticeably slower than the
; falling motion itself - see the two counters at the top of movestars.
STAR_SLOWDOWN       = 3
STAR_COLOR_SLOWDOWN = 6

rand:
 LDA  rand1
 AND  #$48
 EOR  $FC
 ADC  #$38
 ASL  A
 ASL  A
 ROL  rand1+2
 ROL  rand1+1
 ROL  rand1
 LDA  rand1
 RTS

; star_rand_mask: returns rand() EOR $D012 in A (see the file header note
; on why) - callers AND this with whatever range mask they need.
; Preserves X.
star_rand_mask:
 JSR  rand
 EOR  $D012
 RTS

; star_pick_slot: X = star's stardat index (0,3,6,...). Picks a random
; fixed pixel slot (0, 2, 4 or 6 - the bit-shift for one of the 4
; color-pixels in a screen byte) for this star and stores it in
; star_slot,X. Called once per spawn/respawn, never per frame - this is
; what keeps a falling star in the same screen column. Preserves X.
star_pick_slot:
 JSR  star_rand_mask
 AND  #3
 ASL  A
 STA  star_slot,x
 RTS

; star_pick_pattern: X = star's stardat index. Rolls a fresh 2-bit color
; pattern (0-3; 0 = black/background, a twinkle "off") at this star's
; already-chosen fixed slot (star_slot,X) and stores the resulting byte
; in stardat+2,X. Preserves X.
star_pick_pattern:
 JSR  star_rand_mask
 AND  #3
 LDY  star_slot,x
scp_shift:
 CPY  #0
 BEQ  scp_done
 ASL  A
 ASL  A
 DEY
 DEY
 JMP  scp_shift
scp_done:
 STA  stardat+2,x
 RTS

; star_respawn_top: (re)spawns star X at the top of the band (row
; BAND_MIN_ROW, scanline 0) with a random column and a fresh slot+color
; (a brand new star gets its full look immediately, independent of the
; color-slowdown timing in movestars). Preserves X.
star_respawn_top:
 LDA  #0
 STA  star_rowcnt,x
srt_col:
 JSR  star_rand_mask
 AND  #$3F
 CMP  #40
 BCS  srt_col
 STA  temp4
 LDA  #0
 STA  temp4+1
 ASL  temp4
 ROL  temp4+1
 ASL  temp4
 ROL  temp4+1
 ASL  temp4
 ROL  temp4+1            ; temp4 (word) = col * 8
 LDA  #<($6000+BAND_MIN_ROW*320)
 CLC
 ADC  temp4
 STA  stardat,x
 LDA  #>($6000+BAND_MIN_ROW*320)
 ADC  temp4+1
 STA  stardat+1,x
 JSR  star_pick_slot
 JSR  star_pick_pattern
 RTS

; is_row_protected: temp1 = row to check. Sets star_row_protected = 1 if
; the row is one of the 3 permanently HUD-reserved rows a star must never
; occupy - row 3 (the score bar, "SCR .... HI ......") or rows 23/24 (the
; level flags and lives icons) - else 0. That text is drawn with ORA and
; never redrawn/erased once placed (unlike a moving ship/alien), so an
; errant star bit landing there would never get cleaned up - the actual
; cause of the score-corruption bug (print_bitmap_line's own
; star_evict_range call only protects a letter at the MOMENT it's drawn,
; not for the rest of the game afterward, while a star's fall keeps
; going). These 3 rows are reserved identically on every screen (title/
; game/high-scores all use them the same way), so excluding them from the
; star band entirely up front is simpler and far more robust than trying
; to evict/restore a star every single frame it might wander through a
; static HUD element - used by si_row below (initial placement) and
; movestars' ms_wrap_row (every row a falling star advances into).
; Doesn't touch X - both call sites index stars via X and must keep it.
star_row_protected:
 .byte 0

is_row_protected:
 LDA  temp1
 CMP  #3
 BEQ  irp_yes
 CMP  #23
 BEQ  irp_yes
 CMP  #24
 BEQ  irp_yes
 LDA  #0
 STA  star_row_protected
 RTS
irp_yes:
 LDA  #1
 STA  star_row_protected
 RTS

; star_init: populates all STAR_COUNT stars at random positions spread
; through the whole band (so it isn't empty/bunched at the top the first
; time the screen appears) with random slots/colors, and plots them.
; Called once at startup - the per-star row multiply below is too slow
; to repeat every frame, which is why movestars (below) never recomputes
; a row from scratch, only ever adds a fixed offset.
star_init:
 LDX  #0
si_loop:
si_row:
 JSR  star_rand_mask
 AND  #31                ; mask must cover the full BAND_ROWS range (now
                          ; 0-24, full screen) before the reject-retry below
 CMP  #BAND_ROWS
 BCS  si_row
 STA  temp1              ; temp1 = candidate row (scratch - see
                          ; INIT.asm's zero-page usage note; free here,
                          ; nothing else runs during star_init) - saved
                          ; here since is_row_protected needs A and this
                          ; value is still needed below
 JSR  is_row_protected
 LDA  star_row_protected
 BNE  si_row              ; row 3/23/24 - reject and re-roll
 LDA  temp1
 STA  star_rowcnt,x
 STA  temp1              ; temp1 = row offset within the band (reused
                          ; below for the *320 multiply loop)
 LDA  #<($6000+BAND_MIN_ROW*320)
 STA  stardat,x
 LDA  #>($6000+BAND_MIN_ROW*320)
 STA  stardat+1,x
 LDA  temp1
 BEQ  si_row_added
si_row_loop:
 LDA  stardat,x
 CLC
 ADC  #<320
 STA  stardat,x
 LDA  stardat+1,x
 ADC  #>320
 STA  stardat+1,x
 DEC  temp1
 BNE  si_row_loop
si_row_added:
si_col:
 JSR  star_rand_mask
 AND  #$3F
 CMP  #40
 BCS  si_col
 STA  temp4
 LDA  #0
 STA  temp4+1
 ASL  temp4
 ROL  temp4+1
 ASL  temp4
 ROL  temp4+1
 ASL  temp4
 ROL  temp4+1            ; temp4 (word) = col * 8
 LDA  stardat,x
 CLC
 ADC  temp4
 STA  stardat,x
 LDA  stardat+1,x
 ADC  temp4+1
 STA  stardat+1,x
si_scan:
 JSR  star_rand_mask
 AND  #7
 STA  temp4
 LDA  stardat,x
 CLC
 ADC  temp4
 STA  stardat,x
 LDA  stardat+1,x
 ADC  #0
 STA  stardat+1,x

 JSR  star_pick_slot
 JSR  star_pick_pattern

 LDA  stardat,x
 STA  temp3
 LDA  stardat+1,x
 STA  temp3+1
 LDY  #0
 LDA  stardat+2,x
 EOR  (temp3),y
 STA  (temp3),y

 INX
 INX
 INX
 CPX  #(STAR_COUNT*3)
 BEQ  si_done
 JMP  si_loop
si_done:
 RTS

; movestars: called once per frame. Only actually advances the stars
; every STAR_SLOWDOWN'th call (~1/3 speed); of those moves, only every
; STAR_COLOR_SLOWDOWN'th also re-rolls color (each star's fixed pixel
; slot - not its color - so it doesn't jump sideways), so the flicker is
; noticeably slower than the fall. A star that respawns this tick always
; gets a fresh look immediately regardless of the color-tick timing (see
; star_respawn_top).
movestars:
 INC  star_frame_count
 LDA  star_frame_count
 CMP  #STAR_SLOWDOWN
 BCC  ms_skip
 LDA  #0
 STA  star_frame_count
 JMP  ms_run
ms_skip:
 RTS

ms_run:
 INC  star_color_count
 LDA  star_color_count
 CMP  #STAR_COLOR_SLOWDOWN
 BCC  ms_no_recolor
 LDA  #0
 STA  star_color_count
 LDA  #1
 STA  ms_recolor_flag
 JMP  ms_start
ms_no_recolor:
 LDA  #0
 STA  ms_recolor_flag
ms_start:
 LDX  #0
ms_loop:
 LDA  star_hidden,x
 BNE  ms_next             ; a hard object (ship/alien) currently owns this
                           ; star's cell (see star_evict_range) - frozen in
                           ; place, no erase/move/redraw, until it's
                           ; uncovered and star_restore_range redraws it
 LDA  stardat,x
 STA  temp3
 LDA  stardat+1,x
 STA  temp3+1
 LDY  #0
 LDA  stardat+2,x
 EOR  (temp3),y
 STA  (temp3),y          ; erase at the current position

 LDA  stardat,x
 AND  #7
 CMP  #7
 BEQ  ms_wrap_row
 INC  stardat,x
 JMP  ms_pick_color

ms_wrap_row:
 LDA  star_rowcnt,x
 CMP  #(BAND_ROWS-1)
 BCS  ms_respawn
 INC  star_rowcnt,x
 LDA  stardat,x
 CLC
 ADC  #<(320-7)
 STA  stardat,x
 LDA  stardat+1,x
 ADC  #>(320-7)
 STA  stardat+1,x
 LDA  star_rowcnt,x
 STA  temp1
 JSR  is_row_protected
 LDA  star_row_protected
 BNE  ms_wrap_row         ; row 3/23/24 - advance past it too; re-checks
                           ; the BAND_ROWS-1 bound each time round, so a
                           ; star that would land on 23 then 24 (adjacent
                           ; protected rows) correctly respawns instead
                           ; of ever being drawn at either
 JMP  ms_pick_color

ms_respawn:
 JSR  star_respawn_top
 JMP  ms_draw            ; star_respawn_top already picked slot+pattern

ms_pick_color:
 LDA  ms_recolor_flag
 BEQ  ms_draw
 JSR  star_pick_pattern

ms_draw:
 LDA  stardat,x
 STA  temp3
 LDA  stardat+1,x
 STA  temp3+1
 LDY  #0
 LDA  stardat+2,x
 EOR  (temp3),y
 STA  (temp3),y          ; redraw at the new position

ms_next:
 INX
 INX
 INX
 CPX  #(STAR_COUNT*3)
 BEQ  ms_done
 JMP  ms_loop
ms_done:
 RTS

star_frame_count:
 .byte 0
star_color_count:
 .byte 0
ms_recolor_flag:
 .byte 0

; --- Per-cell ownership: star_evict_range/star_restore_range let a hard
; object (ship/alien - see INIT.asm's draw_alien_bitmap_0/1/2, draw_ship,
; draw_explosion_here, erase_alien_x, erase_ship) claim or release a byte
; range of the bitmap without permanently desyncing any star's XOR parity
; - the root cause of the "stuck star" bug (an object's overwrite-style
; draw/erase used to clobber a star's cell with no way for the star to
; know its own bit got destroyed).
;
; star_hidden (declared in Master-c64.mak.asm alongside stardat/
; star_rowcnt/star_slot, same 3*31 stride so it shares the identical X
; index everywhere - deliberately not a second loop counter, since a
; stride mismatch between two related arrays is exactly the kind of
; indexing bug that caused a real crash earlier this session) - nonzero
; means this star is currently covered and frozen; movestars (above)
; skips a hidden star entirely; both routines below fully preserve X, Y
; AND temp3/temp3+1 - draw_alien_bitmap_0/1/2 etc. rely on temp3 still
; holding the cell-band base address the instant one of these calls
; returns, so treating them as a black box that disturbs nothing but
; star_hidden/the actual star pixels removes the need for every one of
; the ~20 call sites to remember to save/restore anything themselves.
sce_range_lo:
 .byte 0
sce_range_hi:
 .byte 0
sce_range_len:
 .byte 0

; star_evict_range: caller sets sce_range_lo/hi (16-bit base address) and
; sce_range_len (range size in bytes - 24 for a full cell-band, 8 for one
; cell) before calling. Scans all stars; any whose current position falls
; in [base, base+len) and isn't already hidden gets XOR'd off and marked
; hidden.
star_evict_range:
 TXA
 PHA
 TYA
 PHA
 LDA  temp3
 PHA
 LDA  temp3+1
 PHA

 LDX  #0
ser_loop:
 LDA  star_hidden,x
 BNE  ser_next             ; already hidden - leave it
 LDA  stardat,x
 SEC
 SBC  sce_range_lo
 STA  ser_diff_lo
 LDA  stardat+1,x
 SBC  sce_range_hi
 BNE  ser_next             ; hi byte of (addr-base) nonzero -> out of range
 LDA  ser_diff_lo
 CMP  sce_range_len
 BCS  ser_next              ; (addr-base) >= len -> out of range

 LDA  stardat,x
 STA  temp3
 LDA  stardat+1,x
 STA  temp3+1
 LDY  #0
 LDA  stardat+2,x
 EOR  (temp3),y
 STA  (temp3),y
 LDA  #1
 STA  star_hidden,x
ser_next:
 INX
 INX
 INX
 CPX  #(STAR_COUNT*3)
 BNE  ser_loop

 PLA
 STA  temp3+1
 PLA
 STA  temp3
 PLA
 TAY
 PLA
 TAX
 RTS
ser_diff_lo:
 .byte 0

; star_restore_range: same inputs/range test as star_evict_range, opposite
; direction - any star in range that IS hidden gets un-hidden and XOR'd
; back on at its current (frozen) position.
star_restore_range:
 TXA
 PHA
 TYA
 PHA
 LDA  temp3
 PHA
 LDA  temp3+1
 PHA

 LDX  #0
srr_loop:
 LDA  star_hidden,x
 BEQ  srr_next             ; not hidden - nothing to restore
 LDA  stardat,x
 SEC
 SBC  sce_range_lo
 STA  srr_diff_lo
 LDA  stardat+1,x
 SBC  sce_range_hi
 BNE  srr_next
 LDA  srr_diff_lo
 CMP  sce_range_len
 BCS  srr_next

 LDA  #0
 STA  star_hidden,x
 LDA  stardat,x
 STA  temp3
 LDA  stardat+1,x
 STA  temp3+1
 LDY  #0
 LDA  stardat+2,x
 EOR  (temp3),y
 STA  (temp3),y
srr_next:
 INX
 INX
 INX
 CPX  #(STAR_COUNT*3)
 BNE  srr_loop

 PLA
 STA  temp3+1
 PLA
 STA  temp3
 PLA
 TAY
 PLA
 TAX
 RTS
srr_diff_lo:
 .byte 0
