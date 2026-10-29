#!/usr/bin/env python3
"""Satamantien alikulku radan alle (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_alikulku.py   (viimeinen vaihe vaala_kunnantalo.py:n jälkeen)
tie.json:iin merkitään "alikulku2": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Tasoristeys poistuu: Satamantie painuu radan kohdalla leikkaukseen, kiskot jäävät entiselle korkeudelleen ja
  vaala.gd _build_underpass_at rakentaa niiden alle betonikannen pilareineen (kuten Vaalaan tultaessa).
- Leikkaus: pohja tien tasolla (ajorata + piennar), sen sivuilla luiska (SLOPE), tie nousee takaisin maahan RAMP m:ssä.
- Alta pois puut ja pienet rakennukset; kiskojen RAIL-koodi vaihtuu leikkauksen kohdalla nurmeksi (alla ajetaan).
"""
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
CLEAR = 4.6        # vapaa korkeus tien pinnasta kannen alapintaan
SLAB = 0.9         # kansi (laatta + ratapohja)
W0 = 5.5           # leikkauksen pohjan puolileveys tien keskeltä
SLOPE = 0.9        # luiskan nousu (m/m)
RAMP = 62.0        # tie nousee takaisin maahan tämän matkan
HW = 2.75          # kadun puolileveys (vaala.gd STREET_HALF)


def unit(v):
    L = math.hypot(*v)
    return (v[0] / L, v[1] / L)


def uniform(pts, step):
    """Murtoviiva tasavälein (step m, viimeinen väli hieman lyhyempi)."""
    out = [pts[0]]
    carry = 0.0
    for a, b in zip(pts, pts[1:]):
        L = math.dist(a, b)
        d = step - carry
        while d <= L:
            out.append((a[0] + (b[0] - a[0]) * d / L, a[1] + (b[1] - a[1]) * d / L))
            d += step
        carry = L - (d - step)
    return out


def seg_cross(a, b, c, d):
    """Janojen ab ja cd leikkauspiste tai None."""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    den = r[0] * s[1] - r[1] * s[0]
    if abs(den) < 1e-9:
        return None
    t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / den
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / den
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return (a[0] + r[0] * t, a[1] + r[1] * t, c[2] if len(c) > 2 else 0.0)
    return None


def main():
    tie = VS.load_tie()
    if tie.get("alikulku2"):
        sys.exit("alikulku on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("kunnantalo"):
        sys.exit("aja ensin vaala_kunnantalo.py")
    terr, trees = VS.Terrain(), VS.Trees()
    sat = next(r for r in tie["side_roads"] if r["name"] == "Satamantie")
    pts = [tuple(q[:2]) for q in sat["pts"]]
    rails = [r["pts"] for r in tie["side_roads"] if r["kind"] == "rail"]

    # Tien ja ratojen leikkauspisteet.
    cross = []
    for a, b in zip(pts, pts[1:]):
        for rl in rails:
            for c, d in zip(rl, rl[1:]):
                x = seg_cross(a, b, c, d)
                if x is not None and not any(math.dist(x[:2], y[:2]) < 2.0 for y in cross):
                    cross.append(x)
    if not cross:
        sys.exit("Satamantie ei ylitä rataa")
    cx = sum(p[0] for p in cross) / len(cross)
    cz = sum(p[1] for p in cross) / len(cross)
    rail_y = max(p[2] for p in cross)
    # Radan suunta: leikkauskohtien ympäriltä, itään.
    rd = None
    for rl in rails:
        for c, d in zip(rl, rl[1:]):
            if math.dist((c[0], c[1]), (cx, cz)) < 20.0:
                rd = unit((d[0] - c[0], d[1] - c[1]))
                break
        if rd:
            break
    if rd[0] < 0:
        rd = (-rd[0], -rd[1])
    nrd = (-rd[1], rd[0])
    offs = [(p[0] - cx) * nrd[0] + (p[1] - cz) * nrd[1] for p in cross]
    span = max(offs) - min(offs) + 3.6          # ratakaistan leveys poikki (raiteet + ratapohja)
    mid = (max(offs) + min(offs)) / 2.0
    cx, cz = cx + nrd[0] * mid, cz + nrd[1] * mid
    # Tie leikkauskeskuksen kohdalla: lähin tien piste ja suunta.
    lane = uniform(pts, 2.0)
    km = min(range(len(lane)), key=lambda k: math.dist(lane[k], (cx, cz)))
    fd = unit((lane[min(km + 3, len(lane) - 1)][0] - lane[max(km - 3, 0)][0], lane[min(km + 3, len(lane) - 1)][1] - lane[max(km - 3, 0)][1]))
    sin_a = abs(rd[0] * fd[1] - rd[1] * fd[0])
    print("risteys", [round(v, 1) for v in (cx, cz)], "radat %d, ratakaista %.1f m, kulma %.0f°, kisko-y %.2f" %
          (len(cross), span, math.degrees(math.asin(sin_a)), rail_y))

    deck = rail_y
    road_y = deck - SLAB - CLEAR
    arc = [0.0]
    for a, b in zip(lane, lane[1:]):
        arc.append(arc[-1] + math.dist(a, b))
    s0 = arc[km]
    flat = (span / 2.0 + 2.5) / max(sin_a, 0.4)  # pohja radan alla ja sen molemmin puolin
    orig = [terr.ground(*q) for q in lane]
    # Syvyys ja pohjan korkeus matkan mukaan; pohja on tasainen ja nousee loivasti ulos ramppia pitkin.
    depth = []
    for s in arc:
        e = abs(s - s0)
        t = min(max((e - flat) / RAMP, 0.0), 1.0)
        depth.append((orig[km] - road_y) * (1.0 - t * t * (3.0 - 2.0 * t)))
    level = [orig[k] - depth[k] for k in range(len(lane))]
    rmax = W0 + (orig[km] - road_y) / SLOPE + 3.0
    n_w = int((flat + RAMP) / 2.0) + 2
    lo, hi = max(km - n_w, 0), min(km + n_w, len(lane) - 1)
    win = lane[lo:hi + 1]
    xs, zs = [q[0] for q in win], [q[1] for q in win]
    cut = 0
    for i, j, q in terr.cells((min(xs) - rmax, min(zs) - rmax, max(xs) + rmax, max(zs) + rmax)):
        k = j * terr.nx + i
        if terr.codes[k] in (WATER, 255):
            continue
        m = min(range(lo, hi + 1), key=lambda t: (lane[t][0] - q[0]) ** 2 + (lane[t][1] - q[1]) ** 2)
        r = math.dist(q, lane[m])
        if r > rmax or depth[m] < 0.05:
            continue
        tgt = level[m] + max(0.0, r - W0) * SLOPE
        if tgt < terr.h[k] - 0.02:
            code = YARD if r < 4.0 else (FIELD if terr.codes[k] in (RAIL, ROAD, SHOULDER, YARD) else terr.codes[k])
            terr.set(i, j, code, tgt)
            cut += 1
        elif r < 4.0:
            terr.set(i, j, YARD, terr.h[k])
    print("leikkaus: %d maastoruutua, pohja %.2f (maa %.2f), tasainen osuus ±%.0f m" % (cut, road_y, orig[km], flat))

    # Rakennukset leikkauksen alta; isot ja nimetyt eivät saa osua.
    kept, removed = [], []
    for b in tie["buildings"]:
        bp = [tuple(q) for q in b["pts"]]
        if min(VS.poly_dist(q, bp) for q in win) < rmax + 1.0:
            if b.get("name") or b["kind"] == "big":
                sys.exit("alikulku osuu rakennukseen %s %s" % (b["id"], b.get("name")))
            removed.append(b)
        else:
            kept.append(b)
    tie["buildings"] = kept
    print("poistetut rakennukset", [(b["id"], b["kind"]) for b in removed])
    near_t = trees.near_any(win, rmax)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)

    tie["underpass2"] = {"at": [round(cx, 2), round(cz, 2)], "dir": [round(rd[0], 4), round(rd[1], 4)],
                         "road_dir": [round(fd[0], 4), round(fd[1], 4)], "deck": round(deck, 2), "road_y": round(road_y, 2),
                         "hw": HW, "open": round(W0 - HW, 2), "slope": SLOPE, "deck_w": round(span + 2.0, 1), "road": "Satamantie"}
    tie["alikulku2"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
