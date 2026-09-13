;;
;; Galaforce 1 BBC
;;
;; (C) Kevin Edwards 1986-2019
;;
;; C64 port

.include "src-c64/c64.inc"

.include "src-c64/ZPWORK.asm"
.include "src-c64/ABSWORK.asm"

.org  $80D

.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

.segment "CODE"
    ; Code execution starts cleanly right here at address $080D
    jmp exec


; The C64 port's actual code lives entirely in INIT.asm + STARS.asm. The
; rest of this list used to be SPRITES/ALIENS1-4/ROUT1-4/BOMBS1-2/CHARP/
; FLAGS/MUSIC1-3/TITLE/HIGH/WAVE/PATT/PATDAT/VECTORS - mechanically
; beebasm->ca65 translated copies of the original BBC source, never
; actually called from anywhere (verified: every reference to their
; labels anywhere in INIT.asm/STARS.asm is inside a comment citing the
; real source for provenance, never a jsr/jmp/lda). They were pure dead
; weight in the assembled program - and, as of today, dangerous dead
; weight: the program's total CODE+RODATA size had grown enough to
; physically overlap $4000-$43E7, the live VIC-II screen-matrix memory
; (see the file header above on VIC bank 1) - whichever bytes of code or
; data happened to land there got silently corrupted by every screen
; write, and vice versa. That's what broke the title-screen rendering.
; The real, authoritative BBC source these were translated from is
; untouched in src/*.asm (read-only reference - see INIT.asm's own
; comments, which already cite src/ throughout, not these copies) - so
; nothing is lost by not assembling them, and removing them recovers
; several KB, clearing the overlap with a comfortable margin.
.include "src-c64/INIT.asm"
.include "src-c64/STARS.asm"

.segment "RODATA"
spfont:
.incbin "object/O.SPFONT_C64"
spfont_end:

stardat:    ;; Doesn't fit in zeropage and moving before code causes overflow
.res 3 * 31

star_rowcnt:    ;; One byte used per star, but kept at the same 3-byte
.res 3 * 31     ;; stride as stardat so both can share the X index in STARS.asm

star_slot:      ;; Same again - each star's fixed pixel bit-shift (0/2/4/6)
.res 3 * 31     ;; within its byte, set once at spawn, kept for its whole life

star_hidden:    ;; Same 3*31 stride again - nonzero means a hard object
.res 3 * 31     ;; (ship/alien) currently covers this star's cell; see
                ;; star_evict_range/star_restore_range in STARS.asm

; O.GRAPHIC (the BBC's raw graphics dump) isn't included in the build:
; every alien/ship/title graphic actually used at runtime was long since
; hand-decoded from it and embedded directly as .byte tables in INIT.asm
; (see e.g. alien_bitmap_0/1/2, ship_bitmap, TITLE_B0/B1/B2, and the
; explosion_frame_0-5 tables) - see src/CONST.asm for the real BBC
; `graph = &297A` pointer-table address these were decoded against.

