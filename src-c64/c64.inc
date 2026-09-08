.ifndef C64_INC
C64_INC  = 1

; Standard VIC-II Hardware Mapping Configuration Registers
VIC_BASE     = $D000
SCN_BASE     = $0400         ; System default screen RAM block location
CLR_BASE     = $D800         ; Color attribute matrix block location

VIC_CTRL1    = VIC_BASE + $11
VIC_CTRL2    = VIC_BASE + $16
VIC_MEM_SET  = VIC_BASE + $18
VIC_BG_CLR0  = VIC_BASE + $20
VIC_BG_CLR1  = VIC_BASE + $21
VIC_BG_CLR2  = VIC_BASE + $22

; Kernal Subroutines (real C64 KERNAL jump table addresses)
SCINIT                        := $FF81
IOINIT                        := $FF84
RAMTAS                        := $FF87
RESTOR                        := $FF8A
SETLFS                        := $FFBA
SETNAM                        := $FFBD
OPEN                          := $FFC0
CLOSE                         := $FFC3
CHKIN                         := $FFC6
CHKOUT                        := $FFC9
CLRCHN                        := $FFCC
CHRIN                         := $FFCF
LOAD                          := $FFD5
SAVE                          := $FFD8
SETTIM                        := $FFDB
RDTIM                         := $FFDE
STOP                          := $FFE1
GETIN                         := $FFE4

; IRQs
IRQVec         := $0314
BRKVec         := $0316
NMIVec         := $0318

.endif
