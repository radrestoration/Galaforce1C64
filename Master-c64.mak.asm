;;
;; Galaforce 1 BBC
;;
;; (C) Kevin Edwards 1986-2019
;;

objstrt =$800  ; Start of actual code, data is loaded below this later ( to &900 and &A00 )
objend  =$3000 ; End of code, where the Downloader is positioned
objexec =$4000 ; Execution address when loaded to &1900 rather than &900 ( objend% + &1900 - &900 )

.include "src-c64/c64.inc"

.include "src-c64/CONST.asm"
.include "src-c64/ZPWORK.asm"
.include "src-c64/ABSWORK.asm"

;; Normal ASCII
;.charmap ' ','Z', 32

.org  $80D

;; Main Code block - source files assembled in the same order as the original
.segment "STARTUP"
.segment "INIT"
.segment "ONCE"

;.segment "EXEHDR"
;    ; This header structure contains exactly 13 bytes ($000D) to match the memory size
;    .word $080B         ; 2 bytes - Address link pointer
;    .word 10            ; 2 bytes - BASIC Line number 10
;    .byte $9E           ; 1 byte  - SYS token
;    .byte "2061"        ; 4 bytes - ASCII target jump text characters
;    .byte 0,0,0         ; 3 bytes - Line end flag bytes
;    .byte 0             ; 1 byte  - Alignment padding byte (Brings total to exactly 13)


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

osword:
osbyte:
oswrch:
  RTS

stardat:    ;; Doesn't fit in zeropage and moving before code causes overflow
.res 3 * 31

star_rowcnt:    ;; One byte used per star, but kept at the same 3-byte
.res 3 * 31     ;; stride as stardat so both can share the X index in STARS.asm

star_slot:      ;; Same again - each star's fixed pixel bit-shift (0/2/4/6)
.res 3 * 31     ;; within its byte, set once at spawn, kept for its whole life

star_hidden:    ;; Same 3*31 stride again - nonzero means a hard object
.res 3 * 31     ;; (ship/alien) currently covers this star's cell; see
                ;; star_evict_range/star_restore_range in STARS.asm

;.define FORCE_ABS(val) (val + 0)

objcodeend = *

; O.GRAPHIC used to be incbin'd here at a hardcoded .org $297A - dead
; weight, same as the legacy .asm files removed above: every alien/ship/
; title graphic actually used at runtime was long since hand-decoded from
; it and embedded directly as .byte tables in INIT.asm (see e.g.
; alien_bitmap_0/1/2, ship_bitmap, TITLE_B0/B1/B2), and CONST.asm's
; `graph = $297A` constant that pointed at it is never referenced outside
; comments. Also worth noting: .org $297A here was almost certainly not
; doing what its own comment claimed anyway - RODATA is a relocatable
; segment (linker-placed, see galaforce1-c64.cfg), and by this point in
; the file it had already emitted well over $297A worth of content, so
; the assembler's PC could not actually have gone backward to $297A; the
; incbin was silently landing wherever RODATA's linked address put it,
; not at the real BBC load address the comment described.

;; Include the Downloader binary at its GENUINE load address
;.org  objend
;.incbin "O.DOWN"

;; SAVE out everything
 ; PRINT not implemented "Saving GAME ", ~objstrt - $200, ~objend% + $200, ~objexec%, ~$1900
 ; SAVE not implemented "GAME", objstrt - $200, objend% + $200, objexec%, $1900

;; Save Main Basic Loader ( gets tokenised first )
 ; PUTBASIC not implemented "bas_extra\LOADER.bas.txt","$.L"

