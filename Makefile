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
SRCS := Master-c64.mak.asm $(wildcard src-c64/*.asm src-c64/*.inc src-c64/gen/*) object/O.SPFONT_C64

.PHONY: all run help clean trace sprtest test-sprtest run-sprtest test-game sprdata
all: $(PRG)

help:
	@echo "make        build/GalaForce1-c64.PRG (plus .list and map.txt beside it)"
	@echo "make run    build, then run it in VICE (x64sc); make run MODEL=ntsc for NTSC"
	@echo "make test-game  play the demo headless and check the alien sprites against the game (tools/test_game_sprites.py)"
	@echo "make sprdata    regenerate src-c64/gen (sprite shapes and tables) from the decoded graphics and the BBC traces"
	@echo "make trace         run the original BBC game headless and record alien positions per wave (build/trace)"
	@echo "make sprtest       build/sprtest/sprtest.prg: the sprite multiplexer test (spritetest/sprtest.s)"
	@echo "make test-sprtest  check it headlessly against the recorded positions (tools/test_sprtest.py)"
	@echo "make run-sprtest  build the sprite test and run it in VICE (x64sc); run-sprtest MODEL=ntsc for NTSC"
	@echo "make clean  remove build/"

$(PRG): $(SRCS) galaforce1-c64.cfg | $(B)
	$(CL65) -m $(B)/map.txt -t c64 -C galaforce1-c64.cfg -Ln $(B)/GalaForce1-c64.lbl -o $@ -l $(B)/GalaForce1-c64.list Master-c64.mak.asm

# the BBC 5-column font, as C64 character rows
object/O.SPFONT_C64: object/O.SPFONT tools/rotate_font.py
	$(PYTHON) tools/rotate_font.py $< $@

$(B):
	mkdir -p $(B)

# MODEL=ntsc (or pal, ...): VICE's -model; unset = VICE's default
run: $(PRG)
	$(X64SC) $(if $(MODEL),-model $(MODEL)) -autostartprgmode 1 -VICIIfilter 0 $(PRG)

# ---- sprite multiplexer test -------------------------------------------------------------------------
build/trace/w15.json:
	tools/bbc_trace.sh
trace: build/trace/w15.json

SPRT := build/sprtest
$(SPRT)/shapes.bin $(SPRT)/tables.inc $(SPRT)/replay.bin: tools/make_sprtest.py src-c64/INIT.asm build/trace/w15.json
	$(PYTHON) tools/make_sprtest.py $(SPRT)
$(SPRT)/sprtest.prg: spritetest/sprtest.s spritetest/sprtest.cfg $(SPRT)/shapes.bin $(SPRT)/tables.inc $(SPRT)/replay.bin
	$(CL65) -t c64 --asm-include-dir . --bin-include-dir . -C spritetest/sprtest.cfg -m $(SPRT)/map.txt -Ln $(SPRT)/sprtest.lbl -o $@ spritetest/sprtest.s
sprtest: $(SPRT)/sprtest.prg
# the game's own copy of the sprite data (checked in, so a normal build does not need the BBC traces)
sprdata: $(SPRT)/shapes.bin $(SPRT)/tables.inc
	cp $(SPRT)/shapes.bin $(SPRT)/tables.inc src-c64/gen/
test-game: $(PRG)
	$(PYTHON) tools/test_game_sprites.py 9000
test-sprtest: $(SPRT)/sprtest.prg
	$(PYTHON) tools/test_sprtest.py

# MODEL=ntsc (or pal, ntscold, ...): VICE's -model; unset = VICE's default
run-sprtest: $(SPRT)/sprtest.prg
	$(X64SC) $(if $(MODEL),-model $(MODEL)) -autostartprgmode 1 -VICIIfilter 0 $(SPRT)/sprtest.prg

clean:
	rm -rf $(B)
