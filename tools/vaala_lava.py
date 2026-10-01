#!/usr/bin/env python3
"""Oulujärven lava oikealle paikalleen Vaalan mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_lava.py   (vaala_bake.py ajaa tämän lopuksi; ei tarvitse verkkoa eikä välimuistia)

Lava oli Oulujoen etelärannalla Pahalahdentien päässä (64.550921 N, 26.822649 E), n. 330 m Vuolijoentieltä.
Pahalahdentien risteys on mopomatkan 1:1-alueella (radan alikulun edellä), joten lava ja koko Pahalahdentie
siirtyvät peliin keskustan siirrolla (town_off) oikeille paikoilleen. Lava on tarkan maaston ulkopuolella,
joten sen tontti, parkkipaikka ja tien varsi merkitään maastoon (nurmea kaukomaaston korkeudella), kaukomaasto
painetaan niiden alle (ei päällekkäisiä pintoja) ja puut poistetaan tontilta ja tieltä. Ajo on toistettavissa.
"""
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "vaala", "reitti.json")
TIE = os.path.join(ROOT, "assets", "vaala", "tie.json")
MAASTO = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
PUUT = os.path.join(ROOT, "assets", "vaala", "puut.bin")

LAT0, LON0 = 64.5054523, 26.6672225  # Kaisuantie 62 (vaala_reitti.py)
M_PER_DEG = 111320.0
LAVA = (64.550921, 26.822649)
LAVA_SIZE = (34.0, 44.0)  # 1 500 m², pitkä sivu z-suunnassa (vaala.gd _build_lava)
ROAD_NAME = "Pahalahdentie"
YARD, OUTSIDE = 4, 255


def to_xz(lat, lon):
    return ((lon - LON0) * math.cos(math.radians(LAT0)) * M_PER_DEG, -(lat - LAT0) * M_PER_DEG)


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


def apply():
    d = json.load(open(SRC))
    tie = json.load(open(TIE))
    off = tie["town_off"]
    g = lambda p: (p[0] + off[0], p[1] + off[1])  # noqa: E731

    c = g(to_xz(*LAVA))
    # Pahalahdentie kokonaan (OSM-palat yhteen risteyksestä alkaen) ja lavan ajotie tien päästä ovelle.
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
    road = [g(p) for p in road]
    if math.dist(road[0], c) < math.dist(road[-1], c):
        road.reverse()  # risteyksestä lavalle
    end = road[-1]
    side = 1.0 if end[0] >= c[0] else -1.0
    door = (c[0] + side * (LAVA_SIZE[0] / 2.0 + 4.0), c[1])
    drive = [end, door]
    tie["side_roads"] = [r for r in tie["side_roads"] if r.get("name") != ROAD_NAME]
    tie["side_roads"].append({"kind": "road", "hw": "unclassified", "name": ROAD_NAME, "surface": "unpaved",
                              "pts": [[round(x, 2), round(z, 2)] for x, z in resample(road, 6.0)]})
    tie["lava"] = {"x": round(c[0], 2), "z": round(c[1], 2), "w": LAVA_SIZE[0], "l": LAVA_SIZE[1], "door_side": side,
                   "road": [[round(x, 2), round(z, 2)] for x, z in drive], "lat": LAVA[0], "lon": LAVA[1]}
    hw, hl = LAVA_SIZE[0] / 2.0, LAVA_SIZE[1] / 2.0
    # Tontti: lava, portaat, parkkipaikka oven puolella ja pihaa ympärillä.
    plot_lo = (c[0] - hw - 10.0 + (0.0 if side > 0 else -14.0), c[1] - hl - 10.0)
    plot_hi = (c[0] + hw + 10.0 + (14.0 if side > 0 else 0.0), c[1] + hl + 10.0)

    def in_plot(p, grow=0.0):
        return plot_lo[0] - grow <= p[0] <= plot_hi[0] + grow and plot_lo[1] - grow <= p[1] <= plot_hi[1] + grow

    # Päällekkäiset rakennukset tontilta pois (OSM:n lavan pohja tms.).
    tie["buildings"] = [b for b in tie["buildings"] if not any(in_plot(q, 2.0) for q in b["pts"])]
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))

    # --- Maasto: tontti ja tien varsi nurmeksi, kaukomaasto niiden alle. --------------------------------
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    fnx, fnz, fx0, fz0, fcell = struct.unpack_from("<iifff", raw, o)
    o += 20
    far = list(struct.unpack_from("<%df" % (fnx * fnz), raw, o))
    lane = road + [door]
    lo = (min(min(p[0] for p in lane), plot_lo[0]) - 12.0, min(min(p[1] for p in lane), plot_lo[1]) - 12.0)
    hi = (max(max(p[0] for p in lane), plot_hi[0]) + 12.0, max(max(p[1] for p in lane), plot_hi[1]) + 12.0)
    marked = 0
    for j in range(max(int((lo[1] - z0) / cell), 0), min(int((hi[1] - z0) / cell) + 2, nz)):
        for i in range(max(int((lo[0] - x0) / cell), 0), min(int((hi[0] - x0) / cell) + 2, nx)):
            k = j * nx + i
            if codes[k] != OUTSIDE:
                continue
            p = (x0 + i * cell, z0 + j * cell)
            if in_plot(p):
                codes[k] = YARD
            elif line_dist(p, lane) < 9.0:
                codes[k] = YARD
            else:
                continue
            marked += 1
    for j in range(fnz):
        for i in range(fnx):
            x, z = fx0 + i * fcell, fz0 + j * fcell
            ci, cj = int((x - x0) / cell), int((z - z0) / cell)
            if lo[0] - 40 <= x <= hi[0] + 40 and lo[1] - 40 <= z <= hi[1] + 40 and 0 <= ci < nx and 0 <= cj < nz \
                    and codes[cj * nx + ci] != OUTSIDE:
                far[j * fnx + i] = round(heights[cj * nx + ci] - 1.5, 2)
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(struct.pack("<iifff", fnx, fnz, fx0, fz0, fcell))
        f.write(struct.pack("<%df" % (fnx * fnz), *far))

    # --- Puut: tontilta ja tieltä pois (pituus 0 = ei piirretä eikä törmätä, ks. forest.gd). --------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, W, H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    removed = 0
    for n in range(count):
        q = t0 + n * 16
        x, _y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0 or not (lo[0] <= x <= hi[0] and lo[1] <= z <= hi[1]):
            continue
        if in_plot((x, z), 4.0) or line_dist((x, z), lane) < 5.5:
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("Oulujärven lava", tie["lava"], "| Pahalahdentie %.0f m" % sum(math.dist(a, b) for a, b in zip(road, road[1:])),
          "| maastoruutuja", marked, "| puita pois", removed)


if __name__ == "__main__":
    apply()
