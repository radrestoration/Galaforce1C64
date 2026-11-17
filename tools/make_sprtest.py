"""Data for the sprite multiplexer test (spritetest/sprtest.s), made from the real decoded graphics in
src-c64/INIT.asm (explosion frames), sprites/shape_source.asm (aliens, ship) and the alien positions recorded from the original BBC game (tools/bbc_trace.sh).

usage: make_sprtest.py <outdir>

  shapes.bin   19 sprite blocks of 64 bytes: alien types 0-11, explosion frames 0-5, the ship
  tables.inc   ca65: the Y map (BBC 0-255 -> screen 0-199), BBC graphic index -> shape, per-shape own colour
  replay.bin   per frame: count, then count x (alx, aly, gra) - recorded BBC positions (swarm waves left out:
               they stay in the bitmap)
  report.txt   what the shared-colour choice costs

A multicolour sprite has two colours shared by all sprites (pixel values 01 and 11) and one of its own
(10); the bitmap has three per cell. Every shape's three colours are therefore assigned to those slots to
lose as few pixels as possible against the one global pair (chosen over all pairs, weighted by how often
each shape appears in the recorded waves).
"""
import collections
import itertools
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
out = sys.argv[1]
os.makedirs(out, exist_ok=True)
src = (open(os.path.join(ROOT, "src-c64", "INIT.asm")).read() + "\n" + open(os.path.join(ROOT, "sprites", "shape_source.asm")).read()).split("\n")

NAMES = ["0", "1b", "2", "1", "4", "5", "6", "7", "8", "9", "9", "9"]     # alien_bitmap_lo/hi order
consts = {m.group(1): int(m.group(2), 16) for l in src if (m := re.match(r"(\w+)\s*=\s*\$([0-9a-fA-F]+)", l))}


def block(label):
    i = next(n for n, l in enumerate(src) if l.startswith(label + ":"))
    data = bytearray()
    for l in src[i + 1:]:
        if re.match(r"^\w+:", l):
            break
        if (m := re.match(r"\s*\.byte\s+(.*?)(;.*)?$", l)):
            data += bytes(int(v.strip().lstrip("$"), 16) for v in m.group(1).split(","))
    assert len(data) == 48, (label, len(data))
    return bytes(data), src[i]


shapes = []          # (name, 48 cell-order bytes, (c01, c10, c11))
for t, n in enumerate(NAMES):
    d, _ = block("alien_bitmap_" + n)
    m, c = consts["ALIEN_MATRIX_" + n.upper()], consts["ALIEN_COLORRAM_" + n.upper()]
    shapes.append((f"alien{t}", d, (m >> 4, m & 15, c & 15)))
for f in range(6):
    d, line = block(f"explosion_frame_{f}")
    hi, lo, cr = map(int, re.findall(r"\((\d+)\)", line))
    shapes.append((f"expl{f}", d, (hi, lo, cr)))
d, _ = block("ship_bitmap")
shapes.append(("ship", d, (consts["SHIP_MATRIX_BYTE"] >> 4, consts["SHIP_MATRIX_BYTE"] & 15, consts["SHIP_COLORRAM_BYTE"] & 15)))


def pixels(cell):
    """48 cell-order bytes (top row cols 0-2, bottom row cols 0-2, 8 bytes per cell) -> 16 lines x 12 pixels (0-3)"""
    rows = []
    for y in range(16):
        r, line = divmod(y, 8)
        px = []
        for col in range(3):
            b = cell[(r * 3 + col) * 8 + line]
            px += [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
        rows.append(px)
    return rows


# ---- how often each shape appears in the recorded waves (weights for the colour choice) ----------------
trace = os.path.join(ROOT, "build", "trace")
SWARM = (3, 7, 11)
waves = {w: json.load(open(os.path.join(trace, f"w{w}.json")))["samples"] for w in range(16) if w not in SWARM}


def shape_of_gra(g):
    return 12 + g // 2 if g < 12 else (g - 12) // 2


freq = [0] * len(shapes)
for s in waves.values():
    for sample in s:
        for a in sample:
            freq[shape_of_gra(a[3])] += 1
freq[18] = max(freq) * 2         # the ship is always on screen

counts = []
for name, d, cols in shapes:
    c = [0, 0, 0, 0]
    for row in pixels(d):
        for p in row:
            c[p] += 1
    counts.append(c)

PERMS = list(itertools.permutations(range(3)))      # which logical colour (index into cols) goes to slot (A=01, own=10, B=11)


def cost(sh, A, B):
    """best (lost pixels, perm) for shape sh with shared colours A (sprite pixel 01) and B (11)"""
    best = None
    c = counts[sh]
    for perm in PERMS:
        ia, io, ib = perm
        cc = shapes[sh][2]
        lost = 0
        # logical pixel value v (1,2,3) uses colour cc[v-1]; the slot it lands in: ia->A, io->own, ib->B
        for v, slot in ((ia, "A"), (io, "O"), (ib, "B")):
            if slot == "A" and cc[v] != A:
                lost += c[v + 1]
            if slot == "B" and cc[v] != B:
                lost += c[v + 1]
        if best is None or lost < best[0]:
            best = (lost, perm)
    return best


best = None
for A in range(16):
    for B in range(16):
        tot = sum(freq[s] * cost(s, A, B)[0] for s in range(len(shapes)))
        if best is None or tot < best[0]:
            best = (tot, A, B)
_, SA, SB = best
NAMEC = "black white red cyan purple green blue yellow orange brown lred dgrey grey lgreen lblue lgrey".split()
rep = [f"shared colours: sprite pixel 01 = {SA} ({NAMEC[SA]}), 11 = {SB} ({NAMEC[SB]})", "shape  freq  pixels lost / drawn   own colour"]

# ---- the sprite blocks ----------------------------------------------------------------------------------
blocks = bytearray()
own = []
for sh, (name, d, cc) in enumerate(shapes):
    lost, perm = cost(sh, SA, SB)
    ia, io, ib = perm
    role = {ia + 1: 1, io + 1: 2, ib + 1: 3}          # logical bitmap pixel value -> sprite pixel value
    own.append(cc[io])
    rows = pixels(d)
    blk = bytearray()
    for y in range(21):
        px = rows[y] if y < 16 else [0] * 12
        bits = [0 if p == 0 else role[p] for p in px]
        for k in range(0, 12, 4):
            blk.append(bits[k] << 6 | bits[k + 1] << 4 | bits[k + 2] << 2 | bits[k + 3])
    blk.append(0)
    assert len(blk) == 64
    blocks += blk
    drawn = sum(counts[sh][1:])
    rep.append(f"{name:7s}{freq[sh]:6d}  {lost:4d} / {drawn:3d}        {own[-1]} ({NAMEC[own[-1]]})")
open(os.path.join(out, "shapes.bin"), "wb").write(blocks)

# eyeball check of the cell-order assumption: print the ship and alien 0 as ASCII
for name in ("ship", "alien0"):
    sh = [s[0] for s in shapes].index(name)
    rep.append(f"\n{name} (pixel values 1-3):")
    for row in pixels(shapes[sh][1]):
        rep.append("  " + "".join(".1230"[p] if p else "." for p in row))

# ---- tables ---------------------------------------------------------------------------------------------
# BBC scanline -> C64 screen line. The original does not draw aliens above scanline 23 (below the score line), so
# 23 goes to the first line under the C64 score bar (8) and 234, the ship's lowest position, to the ship's lowest
# row (line 184); in between it is linear (0.834 lines per scanline, against 0.78 for a plain 256 -> 200 scale).
YMAP_TOP, YMAP_BOT = (23, 8), (234, 184)
YSCALE = (YMAP_BOT[1] - YMAP_TOP[1]) / (YMAP_BOT[0] - YMAP_TOP[0])
ymap = [min(255, round(YMAP_TOP[1] + (y - YMAP_TOP[0]) * YSCALE)) if y >= YMAP_TOP[0] else (y * (YMAP_TOP[1] - 1)) // YMAP_TOP[0] for y in range(256)]
g2s = [shape_of_gra(g) if g in range(0, 12, 2) or g in range(12, 36, 2) else 0 for g in range(0, 36, 2)]


def bytes_lines(label, vals):
    s = f"{label}:\n"
    for i in range(0, len(vals), 16):
        s += " .byte " + ",".join(str(v) for v in vals[i:i + 16]) + "\n"
    return s


with open(os.path.join(out, "tables.inc"), "w") as f:
    f.write(f"SPR_SHARED_A = {SA}\nSPR_SHARED_B = {SB}\nSPR_SHAPE_SHIP = 18\n")
    f.write(bytes_lines("spr_ymap", ymap))
    f.write(bytes_lines("spr_gra2shape", g2s))
    f.write(bytes_lines("spr_own_col", own))

# ---- per-wave palettes ------------------------------------------------------------------------------------
# The two shared colours need not be the same all game: each wave gets the pair that costs its own aliens (as
# recorded in the BBC traces) and the ship the fewest wrong-coloured pixels. canon.bin holds every shape with
# its pixels as the original bitmap values (1-3); at the start of a wave the game remaps them into the sprite
# blocks with that wave's roles (spr_palette in SPRMUX.asm).
SHIP = 18
wave_pal = []                        # per wave (A, B)
wave_roles = []                      # per wave, per shape: (packed roles, own colour)
for w in range(16):
    f = collections.Counter()
    frames = 0
    for sample in waves.get(w, []):
        frames += 1
        for a in sample:
            f[shape_of_gra(a[3])] += 1
    f[SHIP] = max(frames, 1) * 3                                 # always on screen, and the player's own
    for e in range(12, 18):
        f[e] = max(frames // 50, 1)                              # explosions: every wave has some
    best = min((sum(v * cost(k, A, B)[0] for k, v in f.items()), (A, B) != (SA, SB), A, B) for A in range(16) for B in range(16))
    _, _, A, B = best
    wave_pal.append((A, B))
    row = []
    for sh in range(len(shapes)):
        lost, perm = cost(sh, A, B)
        ia, io, ib = perm
        role = {ia + 1: 1, io + 1: 2, ib + 1: 3}
        row.append((role[1] | role[2] << 2 | role[3] << 4, shapes[sh][2][io]))
    wave_roles.append(row)
    ev = sum(f[k] * cost(k, A, B)[0] for k in range(12))
    ev0 = sum(f[k] * cost(k, SA, SB)[0] for k in range(12))
    n = max(sum(f[k] for k in range(12)), 1)
    rep.append(f"wave {w:2d}: shared {NAMEC[A]}+{NAMEC[B]}; aliens lose {ev / n:5.1f} px each (global pair: {ev0 / n:5.1f}); ship loses {cost(SHIP, A, B)[0]}")
canon = bytearray()
for name, d, cc in shapes:
    blk = bytearray()
    for y in range(21):
        px = pixels(d)[y] if y < 16 else [0] * 12
        for k in range(0, 12, 4):
            blk.append(px[k] << 6 | px[k + 1] << 4 | px[k + 2] << 2 | px[k + 3])
    blk.append(0)
    canon += blk
open(os.path.join(out, "canon.bin"), "wb").write(canon)
with open(os.path.join(out, "pal.inc"), "w") as f:
    f.write("spr_wave_pal:\n" + "".join(f" .byte {A},{B}\n" for A, B in wave_pal))
    f.write("spr_role_lo:\n .byte " + ",".join(f"<(spr_roles+{w * 2 * len(shapes)})" for w in range(16)) + "\n")
    f.write("spr_role_hi:\n .byte " + ",".join(f">(spr_roles+{w * 2 * len(shapes)})" for w in range(16)) + "\n")
    f.write("spr_roles:\n")
    for w in range(16):
        f.write(" .byte " + ",".join(f"{r},{c}" for r, c in wave_roles[w]) + f"   ; wave {w}\n")

# ---- the replay: normal waves only, the densest stretches ---------------------------------------------
H = 24


def demand(sample):
    ys = sorted(ymap[a[2]] for a in sample)
    best = 0
    for i, y in enumerate(ys):
        best = max(best, sum(1 for z in ys[i:] if z < y + H))
    return best


def window(w, n):
    s = waves[w]
    bestsum, bi = -1, 0
    sc = [demand(x) for x in s]
    for i in range(0, len(s) - n):
        v = sum(sc[i:i + n])
        if v > bestsum:
            bestsum, bi = v, i
    return w, bi, n


segments = [(0, 0, 330), window(8, 180), window(14, 120), window(5, 120)]
stream = bytearray()
desc = []
for w, i, n in segments:
    desc.append(f"wave {w} samples {i}..{i + n}")
    for sample in waves[w][i:i + n]:
        sample = sample[:15]
        stream.append(len(sample))
        for _, x, y, g in sample:
            stream += bytes([x, y, g])
stream.append(0xFF)
open(os.path.join(out, "replay.bin"), "wb").write(stream)
rep.append("\nreplay: " + "; ".join(desc) + f" = {len(stream)} bytes")
open(os.path.join(out, "report.txt"), "w").write("\n".join(rep) + "\n")
print("\n".join(rep))
