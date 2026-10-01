"""Vaalan mopomatkan tarkka aineisto vaala_bake.py:lle (tarkka.py:n päälle):

- FrameDem: MML:n 2 m korkeusmalli uudelleennäytteistettynä mökin kehykseen (x itään, z etelään), jotta
  vaala_bake.py:n silmukat voivat kysyä korkeuksia nopeasti pisteittäin.
- refine(): korvaa reitti.json:n EU-DEM-korkeudet (tien keskilinja, sivut, keskustan ruudukko) korkeusmallilla
  ja OSM:n pellot, suot ja vedet maastotietokannalla; keskustan ulkopuoliset rakennukset maastotietokannasta,
  kaikille harjan korkeus laserista.
- trees(): laserpuut pelin kehykseen tien suhteen (vaala_bake.py:n to_game), tiivistetyllä välillä harvennettuna
  samassa suhteessa, jotta metsän tiheys säilyy.
"""
import math

import numpy as np
from scipy import ndimage

import tarkka as T

DEM_SHEETS_PAD = 1200.0
LASER_TILES = ["R4333D1", "R4333D2", "R4333D3", "R4333D4", "R4333F1", "R4333F2", "R4333F4", "R4334E1", "R4334E3"]
MTK_SHEETS = ["R4333L", "R4333R", "R4334R"]
FIELD = (32611, 32612)
BOG = (35300, 35411, 35412, 35421, 35422)
WATER = (36200, 36211, 36313)


class FrameDem:
    def __init__(self, cache, x0, z0, x1, z1, step=2.0):
        corners = T.frame_to_tm(np.array([x0, x1, x0, x1]), np.array([z0, z0, z1, z1]))
        e0, e1 = min(corners[0]) - 50, max(corners[0]) + 50
        n0, n1 = min(corners[1]) - 50, max(corners[1]) + 50
        self.dem = T.Dem(cache, e0, n0, e1, n1)
        self.x0, self.z0, self.step = x0, z0, step
        self.nx = int((x1 - x0) / step) + 1
        self.nz = int((z1 - z0) / step) + 1
        xs = x0 + np.arange(self.nx) * step
        rows = []
        for zz in np.array_split(z0 + np.arange(self.nz) * step, 16):
            X, Z = np.meshgrid(xs, zz)
            e, n = T.frame_to_tm(X.ravel(), Z.ravel())
            rows.append(self.dem.at(e, n).reshape(X.shape))
        self.a = np.vstack(rows).astype(np.float64)
        self._smooth = {}
        print("korkeusmalli kehyksessä %d x %d (%.0f m)" % (self.nx, self.nz, step))

    def at(self, x, z, smooth=0):
        a = self.a
        if smooth:
            if smooth not in self._smooth:
                self._smooth[smooth] = ndimage.gaussian_filter(self.a, smooth)
            a = self._smooth[smooth]
        fx = min(max((x - self.x0) / self.step, 0.0), self.nx - 1.001)
        fz = min(max((z - self.z0) / self.step, 0.0), self.nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        r0 = a[j, i] + (a[j, i + 1] - a[j, i]) * u
        r1 = a[j + 1, i] + (a[j + 1, i + 1] - a[j + 1, i]) * u
        return float(r0 + (r1 - r0) * v)


def _frame_ring(r):
    x, z = T.tm_to_frame([p[0] for p in r], [p[1] for p in r])
    return [[round(float(a), 2), round(float(b), 2)] for a, b in zip(x, z)]


def refine(d, cache, town_r=480.0):
    """Muokkaa reitti.json:n datan (d) paikallaan. Palauttaa (FrameDem, Laser)."""
    xs = [p[0] for p in d["line"]]
    zs = [p[1] for p in d["line"]]
    pad = DEM_SHEETS_PAD
    fd = FrameDem(cache, min(xs) - pad, min(zs) - pad, max(xs) + pad, max(zs) + pad)
    # Tien keskilinja ja sivut: korkeusmallin maanpinta (tienpinta on maanpintaa) hieman pehmennettynä.
    for p in d["line"]:
        p[2] = round(fd.at(p[0], p[1], smooth=1), 2)
    for p in d["side"]:
        p[2] = round(fd.at(p[0], p[1], smooth=1), 2)
    # Keskustan ruudukko 2 m Siitarin ympärille (ennen 25 m EU-DEM).
    sx, sz = d["siitari"]
    half = town_r + 160.0
    n = int(half * 2 / 2.0) + 1
    vals = [round(fd.at(sx - half + i * 2.0, sz - half + j * 2.0), 2) for j in range(n) for i in range(n)]
    d["town_dem"] = {"x0": sx - half, "z0": sz - half, "step": 2.0, "n": n, "values": vals}

    # Maankäyttö maastotietokannasta (OSM:n pellot, suot ja vedet pois).
    keep = [f for f in d["features"] if f["kind"] not in ("field", "bog", "water")]
    added = {"field": 0, "bog": 0, "water": 0}
    lim = (min(xs) - pad, min(zs) - pad, max(xs) + pad, max(zs) + pad)
    for luokka, name, rings, _rec in T.mtk(cache, MTK_SHEETS, "m_p"):
        kind = "field" if luokka in FIELD else "bog" if luokka in BOG else "water" if luokka in WATER else None
        if kind is None:
            continue
        outer = [r for r in rings if T.ring_area(r) < 0] or rings[:1]
        for r in outer:
            pts = _frame_ring(r)
            px = [p[0] for p in pts]
            pz = [p[1] for p in pts]
            if max(px) < lim[0] or min(px) > lim[2] or max(pz) < lim[1] or min(pz) > lim[3]:
                continue
            keep.append({"kind": kind, "id": -len(keep), "name": name, "pts": pts})
            added[kind] += 1
    print("maastotietokannasta: pellot %d, suot %d, vedet %d" % (added["field"], added["bog"], added["water"]))

    # Rakennukset maastotietokannasta (pohjapiirros ja tyyppi), korkeus laserista. Keskustassa OSM:n nimi, tyyppi
    # ja tunniste (Siitari, hotelli, kirkko, kaupat) siirretään MTK-rakennukselle, jonka keskipiste on OSM:n
    # pohjan sisällä (tunniste vain suurimmalle, jos OSM:n pohja kattaa useita: esim. koulun koko kortteli).
    laser = T.Laser(cache, fd.dem, LASER_TILES)
    osm = [f for f in keep if f["kind"] == "building"]
    out = [f for f in keep if f["kind"] != "building"]
    osm_polys = []
    for f in osm:
        q = np.array(f["pts"], float)
        osm_polys.append((f, q, q[:, 0].min(), q[:, 1].min(), q[:, 0].max(), q[:, 1].max()))
    types = {"house": "house", "cottage": "cabin", "shed": "shed", "big": "yes"}
    cand = []
    for luokka, _t, rings, _rec in T.mtk(cache, MTK_SHEETS, "r_p"):
        r = rings[0]
        pts = _frame_ring(r)
        if pts[0] == pts[-1]:
            pts = pts[:-1]
        c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
        if not (lim[0] < c[0] < lim[2] and lim[1] < c[1] < lim[3]):
            continue
        kind = T.BUILDING_KIND.get(luokka, "shed")
        f = {"kind": "building", "id": -100000 - len(cand), "building": types[kind], "pts": pts + [pts[0]]}
        hb = laser.building_height(r)
        if hb is not None and hb > 2.0:
            f["height"] = round(min(hb, {"house": 9.5, "cottage": 7.0, "shed": 5.5}.get(kind, 30.0)), 1)
            f["building_levels"] = max(1, int(round((f["height"] - 1.0) / 3.2)))
        f["_area"] = abs(T.ring_area(r))
        f["_c"] = c
        cand.append(f)
    owner = {}
    for f in cand:
        c = f["_c"]
        if math.dist(c, (sx, sz)) >= town_r:
            continue
        for o, q, bx0, bz0, bx1, bz1 in osm_polys:
            if bx0 <= c[0] <= bx1 and bz0 <= c[1] <= bz1 and T.in_poly(q, np.array([c[0]]), np.array([c[1]]))[0]:
                for k2 in ("building", "name", "amenity", "addr_street", "addr_housenumber"):
                    if k2 in o:
                        f[k2] = o[k2]
                if "building_levels" in o and "height" not in f:
                    f["building_levels"] = o["building_levels"]
                prev = owner.get(o["id"])
                if prev is None or f["_area"] > prev["_area"]:
                    owner[o["id"]] = f
                break
    for oid, f in owner.items():
        f["id"] = oid
    for f in cand:
        if f["id"] < 0:
            f.pop("name", None)  # nimi vain pääosalle (ei kylttejä joka siipeen)
        f.pop("_area")
        f.pop("_c")
        out.append(f)
    print("rakennukset maastotietokannasta %d (OSM-tunniste %d:lle)" % (len(cand), len(owner)))
    d["features"] = out
    return fd, laser


def trees(cache, laser, fd, real_route, to_game, code_at, ground_at, c_at, rng, rmax, rmax_far, ground_far):
    """Laserpuut pelin kehykseen. real_route: todellisen reitin pisteet (kehys). to_game(p, r) -> pelin piste tai
    None; code_at(x, z) -> maankäyttökoodi pelissä (255 = kaukomaasto); ground_at / ground_far(x, z) -> pelin
    maanpinta tarkalla / kaukoalueella; c_at(p) -> tiivistys. Alle rmax m tiestä latvuston aukot täydennetään,
    rmax_far m asti vain laserin erottamat valtapuut (kaukomaaston metsä)."""
    re, rn = T.frame_to_tm([p[0] for p in real_route], [p[1] for p in real_route])
    cell = 4.0
    w, h = int(laser.w / cell) + 1, int(laser.h / cell) + 1
    near = np.zeros((h, w), bool)
    ci = np.clip(((np.asarray(re) - laser.e0) / cell).astype(int), 0, w - 1)
    cj = np.clip(((laser.n1 - np.asarray(rn)) / cell).astype(int), 0, h - 1)
    near[cj, ci] = True
    dist = ndimage.distance_transform_edt(~near) * cell

    def zone(lim):
        def f(e, n):
            i = np.clip(((np.asarray(e) - laser.e0) / cell).astype(int), 0, w - 1)
            j = np.clip(((laser.n1 - np.asarray(n)) / cell).astype(int), 0, h - 1)
            return dist[j, i] < lim
        return f

    near_zone, far_zone = zone(rmax), zone(rmax_far)
    e, n, hh = laser.trees(rng, lambda a, b: ~far_zone(a, b), near_zone)
    species = T.Species(cache, laser.e0, laser.n0, laser.e1, laser.n1)
    sp = species(rng, e, n, hh)
    fx, fz = T.tm_to_frame(e, n)
    out = [[], [], [], [], []]
    for k in range(len(fx)):
        p = (float(fx[k]), float(fz[k]))
        c = c_at(p)
        if c < 1.0 and rng.random() > c:
            continue  # tiivistetty väli: sama tiheys
        g = to_game(p, rmax_far)
        if g is None:
            continue
        code = code_at(g[0], g[1])
        if code not in (0, 2, 4, 255):  # metsä, suo, piha, kaukomaasto
            continue
        out[0].append(g[0])
        out[1].append(ground_far(g[0], g[1]) if code == 255 else ground_at(g[0], g[1]))
        out[2].append(g[1])
        out[3].append(float(hh[k]))
        out[4].append(int(sp[k]))
    return [np.array(v, np.float32 if i < 4 else np.uint8) for i, v in enumerate(out)]
