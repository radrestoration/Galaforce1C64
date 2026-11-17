"""Render every alien type (and the ship) twice: as the bitmap draws it (its own three colours) and as the sprite
shows it with the shared colours the game uses. usage: render_sprite_colours.py out.png [A B]  (shared colours
as C64 colour numbers, default the generated pair)."""
import os
import runpy
import sys
import io
import contextlib
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
out = sys.argv[1]
PAIR = [int(v) for v in sys.argv[2:4]]
tmp = os.path.join(os.path.dirname(out) or ".", "_rs")
sys.argv = ["x", tmp]
with contextlib.redirect_stdout(io.StringIO()):
    g = runpy.run_path(os.path.join(HERE, "make_sprtest.py"))
shapes, cost, pixels, SA, SB = g["shapes"], g["cost"], g["pixels"], g["SA"], g["SB"]
A, B = PAIR if PAIR else (SA, SB)
PAL = [(0, 0, 0), (255, 255, 255), (136, 57, 50), (103, 182, 189), (139, 63, 150), (85, 160, 73), (64, 49, 141), (191, 206, 114),
       (139, 84, 41), (87, 66, 0), (184, 105, 98), (80, 80, 80), (120, 120, 120), (148, 224, 137), (120, 105, 196), (159, 159, 159)]
Z = 8                                          # screen pixels per colour pixel (x2 wide, like the real thing)
names = [s[0] for s in shapes if not s[0].startswith("expl")]
idx = [i for i, s in enumerate(shapes) if not s[0].startswith("expl")]
img = Image.new("RGB", (len(idx) * 13 * Z * 2 + 8, 2 * 17 * Z + 8), (24, 24, 24))
for col, sh in enumerate(idx):
    name, d, cc = shapes[sh]
    lost, perm = cost(sh, A, B)
    ia, io_, ib = perm
    role = {ia + 1: A, io_ + 1: cc[io_], ib + 1: B}
    for y, row in enumerate(pixels(d)):
        for x, p in enumerate(row):
            if not p:
                continue
            for k, c in ((0, cc[p - 1]), (1, role[p])):
                for dy in range(Z):
                    for dx in range(Z * 2):
                        img.putpixel((4 + col * 13 * Z * 2 + x * Z * 2 + dx, 4 + k * 17 * Z + y * Z + dy), PAL[c])
img.save(out)
print("saved", out, "shared", A, B, "; top row = as the bitmap draws them, bottom row = as sprites")
print("order:", ", ".join(names))
