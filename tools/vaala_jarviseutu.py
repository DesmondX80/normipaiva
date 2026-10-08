#!/usr/bin/env python3
"""Neittävän järviseudun tiivistys valmiissa mopomaailmassa (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: venv/bin/python tools/vaala_jarviseutu.py <kerroin>   (esim. 0.5 = ajomatkat puoleen)

Järviseudun järvet (vaala_bake.py NORTH_LAKES) on leivottu maastoon kuvauksella T: todellinen p -> c + (p - ref) * s.
Tämä skripti kutistaa T:n kertoimella Neittäväntien haaran pään (Nuojuankoskentien alun) ympäri ilman lähdeaineiston
välimuistia: nykyiset järvet täytetään suoksi (pohja lähimmästä rantaruudusta, pehmennys kuten leivonnassa
vanhoille pikkujärville), järvet kaiverretaan uudelle paikalle samalla tavalla kuin leivonnassa (rannat loivasti,
taso rannan maastosta), järvien alle jäävät talot, sivutiet ja puut poistetaan, ja tie.json:n mokki_map ja
north_lakes päivitetään. vaala.gd laskee tiet, Ranta-Rosvon, uimarannan ja laavun T:stä ajon aikana.
Päivitä vaala_bake.py:n NL_C ja NL_S tulostettuihin arvoihin, jotta täysi leivonta tuottaa saman.
"""
import json
import os
import struct
import sys

import numpy as np
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools", "kartta"))
import vaala_warp as VW  # noqa: E402

TIE = os.path.join(ROOT, "assets", "vaala", "tie.json")
MAASTO = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
PUUT = os.path.join(ROOT, "assets", "vaala", "puut.bin")
MOKKI_KARTTA = os.path.join(ROOT, "assets", "mokki", "kartta.json")
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
NORTH_LAKES = ("Pyöriäinen", "Etu-Salminen", "Pikku-Salminen", "Taka-Salminen", "Keskimmäinen")
NL_ROAD = 35.0  # järvet näin kauas reitistä ja haaroista (vaala_bake.py)


def main():
    f = float(sys.argv[1]) if len(sys.argv) > 1 else 0.5
    tie = json.load(open(TIE))
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    H2 = np.frombuffer(raw, np.float32, nx * nz, o).reshape(nz, nx).astype(np.float64)
    o += nx * nz * 4
    C2 = np.frombuffer(raw, np.uint8, nx * nz, o).reshape(nz, nx).copy()
    o += nx * nz
    rest = raw[o:]
    H0 = H2.copy()
    mm = tie["mokki_map"]
    neitt = next(b for b in tie["branches"] if b["name"] == "Neittäväntie")
    bend = (neitt["pts"][-1][0], neitt["pts"][-1][2])
    old_c, old_s, ref = mm["c"], mm["s"], mm["ref"]
    new_c = [round(bend[0] + (old_c[0] - bend[0]) * f, 2), round(bend[1] + (old_c[1] - bend[1]) * f, 2)]
    new_s = [round(old_s[0] * f, 4), round(old_s[1] * f, 4)]

    def t_old(p):
        return (old_c[0] + (p[0] - ref[0]) * old_s[0], old_c[1] + (p[1] - ref[1]) * old_s[1])

    def t_new(p):
        return (new_c[0] + (p[0] - ref[0]) * new_s[0], new_c[1] + (p[1] - ref[1]) * new_s[1])

    route_lines = [[(q[0], q[2]) for q in tie["road"]]] + [[(q[0], q[2]) for q in b["pts"]] for b in tie["branches"]]
    near_route = VW.game_raster([], x0, z0, nx, nz, cell, route_lines, 2.0 * NL_ROAD)
    mk = json.load(open(MOKKI_KARTTA))
    feats = [ft for ft in mk["features"] if ft["kind"] == "water" and ft.get("name") in NORTH_LAKES and len(ft["pts"]) >= 3]

    # --- Vanhat järvet suoksi. ----------------------------------------------------------------------------------
    old = np.zeros((nz, nx), bool)
    for ft in feats:
        old |= VW.game_raster([[t_old(q) for q in ft["pts"]]], x0, z0, nx, nz, cell)
    old = ndimage.binary_dilation(old, iterations=2) & (C2 == WATER) & ~near_route
    near_idx = ndimage.distance_transform_edt(old, return_distances=False, return_indices=True)
    H2[old] = H2[near_idx[0], near_idx[1]][old] - 0.3
    soft = ndimage.binary_dilation(old, iterations=3)
    H2[soft] = ndimage.gaussian_filter(H2, 2.0)[soft]
    C2[old] = BOG

    # --- Uudet järvet (kuten vaala_bake.py). ----------------------------------------------------------------------
    north_lakes = []
    nl_mask = np.zeros((nz, nx), bool)
    for ft in feats:
        poly = [t_new(q) for q in ft["pts"]]
        m_ = VW.game_raster([poly], x0, z0, nx, nz, cell) & ~near_route & (C2 != WATER) & (C2 != ROAD) & (C2 != RAIL)
        if m_.sum() < 20:
            print("järvi jää pois (liian pieni tai reitin päällä):", ft["name"])
            continue
        d_out = ndimage.distance_transform_edt(~m_) * cell
        ring = (~m_) & (d_out <= 40.0) & (C2 != BOG)
        lvl = float(np.percentile(H2[ring if ring.any() else (~m_) & (d_out <= 40.0)], 25)) - 0.5
        shore = (~m_) & (d_out < 45.0) & ~near_route & (C2 != WATER)
        t_ = np.sqrt(np.clip(d_out / 45.0, 0.0, 1.0))
        new_h = np.maximum(lvl + 0.15, lvl + 0.35 + (H2 - lvl - 0.35) * t_)
        H2[shore] = np.where(H2[shore] > lvl + 0.15, np.minimum(H2[shore], new_h[shore]), lvl + 0.15)
        H2[m_] = lvl - 1.2
        C2[m_] = WATER
        C2[shore & (d_out < 8.0) & (C2 == YARD)] = FOREST
        C2[shore & (d_out < 30.0) & (C2 == BOG)] = FOREST  # vanhan järven suo ei jää uuden rannalle
        nl_mask |= m_
        cz_, cx_ = np.argwhere(m_).mean(0)
        north_lakes.append({"name": ft["name"], "c": [round(float(x0 + cx_ * cell), 1), round(float(z0 + cz_ * cell), 1)],
                            "level": round(lvl, 2)})

    # --- Talot, sivutiet ja puut pois järvistä. -------------------------------------------------------------------
    wet_g = ndimage.binary_dilation(nl_mask, iterations=1)

    def wet_at(q):
        i_, j_ = int(round((q[0] - x0) / cell)), int(round((q[1] - z0) / cell))
        return 0 <= i_ < nx and 0 <= j_ < nz and wet_g[j_, i_]

    nb = len(tie["buildings"])
    tie["buildings"] = [bd for bd in tie["buildings"] if not any(wet_at(q) for q in bd["pts"])]
    cut_sr = []
    for r in tie["side_roads"]:
        if r["kind"] == "rail":
            cut_sr.append(r)
            continue
        cur = []
        for q in r["pts"]:
            if wet_at(q):
                if len(cur) > 1:
                    cut_sr.append(dict(r, pts=cur))
                cur = []
            else:
                cur.append(q)
        if len(cur) > 1:
            cut_sr.append(dict(r, pts=cur))
    tie["side_roads"] = cut_sr
    tie["mokki_map"]["c"] = new_c
    tie["mokki_map"]["s"] = new_s
    tie["north_lakes"] = north_lakes

    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, pnfx, pnfz, pnnx, pnnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (pnfx * pnfz + pnnx * pnnz) * 5 * 8
    gone = 0
    changed = np.abs(H2 - H0) > 0.05
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0:
            continue
        i_, j_ = int(round((x - x0) / cell)), int(round((z - z0) / cell))
        if not (0 <= i_ < nx and 0 <= j_ < nz):
            continue
        if wet_g[j_, i_]:
            struct.pack_into("<f", buf, q + 12, 0.0)
            gone += 1
        elif changed[j_, i_]:
            struct.pack_into("<f", buf, q + 4, float(H2[j_, i_]))

    with open(TIE, "w") as fo:
        json.dump(tie, fo, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as fo:
        fo.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        fo.write(H2.astype(np.float32).tobytes())
        fo.write(C2.astype(np.uint8).tobytes())
        fo.write(rest)
    with open(PUUT, "wb") as fo:
        fo.write(buf)
    print("Järviseutu tiivistetty kertoimella %.2f haaran pään %s ympäri: NL_C = %s, NL_S = %s" % (f, [round(v, 1) for v in bend],
          tuple(new_c), tuple(new_s)))
    print("järvet:", [(nl["name"], nl["c"]) for nl in north_lakes], "| vanhaa vettä suoksi %d ruutua" % old.sum(),
          "| taloja pois %d" % (nb - len(tie["buildings"])), "| puita pois %d" % gone)


if __name__ == "__main__":
    main()
