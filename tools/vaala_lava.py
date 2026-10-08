#!/usr/bin/env python3
"""Oulujärven lava ja sen ympäristö Vaalan mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_lava.py [--cache <välimuisti>]
(vaala_bake.py ajaa tämän lopuksi; ilman välimuistia, kun reitti.json:ssa on jo "lava_dem").

Lava oli Pahalahdentien päässä niemen kärjessä (64.550921 N, 26.822649 E), jossa Oulujoki alkaa Oulujärvestä:
idässä joki, etelässä järvi ja lounaassa Pahalahti, kaikki samassa pinnassa (korkeusmallissa 122,74 m). Pelissä lava
on aivan rannassa (SHORE_GAP m vedestä, lähin sellainen paikka todellisesta) ja vähän pienempi, ja Pahalahdentie on
asfaltoitu lavalle asti.

Niemi (AREA) on mopomatkan 1:1-aluetta: vaala_bake.py kuvaa sen maaston, vedet ja metsän samalla saumattomalla
kuvauksella kuin muunkin alueen (tools/kartta/vaala_warp.py, AREA:n ankkurit). Tämä lisää vain lavan omat asiat:
- lava, tontti ja Pahalahdentie (asfaltti lavalle asti, maasto tasoitetaan tien alle) ja aidan sisäpuoli nurmeksi
- aita lavan ympäri rannasta rantaan (pohjoisessa joelta Pahalahdentien portin yli, lännessä Pahalahteen)
- puut pois tontilta, tieltä, aidan linjalta ja vedestä; tasoitetulla maalla uudelle korkeudelle.
"""
import argparse
import base64
import json
import math
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "vaala", "reitti.json")
TIE = os.path.join(ROOT, "assets", "vaala", "tie.json")
MAASTO = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
PUUT = os.path.join(ROOT, "assets", "vaala", "puut.bin")

LAT0, LON0 = 64.5054523, 26.6672225  # Kaisuantie 62 (vaala_reitti.py)
M_PER_DEG = 111320.0
LAVA = (64.550921, 26.822649)
LAVA_SIZE = (28.0, 36.0)  # n. 1 000 m² (todellinen n. 1 500 m²), pitkä sivu z-suunnassa (vaala.gd _build_lava)
SHORE_GAP = (3.0, 7.0)    # lava aivan rannassa: seinästä lähimpään veteen (m)
ROAD_NAME = "Pahalahdentie"
# Niemen 1:1-alue (x0, z0, x1, z1; vaala_bake.py:n ankkurit x0 + 60 m alkaen) todellisessa kehyksessä; pelissä
# se siirtyy niemen siirron (tie.json "lava_off") mukana: area(off). AREA on viimeksi käytetty pelin alue.
AREA_REAL = (7149.18, -5936.78, 8149.18, -4786.78)
AREA = (300.0, -1300.0, 1300.0, -150.0)


def area(off):
    return (AREA_REAL[0] + off[0], AREA_REAL[1] + off[1], AREA_REAL[2] + off[0], AREA_REAL[3] + off[1])
FENCE_GAP = (30.0, 25.0)  # aidan etäisyys lavasta pohjoiseen ja länteen
FENCE_INTO_WATER = 8.0
GATE_W = 6.0
DEM_PAD = 40.0
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
OUTSIDE = 255


def to_xz(lat, lon):
    return ((lon - LON0) * math.cos(math.radians(LAT0)) * M_PER_DEG, -(lat - LAT0) * M_PER_DEG)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def resample(pts, step):
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        L = math.dist(a, b)
        m = max(int(L / step), 1)
        for k in range(1, m + 1):
            out.append((a[0] + (b[0] - a[0]) * k / m, a[1] + (b[1] - a[1]) * k / m))
    return out


def seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz or 1e-9
    t = max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / L2))
    return math.dist(p, (a[0] + dx * t, a[1] + dz * t))


def line_dist(p, pts):
    return min(seg_dist(p, a, b) for a, b in zip(pts, pts[1:]))


def in_box(p, b, grow=0.0):
    return b[0] - grow <= p[0] <= b[2] + grow and b[1] - grow <= p[1] <= b[3] + grow


# --- Lähdeaineisto: korkeusmalli AREA:lle todellisessa kehyksessä (reitti.json "lava_dem"). ---------------------

def fetch_dem(d, off, cache):
    """MML:n 2 m korkeusmalli 4 m ruudukoksi AREA:n alle (tarvitsee venvin: tools/kartta/requirements.txt)."""
    sys.path.insert(0, os.path.join(ROOT, "tools", "kartta"))
    import tarkka as T  # noqa: E402
    x0, z0 = AREA[0] - off[0] - DEM_PAD, AREA[1] - off[1] - DEM_PAD
    nx = int((AREA[2] - AREA[0] + 2 * DEM_PAD) / 4.0) + 1
    nz = int((AREA[3] - AREA[1] + 2 * DEM_PAD) / 4.0) + 1
    xs = [x0 + i * 4.0 for i in range(nx)]
    zs = [z0 + j * 4.0 for j in range(nz)]
    e, n = T.frame_to_tm([x for _z in zs for x in xs], [z for z in zs for _x in xs])
    dem = T.Dem(cache, min(e) - 50, min(n) - 50, max(e) + 50, max(n) + 50)
    vals = dem.at(e, n)
    cm = struct.pack("<%dH" % len(vals), *[max(0, min(65535, int(round((float(v) - 100.0) * 100.0)))) for v in vals])
    d["lava_dem"] = {"x0": round(x0, 2), "z0": round(z0, 2), "step": 4.0, "nx": nx, "nz": nz, "base": 100.0,
                     "cm": base64.b64encode(cm).decode("ascii"),
                     "source": "MML korkeusmalli 2 m (CC BY 4.0), tools/vaala_lava.py --cache"}
    with open(SRC, "w") as f:
        json.dump(d, f, ensure_ascii=False, separators=(",", ":"))
    print("korkeusmalli lavan ympäriltä reitti.json:iin (%d x %d)" % (nx, nz))


class Dem:
    def __init__(self, ld, off):
        self.x0, self.z0, self.step, self.nx, self.nz = ld["x0"] + off[0], ld["z0"] + off[1], ld["step"], ld["nx"], ld["nz"]
        raw = base64.b64decode(ld["cm"])
        self.v = [ld["base"] + c / 100.0 for c in struct.unpack("<%dH" % (self.nx * self.nz), raw)]

    def at(self, x, z):
        fx = min(max((x - self.x0) / self.step, 0.0), self.nx - 1.001)
        fz = min(max((z - self.z0) / self.step, 0.0), self.nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        q = j * self.nx + i
        return lerp(lerp(self.v[q], self.v[q + 1], u), lerp(self.v[q + self.nx], self.v[q + self.nx + 1], u), v)


# --- Ajo -----------------------------------------------------------------------------------------------------

def apply(cache=None):
    d = json.load(open(SRC))
    tie = json.load(open(TIE))
    global AREA
    off = tie.get("lava_off", tie["town_off"])
    AREA = area(off)
    wl = tie["water_level"]
    if "lava_dem" not in d:
        if not cache:
            sys.exit("reitti.json:ssa ei ole lavan korkeusmallia: aja kerran --cache <välimuisti>")
        fetch_dem(d, off, cache)
    dem = Dem(d["lava_dem"], off)
    g = lambda p: (p[0] + off[0], p[1] + off[1])  # noqa: E731

    # --- Maasto sisään (vaala_bake.py on juuri kirjoittanut sen; niemi on jo 1:1 samalla kuvauksella). ----------
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    far_raw = raw[o:]
    ai0, aj0 = int(round((AREA[0] - x0) / cell)), int(round((AREA[1] - z0) / cell))
    ai1, aj1 = int(round((AREA[2] - x0) / cell)), int(round((AREA[3] - z0) / cell))

    # --- Lava, Pahalahdentie (asfaltti lavalle asti) ja aita. ------------------------------------------------
    real = g(to_xz(*LAVA))
    hw, hl = LAVA_SIZE[0] / 2.0, LAVA_SIZE[1] / 2.0

    def game_wet(p):
        i, j = int(round((p[0] - x0) / cell)), int(round((p[1] - z0) / cell))
        return 0 <= i < nx and 0 <= j < nz and codes[j * nx + i] == WATER

    # Lava rantaan: lähin paikka todellisesta, jossa lava on kuivalla ja seinästä veteen SHORE_GAP (pelin vesiruudut).
    wet_pts = []
    for j in range(int((real[1] - 260 - z0) / cell), int((real[1] + 260 - z0) / cell)):
        for i in range(int((real[0] - 260 - x0) / cell), int((real[0] + 260 - x0) / cell)):
            if 0 <= i < nx and 0 <= j < nz and codes[j * nx + i] == WATER:
                wet_pts.append((x0 + i * cell, z0 + j * cell))
    buckets = {}
    for q in wet_pts:
        buckets.setdefault((int(q[0] // 40), int(q[1] // 40)), []).append(q)
    best = None
    for dz in range(-200, 201, 4):
        for dx in range(-200, 201, 4):
            cc = (real[0] + dx, real[1] + dz)
            gap = 1e9
            bi, bj = int(cc[0] // 40), int(cc[1] // 40)
            for di in (-1, 0, 1):
                for dj in (-1, 0, 1):
                    for q in buckets.get((bi + di, bj + dj), ()):
                        ex = max(abs(q[0] - cc[0]) - hw, 0.0)
                        ez = max(abs(q[1] - cc[1]) - hl, 0.0)
                        gap = min(gap, math.hypot(ex, ez) - cell / 2.0)
            if not (SHORE_GAP[0] <= gap <= SHORE_GAP[1]):
                continue
            score = math.hypot(dx, dz)
            if best is None or score < best[0]:
                best = (score, cc, gap)
    if best is None:
        sys.exit("lavalle ei löytynyt rantapaikkaa")
    c = best[1]
    print("lava rannassa: %.1f m vedestä, %.0f m todellisesta paikasta" % (best[2], best[0]))
    parts = [[tuple(q) for q in f["pts"]] for f in d["features"] if f["kind"] == "road" and f.get("name") == ROAD_NAME]
    road = []
    while parts:
        if not road:
            road = parts.pop(0)
            continue
        for i, p in enumerate(parts):
            if math.dist(p[0], road[-1]) < 1.0:
                road += p[1:]
            elif math.dist(p[-1], road[-1]) < 1.0:
                road += p[::-1][1:]
            elif math.dist(p[-1], road[0]) < 1.0:
                road = p + road[1:]
            elif math.dist(p[0], road[0]) < 1.0:
                road = p[::-1] + road[1:]
            else:
                continue
            parts.pop(i)
            break
        else:
            break
    road = resample([g(p) for p in road], 2.0)
    if math.dist(road[0], real) < math.dist(road[-1], real):
        road.reverse()  # risteyksestä niemen kärkeen
    # Ovi tien puoleiselle pitkälle sivulle; tie loppuu ajotien liittymään (niemen kärkeen ei enää ajeta).
    side = 1.0 if min(road, key=lambda p: math.dist(p, c))[0] >= c[0] else -1.0
    if game_wet((c[0] + side * (hw + 4.0), c[1])):
        side = -side  # ovi ei rannan puolelle
    door = (c[0] + side * (hw + 4.0), c[1])
    road = road[:min(range(len(road)), key=lambda k: math.dist(road[k], door)) + 1]
    drive = [road[-1], door]
    tie["side_roads"] = [r for r in tie["side_roads"] if r.get("name") != ROAD_NAME]
    tie["side_roads"].append({"kind": "road", "hw": "unclassified", "name": ROAD_NAME, "surface": "asphalt",
                              "pts": [[round(x, 2), round(z, 2)] for x, z in road[:-1:2] + [road[-1]]]})
    plot_lo = (c[0] - hw - 10.0 + (0.0 if side > 0 else -14.0), c[1] - hl - 10.0)
    plot_hi = (c[0] + hw + 10.0 + (14.0 if side > 0 else 0.0), c[1] + hl + 10.0)

    def in_plot(p, grow=0.0):
        return plot_lo[0] - grow <= p[0] <= plot_hi[0] + grow and plot_lo[1] - grow <= p[1] <= plot_hi[1] + grow

    def wet(p):
        return dem.at(*p) < wl + 0.05

    # Aita: pohjoisessa joelta länteen Pahalahdentien yli (portti), kulmasta etelään Pahalahteen. Päät veteen.
    corner = (c[0] - hw - FENCE_GAP[1], c[1] - hl - FENCE_GAP[0])

    def to_water(p, dx, dz):
        t = 0.0
        while not game_wet((p[0] + dx * t, p[1] + dz * t)):
            t += 1.0
            if t > 600.0:
                sys.exit("aidan linja ei osu veteen")
        t += FENCE_INTO_WATER
        return (p[0] + dx * t, p[1] + dz * t)

    fence = [to_water(corner, 1.0, 0.0), corner, to_water(corner, 0.0, 1.0)]
    gate = None
    for a, b in zip(road, road[1:]):
        if (a[1] - corner[1]) * (b[1] - corner[1]) <= 0.0 and a[1] != b[1]:
            t = (corner[1] - a[1]) / (b[1] - a[1])
            gate = (lerp(a[0], b[0], t), corner[1])
    tie["lava"] = {"x": round(c[0], 2), "z": round(c[1], 2), "w": LAVA_SIZE[0], "l": LAVA_SIZE[1], "door_side": side,
                   "road": [[round(x, 2), round(z, 2)] for x, z in drive], "lat": LAVA[0], "lon": LAVA[1],
                   "fence": [[round(x, 2), round(z, 2)] for x, z in fence],
                   "gate": [round(gate[0], 2), round(gate[1], 2)] if gate else None, "gate_w": GATE_W}
    tie["buildings"] = [b for b in tie["buildings"] if not any(in_plot(q, 2.0) for q in b["pts"])]
    # Muut tiet ja polut aidan sisällä (lava on siirretty niiden päälle) pois: tie loppuu aidan taakse.
    near_fence = lambda p: p[0] > corner[0] - 4.0 and p[1] > corner[1] - 4.0  # noqa: E731
    cut_roads = []
    for r in tie["side_roads"]:
        if r.get("name") == ROAD_NAME or r["kind"] != "road":
            cut_roads.append(r)
            continue
        cur = []
        for q in r["pts"]:
            if near_fence(q):
                if len(cur) > 1:
                    cut_roads.append(dict(r, pts=cur))
                cur = []
            else:
                cur.append(q)
        if len(cur) > 1:
            cut_roads.append(dict(r, pts=cur))
    tie["side_roads"] = cut_roads
    lane = road + [door]
    # Tien pinta: korkeusmalli tien linjalla pehmennettynä (±10 m); maasto tasoitetaan sen alle, jottei tie jää
    # kumpareiden alle.
    lane_pts = resample(lane, 2.0)
    lane_raw = [dem.at(*q) for q in lane_pts]
    lane_h = [max(sum(lane_raw[max(0, k - 5):k + 6]) / len(lane_raw[max(0, k - 5):k + 6]), wl + 0.3) for k in range(len(lane_raw))]

    def lane_at(p):
        k = min(range(len(lane_pts)), key=lambda q: (lane_pts[q][0] - p[0]) ** 2 + (lane_pts[q][1] - p[1]) ** 2)
        return math.dist(p, lane_pts[k]), lane_h[k]

    def inside_fence(p):
        return p[0] > corner[0] and p[1] > corner[1]

    def cell_wet(x, z):
        return wet((x0 + round((x - x0) / cell) * cell, z0 + round((z - z0) / cell) * cell))

    def drop(x, z):
        # Puu pois: vedessä tai rantaviivalla, tontilla, tiellä tai aidan linjalla.
        return cell_wet(x, z) or dem.at(x, z) < wl + 0.15 or in_plot((x, z), 4.0) or line_dist((x, z), lane) < 5.5 \
            or line_dist((x, z), fence) < 2.5

    # --- Tontti, ajotie ja aidan sisäpuoli nurmeksi, Pahalahdentien alle tasainen pohja. -------------------------
    changed = set()
    for j in range(max(aj0, 0), min(aj1, nz - 1) + 1):
        for i in range(max(ai0, 0), min(ai1, nx - 1) + 1):
            k = j * nx + i
            p = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (ROAD, SHOULDER, RAIL, WATER) or wet(p):
                continue
            h = heights[k]
            code = codes[k]
            meadow = ((p[0] - c[0]) / (hw + 36.0)) ** 2 + ((p[1] - c[1]) / (hl + 32.0)) ** 2 < 1.0
            if line_dist(p, lane) < 6.0 or (inside_fence(p) and meadow):
                code = YARD  # tontti, ajotie ja lavan ympäristö aidan sisällä nurmella
            ld = line_dist(p, lane)
            if ld < 11.0:
                _ld, lh = lane_at(p)
                h = lerp(lh - 0.05, max(h, wl + 0.1), smooth(6.5, 11.0, ld))
            if code != codes[k] or abs(h - heights[k]) > 0.01:
                codes[k] = code
                heights[k] = round(h, 3)
                changed.add((i, j))
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(far_raw)

    # Maan korkeus kuten vaala.gd:n h(): tarkka ruudukko kolmioittain.
    def ground(x, z):
        fx = min(max((x - x0) / cell, 0.0), nx - 1.001)
        fz = min(max((z - z0) / cell, 0.0), nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        q = j * nx + i
        if u + v <= 1.0:
            return heights[q] + (heights[q + 1] - heights[q]) * u + (heights[q + nx] - heights[q]) * v
        return heights[q + nx + 1] + (heights[q + nx] - heights[q + nx + 1]) * (1.0 - u) \
            + (heights[q + 1] - heights[q + nx + 1]) * (1.0 - v)

    # --- Puut pois tontilta, tieltä, aidan linjalta ja vedestä; tasoitetulla maalla uudelle korkeudelle. ----------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    removed = moved = 0
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0 or not in_box((x, z), AREA, 8.0):
            continue
        if drop(x, z):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif (int(round((x - x0) / cell)), int(round((z - z0) / cell))) in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("Oulujärven lava", {k: v for k, v in tie["lava"].items() if k != "fence"},
          "| aita %.0f m" % sum(math.dist(a, b) for a, b in zip(fence, fence[1:])),
          "| Pahalahdentie %.0f m" % sum(math.dist(a, b) for a, b in zip(road, road[1:])),
          "| muutettuja ruutuja %d" % len(changed), "| puita pois %d, korkeus uuteen maahan %d" % (removed, moved))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cache", help="MML:n aineiston välimuisti (vain, jos reitti.json:ssa ei ole vielä lava_dem)")
    apply(ap.parse_args().cache)
