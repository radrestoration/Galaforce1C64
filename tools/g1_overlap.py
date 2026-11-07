"""Run the real BBC Galaforce 1 headless (Droid's sim6502) and record how many aliens
overlap vertically, i.e. how many hardware sprites a C64 would need on one scanline.

usage: g1_overlap.py <ssd> <syms.txt> <wave> <max_iterations> <out.json>
syms.txt: the "SYM name &addr" lines beebasm printed (tools/bbc_trace.sh)
The ship never fires and cannot be hit (collision() is stubbed), so aliens live until
their flight pattern ends: this is an UPPER bound on simultaneous aliens.
"""
import json
import sys

import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402

ssd, symfile, wave, max_it, out = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
SYM = {l.split()[1]: int(l.split()[2].lstrip("&"), 16) for l in open(symfile) if l.startswith("SYM")}

d = open(ssd, "rb").read()
n = d[0x105] // 8
img = None
for i in range(n):
    e, m = 8 + i * 8, 0x108 + i * 8
    if d[e:e + 7].decode("latin1").strip() == "GAME":
        ln = d[m + 4] | d[m + 5] << 8 | ((d[m + 6] >> 4) & 3) << 16
        sec = d[m + 7] | ((d[m + 6] & 3) << 8)
        img = d[sec * 256: sec * 256 + ln]
assert img, "no GAME file"

cpu = CPU()
cpu.m[0x900:0x900 + len(img)] = img      # the game's own memory image (the downloader just moves it here)
cpu.pc, cpu.sp = SYM["exec"], 0xFF


def osbyte(c):
    if c.a == 0x81:                       # INKEY: nothing pressed
        c.x, c.y = 0, 0
        c.c = 0
    elif c.a == 0x80:
        c.x, c.y = 0xFF, 0


def wait_for_space(c):                    # return the starting wave in A, as the real routine returns the key
    c.a = wave


cpu.traps[0xFFF4] = osbyte
cpu.traps[0xFFEE] = lambda c: None
cpu.traps[0xFFE3] = lambda c: None
cpu.traps[0xFFF1] = lambda c: None
cpu.traps[SYM["wait_for_space"]] = wait_for_space
# collision(): the ship can't be hit and nothing is shot, so the whole wave plays out
coll = None

samples = []
it = 0
seen_main = False
steps = 0
while it < max_it:
    cpu.step()
    steps += 1
    if cpu.pc == SYM["main_loop"]:
        if not seen_main:
            seen_main = True
            coll = SYM["collision"]
            cpu.traps[coll] = lambda c: None
        cpu.m[SYM["lives"]] = 3
        al = []
        for i in range(40):
            if cpu.m[SYM["alst"] + i] & 0x80:
                al.append((i, cpu.m[SYM["alx"] + i], cpu.m[SYM["aly"] + i], cpu.m[SYM["algra"] + i]))
        samples.append(al)
        it += 1
        if cpu.m[SYM["curwave"]] != wave:
            break
json.dump(dict(wave=wave, iterations=it, steps=steps, coll=hex(coll or 0), samples=samples), open(out, "w"))
print("wave", wave, "iterations", it, "steps", steps, "collision at", hex(coll or 0))
