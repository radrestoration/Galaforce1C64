;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;
;; C64 port - absolute (non-zero-page) working storage. Originally a direct
;; translation of the BBC source's own general workspace (alien pool
;; arrays, bullet arrays, ship/score state, high-score text buffers,
;; misc flags) - all superseded by this port's own equivalents in
;; src-c64/INIT.asm once those got real implementations, except for the
;; 3 demo-mode flags below, which INIT.asm's process_demo/
;; handle_ship_input/title_wait_loop genuinely still read and write
;; here (never given their own C64-side declaration).

.org  $400
.segment "DATA"

demo_flag:
  .byte 0
demo_count:
  .byte 0
demo_direction:
  .byte 0
