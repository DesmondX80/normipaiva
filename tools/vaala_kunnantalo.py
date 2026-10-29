#!/usr/bin/env python3
"""Vaalan kunnantalo vanhan torin paikalle Aseman pihan varteen aseman lähelle (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_kunnantalo.py   (viimeinen vaihe vaala_torisiirto.py:n jälkeen)
tie.json:iin merkitään "kunnantalo": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Rakennus (46 x 10 m, malli vaala.gd _build_kunnantalo) seisoo Siitarin puolella tietä (Aseman pihan eteläpuolella) julkisivu tielle päin, 22 m
  tiestä (edessä nurmikko, suihkulähde ja kävelyreitti). OSM:n yleispiirteinen Kunnanvirasto (225699563) korvataan tällä.
- Tontti tasoitetaan, rakennuksen ja reitin kohdalta puut pois (nurmikon männyt jäävät).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import vaala_keskusta as K  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

LEN, DEPTH = 46.0, 10.0
SETBACK = 27.0          # tien keskiviivasta rakennuksen keskelle
FOOT_X = 865.0          # Aseman pihan suoran piste, jonka kohdalle rakennuksen keskikohta tulee
REPLACED = (225699563,)


def unit(v):
    L = math.hypot(*v)
    return (v[0] / L, v[1] / L)


def rect(c, u, hx, hz):
    v = (-u[1], u[0])
    return [(c[0] + u[0] * x + v[0] * z, c[1] + u[1] * x + v[1] * z) for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]


def main():
    tie = VS.load_tie()
    if tie.get("kunnantalo"):
        sys.exit("kunnantalo on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("torisiirto"):
        sys.exit("aja ensin vaala_torisiirto.py")
    terr, trees = VS.Terrain(), VS.Trees()
    piha = next(r for r in tie["side_roads"] if r.get("name") == "Aseman piha")
    k0 = next(i for i, q in enumerate(piha["pts"]) if math.dist(q, piha["pts"][i + 1]) > 50.0)
    p0, p1 = piha["pts"][k0], piha["pts"][k0 + 1]
    pd = unit((p1[0] - p0[0], p1[1] - p0[1]))
    t = (FOOT_X - p0[0]) / pd[0]
    foot = (p0[0] + pd[0] * t, p0[1] + pd[1] * t)
    # Rakennus Siitarin puolella tietä (Aseman pihan eteläpuolella), julkisivu tielle päin: f osoittaa pois Siitarin puolelta.
    f = (-pd[1], pd[0])
    sx, sz = tie["siitari"]
    if (sx - foot[0]) * f[0] + (sz - foot[1]) * f[1] > 0.0:
        f = (-f[0], -f[1])
    c = (foot[0] - f[0] * SETBACK, foot[1] - f[1] * SETBACK)
    left = (-f[1], f[0])
    print("kunnantalo", [round(v, 1) for v in c], "julkisivu", [round(v, 3) for v in f])

    bld = rect(c, left, LEN / 2.0, DEPTH / 2.0)
    lot_c = (c[0] + f[0] * 5.0, c[1] + f[1] * 5.0)
    lot = rect(lot_c, left, LEN / 2.0 + 3.0, 14.0)

    removed, kept = [], []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        if b["id"] in REPLACED:
            removed.append(b)
        elif any(K.in_poly(q, lot) for q in pts) or any(K.in_poly(q, pts) for q in lot) or min(K.poly_dist(q, lot) for q in pts) < 2.0:
            if b.get("name") or b["kind"] == "big":
                sys.exit("kunnantalon paikka osuu rakennukseen %s %s" % (b["id"], b.get("name")))
            removed.append(b)
        else:
            kept.append(b)
    tie["buildings"] = kept
    print("poistetut rakennukset", [(b["id"], b["kind"], b.get("name")) for b in removed])

    terr.flatten([lot], 8.0)
    # Puut pois rakennuksen ja takaosan alta (nurmikon männyt jäävät; v <= 9 m rakennuksen keskeltä).
    zone = rect((c[0] + f[0] * 1.0, c[1] + f[1] * 1.0), left, LEN / 2.0 + 4.0, 11.0 + 4.0 / 2.0)
    pts, xs, zs = [], [q[0] for q in zone], [q[1] for q in zone]
    gx = min(xs)
    while gx <= max(xs):
        gz = min(zs)
        while gz <= max(zs):
            if K.in_poly((gx, gz), zone):
                pts.append((gx, gz))
            gz += 2.0
        gx += 2.0
    near_t = trees.near_any(pts, 3.0)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)

    tie["keskusta"]["kunnantalo"] = {"c": [round(c[0], 2), round(c[1], 2)], "face": [round(f[0], 4), round(f[1], 4)],
                                     "len": LEN, "depth": DEPTH}
    tie["kunnantalo"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
