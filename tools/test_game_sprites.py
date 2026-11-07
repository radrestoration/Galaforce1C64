"""Headless check of the real game's alien sprites (src-c64/SPRMUX.asm): the PRG runs from its BASIC entry in the
plain 6502 interpreter with a small VIC-II / CIA model (raster counter from the cycle count, the raster
interrupt delivered the way the KERNAL's IRQ entry would, no keys pressed), so it goes title -> high scores ->
demo and plays itself. Every sprite register write is logged and what the sprites would show is reconstructed
line by line, then compared with the game's own alien pool as it was when each frame's list was built.

    tools/test_game_sprites.py [screen_frames] [cycles_per_line]

Checks that every active alien that should be visible is shown with the right shape, colour and position (to
within the few lines a crowded Y band may move it), that nothing else is shown, and that a sprite is never
re-programmed while its data is still being drawn. It cannot say anything about real VIC-II timing or looks.
"""
import collections
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
B = os.path.join(ROOT, "build")
FRAMES = int(sys.argv[1]) if len(sys.argv) > 1 else 3000
CPL = int(sys.argv[2]) if len(sys.argv) > 2 else 46
LINES = 263

lbl = {}
for line in open(os.path.join(B, "GalaForce1-c64.lbl")):
    _, a, n = line.split()
    lbl[n[1:]] = int(a, 16)

prg = open(os.path.join(B, "GalaForce1-c64.PRG"), "rb").read()
cpu = CPU()
addr = prg[0] | prg[1] << 8
cpu.m[addr:addr + len(prg) - 2] = prg[2:]
cpu.pc, cpu.sp = 0x080D, 0xFF
cpu.m[1] = 0x37

PRESS = [tuple(int(v) for v in k.split(':')) for k in os.environ.get('PRESS', '').split(',') if k]   # PRESS=frame0:frame1:col:row,...
state = dict(pending=False)
sid = []              # (frame, register, value) writes to the SID
events = []           # (cycles, addr, value) for the VIC sprite registers and pointers
builds = []         # cycle count at each spr_build
snaps = []            # alien pool at the end of each spr_build
markers = []          # (cycles, snapshot index on screen) at each top-of-frame D015 write
shown = dict(i=-1)
raw_rd = cpu.rd


def rd(a):
    a &= 0xFFFF
    if 0xD000 <= a < 0xD400:
        line = (cpu.cycles // CPL) % LINES
        if a == 0xD012:
            return line & 255
        if a == 0xD011:
            return (cpu.m[0xD011] & 0x7F) | ((line >> 8) << 7)
    elif a == 0xDC01:                       # keyboard matrix: a key pulls its row bit low when its column is selected
        v = 0xFF
        frame = cpu.cycles // (CPL * LINES)
        for (f0, f1, col, row) in PRESS:
            if f0 <= frame < f1 and not cpu.m[0xDC00] & (1 << col):
                v &= ~(1 << row)
        return v & 0xFF
    elif a == 0xDC00:
        return 0xFF                         # no joystick
    elif a == 0xDC0D:
        return 0
    return raw_rd(a)


cpu.rd = rd


def pool():
    m = cpu.m
    n = m[lbl["alien_pool_max"]]
    out = []
    for i in range(min(n, 40)):
        if m[lbl["alien_active"] + i]:
            out.append((m[lbl["alien_x"] + i], m[lbl["alien_y"] + i], m[lbl["alien_type"] + i],
                        m[lbl["alien_exploding"] + i], m[lbl["alien_explode_timer"] + i]))
    return dict(swarm=m[lbl["swarm_flag"]], aliens=out, wave=m[lbl["c64_curwave"]], state=m[lbl["game_state"]],
                demo=m[lbl["demo_flag"]])


def wr_hook(a, v):
    if a == lbl["sz_back_ready"] and v == 1:
        builds.append(cpu.cycles)
        snaps.append(pool())
    elif a == lbl["sz_front"]:
        shown["i"] = len(snaps) - 1
    elif a == 0xD019 and v & 1:
        state["pending"] = False
    if 0xD400 <= a <= 0xD418:
        sid.append((cpu.cycles // (CPL * LINES), a - 0xD400, v))
    if 0xD000 <= a <= 0xD02E or 0x43F8 <= a <= 0x43FF:
        events.append((cpu.cycles, a, v))
        if a == 0xD015:
            markers.append((cpu.cycles, shown["i"]))


cpu.write_hooks.append(wr_hook)

START_WAVE = os.environ.get("WAVE")      # WAVE=3: begin the game on that wave (3, 7 and 11 end in the swarm)
started = False
COUNT_AT = lbl.get(os.environ.get('COUNT'))      # COUNT=label: frames at which that label is reached
hits = []
import bisect
PROF = collections.Counter() if os.environ.get("PROF") else None     # PROF=1: cycles by nearest preceding label
_all = dict(lbl)
if os.environ.get("SYMS"):               # SYMS=file.dbg: ld65 --dbgfile output (every label, not just the exported ones)
    import re
    for m_ in re.finditer(r'^sym\s.*?name="([^"]+)".*?val=0x([0-9A-Fa-f]+).*?type=lab', open(os.environ["SYMS"]).read(), re.M):
        _all.setdefault(m_.group(1), int(m_.group(2), 16))
_ls = sorted((a, n) for n, a in _all.items())
label_addrs = [a for a, _ in _ls]
label_names = [n for _, n in _ls]
prof_from = 0
calls = []
depth = [0]
percall = collections.Counter()
passes = []
gl_lo = lbl["game_loop"]
gl_hi = lbl["game_loop"] + 0x300


def label_at(a):
    return label_names[bisect.bisect_right(label_addrs, a) - 1]
awaiting = False
WATCH = {lbl[n]: n for n in ('title_wait_loop', 'show_high_scores', 'hs_loop', 'start_demo', 'game_loop', 'hs_enter_name', 'game_loop_escape', 'start_tune') if n in lbl}
seen = {}
frame_cycles = CPL * LINES
irqs = 0
last_line = -1
while cpu.cycles < FRAMES * frame_cycles:
    if START_WAVE is not None and not started and cpu.pc == lbl["game_loop"]:
        started = True                       # the game has just started: switch to the wave asked for
        cpu.m[lbl["c64_curwave"]] = int(START_WAVE)
        cpu.push((lbl["game_loop"] - 1) >> 8)
        cpu.push((lbl["game_loop"] - 1) & 255)
        cpu.pc = lbl["init_alien_wave"]
        awaiting = True
        if os.environ.get("SCORE"):          # SCORE=<n>: start with that many ten-thousands, so the game over reaches name entry
            cpu.m[lbl["score_digits"] + 3] = int(os.environ["SCORE"])
    elif START_WAVE is not None and started and awaiting and cpu.pc == lbl["game_loop"]:
        awaiting = False
        if os.environ.get("SWARM"):          # SWARM=<n>: skip to group n of the wave's list (6 = the swarm in waves 3 and 7)
            cpu.m[lbl["wave_off"]] = int(os.environ["SWARM"])
    if PROF is not None:
        pc0, c0 = cpu.pc, cpu.cycles
        op0 = cpu.m[pc0]
        cpu.step()
        if started:                                  # inclusive cost of everything game_loop calls directly, per pass
            if op0 == 0x20:
                if cpu.pc != pc0 and not calls and gl_lo <= pc0 < gl_hi:
                    calls.append((cpu.pc, c0, len(cpu.stack_dbg()) if False else 0))
                    depth[0] = 1
                elif calls:
                    depth[0] += 1
            elif op0 == 0x60 and calls:
                depth[0] -= 1
                if depth[0] == 0:
                    t0 = calls.pop()
                    percall[label_at(t0[0])] += cpu.cycles - t0[1]
            if pc0 == lbl["game_loop"] + 5 and cpu.pc == lbl["game_loop"] + 3:    # still waiting: ignore
                pass
            if pc0 == lbl["game_loop"] + 5 and cpu.pc == lbl["game_loop"] + 7:
                passes.append(dict(percall)); percall.clear()
        if started and c0 > prof_from:
            k = bisect.bisect_right(label_addrs, pc0) - 1
            PROF[label_names[k]] += cpu.cycles - c0
    else:
        cpu.step()
    if COUNT_AT is not None and cpu.pc == COUNT_AT:
        hits.append(cpu.cycles // frame_cycles)
    if cpu.pc in WATCH and WATCH[cpu.pc] not in seen:
        seen[WATCH[cpu.pc]] = cpu.cycles // frame_cycles
    line = (cpu.cycles // CPL) % LINES
    if line != last_line:
        last_line = line
        if line == (cpu.m[0xD012] | ((cpu.m[0xD011] & 0x80) << 1)):
            state["pending"] = True
    if state["pending"] and not cpu.i and cpu.m[0xD01A] & 1:
        # the KERNAL's IRQ entry: push PC and P, then A, X, Y, and go through the $0314 vector
        cpu.push(cpu.pc >> 8)
        cpu.push(cpu.pc & 255)
        cpu.push(cpu.p() & ~0x10)
        cpu.i = 1
        cpu.push(cpu.a)
        cpu.push(cpu.x)
        cpu.push(cpu.y)
        cpu.pc = cpu.rw(0x0314)
        cpu.cycles += 20
        irqs += 1
        state["pending"] = False

print(f"ran {cpu.cycles // frame_cycles} frames at {CPL} cycles/line, {irqs} IRQs, {len(snaps)} sprite lists built, "
      f"{len(events)} VIC writes; pc=${cpu.pc:04X}")
if os.environ.get("EXTENT"):                   # EXTENT=1: where text is on the multicolour bitmap at the end of the run
    def pix(cx, cy, line):
        b = cpu.m[0x6000 + (cy * 40 + cx) * 8 + line]
        return [(b >> 6) & 3, (b >> 4) & 3, (b >> 2) & 3, b & 3]
    for cy in range(25):
        xs = [cx * 4 + k for cx in range(40) for line in range(8) for k, v in enumerate(pix(cx, cy, line)) if v]
        if xs:
            print("  cell row %2d: colour pixels %3d..%3d (of 160) margins %3d left %3d right, centre %.0f" % (cy, min(xs), max(xs), min(xs), 159 - max(xs), (min(xs) + max(xs)) / 2))
if COUNT_AT is not None:
    print("%s reached %d times; frames: %s" % (os.environ["COUNT"], len(hits), hits[:40]))
if PROF and passes:
    agg = collections.defaultdict(list)
    for ps in passes:
        for k, v in ps.items():
            agg[k].append(v)
    n = len(passes)
    print("per pass, cycles called from game_loop (inclusive) over %d passes; frame = %d cycles; mean / max / passes over 12000:" % (n, frame_cycles))
    for k, v in sorted(agg.items(), key=lambda kv: -sum(kv[1]))[:14]:
        print("  %-26s %6d %6d %5d" % (k, sum(v) / n, max(v), sum(1 for x in v if x > 12000)))
    slow = collections.Counter(max(ps, key=ps.get) for ps in passes if sum(ps.values()) > 12000)
    print("passes over one frame: %d of %d; biggest single call in them: %s" % (sum(slow.values()), n, dict(slow.most_common(6))))
    tots = sorted(sum(ps.values()) for ps in passes)
    print("pass total (calls only): median %d, p90 %d, max %d" % (tots[n // 2], tots[n * 9 // 10], tots[-1]))
if PROF:
    tot = sum(PROF.values())
    print("cycles by label (nearest preceding), total %d:" % tot)
    for n, c in PROF.most_common(25):
        print("  %-28s %5.1f%%" % (n, 100 * c / tot))
if os.environ.get("PACE"):                    # PACE=1: how many frames each game loop pass took
    d = [round((b - a) / frame_cycles, 2) for a, b in zip(builds, builds[1:])]
    h = collections.Counter(min(int(x + 0.5), 6) for x in d)
    print("frames per game loop pass (rounded) -> passes:", dict(sorted(h.items())))
    print("first 60 passes:", d[:60])
if os.environ.get("TRACEOUT"):                # TRACEOUT=file.json: the alien pool at every game loop pass
    import json
    json.dump(snaps, open(os.environ["TRACEOUT"], "w"))
waves = collections.Counter((s["demo"], s["wave"], s["state"]) for s in snaps)
print("first reached at frame:", dict(sorted(seen.items(), key=lambda kv: kv[1])))
print("game (demo flag, wave, state) -> lists:", dict(sorted(waves.items())))
print("most aliens in one list:", max((len(s["aliens"]) for s in snaps), default=0),
      "; lists during a swarm:", sum(1 for s in snaps if s["swarm"]))
if len(snaps) < 50:
    print("too few lists: the game did not get going")
    sys.exit(1)

# ---- what the sprites show, line by line ---------------------------------------------------------------------
reg = collections.defaultdict(int)
ev = 0
active = [0] * 7
snap = [None] * 7
displays = []
corrupt = []
mi = -1
for L in range(int(cpu.cycles // CPL)):
    tchk = L * CPL + CPL * 55 // 65
    while ev < len(events) and events[ev][0] <= tchk:
        reg[events[ev][1]] = events[ev][2]
        ev += 1
    while mi + 1 < len(markers) and markers[mi + 1][0] <= tchk:
        mi += 1
    lf = L % LINES
    for s in range(7):
        x = reg[0xD000 + 2 * s] | (((reg[0xD010] >> s) & 1) << 8)
        ptr, col = reg[0x43F8 + s], reg[0xD027 + s]
        if active[s]:
            if 21 - active[s] <= 16 and (x, ptr, col) != snap[s]:
                corrupt.append((mi, s, lf))
            active[s] -= 1
        elif (reg[0xD015] >> s) & 1 and reg[0xD001 + 2 * s] == lf and lf < 256:
            snap[s] = (x, ptr, col)
            active[s] = 21
            displays.append((mi, s, lf, x, ptr, col))

if os.environ.get("SHIPLOG"):                  # SHIPLOG=1: sprite 7 (the ship) at every 60th frame
    r7 = collections.defaultdict(int)
    j = 0
    for L in range(int(cpu.cycles // CPL)):
        t_ = L * CPL + CPL * 55 // 65
        while j < len(events) and events[j][0] <= t_:
            r7[events[j][1]] = events[j][2]
            j += 1
        if L % LINES == 200 and (L // LINES) % 60 == 0:
            on = r7[0xD015] >> 7
            x7 = r7[0xD00E] | (r7[0xD010] >> 7) << 8
            print("  frame %4d ship sprite %s at x=%3d y=%3d (col %.1f row %.1f) ptr %02X col %X" % (L // LINES, "on " if on else "off", x7, r7[0xD00F], (x7 - 24) / 8, (r7[0xD00F] - 50) / 8, r7[0x43FF], r7[0xD02E]))
# ---- expected, through an independent copy of the transform --------------------------------------------------
ymap = [round(y * 200 / 256) for y in range(256)]
own = None
for l in open(os.path.join(ROOT, "src-c64", "gen", "tables.inc")):
    pass
tab = open(os.path.join(ROOT, "src-c64", "gen", "tables.inc")).read()
own = [int(v) for v in tab.split("spr_own_col:")[1].replace(".byte", ",").replace("\n", "").split(",") if v.strip()]


def expected(s):
    if s["swarm"]:
        return []
    out = []
    for x, y, typ, expl, timer in s["aliens"]:
        line = ymap[y]
        if line < 8 or line > 168:
            continue
        shape = 12 + min(timer, 5) if expl else typ
        out.append((24 + 2 * x, 50 + line, 0x10 + shape, own[shape]))
    return out


per = collections.defaultdict(list)
for m_, s, lf, x, ptr, col in displays:
    per[m_].append((x, lf, ptr, col))
missing = ghost = ok = wrongcol = checked = 0
dy = collections.Counter()
for m, si in enumerate(m[1] for m in markers):
    if si < 0 or m < 3:
        continue
    exp = sorted(expected(snaps[si]), key=lambda e: e[1])
    left = list(per.get(m, []))
    checked += 1
    for (ex, ey, ep, ec) in exp:
        cand = [a for a in left if a[0] == ex and a[2] == ep]
        if not cand:
            missing += 1
            continue
        a = min(cand, key=lambda a: abs(a[1] - ey))
        left.remove(a)
        dy[a[1] - ey] += 1
        ok += 1
        if a[3] != ec:
            wrongcol += 1
    ghost += len(left)
print(f"{checked} screen frames compared with the alien pool")
print(f"aliens shown {ok}, missing {missing}, ghosts {ghost}, wrong colour {wrongcol}")
print("vertical displacement of shown aliens (lines, + = lower):", dict(sorted(dy.items())))
print(f"sprite register changes while a sprite's data was still being drawn: {len(corrupt)}")
if corrupt:
    print("  first few (frame, sprite, line):", corrupt[:6])
    if os.environ.get("CORRUPT"):
        f0 = markers[corrupt[0][0]][0]
        for c_, a_, v_ in events:
            if f0 - 2 * frame_cycles < c_ < f0 + frame_cycles and a_ in (0xD004, 0xD005, 0xD027 + 2, 0x43FA, 0xD015, 0xD010):
                print("     line %3d  %04X <- %02X" % ((c_ // CPL) % LINES, a_, v_))

        for mi_, s_, lf_ in corrupt[:2]:
            sn = snaps[markers[mi_][1]]
            print("   list at frame", mi_, "sprite", s_, "line", lf_, "alien lines:", sorted(ymap[a[1]] for a in sn["aliens"]), "x:", sorted(a[0] for a in sn["aliens"]))

if os.environ.get("BAD"):
    shown_n = 0
    for m, si in enumerate(mk[1] for mk in markers):
        if si < 0 or m < 3:
            continue
        exp = sorted(expected(snaps[si]), key=lambda e: e[1])
        have = {(a[0], a[2]) for a in per.get(m, [])}
        lost = [e for e in exp if (e[0], e[2]) not in have]
        if lost:
            print(f"frame {m} list {si} wave {snaps[si]['wave']}: {len(exp)} expected, missing {[(e[0], e[1] - 50) for e in lost]}")
            print("   expected lines:", [e[1] - 50 for e in exp], " shown lines:", sorted(a[1] - 50 for a in per.get(m, [])))
            shown_n += 1
            if shown_n >= int(os.environ["BAD"]):
                break

# sprites on a screen that should have none: from game over (game_loop_escape) to the next game
if "game_loop_escape" in seen:
    f0 = seen["game_loop_escape"]
    f1 = min([f for n, f in seen.items() if n in ("start_demo",) and f > f0] or [FRAMES])
    stray = sum(1 for (mi_, s, lf, x, ptr, col) in displays if f0 + 2 <= markers[mi_][0] // frame_cycles < f1 - 2)
    print(f"sprite images shown on the screens after game over (frames {f0}-{f1}): {stray}")

if sid:
    fr = sorted({f for f, _, _ in sid})
    print(f"SID: {len(sid)} register writes in frames {fr[0]}-{fr[-1]}; volume writes (D418): {[v for f, r, v in sid if r == 24][:6]};"
          f" gate-on writes: {sum(1 for f, r, v in sid if r in (4, 11, 18) and v & 1)}; distinct voice-1 frequencies: {len({v for f, r, v in sid if r == 1})}")
else:
    print("SID: no register writes at all")
