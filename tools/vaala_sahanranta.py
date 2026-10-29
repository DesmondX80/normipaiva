#!/usr/bin/env python3
"""Vaalan aseman siirto, satama lähemmäs, uiton sauna ja Sahanrannan täyte (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: python3 tools/vaala_sahanranta.py   (venv/bin/python; viimeinen vaihe vaala_suorat.py:n jälkeen)
tie.json:iin merkitään "sahanranta": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

1. Asema (rakennus, laituri, piha), Veturitalli, Veturitallintie ja Kätkötie siirtyvät ST_SHIFT m radan suuntaan
   (itään), ja kätkö (asema.katko) seuraa. Aseman lähirakennukset siirtyvät mukana lähimpään vapaaseen paikkaan.
   Satamantie lähtee nyt Aseman pihan taitteesta suoraan etelään vanhan aseman paikan läpi (tasoristeys) eikä kierrä
   aseman takaa.
2. Satama haetaan rannasta lähemmäs asemaa (vaala_satama.py, hakukeskus HARBOR_TARGET).
3. Uiton sauna: toinen rantapaikka satamaan johtavan tien varrella (tie.json "uitto"; vaala.gd _build_uitto):
   hirsisauna, pukuhuone/varasto, laituri ja uimatikkaat sekä Uitontie-sorapätkä.
4. Sahanrannan täyte: pientaloja, aittoja ja saunoja teiden varrella (oikean Sahanrannan rakennusten mitoin), puita
   pihoille, rannoille ja tyhjille nurmille.
"""
import json
import math
import os
import random
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "kartta"))
import numpy as np  # noqa: E402
import puut_teilta as PT  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_satama as VSA  # noqa: E402

TIE, MAASTO, PUUT = VL.TIE, VL.MAASTO, VL.PUUT
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)

ST_SHIFT = 80.0                    # asema (ja kätkö) näin paljon radan suuntaan itään
PROTECT = (225699583, 225699578, 534430535, 225699572, 225699563)  # K-Market, Siitari, Gasthaus, hotelli, kunnantalo
J_BEND = (840.0, -800.0)           # Aseman pihan taite = Satamantien risteys
HARBOR_TARGET = (775.0, -318.0)    # sataman hakukeskus pelin koordinaateissa (rantaviivaa lähin kelvollinen paikka)
UITTO_TARGET = (745.0, -440.0)
UITTO_YARD = 2.6                   # uiton pihan korkeus vedenpinnan yläpuolella (m)
UITTO_BANK = 3.2                   # törmän korkeus vedenpinnasta enintään (m)     # uiton saunan hakukeskus
UITTO_DOCK = 9.0
UITTO_PARK_BACK = 9.0
UITTO_PARK_R = (13.0, 8.0)
SAUNA_SIZE = (6.2, 4.4)            # hirsisauna: leveys rantaa pitkin x syvyys
RNG = random.Random(2810)


# --- Geometria ---------------------------------------------------------------------------------------------------

def rect(c, ax, az, hl, hw):
    return [[c[0] + ax[0] * hl * u + az[0] * hw * v, c[1] + ax[1] * hl * u + az[1] * hw * v]
            for u, v in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def in_poly(p, poly):
    x, z = p
    inside = False
    n = len(poly)
    for i in range(n):
        a, b = poly[i], poly[(i + 1) % n]
        if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
    return inside


def poly_dist(p, poly):
    """Etäisyys monikulmion reunasta (0 sisällä)."""
    if in_poly(p, poly):
        return 0.0
    return min(VL.seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def polys_dist(a, b):
    """Likimääräinen etäisyys kahden monikulmion välillä (kärjet toistensa reunoihin)."""
    if any(in_poly(q, b) for q in a) or any(in_poly(q, a) for q in b):
        return 0.0
    return min(min(poly_dist(q, b) for q in a), min(poly_dist(q, a) for q in b))


def center(poly):
    pts = poly[:-1] if poly[0] == poly[-1] else poly
    return (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))


def shifted(poly, dx, dz):
    return [[round(p[0] + dx, 2), round(p[1] + dz, 2)] for p in poly]


# --- Maasto ja puut -----------------------------------------------------------------------------------------------

class Terrain:
    def __init__(self):
        raw = open(MAASTO, "rb").read()
        self.nx, self.nz, self.x0, self.z0, self.cell = struct.unpack_from("<iifff", raw, 0)
        o = 20
        self.h = list(struct.unpack_from("<%df" % (self.nx * self.nz), raw, o))
        o += self.nx * self.nz * 4
        self.codes = bytearray(raw[o:o + self.nx * self.nz])
        o += self.nx * self.nz
        self.far = raw[o:]
        self.changed = set()

    def ij(self, p):
        return int(round((p[0] - self.x0) / self.cell)), int(round((p[1] - self.z0) / self.cell))

    def code(self, p):
        i, j = self.ij(p)
        return self.codes[j * self.nx + i] if 0 <= i < self.nx and 0 <= j < self.nz else 255

    def ground(self, x, z):
        fx = min(max((x - self.x0) / self.cell, 0.0), self.nx - 1.001)
        fz = min(max((z - self.z0) / self.cell, 0.0), self.nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        q = j * self.nx + i
        h, nx = self.h, self.nx
        if u + v <= 1.0:
            return h[q] + (h[q + 1] - h[q]) * u + (h[q + nx] - h[q]) * v
        return h[q + nx + 1] + (h[q + nx] - h[q + nx + 1]) * (1.0 - u) + (h[q + 1] - h[q + nx + 1]) * (1.0 - v)

    def cells(self, box):
        for j in range(max(int((box[1] - self.z0) / self.cell), 0), min(int((box[3] - self.z0) / self.cell), self.nz - 1) + 1):
            for i in range(max(int((box[0] - self.x0) / self.cell), 0), min(int((box[2] - self.x0) / self.cell), self.nx - 1) + 1):
                yield i, j, (self.x0 + i * self.cell, self.z0 + j * self.cell)

    def set(self, i, j, code, height):
        k = j * self.nx + i
        if code != self.codes[k] or abs(height - self.h[k]) > 0.01:
            self.codes[k] = code
            self.h[k] = round(height, 3)
            self.changed.add((i, j))

    def flatten(self, lots, blend=8.0, level=None):
        """Tontit tasaiseksi (yhteinen korkeus), pehmeä liitos blend m:llä; tontin ruudut pihaksi."""
        pts = [q for p in lots for q in p]
        box = (min(q[0] for q in pts) - blend - 4, min(q[1] for q in pts) - blend - 4,
               max(q[0] for q in pts) + blend + 4, max(q[1] for q in pts) + blend + 4)
        inner = [self.h[j * self.nx + i] for i, j, q in self.cells(box)
                 if self.codes[j * self.nx + i] not in (WATER, 255) and any(in_poly(q, p) for p in lots)]
        lvl = level if level is not None else (sum(inner) / len(inner) if inner else self.ground(*center(pts)))
        for i, j, q in self.cells(box):
            k = j * self.nx + i
            if self.codes[k] in (WATER, 255):
                continue
            d = min(poly_dist(q, p) for p in lots)
            if d <= 0.0:
                self.set(i, j, YARD if self.codes[k] != RAIL else RAIL, lvl)
            elif d < blend and self.codes[k] != RAIL:
                self.set(i, j, YARD if d < 2.0 else self.codes[k], VL.lerp(lvl, self.h[k], VL.smooth(0.0, blend, d)))
        return lvl

    def lane(self, pts, wl, ramp=15):
        """Tien alle tasoitettu pohja ja piha-koodi (kuten vaala_suorat.py); tasoristeys nousee kiskojen korkeudelle."""
        lane = VL.resample([tuple(q) for q in pts], 3.0)
        raw = [self.ground(*q) for q in lane]
        lh = [max(sum(raw[max(0, k - 4):k + 5]) / len(raw[max(0, k - 4):k + 5]), wl + 0.45) for k in range(len(raw))]
        rail_k = [k for k, q in enumerate(lane) if self.code(q) == RAIL]
        if rail_k:
            a, b = rail_k[0], rail_k[-1]
            hr = max(raw[max(0, a - 2):b + 3])
            for k in range(len(lane)):
                d = a - k if k < a else (k - b if k > b else 0)
                lh[k] = hr if d == 0 else VL.lerp(hr, lh[k], VL.smooth(0.0, ramp, d))
        xs, zs = [q[0] for q in lane], [q[1] for q in lane]
        for i, j, q in self.cells((min(xs) - 12, min(zs) - 12, max(xs) + 12, max(zs) + 12)):
            k = j * self.nx + i
            if self.codes[k] in (WATER, ROAD, SHOULDER):
                continue
            m = min(range(len(lane)), key=lambda t: (lane[t][0] - q[0]) ** 2 + (lane[t][1] - q[1]) ** 2)
            ld = math.dist(q, lane[m])
            if ld > 9.0 or (self.codes[k] == RAIL and ld >= 3.5):
                continue
            code = self.codes[k] if self.codes[k] == RAIL else (YARD if ld < 3.5 else self.codes[k])
            hh = VL.lerp(lh[m] - 0.05, max(self.h[k], wl + 0.1), VL.smooth(3.5, 9.0, ld)) if ld >= 3.5 else lh[m] - 0.05
            self.set(i, j, code, hh)

    def _sync_far(self):
        """Kaukomaasto tarkan alueen alla on tarkan maaston korkeus - 1,5 m (vaala_bake.py): muuttuneet ruudut päivitetään,
        muuten esim. alikulun leikkauksen päälle jää kaukomaaston "katto"."""
        if not self.changed:
            return
        fnx, fnz, fx0, fz0, fcell = struct.unpack_from("<iifff", self.far, 0)
        arr = list(struct.unpack_from("<%df" % (fnx * fnz), self.far, 20))
        ci0 = min(i for i, j in self.changed)
        ci1 = max(i for i, j in self.changed)
        cj0 = min(j for i, j in self.changed)
        cj1 = max(j for i, j in self.changed)
        fi0 = max(int((self.x0 + (ci0 - 1) * self.cell - fx0) / fcell), 0)
        fi1 = min(int((self.x0 + (ci1 + 2) * self.cell - fx0) / fcell) + 1, fnx - 1)
        fj0 = max(int((self.z0 + (cj0 - 1) * self.cell - fz0) / fcell), 0)
        fj1 = min(int((self.z0 + (cj1 + 2) * self.cell - fz0) / fcell) + 1, fnz - 1)
        n = 0
        # Kaukomaaston kolmiot ulottuvat kulmasta kulmaan (fcell), joten kulma painetaan koko ympäristönsä
        # (±fcell) tarkan maaston matalimman pisteen alle: muuten leikkauksen yli jää kaukomaaston "katto".
        reach = int(fcell / self.cell)
        for fj in range(max(fj0 - 1, 0), min(fj1 + 1, fnz - 1) + 1):
            for fi in range(max(fi0 - 1, 0), min(fi1 + 1, fnx - 1) + 1):
                ci = int(round((fx0 + fi * fcell - self.x0) / self.cell))
                cj = int(round((fz0 + fj * fcell - self.z0) / self.cell))
                if not (0 <= ci < self.nx and 0 <= cj < self.nz):
                    continue
                low = min(self.h[j * self.nx + i]
                          for j in range(max(cj - reach, 0), min(cj + reach, self.nz - 1) + 1)
                          for i in range(max(ci - reach, 0), min(ci + reach, self.nx - 1) + 1))
                if low - 1.5 < arr[fj * fnx + fi] - 0.005:
                    arr[fj * fnx + fi] = round(low - 1.5, 2)
                    n += 1
        self.far = struct.pack("<iifff", fnx, fnz, fx0, fz0, fcell) + struct.pack("<%df" % (fnx * fnz), *arr)
        print("kaukomaasto päivitetty: %d ruutua" % n)

    def save(self):
        self._sync_far()
        with open(MAASTO, "wb") as f:
            f.write(struct.pack("<iifff", self.nx, self.nz, self.x0, self.z0, self.cell))
            f.write(struct.pack("<%df" % (self.nx * self.nz), *self.h))
            f.write(bytes(self.codes))
            f.write(self.far)


class Trees:
    """puut.bin muistissa: poisto, korkeuden päivitys ja lisäys (PT.write_onp3 säilyttää puukohtaiset tavut)."""

    def __init__(self):
        t0, t1, self.far_chunk, self.near_chunk = PT.read_onp3(PUUT)
        live = t0[:, 3] > 0.0
        self.t0, self.t1 = t0[live], t1[live]

    def near_any(self, pts, d):
        """Maski: puut, jotka ovat alle d m jostain pisteestä."""
        mask = np.zeros(len(self.t0), bool)
        for x, z in pts:
            mask |= (np.abs(self.t0[:, 0] - x) < d) & (np.abs(self.t0[:, 2] - z) < d) \
                & ((self.t0[:, 0] - x) ** 2 + (self.t0[:, 2] - z) ** 2 < d * d)
        return mask

    def remove(self, mask):
        self.t0, self.t1 = self.t0[~mask], self.t1[~mask]

    def reground(self, terr):
        for k in range(len(self.t0)):
            if terr.ij((self.t0[k, 0], self.t0[k, 2])) in terr.changed:
                self.t0[k, 1] = terr.ground(self.t0[k, 0], self.t0[k, 2])

    def add(self, items, terr):
        """items = [(x, z, korkeus, laji)]."""
        a = np.zeros((len(items), 4), "<f4")
        b = np.zeros((len(items), 4), np.uint8)
        for k, (x, z, h, sp) in enumerate(items):
            a[k] = (x, terr.ground(x, z), z, h)
            r = 0.35 + 0.085 * h if sp == 1 else (0.5 + 0.1 * h if sp == 0 else 0.6 + 0.12 * h)
            b[k] = (int(np.clip(round(min(max(r, 0.4), 5.0) * 40), 1, 255)), sp, RNG.randrange(256), RNG.randrange(256))
        self.t0 = np.concatenate([self.t0, a])
        self.t1 = np.concatenate([self.t1, b])

    def save(self):
        PT.write_onp3(PUUT, self.t0, self.t1, self.far_chunk, self.near_chunk)


def load_tie():
    return json.load(open(TIE))


def save_tie(tie):
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))


def road_rec(name, hw, surface, pts, **extra):
    r = {"kind": "road", "hw": hw, "name": name, "surface": surface, "_sahanranta": 1,
         "pts": [[round(x, 2), round(z, 2)] for x, z in pts]}
    r.update(extra)
    return r


def rail_lines(tie):
    return [[tuple(p[:2]) for p in r["pts"]] for r in tie["side_roads"] if r["kind"] == "rail" and len(r["pts"]) > 50]


def rail_z(line, x):
    for a, b in zip(line, line[1:]):
        if a[0] <= x <= b[0]:
            return a[1] + (b[1] - a[1]) * (x - a[0]) / (b[0] - a[0])
    return None


def road_pts(tie, tag_skip=()):
    out = [(p[0], p[2]) for p in tie["road"]]
    for r in tie["side_roads"]:
        if r["kind"] == "road" and r.get("hw") not in ("pedestrian",) and not any(r.get(t) for t in tag_skip):
            out += VL.resample([tuple(q[:2]) for q in r["pts"]], 4.0)
    return out


# --- 1. Asema ----------------------------------------------------------------------------------------------------

def move_station(tie, terr, trees):
    ast = tie["keskusta"]["asema"]
    ra = tuple(ast["along"])
    out = tuple(ast["out"])
    dx, dz = ra[0] * ST_SHIFT, ra[1] * ST_SHIFT
    old = {k: ast[k] for k in ("pts", "platform", "yard")}
    old_door = list(ast["door"])
    for k in ("pts", "platform", "yard"):
        ast[k] = shifted(ast[k], dx, dz)
    ast["door"] = [round(ast["door"][0] + dx, 2), round(ast["door"][1] + dz, 2)]
    pts = ast["pts"]
    c = center(pts)
    sl = math.dist(pts[0], pts[1])  # aseman pituus radan suuntaan
    sd = math.dist(pts[1], pts[2])
    # Veturitalli (vaala.gd _build_veturitalli): aseman itäpäätyyn + 11 m, ulospäin D/2 + 8 m; 12 x 8 m, piha 16 m eteen.
    vq = (c[0] + ra[0] * (sl / 2 + 11) + out[0] * (sd / 2 + 8), c[1] + ra[1] * (sl / 2 + 11) + out[1] * (sd / 2 + 8))
    vt_lot = rect((vq[0] + out[0] * 6.0, vq[1] + out[1] * 6.0), ra, out, 9.0, 10.5)
    vt_door = (vq[0] + out[0] * 6.2, vq[1] + out[1] * 6.2)
    lots = [pts, ast["platform"], ast["yard"], vt_lot]
    door_out = (ast["door"][0] + out[0] * 1.5, ast["door"][1] + out[1] * 1.5)
    front = (ast["door"][0] + out[0] * 8.0, ast["door"][1] + out[1] * 8.0)

    # Kätkö: sama paikka radan suhteen kuin ennen (vanha 981, -783), nyt ST_SHIFT eteenpäin.
    katko = (981.0 + dx, -783.0 + dz)
    lines = rail_lines(tie)
    zn = min(rail_z(ln, katko[0]) for ln in lines if rail_z(ln, katko[0]) is not None)
    katko = (katko[0], zn - 5.6)
    ast["katko"] = [round(katko[0], 2), round(katko[1], 2)]

    # Tiet: Aseman piha jatkuu taitteesta radan pohjoispuolta aseman ovelle, Satamantie suoraan etelään.
    piha = [tuple(p[:2]) for p in next(r for r in tie["side_roads"] if r.get("name") == "Aseman piha")["pts"]][:2]
    piha_new = piha + [(870.0, -792.0), (895.0, -785.0), front, door_out]
    e_vt = (vt_door[0] + out[0] * 2.0, vt_door[1] + out[1] * 2.0)
    vt_road = [(front[0] - ra[0] * 4.0 - out[0] * 2.0, front[1] - ra[1] * 4.0 - out[1] * 2.0),
               (e_vt[0] - ra[0] * 14.0, e_vt[1] - ra[1] * 14.0 + 0.5), e_vt]
    # Kätkötie: Veturitallin edestä itään radan pohjoispuolta (8 m pohjoiseen pohjoisimmasta kiskosta) kätkölle.
    kt = [e_vt, (e_vt[0] + ra[0] * 12.0, e_vt[1] + ra[1] * 12.0)]  # ensin vajan edustaa eteenpäin (ei kulman poikki)
    x = e_vt[0] + 34.0
    while x < katko[0] - 9.0:
        zr = min(rail_z(ln, x) for ln in lines if rail_z(ln, x) is not None)
        kt.append((x, zr - 8.0))
        x += 25.0
    kt.append((katko[0] - 5.5, katko[1] - 0.5))
    sat_old = next(r for r in tie["side_roads"] if r.get("name") == "Satamantie")["pts"]
    tail = [tuple(p) for p in sat_old[5:]]  # (843, -596) -> eteenpäin
    sat_new = [J_BEND, (840.0, -760.0), (841.0, -728.0), (842.0, -690.0), (847.0, -650.0)] + tail
    tie["side_roads"] = [r for r in tie["side_roads"] if r.get("name") not in ("Aseman piha", "Veturitallintie", "Kätkötie", "Satamantie")]
    tie["side_roads"] += [road_rec("Aseman piha", "residential", "asphalt", piha_new),
                          road_rec("Veturitallintie", "residential", "asphalt", vt_road),
                          road_rec("Kätkötie", "unclassified", "unpaved", kt),
                          road_rec("Satamantie", "residential", "asphalt", sat_new)]

    # Rakennukset: lähitalot siirtyvät mukana lähimpään vapaaseen paikkaan; muut, jotka osuvat uusiin tontteihin, pois.
    roads = [VL.resample([tuple(q[:2]) for q in r["pts"]], 4.0) for r in tie["side_roads"] if r["kind"] == "road"
             and r.get("name") != "Vaalan tori"]
    rails = [q for ln in lines for q in VL.resample(ln, 6.0)]
    old_lots = [old["pts"], old["platform"], old["yard"]]
    moved = dropped = 0
    keep = []
    todo = []
    for b in tie["buildings"]:
        if b["id"] in PROTECT or b["id"] == ast["id"]:
            keep.append(b)
        elif polys_dist(b["pts"], pts) < 22.0 and min(poly_dist(center(b["pts"]), p) for p in old_lots) < 40.0 \
                or any(polys_dist(b["pts"], p) < 3.0 for p in lots):
            todo.append(b)
        else:
            keep.append(b)

    def ok(poly):
        if any(polys_dist(poly, p) < 3.5 for p in lots):
            return False
        if any(polys_dist(poly, o["pts"]) < 4.0 for o in keep):
            return False
        cc = center(poly)
        if any(math.dist(cc, q) < 7.0 for r in roads for q in r) or any(math.dist(cc, q) < 12.0 for q in rails):
            return False
        return all(terr.code(q) not in (WATER, RAIL, ROAD, 255) for q in poly + [cc])

    for b in todo:
        bp = b["pts"]
        best = None
        for r in range(0, 61, 4):
            for k in range(0 if r == 0 else 12):
                a = k / 12.0 * math.tau
                tdx, tdz = dx + math.cos(a) * r, dz + math.sin(a) * r
                cand = shifted(bp, tdx, tdz)
                if ok(cand):
                    best = cand
                    break
            if best:
                break
        if best:
            b["pts"] = best
            keep.append(b)
            moved += 1
        else:
            dropped += 1
    tie["buildings"] = keep
    # Maasto: asema, laituri ja piha tasaisiksi, tiet pohjineen; puut pois.
    terr.flatten([pts, ast["platform"], ast["yard"]], 8.0)
    terr.flatten([vt_lot], 6.0)
    for r in ("Aseman piha", "Veturitallintie", "Kätkötie", "Satamantie"):
        terr.lane(next(q for q in tie["side_roads"] if q.get("name") == r)["pts"], tie["water_level"])
    allroads = [q for r in tie["side_roads"] if r.get("_sahanranta") for q in VL.resample([tuple(p) for p in r["pts"]], 3.0)]
    trees.remove(trees.near_any(allroads, 5.0))
    for p in lots:
        px = [q for q in VL.resample([tuple(q) for q in p + [p[0]]], 3.0)]
        trees.remove(trees.near_any(px, 4.0))
        cc = center(p)
        trees.remove(trees.near_any([cc], max(math.dist(cc, q) for q in p) + 1.0) & np.array(
            [in_poly((x, z), p) for x, z in zip(trees.t0[:, 0], trees.t0[:, 2])]) if len(trees.t0) else np.zeros(0, bool))
    print("asema %s -> %s | lähitaloja siirretty %d, pois %d | kätkö %s" % (
        [round(v, 1) for v in old_door], ast["door"], moved, dropped, ast["katko"]))


# --- Täyte ----------------------------------------------------------------------------------------------------

def noise(x, z):
    """Pehmeä 0..1-kohina (summa siniaaltoja): lehdot ja aukiot."""
    v = math.sin(x * 0.043 + 1.3) * math.sin(z * 0.051 + 0.4) + 0.6 * math.sin(x * 0.11 + z * 0.07 + 2.0) \
        + 0.4 * math.sin(z * 0.19 - x * 0.13)
    return min(max(0.5 + v * 0.3, 0.0), 1.0)


def fill(tie, terr, trees):
    wl = tie["water_level"]
    sat, uit = tie["satama"], tie["uitto"]
    names = ("Satamantie", "Sahanrannantie", "Uitontie")
    lines = {r["name"]: r for r in tie["side_roads"] if r["kind"] == "road" and r["name"] in names}
    zone = []
    for n in names:
        pts = [tuple(p) for p in lines[n]["pts"]]
        zone.append(([q for q in VL.resample(pts, 3.0) if q[1] > -610.0], n))
    dims = [(8.5, 7.6, "house", 1, 5.5), (9.0, 6.2, "house", 1, 5.5), (9.1, 6.8, "house", 1, 4.3), (10.7, 6.5, "house", 1, 3.7),
            (11.7, 6.5, "house", 1, 5.5), (12.5, 11.2, "house", 2, 6.9), (12.7, 8.1, "house", 1, 5.5), (13.3, 11.5, "house", 2, 7.4),
            (13.9, 8.7, "house", 2, 7.4), (13.5, 9.3, "house", 1, 4.8), (16.2, 9.0, "house", 1, 5.8), (10.0, 6.5, "house", 1, 4.4),
            (5.2, 4.1, "shed", 1, 3.2), (4.3, 3.9, "shed", 1, 3.0), (5.3, 4.4, "shed", 1, 3.4), (3.2, 3.0, "shed", 1, 2.9)]
    all_roads = road_pts(tie)
    rails = [q for ln in rail_lines(tie) for q in VL.resample(ln, 6.0)]
    # Sataman, uiton saunan ja laitureiden varaukset.
    keepouts = []
    for site, pr in ((sat, 1.9), (uit, 1.9)):
        d = site["dir"]
        keepouts.append((tuple(site["park"]), max(site["park_r"]) * pr))
        for t in range(0, int(site["dock_len"]) + 8, 4):
            keepouts.append(((site["x"] + d[0] * t, site["z"] + d[1] * t), 9.0))
    lava = tie.get("lava", {}).get("fence", [])
    exist = [b["pts"] for b in tie["buildings"]]
    nid = -3000000
    placed = 0

    def free(poly, cc, margin):
        if any(math.dist(cc, k[0]) < k[1] for k in keepouts):
            return False
        if any(math.dist(cc, q) < 12.0 for q in rails):
            return False
        for q in poly + [cc]:
            if terr.code(q) in (WATER, RAIL, ROAD, SHOULDER, 255) or terr.ground(*q) < wl + 1.2:
                return False
        if any(math.dist(cc, q) < margin for q in all_roads):
            return False
        if any(min(math.dist(q, r) for r in all_roads[::1]) < 3.8 for q in poly) if False else False:
            return False
        if any(polys_dist(poly, e) < 5.0 for e in exist):
            return False
        return True

    for pts, name in zone:
        hw = 3.0
        s = 8.0
        while s < len(pts) * 3.0 - 8.0:
            k = int(s / 3.0)
            a, b = pts[k], pts[min(k + 2, len(pts) - 1)]
            tl = math.dist(a, b) or 1.0
            t = ((b[0] - a[0]) / tl, (b[1] - a[1]) / tl)
            n = (-t[1], t[0])
            for side in (1.0, -1.0):
                if RNG.random() < 0.12:
                    continue
                w, d, kind, lv, hh = RNG.choice(dims if RNG.random() < 0.72 else dims[-4:])
                if kind == "shed":
                    w, d = w * RNG.uniform(0.9, 1.3), d * RNG.uniform(0.9, 1.2)
                setback = hw + RNG.uniform(5.0, 12.0) + d / 2.0
                cc = (a[0] + n[0] * side * setback, a[1] + n[1] * side * setback)
                yaw = RNG.uniform(-0.15, 0.15)
                tt = (t[0] * math.cos(yaw) - t[1] * math.sin(yaw), t[0] * math.sin(yaw) + t[1] * math.cos(yaw))
                nn = (-tt[1], tt[0])
                poly = rect(cc, tt, nn, w / 2.0, d / 2.0)
                if not free(poly, cc, hw + d / 2.0 + 2.5):
                    continue
                nid -= 1
                tie["buildings"].append({"id": nid, "type": "yes", "kind": kind, "levels": lv, "h": hh, "name": "", "addr": "",
                                         "pts": [[round(q[0], 2), round(q[1], 2)] for q in poly]})
                exist.append(poly)
                terr_flat = [poly]
                terr.flatten(terr_flat, 4.0)
                placed += 1
            s += RNG.uniform(14.0, 24.0)
    # Rantamökit ja aitat tienvarren takana: satunnaisia paikkoja nurmella, kaukana teistä ja rannasta, julkisivu rantaan päin.
    wz = [q for q in all_roads if q[1] > -620.0]
    sh = [(xq, zq) for xq in range(700, 960, 4) for zq in range(-600, -240, 4) if terr.code((xq, zq)) == WATER]
    cx0 = (tie["satama"]["x"] + tie["uitto"]["x"]) / 2.0
    tries = 0
    cottages = 0
    while cottages < 22 and tries < 4000:
        tries += 1
        cc = (RNG.uniform(700.0, 960.0), RNG.uniform(-600.0, -250.0))
        if terr.code(cc) not in (YARD, FIELD):
            continue
        near_r = min(math.dist(cc, q) for q in wz)
        if not 16.0 < near_r < 75.0:
            continue
        wq = min(sh, key=lambda q: math.dist(cc, q))
        wd = math.dist(cc, wq)
        if not 12.0 < wd < 95.0:
            continue
        nn = ((wq[0] - cc[0]) / wd, (wq[1] - cc[1]) / wd)  # rantaa kohti
        tt = (-nn[1], nn[0])
        w, d, kind, lv, hh = RNG.choice(dims if RNG.random() < 0.45 else dims[-4:])
        poly = rect(cc, tt, nn, w / 2.0, d / 2.0)
        if not free(poly, cc, 16.0):
            continue
        nid -= 1
        tie["buildings"].append({"id": nid, "type": "yes", "kind": kind, "levels": lv, "h": hh, "name": "", "addr": "",
                                 "pts": [[round(q[0], 2), round(q[1], 2)] for q in poly]})
        exist.append(poly)
        terr.flatten([poly], 4.0)
        cottages += 1
    placed += cottages
    # Pihojen ja rannan puut sekä lehdot tyhjille nurmille.
    zone_pts = [q for pts, _ in zone for q in pts]
    zone_pts += [tuple(sat["park"]), tuple(uit["park"])]
    bx = (min(q[0] for q in zone_pts) - 130, min(q[1] for q in zone_pts) - 40, max(q[0] for q in zone_pts) + 130, max(q[1] for q in zone_pts) + 150)
    near_b = [center(e) for e in exist]
    items = []
    ex = {}
    for x, z in zip(trees.t0[:, 0], trees.t0[:, 2]):
        ex.setdefault((int(x // 5), int(z // 5)), []).append((x, z))

    def crowded(x, z, d):
        gi, gj = int(x // 5), int(z // 5)
        r = int(d // 5) + 1
        return any(math.dist((x, z), q) < d for di in range(-r, r + 1) for dj in range(-r, r + 1) for q in ex.get((gi + di, gj + dj), ()))

    shore = [(x0, z0) for i, j, (x0, z0) in terr.cells(bx) if terr.codes[j * terr.nx + i] == WATER]
    sg = {}
    for q in shore:
        sg.setdefault((int(q[0] // 16), int(q[1] // 16)), []).append(q)

    def water_d(x, z):
        gi, gj = int(x // 16), int(z // 16)
        return min((math.dist((x, z), q) for di in (-2, -1, 0, 1, 2) for dj in (-2, -1, 0, 1, 2) for q in sg.get((gi + di, gj + dj), ())), default=99.0)

    grove = 0
    step = 4.0
    xx = bx[0]
    while xx < bx[2]:
        zz = bx[1]
        while zz < bx[3]:
            x, z = xx + RNG.uniform(0, step), zz + RNG.uniform(0, step)
            zz += step
            c = terr.code((x, z))
            if c in (WATER, ROAD, SHOULDER, RAIL, 255) or terr.ground(x, z) < wl + 0.6:
                continue
            if min(math.dist((x, z), q) for q in zone_pts) > 150.0:
                continue
            if min(math.dist((x, z), q) for q in all_roads if abs(q[0] - x) < 30 and abs(q[1] - z) < 30) < 5.5 if any(
                    abs(q[0] - x) < 30 and abs(q[1] - z) < 30 for q in all_roads) else False:
                continue
            if any(math.dist((x, z), k[0]) < k[1] + 2.0 for k in keepouts) or any(math.dist((x, z), q) < 12.0 for q in rails):
                continue
            if any(in_poly((x, z), e) or poly_dist((x, z), e) < 3.0 for e in exist if abs(center(e)[0] - x) < 25 and abs(center(e)[1] - z) < 25):
                continue
            nz_ = noise(x, z)
            wd = water_d(x, z)
            nb = min((math.dist((x, z), q) for q in near_b if abs(q[0] - x) < 22 and abs(q[1] - z) < 22), default=99.0)
            p = 0.01 + (0.5 if nz_ > 0.62 else 0.0) * (1.0 if c in (YARD, FIELD) else 0.4)
            if nb < 18.0:
                p += 0.09                       # pihapuut
            if 5.0 < wd < 22.0:
                p += 0.1                        # rantaleppiä ja -pajuja
            if RNG.random() > p or crowded(x, z, 3.2):
                continue
            wet_side = wd < 22.0 or c == BOG
            if wet_side and RNG.random() < 0.35:
                sp, hh = 4, RNG.uniform(1.4, 2.6)
            elif nb < 18.0 and RNG.random() < 0.6:
                sp, hh = RNG.choice([2, 2, 3, 0]), RNG.uniform(7.0, 13.0)
            else:
                sp = RNG.choices([0, 1, 2, 3], [0.45, 0.3, 0.2, 0.05])[0]
                hh = RNG.uniform(9.0, 17.0) if sp != 2 else RNG.uniform(8.0, 15.0)
            items.append((x, z, hh, sp))
            ex.setdefault((int(x // 5), int(z // 5)), []).append((x, z))
            if nz_ > 0.62:
                grove += 1
        xx += step
    trees.add(items, terr)
    # Lehtojen alla metsäpohja (nurmi -> metsä), ei teiden, pihojen eikä talojen vieressä.
    forested = 0
    for i, j, q in terr.cells(bx):
        k = j * terr.nx + i
        if terr.codes[k] != YARD or noise(*q) <= 0.7:
            continue
        if min((math.dist(q, r) for r in all_roads if abs(r[0] - q[0]) < 14 and abs(r[1] - q[1]) < 14), default=99.0) < 9.0:
            continue
        if any(math.dist(q, kk[0]) < kk[1] + 6.0 for kk in keepouts) or min(near_b and [math.dist(q, c2) for c2 in near_b if abs(c2[0] - q[0]) < 30 and abs(c2[1] - q[1]) < 30] or [99.0]) < 16.0:
            continue
        terr.codes[k] = FOREST
        forested += 1
    print("täyte: taloja %d, puita %d (lehtoja %d), metsäpohjaa %d ruutua" % (placed, len(items), grove, forested))


def main():
    tie = load_tie()
    if tie.get("sahanranta"):
        sys.exit("tie.json on jo käsitelty (sahanranta: true); uusi lähtötilanne: git checkout assets/vaala")
    terr, trees = Terrain(), Trees()
    move_station(tie, terr, trees)
    tie["sahanranta"] = True
    save_tie(tie)
    terr.save()
    trees.reground(terr)
    trees.save()
    # Satama lähemmäs ja uiton sauna (vaala_satama.py lukee ja kirjoittaa tiedostot itse).
    VSA.apply(target=HARBOR_TARGET, search_r=110.0)
    VSA.apply(target=UITTO_TARGET, search_r=170.0, max_bank=UITTO_BANK, key="uitto", name="Uitontie", tag="_uitto", dock_len=UITTO_DOCK,
              park_back=UITTO_PARK_BACK, park_r=UITTO_PARK_R, avoid=[(json.load(open(TIE))["satama"]["x"], json.load(open(TIE))["satama"]["z"])], avoid_d=70.0)
    tie = load_tie()
    trim_satamantie(tie)
    terr, trees = Terrain(), Trees()
    soften_uitto(tie, terr)
    fill(tie, terr, trees)
    save_tie(tie)
    terr.save()
    trees.reground(terr)
    trees.save()


def soften_uitto(tie, terr):
    """Uiton piha matalammaksi ja ranta loivaksi: DEM:n törmä (5 m neljässä metrissä) on liian jyrkkä laiturille ja
    uimarannalle. Piha vedenpinnan yläpuolelle UITTO_YARD m, pihalta vesirajaan tasainen luiska."""
    u = tie["uitto"]
    d = u["dir"]
    side = (d[1], -d[0])
    wl = tie["water_level"]
    ly = wl + UITTO_YARD
    pc = u["park"]
    pr = u["park_r"]
    yard = [[pc[0] + side[0] * math.cos(a) * pr[0] * 0.97 + d[0] * math.sin(a) * pr[1] * 0.97,
             pc[1] + side[1] * math.cos(a) * pr[0] * 0.97 + d[1] * math.sin(a) * pr[1] * 0.97]
            for a in [k * math.tau / 24 for k in range(24)]]
    terr.flatten([yard], 9.0, level=ly)
    root = (u["x"], u["z"])
    for i, j, q in terr.cells((root[0] - 30, root[1] - 30, root[0] + 30, root[1] + 30)):
        k = j * terr.nx + i
        if terr.codes[k] in (WATER, RAIL, ROAD, 255):
            continue
        rx, rz = q[0] - root[0], q[1] - root[1]
        uu, vv = rx * side[0] + rz * side[1], rx * d[0] + rz * d[1]
        wgt = 1.0 - VL.smooth(8.0, 13.0, abs(uu))
        if wgt <= 0.0 or vv < -2.0:
            continue
        prof = VL.lerp(ly, wl + 0.05, VL.smooth(-2.0, 4.5, vv))
        new = VL.lerp(terr.h[k], min(prof, terr.h[k]), wgt)
        terr.set(i, j, YARD if (wgt > 0.5 and terr.codes[k] != SHOULDER) else terr.codes[k], new)
    print("uiton piha %.1f m, ranta loivennettu" % ly)


def trim_satamantie(tie):
    """Satamantie päättyy Sahanrannantien (sataman) liittymään; Uitontie liittyy Satamantiehen."""
    sat = next(r for r in tie["side_roads"] if r.get("name") == "Satamantie")
    pts = [tuple(p) for p in sat["pts"]]
    j = tuple(tie["satama"]["road"][0])
    best = min(range(len(pts) - 1), key=lambda i: VL.seg_dist(j, pts[i], pts[i + 1]))
    sat["pts"] = [list(p) for p in pts[:best + 1]] + [[round(j[0], 2), round(j[1], 2)]]
    print("Satamantie päättyy", [round(v) for v in j], "pituus %.0f m" % sum(math.dist(a, b) for a, b in zip(sat["pts"], sat["pts"][1:])))


if __name__ == "__main__":
    main()
