#!/usr/bin/env python3
"""Oulujoen silta suoraksi ja Oulujärvi luoteiskulmaan Vaalan mopomatkan dataan (assets/vaala/tie.json, maasto.bin,
puut.bin).

Ajo: python3 tools/vaala_silta_jarvi.py   (vaala_bake.py ajaa tämän lopuksi lavan jälkeen)

- Oulujoen silta: tiivistyskaistan saumassa sillan keskellä tie taittui (suunta muuttui ~11°) ja sillan alku painui
  länsirannan rinteen mukana 3,7 m alemmas kuin tie ennen sitä. Silta tehdään suoraksi päästä päähän (päät pysyvät
  paikallaan, siirtymä tiehen pehmeästi SMOOTH näytteen matkalla) ja sen korkeus suoraksi viivaksi tasaisen tien
  kohdalta toiselle (RAMP näytettä sillan molemmin puolin). Rannoilla maa nostetaan pengerreksi tien alle, ja
  sillan alla vanhan tien jälki joessa vedeksi.
- Oulujärvi: kaukomaaston luoteiskulmassa järvi jäi matalikkojen kohdalta kuivaksi (vesi piirretään vain, jos pohja
  on 1,9 m vedenpinnan alla), joten LAKE-monikulmion alue painetaan järven pohjaksi ja puut otetaan pois.
Ajo on toistettavissa: muutettujen näytteiden ja ruutujen alkuarvot ovat tie.json:ssa ("silta_jarvi").
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
SMOOTH = 8      # näytettä sillan päistä tiehen: siirtymä suoralta sillalta alkuperäiseen tiehen
RAMP = 8        # näytettä sillan päistä: korkeus suoraksi näiden välillä
BANK = 1.5      # penger: tasainen ajoradan reunasta, sitten luiska 1:1,5
# Oulujärvi kaukomaastossa (pelin x, z): luoteiskulma kaukomaaston reunojen yli, itäranta ja etelärannan linja
# tarkan alueen reunaan, jossa järvi jatkuu tarkassa maastossa.
LAKE = [(-1400.0, -2700.0), (80.0, -2700.0), (80.0, -2256.0), (212.0, -1756.0), (-468.0, -1756.0),
        (-468.0, -1576.0), (-708.0, -1516.0), (-1168.0, -1368.0), (-1400.0, -1300.0)]
LAKE_DEPTH = 4.0  # pohja näin syvälle vedenpinnan alle


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


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
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - az * t), t


def apply():
    tie = json.load(open(TIE))
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    fnx, fnz, fx0, fz0, fcell = struct.unpack_from("<iifff", raw, o)
    far = list(struct.unpack_from("<%df" % (fnx * fnz), raw, o + 20))
    tail = raw[o + 20 + fnx * fnz * 4:]
    road = tie["road"]
    wl = tie["water_level"]

    # --- Edellinen ajo pois. ---------------------------------------------------------------------------------
    prev = tie.pop("silta_jarvi", None)
    if prev:
        for i, smp in prev["road"]:
            road[i] = smp
        for k, hv, cv in reversed(prev["cells"]):
            heights[k] = hv
            codes[k] = cv
        for k, hv in reversed(prev["far"]):
            far[k] = hv
    saved_road = []
    cells = []
    far_cells = []

    # --- Silta suoraksi. -------------------------------------------------------------------------------------
    i0, i1 = tie["bridges"][-1]
    for i in range(i0 - max(SMOOTH, RAMP), i1 + max(SMOOTH, RAMP) + 1):
        saved_road.append([i, list(road[i])])
    A = (road[i0][0], road[i0][2])
    B = (road[i1][0], road[i1][2])
    step = ((B[0] - A[0]) / (i1 - i0), (B[1] - A[1]) / (i1 - i0))
    line = lambda i: (A[0] + step[0] * (i - i0), A[1] + step[1] * (i - i0))  # noqa: E731
    old_xz = {i: (road[i][0], road[i][2]) for i in range(i0 - SMOOTH, i1 + SMOOTH + 1)}
    for i in range(i0 - SMOOTH, i1 + SMOOTH + 1):
        if i0 <= i <= i1:
            w = 1.0
        elif i < i0:
            w = smooth(i0 - SMOOTH, i0, i)
        else:
            w = 1.0 - smooth(i1, i1 + SMOOTH, i)
        q = line(i)
        road[i][0] = round(old_xz[i][0] + (q[0] - old_xz[i][0]) * w, 2)
        road[i][2] = round(old_xz[i][1] + (q[1] - old_xz[i][1]) * w, 2)
    ia, ib = i0 - RAMP, i1 + RAMP
    ya, yb = road[ia][1], road[ib][1]
    for i in range(ia, ib + 1):
        road[i][1] = round(ya + (yb - ya) * (i - ia) / (ib - ia), 2)
    dev = max(math.dist(old_xz[i], (road[i][0], road[i][2])) for i in old_xz)

    # Penger rannoille (vain nostetaan maata, ei vettä eikä rataa) ja vanhan tien jälki sillan alla vedeksi.
    hw = road[i0][4]
    span = list(range(ia, ib))
    bx0 = min(road[i][0] for i in span) - 30.0
    bx1 = max(road[i][0] for i in span) + 30.0
    bz0 = min(road[i][2] for i in span) - 30.0
    bz1 = max(road[i][2] for i in span) + 30.0
    raised = 0
    wetted = 0
    for j in range(max(0, int((bz0 - z0) / cell)), min(nz, int((bz1 - z0) / cell) + 1)):
        for i in range(max(0, int((bx0 - x0) / cell)), min(nx, int((bx1 - x0) / cell) + 1)):
            k = j * nx + i
            p = (x0 + i * cell, z0 + j * cell)
            best = (1e9, 0.0, 0)
            for s in span:
                d, t = seg_dist(p, (road[s][0], road[s][2]), (road[s + 1][0], road[s + 1][2]))
                if d < best[0]:
                    best = (d, road[s][1] + (road[s + 1][1] - road[s][1]) * t, s)
            d, ry, s = best
            if codes[k] in (OUTSIDE, RAIL):
                continue
            if codes[k] == WATER or heights[k] < wl + 0.2:
                # Joki: vanhan tien jälki (tie- ja piennarruudut uoman pohjassa) vedeksi.
                if codes[k] in (ROAD, SHOULDER) and heights[k] < wl - 0.5:
                    cells.append([k, heights[k], codes[k]])
                    heights[k] = round(wl - 1.2, 3)
                    codes[k] = WATER
                    wetted += 1
                continue
            if i0 + 2 <= s < i1 - 2:
                continue  # sillan keskiosan alla oleva maa (saaret, rantapenger) jää ennalleen
            target = ry - 0.08 - max(0.0, d - hw - BANK) / 1.5
            if target > heights[k] + 0.01:
                cells.append([k, heights[k], codes[k]])
                heights[k] = round(target, 3)
                if d < hw + BANK and codes[k] not in (ROAD, SHOULDER):
                    codes[k] = SHOULDER
                raised += 1

    # --- Oulujärvi luoteiskulmaan kaukomaastossa. ----------------------------------------------------------------
    lake_far = 0
    for j in range(fnz):
        for i in range(fnx):
            p = (fx0 + i * fcell, fz0 + j * fcell)
            k = j * fnx + i
            if in_poly(p, LAKE) and far[k] > wl - LAKE_DEPTH:
                far_cells.append([k, far[k]])
                far[k] = round(wl - LAKE_DEPTH, 3)
                lake_far += 1

    tie["silta_jarvi"] = {"road": saved_road, "cells": cells, "far": far_cells}
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(struct.pack("<iifff", fnx, fnz, fx0, fz0, fcell))
        f.write(struct.pack("<%df" % (fnx * fnz), *far))
        f.write(tail)

    # --- Puut pois järvestä ja pengerryksen alta (penkereellä uudelle korkeudelle). -----------------------------
    def ground(x, z):
        fx, fz = (x - x0) / cell, (z - z0) / cell
        i, j = min(max(int(fx), 0), nx - 2), min(max(int(fz), 0), nz - 2)
        u, v = min(max(fx - i, 0.0), 1.0), min(max(fz - j, 0.0), 1.0)
        q = j * nx + i
        if u + v <= 1.0:
            return heights[q] + (heights[q + 1] - heights[q]) * u + (heights[q + nx] - heights[q]) * v
        return heights[q + nx + 1] + (heights[q + nx] - heights[q + nx + 1]) * (1.0 - u) \
            + (heights[q + 1] - heights[q + nx + 1]) * (1.0 - v)

    changed = {k for k, _h, _c in cells}
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, pnfx, pnfz, pnnx, pnnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (pnfx * pnfz + pnnx * pnnz) * 5 * 8
    removed = moved = 0
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0:
            continue
        i, j = int(round((x - x0) / cell)), int(round((z - z0) / cell))
        tarkka = 0 <= i < nx and 0 <= j < nz
        if (not tarkka and in_poly((x, z), LAKE)) or (tarkka and codes[j * nx + i] == WATER):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif tarkka and j * nx + i in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("Oulujoen silta %d-%d suoraksi (siirto enintään %.1f m), korkeus %.2f -> %.2f m (vesi %.2f)" % (
        i0, i1, dev, ya, yb, wl), "| penger %d ruutua, uomaan %d" % (raised, wetted),
        "| järvi kaukomaastoon %d ruutua" % lake_far, "| puita pois %d, korkeus penkereelle %d" % (removed, moved))


if __name__ == "__main__":
    apply()
