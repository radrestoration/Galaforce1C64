# Galaforce 1 - C64 port.  `make help` lists the targets.
#
# src/      the original BBC source (beebasm syntax): read-only reference
# src-c64/  the C64 port, assembled via Master-c64.mak.asm
-include tools.cfg
tilde = $(patsubst ~%,$(HOME)%,$(1))
ifneq ($(strip $(CC65_HOME)),)
CC65_HOME := $(call tilde,$(CC65_HOME))
export CC65_HOME
CL65       ?= $(CC65_HOME)/bin/cl65
endif
CL65       ?= cl65
PYTHON     ?= python3
X64SC      ?= x64sc
override CL65 := $(call tilde,$(CL65))

B    := build
PRG  := $(B)/GalaForce1-c64.PRG
SRCS := Master-c64.mak.asm $(wildcard src-c64/*.asm src-c64/*.inc) object/O.SPFONT_C64

.PHONY: all run help clean
all: $(PRG)

help:
	@echo "make        build/GalaForce1-c64.PRG (plus .list and map.txt beside it)"
	@echo "make run    build, then run it in VICE (x64sc)"
	@echo "make clean  remove build/"

$(PRG): $(SRCS) galaforce1-c64.cfg | $(B)
	$(CL65) -m $(B)/map.txt -t c64 -C galaforce1-c64.cfg -o $@ -l $(B)/GalaForce1-c64.list Master-c64.mak.asm

# the BBC 5-column font, as C64 character rows
object/O.SPFONT_C64: object/O.SPFONT tools/rotate_font.py
	$(PYTHON) tools/rotate_font.py $< $@

$(B):
	mkdir -p $(B)

run: $(PRG)
	$(X64SC) -autostartprgmode 1 -VICIIfilter 0 $(PRG)

clean:
	rm -rf $(B)
