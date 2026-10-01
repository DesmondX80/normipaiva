#!/usr/bin/env python3
"""Mopomatkan pelimaailma assets/vaala/reitti.json -datasta: tiivistetty tie, maasto ja kohteet.

Ajo: venv/bin/python tools/vaala_bake.py --cache <välimuisti>   (riippuvuudet tools/kartta/requirements.txt)
Tulos: assets/vaala/tie.json (tie, kyltit, rakennukset, sivutiet, rata, vedet), assets/vaala/maasto.bin
(korkeusruudukko 4 m ja maankäyttö; kaukomaasto 32 m) ja assets/vaala/puut.bin (metsä, scripts/forest.gd).

Tarkka aineisto (tools/kartta/vaala_tarkka.py): korkeudet MML:n 2 m korkeusmallista (tie, sivut, keskusta ja
kaukomaasto), pellot, suot ja vedet maastotietokannasta, keskustan ulkopuoliset rakennukset maastotietokannasta,
rakennusten harjakorkeudet ja puut MML:n laserkeilauksesta 2011, puulajit Luken VMI 2023:sta. Reitin linja,
tiennimet ja päällysteet sekä keskustan rakennusten nimet ja tyypit OpenStreetMapista (reitti.json).

Tiivistys: mökin pihasta Neittäväntien risteyksen yli (S_A) ja radan alikulusta Siitariin (S_B ->, koko Vaalan
keskusta Oulujoen siltoineen) mittakaava on 1:1, välissä matka lyhenee K-kertaisesti. Jokainen tien pala lyhenee samassa suhteessa, joten
suunnat ja risteysten kulmat säilyvät ja keskusta osuu tarkasti oikeaan kohtaan (vain siirrettynä).
Pelin koordinaatit: mökin osoitepiste origossa kuten reitti.json:ssa (x itään, z etelään), korkeus metreinä mpy.
Kohteet tien varrelta siirretään tien mukana: todellinen paikka -> lähin tien kohta (matka s, sivuetäisyys d)
-> pelissä sama d samasta tien kohdasta.
"""
import argparse
import json
import math
import os
import struct
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), "kartta"))
import numpy as np  # noqa: E402
import tarkka as T  # noqa: E402
import vaala_tarkka as VT  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_lava as VL  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "vaala", "reitti.json")
OUT_JSON = os.path.join(ROOT, "assets", "vaala", "tie.json")
OUT_BIN = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
OUT_TREES = os.path.join(ROOT, "assets", "vaala", "puut.bin")

K = 22.0           # tiivistyskerroin välimatkalla
STEP = 2.0         # tien näytteiden väli pelissä (m)
CELL = 4.0         # tarkka maasto
NEAR = 150.0       # tarkka maasto tien ympärillä
TOWN_R = 480.0     # keskustan tarkka alue Siitarista (kaikki rakennukset, kadut ja rata)
RAIL_1TO1 = 150.0  # 1:1 alkaa näin paljon ennen radan alikulkua (Vuolijoentie radan ali juuri ennen Oulujokea)
UNDER_CLEAR = 4.6  # alikulun vapaa korkeus tien pinnasta ratasillan alapintaan
UNDER_DIP = 1.3    # tie painuu alikulussa
BRANCH_LEN = 90.0  # risteysten haarat väärään suuntaan: näin pitkä pätkä, sitten umpitie
FAR_CELL = 32.0
FAR_TREES = 650.0  # kaukomaaston metsä (laserin valtapuut) näin kauas todellisesta tiestä
FAR_MARGIN = 700.0
SIDE_D = 60.0      # sivukorkeuksien etäisyys tiestä (reitti.json "side")

# Maankäyttökoodit (maasto.bin): 0 metsä, 1 pelto, 2 suo, 3 vesi, 4 piha/nurmi, 5 piennar/sora, 6 tie, 7 rata.
FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


def chaikin(pts, it=3):
    for _ in range(it):
        out = [pts[0]]
        for a, b in zip(pts, pts[1:]):
            out.append((a[0] * 0.75 + b[0] * 0.25, a[1] * 0.75 + b[1] * 0.25))
            out.append((a[0] * 0.25 + b[0] * 0.75, a[1] * 0.25 + b[1] * 0.75))
        out.append(pts[-1])
        pts = out
    return pts


def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = math.dist(a, b)
        while d > 1e-9 and acc + d >= step:
            t = (step - acc) / d
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            d = math.dist(a, b)
            acc = 0.0
            out.append(a)
        acc += d
    if math.dist(out[-1], pts[-1]) > 0.3:
        out.append(pts[-1])
    return out


def pip(p, poly, bb):
    if not (bb[0] <= p[0] <= bb[2] and bb[1] <= p[1] <= bb[3]):
        return False
    x, y = p
    ins = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            ins = not ins
        j = i
    return ins


def bbox(pts, grow=0.0):
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    return (min(xs) - grow, min(zs) - grow, max(xs) + grow, max(zs) + grow)


def seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / L2))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t), t


class Grid:
    """Pistehaku: lähin näyte ruudukosta."""

    def __init__(self, pts, cell):
        self.cell = cell
        self.pts = pts
        self.g = {}
        for i, p in enumerate(pts):
            self.g.setdefault((int(p[0] // cell), int(p[1] // cell)), []).append(i)

    def nearest(self, p, rmax):
        c = self.cell
        ci, cj = int(p[0] // c), int(p[1] // c)
        best, bi = rmax, -1
        r = int(math.ceil(rmax / c))
        for dj in range(-r, r + 1):
            for di in range(-r, r + 1):
                for i in self.g.get((ci + di, cj + dj), ()):
                    q = self.pts[i]
                    d = math.hypot(p[0] - q[0], p[1] - q[1])
                    if d < best:
                        best, bi = d, i
        return bi, best


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--cache", required=True, help="MML:n ja Luken lähdeaineiston välimuisti")
    args = ap.parse_args()
    d = json.load(open(SRC))
    fd, laser = VT.refine(d, args.cache, TOWN_R)
    feats = d["features"]
    sx, sz = d["siitari"]
    steps = d["steps"]

    # --- Todellinen reitti: pehmennetään mutkat, risteysten kärjet pysyvät paikallaan. ----------------------------
    route = [tuple(p) for p in d["route"]]
    fixed = set()
    for st in steps[1:-1]:
        at = tuple(st["at"])
        fixed.add(min(range(len(route)), key=lambda i: math.dist(route[i], at)))
    fixed = sorted(fixed | {0, len(route) - 1})
    real = []
    for a, b in zip(fixed, fixed[1:]):
        part = chaikin(route[a:b + 1], 3)
        real += part if not real else part[1:]
    real = resample(real, 1.0)
    rs = [0.0]
    for a, b in zip(real, real[1:]):
        rs.append(rs[-1] + math.dist(a, b))
    total = rs[-1]

    def arc_at(p):
        return rs[min(range(len(real)), key=lambda i: math.dist(real[i], p))]

    s_neitt = arc_at(steps[2]["at"])       # käännös Neittäväntielle
    s_vaala = arc_at(steps[4]["at"])       # Vuolijoentie päättyy Vaalantiehen
    S_A = s_neitt + 60.0
    # Rata ylittää Vuolijoentien sillalla: reitin ja ratojen leikkauskohta (todellinen matka).
    rail_feats = [f for f in feats if f["kind"] == "rail"]

    def cross_t(p1, p2, p3, p4):
        den = (p2[0] - p1[0]) * (p4[1] - p3[1]) - (p2[1] - p1[1]) * (p4[0] - p3[0])
        if den == 0:
            return None
        t = ((p3[0] - p1[0]) * (p4[1] - p3[1]) - (p3[1] - p1[1]) * (p4[0] - p3[0])) / den
        u = ((p3[0] - p1[0]) * (p2[1] - p1[1]) - (p3[1] - p1[1]) * (p2[0] - p1[0])) / den
        return t if 0 <= t <= 1 and 0 <= u <= 1 else None

    rail_cross = []  # [(s, todellinen piste, radan suunta)]
    for f in rail_feats:
        for a, b in zip(f["pts"], f["pts"][1:]):
            for i in range(len(real) - 1):
                t = cross_t(real[i], real[i + 1], a, b)
                if t is not None:
                    L = math.dist(a, b) or 1.0
                    rail_cross.append((rs[i] + t * math.dist(real[i], real[i + 1]),
                                       (lerp(real[i][0], real[i + 1][0], t), lerp(real[i][1], real[i + 1][1], t)),
                                       ((b[0] - a[0]) / L, (b[1] - a[1]) / L)))
    rail_cross.sort()
    print("rata ylittää reitin", [(round(c[0]), [round(v) for v in c[1]]) for c in rail_cross])
    S_B = (rail_cross[0][0] if rail_cross else total - 260.0) - RAIL_1TO1
    # Oulujoen silta 1:1 (uoma ei kapene): reitin kohdat joen keskiviivan lähellä.
    rivers = [f for f in feats if f["kind"] == "river"]
    RIVER_HALF = 30.0
    oulu = [(a, b) for f in rivers if f.get("name") == "Oulujoki" for a, b in zip(f["pts"], f["pts"][1:])
            if math.dist(a, (sx, sz)) < 1500.0]

    def in_river(rp, grow=0.0):
        return any(seg_dist(rp, a, b)[0] < RIVER_HALF + grow for a, b in oulu)

    wet = [rs[i] for i in range(0, len(real), 2) if in_river(real[i], 6.0)]
    B_LO, B_HI = (min(wet) - 45.0, max(wet) + 45.0) if wet else (-1.0, -1.0)
    B_LO = min(B_LO, S_B)
    WINDOWS = [(0.0, S_A), (S_B, total + 1.0)]

    def scale(s):
        return 1.0 if any(a <= s <= b for a, b in WINDOWS) else 1.0 / K

    # --- Korkeudet: tien keskilinja (20 m) ja sivut (60 m, 100 m välein). ----------------------------------------
    line = d["line"]
    lg = Grid([(p[0], p[1]) for p in line], 40.0)
    lh = [p[2] for p in line]
    ls = [0.0]
    for a, b in zip(line, line[1:]):
        ls.append(ls[-1] + math.dist(a[:2], b[:2]))

    def h_real_s(s):
        # keskilinjan korkeus todellisella matkalla s (line-näytteet ovat 20 m välein alusta)
        k = s / 20.0
        i = min(int(k), len(lh) - 2)
        return lerp(lh[i], lh[i + 1], min(max(k - i, 0.0), 1.0))

    def h_game_s(s):
        h = h_real_s(s)
        if scale(s) == 1.0:
            return h
        # Tiivistetyllä välillä mäet loivemmiksi (muuten jyrkkyys K-kertainen): pohja 1:1-ikkunoiden reunoilta.
        lo = max(b for a, b in WINDOWS if b <= s)
        hi = min(a for a, b in WINDOWS if a >= s)
        base = lerp(h_real_s(lo), h_real_s(hi), (s - lo) / max(hi - lo, 1.0))
        return base + (h - base) * 0.25

    side = d["side"]
    sg = Grid([(p[0], p[1]) for p in side], 60.0)

    # --- Pelin tie: todellinen askel skaalataan, suunta säilyy. ---------------------------------------------------
    game = [real[0]]
    for i in range(1, len(real)):
        k = scale(rs[i - 1])
        a, b = real[i - 1], real[i]
        game.append((game[-1][0] + (b[0] - a[0]) * k, game[-1][1] + (b[1] - a[1]) * k))
    gs = [0.0]
    for a, b in zip(game, game[1:]):
        gs.append(gs[-1] + math.dist(a, b))
    town_off = (game[-1][0] - real[-1][0], game[-1][1] - real[-1][1])
    print("todellinen %.0f m -> pelissä %.0f m, S_A %.0f S_B %.0f, keskustan siirto %.1f %.1f" % (
        total, gs[-1], S_A, S_B, town_off[0], town_off[1]))

    # Pelin näytteet STEP m välein: paikka, todellinen matka s, todellinen paikka.
    samples = []
    j = 0
    g = 0.0
    while g <= gs[-1]:
        while j < len(gs) - 2 and gs[j + 1] < g:
            j += 1
        t = 0.0 if gs[j + 1] == gs[j] else (g - gs[j]) / (gs[j + 1] - gs[j])
        gp = (lerp(game[j][0], game[j + 1][0], t), lerp(game[j][1], game[j + 1][1], t))
        s = lerp(rs[j], rs[j + 1], t)
        rp = (lerp(real[j][0], real[j + 1][0], t), lerp(real[j][1], real[j + 1][1], t))
        samples.append({"g": gp, "s": s, "r": rp, "c": scale(s)})
        g += STEP
    n = len(samples)
    for i, smp in enumerate(samples):
        a = samples[max(i - 1, 0)]["g"]
        b = samples[min(i + 1, n - 1)]["g"]
        L = math.dist(a, b) or 1.0
        smp["dir"] = ((b[0] - a[0]) / L, (b[1] - a[1]) / L)
        ra = samples[max(i - 1, 0)]["r"]
        rb = samples[min(i + 1, n - 1)]["r"]
        L = math.dist(ra, rb) or 1.0
        smp["rdir"] = ((rb[0] - ra[0]) / L, (rb[1] - ra[1]) / L)

    # Tien nimi, luokka ja pinta lähimmästä OSM-tiestä; Oulujoen silta.
    roads = [f for f in feats if f["kind"] == "road"]
    named = {"Uutelanperäntie": ("gravel", 2.6), "Neittäväntie": ("asphalt", 3.1), "Vuolijoentie": ("asphalt", 3.6),
             "Vaalantie": ("asphalt", 3.6)}
    waters = [(f, bbox(f["pts"])) for f in feats if f["kind"] == "water"]
    for smp in samples:
        r = smp["r"]
        best, bn = 12.0, ""
        for f in roads:
            if f.get("name") not in named:
                continue
            bb = bbox(f["pts"], 12.0)
            if not (bb[0] <= r[0] <= bb[2] and bb[1] <= r[1] <= bb[3]):
                continue
            for a, b in zip(f["pts"], f["pts"][1:]):
                dd, _ = seg_dist(r, a, b)
                if dd < best:
                    best, bn = dd, f["name"]
        if not bn:
            bn = "Kaisuantie" if smp["s"] < 70 else ("Vaalantie" if smp["s"] > S_B else "")
        smp["name"] = bn
        surf, hw = named.get(bn, ("gravel", 2.2))
        smp["surf"], smp["hw"] = surf, hw
        smp["bridge"] = any(pip(r, f["pts"], bb) for f, bb in waters)
    # Oulujoki keskustassa: OSM:ssä vain keskiviiva, joten uoma RIVER_HALF m sen molemmin puolin; silta yli.
    for smp in samples:
        if in_river(smp["r"], 6.0):
            smp["bridge"] = True
    # Nimettömät pätkät saavat edellisen nimen.
    last = "Kaisuantie"
    for smp in samples:
        if smp["name"]:
            last = smp["name"]
        else:
            smp["name"] = last
            smp["surf"], smp["hw"] = named.get(last, ("gravel", 2.2))

    # Sillan kohdalla tie kulkee suoraan rannalta rannalle (korkeusmalli painuu vedenpintaan).
    for smp in samples:
        smp["y"] = h_game_s(smp["s"])
    # Radan alikulku: tie painuu ratasillan kohdalla, kansi UNDER_CLEAR m tien yläpuolella.
    underpass = None
    if rail_cross:
        cs_, cp_, cd_ = rail_cross[0]
        ci = min(range(n), key=lambda i: abs(samples[i]["s"] - cs_))
        y0 = samples[ci]["y"]
        for smp in samples:
            e = abs(smp["s"] - cs_)
            smp["y"] -= UNDER_DIP * (1.0 - smooth(10.0, 55.0, e))
        underpass = {"i": ci, "real": cp_, "rdir": cd_, "deck": y0 - UNDER_DIP + UNDER_CLEAR + 0.9}
    flags = [smp["bridge"] for smp in samples]
    i = 0
    bridges = []
    while i < n:
        if flags[i]:
            a = i
            while i < n and flags[i]:
                i += 1
            a0, b0 = max(a - 4, 0), min(i - 1 + 4, n - 1)
            bridges.append([a0, b0])
        else:
            i += 1
    for a0, b0 in bridges:
        ya, yb = samples[a0]["y"], samples[b0]["y"]
        for k in range(a0, b0 + 1):
            # Kansi 0,6 m tien yläpuolelle loivasti päistä (4 näytettä = 8 m): ei porrasta, johon mopo töksähtää.
            ramp = smooth(0.0, 4.0, min(k - a0, b0 - k))
            samples[k]["y"] = lerp(ya, yb, (k - a0) / max(b0 - a0, 1)) + 0.6 * ramp
            samples[k]["bridge"] = True
    print("sillat", bridges)

    # --- Todellinen paikka -> pelin paikka tien suhteen. ---------------------------------------------------------
    rgrid = Grid([smp["r"] for smp in samples], 20.0)
    ggrid = Grid([smp["g"] for smp in samples], 20.0)

    real_town = (sx, sz)

    def to_game(p, rmax=NEAR + 60.0):
        """Todellinen piste pelin kehykseen lähimmän tien kohdan mukaan (tien suunnassa näytteen mittakaava,
        sivusuunnassa 1:1), None jos kaukana tiestä. Keskusta on kokonaan 1:1: pelkkä siirto."""
        if math.dist(p, real_town) < TOWN_R:
            return (p[0] + town_off[0], p[1] + town_off[1])
        i, dist = rgrid.nearest(p, rmax)
        if i < 0:
            return None
        smp = samples[i]
        rd = smp["rdir"]
        dx, dz = p[0] - smp["r"][0], p[1] - smp["r"][1]
        along = dx * rd[0] + dz * rd[1] * 1.0
        lat = -dx * rd[1] + dz * rd[0]
        gd = smp["dir"]
        c = smp["c"]
        return (smp["g"][0] + gd[0] * along * c - gd[1] * lat, smp["g"][1] + gd[1] * along * c + gd[0] * lat)

    def to_real(p):
        """Pelin piste todelliseksi (maankäytön haku). Palauttaa (piste, lähin näyte, etäisyys tiestä, puoli)."""
        if math.dist(p, (sx + town_off[0], sz + town_off[1])) < TOWN_R + 20.0:
            i, dist = ggrid.nearest(p, 2000.0)
            return (p[0] - town_off[0], p[1] - town_off[1]), i, dist, 0.0
        i, dist = ggrid.nearest(p, 400.0)
        smp = samples[i]
        gd = smp["dir"]
        dx, dz = p[0] - smp["g"][0], p[1] - smp["g"][1]
        lat = -dx * gd[1] + dz * gd[0]
        along = dx * gd[0] + dz * gd[1]
        rd = smp["rdir"]
        c = smp["c"]
        rp = (smp["r"][0] + rd[0] * along / c - rd[1] * lat, smp["r"][1] + rd[1] * along / c + rd[0] * lat)
        return rp, i, dist, lat

    # --- Kohteet peliin. -------------------------------------------------------------------------------------
    rr = Grid(real[::2], 20.0)  # tiheä todellinen reitti (näytteet ovat tiivistetyllä välillä harvassa)

    def on_route(p):
        return rr.nearest(p, 6.0)[0] >= 0

    # Tiivistetyllä välillä ennen Oulujoen siltaa K-kertainen matka pakkautuisi lyhyelle pätkälle ja talot
    # kasautuisivat toistensa päälle: sinne vain isoimmat talot vähintään THIN_GAP m välein, ei vajoja.
    THIN_GAP = 45.0
    kept = []
    out_buildings = []
    def b_area(f):
        q = f["pts"]
        return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(q, q[1:] + q[:1]))) / 2.0
    for f in sorted((f for f in feats if f["kind"] == "building"), key=lambda f: -b_area(f)):
        pts = f["pts"][:-1] if f["pts"][0] == f["pts"][-1] else f["pts"]
        c = (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
        gc = to_game(c)
        if gc is None:
            continue
        ri, _ = rgrid.nearest(c, NEAR + 60.0)
        if ri >= 0 and samples[ri]["c"] < 1.0 and samples[ri]["s"] < B_LO:
            if b_area(f) < 60.0 or any(math.dist(gc, q) < THIN_GAP for q in kept):
                continue
            kept.append(gc)
        off = (gc[0] - c[0], gc[1] - c[1])
        bt = f.get("building", "yes")
        area = abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2.0
        lv = f.get("building_levels")
        levels = int(float(lv)) if lv else (2 if bt in ("apartments", "hotel", "commercial", "school") else 1)
        if bt in ("garage", "shed", "barn", "sauna", "hut", "cabin", "garages") or area < 30.0:
            kind = "shed"
        elif bt in ("house", "detached", "residential", "semidetached_house", "farm") or (bt == "yes" and area < 220):
            kind = "house"
        else:
            kind = "big"
        out_buildings.append({"id": f["id"], "type": bt, "kind": kind, "levels": levels, "h": f.get("height", 0.0),
                              "name": f.get("name", ""), "addr": ("%s %s" % (f.get("addr_street", ""), f.get("addr_housenumber", ""))).strip(),
                              "pts": [[round(q[0] + off[0], 2), round(q[1] + off[1], 2)] for q in pts]})
    # --- Risteysten haarat väärään suuntaan: OSM:n tie risteyksestä BRANCH_LEN m (1:1), sitten umpitie. ------------
    def road_kind(f):
        hw = f.get("highway", "")
        paved = f.get("surface", "") in ("asphalt", "paved") or hw in ("secondary", "tertiary")
        width = 3.1 if hw in ("secondary", "tertiary") else (2.6 if hw in ("unclassified", "residential") else 2.0)
        return ("asphalt" if paved else "gravel"), width

    branches = []
    branch_ways = set()
    for st in steps[1:5]:
        J = tuple(st["at"])
        ji = min(range(n), key=lambda i: math.dist(samples[i]["r"], J))
        gj = samples[ji]["g"]
        yj = None
        for f in roads:
            if f.get("highway") in ("footway", "cycleway", "path", "pedestrian", "track") or len(f["pts"]) < 2:
                continue
            vi = min(range(len(f["pts"])), key=lambda i: math.dist(f["pts"][i], J))
            if math.dist(f["pts"][vi], J) > 15.0:
                continue
            for step_dir in (1, -1):
                pts = [J]
                k = vi
                while 0 <= k + step_dir < len(f["pts"]):
                    k += step_dir
                    pts.append(tuple(f["pts"][k]))
                line = resample(pts, 2.0)
                acc, cut = 0.0, [line[0]]
                for a, b in zip(line, line[1:]):
                    acc += math.dist(a, b)
                    if acc > BRANCH_LEN:
                        break
                    cut.append(b)
                if acc < 20.0 and len(cut) < 10:
                    continue
                probe = cut[min(12, len(cut) - 1)]
                if on_route(probe):
                    continue  # tämä suunta on itse reitti
                if any(math.dist(probe, tuple(q)) < 8.0 for b in branches for q in b["real"]):
                    continue  # sama haara toisesta OSM-pätkästä
                surf, hw = road_kind(f)
                y0 = samples[ji]["y"]
                gp = [(gj[0] + q[0] - J[0], gj[1] + q[1] - J[1]) for q in cut]
                branches.append({"name": f.get("name", ""), "hw": hw, "gravel": 1 if surf == "gravel" else 0, "s": samples[ji]["s"],
                                 "pts": [[round(q[0], 2), round(y0, 2), round(q[1], 2)] for q in gp],
                                 "real": [[round(q[0], 2), round(q[1], 2)] for q in cut]})
                branch_ways.add(f["id"])
    print("haaroja", len(branches), [(b["name"], len(b["pts"])) for b in branches])

    # Talot eivät saa jäädä tien päälle: tiivistetyillä risteyksillä kulman talo osuisi kääntyvälle tielle.
    # Reitin päät (mökin piha, Siitarin piha) ovat omia kohteitaan.
    road_pts = [(smp["g"], smp["hw"], i) for i, smp in enumerate(samples)]
    for b in branches:
        road_pts += [((q[0], q[2]), b["hw"], -1) for q in b["pts"]]
    rp_grid = Grid([q[0] for q in road_pts], 20.0)
    keep = []
    dropped = []
    for bd in out_buildings:
        pts = bd["pts"]
        c = (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
        rad = max(math.dist(c, q) for q in pts) + 6.0
        bb = bbox(pts)
        hit = False
        ci_, cj_ = int(c[0] // 20.0), int(c[1] // 20.0)
        rr_ = int(math.ceil(rad / 20.0))
        for dj in range(-rr_, rr_ + 1):
            for di in range(-rr_, rr_ + 1):
                for qi in rp_grid.g.get((ci_ + di, cj_ + dj), ()):
                    q, hw_, si_ = road_pts[qi]
                    if 0 <= si_ < 10 or si_ > n - 15:
                        continue
                    if math.dist(q, c) > rad:
                        continue
                    edge = min(seg_dist(q, a, b2)[0] for a, b2 in zip(pts, pts[1:] + pts[:1]))
                    if pip(q, pts, bb) or edge < hw_ + 1.2:
                        hit = True
                        break
                if hit:
                    break
            if hit:
                break
        if hit:
            dropped.append((bd["id"], bd["type"], bd["name"]))
        else:
            keep.append(bd)
    out_buildings = keep
    print("tien päältä pois", dropped)

    side_roads = []
    for f in feats:
        if f["kind"] not in ("road", "rail") or f["id"] in branch_ways:
            continue
        hw = f.get("highway", "")
        cur = []
        pts = resample(f["pts"], 6.0)
        for p in pts:
            gp = to_game(p, 130.0)
            if gp is None or (f["kind"] == "road" and on_route(p)):
                if len(cur) > 1:
                    side_roads.append({"kind": f["kind"], "hw": hw, "name": f.get("name", ""), "surface": f.get("surface", ""),
                                       "pts": cur})
                cur = []
                continue
            cur.append([round(gp[0], 2), round(gp[1], 2)])
        if len(cur) > 1:
            side_roads.append({"kind": f["kind"], "hw": hw, "name": f.get("name", ""), "surface": f.get("surface", ""), "pts": cur})
    out_water = []
    parkings = []
    for f in feats:
        if f["kind"] != "parking":
            continue
        gp = [to_game(q) for q in f["pts"]]
        if all(q is not None for q in gp):
            parkings.append([[round(q[0], 2), round(q[1], 2)] for q in gp])

    # --- Maasto: tarkka ruudukko tien ympärillä, kaukomaasto karkeana. --------------------------------------------
    gx = [smp["g"][0] for smp in samples]
    gz = [smp["g"][1] for smp in samples]
    x0 = math.floor((min(gx) - NEAR - 40) / CELL) * CELL
    z0 = math.floor((min(gz) - NEAR - 40) / CELL) * CELL
    x1 = max(max(gx) + NEAR + 40, sx + town_off[0] + TOWN_R + 40)
    z1 = max(max(gz) + NEAR + 40, sz + town_off[1] + TOWN_R + 40)
    x0 = min(x0, math.floor((sx + town_off[0] - TOWN_R - 40) / CELL) * CELL)
    z0 = min(z0, math.floor((sz + town_off[1] - TOWN_R - 40) / CELL) * CELL)
    nx = int((x1 - x0) / CELL) + 1
    nz = int((z1 - z0) / CELL) + 1
    print("ruudukko %d x %d (%.0f x %.0f m)" % (nx, nz, nx * CELL, nz * CELL))
    INF = 1e9
    # Maaston näytteet: reitti ja risteysten haarat (haaran alla tasainen tiepohja kuten reitillä).
    tsamp = list(samples)
    for b in branches:
        for q, rq in zip(b["pts"], b["real"]):
            tsamp.append({"g": (q[0], q[2]), "y": q[1], "hw": b["hw"], "s": b["s"], "r": tuple(rq), "bridge": False})
    near_d = [INF] * (nx * nz)
    near_i = [-1] * (nx * nz)
    rcell = int(NEAR / CELL) + 1
    for si in list(range(0, n, 2)) + list(range(n, len(tsamp))):
        p = tsamp[si]["g"]
        ci = int((p[0] - x0) / CELL)
        cj = int((p[1] - z0) / CELL)
        for j in range(max(cj - rcell, 0), min(cj + rcell + 1, nz)):
            zz = z0 + j * CELL - p[1]
            for i in range(max(ci - rcell, 0), min(ci + rcell + 1, nx)):
                xx = x0 + i * CELL - p[0]
                dd = xx * xx + zz * zz
                k = j * nx + i
                if dd < near_d[k]:
                    near_d[k] = dd
                    near_i[k] = si
    town_c = (sx + town_off[0], sz + town_off[1])
    tdem = d["town_dem"]

    def town_h(rp):
        fx = (rp[0] - tdem["x0"]) / tdem["step"]
        fz = (rp[1] - tdem["z0"]) / tdem["step"]
        nn = tdem["n"]
        if fx < 0 or fz < 0 or fx > nn - 1 or fz > nn - 1:
            return None
        i, j = min(int(fx), nn - 2), min(int(fz), nn - 2)
        u, v = fx - i, fz - j
        vals = tdem["values"]
        return lerp(lerp(vals[j * nn + i], vals[j * nn + i + 1], u), lerp(vals[(j + 1) * nn + i], vals[(j + 1) * nn + i + 1], u), v)

    fields = [(f["pts"], bbox(f["pts"])) for f in feats if f["kind"] == "field"]
    bogs = [(f["pts"], bbox(f["pts"])) for f in feats if f["kind"] == "bog"]
    towns = [(f["pts"], bbox(f["pts"])) for f in feats if f["kind"] == "town"]
    wpolys = [(f["pts"], bbox(f["pts"])) for f in feats if f["kind"] == "water"]
    bgrid = Grid([tuple(map(float, (sum(q[0] for q in b["pts"]) / len(b["pts"]), sum(q[1] for q in b["pts"]) / len(b["pts"]))))
                  for b in out_buildings], 30.0)
    rails = [r for r in side_roads if r["kind"] == "rail"]
    rail_grid = Grid([tuple(q) for r in rails for q in r["pts"]], 20.0) if rails else None
    # Oulujoen pinta korkeusmallista (tasoitettu vedenpinta joen keskiviivalla keskustassa).
    wl = sorted(fd.at(q[0], q[1]) for a, b in oulu for q in (a, b))
    water_level = wl[len(wl) // 2] if wl else min([smp["y"] - 0.6 for smp in samples if smp["bridge"]] or [121.0]) - 3.5
    heights = [0.0] * (nx * nz)
    codes = [0] * (nx * nz)
    for j in range(nz):
        for i in range(nx):
            k = j * nx + i
            p = (x0 + i * CELL, z0 + j * CELL)
            in_town = math.dist(p, town_c) < TOWN_R
            if near_d[k] == INF and not in_town:
                codes[k] = 255  # ei tarkkaa maastoa (täytetään kaukomaastosta)
                continue
            if near_i[k] < 0:
                si, dist = ggrid.nearest(p, 450.0)
            else:
                si, dist = near_i[k], math.sqrt(near_d[k])
            smp = tsamp[si]
            rp, _, _, lat = to_real(p)
            hw = smp["hw"]
            # Luonnollinen maa: keskustassa korkeusmalli, muualla tien korkeus + sivun kallistus.
            ground = None
            if in_town or smp["s"] > S_B:
                ground = town_h(rp)
            if ground is None:
                # Korkeusmalli todellisessa paikassa tien korkeuteen suhteutettuna (tiivistetyllä välillä loivemmin).
                ground = smp["y"] + (fd.at(rp[0], rp[1]) - fd.at(smp["r"][0], smp["r"][1], smooth=1)) \
                    * (1.0 if smp.get("c", 1.0) >= 1.0 else 0.5)
            code = FOREST
            if any(pip(rp, pts, bb) for pts, bb in wpolys) or (smp["s"] > B_LO - 600.0 and in_river(rp)):
                code = WATER
                ground = water_level - 1.2
            elif any(pip(rp, pts, bb) for pts, bb in fields):
                code = FIELD
            elif any(pip(rp, pts, bb) for pts, bb in bogs):
                code = BOG
            elif any(pip(rp, pts, bb) for pts, bb in towns) or bgrid.nearest(p, 16.0)[0] >= 0:
                code = YARD
            if rail_grid is not None and rail_grid.nearest(p, 4.0)[0] >= 0:
                code = RAIL
            # Tie: tasainen piennar, oja ja luiska luonnolliseen maahan.
            y = smp["y"]
            if smp["bridge"]:
                # Rannoilla maa ei saa nousta kannen läpi (kansi törmäyksineen on sillan puolella).
                h = min(ground, y - 0.1) if dist < hw + 3.0 else ground
                if dist < hw + 0.5:
                    code = ROAD
            else:
                ditch = hw + 2.6
                if dist < hw + 0.9:
                    h = y - 0.05
                    code = ROAD if dist < hw else SHOULDER
                elif dist < ditch + 2.0:
                    h = y - 0.05 - 0.55 * math.sin(min((dist - hw - 0.9) / (ditch + 2.0 - hw - 0.9), 1.0) * math.pi) \
                        if not in_town else y - 0.05
                    h = lerp(h, ground, smooth(ditch, ditch + 2.0, dist) * 0.5)
                    if code in (FOREST, BOG):
                        code = FIELD  # ojan pientareet nurmella
                else:
                    h = lerp(y - 0.05, ground, smooth(ditch + 2.0, ditch + 22.0, dist))
            heights[k] = round(h, 3)
            codes[k] = code

    def grid_h(p):
        fx = min(max((p[0] - x0) / CELL, 0.0), nx - 1.001)
        fz = min(max((p[1] - z0) / CELL, 0.0), nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        q = j * nx + i
        return lerp(lerp(heights[q], heights[q + 1], u), lerp(heights[q + nx], heights[q + nx + 1], u), v)

    # Radan alikulku: rata penkereellä, joka nousee kannen korkeuteen tien kohdalla. Penger maastoon luiskineen,
    # tien kohta (ajorata pientareineen) jää auki: siihen ratasilta maatukineen (vaala.gd).
    for r in rails:
        for q in r["pts"]:
            q.append(round(grid_h(q), 2))
    if underpass is not None:
        us = samples[underpass["i"]]
        ug = us["g"]
        underpass["at"] = [round(ug[0], 2), round(ug[1], 2)]
        rd_ = underpass["rdir"]
        # Radan suunta pelissä: keskustan 1:1-alueella sama kuin todellinen.
        underpass["dir"] = [round(rd_[0], 4), round(rd_[1], 4)]
        underpass["road_y"] = round(us["y"], 2)
        underpass["hw"] = us["hw"]
        deck = underpass["deck"]
        near_rail = []
        for r in rails:
            for q in r["pts"]:
                e = math.dist((q[0], q[1]), ug)
                if e < 340.0:
                    top = lerp(q[2], deck, 1.0 - smooth(40.0, 320.0, e))
                    q[2] = round(max(q[2], top), 2)
            # Tiheä (1 m) viiva penkereen laskentaan.
            for a, b in zip(r["pts"], r["pts"][1:]):
                if math.dist((a[0], a[1]), ug) > 350.0 and math.dist((b[0], b[1]), ug) > 350.0:
                    continue
                m = max(int(math.dist((a[0], a[1]), (b[0], b[1]))), 1)
                for t in range(m):
                    near_rail.append([lerp(a[0], b[0], t / m), lerp(a[1], b[1], t / m), lerp(a[2], b[2], t / m)])
        ng = Grid([(q[0], q[1]) for q in near_rail], 12.0)
        # Alikulun aukko: ajorata, piennar ja yksi ruutu varaa (4 m ruudukon kolmiot eivät saa nousta ajoradan päälle).
        # Maatuet (vaala.gd) peittävät aukon reunat.
        span = us["hw"] + 6.0
        for j in range(nz):
            for i in range(nx):
                k = j * nx + i
                p = (x0 + i * CELL, z0 + j * CELL)
                if codes[k] == 255 or math.dist(p, ug) > 360.0:
                    continue
                qi, dr = ng.nearest(p, 16.0)
                if qi < 0:
                    continue
                top = near_rail[qi][2] - 0.1
                # Alikulun aukko: ajoradan kohta pysyy tien tasossa.
                rdist = math.sqrt(near_d[k]) if near_d[k] < INF else 1e9
                if rdist < span:
                    continue
                emb = top - max(0.0, dr - 2.8) * 0.75
                if emb > heights[k]:
                    heights[k] = round(emb, 3)
                    if dr < 2.8:
                        codes[k] = RAIL
                    elif codes[k] in (ROAD, SHOULDER, YARD, FOREST):
                        codes[k] = FIELD  # penkereen luiskat nurmella
        print("alikulku", underpass)
    # Kaukomaasto: karkea ruudukko koko alueelle, korkeus lähimmän tien kohdan mukaan (näytteet 40 m välein).
    fx0 = x0 - FAR_MARGIN
    fz0 = z0 - FAR_MARGIN
    fnx = int((x0 + nx * CELL + FAR_MARGIN - fx0) / FAR_CELL) + 1
    fnz = int((z0 + nz * CELL + FAR_MARGIN - fz0) / FAR_CELL) + 1
    coarse = Grid([samples[i]["g"] for i in range(0, n, 20)], 80.0)
    far = []
    for j in range(fnz):
        for i in range(fnx):
            p = (fx0 + i * FAR_CELL, fz0 + j * FAR_CELL)
            ci, _ = coarse.nearest(p, 4000.0)
            smp = samples[ci * 20]
            if math.dist(p, town_c) < TOWN_R + 300.0:
                far.append(round(fd.at(p[0] - town_off[0], p[1] - town_off[1]), 2))
                continue
            # Kaukomaasto korkeusmallista: todellinen paikka tien suhteen (sivusuunta 1:1).
            gd = smp["dir"]
            dx, dz = p[0] - smp["g"][0], p[1] - smp["g"][1]
            lat = -dx * gd[1] + dz * gd[0]
            along = dx * gd[0] + dz * gd[1]
            rd = smp["rdir"]
            rp = (smp["r"][0] + rd[0] * along / smp["c"] - rd[1] * lat, smp["r"][1] + rd[1] * along / smp["c"] + rd[0] * lat)
            far.append(round(smp["y"] + (fd.at(rp[0], rp[1]) - fd.at(smp["r"][0], smp["r"][1], smooth=1))
                             * (1.0 if smp["c"] >= 1.0 else 0.5), 2))

    def far_h(x, z):
        fx = (x - fx0) / FAR_CELL
        fz = (z - fz0) / FAR_CELL
        i, j = min(max(int(fx), 0), fnx - 2), min(max(int(fz), 0), fnz - 2)
        u, v = min(max(fx - i, 0), 1), min(max(fz - j, 0), 1)
        return lerp(lerp(far[j * fnx + i], far[j * fnx + i + 1], u), lerp(far[(j + 1) * fnx + i], far[(j + 1) * fnx + i + 1], u), v)

    for j in range(nz):
        for i in range(nx):
            k = j * nx + i
            if codes[k] == 255:
                heights[k] = round(far_h(x0 + i * CELL, z0 + j * CELL), 3)
    # Tarkan alueen reunoilla kaukomaasto seuraa tarkkaa (ettei rako näy).
    for j in range(fnz):
        for i in range(fnx):
            x, z = fx0 + i * FAR_CELL, fz0 + j * FAR_CELL
            ci, cj = int((x - x0) / CELL), int((z - z0) / CELL)
            if 0 <= ci < nx and 0 <= cj < nz and codes[cj * nx + ci] != 255:
                far[j * fnx + i] = round(heights[cj * nx + ci] - 1.5, 2)

    with open(OUT_BIN, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, CELL))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(struct.pack("<iifff", fnx, fnz, fx0, fz0, FAR_CELL))
        f.write(struct.pack("<%df" % (fnx * fnz), *far))

    # --- Metsä: laserpuut tien suhteen pelin kehykseen (vaala_tarkka.trees). -----------------------------------
    def code_at(x, z):
        i, j = int(round((x - x0) / CELL)), int(round((z - z0) / CELL))
        if i < 0 or j < 0 or i >= nx or j >= nz:
            return 255
        return codes[j * nx + i]

    def c_at(p):
        if math.dist(p, real_town) < TOWN_R:
            return 1.0
        i, _ = rgrid.nearest(p, NEAR + 60.0)
        return samples[i]["c"] if i >= 0 else 1.0

    rng = np.random.default_rng(1170)
    tx, ty, tz, th, tsp = VT.trees(args.cache, laser, fd, real, to_game,
                                   code_at,
                                   lambda x, z: grid_h((x, z)), c_at, rng, NEAR + 60.0, FAR_TREES, far_h)
    T.write_trees(OUT_TREES, tx, ty, tz, th, tsp, rng)

    # --- Kyltit: risteykset ja kilometrit Vaalaan (todellinen matka). --------------------------------------------
    def sample_at_real(s):
        return min(range(n), key=lambda i: abs(samples[i]["s"] - s))

    signs = []
    for st in steps[1:5]:
        si = sample_at_real(arc_at(st["at"]))
        signs.append({"i": si, "text": st["name"], "kind": "street"})
    for km in range(1, int(total / 1000) + 1):
        left = int(round((total - km * 1000) / 1000))
        if left >= 1:
            signs.append({"i": sample_at_real(km * 1000.0), "text": "Vaala %d" % left, "kind": "km"})
    sgn = min(range(n), key=lambda i: math.dist(samples[i]["r"], (7300, -5560)))
    signs.append({"i": sgn, "text": "Oulujoki", "kind": "river"})

    out = {
        "source": d["source"] + " Leivottu: tools/vaala_bake.py (tiivistys K=%.0f)." % K,
        "k": K, "s_a": round(S_A, 1), "s_b": round(S_B, 1), "real_total": round(total, 1), "step": STEP,
        "town_off": [round(town_off[0], 2), round(town_off[1], 2)],
        "siitari": [round(sx + town_off[0], 2), round(sz + town_off[1], 2)], "water_level": round(water_level, 2),
        "names": sorted({smp["name"] for smp in samples}),
        "road": [[round(smp["g"][0], 2), round(smp["y"], 2), round(smp["g"][1], 2), round(smp["s"], 1),
                  smp["hw"], 1 if smp["surf"] == "gravel" else 0, 1 if smp["bridge"] else 0] for smp in samples],
        "road_names": [smp["name"] for smp in samples],
        "bridges": bridges, "signs": signs, "branches": [{k2: v for k2, v in b.items() if k2 != "real"} for b in branches], "buildings": out_buildings, "side_roads": side_roads,
        "water": out_water, "parkings": parkings, "river_half": RIVER_HALF,
        "underpass": {k2: v for k2, v in underpass.items() if k2 not in ("real", "rdir")} if underpass else None,
    }
    with open(OUT_JSON, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("kirjoitettu", OUT_JSON, os.path.getsize(OUT_JSON) // 1024, "kt;", OUT_BIN, os.path.getsize(OUT_BIN) // 1024, "kt;",
          "rakennuksia", len(out_buildings), "sivuteitä", len(side_roads), "kylttejä", len(signs))
    # Oulujärven lava oikealle paikalleen (tarkan alueen ulkopuolella): tontti, Pahalahdentie ja puut.
    VL.apply()


if __name__ == "__main__":
    main()
