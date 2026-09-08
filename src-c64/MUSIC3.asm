;;
;; Galaforce 1 ( BBC Micro ) from the original 6502 source code, adapted to assemble using beebasm
;;
;; (c) Kevin Edwards 1986-2019
;;
;; Twitter @KevEdwardsRetro
;;

;; REM SAVE":2.MUSIC3"
;; B%=P%
;; [OPT pass

;16-Zone Music

ZONE1:
.byte  8+D2
.byte  8+D2
.byte  20+D1
.byte  8+D2
.byte  8+D1
.byte  8+D2
.byte  8+D2
.byte  20+D1
.byte  8+D2
.byte  8+D1
.byte  11+D2
.byte  11+D2
.byte  18+D1
.byte  11+D2
.byte  11+D1
.byte  11+D2
.byte  11+D2
.byte  18+D1
.byte  11+D2
.byte  11+D1
.byte  13+D2
.byte  13+D2
.byte  20+D1
.byte  13+D2
.byte  13+D1
.byte  13+D2
.byte  13+D2
.byte  20+D1
.byte  13+D2
.byte  13+D1
.byte  16+D2
.byte  16+D2
.byte  20+D1
.byte  16+D2
.byte  16+D1
.byte  16+D2
.byte  16+D2
.byte  20+D1
.byte  16+D2
.byte  16+D1
.byte  0
ZONE2:
.byte  3+D1
.byte  8+D1
.byte  11+D1
.byte  15+D1
.byte  20+D1
.byte  15+D1
.byte  11+D1
.byte  8+D1
.byte  3+D1
.byte  8+D1
.byte  11+D1
.byte  15+D1
.byte  20+D1
.byte  15+D1
.byte  11+D1
.byte  8+D1
.byte  3+D1
.byte  6+D1
.byte  11+D1
.byte  15+D1
.byte  18+D1
.byte  15+D1
.byte  11+D1
.byte  6+D1
.byte  3+D1
.byte  6+D1
.byte  11+D1
.byte  15+D1
.byte  18+D1
.byte  15+D1
.byte  11+D1
.byte  6+D1
.byte  4+D1
.byte  8+D1
.byte  13+D1
.byte  16+D1
.byte  20+D1
.byte  16+D1
.byte  13+D1
.byte  8+D1
.byte  4+D1
.byte  8+D1
.byte  13+D1
.byte  16+D1
.byte  20+D1
.byte  16+D1
.byte  13+D1
.byte  8+D1
.byte  4+D1
.byte  8+D1
.byte  11+D1
.byte  16+D1
.byte  20+D1
.byte  16+D1
.byte  11+D1
.byte  8+D1
.byte  4+D1
.byte  8+D1
.byte  11+D1
.byte  16+D1
.byte  20+D1
.byte  16+D1
.byte  11+D1
.byte  8+D1
.byte  Rest+D1
.byte  0
ZONE3:
.byte  32+D2
.byte  32+D3
.byte  32+D2
.byte  30+D1
.byte  32+D2
.byte  32+D3
.byte  27+D1
.byte  30+D1
.byte  32+D1
.byte  35+D2
.byte  35+D3
.byte  35+D2
.byte  30+D1
.byte  35+D2
.byte  35+D3
.byte  30+D1
.byte  32+D1
.byte  35+D1
.byte  37+D2
.byte  37+D3
.byte  37+D2
.byte  37+D1
.byte  37+D2
.byte  37+D3
.byte  37+D2
.byte  36+D1
.byte  35+D2
.byte  35+D3
.byte  35+D2
.byte  34+D1
.byte  35+D2
.byte  35+D1
.byte  34+D1
.byte  35+D1
.byte  37+D1
.byte  35+D1
.byte  34+D1
.byte  0

; Addr1 Index2 Index3 Speed Env Dur
LT:
 .word  STRT1
.byte (STRT2-STRT1) & $ff
.byte (STRT3-STRT1) & $ff
.byte  23
.byte  05
.byte  05
.word  BETW1
.byte (BETW2-BETW1) & $ff
.byte (BETW3-BETW1) & $ff
.byte  07
.byte  08
.byte  08
.word  OVER1
.byte (OVER2-OVER1) & $ff
.byte (OVER3-OVER1) & $ff
.byte  23
.byte  11
.byte  05
.word  DEMa1
.byte (DEMa2-DEMa1) & $ff
.byte (DEMa3-DEMa1) & $ff
.byte  27
.byte  14
.byte  11
.word  LOST1
.byte (LOST2-LOST1) & $ff
.byte (LOST3-LOST1) & $ff
.byte  03
.byte  02
.byte  02
.word  ZONE1
.byte (ZONE2-ZONE1) & $ff
.byte (ZONE3-ZONE1) & $ff
.byte  03
.byte  05
.byte  05
.word  DEMa1
.byte (DEMa2-DEMa1) & $ff
.byte (DEMb3-DEMa1) & $ff
.byte  27
.byte  14
.byte  11
.word  DEMa2
.byte (DEMa3-DEMa2) & $ff
.byte (DEMc1-DEMa2) & $ff
.byte  27
.byte  14
.byte  11
.word  DEMd1
.byte (DEMd2-DEMd1) & $ff
.byte (DEMd3-DEMd1) & $ff
.byte  27
.byte  14
.byte  14

;; ]
;; PRINT"Music 3 from &";~B%;" to &";~P%-1;" (";P%-B%;")"
;; PAGE=&5800
;; RETURN
