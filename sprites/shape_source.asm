; Source data for the alien and ship sprite shapes: NOT assembled. tools/make_sprtest.py reads it (with the explosion
; frames and the colour equates in src-c64/INIT.asm) and writes src-c64/gen/shapes.bin and tables.inc (make sprdata).
; These were the bitmap drawings of the aliens and the ship before they became hardware sprites.

; --- Aliens: decoded from O.GRAPHIC's graphics pointer table, same table
; the ship's graph+36/37 pointer lives in (entries 96 bytes apart =
; alwidth*alheight=6*16, CONST.asm) and the same dual-buffer "sprite"
; plotter, so the same row-reversal applies. Which entries to decode
; isn't a guess: ALIENS1.asm's spawn-group records (see alien_spawn_table
; below) each carry a raw `initgra` byte, and ALIENS2.asm reads it as
; "LDY algra,X : LDX graph,Y : LDA graph+1,Y" - Y indexes BYTES into a
; table of 2-byte pointers, so the real entry index is initgra/2, and
; the real per-type index used everywhere in this port (alien_type,
; alien_hp_table/alien_score_table, this table set) is (initgra-12)/2 -
; traced from ALIENS2.asm's own "SEC:SBC#12:LSRA".
;
; alien_bitmap_0/1/2 were the first three decoded (this port's original
; 3-type era); a later full 12-type decode pass (verified pixel-exact
; against these three before trusting the other 9) turned up that
; alien_bitmap_1 is real type 3 (gra=18), not type 1 (gra=14) as first
; assumed - type 1 was never actually decoded, it just happened to get
; a plausible-looking label. Real type 1 data was decoded in a later
; pass and lives at alien_bitmap_1b (see alien_bitmap_lo/hi near
; draw_alien_x) - the _1b name, not _1, because _1 was already taken by
; the mislabeled real type 3 by the time this was sorted out.
; Also worth knowing: type 5 (gra=22) decodes to the exact same raw
; pixels as the player ship, upside down relative to ship_bitmap (their
; graph-table blocks are byte-identical once row-reversed) - confirmed,
; not an artifact of decoding it differently.
;
; Colors reduced per-type (each type's own dominant colors, not a shared
; palette), stray/minor pixels folded into whichever major color they
; were spatially adjacent to (measured, not guessed) - except type 8,
; where the fold was a near-tie (red 23 vs blue 21 neighbors) and is
; flagged here as the one genuinely low-confidence color call.
ALIEN_MATRIX_0   = $63  ; hi=6 blue (01), lo=3 cyan (10)
ALIEN_COLORRAM_0 = $01  ; white (11)
ALIEN_MATRIX_1   = $26  ; hi=2 red (01), lo=6 blue (10)
ALIEN_COLORRAM_1 = $04  ; magenta (11)
ALIEN_MATRIX_2   = $63  ; hi=6 blue (01), lo=3 cyan (10)
ALIEN_COLORRAM_2 = $04  ; magenta (11)
ALIEN_MATRIX_4   = $57  ; hi=5 green (01), lo=7 yellow (10)
ALIEN_COLORRAM_4 = $03  ; cyan (11)
ALIEN_MATRIX_5   = $17  ; hi=1 white (01), lo=7 yellow (10) - same as
ALIEN_COLORRAM_5 = $03  ; cyan (11) - SHIP_MATRIX_BYTE/SHIP_COLORRAM_BYTE
ALIEN_MATRIX_6   = $24  ; hi=2 red (01), lo=4 magenta (10)
ALIEN_COLORRAM_6 = $07  ; yellow (11)
ALIEN_MATRIX_7   = $36  ; hi=3 cyan (01), lo=6 blue (10)
ALIEN_COLORRAM_7 = $06  ; blue (11) - unused (only 2 real colors in this one)
ALIEN_MATRIX_8   = $26  ; hi=2 red (01), lo=6 blue (10)
ALIEN_COLORRAM_8 = $05  ; green (11)
ALIEN_MATRIX_9   = $24  ; hi=2 red (01), lo=4 magenta (10) - shared by
ALIEN_COLORRAM_9 = $04  ; magenta (11) - types 9/10/11 (identical source)
; Real type 1 (gra=14) - named _1B, not _1, because ALIEN_MATRIX_1/
; alien_bitmap_1 already belong to real type 3 (gra=18) - see the
; alien_bitmap_lo/hi header below for how that mislabeling happened.
ALIEN_MATRIX_1B   = $53  ; hi=5 green (01), lo=3 cyan (10)
ALIEN_COLORRAM_1B = $02  ; red (11)

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

alien_bitmap_4:
 .byte $02,$09,$24,$93,$93,$94,$95,$25
 .byte $aa,$55,$00,$c3,$c3,$00,$55,$55
 .byte $80,$60,$18,$c6,$c6,$16,$56,$58
 .byte $0a,$00,$02,$29,$95,$95,$26,$08
 .byte $55,$96,$55,$55,$69,$82,$00,$00
 .byte $a0,$00,$80,$68,$56,$56,$98,$20

alien_bitmap_5:
 .byte $40,$91,$66,$69,$61,$65,$69,$4a
 .byte $88,$a9,$56,$75,$fd,$fd,$fd,$fe
 .byte $04,$18,$64,$a4,$24,$64,$a4,$84
 .byte $c2,$02,$01,$01,$03,$00,$00,$00
 .byte $fe,$ba,$a9,$65,$13,$10,$10,$30
 .byte $0c,$00,$00,$00,$00,$00,$00,$00

alien_bitmap_6:
 .byte $54,$19,$06,$01,$06,$25,$9f,$9d
 .byte $00,$01,$46,$99,$9a,$99,$67,$65
 .byte $54,$90,$40,$00,$40,$60,$d8,$d8
 .byte $65,$1a,$06,$01,$01,$06,$19,$54
 .byte $99,$56,$9a,$a9,$99,$46,$01,$00
 .byte $64,$90,$40,$00,$00,$40,$90,$54

alien_bitmap_7:
 .byte $14,$69,$65,$14,$01,$06,$06,$06
 .byte $00,$01,$01,$54,$a9,$a5,$95,$95
 .byte $50,$84,$94,$50,$00,$40,$40,$40
 .byte $06,$06,$05,$01,$14,$69,$65,$14
 .byte $55,$55,$55,$55,$54,$01,$01,$00
 .byte $40,$40,$40,$00,$50,$a4,$94,$50

alien_bitmap_8:
 .byte $54,$64,$51,$05,$16,$59,$59,$5a
 .byte $10,$54,$69,$aa,$56,$fd,$fd,$56
 .byte $54,$64,$14,$40,$90,$a4,$a4,$a4
 .byte $5a,$6a,$69,$1a,$06,$51,$64,$54
 .byte $aa,$56,$fd,$56,$aa,$a9,$64,$10
 .byte $a4,$a4,$a4,$90,$40,$14,$64,$54

; alien_bitmap_9: real type 9 (gra=30); types 10/11 (gra=32/34) point at
; the exact same graph-table entry ($2F40, confirmed via direct pointer
; comparison), so they share this same data - see alien_bitmap_lo/hi.
alien_bitmap_9:
 .byte $05,$18,$60,$68,$22,$09,$25,$09
 .byte $00,$00,$41,$aa,$55,$55,$55,$55
 .byte $60,$18,$06,$1a,$88,$60,$58,$60
 .byte $09,$25,$09,$22,$68,$60,$18,$05
 .byte $55,$55,$55,$55,$aa,$41,$00,$00
 .byte $60,$58,$60,$88,$1a,$06,$18,$60

; alien_bitmap_1b: real type 1 (gra=14) - the one gap left after the
; earlier 9-type decode pass, closed the same way (calibrated by
; re-deriving alien_bitmap_0/2 from O.GRAPHIC and matching them byte-
; exact before trusting this one). Named _1b, not _1 - see ALIEN_MATRIX_
; 1B's own comment on why that name is already taken.
alien_bitmap_1b:
 .byte $15,$50,$51,$15,$05,$04,$04,$05
 .byte $00,$41,$55,$55,$41,$00,$ff,$ff
 .byte $54,$05,$45,$54,$50,$10,$10,$50
 .byte $01,$04,$15,$56,$58,$56,$15,$05
 .byte $7d,$00,$55,$a5,$00,$00,$81,$42
 .byte $40,$20,$58,$56,$16,$56,$58,$a0


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

