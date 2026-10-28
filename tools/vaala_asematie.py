#!/usr/bin/env python3
"""Vaalantie siistillä mutkalla asemalle, torin laajennus, satamatie soraksi ja lavan parkki (assets/vaala/tie.json,
maasto.bin, puut.bin).

Ajo: python3 tools/vaala_asematie.py   (viimeinen vaihe vaala_risteys.py:n jälkeen; ajo kerran, merkki "asematie")

- Reitin (road) häntä, joka kääntyi U-mutkalla Zabukin pihan läpi Siitarin ovelle, poistetaan. Vaalantie kääntyy
  ympyränkaarella (CUT:sta alkava tangenttipiste) suoraan asemalle: ei liittymää torille. Aseman piha (asfaltti) on
  kaari ja suora aseman oven eteen; vanha Zabukin pihan kautta kiertävä Vaalantien pätkä poistuu.
- Satamantie haarautuu Aseman pihan suoralta (840, y) ja on soratie (kuten Paapelin soratiet).
- Tori laajennetaan Aseman pihan pohjoispuolelle Zabukin eteen (Vaalan tori -monikulmio), tiestä TORI_GAP päähän.
- Pahalahdentie (lavan tie) on soratie ja päättyy soralle parkkipaikalle lavan aidan ulkopuolella portin edessä
  (lava.lot; vaala.gd _build_lava_lot). Aidan sisäpuoli on kävelyaluetta, joten pihan tie (lava.road) on vain parkin ajokaista.
- Maasto: uusien teiden ja parkin alle piha ja tasoitettu korkeus, poistetun hännän pinta takaisin pihaksi;
  puut pois uusilta teiltä, torilta ja parkilta.
"""
import json
import math
import struct
import sys

import vaala_lava as VL

TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
CUT = 743                              # reitin viimeinen näyte: mutkan alkupiste T1 (suora tien pää)
J = (770.7, -860.3)                    # mutkan kulmapiste: reitin suoran ja aseman suoran leikkaus (reitin näyte 749)
S1 = (893.0, -786.0)                   # aseman suoran loppu
STATION_END = [(908.5, -779.8), (910.5, -773.6)]
ARC_STEP = 2.0
TORI_BACK = 22.0                       # torin syvyys tiestä Zabukin taakse (m)
TORI_GAP = 9.0                         # torin reuna näin kauas Aseman pihan keskiviivasta (tie 4 + piennar 1,2 + tilaa)
TORI_LEN = 46.0
LANE_LEVEL = 9.0
# Lavan parkki aidan (z = -296,9) ulkopuolella portin (645,25, -296,88) edessä: u itään, v pohjoiseen (poispäin aidasta).
LOT = {"c": [642.5, -301.5], "ax": [1.0, 0.0], "front": [0.0, -1.0], "ua": -10.0, "nb": 8, "v0": 1.5, "aisle": 6.0}
LOT_BAY_W, LOT_BAY_D = 2.6, 5.0       # vaala.gd LOT_BAY_W, LOT_BAY_D
LOT_END_Z = -311.5                     # Pahalahdentien pää parkin ajokaistalla


def rnd(p):
    return [round(p[0], 2), round(p[1], 2)]


def unit(v):
    n = math.hypot(*v)
    return (v[0] / n, v[1] / n)


def in_poly(p, poly):
    ins = False
    for a, b in zip(poly, poly[1:] + poly[:1]):
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            ins = not ins
    return ins


def main():
    tie = json.load(open(TIE))
    if tie.get("asematie"):
        sys.exit("asematie on jo tehty (asematie: true); aja vaala_bake.py-ketju uudelleen (git checkout assets/vaala)")
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

    # --- Reitin häntä pois, mutka asemalle. -----------------------------------------------------------------------------
    rt = tie["road"]
    t1 = (rt[CUT][0], rt[CUT][2])
    din = unit((J[0] - t1[0], J[1] - t1[1]))
    dout = unit((S1[0] - J[0], S1[1] - J[1]))
    turn = math.atan2(din[0] * dout[1] - din[1] * dout[0], din[0] * dout[0] + din[1] * dout[1])  # + = oikealle (z alas)
    tl = math.dist(t1, J)                      # tangenttipituus
    rad = tl / math.tan(abs(turn) / 2.0)       # kaaren säde
    sgn = 1.0 if turn > 0 else -1.0
    nrm = (-din[1] * sgn, din[0] * sgn)        # sisäpuolen normaali (kaaren keskipisteeseen)
    centre = (t1[0] + nrm[0] * rad, t1[1] + nrm[1] * rad)
    t2 = (J[0] + dout[0] * tl, J[1] + dout[1] * tl)
    a0 = math.atan2(t1[1] - centre[1], t1[0] - centre[0])
    steps = max(int(abs(turn) * rad / ARC_STEP), 4)
    # Kaari kulkee T1:stä T2:een: kokeillaan kiertosuunta, jolla viimeinen piste on lähempänä T2:ta.
    def sweep(direction):
        return [(centre[0] + math.cos(a0 + direction * abs(turn) * k / steps) * rad,
                 centre[1] + math.sin(a0 + direction * abs(turn) * k / steps) * rad) for k in range(1, steps)]

    arc = min((sweep(1.0), sweep(-1.0)), key=lambda c_: math.dist(c_[-1], t2))
    assert math.dist(arc[-1], t2) < math.dist(arc[0], t2), "kaari väärään suuntaan"
    print("mutka: kulma %.0f°, säde %.1f m, tangentti %.1f m, kaarella %d pistettä" % (math.degrees(abs(turn)), rad, tl, len(arc)))
    tail = [(q[0], q[2]) for q in rt[CUT + 1:]]
    tie["road"] = rt[:CUT + 1]
    tie["road_names"] = tie["road_names"][:CUT + 1]
    print("reitin pää (%.1f, %.1f), häntä %d näytettä pois" % (t1[0], t1[1], len(tail)))
    aseman = [t1] + arc + [t2, S1] + STATION_END
    sat_z = round(J[1] + (840.0 - J[0]) * (S1[1] - J[1]) / (S1[0] - J[0]), 2)
    satama_join = (840.0, sat_z)

    # --- Tiet. -------------------------------------------------------------------------------------------------------
    old_roads = [r for r in tie["side_roads"] if r["name"] == "Aseman piha"]
    old_vt = [r for r in tie["side_roads"] if r["name"] == "Vaalantie" and r["kind"] == "road"]
    old_lane = [tuple(q[:2]) for r in old_vt + old_roads for q in r["pts"]]
    tie["side_roads"] = [r for r in tie["side_roads"] if r not in old_roads and r not in old_vt]
    piha = {"kind": "road", "hw": "tertiary", "name": "Aseman piha", "surface": "asphalt", "_suorat": 1,
            "pts": [rnd(p) for p in aseman]}
    tie["side_roads"].append(piha)
    sat = next(r for r in tie["side_roads"] if r["name"] == "Satamantie")
    sat["pts"] = [rnd(satama_join)] + sat["pts"]  # alkaa Aseman pihalta, jatkuu entiseen (840, -800)
    sat["surface"] = "unpaved"
    sat["hw"] = "unclassified"

    # --- Tori: Aseman pihan pohjoispuolella, Zabukin edessä. -----------------------------------------------------------
    d = dout
    n = (d[1], -d[0])              # pohjoiseen (z pienenee) päin
    if n[1] > 0:
        n = (-n[0], -n[1])
    p1 = (J[0] + n[0] * TORI_GAP - d[0] * 2.0, J[1] + n[1] * TORI_GAP - d[1] * 2.0)
    p2 = (p1[0] + d[0] * TORI_LEN, p1[1] + d[1] * TORI_LEN)
    p3 = (p2[0] + n[0] * TORI_BACK, p2[1] + n[1] * TORI_BACK)
    # Länsireuna kauemmas pienestä talosta (759-771, -883--872): ajoalueen marginaali ei saa jäädä torin reunan päälle.
    p4 = (p1[0] + n[0] * TORI_BACK + d[0] * 14.0, p1[1] + n[1] * TORI_BACK + d[1] * 14.0)
    tori = [p1, p2, p3, p4, (p1[0] + n[0] * 5.0 + d[0] * 5.0, p1[1] + n[1] * 5.0 + d[1] * 5.0)]  # kolmioituu (Geometry2D)
    tori_r = next(r for r in tie["side_roads"] if r["name"] == "Vaalan tori")
    tori_r["pts"] = [rnd(p) for p in tori] + [rnd(tori[0])]
    print("tori", tori_r["pts"])

    # Vanha torin parkkipaikka (keskusta.tori.parkings) olisi Aseman pihan ja torin päällä: pois.
    def crosses(poly):
        c = (sum(q[0] for q in poly) / len(poly), sum(q[1] for q in poly) / len(poly))
        return VL.line_dist(c, [tuple(p) for p in aseman]) < 20.0 or in_poly(c, tori)

    kp = tie["keskusta"]["tori"]["parkings"]
    tie["keskusta"]["tori"]["parkings"] = [pk for pk in kp if not crosses([tuple(q) for q in pk])]
    tie["parkings"] = [pk for pk in tie["parkings"] if not (700 < pk[0][0] < 900 and -900 < pk[0][1] < -780
                                                           and crosses([tuple(q) for q in pk]))]

    # --- Lavan tie soraksi ja parkki aidan ulkopuolelle. -----------------------------------------------------------------
    lv = tie["lava"]
    paha = next(r for r in tie["side_roads"] if r["name"] == "Pahalahdentie")
    a, b = paha["pts"][-2], paha["pts"][-1]
    end = [round(a[0] + (b[0] - a[0]) * (LOT_END_Z - a[1]) / (b[1] - a[1]), 2), LOT_END_Z]
    paha["pts"] = paha["pts"][:-1] + [end]
    paha["surface"] = "unpaved"
    lv["lot"] = dict(LOT)
    cx, cz = LOT["c"]
    lot_poly = [(cx + LOT["ua"], cz - LOT["v0"]), (cx + LOT["ua"] + LOT["nb"] * LOT_BAY_W, cz - LOT["v0"]),
                (cx + LOT["ua"] + LOT["nb"] * LOT_BAY_W, cz - LOT["v0"] - LOT_BAY_D - LOT["aisle"]),
                (cx + LOT["ua"], cz - LOT["v0"] - LOT_BAY_D - LOT["aisle"])]
    lane_z = cz - LOT["v0"] - LOT_BAY_D - LOT["aisle"] / 2.0
    lv["road"] = [rnd((lot_poly[0][0] + 1.0, lane_z)), rnd((lot_poly[1][0] - 1.0, lane_z))]
    assert in_poly(tuple(end), lot_poly), "Pahalahdentien pää ei osu parkin ajokaistalle %s %s" % (end, lot_poly)
    old_lane_lava = [(660.16, -276.01), (658.63, -270.88), (658.63, -248.88)]

    # --- Maasto. -----------------------------------------------------------------------------------------------------
    changed = set()
    # Poistetun hännän ja vanhojen kiertoteiden pinta takaisin pihaksi (ei uusien teiden eikä torin alla).
    new_lane = VL.resample([tuple(p) for p in aseman], 3.0)
    old_pts = VL.resample(tail, 3.0) + VL.resample(old_lane, 3.0) + VL.resample(old_lane_lava, 3.0)
    for q0 in old_pts:
        ci, cj = ij(q0)
        for j in range(cj - 3, cj + 4):
            for i in range(ci - 3, ci + 4):
                if not (0 <= i < nx and 0 <= j < nz):
                    continue
                k = j * nx + i
                q = (x0 + i * cell, z0 + j * cell)
                if codes[k] in (ROAD, SHOULDER) and math.dist(q, q0) < 8.0 and VL.line_dist(q, new_lane) > 6.0:
                    codes[k] = YARD
                    changed.add((i, j))

    def level_lane(lane):
        lane_raw = [ground(*q) for q in lane]
        lane_h = [max(sum(lane_raw[max(0, k - 4):k + 5]) / len(lane_raw[max(0, k - 4):k + 5]), wl + 0.45)
                  for k in range(len(lane_raw))]
        xs = [q[0] for q in lane]
        zs = [q[1] for q in lane]
        for j in range(max(int((min(zs) - 12 - z0) / cell), 0), min(int((max(zs) + 12 - z0) / cell), nz - 1) + 1):
            for i in range(max(int((min(xs) - 12 - x0) / cell), 0), min(int((max(xs) + 12 - x0) / cell), nx - 1) + 1):
                k = j * nx + i
                q = (x0 + i * cell, z0 + j * cell)
                if codes[k] in (WATER, RAIL):
                    continue
                m = min(range(len(lane)), key=lambda t: (lane[t][0] - q[0]) ** 2 + (lane[t][1] - q[1]) ** 2)
                ld = math.dist(q, lane[m])
                if ld > LANE_LEVEL:
                    continue
                hh = VL.lerp(lane_h[m] - 0.05, max(heights[k], wl + 0.1), VL.smooth(3.5, LANE_LEVEL, ld)) if ld >= 3.5 else lane_h[m] - 0.05
                code_k = YARD if ld < 3.5 else codes[k]
                if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                    codes[k] = code_k
                    heights[k] = round(hh, 3)
                    changed.add((i, j))

    # Uusi Aseman piha ja Satamantien alkupätkä: piha-koodi ja tasoitettu korkeus.
    level_lane(new_lane)
    level_lane(VL.resample([satama_join, (840.0, -800.0)], 3.0))

    # Parkki tasaiseksi pihaksi (korkeus keskiarvo), reunat liukuvat ympäristöön 3-8 m:ssä.
    lot_h = sum(ground(*q) for q in lot_poly + [tuple(end)]) / 5.0
    for j in range(max(int((min(p[1] for p in lot_poly) - 9 - z0) / cell), 0), min(int((max(p[1] for p in lot_poly) + 9 - z0) / cell), nz - 1) + 1):
        for i in range(max(int((min(p[0] for p in lot_poly) - 9 - x0) / cell), 0), min(int((max(p[0] for p in lot_poly) + 9 - x0) / cell), nx - 1) + 1):
            k = j * nx + i
            q = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (WATER, RAIL):
                continue
            inside = in_poly(q, lot_poly)
            dist = 0.0 if inside else min(VL.seg_dist(q, a_, b_) for a_, b_ in zip(lot_poly, lot_poly[1:] + lot_poly[:1]))
            if dist > 8.0:
                continue
            hh = lot_h - 0.05 if dist < 3.0 else VL.lerp(lot_h - 0.05, heights[k], VL.smooth(3.0, 8.0, dist))
            code_k = YARD if dist < 3.0 else codes[k]
            if code_k != codes[k] or abs(hh - heights[k]) > 0.01:
                codes[k] = code_k
                heights[k] = round(hh, 3)
                changed.add((i, j))
    # Tori tasaiseksi pihaksi.
    for j in range(max(int((min(p[1] for p in tori) - 4 - z0) / cell), 0), min(int((max(p[1] for p in tori) + 4 - z0) / cell), nz - 1) + 1):
        for i in range(max(int((min(p[0] for p in tori) - 4 - x0) / cell), 0), min(int((max(p[0] for p in tori) + 4 - x0) / cell), nx - 1) + 1):
            k = j * nx + i
            q = (x0 + i * cell, z0 + j * cell)
            if codes[k] in (WATER, RAIL) or not in_poly(q, tori):
                continue
            if codes[k] != YARD:
                codes[k] = YARD
                changed.add((i, j))
    with open(TIE, "w") as f:
        tie["asematie"] = True
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(far_raw)

    # --- Puut pois uusilta teiltä, torilta ja parkilta; muutetulla maalla uuteen korkeuteen. ----------------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    sat_new = VL.resample([satama_join, (840.0, -800.0)], 3.0)
    lot_edge = lot_poly + [lot_poly[0]]
    removed_t = moved_t = 0
    for q_i in range(count):
        q = t0 + q_i * 16
        x, y, z, hgt = struct.unpack_from("<ffff", buf, q)
        if hgt <= 0.0:
            continue
        near_lot = in_poly((x, z), lot_poly) or VL.line_dist((x, z), lot_edge) < 4.0
        if VL.line_dist((x, z), new_lane) < 6.5 or VL.line_dist((x, z), sat_new) < 5.0 or in_poly((x, z), tori) or near_lot:
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed_t += 1
        elif ij((x, z)) in changed:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved_t += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("muutettuja maaruutuja %d | puita pois %d, korkeus uuteen maahan %d" % (len(changed), removed_t, moved_t))


if __name__ == "__main__":
    sys.exit(main())
