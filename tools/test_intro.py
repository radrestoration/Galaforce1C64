"""Headless check of the loading screens (intro/intro.asm): the PRG runs in the plain 6502 interpreter with a small VIC/CIA
model, SPACE is pressed for each page, and every page and the picture are drawn to PNGs in build/intro_test/ (as the C64 would show
them: the screen, colour RAM and the character set the program built, or the bitmap). Checks the picture against the disc's,
that RUN/STOP skips the pages, and that the loader asks for the file GAME from device 8 and jumps to $080D.

    tools/test_intro.py [skip|pickey]   skip: press RUN/STOP at the first page; pickey: press a key 30 frames into the picture
    NTSC=1 tools/test_intro.py          a 262-line machine (the picture waits 300 frames instead of 250)

The picture must stay up for 5 seconds (250 PAL frames, 300 NTSC) unless a key is pressed.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sim6502 import CPU  # noqa: E402
import make_intro  # noqa: E402
from PIL import Image  # noqa: E402

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
B = os.path.join(ROOT, "build")
OUT = os.path.join(B, "intro_test")
os.makedirs(OUT, exist_ok=True)
CHARGEN = "/usr/share/vice/C64/chargen-901225-01.bin"
SKIP = len(sys.argv) > 1 and sys.argv[1] == "skip"
PICKEY = len(sys.argv) > 1 and sys.argv[1] == "pickey"
NTSC = bool(os.environ.get("NTSC"))
CPL, LINES = (65, 263) if NTSC else (63, 312)
pic_t = None                                          # the frame the picture wait began

lbl = {}
for line in open(os.path.join(B, "intro.lbl")):
    _, a, n = line.split()
    lbl[n[1:]] = int(a, 16)
prg = open(os.path.join(B, "intro.prg"), "rb").read()
cpu = CPU()
cpu.m[0x0801:0x0801 + len(prg) - 2] = prg[2:]
cpu.pc, cpu.sp = 0x0810, 0xFF
cpu.m[0xBA] = 8
chargen = open(CHARGEN, "rb").read()                  # the sim has no banking: the ROM's set 2 sits where the program reads it
cpu.m[0xD800:0xDC00] = chargen[0x800:0xC00]
PAL = [(0, 0, 0), (255, 255, 255), (136, 0, 0), (170, 255, 238), (204, 68, 204), (0, 204, 85), (0, 0, 170), (238, 238, 119),
       (221, 136, 85), (102, 68, 0), (255, 119, 119), (51, 51, 51), (119, 119, 119), (170, 255, 102), (0, 136, 255), (187, 187, 187)]
raw_rd = cpu.rd
log = []


def frame():
    return cpu.cycles // (CPL * LINES)


def rd(a):
    a &= 0xFFFF
    if a == 0xD012:
        return (cpu.cycles // CPL) % LINES & 255
    if a == 0xD011:
        return (cpu.m[0xD011] & 0x7F) | (((cpu.cycles // CPL) % LINES >> 8) << 7)
    if a == 0xDC01:
        v = 0xFF
        if pic_t is not None:                            # in the picture wait: no key, or (pickey) SPACE 30 frames in
            return 0xEF if PICKEY and frame() >= pic_t + 30 and not cpu.m[0xDC00] & 0x80 else 0xFF
        # SPACE (column 7, row 4) for 3 frames in every 40 once released; RUN/STOP (column 7, row 7) in the skip test
        if not cpu.m[0xDC00] & 0x80 and frame() % 40 < 3 and frame() > 5:
            v &= ~(0x80 if SKIP else 0x10)
        return v
    if a == 0xDC00:
        return 0xFF
    return raw_rd(a)


cpu.rd = rd


def text_png(n):
    scr, col, cs = cpu.m[0x0400:0x0400 + 1000], cpu.m[0xD800:0xD800 + 1000], cpu.m[0x3800:0x4000]
    im = Image.new("RGB", (320, 200), PAL[0])
    px = im.load()
    for i, code in enumerate(scr):
        cx, cy = i % 40, i // 40
        c = PAL[col[i] & 15]
        for ln in range(8):
            b = cs[code * 8 + ln]
            for k in range(8):
                if b >> (7 - k) & 1:
                    px[cx * 8 + k, cy * 8 + ln] = c
    im.resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "page%d.png" % n))


def picture_png():
    bm, scr, col = cpu.m[0xE000:0xE000 + 8000], cpu.m[0xCC00:0xCC00 + 1000], cpu.m[0xD800:0xD800 + 1000]
    im = Image.new("RGB", (160, 200))
    px = im.load()
    for y in range(200):
        for x in range(160):
            cell = (y // 8) * 40 + x // 4
            v = bm[cell * 8 + y % 8] >> (6 - 2 * (x % 4)) & 3
            px[x, y] = (PAL[0], PAL[scr[cell] >> 4], PAL[scr[cell] & 15], PAL[col[cell] & 15])[v]
    im.resize((640, 400), Image.NEAREST).save(os.path.join(OUT, "picture.png"))


page = 0
shown = []
steps = 0
prev = 0
done = False
while steps < 60_000_000 and not done:
    steps += 1
    pc = cpu.pc
    if pc == lbl["wait_key"] and not lbl["wait_key"] < prev <= lbl["wait_key"] + 8:   # (the loop that waits for the keys to be let go starts at the same address)
        text_png(page)
        shown.append(bytes(cpu.m[0x0400:0x0400 + 1000]))
        page += 1
    if pc == lbl["wait_picture"] and pic_t is None:
        pic_t = frame()
    if pc == 0x0335:                                    # the relocated loader: the picture is complete
        picture_png()
        files = {}
        files["bitmap"] = bytes(cpu.m[0xE000:0xE000 + 8000])
        cpu.m[0x01] = 0x37
        # run the loader up to LOAD ($FFD5), which the sim does not have: read the name it gave SETNAM
        cpu.traps[0xFFBD] = lambda c: files.__setitem__("namelen", c.a) or files.__setitem__("name", (c.x, c.y))
        cpu.traps[0xFFBA] = lambda c: files.__setitem__("lfs", (c.a, c.x, c.y))

        def load(c):
            files["loaded"] = True
            c.c = 0
        cpu.traps[0xFFD5] = load
        for _ in range(200):
            if cpu.pc == 0x080D:
                break
            cpu.step()
        done = True
        break
    prev = pc
    cpu.step()
ref = make_intro.picture(make_intro.disc_files(os.path.join(ROOT, "disc", "Disc025-Galaforce.ssd"))["GalaSCR"])
name = bytes(cpu.m[files["name"][0] | files["name"][1] << 8:][:files["namelen"]])
print("pages shown:", page, " frames:", frame())
print("picture equals the disc's:", files["bitmap"] == ref)
print("loader: file %r, SETLFS %s, entered the game at $%04X" % (name, files["lfs"], cpu.pc))
ok = files["bitmap"] == ref and name == b"GAME" and files["lfs"] == (1, 8, 1) and cpu.pc == 0x080D
ok = ok and page == (1 if SKIP else 6)
waited = frame() - pic_t
print("picture waited %d frames" % waited)
ok = ok and (28 <= waited <= 36 if PICKEY else abs(waited - (300 if NTSC else 250)) <= 2)
print("ok" if ok else "FAILED")
sys.exit(0 if ok else 1)
