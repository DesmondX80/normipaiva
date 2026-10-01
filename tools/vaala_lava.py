#!/usr/bin/env python3
"""Oulujärven lava ja sen ympäristö Vaalan mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_lava.py [--cache <välimuisti>]
(vaala_bake.py ajaa tämän lopuksi; ilman välimuistia, kun reitti.json:ssa on jo "lava_dem").

Lava oli Pahalahdentien päässä niemen kärjessä (64.550921 N, 26.822649 E), jossa Oulujoki alkaa Oulujärvestä:
idässä joki, etelässä järvi ja lounaassa Pahalahti, kaikki samassa pinnassa (korkeusmallissa 122,74 m). Pelissä lava
on hieman lähempänä Vuolijoentietä (LAVA_SHIFT) ja Pahalahdentie on asfaltoitu lavalle asti.

Pahalahdentien risteys on mopomatkan 1:1-alueella, mutta niemen kaukomaasto tuli leivonnassa tiivistetyn tien
suhteen (todellisuudessa muualta), joten niemellä ei ollut vettä. Tämä tekee alueelle AREA 1:1-maaston:
- tarkka ruudukko (4 m) korkeusmallista (reitti.json "lava_dem", MML 2 m; --cache hakee sen) koko AREA:lle: vesi
  korkeusmallin vedenpinnasta (joki leveänä sillalta järveen), tontti ja tien varsi nurmeksi, tiivistetyn tien
  käytävän (CORRIDOR) maasto liitetään 1:1-maastoon pehmeästi; tiet, pientareet ja rata jäävät ennalleen
- kaukomaasto tarkan alle ja järvi kaukomaastoon: tasaiset vedenpinnat (1:1-alueella vedenpinnan korkeudella,
  tiivistetyllä alueella tien suhteen siirtyneinä) painetaan pohjaksi (vedenpinta - 2 m), vaala.gd piirtää niille vettä
- aita lavan ympäri rannasta rantaan (pohjoisessa joelta Pahalahdentien portin yli, lännessä Pahalahteen)
- puut pois vedestä, tontilta, aidan linjalta ja tieltä; muiden korkeus uuteen maahan.
Ajo on toistettavissa: muutettujen kaukoruutujen alkuarvot ja alun perin tyhjät tarkat ruudut ovat tie.json:ssa
("lava_area"), ja ne palautetaan ennen uutta ajoa.
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
LAVA_SHIFT = (-68.0, -65.0)  # pelissä niemen kärjestä n. 90 m lähemmäs Vuolijoentietä, Pahalahdentien länsipuolelle
LAVA_SIZE = (34.0, 44.0)  # 1 500 m², pitkä sivu z-suunnassa (vaala.gd _build_lava)
ROAD_NAME = "Pahalahdentie"
# Pelin kehyksessä (x0, z0, x1, z1): 1:1-maasto, tiivistetyn tien käytävä sen sisällä ja järven etsintä.
AREA = (300.0, -1300.0, 1300.0, -150.0)
CORRIDOR = (300.0, -650.0, 330.0, -150.0)  # tien varsi pysyy leivottuna, 1:1-maasto liitetään siihen
REMAP = (330.0, -650.0, 1300.0, -150.0)    # leivottu maasto (tiivistetyn tien suhteen) korvataan 1:1-maastolla
CORRIDOR_BLEND = 60.0
LAKE_REL = (300.0, -700.0, 1e9, 1e9)  # tiivistetyn tien suhteen kuvattu järvi (pinta siirtynyt)
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

def rle(flags):
    out, k = [], 0
    while k < len(flags):
        if flags[k]:
            s = k
            while k < len(flags) and flags[k]:
                k += 1
            out.append([s, k - s])
        else:
            k += 1
    return out


def apply(cache=None):
    d = json.load(open(SRC))
    tie = json.load(open(TIE))
    off = tie["town_off"]
    wl = tie["water_level"]
    if "lava_dem" not in d:
        if not cache:
            sys.exit("reitti.json:ssa ei ole lavan korkeusmallia: aja kerran --cache <välimuisti>")
        fetch_dem(d, off, cache)
    dem = Dem(d["lava_dem"], off)
    g = lambda p: (p[0] + off[0], p[1] + off[1])  # noqa: E731

    # --- Maasto sisään; edellisen ajon muutokset pois. ---------------------------------------------------------
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
    ai0, aj0 = int(round((AREA[0] - x0) / cell)), int(round((AREA[1] - z0) / cell))
    ai1, aj1 = int(round((AREA[2] - x0) / cell)), int(round((AREA[3] - z0) / cell))
    anx = ai1 - ai0 + 1
    prev = tie.get("lava_area")
    if prev:
        for k, v in prev["far_orig"]:
            far[k] = v
        gen = [False] * (anx * (aj1 - aj0 + 1))
        for s, n in prev["gen"]:
            for k in range(s, s + n):
                gen[k] = True
    else:
        gen = [codes[(aj0 + k // anx) * nx + ai0 + k % anx] == OUTSIDE for k in range(anx * (aj1 - aj0 + 1))]
    far_orig = list(far)

    def far_h(x, z, f=far):
        fx = min(max((x - fx0) / fcell, 0.0), fnx - 1.001)
        fz = min(max((z - fz0) / fcell, 0.0), fnz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        q = j * fnx + i
        return lerp(lerp(f[q], f[q + 1], u), lerp(f[q + fnx], f[q + fnx + 1], u), v)

    # --- Lava, Pahalahdentie (asfaltti lavalle asti) ja aita. ------------------------------------------------
    real = g(to_xz(*LAVA))
    c = (real[0] + LAVA_SHIFT[0], real[1] + LAVA_SHIFT[1])
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
    hw, hl = LAVA_SIZE[0] / 2.0, LAVA_SIZE[1] / 2.0
    # Ovi tien puoleiselle pitkälle sivulle; tie loppuu ajotien liittymään (niemen kärkeen ei enää ajeta).
    side = 1.0 if min(road, key=lambda p: math.dist(p, c))[0] >= c[0] else -1.0
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
        while not wet((p[0] + dx * t, p[1] + dz * t)):
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

    # Puut (pituus 0 = ei piirretä eikä törmätä, ks. forest.gd). AREA:n metsäpohja vain puiden alle, muualla niittyä.
    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, nfx, nfz, nnx, nnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (nfx * nfz + nnx * nnz) * 5 * 8
    wooded = set()
    for n in range(count):
        x, _y, z, h = struct.unpack_from("<ffff", buf, t0 + n * 16)
        if h > 0.0 and in_box((x, z), AREA, 8.0) and not drop(x, z):
            ci, cj = int(round((x - x0) / cell)), int(round((z - z0) / cell))
            wooded.update((ci + di, cj + dj) for di in (-1, 0, 1) for dj in (-1, 0, 1))

    # --- Tarkka maasto AREA:lle. -------------------------------------------------------------------------------
    corridor = []  # tiivistetyn tien ajorata ja pientareet, joihin 1:1-maasto liitetään: (i, j, korkeusero)
    for j in range(aj0, aj1 + 1):
        for i in range(ai0, ai1 + 1):
            p = (x0 + i * cell, z0 + j * cell)
            if in_box(p, CORRIDOR) and not gen[(j - aj0) * anx + i - ai0] and codes[j * nx + i] in (ROAD, SHOULDER):
                corridor.append((i, j, max(-4.0, min(4.0, heights[j * nx + i] - dem.at(*p)))))
    # Lähin käytävän ruutu (monilähteinen leveyshaku ruudukossa, riittää liitokseen).
    near = {}
    front = []
    for i, j, dh in corridor:
        near[(i, j)] = (i, j, dh)
        front.append((i, j))
    reach = int(CORRIDOR_BLEND / cell) + 1
    for _step in range(reach):
        nxt = []
        for i, j in front:
            src = near[(i, j)]
            for di, dj in ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1)):
                q = (i + di, j + dj)
                if not (ai0 <= q[0] <= ai1 and aj0 <= q[1] <= aj1):
                    continue
                old = near.get(q)
                if old is None or (q[0] - src[0]) ** 2 + (q[1] - src[1]) ** 2 < (q[0] - old[0]) ** 2 + (q[1] - old[1]) ** 2:
                    near[q] = src
                    nxt.append(q)
        front = nxt
    made = recoded = 0
    for j in range(aj0, aj1 + 1):
        for i in range(ai0, ai1 + 1):
            k = j * nx + i
            p = (x0 + i * cell, z0 + j * cell)
            is_gen = gen[(j - aj0) * anx + i - ai0]
            if not is_gen and ((in_box(p, CORRIDOR) and codes[k] != WATER) or codes[k] in (ROAD, SHOULDER, RAIL)):
                continue  # tiivistetyn tien käytävä ja leivotut tiet ennallaan
            # Käytävän vedet ovat tiivistetyn tien kuvauksesta (todellisuudessa muualla): nekin 1:1-maastoksi.
            regen = is_gen or in_box(p, REMAP) or in_box(p, CORRIDOR)
            h = dem.at(*p)
            if wet(p):
                code, h = WATER, wl - 1.2
            else:
                src = near.get((i, j))
                if src is not None and regen:
                    e = math.hypot(i - src[0], j - src[1]) * cell
                    h += src[2] * (1.0 - smooth(0.0, CORRIDOR_BLEND, e))
                h = max(h, wl + 0.1)
                if in_plot(p) or line_dist(p, lane) < 6.0 or (regen and inside_fence(p)):
                    code = YARD  # tontti, tienvarsi ja aidan sisäpuoli nurmella
                elif regen:
                    code = FOREST if (i, j) in wooded else FIELD
                elif codes[k] == WATER:
                    code = FOREST  # leivottu joen uoma (keskiviivan ympärillä) kuivalla maalla
                else:
                    code, h = codes[k], heights[k]
                if line_dist(p, lane) < 11.0:
                    # Tien alla tasainen, sivuilla liitos maastoon (säilytetyillä leivotuilla ruuduilla korkeusmallin
                    # kautta, jotta ajo on toistettavissa).
                    ld, lh = lane_at(p)
                    h = lerp(lh - 0.05, h if regen else max(dem.at(*p), wl + 0.1), smooth(6.5, 11.0, ld))
            if regen:
                made += 1
            elif code != codes[k] or abs(h - heights[k]) > 0.01:
                recoded += 1
            codes[k] = code
            heights[k] = round(h, 3)

    # --- Kaukomaasto: tarkan alle, järvi pohjaksi. -----------------------------------------------------------
    lake = []
    for j in range(fnz):
        for i in range(fnx):
            q = j * fnx + i
            x, z = fx0 + i * fcell, fz0 + j * fcell
            ci, cj = int((x - x0) / cell), int((z - z0) / cell)
            if in_box((x, z), AREA) and 0 <= ci < nx and 0 <= cj < nz:
                far[q] = round(heights[cj * nx + ci] - 1.5, 2)
                continue
            if 0 <= ci < nx and 0 <= cj < nz and codes[cj * nx + ci] != OUTSIDE:
                continue  # muu tarkka alue: leivonnan mukaan
            v = far_orig[q]
            flat = sum(1 for di in (-1, 0, 1) for dj in (-1, 0, 1) if (di or dj) and 0 <= i + di < fnx and 0 <= j + dj < fnz
                       and abs(far_orig[q + dj * fnx + di] - v) < 0.03)
            if flat < 4:
                continue
            if abs(v - wl) < 0.08 or (in_box((x, z), LAKE_REL) and wl - 0.5 < v < wl + 3.5):
                lake.append(q)
    # Järven reunat ja saarekkeet: tasaisuusehdon ulkopuolelle jääneet vedenpinnan ruudut järveen naapureiden mukaan.
    lake_set = set(lake)
    for _round in range(3):
        add = []
        for j in range(1, fnz - 1):
            for i in range(1, fnx - 1):
                q = j * fnx + i
                x, z = fx0 + i * fcell, fz0 + j * fcell
                ci, cj = int((x - x0) / cell), int((z - z0) / cell)
                if q in lake_set or in_box((x, z), AREA) or (0 <= ci < nx and 0 <= cj < nz and codes[cj * nx + ci] != OUTSIDE):
                    continue
                v = far_orig[q]
                if not (wl - 0.5 < v < wl + (3.5 if in_box((x, z), LAKE_REL) else 0.5)):
                    continue
                if sum(1 for di in (-1, 0, 1) for dj in (-1, 0, 1) if q + dj * fnx + di in lake_set) >= 5:
                    add.append(q)
        lake += add
        lake_set.update(add)
    for q in lake:
        far[q] = round(wl - 2.0, 2)
    for j in range(nz):
        for i in range(nx):
            k = j * nx + i
            if codes[k] == OUTSIDE:
                heights[k] = round(far_h(x0 + i * cell, z0 + j * cell), 3)
    low = sum(1 for q in range(fnx * fnz) if far[q] < wl - 1.9 and q not in lake_set)
    tie["lava_area"] = {"area": list(AREA), "gen": rle(gen),
                        "far_orig": [[q, far_orig[q]] for q in range(fnx * fnz) if far[q] != far_orig[q]]}
    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(struct.pack("<iifff", fnx, fnz, fx0, fz0, fcell))
        f.write(struct.pack("<%df" % (fnx * fnz), *far))

    # Maan korkeus kuten vaala.gd:n h(): tarkka ruudukko kolmioittain, sen ulkopuolella kaukomaasto.
    def ground(x, z):
        fx, fz = (x - x0) / cell, (z - z0) / cell
        if fx < 0.0 or fz < 0.0 or fx > nx - 1 or fz > nz - 1:
            return far_h(x, z)
        i, j = min(int(fx), nx - 2), min(int(fz), nz - 2)
        u, v = fx - i, fz - j
        q = j * nx + i
        if u + v <= 1.0:
            return heights[q] + (heights[q + 1] - heights[q]) * u + (heights[q + nx] - heights[q]) * v
        return heights[q + nx + 1] + (heights[q + nx] - heights[q + nx + 1]) * (1.0 - u) \
            + (heights[q + 1] - heights[q + nx + 1]) * (1.0 - v)

    def code_at(x, z):
        i, j = int(round((x - x0) / cell)), int(round((z - z0) / cell))
        return codes[j * nx + i] if 0 <= i < nx and 0 <= j < nz else OUTSIDE

    # --- Puut pois (drop, kaukomaastossa järvestä); muut AREA:lla ja järven rannoilla uuden maan korkeudelle. ----
    removed = moved = 0
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0:
            continue
        fi, fj = int(round((x - fx0) / fcell)), int(round((z - fz0) / fcell))
        in_lake = any((fj + dj) * fnx + fi + di in lake_set for di in (-1, 0, 1) for dj in (-1, 0, 1))
        if not in_box((x, z), AREA, 8.0) and not in_lake:
            continue
        cd = code_at(x, z)
        gy = ground(x, z)
        if (drop(x, z) if in_box((x, z), AREA, 8.0) else cd == WATER or gy < wl + 0.15) \
                or (cd == OUTSIDE and fj * fnx + fi in lake_set):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif abs(gy - y) > 0.01:
            struct.pack_into("<f", buf, q + 4, gy)
            moved += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("Oulujärven lava", {k: v for k, v in tie["lava"].items() if k != "fence"},
          "| aita %.0f m" % sum(math.dist(a, b) for a, b in zip(fence, fence[1:])),
          "| Pahalahdentie %.0f m" % sum(math.dist(a, b) for a, b in zip(road, road[1:])),
          "| tarkkoja ruutuja uusia %d, muutettuja %d" % (made, recoded), "| järviruutuja", len(lake), "(muita matalia %d)" % low,
          "| puita pois %d, korkeus uuteen maahan %d" % (removed, moved))


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--cache", help="MML:n aineiston välimuisti (vain, jos reitti.json:ssa ei ole vielä lava_dem)")
    apply(ap.parse_args().cache)
