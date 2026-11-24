# Galaforce 1 - C64 port (work in progress)

Original BBC Micro game (c) Kevin Edwards 1985-2019, published by Superior Software as *Galaforce*.
The BBC source is in `src/` (beebasm syntax, unmodified, reference only). This is a port to the Commodore 64.

## Building

    cp tools.cfg.tmpl tools.cfg    # set CC65_HOME if cc65 is not on PATH
    make                           # build/GalaForce1-c64.PRG (+ .list, map.txt)
    make run                       # build and run in VICE (x64sc)
    make d64                       # build/galaforce1.d64: the loading screens, then the game (LOAD"*",8,1)
    make zip                       # build/Galaforce1-C64.zip: the release (disk image, game PRG, README)
    make timing-build              # build/GalaForce1-c64-TIMING.PRG: the border shows what the CPU is doing (see below)
    make clean

Needs cc65 (`cl65`) and python3.

## Layout

| | |
|---|---|
| `src/` | the original BBC source: reference only, not assembled |
| `Master-c64.mak.asm` | top-level file for the C64 build |
| `src-c64/INIT.asm` | the game: boot, title/high-score/demo cycle, game loop, ship, aliens, waves, collisions, score |
| `src-c64/SPRMUX.asm` | the alien/ship sprite multiplexer (raster interrupt) |
| `src-c64/MUSIC.asm` | the SID music and sound-effect engine, run from the raster interrupt; lives in the free part of VIC bank 1 |
| `src-c64/gen/` | generated data: sprite shapes and tables (`make sprdata`), tunes, instruments and effects (`make musicdata`) |
| `src-c64/STARS.asm` | star field (a rewrite for the C64, not a translation) |
| `src-c64/ZPWORK.asm`, `ABSWORK.asm`, `c64.inc` | zero-page and absolute variables, KERNAL/VIC equates |
| `galaforce1-c64.cfg` | ld65 memory layout |
| `sprites/shape_source.asm` | the alien and ship drawings (not assembled): the source `tools/make_sprtest.py` makes the sprite shapes from |
| `intro/intro.asm` | the loading screens: a program of its own that shows the instruction pages and the picture, then loads the game (see below) |
| `disc/` | the original disc image the loading screens are made from (`make intro`, `tools/make_intro.py`) |
| `object/` | BBC font and graphics data (`O.SPFONT_C64` is generated from `O.SPFONT` by `tools/rotate_font.py`) |
| `bas_extra/LOADER.bas.txt` | the BBC loader (its `ENVELOPE` lines are what the original's sounds were built from; the C64 uses SID patches instead) |

## Controls

| | |
|---|---|
| Z / X | left / right |
| `;` or `=` / `/` | up / down |
| RETURN | fire (hold for autorepeat) |
| SPACE or RETURN | start a game from the title; also ends the demo |
| joystick, port 2 | works at the same time as the keys: left, right, up, down, fire (the original's K switch is gone) |
| S | sound on or off; the letter in the bottom right corner shows S or Q |
| P | pause (the P in the bottom right corner, as the original shows it) |
| RUN/STOP | give up the game (loses every ship), as the original's ESCAPE; back to the title from the demo |

### Timing build

`make timing-build` (`make run-timing`) builds `build/GalaForce1-c64-TIMING.PRG`, which colours the border by what the CPU is doing, so on a
real machine the stripes down the sides of the screen show how much of a frame each part of the game takes: black = waiting for the
next frame, red = building the sprite list, blue = the rest of a game loop pass (while playing it is split: white = the stars, cyan = the ship and its bullets, purple = the aliens' bullets, orange = the aliens' movement, brown = ship bullets against aliens, light grey = aliens against the ship), yellow and green = the sprite and music interrupts.
A pass whose red and blue run on past the end of the frame is taking more than a frame. The real build has none of this.

### Test build

`make test-build` (or `make run-test`) builds `build/GalaForce1-c64-TEST.PRG` with cheat keys, which the real build does
not contain: **1** skip to the next wave, **2** an extra ship, **3** invulnerable on/off (the border turns red),
**4** +10000 points. They work in a real game, not in the demo.

## Loading screens

The disk image (`make d64`) starts with `galaforce`, a small program made from the original disc (`disc/Disc025-Galaforce.ssd`),
as the BBC's loader does it: first the MODE 7 instruction pages (the logo, the story, playing instructions, the pilot's
briefing, the zones, game controls) in C64 text mode, SPACE or joystick fire for the next, RUN/STOP to skip them; then the
loading picture, which stays up for 5 seconds (any key or the joystick fire goes on sooner) and then while the game
(`game` on the disk) loads. The controls page lists the C64's keys instead of
the BBC's. The picture (MODE 5, 160 x 200 of it, four colours) is the C64's multicolour bitmap format already, so it is
the disc's pixels, not a conversion; the block graphics of the logo are 64 extra characters; the flashing line flashes.
`tools/make_intro.py` makes the data, `make test-intro` runs the program headless and draws every page and the picture to
`build/intro_test/`. The standalone `GalaForce1-c64.PRG` (`make run`) has no loading screens.

## Display

**Aliens are hardware sprites** (`src-c64/SPRMUX.asm`): a Y-sorted raster-IRQ multiplexer over sprites 0-6, fed each
frame from the game's alien pool, with the six explosion frames as shapes too. **The ship is sprite 7**, moved a cell
at a time by `spr_ship_show`. Sprite shapes and the shared colours are generated into `src-c64/gen/` by
`tools/make_sprtest.py` (`make sprdata`) from `sprites/shape_source.asm` and `INIT.asm`'s explosion frames. The
32-alien swarm waves (4, 8, 12 = wave index 3, 7, 11) are sprites too: at most 7 can share a scanline, and the rest of
a crowded row are moved down a few lines or dropped. Bullets, stars, the ship's explosion and the HUD are bitmap.
`make test-game` plays the demo headless and checks the sprites against the alien pool (`PACE=1` and `PROF=1`, with
`SYMS=`, measure how many frames each game loop pass takes and where the time goes); `spritetest/` is the stand-alone
multiplexer test (`make run-sprtest`).
Memory: code and data end below $4000; sprite shapes, tables and the star arrays are in the free part of VIC bank 1.

Everything is drawn into the VIC-II multicolour bitmap (VIC bank 1: screen matrix `$4000`, bitmap `$6000`),
160 x 200 colour pixels, which matches the BBC's MODE 2 pixel grid horizontally. The BBC screen is 256 lines
high, so the vertical layout has to be squeezed to 200.

## Status

The game logic is a reimplementation that follows the BBC source (alien types, spawn waves, flight patterns,
scoring, lives, high scores), not a line-by-line translation; comments in `INIT.asm` cite the BBC routines.

## Screens and messages

As in the original: the main screen for 256 frames, the high scores for 256, then the demo, on a random wave from 0 to 7; after a
demo's game over it starts again from the main screen, and the demo's music goes on through those screens without a restart. "ENTERING ZONE nn" appears at the start
of every life and wave for about 4 seconds (the original's 256 passes, counted on the BBC code), while the ship, its shots and the
stars carry on and the aliens wait. SATURN, BATTERY and TURBO appear under it on arriving at wave 16, 32 and 48, flashing red and cyan
(the BBC's default flash rate: the source does not set another). GAME OVER shows during the game-over tune, and ENTER YOUR NAME while
a new high score's name is typed.

## Music and sound

The notes, tempo and rhythm of every tune are the original's: `tools/make_music.py` reads `MUSIC1-3.asm` and writes
`src-c64/gen/music.inc`. The sounds are SID patches made for this port (four instruments, five effects), not an
emulation of the BBC's `ENVELOPE`s. The engine ticks 50 times a second, as the original's vertical-sync event does
(every frame on PAL, 5 in 6 on NTSC), independent of the game loop. Tunes: game start, between levels (the zone tune
every 16th wave), lost a life (the ship's respawn waits for it), game over (the high-score screen waits for it) and the
demo's four sections. The title and high-score screens have no music, as in the original. Effects (fire, alien
explosion, ship crash, extra life, last man) take over SID voice 3 briefly. `make test-music` checks every tune against the original's note
data (pitch, start time, gate length), headless; `PAL=1 make test-music` does it for PAL.

The extra life (the first time the score reaches 20000) and the "last man" sound (when the last spare ship goes into
play) are the original's, with their own warbling effects. As in the original a game has the ship in play plus three
spares, and is over when a ship is lost with none left.

## Checked against the original

Every table the game takes from the original (spawn groups, flight-pattern bytecode, wave lists and pool sizes, hit points, scores,
the direction tables) is compared with the BBC source files by a script, and all match. The alien paths of all 16 waves were also
compared with the original running headless: every path the original flies is flown by the port (waves 1 and 8 miss a couple of
a child alien's paths in the window compared). Differences that were found and fixed: spawn positions cut to cells, the random start
columns (78, 79), the in-flight left/right wrap, spawn groups 28-45 reading the wrong rows of the table, a child alien's random type,
losing a ship (the original replays the group in progress, not the whole wave), the score field (7 digits, no leading zeros, past
99990) and the high-score table's layout.

## Known gaps and choices

- Bullets, stars, the ship's explosion and the HUD are bitmap, not sprites; collisions test whole character cells,
  not the original's pixel boxes.
- With 8 or more aliens on screen the sprite list is rebuilt every other frame (the ship, its shots and the game itself still run
  every frame), so the aliens' sprites move in steady half-rate steps. A game loop pass that runs over a frame starts the next at
  once instead of waiting for the next frame, so the game slows down in proportion to the overrun (as the BBC's does) rather than
  dropping to half speed. A row of 8 aliens needs more sprites than there are, so one in a row is moved down some lines; the
  32-alien swarm waves are the heaviest case.
- The "HIGH SCORES" heading is the port's own; the original shows only the rows.
- In the demo the ship stays on the bottom row (a port choice). The demo ends at its own game over, or on
  SPACE/RETURN, which starts a real game.
- Alien bombs follow BOMBS2.asm: a random alien drops one on about 1 pass in 16, each bomb is fast or slow, and from
  wave 13 they drift toward the ship (one column at a time, not the original's pixel).
