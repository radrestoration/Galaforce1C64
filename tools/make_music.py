"""Music and sound-effect data for the C64 SID engine (src-c64/MUSIC.asm), made from the original BBC source.

usage: make_music.py [bbc_src_dir] [out.inc]      (default build/bbc/src -> src-c64/gen/music.inc)

The notes and rhythm are the original's, read from MUSIC1-3.asm: each tune has three note streams, a note byte is
pitch (0-62, 63 = rest) + 64 * duration class, 0 ends a stream, and the class picks one of four delays (in 50 Hz
ticks, the BBC's vertical-sync event) from the tune's speed row. How it SOUNDS is not the original's (BBC ENVELOPE
numbers and OSWORD 7 sounds): the instruments and effects below are SID patches chosen for this port.

Pitch: a note's BBC pitch is 4 * n (4 steps to a semitone, 53 = middle C), so n semitones above 122 Hz.
"""
import math
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "build", "bbc", "src")
out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "src-c64", "gen", "music.inc")

NAMES = {"D1": 0, "D2": 64, "D3": 128, "D4": 192, "Rest": 63}


def lines(name):
    return open(os.path.join(src, name)).read().split("\n")


def values(text):
    """the EQUB items of one source line"""
    text = text.split("\\")[0]
    vals = []
    for m in re.finditer(r"EQUB\s*([^:]+)", text):
        expr = re.sub(r"\b0+(\d)", r"\1", m.group(1).strip())      # 01+D4 -> 1+D4
        vals.append(eval(expr, {"__builtins__": {}}, dict(NAMES)))
    return vals


# ---- the note streams: every EQUB line from the first stream label to the end of the data -----------------------
labels = {}            # name -> (file index, offset)
blobs = []             # per file: list of bytes
order = []             # label names in order, per file
for fi, (fname, first, last) in enumerate((("MUSIC1.asm", ".LOST1", None), ("MUSIC2.asm", ".STRT1", ".CodeEnd"), ("MUSIC3.asm", ".ZONE1", ".LT"))):
    data, started = [], False
    names = []
    for l in lines(fname):
        s = l.strip()
        if not started:
            if s.startswith(first):
                started = True
            else:
                continue
        if last and s.startswith(last):
            break
        m = re.match(r"\.(\w+)", s)
        if m:
            labels[m.group(1)] = (fi, len(data))
            names.append(m.group(1))
            s = s[m.end():].strip()
        if "EQUB" in s:
            data += values(s)
    blobs.append(data)
    order.append(names)

# ---- the tune table (MUSIC3.asm's .LT) and the speed rows (MUSIC1.asm's .SPT) ----------------------------------------
lt = []
for l in lines("MUSIC3.asm"):
    m = re.search(r"EQUW\s+(\w+):EQUB\s+(\w+)-(\w+):EQUB\s+(\w+)-(\w+):EQUB\s+(\d+):EQUB\s+(\d+):EQUB\s+(\d+)", l)
    if m:
        a, b, a2, c, a3, spd, env, dur = m.groups()
        assert a == a2 == a3
        lt.append((a, b, c, int(spd)))
assert len(lt) == 9, lt

spt, grab = [], False
for l in lines("MUSIC1.asm"):
    if l.strip().startswith(".SPT"):
        grab = True
        l = l.split(".SPT", 1)[1]
    elif l.strip().startswith(".ENV"):
        break
    if grab:
        spt += values(l)
speeds = []
for a, b, c, x in lt:
    speeds.append([spt[x - 3 + k] for k in range(4)])        # StartTune: SPD[3..0] = SPT[x..x-3]

# ---- the SID side: instruments, which tune uses which, effects --------------------------------------------------------
# instrument: waveform (with gate bit), pulse width (12 bit), then attack/decay and sustain/release twice: for notes
# shorter than LONG_TICKS ticks and for longer ones (a run of 1-tick notes wants a fast attack, the chord it ends on
# a slow, sustained one)
LONG_TICKS = 8
PLUCK, LEAD, PAD, BASS = range(4)
INST = [
    (0x41, 0x0800, 0x04, 0x24, 0x08, 0x44),     # PLUCK: square pluck, for the arpeggios
    (0x41, 0x0400, 0x06, 0x85, 0x09, 0xA8),     # LEAD:  narrow pulse, sustained
    (0x11, 0x0800, 0x05, 0x65, 0x48, 0xA9),     # PAD:   triangle, soft when held
    (0x21, 0x0800, 0x05, 0x45, 0x08, 0x78),     # BASS:  sawtooth
]
TUNE_NAMES = ["START", "BETWEEN", "OVER", "DEMO_A", "LOST", "ZONE", "DEMO_B", "DEMO_C", "DEMO_D"]
TUNE_INST = [
    (BASS, LEAD, LEAD),             # game start
    (PAD, PAD, PAD),                # between levels
    (PLUCK, PLUCK, PLUCK),          # game over (a canon of the lost-life arpeggio)
    (PLUCK, BASS, LEAD),            # demo a
    (PLUCK, PLUCK, PLUCK),          # lost a life
    (BASS, PLUCK, LEAD),            # the 16th-wave zone tune
    (PLUCK, BASS, LEAD),            # demo b (no third voice)
    (BASS, LEAD, LEAD),             # demo c
    (PLUCK, BASS, LEAD),            # demo d
]

NTSC, PAL = 1022727.0, 985248.0


def hz(n):
    return 261.626 * 2 ** ((4 * n - 53) / 48.0)


def sidf(h, clock):
    return min(65535, int(round(h * 16777216.0 / clock)))


def warble(hz, semis, half, total):
    """segments that swing a note up `semis` semitones and back, `half` frames each way, for `total` frames"""
    up = hz * 2 ** (semis / 12.0)
    segs, t = [], 0
    while t + 2 * half <= total:
        segs += [(half, hz, up), (half, up, hz)]
        t += 2 * half
    return segs


# effects: (waveform, pulse width, AD, SR, [(frames, hz_start, hz_end), ...])
FX = [
    ("FIRE", 0x41, 0x0300, 0x03, 0x02, [(8, 2200, 380)]),
    ("HIT", 0x81, 0x0000, 0x0A, 0x04, [(14, 2200, 300)]),                 # an alien blown up: a burst of noise
    ("CRASH", 0x81, 0x0000, 0x0C, 0x08, [(44, 1600, 90)]),                # the ship: a longer, deeper noise
    ("XLIFE", 0x41, 0x0800, 0x08, 0xA6, warble(785, 4, 7, 75)),            # extra life: ENVELOPE 3's slow warble, 1.5 s
    ("LSTMAN", 0x41, 0x0800, 0x08, 0xA6, warble(1230, 7, 3, 126)),         # last ship: ENVELOPE 9's quick, wide warble, 2.5 s
    # the BBC's bell (VDU 7: HIGH.asm's gn3, a wrong key in name entry): the OS defaults, channel 3, square wave, treble C =
    # 523.013 Hz, 0.3 s (6 x 1/20 s); amplitude 144 = -13 of -15, so near full volume with no envelope
    ("BELL", 0x41, 0x0800, 0x00, 0xD1, [(15, 523.013, 523.013)]),
]
FX_NOISE_NOTE = "noise 'frequency' is the SID's own, it only sets how coarse the hiss is"


def build():
    o = []
    w = o.append
    w("; generated by tools/make_music.py from the original BBC source - do not edit")
    w("MUS_TUNE_SIZE = 16")
    for i, n in enumerate(TUNE_NAMES):
        w(f"MUS_{n} = {i}")
    for i, f in enumerate(FX):
        w(f"SFX_{f[0]} = {i}")
    w("")
    # the streams, as the original lays them out (so a stream that runs on into the next label does, as in the original)
    w("mus_streams:")
    for fi, data in enumerate(blobs):
        idx = {off: nm for nm, (f, off) in labels.items() if f == fi}
        i = 0
        while i < len(data):
            for nm in [n for n, (f, off) in labels.items() if f == fi and off == i]:
                w(f"mus_{nm}:")
            j = i
            row = []
            while j < len(data) and (j == i or not any(f == fi and off == j for f, off in labels.values())) and len(row) < 16:
                row.append(data[j])
                j += 1
            w(" .byte " + ",".join(str(v) for v in row))
            i = j
    w("")
    w("mus_tunes:")
    for t, (a, b, c, x) in enumerate(lt):
        sp = speeds[t]
        ins = TUNE_INST[t]
        w(f" .word mus_{a},mus_{b},mus_{c}")
        w(" .byte " + ",".join(str(v) for v in sp) + "," + ",".join(str(v * 8) for v in ins) + ",0,0,0   ; " + TUNE_NAMES[t])
    w("")
    w(f"MUS_LONG_TICKS = {LONG_TICKS}")
    w("mus_inst:                              ; wave, pulse width lo, hi, AD, SR (short notes), AD, SR (long notes), 0")
    for wv, pw, ad, sr, adl, srl in INST:
        w(f" .byte {wv},{pw & 255},{pw >> 8},{ad},{sr},{adl},{srl},0")
    w("")
    for tag, clock in (("ntsc", NTSC), ("pal", PAL)):
        w(f"mus_f{tag}_lo:")
        w(" .byte " + ",".join(str(sidf(hz(n), clock) & 255) for n in range(64)))
        w(f"mus_f{tag}_hi:")
        w(" .byte " + ",".join(str(sidf(hz(n), clock) >> 8) for n in range(64)))
    w("")
    # effects: header wave, pw lo, pw hi, AD, SR, then segments: frames, freq lo, freq hi, delta lo, delta hi; 0 ends
    w("mus_fx_lo:")
    w(" .byte " + ",".join(f"<mus_fx_{f[0].lower()}" for f in FX))
    w("mus_fx_hi:")
    w(" .byte " + ",".join(f">mus_fx_{f[0].lower()}" for f in FX))
    for name, wv, pw, ad, sr, segs in FX:
        w(f"mus_fx_{name.lower()}:")
        w(f" .byte {wv},{pw & 255},{pw >> 8},{ad},{sr}")
        for frames, h0, h1 in segs:
            f0, f1 = sidf(h0, NTSC), sidf(h1, NTSC)
            d = int(round((f1 - f0) / frames)) & 0xFFFF
            w(f" .byte {frames},{f0 & 255},{f0 >> 8},{d & 255},{d >> 8}")
        w(" .byte 0")
    return "\n".join(o) + "\n"


text = build()
open(out, "w").write(text)
nbytes = sum(len(b) for b in blobs)
print(f"{out}: {nbytes} stream bytes in {len(labels)} streams, {len(lt)} tunes, {len(FX)} effects")
for t, (a, b, c, x) in enumerate(lt):
    print(f"  {t} {TUNE_NAMES[t]:8s} {a}/{b}/{c} ticks per class {speeds[t]}")
