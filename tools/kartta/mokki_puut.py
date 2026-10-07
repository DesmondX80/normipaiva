"""Mökin metsä oikeista puista (assets/mokki/puut.bin, scripts/forest.gd): MML:n laserkeilaus 2011 ja Luken VMI 2023.

Kävelyalueella ja 250 m sen ympärillä latvuston aukot täydennetään laserin näkemään latvustoon, kauempana (VIEW_PAD)
vain laserin erottamat valtapuut. Puita ei vesistöihin, pelloille, teille, rakennusten
päälle eikä pelin omiin aukkoihin (piha, laiturin polku, metsästyslavan aukea; vakiot scripts/mokki.gd:stä).
Puun maanpinta lasketaan samoin kuin mokki.gd:n h() (kartta.json:n dem/dem_far ja vesistöt). Lisäksi
naapurirakennusten harjakorkeudet laserista: assets/mokki/rakennukset.json.

Ajo: venv/bin/python tools/kartta/mokki_puut.py --cache <välimuisti>
"""
import argparse
import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import tarkka as T  # noqa: E402
import puut_teilta as PT  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
KARTTA = os.path.join(ROOT, "assets", "mokki", "kartta.json")
OUT = os.path.join(ROOT, "assets", "mokki", "puut.bin")
BUILD_OUT = os.path.join(ROOT, "assets", "mokki", "rakennukset.json")

# scripts/mokki.gd
YARD_C = (1.0, 2.35)
YARD_ROT_DEG = 17.6
AREA_MIN = (-400.0, -1750.0)  # kävelyalue karttakehyksessä
AREA_MAX = (600.0, 400.0)
VIEW_PAD = 550.0
FILL_PAD = 250.0  # latvuston aukot täydennetään näin kauas kävelyalueesta, kauempana vain valtapuut
YARD_CENTER = (-2.0, 10.0)
YARD_R = (21.0, 19.0)
DOCK = (8.9, 55.4)
DOCK_PATH = ((8.9, 27.0), (8.9, 56.9))
HUNT = (-30.0, 5.0)
HUNT_GLADE = (-44.0, 5.0)
HUNT_GLADE_R = 10.0
COTTAGE_LOCAL = (0.0, -1.0)
LASER_TILES = ["R4333D1", "R4333D2", "R4333D3", "R4333D4"]
MTK_SHEETS = ["R4333L"]


def to_local(x, z):
    b = math.radians(YARD_ROT_DEG)
    dx, dz = np.asarray(x) - YARD_C[0], np.asarray(z) - YARD_C[1]
    return dx * math.cos(b) + dz * math.sin(b), -dx * math.sin(b) + dz * math.cos(b)


def to_map(lx, lz):
    b = math.radians(YARD_ROT_DEG)
    lx, lz = np.asarray(lx), np.asarray(lz)
    return lx * math.cos(b) - lz * math.sin(b) + YARD_C[0], lx * math.sin(b) + lz * math.cos(b) + YARD_C[1]


def grid(dem, mx, mz):
    n, nz = dem.get("nx", dem["n"]), dem.get("nz", dem["n"])
    v = np.asarray(dem["values"], np.float64).reshape(nz, n)
    fx = np.clip((mx - dem["x0"]) / dem["step"], 0.0, n - 1.001)
    fz = np.clip((mz - dem["z0"]) / dem["step"], 0.0, nz - 1.001)
    i, j = fx.astype(int), fz.astype(int)
    u, w = fx - i, fz - j
    a = v[j, i] + (v[j, i + 1] - v[j, i]) * u
    b = v[j + 1, i] + (v[j + 1, i + 1] - v[j + 1, i]) * u
    return a + (b - a) * w


def seg_dist(px, pz, a, b):
    ax, az = a
    dx, dz = b[0] - ax, b[1] - az
    t = np.clip(((px - ax) * dx + (pz - az) * dz) / max(dx * dx + dz * dz, 1e-9), 0, 1)
    return np.hypot(px - ax - dx * t, pz - az - dz * t)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", required=True)
    a = ap.parse_args()
    rng = np.random.default_rng(1170)
    k = json.load(open(KARTTA, encoding="utf-8"))
    dem_in, dem_far = k["dem"], k["dem_far"]

    def dem_local(lx, lz):
        mx, mz = to_map(lx, lz)
        lim = -float(dem_in["x0"]) - 2.0
        edge = np.maximum(np.abs(mx), np.abs(mz))
        inner, far = grid(dem_in, mx, mz), grid(dem_far, mx, mz)
        t = np.clip((edge - (lim - 16.0)) / 16.0, 0.0, 1.0)
        return inner + (far - inner) * t

    base = float(grid(dem_in, *[np.array([v]) for v in to_map(*COTTAGE_LOCAL)])[0])
    water_y = float(dem_in["water"]) - base

    # Kohteet paikallisessa kehyksessä.
    waters, fields, roads, builds = [], [], [], []
    for f in k["features"]:
        lx, lz = to_local([p[0] for p in f["pts"]], [p[1] for p in f["pts"]])
        poly = np.stack([lx, lz], 1)
        if f["kind"] == "water":
            waters.append(poly)
        elif f["kind"] == "field":
            fields.append(poly)
        elif f["kind"] == "road":
            roads.append((poly, 3.5 if f.get("type") in ("tertiary", "secondary", "unclassified") else 2.6))
        elif f["kind"] == "building":
            builds.append(poly)

    def exclude_local(lx, lz):
        mx, mz = to_map(lx, lz)
        bad = (mx < AREA_MIN[0] - VIEW_PAD) | (mx > AREA_MAX[0] + VIEW_PAD) | (mz < AREA_MIN[1] - VIEW_PAD) | (mz > AREA_MAX[1] + VIEW_PAD)
        bad |= ((lx - YARD_CENTER[0]) / YARD_R[0]) ** 2 + ((lz - YARD_CENTER[1]) / YARD_R[1]) ** 2 < 1.0
        bad |= seg_dist(lx, lz, *DOCK_PATH) < 3.0
        bad |= np.hypot(lx - HUNT_GLADE[0], lz - HUNT_GLADE[1]) < HUNT_GLADE_R
        bad |= seg_dist(lx, lz, (HUNT[0] - 2.0, HUNT[1]), HUNT_GLADE) < 6.0
        for poly in waters + fields:
            near = (lx > poly[:, 0].min() - 1) & (lx < poly[:, 0].max() + 1) & (lz > poly[:, 1].min() - 1) & (lz < poly[:, 1].max() + 1)
            if near.any():
                bad[near] |= T.in_poly(poly, lx[near], lz[near])
        for poly, w in roads:
            near = (lx > poly[:, 0].min() - w) & (lx < poly[:, 0].max() + w) & (lz > poly[:, 1].min() - w) & (lz < poly[:, 1].max() + w)
            if near.any():
                d = np.full(near.sum(), np.inf)
                for p, q in zip(poly, poly[1:]):
                    d = np.minimum(d, seg_dist(lx[near], lz[near], p, q))
                bad[near] |= d < w
        for poly in builds:
            c = poly.mean(0)
            r = np.max(np.hypot(*(poly - c).T)) + 2.0
            near = np.hypot(lx - c[0], lz - c[1]) < r
            if near.any():
                bad[near] |= T.in_poly(poly, lx[near], lz[near]) | (np.hypot(lx[near] - c[0], lz[near] - c[1]) < r - 1.0)
        return bad

    def exclude(e, n):
        x, z = T.tm_to_frame(e, n)
        return exclude_local(*to_local(x, z))

    def fill_mask(e, n):
        x, z = T.tm_to_frame(e, n)
        return (x > AREA_MIN[0] - FILL_PAD) & (x < AREA_MAX[0] + FILL_PAD) & (z > AREA_MIN[1] - FILL_PAD) & (z < AREA_MAX[1] + FILL_PAD)

    # Lähdeaineiston rajaus TM35:ssä: näkyvä alue (karttakehys, z etelään = pohjoinen pienenee) varalla.
    ex = [T.frame_to_tm(x, z) for x in (AREA_MIN[0] - VIEW_PAD - 100, AREA_MAX[0] + VIEW_PAD + 100)
          for z in (AREA_MIN[1] - VIEW_PAD - 100, AREA_MAX[1] + VIEW_PAD + 100)]
    e0, e1 = min(float(q[0]) for q in ex), max(float(q[0]) for q in ex)
    n0, n1 = min(float(q[1]) for q in ex), max(float(q[1]) for q in ex)
    dem = T.Dem(a.cache, e0, n0, e1, n1)
    laser = T.Laser(a.cache, dem, LASER_TILES)
    e, n, h = laser.trees(rng, exclude, fill_mask)
    species = T.Species(a.cache, e0, n0, e1, n1)
    sp = species(rng, e, n, h)
    x, z = T.tm_to_frame(e, n)
    lx, lz = to_local(x, z)
    y = np.maximum(dem_local(lx, lz) - base, water_y + 0.12)
    T.write_trees(OUT, lx.astype(np.float32), y.astype(np.float32), lz.astype(np.float32), h.astype(np.float32), sp, rng)
    PT.filter_mokki()  # pihatie ja asfalttitien reunat (piirretty leveys)

    # Naapurirakennusten harjakorkeudet laserista (mokki.gd lukee ne tiedostosta rakennukset.json OSM-tunnisteittain).
    heights = {}
    for f in k["features"]:
        if f["kind"] != "building":
            continue
        be, bn = T.frame_to_tm([p[0] for p in f["pts"]], [p[1] for p in f["pts"]])
        hb = laser.building_height(list(zip(be, bn)))
        if hb is not None and 2.0 < hb:
            heights[str(f["id"])] = round(min(hb, 9.0 if f.get("type") in ("house", "detached") else 6.5), 1)
    with open(BUILD_OUT, "w", encoding="utf-8") as fh:
        json.dump({"source": "MML laserkeilaus 2011 (CC BY 4.0), harjan korkeus maasta (95. persentiili), "
                   "tools/kartta/mokki_puut.py", "height": heights}, fh, ensure_ascii=False, indent=0)
    print("rakennusten korkeuksia laserista: %d" % len(heights))


if __name__ == "__main__":
    main()
