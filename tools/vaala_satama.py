#!/usr/bin/env python3
"""Vaalan satama (Venesatama) mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_satama.py   (vaala_bake.py ajaa tämän keskustan siistinnän jälkeen; toistettava)

Oikea Venesatama (OSM relation 2998991, leisure=marina) on Oulujoen suun itärannalla n. 700 m rautatieasemalta
etelään, Sahanrannan uimarannan länsipuolella. Pelissä asema pysyy paikallaan (keskustan 1:1-alue), ja satama haetaan
sen kehyksessä (town_off) lähimpään kohtaan, jossa pelin rantaviiva on (kuiva ruutu, jonka vesi on 2-6 m päässä ja
laiturin suunnassa avovettä). Pelin ranta poikkeaa todellisesta, koska keskustan 1:1-alue ja tiivistetty maasto
liitetään toisiinsa pehmeästi. Tulostus kertoo, kuinka paljon paikka siirtyi ja miltä suunnalta asemalta satama on.

Työkalu tekee:
- tie.json "satama": {x, z (laiturin juuri rannalla), dir (rannalta järvelle), dock_len, park, road, ...}
- soratie (Sahanrannantie) lähimmästä tiestä sataman parkkipaikalle, parkin maasto pihaksi ja tasaiseksi
- puut pois tieltä, parkilta ja laiturin juuresta
Ajo on toistettavissa: aiempi satama-sorapätkä poistetaan ennen uutta ajoa.
"""
import heapq
import json
import math
import os
import struct
import sys

import vaala_lava as VL

ROOT = VL.ROOT
TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)

SATAMA = (64.5511774, 26.8367173)  # Venesatama, OSM relation 2998991 (keskipiste)
ROAD_NAME = "Sahanrannantie"
SEARCH_R = 320.0     # haku todellisen paikan ympäriltä (m)
GAP = (2.0, 6.0)     # rannan ja lähimmän vesiruudun väli (m)
DOCK_LEN = 16.0
OPEN_WATER = 26.0    # laiturin suunnassa vesi näin pitkälle juuresta
FENCE_FAR = 60.0     # lavan aidasta
BUILD_FAR = 25.0     # rakennuksista
PARK_BACK = 9.0      # parkki näin kauas rannalta sisämaahan
PARK_R = (9.0, 6.0)  # parkin ellipsin säteet (pitkin rantaa, rantaan päin)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


def apply():
    tie = json.load(open(TIE))
    off = tie["town_off"]
    wl = tie["water_level"]
    real = VL.to_xz(*SATAMA)
    real_game = (real[0] + off[0], real[1] + off[1])
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    far_raw = raw[o:]

    def ij(p):
        return int(round((p[0] - x0) / cell)), int(round((p[1] - z0) / cell))

    def code(p):
        i, j = ij(p)
        return codes[j * nx + i] if 0 <= i < nx and 0 <= j < nz else 255

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

    # Edellinen ajo pois: satama-sorapätkä.
    tie["side_roads"] = [r for r in tie["side_roads"] if not r.get("_satama")]

    # Iso vesialue (järvi): 4-naapurin täyttö joen/lahden ulkopuolelle, jotta lampi ei kelpaa satamaksi.
    big = bytearray(nx * nz)
    best_lake = 0
    seen = bytearray(nx * nz)
    for s in range(nx * nz):
        if codes[s] != WATER or seen[s]:
            continue
        comp = [s]
        seen[s] = 1
        k = 0
        while k < len(comp):
            q = comp[k]
            k += 1
            qi, qj = q % nx, q // nx
            for a, b in ((qi - 1, qj), (qi + 1, qj), (qi, qj - 1), (qi, qj + 1)):
                if 0 <= a < nx and 0 <= b < nz:
                    w = b * nx + a
                    if codes[w] == WATER and not seen[w]:
                        seen[w] = 1
                        comp.append(w)
        if len(comp) > best_lake:
            best_lake = len(comp)
            big = bytearray(nx * nz)
            for q in comp:
                big[q] = 1
    if best_lake < 5000:
        sys.exit("pelin kartassa ei ole isoa vesialuetta")

    def lake(p):
        i, j = ij(p)
        return 0 <= i < nx and 0 <= j < nz and big[j * nx + i] == 1

    # Esteet: lavan aita, sillat, rakennukset, tiet.
    fence = tie["lava"]["fence"]
    fence_pts = VL.resample([tuple(q) for q in fence], 4.0)
    bridge_pts = []
    for a, b in tie["bridges"]:
        bridge_pts += [(p[0], p[2]) for p in tie["road"][a:b + 1]]
    bld_pts = [tuple(q) for b in tie["buildings"] for q in b["pts"]]
    road_pts = [(p[0], p[2]) for p in tie["road"]]
    for r in tie["side_roads"]:
        if r["kind"] == "road":
            road_pts += VL.resample([tuple(q) for q in r["pts"]], 6.0)

    def near_any(p, pts, d):
        return any(abs(p[0] - q[0]) < d and abs(p[1] - q[1]) < d and math.dist(p, q) < d for q in pts)

    wet_cells = [(x0 + i * cell, z0 + j * cell) for j in range(nz) for i in range(nx) if big[j * nx + i]
                 and abs(x0 + i * cell - real_game[0]) < SEARCH_R + 60 and abs(z0 + j * cell - real_game[1]) < SEARCH_R + 60]
    buckets = {}
    for q in wet_cells:
        buckets.setdefault((int(q[0] // 24), int(q[1] // 24)), []).append(q)

    def water_near(p, r):
        out = []
        bi, bj = int(p[0] // 24), int(p[1] // 24)
        n = int(r // 24) + 1
        for di in range(-n, n + 1):
            for dj in range(-n, n + 1):
                for q in buckets.get((bi + di, bj + dj), ()):
                    if math.dist(p, q) <= r:
                        out.append(q)
        return out

    best = None
    for dz in range(-int(SEARCH_R), int(SEARCH_R) + 1, 4):
        for dx in range(-int(SEARCH_R), int(SEARCH_R) + 1, 4):
            p = (round((real_game[0] + dx) / cell) * cell, round((real_game[1] + dz) / cell) * cell)
            score = math.hypot(dx, dz)
            if best is not None and score >= best[0]:
                continue
            if code(p) in (WATER, ROAD, RAIL, SHOULDER, 255) or lake(p):
                continue
            near = water_near(p, 30.0)
            if len(near) < 12:
                continue
            gap = min(math.dist(p, q) for q in near) - cell / 2.0
            if not (GAP[0] <= gap <= GAP[1]):
                continue
            cx = sum(q[0] for q in near) / len(near)
            cz = sum(q[1] for q in near) / len(near)
            d = (cx - p[0], cz - p[1])
            n = math.hypot(*d)
            if n < 1e-6:
                continue
            d = (d[0] / n, d[1] / n)
            # Laituri: ensimmäinen vesi pisteen suunnassa, sen jälkeen avovettä OPEN_WATER asti.
            t_wet = next((t for t in range(2, 30) if lake((p[0] + d[0] * t, p[1] + d[1] * t))), None)
            if t_wet is None or t_wet > 9:
                continue
            if not all(lake((p[0] + d[0] * t, p[1] + d[1] * t)) for t in range(t_wet, int(OPEN_WATER) + 1, 2)):
                continue
            side = (-d[1], d[0])
            if not all(lake((p[0] + d[0] * t + side[0] * s, p[1] + d[1] * t + side[1] * s)) for t in (t_wet + 4, t_wet + 12)
                       for s in (-6.0, 6.0)):
                continue
            if near_any(p, fence_pts, FENCE_FAR) or near_any(p, bridge_pts, 40.0) or near_any(p, bld_pts, BUILD_FAR):
                continue
            if near_any(p, road_pts, 14.0):
                continue
            # Parkki sisämaahan: kuiva, ei vettä ellipsin alla.
            pk = (p[0] - d[0] * PARK_BACK, p[1] - d[1] * PARK_BACK)
            if code(pk) in (WATER, ROAD, RAIL, 255) or water_near(pk, 8.0) or near_any(pk, bld_pts, BUILD_FAR):
                continue
            best = (score, p, d, gap, t_wet)
    if best is None:
        sys.exit("satamalle ei löytynyt rantapaikkaa %d m säteellä todellisesta paikasta" % SEARCH_R)
    moved, p, d, gap, t_wet = best
    # Laiturin juuri vesirajaan; kansi alkaa maalta.
    root = (p[0] + d[0] * (t_wet - 3.0), p[1] + d[1] * (t_wet - 3.0))
    park = (root[0] - d[0] * PARK_BACK, root[1] - d[1] * PARK_BACK)
    print("satama rannassa: %.1f m vedestä, %.0f m todellisesta paikasta (pelin kehyksessä)" % (gap, moved))

    # --- Soratie lähimmältä tieltä parkille (Dijkstra 4 m ruudukossa kuivan maan yli). ---------------------------
    targets = []
    for r in tie["side_roads"]:
        if r["kind"] == "road" and r.get("hw") not in ("path", "footway", "cycleway", "pedestrian"):
            targets += VL.resample([tuple(q) for q in r["pts"]], 4.0)
    targets += [(p2[0], p2[2]) for p2 in tie["road"]]
    tset = {}
    for q in targets:
        tset.setdefault(ij(q), q)
    si = ij(park)
    dist = {si: 0.0}
    prev = {}
    pq = [(0.0, si)]
    goal = None
    while pq:
        dd, cur = heapq.heappop(pq)
        if dd > dist.get(cur, 1e18):
            continue
        if cur in tset and cur != si:
            goal = cur
            break
        for ddi, ddj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
            nb = (cur[0] + ddi, cur[1] + ddj)
            if not (0 <= nb[0] < nx and 0 <= nb[1] < nz):
                continue
            c = codes[nb[1] * nx + nb[0]]
            if c in (WATER, RAIL):
                continue
            pnb = (x0 + nb[0] * cell, z0 + nb[1] * cell)
            if near_any(pnb, bld_pts, 8.0) or near_any(pnb, fence_pts, 6.0):
                continue
            step = math.hypot(ddi, ddj) * cell
            slope = abs(heights[nb[1] * nx + nb[0]] - heights[cur[1] * nx + cur[0]]) / cell
            wetpen = 6.0 if any(codes[(nb[1] + b) * nx + nb[0] + a] == WATER for a in (-1, 0, 1) for b in (-1, 0, 1)
                                if 0 <= nb[0] + a < nx and 0 <= nb[1] + b < nz) else 1.0
            nd = dd + step * (1.0 + slope * 6.0 + (0.4 if c in (FOREST, BOG) else 0.0)) * wetpen
            if nd < dist.get(nb, 1e18):
                dist[nb] = nd
                prev[nb] = cur
                heapq.heappush(pq, (nd, nb))
    if goal is None:
        sys.exit("parkilta ei löytynyt reittiä tielle")
    cells = [goal]
    while cells[-1] != si:
        cells.append(prev[cells[-1]])
    path = [tset[goal]] + [(x0 + a * cell, z0 + b * cell) for a, b in cells[1:-1]] + [park]
    # Silotus: liukuva keskiarvo (päät paikallaan), sitten 6 m välein.
    sm = [path[0]]
    for k in range(1, len(path) - 1):
        lo, hi = max(0, k - 3), min(len(path), k + 4)
        sm.append((sum(q[0] for q in path[lo:hi]) / (hi - lo), sum(q[1] for q in path[lo:hi]) / (hi - lo)))
    sm.append(path[-1])
    lane = VL.resample(sm, 3.0)
    thin = lane[::2]
    if thin[-1] != lane[-1]:
        thin.append(lane[-1])
    print("sorapätkä %s %.0f m" % (ROAD_NAME, sum(math.dist(a, b) for a, b in zip(lane, lane[1:]))))
    tie["side_roads"].append({"kind": "road", "hw": "unclassified", "name": ROAD_NAME, "surface": "unpaved",
                              "_satama": 1, "pts": [[round(x, 2), round(z, 2)] for x, z in thin]})

    # --- Maasto: parkki ja sorapätkä nurmeksi, parkin ja tien alle tasainen pohja. ------------------------------
    def lane_d(q):
        return VL.line_dist(q, lane)

    def seg_h(q):
        k = min(range(len(lane)), key=lambda m: (lane[m][0] - q[0]) ** 2 + (lane[m][1] - q[1]) ** 2)
        return math.dist(q, lane[k]), k

    lane_raw = [ground(*q) for q in lane]
    lane_h = [max(sum(lane_raw[max(0, k - 4):k + 5]) / len(lane_raw[max(0, k - 4):k + 5]), wl + 0.45)
              for k in range(len(lane_raw))]
    park_h = lane_h[-1]
    changed = set()
    ax, az = -d[1], d[0]
    for j in range(max(int((park[1] - 40 - z0) / cell), 0), min(int((park[1] + 40 - z0) / cell), nz - 1) + 1):
        for i in range(max(int((park[0] - 40 - x0) / cell), 0), min(int((park[0] + 40 - x0) / cell), nx - 1) + 1):
            k = j * nx + i
            q = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (WATER, RAIL, ROAD, SHOULDER):
                continue
            u = ((q[0] - park[0]) * ax + (q[1] - park[1]) * az) / PARK_R[0]
            w = ((q[0] - park[0]) * d[0] + (q[1] - park[1]) * d[1]) / PARK_R[1]
            pe = math.hypot(u, w)  # 1 = parkin reuna
            hh, code_k = heights[k], codes[k]
            if pe < 1.0:
                code_k = YARD
                hh = park_h
            elif pe < 1.9:
                hh = lerp(park_h, max(hh, wl + 0.1), smooth(1.0, 1.9, pe))
            if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                codes[k] = code_k
                heights[k] = round(hh, 3)
                changed.add((i, j))
    xs = [q[0] for q in lane]
    zs = [q[1] for q in lane]
    for j in range(max(int((min(zs) - 12 - z0) / cell), 0), min(int((max(zs) + 12 - z0) / cell), nz - 1) + 1):
        for i in range(max(int((min(xs) - 12 - x0) / cell), 0), min(int((max(xs) + 12 - x0) / cell), nx - 1) + 1):
            k = j * nx + i
            q = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (WATER, RAIL, ROAD, SHOULDER) or (i, j) in changed:
                continue
            ld, m = seg_h(q)
            if ld > 9.0:
                continue
            code_k = YARD if ld < 3.5 else codes[k]
            hh = heights[k]
            if ld < 9.0 and m < len(lane_h):
                hh = lerp(lane_h[m] - 0.05, max(heights[k], wl + 0.1), smooth(3.5, 9.0, ld))
            if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                codes[k] = code_k
                heights[k] = round(hh, 3)
                changed.add((i, j))

    tie["satama"] = {"x": round(root[0], 2), "z": round(root[1], 2), "dir": [round(d[0], 4), round(d[1], 4)],
                     "dock_len": DOCK_LEN, "park": [round(park[0], 2), round(park[1], 2)], "park_r": list(PARK_R),
                     "road": [[round(x, 2), round(z, 2)] for x, z in lane[::3]] + [[round(lane[-1][0], 2), round(lane[-1][1], 2)]],
                     "lat": SATAMA[0], "lon": SATAMA[1], "real_game": [round(real_game[0], 1), round(real_game[1], 1)],
                     "moved": round(moved), "name": ROAD_NAME}
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(far_raw)

    # --- Puut pois tieltä, parkilta ja laiturin juuresta; muutetulla maalla uuteen korkeuteen. ---------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    removed = moved_t = 0
    box = (min(xs) - 20, min(zs) - 20, max(xs) + 20, max(zs) + 20)
    for n in range(count):
        q = t0 + n * 16
        x, y, z, hgt = struct.unpack_from("<ffff", buf, q)
        if hgt <= 0.0 or not VL.in_box((x, z), box):
            continue
        u = ((x - park[0]) * ax + (z - park[1]) * az) / PARK_R[0]
        w = ((x - park[0]) * d[0] + (z - park[1]) * d[1]) / PARK_R[1]
        dr = VL.line_dist((x, z), [root, (root[0] + d[0] * DOCK_LEN, root[1] + d[1] * DOCK_LEN)])
        if lane_d((x, z)) < 5.0 or math.hypot(u, w) < 1.6 or dr < 4.5 or code((x, z)) == WATER:
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif ij((x, z)) in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved_t += 1
    with open(PUUT, "wb") as f:
        f.write(buf)

    st = tie["keskusta"]["asema"]["door"]
    gdx, gdz = root[0] - st[0], root[1] - st[1]
    rdx, rdz = real_game[0] - st[0], real_game[1] - st[1]

    def compass(dx, dz):  # +z on etelä, +x itä
        names = ["itä", "kaakko", "etelä", "lounas", "länsi", "luode", "pohjoinen", "koillinen"]
        a = math.degrees(math.atan2(dz, dx)) % 360.0
        return names[int((a + 22.5) // 45) % 8]

    print("satama (%.0f, %.0f) suunta laiturilla (%.2f, %.2f) | asemalta pelissä %s %.0f m, oikeasti %s %.0f m"
          % (root[0], root[1], d[0], d[1], compass(gdx, gdz), math.hypot(gdx, gdz), compass(rdx, rdz), math.hypot(rdx, rdz)))
    print("muutettuja ruutuja %d | puita pois %d, korkeus uuteen maahan %d" % (len(changed), removed, moved_t))


if __name__ == "__main__":
    apply()
