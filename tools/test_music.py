"""Check the SID music against the original's note data.

The game is played headless (tools/test_game_sprites.py, which logs every SID register write) to the point where
each tune has been started, then every note the SID was given is compared with what the BBC source says should
play: which note, when (the original ticks at 50 Hz, so 5 frames in 6 on NTSC) and for how long the gate is open.

    tools/test_music.py            runs the game headless itself (a minute or two); or SIDLOG=file.json to reuse a log
"""
import json
import math
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
PAL = bool(os.environ.get("PAL"))
FRAME_TICKS = 1.0 if PAL else 213 / 256.0     # ticks per frame: 50 Hz on PAL, 5 in 6 frames on NTSC

# ---- expected, from the generated data (itself made from the BBC source) ---------------------------------------------
inc = open(os.path.join(ROOT, "src-c64", "gen", "music.inc")).read().split("\n")
flat, labels, tunes, section = [], {}, [], None
tune_names = {}
for l in inc:
    m = re.match(r"MUS_(\w+) = (\d+)$", l)
    if m and m.group(1) not in ("TUNE_SIZE", "LONG_TICKS"):
        tune_names[int(m.group(2))] = m.group(1)
    t = l.split(";")[0].strip()
    if t.startswith("mus_streams:"):
        section = "streams"
    elif t.startswith("mus_tunes:"):
        section = "tunes"
    elif t.startswith("mus_inst:"):
        section = None
    if section == "streams" and re.match(r"mus_\w+:$", t):
        labels[t[:-1]] = len(flat)
    elif section == "streams" and t.startswith(".byte"):
        flat += [int(v) for v in t[5:].split(",")]
    elif section == "tunes":
        if t.startswith(".word"):
            tunes.append({"ch": [x.strip() for x in t[5:].split(",")]})
        elif t.startswith(".byte"):
            v = [int(x) for x in t[5:].split(",")]
            tunes[-1]["speed"] = v[:4]
            tunes[-1]["inst"] = [x // 8 for x in v[4:7]]
FREQ = {}
TAG = "pal" if PAL else "ntsc"
for tag in ("pal" if PAL else "ntsc",):
    lo = [int(v) for v in re.search(r"mus_f%s_lo:\n \.byte ([\d,]+)" % tag, "\n".join(inc)).group(1).split(",")]
    hi = [int(v) for v in re.search(r"mus_f%s_hi:\n \.byte ([\d,]+)" % tag, "\n".join(inc)).group(1).split(",")]
    FREQ[tag] = [a | b << 8 for a, b in zip(lo, hi)]
LONG_TICKS = int(re.search(r"MUS_LONG_TICKS = (\d+)", "\n".join(inc)).group(1))


def expected(tune):
    """per voice: [(tick, pitch, ticks_long)] for the notes (rests are gaps)"""
    out = []
    for ch in tunes[tune]["ch"]:
        i, tick, notes = labels[ch], 0, []
        while flat[i] != 0:
            b = flat[i]
            p, cls = b & 63, b >> 6
            n = tunes[tune]["speed"][cls]
            if p != 63:
                notes.append((tick, p, n))
            tick += n
            i += 1
        out.append(notes)
    return out


def gate_len(n):
    shave = max(n >> 2, 1)
    g = n - shave
    return g if g else 1


# ---- actual: the SID writes -------------------------------------------------------------------------------------------
def voice_notes(sid, voice, f0, f1):
    """[(frame, pitch idx, gate frames)] for one voice between two frames, from its control-register gate edges"""
    base = voice * 7
    reg = {}
    notes, on = [], None
    for fr, r, v in sid:
        if fr < f0 or fr > f1 or not base <= r < base + 7:
            continue
        reg[r - base] = v
        if r - base == 4:
            gate = v & 1
            if gate and on is None:
                f = reg.get(0, 0) | reg.get(1, 0) << 8
                on = (fr, f)
            elif not gate and on is not None:
                notes.append((on[0], on[1], fr - on[0]))
                on = None
    if on is not None:
        notes.append((on[0], on[1], None))
    return notes


def pitch_of(f):
    best = min(range(len(FREQ[TAG])), key=lambda n: abs(FREQ[TAG][n] - f))
    return best if abs(FREQ[TAG][best] - f) <= 2 else None


def check(tune, sid, f_start, f_end):
    name = tune_names[tune]
    exp = expected(tune)
    ok = True
    for v in range(3):
        got = voice_notes(sid, v, f_start, f_end)
        e = exp[v]
        # the first note is at the first tick, which is the first frame after the start
        t0 = got[0][0] if got else None
        bad_pitch = bad_time = bad_gate = 0
        for k, (tick, p, n) in enumerate(e):
            if k >= len(got):
                break
            fr, f, g = got[k]
            if pitch_of(f) != p:
                bad_pitch += 1
            want = t0 + (tick / FRAME_TICKS) if k == 0 or True else 0
            if abs((fr - got[0][0]) - (tick - e[0][0]) / FRAME_TICKS) > 1.5:
                bad_time += 1
            wg = gate_len(n) / FRAME_TICKS
            if g is not None and abs(g - wg) > 1.5:
                bad_gate += 1
        fine = len(got) == len(e) and not (bad_pitch or bad_time or bad_gate)
        ok &= fine
        print(f"  {name:8s} voice {v + 1}: {len(got):3d} notes heard, {len(e):3d} expected; wrong pitch {bad_pitch}, off time {bad_time}, "
              f"wrong gate {bad_gate}   {'ok' if fine else 'MISMATCH'}")
        if not fine and got:
            print("      first notes heard:", [(fr, pitch_of(f), g) for fr, f, g in got[:6]], " expected:", [(round(t / FRAME_TICKS, 1), p, round(gate_len(n) / FRAME_TICKS, 1)) for t, p, n in e[:6]])
    return ok


def length_frames(tune):
    return int(max(sum(tunes[tune]["speed"][flat[i] >> 6] for i in range(labels[ch], len(flat)) if True and flat[i] != 0 and all(flat[j] != 0 for j in range(labels[ch], i + 1))) for ch in tunes[tune]["ch"]) / FRAME_TICKS)


def run(tune):
    log = os.path.join(ROOT, "build", f"music_sid_{tune}.json")
    env = dict(os.environ, SIDLOG=log, PRESS="100:130:0:1", NOHIT="1", NOFIRE="1", TUNE=str(tune), **({"LINES": "312"} if PAL else {}))
    frames = length_frames(tune) + 400
    subprocess.run([sys.executable, "-I", os.path.join(HERE, "test_game_sprites.py"), str(120 + frames), "63" if PAL else "59"], env=env, check=True, stdout=subprocess.DEVNULL)
    sid = json.load(open(log))
    mark = next(f for f, r, v in sid if r == 0xFF)
    return sid, mark, frames


if __name__ == "__main__":
    which = [int(a) for a in sys.argv[1:]] or sorted(tune_names)
    good = True
    for t in which:
        sid, mark, frames = run(t)
        print(f"tune {t} {tune_names[t]} (started at frame {mark}, {length_frames(t)} frames long)")
        good &= check(t, sid, mark, mark + frames)
        # everything silent at the end: the last gate edge of each voice is an off
        for v in range(3):
            gates = [val & 1 for fr, r, val in sid if r == v * 7 + 4 and fr >= mark]
            if gates and gates[-1]:
                print(f"      voice {v + 1} still has its gate on at the end")
                good = False
    sys.exit(0 if good else 1)
