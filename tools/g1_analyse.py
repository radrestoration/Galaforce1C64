import json, sys, collections
H = int(sys.argv[1]) if len(sys.argv) > 1 else 16          # sprite height in lines (+ any IRQ slack)
SHIP_Y = 227
def need(ys):
    """max sprites on one scanline for intervals [y, y+H)"""
    ev = []
    for y in ys:
        ev += [(y, 1), (y + H, -1)]
    cur = best = 0
    for _, d in sorted(ev, key=lambda e: (e[0], e[1])):
        cur += d; best = max(best, cur)
    return best
print(f"sprite height/occupancy {H} lines; y scaled x200/256; ship at BBC y {SHIP_Y}")
print("wave  samples maxAliens  maxPerLine(aliens)  maxPerLine(+ship)  %samples>7  %samples>8  worstY-band")
tot = collections.Counter()
for w in range(16):
    d = json.load(open(f"build/trace/w{w}.json"))
    ma = mp = mps = 0; over7 = over8 = n = 0; worst = None
    for s in d["samples"]:
        if not s: continue
        n += 1
        ys = [round(a[2] * 200 / 256) for a in s]
        ma = max(ma, len(s))
        p = need(ys); ps = need(ys + [round(SHIP_Y * 200 / 256)])
        if ps > mps: mps = ps; worst = sorted(ys)
        mp = max(mp, p)
        over7 += ps > 7; over8 += ps > 8
        tot[ps] += 1
    print(f"{w:4d} {n:8d} {ma:9d} {mp:19d} {mps:18d} {100*over7/max(n,1):10.1f} {100*over8/max(n,1):10.1f}  {worst[:12] if worst else ''}")
print("all waves, samples by per-line sprite demand (incl. ship):", dict(sorted(tot.items())))
