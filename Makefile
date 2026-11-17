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

.PHONY: all run help clean intro run-intro test-intro zip trace sprtest test-sprtest run-sprtest test-game test-music sprdata musicdata d64 test-build run-test
all: $(PRG)

help:
	@echo "make        build/GalaForce1-c64.PRG (plus .list and map.txt beside it)"
	@echo "make run    build, then run it in VICE (x64sc); make run MODEL=ntsc for NTSC"
	@echo "make test-game  play the demo headless and check the alien sprites against the game (tools/test_game_sprites.py)"
	@echo "make sprdata    regenerate src-c64/gen (sprite shapes and tables) from the decoded graphics and the BBC traces"
	@echo "make musicdata  regenerate src-c64/gen/music.inc (tunes, instruments, effects) from the BBC source in build/bbc/src"
	@echo "make test-music check every tune against the original note data, headless (tools/test_music.py; PAL=1 for PAL)"
	@echo "make trace         run the original BBC game headless and record alien positions per wave (build/trace)"
	@echo "make sprtest       build/sprtest/sprtest.prg: the sprite multiplexer test (spritetest/sprtest.s)"
	@echo "make test-sprtest  check it headlessly against the recorded positions (tools/test_sprtest.py)"
	@echo "make run-sprtest  build the sprite test and run it in VICE (x64sc); run-sprtest MODEL=ntsc for NTSC"
	@echo "make d64    build/galaforce1.d64: the loading screens (first file: LOAD\"*\",8,1) and the game on a disk image"
	@echo "make intro  build/intro.prg: the loading screens alone, made from disc/Disc025-Galaforce.ssd (run-intro runs the d64 in VICE, test-intro checks it headless)"
	@echo "make test-build  build/GalaForce1-c64-TEST.PRG with cheat keys: 1 next wave, 2 extra ship, 3 invulnerable, 4 +10000 (run-test runs it)"
	@echo "make zip    build/Galaforce1-C64.zip: the release (galaforce1.d64, the game PRG without loading screens, README.md)"
	@echo "make clean  remove build/"

$(PRG): $(SRCS) galaforce1-c64.cfg | $(B)
	$(CL65) -m $(B)/map.txt -t c64 -C galaforce1-c64.cfg -Ln $(B)/GalaForce1-c64.lbl -o $@ -l $(B)/GalaForce1-c64.list Master-c64.mak.asm

# a build with cheat keys for testing (see the cheat comment in INIT.asm): 1 next wave, 2 extra ship, 3 invulnerable,
# 4 +10000 points. Its files have -TEST in their names, so the real build is untouched.
TESTPRG := $(B)/GalaForce1-c64-TEST.PRG
test-build: $(TESTPRG)
$(TESTPRG): $(SRCS) galaforce1-c64.cfg | $(B)
	$(CL65) --asm-define CHEAT=1 -m $(B)/map-TEST.txt -t c64 -C galaforce1-c64.cfg -Ln $(B)/GalaForce1-c64-TEST.lbl -o $@ -l $(B)/GalaForce1-c64-TEST.list Master-c64.mak.asm
run-test: $(TESTPRG)
	$(X64SC) $(if $(MODEL),-model $(MODEL)) -autostartprgmode 1 -VICIIfilter 0 $(TESTPRG)

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
musicdata:
	$(PYTHON) tools/make_music.py
test-music: $(PRG)
	$(PYTHON) tools/test_music.py
test-game: $(PRG)
	$(PYTHON) tools/test_game_sprites.py 9000
test-sprtest: $(SPRT)/sprtest.prg
	$(PYTHON) tools/test_sprtest.py

# MODEL=ntsc (or pal, ntscold, ...): VICE's -model; unset = VICE's default
run-sprtest: $(SPRT)/sprtest.prg
	$(X64SC) $(if $(MODEL),-model $(MODEL)) -autostartprgmode 1 -VICIIfilter 0 $(SPRT)/sprtest.prg

# the loading screens: a program of their own (intro/intro.asm) made with the picture and pages of the original disc; it loads
# the file "game" from the same disk
$(B)/intro_data.inc: tools/make_intro.py tools/detok.py disc/Disc025-Galaforce.ssd | $(B)
	$(PYTHON) -I tools/make_intro.py disc/Disc025-Galaforce.ssd $@
INTRO := $(B)/intro.prg
intro: $(INTRO)
$(INTRO): intro/intro.asm intro/intro.cfg $(B)/intro_data.inc
	$(CL65) -t c64 -C intro/intro.cfg -m $(B)/intro-map.txt -Ln $(B)/intro.lbl -o $@ intro/intro.asm

d64: $(PRG) $(INTRO)
	rm -f $(B)/galaforce1.d64
	c1541 -format "galaforce 1,gf" d64 $(B)/galaforce1.d64 -write $(INTRO) galaforce -write $(PRG) game >/dev/null
	@echo "$(B)/galaforce1.d64: LOAD\"*\",8,1 then RUN (the loading screens, then the game)"

# the release: the disk image (loading screens, then the game), the game alone, the README. No cheat keys in either.
ZIP := $(B)/Galaforce1-C64.zip
zip: $(ZIP)
$(ZIP): d64 $(PRG) README.md
	rm -f $@
	rm -rf $(B)/zip && mkdir -p $(B)/zip
	cp $(B)/galaforce1.d64 $(B)/zip/Galaforce1-C64.d64
	cp $(PRG) $(B)/zip/Galaforce1-C64-game-only.prg
	cp README.md $(B)/zip/
	cd $(B)/zip && zip -q ../Galaforce1-C64.zip *
	rm -rf $(B)/zip
	@unzip -l $@

test-intro: $(INTRO)
	$(PYTHON) -I tools/test_intro.py
	$(PYTHON) -I tools/test_intro.py skip
	$(PYTHON) -I tools/test_intro.py pickey
	NTSC=1 $(PYTHON) -I tools/test_intro.py

run-intro: d64
	$(X64SC) $(if $(MODEL),-model $(MODEL)) -VICIIfilter 0 -autostartprgmode 1 -virtualdev8 +drive8truedrive +autostart-handle-tde -8 $(B)/galaforce1.d64 $(INTRO)

clean:
	rm -rf $(B)
