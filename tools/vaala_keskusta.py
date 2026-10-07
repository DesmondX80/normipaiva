#!/usr/bin/env python3
"""Vaalan keskustan siistintä mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_keskusta.py   (vaala_bake.py ajaa tämän lopuksi lavan jälkeen)

- K-Market Tervaportti siirretään oikealta paikaltaan (Vaalantie 26, n. 400 m Siitarista) Vaalantien varteen
  Siitarin lounaispuolelle, jotta kauppa ja sen seinän pankkiautomaatti ovat Siitarin vieressä. Uusi pohja on
  suorakaide pitkä sivu tielle päin (ovi ja kyltti tien puolella, vaala.gd), eteen parkkipaikka. Tontin ja
  parkkipaikan maasto pihaksi ja tasaiseksi, reunat liitetään ympäristöön pehmeästi.
- Puut pois rakennusten sisältä ja vierestä, parkkipaikoilta ja ajoradoilta: laserkeilauksen latvusmallin
  maksimeista tunnistuu "puiksi" myös kattoja, jotka kasvoivat pelissä seinien ja kattojen läpi. Siitarin ympäriltä
  raivataan piha, ettei ovi avaudu suoraan metsään.
Ajo on toistettavissa: K-Marketin alkuperäinen pohja ja muutettujen maastoruutujen alkuarvot ovat tie.json:ssa
("keskusta"), ja ne palautetaan ennen uutta ajoa.
"""
import json
import math
import os
import struct

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIE = os.path.join(ROOT, "assets", "vaala", "tie.json")
MAASTO = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
PUUT = os.path.join(ROOT, "assets", "vaala", "puut.bin")

FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
OUTSIDE = 255
KMARKET_ID = 225699583
SIITARI_ID = 225699578
SIITARI_YARD = 10.0  # Siitarin ympäriltä puut pois (ovi ja terassi eivät avaudu metsään)
KM_FROM_END = 68     # Vaalantien näyte (tien lopusta laskien), jonka kohdalle kauppa tulee (Siitarista n. 45 m lounaaseen)
KM_SIZE = (27.0, 18.0)  # julkisivu tielle x syvyys
KM_SETBACK = 28.0    # tien keskiviivasta rakennuksen keskelle (edessä parkkipaikka)
PARK_DEPTH = 12.0
BUILD_MARGIN = 2.0   # puut näin kauas seinistä
PARK_MARGIN = 1.0
ROAD_MARGIN = 1.5    # tien reunasta


def in_poly(p, poly):
    x, z = p
    inside = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            inside = not inside
        j = i
    return inside


def seg_dist(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    L = ax * ax + az * az
    t = 0.0 if L == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / L))
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - az * t)


def poly_dist(p, poly):
    """0 sisällä, muuten etäisyys reunasta."""
    if in_poly(p, poly):
        return 0.0
    return min(seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def bbox(poly, grow):
    xs = [q[0] for q in poly]
    zs = [q[1] for q in poly]
    return (min(xs) - grow, min(zs) - grow, max(xs) + grow, max(zs) + grow)


def rect(c, ax, az, hx, hz):
    return [[round(c[0] + ax[0] * sx * hx + az[0] * sz * hz, 2), round(c[1] + ax[1] * sx * hx + az[1] * sz * hz, 2)]
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def apply():
    tie = json.load(open(TIE))
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    rest = raw[o:]

    # --- Edellinen ajo pois. ---------------------------------------------------------------------------------
    prev = tie.pop("keskusta", None)
    if prev:
        for k, hv, cv in prev["cells"]:
            heights[k] = hv
            codes[k] = cv
        tie["parkings"] = [p for p in tie["parkings"] if p != prev["parking"]]
        for k, pts in prev["side_roads"]:
            tie["side_roads"][k]["pts"] = pts
        for b in tie["buildings"]:
            if b["id"] == KMARKET_ID:
                b["pts"] = prev["kmarket_pts"]

    km = next(b for b in tie["buildings"] if b["id"] == KMARKET_ID)
    orig_pts = km["pts"]

    # --- K-Market Siitarin viereen. --------------------------------------------------------------------------
    road = tie["road"]
    ki = len(road) - KM_FROM_END
    a, b = road[ki - 4], road[ki + 4]
    d = (b[0] - a[0], b[2] - a[2])
    L = math.hypot(*d)
    ax = (d[0] / L, d[1] / L)  # tien suunta
    az = (-ax[1], ax[0])       # poispäin tiestä (Siitarin puolelle)
    sx, sz = tie["siitari"]
    rp = (road[ki][0], road[ki][2])
    if (sx - rp[0]) * az[0] + (sz - rp[1]) * az[1] < 0.0:
        az = (-az[0], -az[1])
    c = (rp[0] + az[0] * KM_SETBACK, rp[1] + az[1] * KM_SETBACK)
    km["pts"] = rect(c, ax, az, KM_SIZE[0] / 2.0, KM_SIZE[1] / 2.0)
    pc = (c[0] - az[0] * (KM_SIZE[1] / 2.0 + PARK_DEPTH / 2.0), c[1] - az[1] * (KM_SIZE[1] / 2.0 + PARK_DEPTH / 2.0))
    parking = rect(pc, ax, az, KM_SIZE[0] / 2.0 + 4.0, PARK_DEPTH / 2.0)
    tie["parkings"].append(parking)

    # Tontti (rakennus + parkki) tasaiseksi, pehmeä liitos 8 m:llä; ruudut pihaksi. Ei saa osua muihin.
    lot = rect(((c[0] + pc[0]) / 2.0, (c[1] + pc[1]) / 2.0), ax, az, KM_SIZE[0] / 2.0 + 4.0,
               (KM_SIZE[1] + PARK_DEPTH) / 2.0)
    for other in tie["buildings"]:
        if other is not km and (min(poly_dist(q, lot) for q in other["pts"]) < 2.0
                                or any(in_poly(q, other["pts"]) for q in lot)):
            raise SystemExit("K-Marketin uusi paikka osuu rakennukseen %s %s" % (other["id"], other["name"]))
    # Rakennuksen läpi kulkevat sivutiet kiertämään lähemmän päädyn kautta (parkin poikki saa ajaa).
    moved_roads = []
    house = rect(c, ax, az, KM_SIZE[0] / 2.0 + 3.0, KM_SIZE[1] / 2.0 + 3.0)
    for k, sr in enumerate(tie["side_roads"]):
        dense = []
        for a, b in zip(sr["pts"], sr["pts"][1:]):
            n = max(1, int(math.dist(a[:2], b[:2]) / 2.0))
            dense += [[a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n] for t in range(n)]
        dense.append(sr["pts"][-1][:2])
        if not any(in_poly(q, house) for q in dense):
            continue
        moved_roads.append([k, sr["pts"]])
        out = []
        for q in dense:
            if in_poly(q, house):
                u = (q[0] - c[0]) * ax[0] + (q[1] - c[1]) * ax[1]
                v = (q[0] - c[0]) * az[0] + (q[1] - c[1]) * az[1]
                u = math.copysign(KM_SIZE[0] / 2.0 + 3.0, u)
                q = [c[0] + ax[0] * u + az[0] * v, c[1] + ax[1] * u + az[1] * v]
            out.append([round(q[0], 2), round(q[1], 2)])
        sr["pts"] = out
        print("sivutie kiertämään kaupan päädyn:", sr["hw"], sr.get("name", ""))
    fx0, fz0, fx1, fz1 = bbox(lot, 12.0)
    inner = []
    for j in range(nz):
        for i in range(nx):
            x, z = x0 + i * cell, z0 + j * cell
            if fx0 <= x <= fx1 and fz0 <= z <= fz1 and codes[j * nx + i] != OUTSIDE and poly_dist((x, z), lot) < 0.01:
                inner.append(heights[j * nx + i])
    flat = sum(inner) / len(inner)
    cells = []
    for j in range(nz):
        for i in range(nx):
            x, z = x0 + i * cell, z0 + j * cell
            k = j * nx + i
            if not (fx0 <= x <= fx1 and fz0 <= z <= fz1) or codes[k] in (OUTSIDE, ROAD, RAIL, WATER):
                continue
            dd = poly_dist((x, z), lot)
            if dd > 8.0:
                continue
            cells.append([k, heights[k], codes[k]])
            t = max(0.0, (dd - 3.0) / 5.0)
            t = t * t * (3.0 - 2.0 * t)
            heights[k] = round(flat + (heights[k] - flat) * t, 3)
            if dd < 6.0 and codes[k] != SHOULDER:
                codes[k] = YARD
    tie["keskusta"] = {"kmarket_pts": orig_pts, "parking": parking, "cells": cells, "side_roads": moved_roads}

    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(rest)

    def ground(x, z):
        fx, fz = (x - x0) / cell, (z - z0) / cell
        i, j = min(max(int(fx), 0), nx - 2), min(max(int(fz), 0), nz - 2)
        u, v = min(max(fx - i, 0.0), 1.0), min(max(fz - j, 0.0), 1.0)
        q = j * nx + i
        if u + v <= 1.0:
            return heights[q] + (heights[q + 1] - heights[q]) * u + (heights[q + nx] - heights[q]) * v
        return heights[q + nx + 1] + (heights[q + nx] - heights[q + nx + 1]) * (1.0 - u) \
            + (heights[q + 1] - heights[q + nx + 1]) * (1.0 - v)

    def code_at(x, z):
        i, j = int(round((x - x0) / cell)), int(round((z - z0) / cell))
        return codes[j * nx + i] if 0 <= i < nx and 0 <= j < nz else OUTSIDE

    # --- Puut pois rakennuksista, parkeista ja teiltä. ---------------------------------------------------------
    G = 32.0
    grid = {}

    def add(kind, poly, grow):
        bx = bbox(poly, grow)
        for gi in range(int(math.floor(bx[0] / G)), int(math.floor(bx[2] / G)) + 1):
            for gj in range(int(math.floor(bx[1] / G)), int(math.floor(bx[3] / G)) + 1):
                grid.setdefault((gi, gj), []).append((kind, poly, grow))
    for bd in tie["buildings"]:
        add("poly", bd["pts"], SIITARI_YARD if bd["id"] == SIITARI_ID else BUILD_MARGIN)
    for p in tie["parkings"]:
        add("poly", p, PARK_MARGIN)
    for k in range(len(road) - 1):
        r0, r1 = road[k], road[k + 1]
        add("line", [(r0[0], r0[2]), (r1[0], r1[2])], r0[4] + ROAD_MARGIN)
    for sr in tie["side_roads"]:
        hw = 3.0 if sr["hw"] in ("secondary", "tertiary", "residential", "unclassified", "service") else 1.2
        for k in range(len(sr["pts"]) - 1):
            add("line", [tuple(sr["pts"][k][:2]), tuple(sr["pts"][k + 1][:2])], hw + 0.5)

    def blocked(x, z):
        if code_at(x, z) in (ROAD, RAIL):
            return True
        for kind, poly, grow in grid.get((int(math.floor(x / G)), int(math.floor(z / G))), ()):
            if kind == "poly":
                bx = bbox(poly, grow)
                if bx[0] <= x <= bx[2] and bx[1] <= z <= bx[3] and poly_dist((x, z), poly) < grow:
                    return True
            elif seg_dist((x, z), poly[0], poly[1]) < grow:
                return True
        return False

    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, pnfx, pnfz, pnnx, pnnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (pnfx * pnfz + pnnx * pnnz) * 5 * 8
    removed = moved = 0
    lx0, lz0, lx1, lz1 = bbox(lot, 10.0)
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0:
            continue
        if blocked(x, z):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif lx0 <= x <= lx1 and lz0 <= z <= lz1 and abs(ground(x, z) - y) > 0.01:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("K-Market Tervaportti", [round(v, 1) for v in c], "Siitarista %.0f m" % math.dist(c, (sx, sz)),
          "| tontti %.1f m, %d ruutua" % (flat, len(cells)), "| puita pois %d (yht. %d), korkeus uuteen maahan %d" % (
              removed, count, moved))


if __name__ == "__main__":
    apply()
