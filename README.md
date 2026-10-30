# Galaforce 1 - C64 port (work in progress)

Original BBC Micro game (c) Kevin Edwards 1985-2019, published by Superior Software as *Galaforce*.
The BBC source is in `src/` (beebasm syntax, unmodified, reference only) and also at
`../Galaforce1BBC`. This is a port to the Commodore 64.

## Building

    cp tools.cfg.tmpl tools.cfg    # set CC65_HOME if cc65 is not on PATH
    make                           # build/GalaForce1-c64.PRG (+ .list, map.txt)
    make run                       # build and run in VICE (x64sc)
    make clean

Needs cc65 (`cl65`) and python3.

## Layout

| | |
|---|---|
| `src/` | the original BBC source: reference only, not assembled |
| `Master-c64.mak.asm` | top-level file for the C64 build |
| `src-c64/INIT.asm` | the game: boot, title/high-score/demo cycle, game loop, ship, aliens, waves, collisions, score, music |
| `src-c64/STARS.asm` | star field (a rewrite for the C64, not a translation) |
| `src-c64/ZPWORK.asm`, `ABSWORK.asm`, `c64.inc` | zero-page and absolute variables, KERNAL/VIC equates |
| `galaforce1-c64.cfg` | ld65 memory layout |
| `object/` | BBC font and graphics data (`O.SPFONT_C64` is generated from `O.SPFONT` by `tools/rotate_font.py`) |
| `bas_extra/LOADER.bas.txt` | the BBC loader; its `ENVELOPE` lines define the music envelopes |

## Display

Everything is drawn into the VIC-II multicolour bitmap (VIC bank 1: screen matrix `$4000`, bitmap `$6000`),
160 x 200 colour pixels, which matches the BBC's MODE 2 pixel grid horizontally. The BBC screen is 256 lines
high, so the vertical layout has to be squeezed to 200.

## Status

The game logic is a reimplementation that follows the BBC source (alien types, spawn waves, flight patterns,
scoring, lives, high scores), not a line-by-line translation; comments in `INIT.asm` cite the BBC routines.
Known gaps: sound effects (`mk_sound` is a stub), the music is an approximation (amplitude envelopes only, PAL
frequency table), and the rendering of overlapping objects is not yet right.
