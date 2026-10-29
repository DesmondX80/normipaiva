#!/usr/bin/env python3
"""Vaalan tori ja Zabuki kauemmaksi Siitarista, liikenneympyrä kauimmaiseen risteykseen
(assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_torisiirto.py   (viimeinen vaihe vaala_satamatie.py:n jälkeen)
tie.json:iin merkitään "torisiirto": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Vaalantie jatkuu RB_S m ja sen päähän tulee liikenneympyrä (r 12); kunnantalo mahtuu näin tien oikealle puolelle Siitarin viereen.
  Tulosuunnasta katsoen oikealle ympyrästä lähtee Aseman piha asemalle ja vasemmalle uusi Torintie torille.
- Tori (46 x 22 m, asfalttikenttä) ja Zabuki siirtyvät vasemmalle puolelle tietä ympyrästä
  pohjoiseen, yli 120 m Siitarista (ennen 52 m). Ratatie (kierros torin ja Kunnanviraston ympäri) poistuu.
- Vanha torin alue jää tasoitetuksi pihaksi. Tori- ja tietontilta puut pois, maasto tasoitetaan.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import vaala_keskusta as K  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

RB_S = 80.0                # ympyrän keskipiste näin kaukana Vaalantien päästä (kunnantalo mahtuu Siitarin viereen)
TORI_DIST, TORI_DEG = 45.0, -115.0   # torin keskipiste ympyrästä (suunta asteina, -90 = pohjoinen)
TORI_L, TORI_W = 46.0, 22.0
MK_L, MK_D = 46.0, 11.0     # Vaalan matkakeskus torin takana (pitkä sivu torille päin)
REPLACED = (225699564, 534430533, 225699563)  # matkakeskuksen ja torin tieltä: nimettömät isot rakennukset sekä Kunnanvirasto (korvaa vaala_kunnantalo.py)
RB_R = 12.0
KEEP = (225699578, K.KMARKET_ID, K.GASTHAUS_ID, 178199720)  # Siitari, kauppa, Gasthaus, asema


def unit(v):
    L = math.hypot(*v)
    return (v[0] / L, v[1] / L)


def dense(p, st=1.0):
    out = []
    for a, b in zip(p, p[1:] + p[:1]):
        n = max(1, int(math.dist(a, b) / st))
        out += [(a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n) for t in range(n)]
    return out


def near(a, b, m):
    da, db = dense(a), dense(b)
    return any(K.in_poly(q, b) for q in da) or any(K.in_poly(q, a) for q in db) or min(K.poly_dist(q, b) for q in da) < m


def rect(c, u, hx, hz):
    v = (-u[1], u[0])
    return [(c[0] + u[0] * x + v[0] * z, c[1] + u[1] * x + v[1] * z) for x, z in ((-hx, -hz), (hx, -hz), (hx, hz), (-hx, hz))]


def main():
    tie = VS.load_tie()
    if tie.get("torisiirto"):
        sys.exit("torisiirto on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("satamatie"):
        sys.exit("aja ensin vaala_satamatie.py")
    terr, trees = VS.Terrain(), VS.Trees()
    wl = tie["water_level"]
    roads = tie["side_roads"]
    piha = next(r for r in roads if r.get("name") == "Aseman piha")
    roads_old_pts = [q[:2] for q in piha["pts"][: next(i for i, q in enumerate(piha["pts"]) if math.dist(q, piha["pts"][i + 1]) > 50.0) + 2]]

    # Ympyrä Vaalantien jatkeelle RB_S m päähän tien päästä; oikealle Aseman pihan pitkä suora asemalle.
    road = tie["road"]
    e = (road[-1][0], road[-1][2])
    td = unit((e[0] - road[-8][0], e[1] - road[-8][2]))
    c = (e[0] + td[0] * RB_S, e[1] + td[1] * RB_S)
    k0 = next(i for i, q in enumerate(piha["pts"]) if math.dist(q, piha["pts"][i + 1]) > 50.0)
    p0, p1 = piha["pts"][k0], piha["pts"][k0 + 1]
    pd = unit((p1[0] - c[0], p1[1] - c[1]))
    print("ympyrä", [round(v, 1) for v in c], "tien päästä %.0f m" % RB_S)
    TORI_C = (c[0] + math.cos(math.radians(TORI_DEG)) * TORI_DIST, c[1] + math.sin(math.radians(TORI_DEG)) * TORI_DIST)

    # Vasen haara: ympyrästä torin eteläreunan keskelle; tori kohtisuoraan tietä vasten.
    ang = unit((TORI_C[0] - c[0], TORI_C[1] - c[1]))
    long_ax = (-ang[1], ang[0])
    tori = rect(TORI_C, long_ax, TORI_L / 2.0, TORI_W / 2.0)
    arm0 = (c[0] + ang[0] * (RB_R - 0.5), c[1] + ang[1] * (RB_R - 0.5))
    arm1 = (TORI_C[0] - ang[0] * (TORI_W / 2.0), TORI_C[1] - ang[1] * (TORI_W / 2.0))
    # Matkakeskus torin takana, julkisivu torille (face); Zabuki sen vasemmassa päässä (katsojasta torilta, +u = vasen).
    face = (-ang[0], -ang[1])
    left = (-face[1], face[0])
    mk_c = (TORI_C[0] + ang[0] * (TORI_W / 2.0 + 0.5 + MK_D / 2.0), TORI_C[1] + ang[1] * (TORI_W / 2.0 + 0.5 + MK_D / 2.0))
    mk = rect(mk_c, left, MK_L / 2.0, MK_D / 2.0)
    zu = MK_L / 2.0 - 6.0
    zc = (mk_c[0] + left[0] * zu + face[0] * (MK_D / 2.0 + 3.0), mk_c[1] + left[1] * zu + face[1] * (MK_D / 2.0 + 3.0))
    z_lot = rect(zc, left, K.ZB_SIZE[0] / 2.0 + 1.5, K.ZB_SIZE[1] / 2.0 + 1.5)
    print("tori", [round(v, 1) for v in TORI_C], "Siitarista %.0f m" % math.dist(TORI_C, tie["siitari"]), "| Zabuki", [round(v, 1) for v in zc])

    exit_r = (c[0] + pd[0] * (RB_R - 0.5), c[1] + pd[1] * (RB_R - 0.5))
    link_end = (c[0] - td[0] * (RB_R - 0.5), c[1] - td[1] * (RB_R - 0.5))
    new_piha = [exit_r, tuple(p1)]
    # Tiet: Ratatie pois, Aseman pihan alku pois (alkaa ympyrän reunasta), Vaalantien linkki ja Torintie uusia.
    piha["pts"] = [[round(exit_r[0], 2), round(exit_r[1], 2)]] + piha["pts"][k0 + 1:]
    tie["side_roads"] = [r for r in roads if r.get("name") != "Ratatie"]
    tie["side_roads"].append({"kind": "road", "hw": "secondary", "name": "Vaalantie", "surface": "paved", "_torisiirto": 1,
                              "pts": [[round(e[0], 2), round(e[1], 2)], [round(link_end[0], 2), round(link_end[1], 2)]]})
    arm = [[round(arm0[0], 2), round(arm0[1], 2)], [round(arm1[0], 2), round(arm1[1], 2)]]
    tie["side_roads"].append({"kind": "road", "hw": "residential", "name": "Torintie", "surface": "asphalt", "_torisiirto": 1, "pts": arm})
    for r in tie["side_roads"]:
        if r.get("name") == "Vaalan tori":
            r["pts"] = [[round(q[0], 2), round(q[1], 2)] for q in tori + [tori[0]]]

    # Rakennukset torin, Zabukin ja Torintien tieltä; suojatut eivät saa osua.
    lane = VL.resample([arm0, arm1], 2.0) + VL.resample([e, link_end], 2.0) + VL.resample(new_piha, 2.0)
    lots = [tori, z_lot, mk]
    ring_sq = rect(c, (1.0, 0.0), RB_R + 1.0, RB_R + 1.0)
    kept, removed = [], []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        if b["id"] in (K.STATION_ID,):
            kept.append(b)
            continue
        if b["id"] in REPLACED:
            removed.append(b)
            continue
        margin = [near(pts, p, 2.5) for p in lots + [ring_sq]]
        if any(margin) or min(VS.poly_dist(q, pts) for q in lane) < 5.5:
            if b["id"] in KEEP:
                sys.exit("uusi paikka osuu rakennukseen %s" % b["id"])
            removed.append(b)
        else:
            kept.append(b)
    tie["buildings"] = kept
    print("poistetut rakennukset", [(b["id"], b["kind"]) for b in removed])
    for pk in tie["parkings"]:
        if any(near([tuple(q) for q in pk], p, 1.0) for p in lots + [ring_sq]) or min(VS.poly_dist(q, [tuple(x) for x in pk]) for q in lane) < 5.5:
            sys.exit("parkkipaikka tiellä: %s" % pk[0])

    # Maasto: ympyrän ja torin tasoitus sekä Torintien pohja; puut pois.
    terr.flatten([ring_sq], 6.0)
    terr.flatten(lots, 8.0)
    # Vanha Aseman pihan alkupätkä (Vaalantien päästä suoraan asemalle) takaisin ympäröivään maahan.
    old = VL.resample([tuple(q) for q in roads_old_pts], 2.0)
    keep_lines = [VL.resample([tuple(q[:2]) for q in r["pts"]], 3.0) for r in tie["side_roads"] if r["kind"] == "road" and r.get("name") not in ("Aseman piha",)]
    keep_pts = [q for ln in keep_lines for q in ln] + VL.resample([arm0, arm1], 2.0) + VL.resample([e, link_end], 2.0) + VL.resample(new_piha, 2.0)
    rev = 0
    xs, zs = [q[0] for q in old], [q[1] for q in old]
    for i, j, q in terr.cells((min(xs) - 6, min(zs) - 6, max(xs) + 6, max(zs) + 6)):
        k = j * terr.nx + i
        if terr.codes[k] != VS.YARD or VL.line_dist(q, old) > 4.6:
            continue
        if any(math.dist(q, p) < 9.0 for p in keep_pts) or any(VS.poly_dist(q, b["pts"]) < 6.0 for b in tie["buildings"]):
            continue
        neigh = []
        for a_ in range(16):
            for rad in (7.0, 10.0):
                cc = terr.code((q[0] + math.cos(a_ * math.tau / 16) * rad, q[1] + math.sin(a_ * math.tau / 16) * rad))
                if cc in (VS.FOREST, VS.FIELD, VS.BOG):
                    neigh.append(cc)
        terr.codes[k] = max(set(neigh), key=neigh.count) if neigh else VS.FOREST
        terr.changed.add((i, j))
        rev += 1
    print("vanhaa pihan alkua takaisin maaksi: %d ruutua" % rev)
    terr.lane([arm0, arm1], wl)
    terr.lane([e, link_end], wl)
    terr.lane(new_piha, wl)
    pts = []
    for p in lots + [ring_sq]:
        xs, zs = [q[0] for q in p], [q[1] for q in p]
        gx = min(xs)
        while gx <= max(xs):
            gz = min(zs)
            while gz <= max(zs):
                if K.in_poly((gx, gz), p):
                    pts.append((gx, gz))
                gz += 2.0
            gx += 2.0
    near_t = trees.near_any(pts + lane + VL.resample([e, link_end], 2.0), 3.5)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)

    # Keskusta-data: Zabuki, ympyrä.
    tie["keskusta"]["matkakeskus"] = {"c": [round(mk_c[0], 2), round(mk_c[1], 2)], "face": [round(face[0], 4), round(face[1], 4)],
                                      "len": MK_L, "depth": MK_D}
    tie["keskusta"]["zabuki"] = {"c": [round(zc[0], 2), round(zc[1], 2)], "face": [round(face[0], 4), round(face[1], 4)]}
    tie["keskusta"]["asema"]["roundabout"] = {"c": [round(c[0], 2), round(c[1], 2)], "r": RB_R, "r_old": RB_R}
    tie["torisiirto"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
