#!/usr/bin/env python3
"""The loading screens for the C64, made from the original disc (disc/Disc025-Galaforce.ssd).

    make_intro.py DISC OUT.inc          (make intro does this)

* The MODE 5 loading picture (the file GalaSCR, 160 x 208, four colours: black, red, yellow, white) is exactly the C64's
  multicolour bitmap format (160 pixels across, two bits each), so it is not resampled: the 2-bit pixel values map straight to
  the C64's 01/10/11 colours (red from the screen RAM, yellow from the screen RAM, white from colour RAM). Its first six
  and last two lines are black, so the 200 lines 6-205 are the picture.
* The instruction pages (the MODE 7 teletext text of the BASIC loader GalaFor, lines 210-630) are run by a small interpreter
  of the statements they use on a 40 x 25 teletext screen, then become C64 text pages: colours, the sixel (block) graphics of
  the logo (as 64 extra characters), and the flashing line. The controls page is the C64's.
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import detok  # noqa: E402

COLS, ROWS = 40, 25
# teletext colours 1-7: red green yellow blue magenta cyan white -> C64 colours (light red and light blue: the C64's red and
# blue are too dark for text)
C64 = {0: 0, 1: 10, 2: 5, 3: 7, 4: 14, 5: 4, 6: 3, 7: 1}


# ---- the disc -------------------------------------------------------------------------------------------------------
def disc_files(path):
    """{name: bytes} for the files of an Acorn DFS .ssd image."""
    d = open(path, "rb").read()
    out = {}
    for i in range(d[256 + 5] // 8):
        name = d[8 + i * 8:15 + i * 8].decode("latin1").strip().rstrip("\x00 ")
        f = d[264 + i * 8:272 + i * 8]
        length = f[4] | f[5] << 8 | ((f[6] >> 4) & 3) << 16
        sec = f[7] | (f[6] & 3) << 8
        out[name] = d[sec * 256:sec * 256 + length]
    return out


# ---- the picture ----------------------------------------------------------------------------------------------------
def picture(scr):
    """C64 multicolour bitmap (8000 bytes, cell by cell) from the MODE 5 screen: 20 character columns of 16 bytes (two byte
    columns of 8 lines), 4 pixels a byte, the pixel's two bits taken from bit 7-n and bit 3-n."""
    assert len(scr) == 26 * 320

    def pix(y, x):
        cr, ln = divmod(y, 8)
        cx, r = divmod(x, 8)
        bx, n = divmod(r, 4)
        b = scr[cr * 320 + cx * 16 + bx * 8 + ln]
        return ((b >> (7 - n)) & 1) << 1 | ((b >> (3 - n)) & 1)

    for y in list(range(0, 6)) + list(range(206, 208)):
        assert not any(pix(y, x) for x in range(160)), "line %d is not blank" % y
    bm = bytearray(8000)
    for y in range(200):
        for x in range(160):
            cx, n = divmod(x, 4)
            cy, ln = divmod(y, 8)
            bm[(cy * 40 + cx) * 8 + ln] |= pix(y + 6, x) << (6 - 2 * n)
    return bytes(bm)


def rle(data):
    """a byte other than 0 stands for itself; 0 is followed by a count of zero bytes (0 = 256)"""
    out, i = bytearray(), 0
    while i < len(data):
        if data[i] == 0:
            j = i
            while j < len(data) and data[j] == 0 and j - i < 256:
                j += 1
            out += bytes([0, (j - i) & 255])
            i = j
        else:
            out.append(data[i])
            i += 1
    return bytes(out)


# ---- the MODE 7 pages -----------------------------------------------------------------------------------------------
class Screen:
    def __init__(self):
        self.mode7()

    def mode7(self):
        self.cells = [[32] * COLS for _ in range(ROWS)]
        self.win = (0, ROWS - 1, COLS - 1, 0)           # left, bottom, right, top
        self.r, self.c = 0, 0

    def home(self):
        self.r, self.c = self.win[3], self.win[0]

    def cls(self):
        l, b, r, t = self.win
        for y in range(t, b + 1):
            for x in range(l, r + 1):
                self.cells[y][x] = 32
        self.home()

    def newline(self):
        l, b, r, t = self.win
        self.c = l
        self.r += 1
        if self.r > b:
            for y in range(t, b):
                self.cells[y][l:r + 1] = self.cells[y + 1][l:r + 1]
            self.cells[b][l:r + 1] = [32] * (r - l + 1)
            self.r = b

    def put(self, ch):
        self.cells[self.r][self.c] = ch
        self.c += 1
        if self.c > self.win[2]:                         # (the cursor wraps at once, as on the BBC)
            self.newline()

    def tab(self, x, y=None):
        self.c = self.win[0] + x
        if y is not None:
            self.r = self.win[3] + y


def split_statements(line):
    out, cur, q = [], "", False
    for ch in line:
        if ch == '"':
            q = not q
        if ch == ":" and not q:
            out.append(cur)
            cur = ""
        else:
            cur += ch
    out.append(cur)
    return out


def string_bytes(s):
    return bytes(int(m.group(1), 16) if m.group(1) else ord(m.group(2)) for m in re.finditer(r"\\x([0-9a-f]{2})|(.)", s))


# The BBC's MODE 7 print routine swaps three codes on the way to the screen (so that the keyboard's # _ ` show as the
# teletext set's # _ and its pound sign): `#` is stored as &5F, `_` as &60 and the backtick as &23. In graphics mode the
# stored &23 is the two top blocks, which is how the logo's strings use the backtick.
MODE7_CODE = {0x23: 0x5F, 0x5F: 0x60, 0x60: 0x23}


def do_print(scr, args):
    i, newline = 0, True
    while i < len(args):
        ch = args[i]
        newline = True
        if ch == '"':
            j = args.index('"', i + 1)
            for b in string_bytes(args[i + 1:j]):
                scr.put(MODE7_CODE.get(b, b))
            i = j + 1
        elif ch == "'":
            scr.newline()
            i += 1
        elif ch == ";":
            newline = False
            i += 1
        elif args.startswith("TAB(", i):
            j = args.index(")", i)
            scr.tab(*[int(x) for x in args[i + 4:j].split(",")])
            i = j + 1
        elif args.startswith("CHR$", i):
            m = re.match(r"CHR\$(\d+)", args[i:])
            scr.put(MODE7_CODE.get(int(m.group(1)), int(m.group(1))))
            i += m.end()
        elif args.startswith("SPC", i):
            m = re.match(r"SPC\(?(\d+)\)?", args[i:])
            for _ in range(int(m.group(1))):
                scr.put(32)
            i += m.end()
        else:
            raise SystemExit("PRINT: cannot read %r" % args[i:])
    if newline:
        scr.newline()


# The BBC's controls page, with the C64's keys (the game's own: README.md)
PATCH = {
    550: 'PRINTTAB(14)CHR$130"; or = - Up"',
    560: 'PRINTTAB(14)CHR$130"/ - Down"',
    580: 'PRINT\'TAB(8)CHR$129"RUN/STOP - Exit from game"',
    620: 'PRINTTAB(10)CHR$129;"K - Keyboard/Joystick 2":*FX15',
}


def run(program):
    """The screens (40 x 25 lists of codes) at each wait for SPACE."""
    scr, pages = Screen(), []
    prog = {ln: t for ln, t in program}
    for ln, t in PATCH.items():
        assert ln in prog, ln
        prog[ln] = t
    for ln in sorted(prog):
        if ln < 210 or ln > 630:
            continue
        for st in split_statements(prog[ln].strip()):
            st = st.strip()
            if not st or st[0] in "*" or st.startswith("REM") or st.startswith("ONERROR"):
                continue
            if st.startswith("MODE7"):
                scr.mode7()
            elif st.startswith("VDU23"):
                pass
            elif st.startswith("VDU28"):
                l, b, r, t = [int(x) for x in st[6:].split(",")]
                scr.win = (l, b, r, t)
                scr.home()
            elif st == "CLS":
                scr.cls()
            elif st.startswith("PRINT"):
                do_print(scr, st[5:])
            elif st.startswith("REPEATUNTILGET=32"):
                pages.append([row[:] for row in scr.cells])
            elif st == "GOTO50":
                return pages
            else:
                raise SystemExit("line %d: cannot run %r" % (ln, st))
    return pages


def row_attrs(row):
    """For each cell: (code shown, graphics?, foreground 1-7, flashing?). The attributes a control code sets (colour,
    alphanumeric/graphics, flash) take effect from the next cell and are reset at the start of each row; the code itself
    shows as a space."""
    fg, gfx, flash, out = 7, False, False, []
    for code in row:
        if 128 <= code < 160:
            out.append((32, False, fg, flash))
            if 129 <= code <= 135:
                fg, gfx = code - 128, False
            elif 145 <= code <= 151:
                fg, gfx = code - 144, True
            elif code == 136:
                flash = True
            elif code == 137:
                flash = False
            elif code in (141, 140, 156, 157, 158, 159, 153, 152):
                raise SystemExit("teletext code %d is not supported" % code)
            continue
        out.append((code & 0x7f, gfx, fg, flash))
    return out


def sixel(c):
    """The six blocks (bit 0 top left, 1 top right, 2 middle left, 3 middle right, 4 bottom left, 5 bottom right) of a graphics
    character, or None when the character is a letter even in graphics mode (0x40-0x5f)."""
    if 0x20 <= c < 0x40 or 0x60 <= c < 0x80:
        return (c & 0x1f) | ((c >> 6) & 1) << 5
    return None


def screen_code(ch):
    """C64 screen code (the lower case character set) for an ASCII character."""
    if 97 <= ch <= 122:
        return ch - 96
    if ch == 64:
        return 0
    return {0x23: 28, 0x5F: 35, 0x60: 45}.get(ch, ch)   # (the teletext set's pound sign, #, and a dash)


def c64_page(cells):
    """Runs (offset in the screen, C64 colour | 0x80 if flashing, screen codes): letters as the character ROM's, blocks as
    codes 128 + the six-bit pattern (see sixel_font)."""
    runs = []
    for y, row in enumerate(cells):
        cur = None
        for x, (ch, gfx, fg, flash) in enumerate(row_attrs(row)):
            s = sixel(ch) if gfx else None
            if s is not None:
                code = 128 + s if s else 32
            else:
                code = screen_code(ch)
            blank = code == 32
            if blank:
                if cur:
                    cur[3].append(32)                  # (spaces inside a run stay in it; trailing ones are trimmed)
                continue
            colour = C64[fg] | (0x80 if flash else 0)
            if cur and cur[2] == colour and cur[0] == y:
                cur[3].append(code)
            else:
                if cur:
                    runs.append(cur)
                cur = [y, x, colour, bytearray([code])]
        if cur:
            runs.append(cur)
    out = []
    for y, x, colour, b in runs:
        while b and b[-1] == 32:
            b.pop()
        if b:
            assert 0 not in b
            out.append((y * COLS + x, colour, bytes(b)))
    return out


def sixel_font():
    """512 bytes: the 8x8 glyphs of the 64 block patterns. The teletext cell is 10 lines and its block rows are 3, 4 and 3 of
    them, so here 2, 4 and 2 of 8 lines (the crossbars of the logo's letters stay as thick as the BBC's); columns of 4 + 4 pixels."""
    out = bytearray()
    for v in range(64):
        for line in range(8):
            r = 0 if line < 2 else 1 if line < 6 else 2
            b = 0
            if v >> (2 * r) & 1:
                b |= 0xf0
            if v >> (2 * r + 1) & 1:
                b |= 0x0f
            out.append(b)
    return bytes(out)


def bytes_lines(b, per=16):
    return "\n".join("    .byte " + ",".join(str(v) for v in b[i:i + per]) for i in range(0, len(b), per))


def main(disc, out):
    files = disc_files(disc)
    bm = picture(files["GalaSCR"])
    comp = rle(bm)
    pages = run(program_lines(files["GalaFor"]))
    text = ["; made by tools/make_intro.py from the original disc: do not edit",
            "PIC_SIZE = %d" % len(bm), "N_PAGES = %d" % len(pages), "",
            "pic_rle:", bytes_lines(comp), "pic_rle_end:", "",
            "sixel_font:", bytes_lines(sixel_font()), "", "page_table:"]
    for n in range(len(pages)):
        text.append("    .word page_%d" % n)
    for n, p in enumerate(pages):
        text.append("page_%d:" % n)
        for off, colour, b in c64_page(p):
            text.append("    .word %d\n    .byte %d, %d\n    .byte %s" % (off, colour, len(b), ",".join(str(v) for v in b)))
        text.append("    .word $ffff")
    open(out, "w").write("\n".join(text) + "\n")
    print("%s: picture %d -> %d bytes, %d pages" % (out, len(bm), len(comp), len(pages)))
    if os.environ.get("SHOW"):
        for n, p in enumerate(pages):
            print("--- page", n + 1)
            for row in p:
                print("".join(chr(c & 0x7f) if 32 <= (c & 0x7f) < 127 and c < 128 else "#" if c >= 128 else "." for c in row).rstrip())


def program_lines(program):
    """detok.lines wants a file: write it beside the output and list it"""
    import tempfile
    with tempfile.NamedTemporaryFile(delete=False) as f:
        f.write(program)
    try:
        return list(detok.lines(f.name))
    finally:
        os.unlink(f.name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
