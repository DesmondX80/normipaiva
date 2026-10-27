#!/usr/bin/env python3
"""Vaalan tieverkon saarekkeet yhteen (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_linkit.py   (toistettava: aiemmat linkit poistetaan ennen uutta ajoa)

Pelin Vaala on tiivistetty ja siirretty kehys, joten osa OSM-teistä jää irralleen muusta tieverkosta (sataman
Sahanrannantie, Lautatarhantie, Takatie, Telitie, metsätiet ...). Mopolla niille ei päässyt: ajoalue oli saareke.
Työkalu etsii tieverkon yhtenäiset osat (tiet, joiden pisteet ovat TOL metrin sisällä toisistaan, ovat samaa
verkkoa) ja yhdistää jokaisen irrallisen osan päätieverkkoon (reitti + haarat) soratiellä:
- Dijkstra 4 m maastoruudukossa lyhintä kuivaa reittiä irralliselta osalta verkkoon (ei vettä, rataa, rakennuksia,
  lavan aitaa), jyrkkä rinne ja rannan läheisyys maksavat
- linkki on tie.json side_roads -rivi (kind road, hw unclassified, surface unpaved, "_linkki": 1)
- maasto tasoitetaan linkin alle (kuten vaala_satama.py), puut pois linkin tieltä.
Tarkistus pelissä: godot --headless --path . -- --shot=x.png --scene=vaala_ajo --ajo=yhteys
"""
import heapq
import json
import math
import struct
import sys

import vaala_lava as VL

TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
TOL = 6.0          # tiet, joiden pisteet ovat näin lähellä, ovat samaa verkkoa (m)
MAX_LINK = 700.0   # pisin linkki (m); pidempi ilmoitetaan eikä tehdä
BUILD_FAR = 8.0    # linkki näin kauas rakennuksista
FENCE_FAR = 6.0
RAIL_FAR = 4.0
ROAD_NAME = ""


def main():
    tie = json.load(open(TIE))
    wl = tie["water_level"]
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

    tie["side_roads"] = [r for r in tie["side_roads"] if not r.get("_linkki")]

    # --- Tieverkon viivat: [nimi, pisteet 4 m välein]. -----------------------------------------------------------
    lines = [["reitti", VL.resample([(p[0], p[2]) for p in tie["road"]], 4.0), "main"]]
    for b in tie["branches"]:
        lines.append(["haara " + b["name"], VL.resample([(p[0], p[2]) for p in b["pts"]], 4.0), "branch"])
    for r in tie["side_roads"]:
        if r["kind"] == "rail" or r["hw"] == "steps" or len(r["pts"]) < 2:
            continue
        lines.append([(r["name"] or "nimetön") + " (" + r["hw"] + ")", VL.resample([tuple(q[:2]) for q in r["pts"]], 4.0), "side"])
    if "lava" in tie:
        lines.append(["lavan tie", VL.resample([tuple(q) for q in tie["lava"]["road"]], 4.0), "lava"])

    parent = list(range(len(lines)))

    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a

    def union(a, b):
        parent[find(a)] = find(b)

    def connect_nearby():
        grid = {}
        for li, ln in enumerate(lines):
            for p in ln[1]:
                grid.setdefault((int(p[0] // TOL), int(p[1] // TOL)), []).append((li, p))
        for li, ln in enumerate(lines):
            for p in ln[1]:
                gi, gj = int(p[0] // TOL), int(p[1] // TOL)
                for di in (-1, 0, 1):
                    for dj in (-1, 0, 1):
                        for lj, q in grid.get((gi + di, gj + dj), ()):
                            if lj != li and find(lj) != find(li) and math.dist(p, q) <= TOL:
                                union(li, lj)

    connect_nearby()

    # --- Esteet. -------------------------------------------------------------------------------------------------
    def hash_pts(pts, size):
        g = {}
        for q in pts:
            g.setdefault((int(q[0] // size), int(q[1] // size)), []).append(q)
        return g

    def near_hash(g, size, p, d):
        gi, gj = int(p[0] // size), int(p[1] // size)
        n = int(d // size) + 1
        for di in range(-n, n + 1):
            for dj in range(-n, n + 1):
                for q in g.get((gi + di, gj + dj), ()):
                    if math.dist(p, q) < d:
                        return True
        return False

    bld = []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        bld += VL.resample(pts + [pts[0]], 3.0)
    bld_h = hash_pts(bld, 8.0)
    fence_h = hash_pts(VL.resample([tuple(q) for q in tie["lava"]["fence"]], 3.0), 8.0)
    rail = []
    for r in tie["side_roads"]:
        if r["kind"] == "rail":
            rail += VL.resample([tuple(q[:2]) for q in r["pts"]], 2.0)
    rail_h = hash_pts(rail, 8.0)

    def blocked(p):
        return near_hash(bld_h, 8.0, p, BUILD_FAR) or near_hash(fence_h, 8.0, p, FENCE_FAR) or near_hash(rail_h, 8.0, p, RAIL_FAR)

    # --- Linkit: pienin irrallinen osa kerrallaan lähimmän verkon kautta päätieverkkoon. --------------------------
    main_root = find(0)
    new_links = []
    failed = []
    skip = set()
    while True:
        roots = {find(i) for i in range(len(lines))}
        islands = [r for r in roots if r != find(0) and r not in skip]
        if not islands:
            break
        # Lähin saareke ensin (linkit voivat ketjuuntua: pieni saareke liittyy suuremman kautta).
        main_pts = [p for li, ln in enumerate(lines) if find(li) == find(0) for p in ln[1]]
        targets = {}
        for p in main_pts:
            targets.setdefault(ij(p), p)

        def gap(root):
            ps = [p for li, ln in enumerate(lines) if find(li) == root for p in ln[1]]
            return min(math.dist(p, q) for p in ps[::3] for q in main_pts[::3])

        root = min(islands, key=gap)
        members = [li for li in range(len(lines)) if find(li) == root]
        names = [lines[li][0] for li in members]
        sources = {}
        for li in members:
            for p in lines[li][1]:
                sources.setdefault(ij(p), p)
        dist = {}
        prev = {}
        pq = []
        for c, p in sources.items():
            dist[c] = 0.0
            heapq.heappush(pq, (0.0, c))
        goal = None
        while pq:
            dd, cur = heapq.heappop(pq)
            if dd > dist.get(cur, 1e18):
                continue
            if dd > MAX_LINK * 1.6:
                break
            if cur in targets and cur not in sources:
                goal = cur
                break
            for ddi, ddj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                nb = (cur[0] + ddi, cur[1] + ddj)
                if not (1 <= nb[0] < nx - 1 and 1 <= nb[1] < nz - 1):
                    continue
                c = codes[nb[1] * nx + nb[0]]
                if c in (WATER, RAIL) or c == 255:
                    continue
                pnb = (x0 + nb[0] * cell, z0 + nb[1] * cell)
                if nb not in targets and nb not in sources and blocked(pnb):
                    continue
                step = math.hypot(ddi, ddj) * cell
                slope = abs(heights[nb[1] * nx + nb[0]] - heights[cur[1] * nx + cur[0]]) / cell
                wetpen = 4.0 if any(codes[(nb[1] + b) * nx + nb[0] + a] == WATER for a in (-1, 0, 1) for b in (-1, 0, 1)) else 1.0
                nd = dd + step * (1.0 + slope * 8.0 + (0.3 if c in (FOREST, BOG) else 0.0)) * wetpen
                if nd < dist.get(nb, 1e18):
                    dist[nb] = nd
                    prev[nb] = cur
                    heapq.heappush(pq, (nd, nb))
        if goal is None:
            failed.append(names)
            skip.add(root)
            continue
        cells = [goal]
        while cells[-1] in prev and cells[-1] not in sources:
            cells.append(prev[cells[-1]])
        cells.reverse()
        path = [sources[cells[0]]] + [(x0 + a * cell, z0 + b * cell) for a, b in cells[1:-1]] + [targets[goal]]
        length = sum(math.dist(a, b) for a, b in zip(path, path[1:]))
        if length > MAX_LINK:
            failed.append(names + ["(%.0f m)" % length])
            skip.add(root)
            continue
        sm = [path[0]]
        for k in range(1, len(path) - 1):
            lo, hi = max(0, k - 3), min(len(path), k + 4)
            sm.append((sum(q[0] for q in path[lo:hi]) / (hi - lo), sum(q[1] for q in path[lo:hi]) / (hi - lo)))
        sm.append(path[-1])
        lane = VL.resample(sm, 3.0)
        thin = lane[::2]
        if thin[-1] != lane[-1]:
            thin.append(lane[-1])
        new_links.append((lane, thin))
        lines.append(["linkki", lane, "link"])
        parent.append(len(lines) - 1)
        union(len(lines) - 1, root)
        union(len(lines) - 1, find(0))
        print("linkki %5.0f m: %s" % (length, ", ".join(names[:3]) + (" +%d" % (len(names) - 3) if len(names) > 3 else "")))

    for names in failed:
        print("EI LINKKIÄ:", names)
    if not new_links:
        print("ei linkitettäviä saarekkeita")
        return

    for lane, thin in new_links:
        tie["side_roads"].append({"kind": "road", "hw": "unclassified", "name": ROAD_NAME, "surface": "unpaved",
                                  "_linkki": 1, "pts": [[round(x, 2), round(z, 2)] for x, z in thin]})

    # --- Maasto: linkin alle piha-koodi ja tasoitettu korkeus (kuten sataman sorapätkä). --------------------------
    changed = set()
    for lane, _thin in new_links:
        lane_raw = [ground(*q) for q in lane]
        lane_h = [max(sum(lane_raw[max(0, k - 4):k + 5]) / len(lane_raw[max(0, k - 4):k + 5]), wl + 0.45)
                  for k in range(len(lane_raw))]
        xs = [q[0] for q in lane]
        zs = [q[1] for q in lane]
        for j in range(max(int((min(zs) - 12 - z0) / cell), 0), min(int((max(zs) + 12 - z0) / cell), nz - 1) + 1):
            for i in range(max(int((min(xs) - 12 - x0) / cell), 0), min(int((max(xs) + 12 - x0) / cell), nx - 1) + 1):
                k = j * nx + i
                q = (x0 + i * cell, z0 + j * cell)
                if codes[k] in (WATER, RAIL, ROAD, SHOULDER):
                    continue
                m = min(range(len(lane)), key=lambda t: (lane[t][0] - q[0]) ** 2 + (lane[t][1] - q[1]) ** 2)
                ld = math.dist(q, lane[m])
                if ld > 9.0:
                    continue
                code_k = YARD if ld < 3.5 else codes[k]
                hh = VL.lerp(lane_h[m] - 0.05, max(heights[k], wl + 0.1), VL.smooth(3.5, 9.0, ld)) if ld >= 3.5 else lane_h[m] - 0.05
                if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                    codes[k] = code_k
                    heights[k] = round(hh, 3)
                    changed.add((i, j))
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(far_raw)

    # --- Puut pois linkiltä; muutetulla maalla uuteen korkeuteen. -------------------------------------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    lane_hash = hash_pts([q for lane, _t in new_links for q in lane], 8.0)
    removed = moved_t = 0
    for n in range(count):
        q = t0 + n * 16
        x, y, z, hgt = struct.unpack_from("<ffff", buf, q)
        if hgt <= 0.0:
            continue
        if near_hash(lane_hash, 8.0, (x, z), 5.0):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif ij((x, z)) in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved_t += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("linkkejä %d, muutettuja ruutuja %d | puita pois %d, korkeus uuteen maahan %d" % (len(new_links), len(changed), removed, moved_t))


if __name__ == "__main__":
    sys.exit(main())
