;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;
;; C64 port - zero-page scratch/working storage. Originally a
;; direct translation of the BBC source's own ZPWORK.asm; trimmed to
;; just what's actually referenced by src-c64/INIT.asm and STARS.asm -
;; the BBC-side variables this file used to also declare (alien/bullet
;; pattern-interpreter workspace, a second sprite XOR buffer, etc.) were
;; superseded by this port's own equivalents (alien_active/alien_type/
;; bullet_row/etc. in INIT.asm) once those got real, decoded
;; implementations, and were never removed until now.
;;
;; temp1-4/colour/length/screen: shared scratch used throughout INIT.asm
;; and STARS.asm - NOT safe to hold a value across a jsr to any routine
;; that also uses the same one internally (see INIT.asm's own file
;; header for the convention this relies on throughout).

.zeropage

.res $22

colour:
  .byte 0
screen:
  .word 0

temp1:
  .byte  0
length:
  .byte  0

temp2:
  .word  0

temp3:
  .word 0
temp4:
  .word  0

rand1:
  .res 3
counter:
  .byte 0

; dab_ptr: draw_alien_bitmap_generic's source-bitmap pointer - needs to
; be zero page for (dab_ptr),y indirect addressing (temp2/3/4 are all
; simultaneously busy holding this same draw's color-RAM/bitmap/screen-
; matrix addresses, so none of them are free to double up here).
dab_ptr:
  .word 0

; dof_ptr: same reasoning as dab_ptr, for draw_flag_generic's source-
; bitmap pointer (the level-number flag icons).
dof_ptr:
  .word 0
