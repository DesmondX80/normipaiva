#!/usr/bin/env python3
"""Vaalan keskustan asfalttitie jatkuu aseman editse kierrokseksi, joka liittyy Zabukin takaa Aseman pihaan
(assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_kierros.py   (viimeinen vaihe vaala_asematie.py:n jälkeen; ajo kerran, merkki "kierros")

- Veturitallintie (asfaltti) kulkee aseman edestä; sen keskipisteestä V lähtee Ratatie: pohjoiseen aseman ja
  Kunnanviraston välistä (x 907), länteen Zabukin ja torin takaa (z -906) ja etelään Aseman pihan mutkaan (x 764,7),
  jossa se liittyy pihaan T-risteyksenä. Kulmat ovat ympyränkaaria (säde 16 m), tie 8 m kuten muu asfaltti.
- Tielle jäävät pienet rakennukset (talot ja vaja, alle 5,5 m reunasta) poistetaan; muut jäävät.
- Maasto: tien alle piha-koodi ja tasoitettu korkeus (kuten vaala_asematie.py level_lane); puut pois tieltä.
"""
import json
import math
import struct
import sys

import vaala_lava as VL

TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
V = (916.81, -790.13)                  # Veturitallintien keskipiste, tästä Ratatie lähtee pohjoiseen
WAYPOINTS = [V, (907.0, -830.0), (907.0, -906.0), (764.7, -906.0), (764.7, -855.37)]
JOIN = (764.66, -855.37)               # Aseman pihan piste, johon tie liittyy (kaaren alku)
FILLET = 16.0
STEP = 2.0
LANE_LEVEL = 9.0
CLEAR = 5.5                            # rakennus vähintään näin kauas tien keskiviivasta (ajorata 4 + piennar 1,2 + tilaa)
TREE_CLEAR = 6.5


def rnd(p):
    return [round(p[0], 2), round(p[1], 2)]


def fillet(wp, rad):
    """Murtoviiva, jonka kulmat pyöristetään ympyränkaarilla."""
    out = [wp[0]]
    for a, b, c in zip(wp, wp[1:], wp[2:]):
        u = (a[0] - b[0], a[1] - b[1])
        v = (c[0] - b[0], c[1] - b[1])
        lu, lv = math.hypot(*u), math.hypot(*v)
        u = (u[0] / lu, u[1] / lu)
        v = (v[0] / lv, v[1] / lv)
        ang = math.acos(max(-1.0, min(1.0, u[0] * v[0] + u[1] * v[1])))
        t = min(rad / math.tan(ang / 2.0), lu * 0.5, lv * 0.5)
        r = t * math.tan(ang / 2.0)
        p1 = (b[0] + u[0] * t, b[1] + u[1] * t)
        p2 = (b[0] + v[0] * t, b[1] + v[1] * t)
        bis = (u[0] + v[0], u[1] + v[1])
        lb = math.hypot(*bis)
        cc = (b[0] + bis[0] / lb * r / math.sin(ang / 2.0), b[1] + bis[1] / lb * r / math.sin(ang / 2.0))
        a0 = math.atan2(p1[1] - cc[1], p1[0] - cc[0])
        da = (math.atan2(p2[1] - cc[1], p2[0] - cc[0]) - a0 + math.pi) % (2 * math.pi) - math.pi
        n = max(int(abs(da) * r / STEP), 2)
        out += [(cc[0] + math.cos(a0 + da * k / n) * r, cc[1] + math.sin(a0 + da * k / n) * r) for k in range(n + 1)]
    out.append(wp[-1])
    return out


def in_poly(p, poly):
    ins = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            ins = not ins
    return ins


def poly_dist(p, poly):
    return 0.0 if in_poly(p, poly) else min(VL.seg_dist(p, a, b) for a, b in zip(poly, poly[1:] + poly[:1]))


def main():
    tie = json.load(open(TIE))
    if not tie.get("asematie"):
        sys.exit("aja ensin vaala_asematie.py")
    if tie.get("kierros"):
        sys.exit("kierros on jo tehty (kierros: true); palauta ensin assets/vaala (git checkout assets/vaala)")
    wl = tie["water_level"]
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    far_raw = raw[o:]

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

    # --- Tie. ----------------------------------------------------------------------------------------------------------
    lane = fillet(WAYPOINTS, FILLET)
    lane[-1] = JOIN
    veturi = next(r for r in tie["side_roads"] if r["name"] == "Veturitallintie")
    assert any(math.dist(q, V) < 0.01 for q in veturi["pts"]), "Veturitallintiessä ei ole pistettä V"
    piha = next(r for r in tie["side_roads"] if r["name"] == "Aseman piha")
    assert any(math.dist(q, JOIN) < 0.01 for q in piha["pts"]), "Aseman pihassa ei ole liittymäpistettä"
    tie["side_roads"].append({"kind": "road", "hw": "residential", "name": "Ratatie", "surface": "asphalt",
                              "pts": [rnd(p) for p in lane]})
    dense = VL.resample(lane, 3.0)

    # --- Rakennukset ja pysäköinti tieltä. -----------------------------------------------------------------------------
    keep = []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        if min(poly_dist(p, pts) for p in VL.resample(lane, 2.0)) < CLEAR:
            print("rakennus pois: %s %s (%.0f, %.0f)" % (b["kind"], b.get("name") or "", pts[0][0], pts[0][1]))
        else:
            keep.append(b)
    tie["buildings"] = keep
    for pk in tie["parkings"] + tie["keskusta"]["tori"]["parkings"]:
        if min(poly_dist(p, [tuple(q) for q in pk]) for p in dense) < CLEAR:
            sys.exit("parkkipaikka tien päällä: %s" % pk[0])

    # --- Maasto: piha-koodi ja tasoitettu korkeus tien alle. ------------------------------------------------------------
    changed = set()
    lane_raw = [ground(*q) for q in dense]
    lane_h = [max(sum(lane_raw[max(0, k - 4):k + 5]) / len(lane_raw[max(0, k - 4):k + 5]), wl + 0.45)
              for k in range(len(lane_raw))]
    xs = [q[0] for q in dense]
    zs = [q[1] for q in dense]
    for j in range(max(int((min(zs) - 12 - z0) / cell), 0), min(int((max(zs) + 12 - z0) / cell), nz - 1) + 1):
        for i in range(max(int((min(xs) - 12 - x0) / cell), 0), min(int((max(xs) + 12 - x0) / cell), nx - 1) + 1):
            k = j * nx + i
            q = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (WATER, RAIL):
                continue
            m = min(range(len(dense)), key=lambda t: (dense[t][0] - q[0]) ** 2 + (dense[t][1] - q[1]) ** 2)
            ld = math.dist(q, dense[m])
            if ld > LANE_LEVEL:
                continue
            hh = VL.lerp(lane_h[m] - 0.05, max(heights[k], wl + 0.1), VL.smooth(3.5, LANE_LEVEL, ld)) if ld >= 3.5 else lane_h[m] - 0.05
            code_k = YARD if ld < 3.5 else codes[k]
            if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                codes[k] = code_k
                heights[k] = round(hh, 3)
                changed.add((i, j))
    with open(TIE, "w") as f:
        tie["kierros"] = True
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(far_raw)

    # --- Puut pois tieltä; muutetulla maalla uuteen korkeuteen. ----------------------------------------------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    removed_t = moved_t = 0
    for q_i in range(count):
        q = t0 + q_i * 16
        x, y, z, hgt = struct.unpack_from("<ffff", buf, q)
        if hgt <= 0.0:
            continue
        if VL.line_dist((x, z), dense) < TREE_CLEAR:
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed_t += 1
        elif (int(round((x - x0) / cell)), int(round((z - z0) / cell))) in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved_t += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("Ratatie %d pistettä, %.0f m | muutettuja maaruutuja %d | puita pois %d, korkeus uuteen maahan %d"
          % (len(lane), sum(math.dist(a, b) for a, b in zip(lane, lane[1:])), len(changed), removed_t, moved_t))


if __name__ == "__main__":
    sys.exit(main())
