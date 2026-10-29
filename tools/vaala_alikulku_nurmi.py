#!/usr/bin/env python3
"""Alikulun leikkauksen luiskat yhtenäiseksi nurmeksi (vaala_alikulku.py jätti luiskille alkuperäisen maankäytön: laikukas hiekka/metsä).

Ajo kerran: venv/bin/python tools/vaala_alikulku_nurmi.py   (vaala_alikulku.py:n jälkeen; idempotentti).
Leikkauksen ruudut (tien ±RMAX m, leikkauksen keskeltä ±REACH m) saavat koodin YARD (nurmi kuten tien piennar), korkeus säilyy.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_sahanranta as VS  # noqa: E402

FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
RMAX = 13.0
REACH = 66.0


def main():
    tie = VS.load_tie()
    u = tie.get("underpass2")
    if not u:
        sys.exit("ei alikulkua (underpass2)")
    cx, cz = u["at"]
    terr = VS.Terrain()
    sat = next(r for r in tie["side_roads"] if r["name"] == u["road"])
    pts = [tuple(q[:2]) for q in sat["pts"]]
    segs = list(zip(pts, pts[1:]))
    n = 0
    for i, j, q in terr.cells((cx - REACH - RMAX, cz - REACH - RMAX, cx + REACH + RMAX, cz + REACH + RMAX)):
        k = j * terr.nx + i
        if terr.codes[k] not in (FOREST, FIELD, BOG) or math.dist(q, (cx, cz)) > REACH + RMAX:
            continue
        best = min(_seg_dist(q, a, b) for a, b in segs)
        if best <= RMAX:
            terr.set(i, j, YARD, terr.h[k])
            n += 1
    print("luiskaruutuja nurmeksi: %d" % n)
    terr.save()


def _seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / max(dx * dx + dz * dz, 1e-9)))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t)


if __name__ == "__main__":
    main()
