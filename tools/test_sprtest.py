"""Headless check of spritetest/sprtest.prg: the PRG runs in the plain 6502 interpreter with a small VIC-II
model (raster counter from the cycle count, the raster interrupt, a log of every sprite register write), and
what the sprites would show is reconstructed line by line and compared with the recorded BBC positions.

    tools/test_sprtest.py [frames] [cycles_per_line]

What it checks: the position/shape/colour transform, the Y sort, the slip rule, that each IRQ re-programs a
sprite only after its previous object has finished, and how far objects are moved. What it does not: real VIC-II
timing (badlines, sprite DMA stealing cycles - cycles_per_line is a deliberately low average for that),
the exact cycle the VIC-II ends a sprite's DMA, or anything about how it looks.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
B = os.path.join(ROOT, "build", "sprtest")
FRAMES = int(sys.argv[1]) if len(sys.argv) > 1 else 1600
CPL = int(sys.argv[2]) if len(sys.argv) > 2 else 46
LINES = 263

lbl = {}
for line in open(os.path.join(B, "sprtest.lbl")):
    _, a, n = line.split()
    lbl[n[1:]] = int(a, 16)

prg = open(os.path.join(B, "sprtest.prg"), "rb").read()
cpu = CPU()
addr = prg[0] | prg[1] << 8
cpu.m[addr:addr + len(prg) - 2] = prg[2:]
cpu.pc, cpu.sp = 0x080D, 0xFF          # where the BASIC stub's SYS 2061 goes
assert cpu.m[0x080D] == 0x4C and cpu.m[0x080E] | cpu.m[0x080F] << 8 == lbl["start"], "entry at $080D is not JMP start"

state = dict(pending=False, line=0)
events = []          # (cycles, addr, value)
markers = []         # (cycles, shown) at each top-of-frame D015 write
raw_rd = cpu.rd


def rd(a):
    a &= 0xFFFF
    line = (cpu.cycles // CPL) % LINES
    if a == 0xD012:
        return line & 255
    if a == 0xD011:
        return (cpu.m[0xD011] & 0x7F) | ((line >> 8) << 7)
    return raw_rd(a)


cpu.rd = rd


def wr_hook(a, v):
    if a == 0xD019 and v & 1:
        state["pending"] = False
    if 0xD000 <= a <= 0xD02E or 0x43F8 <= a <= 0x43FF:
        events.append((cpu.cycles, a, v))
        if a == 0xD015:
            markers.append((cpu.cycles, cpu.m[lbl["shown"]]))


cpu.write_hooks.append(wr_hook)

frame_cycles = CPL * LINES
irqs = 0
last_line = -1
while cpu.cycles < FRAMES * frame_cycles:
    cpu.step()
    line = (cpu.cycles // CPL) % LINES
    if line != last_line:
        last_line = line
        cmp_ = cpu.m[0xD012] | ((cpu.m[0xD011] & 0x80) << 1)
        if line == cmp_:
            state["pending"] = True
    if state["pending"] and not cpu.i and cpu.m[0xD01A] & 1:
        cpu.push(cpu.pc >> 8)
        cpu.push(cpu.pc & 255)
        cpu.push(cpu.p() & ~0x10)
        cpu.i = 1
        cpu.pc = cpu.rw(0xFFFE)
        cpu.cycles += 7
        irqs += 1
        state["pending"] = False

print(f"ran {cpu.cycles // frame_cycles} frames at {CPL} cycles/line, {irqs} IRQs, "
      f"{len(events)} VIC register writes; nslip={cpu.m[lbl['nslip']]} ndrop={cpu.m[lbl['ndrop']]} "
      f"nbuilt={cpu.m[lbl['nbuilt']]} maxobj={cpu.m[lbl['maxobj']]}")

# ---- reconstruct what the sprites show -------------------------------------------------------------------
reg = collections.defaultdict(int)
ev = 0
active = [0] * 8
snap = [None] * 8
displays = []        # (frame marker index, sprite, start line, x, ptr, colour)
corrupt = []
mi = -1
for L in range(int(cpu.cycles // CPL)):
    tchk = L * CPL + CPL * 55 // 65
    while ev < len(events) and events[ev][0] <= tchk:
        reg[events[ev][1]] = events[ev][2]
        ev += 1
    while mi + 1 < len(markers) and markers[mi + 1][0] <= tchk:
        mi += 1
    for s in range(8):
        x = reg[0xD000 + 2 * s] | (((reg[0xD010] >> s) & 1) << 8)
        ptr, col = reg[0x43F8 + s], reg[0xD027 + s]
        if active[s]:
            k = 21 - active[s]
            if k <= 16 and (x, ptr, col) != snap[s]:
                corrupt.append((mi, s, L))
            active[s] -= 1
        elif (reg[0xD015] >> s) & 1 and reg[0xD001 + 2 * s] == L % LINES and L % LINES < 256:
            snap[s] = (x, ptr, col)
            active[s] = 21
            displays.append((mi, s, L % LINES, x, ptr, col))

# ---- what the BBC recorded, through an independent copy of the transform -------------------------------
g2s = lambda g: 12 + g // 2 if g < 12 else (g - 12) // 2
rep = open(os.path.join(B, "replay.bin"), "rb").read()
frames, i = [], 0
while rep[i] != 0xFF:
    n = rep[i]
    objs = []
    for k in range(n):
        x, y, g = rep[i + 1 + 3 * k: i + 4 + 3 * k]
        ys = 50 + round(y * 200 / 256)
        if ys <= 235:
            objs.append((x * 4 + 24, ys, 0x10 + g2s(g)))
    frames.append(objs)
    i += 1 + 3 * n

per = collections.defaultdict(list)
for mi_, s, L, x, ptr, col in displays:
    per[mi_].append((x, L, ptr, s))
shown_by_marker, wrap, prev = [], 0, 0
for _, v in markers:                  # `shown` is a byte: unwrap it
    if v < prev:
        wrap += 256
    prev = v
    shown_by_marker.append(v + wrap)
missing = ghost = shown_total = 0
dy = collections.Counter()
worst = []
checked = 0
for m, shown in enumerate(shown_by_marker):
    if shown == 0 or m < 3:
        continue
    exp = list(frames[(shown - 1) % len(frames)])
    act = per.get(m, [])
    checked += 1
    left = list(act)
    for (ex, ey, ep) in sorted(exp, key=lambda e: e[1]):
        cand = [a for a in left if a[0] == ex and a[2] == ep]
        if not cand:
            missing += 1
            continue
        a = min(cand, key=lambda a: abs(a[1] - ey))
        left.remove(a)
        dy[a[1] - ey] += 1
        shown_total += 1
    ghost += len([a for a in left if a[3] != 7])
print(f"{checked} screen frames compared with the recorded positions")
print(f"objects shown {shown_total}, missing {missing} (not displayed at all), ghosts {ghost} (displayed, not expected)")
print("vertical displacement of shown objects (lines, + = lower than recorded):", dict(sorted(dy.items())))
print(f"sprite register changes while a sprite's data was still being drawn: {len(corrupt)}")
if corrupt:
    print("  first few (marker, sprite, line):", corrupt[:6])

if os.environ.get("DEBUG"):
    for m, shown in enumerate(shown_by_marker):
        if shown and frames[(shown - 1) % len(frames)] and m > 10:
            print("marker", m, "shown", shown, "expected", frames[(shown - 1) % len(frames)][:4], "actual", per.get(m, [])[:4])
            break
    print("first displays:", displays[:6])
    print("first markers:", markers[:6])

if os.environ.get("BAD"):
    shown_n = 0
    for m, shown in enumerate(shown_by_marker):
        if shown == 0 or m < 3:
            continue
        exp = sorted(frames[(shown - 1) % len(frames)], key=lambda e: e[1])
        act = sorted(per.get(m, []), key=lambda a: a[1])
        e_set = {(x, ptr) for x, y, ptr in exp}
        a_set = {(x, ptr) for x, L, ptr, s in act if s != 7}
        if e_set != a_set:
            print(f"marker {m} shown {shown} ({(shown-1)%len(frames)})")
            print("  expected:", [(x, y, hex(p)) for x, y, p in exp])
            print("  actual:  ", [(x, L, hex(p), 'spr%d' % s) for x, L, p, s in act])
            shown_n += 1
            if shown_n >= int(os.environ["BAD"]):
                break
