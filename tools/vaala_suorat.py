#!/usr/bin/env python3
"""Vaalan tieverkko suoriksi ja kohteisiin johtaviksi (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_suorat.py   (viimeinen vaihe bake-ketjun jälkeen)
Ajo kerran: tie.json:iin merkitään "suorat": true, ja uusi ajo kieltäytyy (lähdetiet ovat jo poissa). Uusi
lähtötilanne: ajo vaala_bake.py ja sen jälkeen tämä.

OSM-tieverkko oli sekava: satoja jalkakäytäviä, pyöräteitä, pihateitä ja umpikujia, jotka eivät johda mihinkään.
Tämä työkalu jättää vain tiet, jotka vievät tapahtumapaikalle, ja suoristaa ne (Douglas-Peucker, muutama suora pätkä):
- pääreitti (road) ja Neittäväntie (jatkuu järviseudulle: Ranta-Rosvo, Salmiset, laavu) säilyvät sellaisinaan
- Vaalantie: reitin pää -> liikenneympyrä; Aseman piha: ympyrä -> asema (suora, ei kierrä Ratatietä)
- Veturitallintie: Aseman pihalta Veturitallille
- Satamantie: Aseman pihalta radan ylitse (tasoristeys) ja etelään Sahanrannantielle -> satama
- Pahalahdentie: pääreitiltä lavalle
- rata ja Vaalan tori (kävelyalue) säilyvät; kaikki muu (jalkakäytävät, pyörätiet, sivutiet, umpikujahaarat) pois
Uusille ja suoristetuille teille tasoitetaan maasto ja raivataan puut.
"""
import json
import math
import struct
import sys

import vaala_lava as VL

TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
TOL_STRAIGHT = 5.0   # suoristus: enintään näin kauas alkuperäisestä linjasta (m)
RAMP = 15            # tasoristeyksen ramppi: näin monta 3 m:n näytettä (45 m) kummallakin puolella

# Uudet suorat pätkät (pelin koordinaatit, m). Pisteet tarkistettu rakennuksia vasten (>= 3,5 m).
RING_EDGE = (810.5, -874.5)        # liikenneympyrän reuna asemalle päin (ympyrä c (806, -886), r 12)
ASEMA_BEND = (840.0, -800.0)       # Aseman pihan taite: ohittaa hotellin ja torin rakennukset
SATAMA_LINK = [(839.5, -792.0), (880.0, -778.0), (903.0, -748.0), (903.0, -712.0), (880.0, -650.0)]
VETURI = [(855.0, -785.0), (854.6, -768.6)]
KATKO = [(880.0, -778.0), (900.0, -792.0), (975.0, -785.0)]   # Satamantieltä itään kätkölle (981, -783); rata ~20 m etelään


def dp(pts, tol):
    """Douglas-Peucker: pisteet, joiden väliset suorat pysyvät tol metrin sisällä alkuperäisestä."""
    if len(pts) < 3:
        return list(pts)
    a, b = pts[0], pts[-1]
    dx, dz = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dz) or 1.0
    best, bi = -1.0, 0
    for i in range(1, len(pts) - 1):
        d = abs((pts[i][0] - a[0]) * dz - (pts[i][1] - a[1]) * dx) / n
        if d > best:
            best, bi = d, i
    if best <= tol:
        return [a, b]
    return dp(pts[:bi + 1], tol)[:-1] + dp(pts[bi:], tol)


def road(name, hw, surface, pts, **extra):
    r = {"kind": "road", "hw": hw, "name": name, "surface": surface, "_suorat": 1,
         "pts": [[round(x, 2), round(z, 2)] for x, z in pts]}
    r.update(extra)
    return r


def main():
    tie = json.load(open(TIE))
    if tie.get("suorat"):
        sys.exit("tie.json on jo suoristettu (suorat: true); aja vaala_bake.py ensin")
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

    by_name = {}
    for r in tie["side_roads"]:
        if r["kind"] == "road" and r["name"]:
            by_name.setdefault(r["name"], []).append(r)

    def pts_of(r, rev=False):
        p = [tuple(q[:2]) for q in r["pts"]]
        return p[::-1] if rev else p

    # --- Lähdetiet suoristettaviksi. -------------------------------------------------------------------------------
    pahala = pts_of(by_name["Pahalahdentie"][0])
    sahaaja = pts_of(by_name["Sahaajantie"][0], rev=True)       # radalta etelään: (843, -596) -> (856, -476)
    lautatarha = pts_of(by_name["Lautatarhantie"][0])           # (856, -476) -> (820, -369)
    sahanranta = [tuple(q) for q in tie["satama"]["road"]]       # (832, -373) -> satama
    vaalantie = [r for r in by_name["Vaalantie"] if len(r["pts"]) == 2 and r["pts"][0][0] > 770 and r["pts"][0][0] < 780]
    assert vaalantie, "Vaalantien pää (reitin päästä ympyrään) puuttuu"
    vt = pts_of(vaalantie[0])

    new = []
    new.append(road("Vaalantie", "secondary", "paved", vt))
    new.append(road("Aseman piha", "residential", "asphalt", [RING_EDGE, ASEMA_BEND, tuple(by_name["Aseman piha"][0]["pts"][-1][:2])]))
    new.append(road("Veturitallintie", "residential", "asphalt", VETURI))
    # Satamantie: Aseman pihalta radan yli ja Sahaajantielle; Sahanrannantie: sorapätkä satamaan.
    sat_main = SATAMA_LINK + dp(sahaaja + lautatarha[1:], TOL_STRAIGHT) + [sahanranta[0]]
    new.append(road("Kätkötie", "unclassified", "unpaved", KATKO))
    new.append(road("Satamantie", "residential", "asphalt", sat_main))
    sr = dp(sahanranta, 3.0)
    new.append(road("Sahanrannantie", "unclassified", "unpaved", sr, _satama=1))
    tie["satama"]["road"] = [[round(x, 2), round(z, 2)] for x, z in sr]
    new.append(road("Pahalahdentie", "unclassified", "asphalt", dp(pahala, TOL_STRAIGHT)))

    # --- Poistot: kaikki muut tiet ja haarat. -----------------------------------------------------------------------
    keep = [r for r in tie["side_roads"] if r["kind"] == "rail" or r.get("name") == "Vaalan tori"]
    removed = len(tie["side_roads"]) - len(keep)
    tie["side_roads"] = keep + new
    tie["branches"] = [b for b in tie["branches"] if b["name"] == "Neittäväntie"]
    tie["suorat"] = True
    print("sivuteitä pois %d, uusia %d, haaroja jäljellä %d" % (removed, len(new), len(tie["branches"])))
    for r in new:
        length = sum(math.dist(a, b) for a, b in zip(r["pts"], r["pts"][1:]))
        print("  %-16s %2d pistettä %5.0f m" % (r["name"], len(r["pts"]), length))

    # --- Maasto: uusien ja suoristettujen teiden alle piha-koodi ja tasoitettu korkeus. -------------------------------
    lanes = []
    for r in new:
        if r["name"] == "Vaalantie":
            continue  # reitin pään ja ympyrän välinen pätkä on jo tasoitettu
        lanes.append(VL.resample([tuple(q) for q in r["pts"]], 3.0))
    changed = set()
    for lane in lanes:
        lane_raw = [ground(*q) for q in lane]
        lane_h = [max(sum(lane_raw[max(0, k - 4):k + 5]) / len(lane_raw[max(0, k - 4):k + 5]), wl + 0.45)
                  for k in range(len(lane_raw))]
        # Tasoristeys: tie kulkee kiskojen yli niiden korkeudella ja nousee ratapenkereelle loivana rampina
        # (mopo ei jaksa 0,1:n nousua); penkereen ruudut saavat tien korkeuden, RAIL-koodi säilyy.
        rail_k = [k for k, q in enumerate(lane) if codes[ij(q)[1] * nx + ij(q)[0]] == RAIL]
        if rail_k:
            a, b = rail_k[0], rail_k[-1]
            hr = max(lane_raw[max(0, a - 2):b + 3])
            for k in range(len(lane)):
                d = a - k if k < a else (k - b if k > b else 0)
                lane_h[k] = hr if d == 0 else VL.lerp(hr, lane_h[k], VL.smooth(0.0, RAMP, d))
        xs = [q[0] for q in lane]
        zs = [q[1] for q in lane]
        for j in range(max(int((min(zs) - 12 - z0) / cell), 0), min(int((max(zs) + 12 - z0) / cell), nz - 1) + 1):
            for i in range(max(int((min(xs) - 12 - x0) / cell), 0), min(int((max(xs) + 12 - x0) / cell), nx - 1) + 1):
                k = j * nx + i
                q = (x0 + i * cell, z0 + j * cell)
                if codes[k] in (WATER, ROAD, SHOULDER):
                    continue
                m = min(range(len(lane)), key=lambda t: (lane[t][0] - q[0]) ** 2 + (lane[t][1] - q[1]) ** 2)
                ld = math.dist(q, lane[m])
                if ld > 9.0 or (codes[k] == RAIL and ld >= 3.5):
                    continue
                # Ratapenger säilyy RAIL-koodilla (juna, ääni, vauhti), mutta korkeus seuraa tietä: ei porrasta.
                code_k = codes[k] if codes[k] == RAIL else (YARD if ld < 3.5 else codes[k])
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

    # --- Puut pois teiltä (kaikki uudet linjat); muutetulla maalla uuteen korkeuteen. ---------------------------------
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    lane_pts = [q for r in new for q in VL.resample([tuple(p) for p in r["pts"]], 3.0)]
    grid = {}
    for q in lane_pts:
        grid.setdefault((int(q[0] // 8.0), int(q[1] // 8.0)), []).append(q)

    def near(p, d):
        gi, gj = int(p[0] // 8.0), int(p[1] // 8.0)
        for di in (-1, 0, 1):
            for dj in (-1, 0, 1):
                for q in grid.get((gi + di, gj + dj), ()):
                    if math.dist(p, q) < d:
                        return True
        return False

    removed_t = moved_t = 0
    for n in range(count):
        q = t0 + n * 16
        x, y, z, hgt = struct.unpack_from("<ffff", buf, q)
        if hgt <= 0.0:
            continue
        if near((x, z), 5.0):
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
