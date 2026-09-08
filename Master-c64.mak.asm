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


.include "src-c64/SPRITES.asm"
.include "src-c64/INIT.asm"
.include "src-c64/ALIENS1.asm"
.include "src-c64/ALIENS2.asm"
.include "src-c64/ALIENS3.asm"
.include "src-c64/ALIENS4.asm"
.include "src-c64/ROUT1.asm"
.include "src-c64/ROUT2.asm"
.include "src-c64/ROUT3.asm"
.include "src-c64/ROUT4.asm"
.include "src-c64/STARS.asm"
.include "src-c64/BOMBS1.asm"
.include "src-c64/BOMBS2.asm"
.include "src-c64/CHARP.asm"
.include "src-c64/FLAGS.asm"
.include "src-c64/MUSIC1.asm"
.include "src-c64/MUSIC2.asm"
.include "src-c64/MUSIC3.asm"
.include "src-c64/TITLE.asm"
.include "src-c64/HIGH.asm"
.include "src-c64/WAVE.asm"
.include "src-c64/PATT.asm"
.include "src-c64/PATDAT.asm"
.include "src-c64/VECTORS.asm"

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

;.define FORCE_ABS(val) (val + 0)

objcodeend = *
;objcodeend = FORCE_ABS(objcodeend_raw)
 ; PRINT not implemented"Code start  = ",~objstrt
;.out .sprintf("Code start  = %x", objstrt)
;.out .sprintf("End of code = %x", objcodeend - 1)
;.out .sprintf("Length      = %x  (%d) bytes", objcodeend-objstrt, objcodeend-objstrt)
;.out .sprintf("Bytes left  = %x   (%d) bytes", $297A-objcodeend, $297A-objcodeend)

 ; PRINT not implemented"End of code = ",~objcodeend-1
 ; PRINT not implemented"Length      = ",~objcodeend-objstrt,"    (",objcodeend-objstrt%,") bytes"
 ; PRINT not implemented"Bytes left  = ",~$297A-objcodeend,"   (",$297A-objcodeend,") bytes"

;; Include the graphics object file ( From &297A to &2FFF )
.org  $297A
.incbin "object/O.GRAPHIC"

;; Include the Downloader binary at its GENUINE load address
;.org  objend
;.incbin "O.DOWN"

;; SAVE out everything
 ; PRINT not implemented "Saving GAME ", ~objstrt - $200, ~objend% + $200, ~objexec%, ~$1900
 ; SAVE not implemented "GAME", objstrt - $200, objend% + $200, objexec%, $1900

;; Save Main Basic Loader ( gets tokenised first )
 ; PUTBASIC not implemented "bas_extra\LOADER.bas.txt","$.L"

