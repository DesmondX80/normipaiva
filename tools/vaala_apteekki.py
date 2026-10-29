#!/usr/bin/env python3
"""Apteekki Satamantien varteen radan alikulun jälkeen oikealle puolelle (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_apteekki.py   (viimeinen vaihe vaala_alikulku.py:n jälkeen)
tie.json:iin merkitään "apteekki": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Satamantiellä kuljettaessa kohti satamaa radan jälkeen oikealla (lounaispuolella) APTEEKKI_S m alikulusta: rakennus
  (vaala.gd _build_apteekki), edessä asfalttinen pysäköinti tien ja julkisivun välissä. Tontti tasoitetaan, puut pois.
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import vaala_keskusta as K  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402
from vaala_alikulku import uniform  # noqa: E402

APTEEKKI_S = 112.0   # matka alikulun keskeltä tietä pitkin
LEN, DEPTH = 18.0, 11.0
PARK_D = 6.0         # pysäköinnin syvyys
SETBACK = 2.75 + 1.5 + PARK_D + DEPTH / 2.0   # tien keskeltä rakennuksen keskelle


def rect(c, u, hx, hz):
    v = (-u[1], u[0])
    return [(c[0] + u[0] * x + v[0] * z, c[1] + u[1] * x + v[1] * z) for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]


def main():
    tie = VS.load_tie()
    if tie.get("apteekki"):
        sys.exit("apteekki on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("alikulku2"):
        sys.exit("aja ensin vaala_alikulku.py")
    terr, trees = VS.Terrain(), VS.Trees()
    sat = next(r for r in tie["side_roads"] if r["name"] == "Satamantie")
    lane = uniform([tuple(q[:2]) for q in sat["pts"]], 1.0)
    u2 = tie["underpass2"]
    k0 = min(range(len(lane)), key=lambda k: math.dist(lane[k], u2["at"]))
    k = k0 + int(APTEEKKI_S)
    foot = lane[k]
    d = (lane[k + 3][0] - lane[k - 3][0], lane[k + 3][1] - lane[k - 3][1])
    L = math.hypot(*d)
    d = (d[0] / L, d[1] / L)
    right = (-d[1], d[0])              # kuljettaessa satamaa kohti oikealle (z kasvaa etelään)
    f = (-right[0], -right[1])         # julkisivu tielle päin
    c = (foot[0] + right[0] * SETBACK, foot[1] + right[1] * SETBACK)
    left = (-f[1], f[0])
    print("apteekki", [round(v, 1) for v in c], "julkisivu", [round(v, 3) for v in f], "tiellä %.0f m alikulusta" % APTEEKKI_S)

    park_c = (c[0] + f[0] * (DEPTH / 2.0 + PARK_D / 2.0), c[1] + f[1] * (DEPTH / 2.0 + PARK_D / 2.0))
    park = rect(park_c, left, LEN / 2.0 + 2.0, PARK_D / 2.0)
    lot = rect((c[0] + f[0] * 3.0, c[1] + f[1] * 3.0), left, LEN / 2.0 + 4.0, DEPTH / 2.0 + PARK_D / 2.0 + 4.0)

    kept, removed = [], []
    for b in tie["buildings"]:
        bp = [tuple(q) for q in b["pts"]]
        if any(K.in_poly(q, lot) for q in bp) or any(K.in_poly(q, bp) for q in lot) or min(K.poly_dist(q, lot) for q in bp) < 2.0:
            if b.get("name") or b["kind"] == "big":
                sys.exit("apteekin paikka osuu rakennukseen %s %s" % (b["id"], b.get("name")))
            removed.append(b)
        else:
            kept.append(b)
    tie["buildings"] = kept
    print("poistetut rakennukset", [(b["id"], b["kind"]) for b in removed])

    terr.flatten([lot], 6.0)
    pts, xs, zs = [], [q[0] for q in lot], [q[1] for q in lot]
    gx = min(xs)
    while gx <= max(xs):
        gz = min(zs)
        while gz <= max(zs):
            if K.in_poly((gx, gz), lot):
                pts.append((gx, gz))
            gz += 2.0
        gx += 2.0
    near_t = trees.near_any(pts, 3.0)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)

    tie["parkings"].append([[round(q[0], 2), round(q[1], 2)] for q in park + [park[0]]])
    tie["keskusta"]["apteekki"] = {"c": [round(c[0], 2), round(c[1], 2)], "face": [round(f[0], 4), round(f[1], 4)],
                                   "len": LEN, "depth": DEPTH, "park_depth": PARK_D}
    tie["apteekki"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
