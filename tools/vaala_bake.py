#!/usr/bin/env python3
"""Mopomatkan pelimaailma assets/vaala/reitti.json -datasta: tiivistetty tie, maasto ja kohteet.

Ajo: venv/bin/python tools/vaala_bake.py --cache <välimuisti>   (riippuvuudet tools/kartta/requirements.txt)
Tulos: assets/vaala/tie.json (tie, kyltit, rakennukset, sivutiet, rata, vedet), assets/vaala/maasto.bin
(korkeusruudukko 4 m ja maankäyttö; kaukomaasto 32 m) ja assets/vaala/puut.bin (metsä, scripts/forest.gd).

Tarkka aineisto (tools/kartta/vaala_tarkka.py): korkeudet MML:n 2 m korkeusmallista (tie, sivut, keskusta ja
kaukomaasto), pellot, suot ja vedet maastotietokannasta, keskustan ulkopuoliset rakennukset maastotietokannasta,
rakennusten harjakorkeudet ja puut MML:n laserkeilauksesta 2011, puulajit Luken VMI 2023:sta. Reitin linja,
tiennimet ja päällysteet sekä keskustan rakennusten nimet ja tyypit OpenStreetMapista (reitti.json).

Saumaton kuvaus (tools/kartta/vaala_warp.py): koko alueen maasto, maankäyttö ja metsä haetaan todellisesta paikasta
tien näytteiden ja 1:1-ankkurien kehysten pehmeänä yhdistelmänä, joten kartassa ei näy tiivistyksen reunoja.

Tiivistys: mökin pihassa (GRAVEL_S0), Neittäväntien risteyksessä (.. S_A), radan alikululta Oulujoen länsirannalle
(S_B..S_R, lavan niemi) ja Vaalan keskustassa (S_T ->) mittakaava on 1:1. Soratie mökiltä Neittäväntielle lyhenee
GRAVEL_K-kertaisesti ja maantie Vaalaan K-kertaisesti; jokainen tien pala lyhenee samassa suhteessa, joten suunnat ja
risteysten kulmat säilyvät. Oulujoen ylitys (TOWN_K) ja itärannan pätkä keskustan portille (EAST_K, ei taloja) ovat
lineaarinen kaista kaistan akselin suunnassa: joki kapenee ja keskusta alkaa heti sillan jälkeen. Oulujärven lounainen
lahti on maata (lake_cut; muuten järvi olisi tiivistyksen takia mökin vieressä).
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
import puut_teilta as PT  # noqa: E402
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_lava as VL  # noqa: E402
import vaala_keskusta as VK  # noqa: E402
import vaala_silta_jarvi as VS  # noqa: E402
import vaala_warp as VW  # noqa: E402
from scipy import ndimage  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "vaala", "reitti.json")
OUT_JSON = os.path.join(ROOT, "assets", "vaala", "tie.json")
OUT_BIN = os.path.join(ROOT, "assets", "vaala", "maasto.bin")
OUT_TREES = os.path.join(ROOT, "assets", "vaala", "puut.bin")
MOKKI_KARTTA = os.path.join(ROOT, "assets", "mokki", "kartta.json")

K = 22.0           # tiivistyskerroin välimatkalla
STEP = 2.0         # tien näytteiden väli pelissä (m)
CELL = 4.0         # tarkka maasto
NEAR = 150.0       # kohteet (rakennukset, sivutiet) tien ympäriltä tiivistetyllä välillä
SHAPE = 36.0       # tien muoto (piennar, oja, luiska) näin kauas tiestä
MARGIN = 450.0     # tarkka maasto näin kauas reitistä ja 1:1-alueista
MOKKI_1TO1 = 60.0  # mökin pihapiiri 1:1 näin kauas osoitepisteestä
GRAVEL_S0 = 60.0   # soratie mökiltä Neittäväntielle: 1:1 mökin pihassa tämän matkan, sitten GRAVEL_K-kertaisesti tiivis
GRAVEL_K = 2.0
NEITT_PAD = 20.0   # Neittäväntien risteys 1:1 näin kaukaa ennen käännöstä
# Liian isot rakennukset pienemmiksi (OSM/MTK-tunniste -> pohjapiirroksen mittakerroin keskipisteen ympäri):
# Neittävän koulu soratien varressa.
BUILDING_SCALE = {-100305: 0.5}
GASTHAUS_ID = 534430535  # torin laidan talo, vaala.gd _gasthaus_front
# Pois kokonaan: S-Market jäi tiivistyksessä Oulujoen ylityksen ja keskustan väliin ahtaalle.
DROP_BUILDINGS = ("S-market",)
TOWN_R = 480.0     # keskustan tarkka alue Siitarista (kaikki rakennukset, kadut ja rata)
RAIL_1TO1 = 150.0  # 1:1 alkaa näin paljon ennen radan alikulkua (Vuolijoentie radan ali juuri ennen Oulujokea)
# Alikulusta keskustaan: Oulujoen ylitys ja itärannan alku tiivistetään TOWN_K-kertaisesti länsirannalta (sillan alku)
# siihen asti, kun Siitari on TOWN_GATE m päässä. Joki on tässä lähes kohtisuorassa tiehen nähden, joten tien suuntainen
# kaista kaventaa uomaa tasaisesti. Alikulku, Pahalahdentie ja lavan niemi ovat yhtä 1:1-palaa (west_off), keskusta
# toista (town_off), joka on siten lähempänä alikulkua kuin todellisuudessa.
TOWN_K = 3.5
TOWN_GATE = 130.0  # keskustan portti näin kaukana ennen Siitaria sillalta Siitariin -akselilla; sitä ennen olevista
                   # vain palvelut (terveysasema, Seurantalo...) siirretään kokonaisina heti sillan jälkeen
EAST_KEEP_TYPES = ("retail", "commercial", "civic", "school", "church", "public", "hospital", "library", "supermarket")
# Itäranta sillan päästä keskustan portille (pitkien talojen pätkä) lähes pois: EAST_K-kertaisesti tiivis, ei taloja,
# joten kaupat, Siitari ja keskusta alkavat heti sillan jälkeen.
EAST_K = 12.0
TOWN_RMAX = 650.0  # kaistan kohteet (rakennukset, kadut) näin kauas kaistan akselilta
# Oulujärven lounainen lahti (pelissä Pahalahden eteläpuolella, länteen LAKE_CUT_X:stä ja etelään LAKE_CUT_Z:sta,
# aaltoilevat rajat) maaksi: todellisuudessa järvi on mökiltä n. 7 km päässä, mutta tiivistys toisi sen 300 m päähän
# mökistä. Pahalahti lavan niemen länsipuolella ja järven selkä kaakossa jäävät.
LAKE_CUT_X = 560.0
LAKE_CUT_Z = -60.0
BAND_LAT = 1200.0  # kaistan maastokehykset näin kauas akselilta
UNDER_CLEAR = 4.6  # alikulun vapaa korkeus tien pinnasta ratasillan alapintaan
UNDER_DIP = 1.3    # tie painuu alikulussa
UNDER_OPEN = 13.0  # alikulun aukko maastossa ajoradan reunasta (videon mukaan leveä: kansi pilareilla, maatuet kauempana)
UNDER_SLOPE = 0.55  # aukon reunasta penger nousee luiskana kannen alle (ei pystyseinää; vaala.gd: maatuet luiskan päällä)
RIVER_RAIL_RAMP = 90.0  # Oulujoen ratasilta tiesillan tasossa: radan nousu penkereellä näin pitkä kummallakin rannalla
BRANCH_LEN = 90.0  # risteysten haarat väärään suuntaan: 1:1 näin pitkälle, sitten OSM-linjaa maaston kuvauksella
# Neittävän järviseutu: mökin kävelyalueen pohjoisosan järvet (Salmiset, Pyöriäinen, Keskimmäinen; mökin kartta.json)
# piirretään mopomatkan maailmaan Neittäväntien risteyksen luoteeseen loivalla kuvauksella T (todellinen -> peli:
# NL_C + (p - NL_REF) * NL_S). Tiivistetyssä maailmassa ne puristuisivat tien suunnassa 22-kertaisesti sadan metrin
# läikäksi; nyt paperikartan Salmisen uimaranta, Ranta-Rosvo ja laavu ovat Neittävällä omien järviensä rannoilla.
NORTH_LAKES = ("Pyöriäinen", "Etu-Salminen", "Pikku-Salminen", "Taka-Salminen", "Keskimmäinen")
NL_REF = (100.0, -700.0)
NL_C = (-100.0, -300.0)
NL_S = (0.6, 0.5)
NL_BOX = (-470.0, -1060.0, 240.0, -290.0)  # järviseudun alue pelissä: muut pikkujärvet suoksi
NL_ROAD = 35.0     # järvet näin kauas reitistä ja haaroista
NL_BLEND = (-480.0, -700.0)  # paperikartta: todellinen z, jossa mökin alueen kuvaus vaihtuu maastosta T:hen
THIN_CROSS = 120.0  # tiivistetyllä välillä reitin poikki menevät sivutiet vähintään näin kaukana toisistaan
FAR_CELL = 32.0
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


def lake_cut(x, z):
    """Pelin pisteet (taulukot), joissa Oulujärven lounainen lahti muuttuu maaksi (LAKE_CUT_X, LAKE_CUT_Z)."""
    x = np.asarray(x, np.float64)
    z = np.asarray(z, np.float64)
    west = x < LAKE_CUT_X + 45.0 * np.sin(z / 95.0 + 0.7) + 18.0 * np.sin(z / 37.0 + 2.1)
    south = z > LAKE_CUT_Z + 35.0 * np.sin(x / 80.0 + 1.1) + 14.0 * np.sin(x / 29.0)
    return west & south


def polys_near(a, b, gap):
    """Ovatko monikulmiot a ja b päällekkäin tai alle gap m päässä toisistaan."""
    ba, bb = bbox(a, gap), bbox(b)
    if ba[0] > bb[2] or bb[0] > ba[2] or ba[1] > bb[3] or bb[1] > ba[3]:
        return False
    if pip(a[0], b, bbox(b)) or pip(b[0], a, bbox(a)):
        return True
    return any(seg_seg_dist(p, q, r, t) < gap for p, q in zip(a, a[1:] + a[:1]) for r, t in zip(b, b[1:] + b[:1]))


def seg_seg_dist(p, q, r, t):
    def orient(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    if orient(p, q, r) * orient(p, q, t) < 0 and orient(r, t, p) * orient(r, t, q) < 0:
        return 0.0
    return min(seg_dist(p, r, t)[0], seg_dist(q, r, t)[0], seg_dist(r, p, q)[0], seg_dist(t, p, q)[0])


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
    S_R = min(wet) - 10.0  # länsiranta
    _be = real[min(range(len(real)), key=lambda i: abs(rs[i] - B_HI))]
    _ax = ((sx - _be[0]) / math.dist(_be, (sx, sz)), (sz - _be[1]) / math.dist(_be, (sx, sz)))
    S_T = next(rs[i] for i in range(len(real)) if rs[i] > B_HI and
               (real[i][0] - sx) * _ax[0] + (real[i][1] - sz) * _ax[1] > -TOWN_GATE)
    WINDOWS = [(0.0, GRAVEL_S0), (s_neitt - NEITT_PAD, S_A), (S_B, S_R), (S_T, total + 1.0)]

    def scale(s):
        if any(a <= s <= b for a, b in WINDOWS):
            return 1.0
        if GRAVEL_S0 < s < s_neitt - NEITT_PAD:
            return 1.0 / GRAVEL_K
        return 1.0 / TOWN_K if S_R < s < S_T else 1.0 / K

    # --- Korkeudet: tien keskilinja (20 m) ja sivut (60 m, 100 m välein). ----------------------------------------
    line = d["line"]
    lh = [p[2] for p in line]

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
        return base + (h - base) * (0.25 if scale(s) < 0.1 else 0.6)


    # --- Pelin tie: todellinen askel skaalataan, suunta säilyy. ---------------------------------------------------
    # Joen ja keskustan välinen kaista (S_R..S_T) on yksi lineaarinen kuvaus: kaistan akselin (u, länsirannalta
    # keskustan portille) suunnassa TOWN_K-kertaisesti tiivistetty, sivusuunnassa 1:1. Tie, kohteet ja maasto
    # (kaistan kehykset) käyttävät samaa kuvausta, joten kaikki osuu kohdalleen kaukanakin tiestä.
    ib = max(i for i in range(len(real)) if rs[i] <= S_R)
    it = min(i for i in range(len(real)) if rs[i] >= S_T)
    b_pt, t_pt = real[ib], real[it]
    BAND_W = math.dist(b_pt, t_pt)
    u = ((t_pt[0] - b_pt[0]) / BAND_W, (t_pt[1] - b_pt[1]) / BAND_W)

    def band_a(p):
        """Matka kaistan akselilla länsirannan viivalta (0 .. BAND_W kaistalla)."""
        return (p[0] - b_pt[0]) * u[0] + (p[1] - b_pt[1]) * u[1]

    def bridge_d(p):
        """Matka länsirannan viivalta länteen (negatiivinen kaistalla)."""
        return -band_a(p)

    def gate_d(p):
        """Matka keskustan portilta keskustaan päin (negatiivinen kaistalla)."""
        return band_a(p) - BAND_W

    def west_of_bridge(p):
        return bridge_d(p) >= 0.0

    def past_gate(p):
        return gate_d(p) >= 0.0

    game = [real[0]]
    for i in range(1, ib + 1):
        k = scale(rs[i - 1])
        a, b = real[i - 1], real[i]
        game.append((game[-1][0] + (b[0] - a[0]) * k, game[-1][1] + (b[1] - a[1]) * k))
    west_off = (game[ib][0] - real[ib][0], game[ib][1] - real[ib][1])
    VL.AREA = VL.area(west_off)  # lavan niemen 1:1-alue pelissä
    # Kaista kahdessa osassa: joen ylitys (0..BAND_W1, TOWN_K) ja itäranta keskustan portille (EAST_K).
    BAND_W1 = min(max(band_a(real[min(i for i in range(len(real)) if rs[i] >= max(wet) + 15.0)]), 0.0), BAND_W)

    def band_ga(a):
        """Kaistan akselin todellinen matka -> pelin matka."""
        a = min(max(a, 0.0), BAND_W)
        return a / TOWN_K if a <= BAND_W1 else BAND_W1 / TOWN_K + (a - BAND_W1) / EAST_K

    def band_ra(ag):
        """band_ga käänteisenä."""
        return ag * TOWN_K if ag <= BAND_W1 / TOWN_K else BAND_W1 + (ag - BAND_W1 / TOWN_K) * EAST_K

    def in_east(p):
        return BAND_W1 < band_a(p) < BAND_W

    def band_g(p):
        """Todellinen piste kaistalla (tai sen jälkeen keskustassa) pelin kehykseen."""
        a = band_a(p)
        sh = min(max(a, 0.0), BAND_W) - band_ga(a)
        return (p[0] + west_off[0] - u[0] * sh, p[1] + west_off[1] - u[1] * sh)

    for i in range(ib + 1, len(real)):
        game.append(band_g(real[i]))
    # Itärannan pätkällä tie puristuu akselin suunnassa EAST_K-kertaisesti mutta sivusuunnassa 1:1, jolloin todellinen
    # kaarre muuttuisi koukuksi: tie sillan päästä keskustan portille sujuvaksi käyräksi (Hermite, suunnat säilyvät).
    i0 = next(i for i in range(ib, len(real)) if band_a(real[i]) >= BAND_W1)
    i1 = next(i for i in range(i0, len(real)) if band_a(real[i]) >= BAND_W) + 25
    if i1 < len(real) - 30:
        p0, p1 = game[i0], game[i1]
        t0 = (game[i0][0] - game[i0 - 8][0], game[i0][1] - game[i0 - 8][1])
        t1 = (game[i1 + 8][0] - game[i1][0], game[i1 + 8][1] - game[i1][1])
        L = math.dist(p0, p1)
        t0 = (t0[0] / (math.hypot(*t0) or 1.0) * L, t0[1] / (math.hypot(*t0) or 1.0) * L)
        t1 = (t1[0] / (math.hypot(*t1) or 1.0) * L, t1[1] / (math.hypot(*t1) or 1.0) * L)
        for i in range(i0 + 1, i1):
            t = (rs[i] - rs[i0]) / (rs[i1] - rs[i0])
            h00, h10, h01, h11 = 2 * t ** 3 - 3 * t * t + 1, t ** 3 - 2 * t * t + t, -2 * t ** 3 + 3 * t * t, t ** 3 - t * t
            game[i] = (h00 * p0[0] + h10 * t0[0] + h01 * p1[0] + h11 * t1[0], h00 * p0[1] + h10 * t0[1] + h01 * p1[1] + h11 * t1[1])
    gs = [0.0]
    for a, b in zip(game, game[1:]):
        gs.append(gs[-1] + math.dist(a, b))
    town_off = (game[-1][0] - real[-1][0], game[-1][1] - real[-1][1])
    print("joelta keskustaan: kaista %.0f m -> %.0f m (joki %.0f m -> %.0f m, itäranta %.0f m -> %.0f m; S_R %.0f S_T %.0f)" % (
        BAND_W, band_ga(BAND_W), BAND_W1, BAND_W1 / TOWN_K, BAND_W - BAND_W1, (BAND_W - BAND_W1) / EAST_K, S_R, S_T))
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
        smp["bridge"] = False
    # Silta, jos todellinen tie näytteestä edelliseen (tiivistetyllä välillä kymmeniä metrejä) ylittää vettä: kapeakin
    # puro löytyy näytteiden välistä (ennen yksittäinen näyte osui siihen sattumalta tai ei).
    wet_q = [any(pip(q, f["pts"], bb) for f, bb in waters) for q in real]
    k_ = 0
    for i_, smp in enumerate(samples):
        s_prev = samples[i_ - 1]["s"] if i_ else 0.0
        while k_ < len(rs) - 1 and rs[k_] < s_prev:
            k_ += 1
        k2 = k_
        while k2 < len(rs) and rs[k2] <= smp["s"]:
            if wet_q[k2]:
                smp["bridge"] = True
                break
            k2 += 1
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

    real_town = (sx, sz)

    def to_game(p, rmax=NEAR + 60.0):
        """Todellinen piste pelin kehykseen lähimmän tien kohdan mukaan (tien suunnassa näytteen mittakaava,
        sivusuunnassa 1:1), None jos kaukana tiestä. Keskusta ja lavan niemi (VL.AREA) ovat 1:1: pelkkä siirto,
        mökin pihapiiri paikallaan (samat ankkurit kuin maaston kuvauksessa)."""
        ar = VL.AREA
        wp = (p[0] + west_off[0], p[1] + west_off[1])
        in_area = ar[0] + 60.0 <= wp[0] <= ar[2] and ar[1] <= wp[1] <= ar[3]
        if past_gate(p) and (in_area or math.dist(p, real_town) < TOWN_R):
            return (p[0] + town_off[0], p[1] + town_off[1])
        if west_of_bridge(p) and in_area:
            return wp
        if not west_of_bridge(p) and not past_gate(p):
            # Kaista: sama lineaarinen kuvaus kuin tiellä ja maastossa, TOWN_RMAX m kaistan akselilta.
            lat = -(p[0] - b_pt[0]) * u[1] + (p[1] - b_pt[1]) * u[0]
            return band_g(p) if abs(lat) < TOWN_RMAX else None
        if math.hypot(p[0], p[1]) < MOKKI_1TO1:
            return p
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
        if c < VW.LAT_C:
            lat = VW.lat_in(lat)  # kuten maaston kuvauksessa (vaala_warp.lat_out)
        return (smp["g"][0] + gd[0] * along * c - gd[1] * lat, smp["g"][1] + gd[1] * along * c + gd[0] * lat)

    # --- Kohteet peliin. -------------------------------------------------------------------------------------
    rr = Grid(real[::2], 20.0)  # tiheä todellinen reitti (näytteet ovat tiivistetyllä välillä harvassa)

    def on_route(p):
        return rr.nearest(p, 6.0)[0] >= 0

    # Tiivistetyllä välillä ennen Oulujoen siltaa K-kertainen matka pakkautuisi lyhyelle pätkälle ja talot
    # kasautuisivat toistensa päälle: sinne vain isoimmat talot vähintään THIN_GAP m välein, ei vajoja.
    THIN_GAP = 45.0
    kept = []
    kept_band = []
    out_buildings = []
    def b_area(f):
        q = f["pts"]
        return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(q, q[1:] + q[:1]))) / 2.0

    def b_centroid(f):
        pts = f["pts"][:-1] if f["pts"][0] == f["pts"][-1] else f["pts"]
        return (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))

    def in_band(p):
        return not west_of_bridge(p) and not past_gate(p)

    # Itärannan palvelut (terveysasema, ...) ensin: muut väistävät niitä. Sitten kaistan ulkopuoliset,
    # jotta kaistan talot väistävät niitäkin; kussakin isoimmat ensin.
    def east_service(f):
        c_ = b_centroid(f)
        return in_band(c_) and in_east(c_) and (bool(f.get("name")) or f.get("building", "yes") in EAST_KEEP_TYPES)

    protected = []  # palveluiden pelin pohjat: sivutiet katkaistaan niiden kohdalta

    def rank(f):
        return 0 if east_service(f) else (2 if in_band(b_centroid(f)) else 1)

    for f in sorted((f for f in feats if f["kind"] == "building" and not any(n_ in f.get("name", "") for n_ in DROP_BUILDINGS)),
                    key=lambda f: (rank(f), -b_area(f))):
        pts = f["pts"][:-1] if f["pts"][0] == f["pts"][-1] else f["pts"]
        c = b_centroid(f)
        if f["id"] in BUILDING_SCALE:
            k_ = BUILDING_SCALE[f["id"]]
            pts = [(c[0] + (q[0] - c[0]) * k_, c[1] + (q[1] - c[1]) * k_) for q in pts]
        gc = to_game(c)
        if gc is None:
            continue
        ri, _ = rgrid.nearest(c, NEAR + 60.0)
        off = (gc[0] - c[0], gc[1] - c[1])
        if in_band(c) and in_east(c):
            # Itärannan pätkä on pelissä vain muutama kymmenen metriä: asuintalot pois, palvelut kokonaisina.
            if not f.get("name") and f.get("building", "yes") not in EAST_KEEP_TYPES:
                continue
            g_ = band_g(c)
            off = (g_[0] - c[0], g_[1] - c[1])
            gc = g_
            gpts = [(q[0] + off[0], q[1] + off[1]) for q in pts]
            if any(polys_near(gpts, q, 3.0) for q in kept_band):
                continue
            kept_band.append(gpts)
            protected.append(gpts)
        elif in_band(c):
            # Kaistalla talot tiivistyvät akselin suunnassa: isoimmat ensin, alle 4 m päässä toisistaan olevat pois.
            gpts = [band_g(q) for q in pts]
            if any(polys_near(gpts, q, 4.0) for q in kept_band):
                continue
            kept_band.append(gpts)
            off = None
        elif ri >= 0 and samples[ri]["c"] < VW.LAT_C:
            if b_area(f) < 60.0 or any(math.dist(gc, q) < THIN_GAP for q in kept):
                continue
            kept.append(gc)
        elif ri >= 0 and samples[ri]["c"] < 1.0:
            # Lievästi tiivistetty (soratie mökiltä): talot siirtyvät kokonaisina, päällekkäiset pois.
            gpts = [(q[0] + off[0], q[1] + off[1]) for q in pts]
            if any(polys_near(gpts, q, 3.0) for q in kept_band):
                continue
            kept_band.append(gpts)
        if off is not None and (-80.0 < gate_d(c) < 80.0 or -80.0 < bridge_d(c) < 80.0):
            rp_ = [(q[0] + off[0], q[1] + off[1]) for q in pts]
            if not any(rp_ is q or rp_ == q for q in protected) and any(polys_near(rp_, q, 2.0) for q in protected):
                continue  # keskustan reunan talo palvelun päällä
            kept_band.append(rp_)
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
                              "pts": [[round(q[0], 2), round(q[1], 2)] for q in gpts] if off is None else
                              [[round(q[0] + off[0], 2), round(q[1] + off[1], 2)] for q in pts]})
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
                                 "real": [[round(q[0], 2), round(q[1], 2)] for q in cut],
                                 "rest": line[len(cut):]})
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

    def in_protected(gp):
        for poly in protected:
            bb_ = bbox(poly, 3.0)
            if bb_[0] <= gp[0] <= bb_[2] and bb_[1] <= gp[1] <= bb_[3] and (
                    pip(gp, poly, bbox(poly)) or min(seg_dist(gp, a, b2)[0] for a, b2 in zip(poly, poly[1:] + poly[:1])) < 3.0):
                return True
        return False
    # Sivutiet loppuvat ennen siltoja (kannen kaiteet ja rantapenkat): ei liittymää sillan päähän.
    bgrid = Grid([smp["g"] for smp in samples if smp["bridge"]], 20.0)
    for f in feats:
        if f["kind"] not in ("road", "rail") or f["id"] in branch_ways:
            continue
        hw = f.get("highway", "")
        cur = []
        pts = resample(f["pts"], 6.0)
        for p in pts:
            gp = to_game(p, 130.0)
            if gp is None or (f["kind"] == "road" and (on_route(p) or bgrid.nearest(gp, 20.0)[0] >= 0 or in_protected(gp)
                                                       or (in_band(p) and in_east(p)))):  # itärannan pätkä: ei katuja
                if len(cur) > 1:
                    side_roads.append({"kind": f["kind"], "hw": hw, "name": f.get("name", ""), "surface": f.get("surface", ""),
                                       "pts": cur})
                cur = []
                continue
            cur.append([round(gp[0], 2), round(gp[1], 2)])
        if len(cur) > 1:
            side_roads.append({"kind": f["kind"], "hw": hw, "name": f.get("name", ""), "surface": f.get("surface", ""), "pts": cur})
    # Talot eivät saa jäädä ajettavien sivuteiden päälle (tiivistetyllä välillä kadut kutistuvat pisteittäin, talot
    # siirtyvät kokonaisina): ajoradan puoliskon sisällä oleva talo pois.
    # Tiivistetyllä välillä reitin poikki menevät metsätiet puristuvat yhdensuuntaisiksi raidoiksi: pisimmät jäävät
    # THIN_CROSS m välein, muut pois.
    gs_grid = Grid([smp["g"] for smp in samples], 20.0)
    crossings = []
    keep_sr = []
    for r in side_roads:
        if r["kind"] != "road":
            keep_sr.append(r)
            continue
        bd_, bi_ = 1e9, -1
        for q in r["pts"]:
            i_, d_ = gs_grid.nearest(tuple(q), 40.0)
            if i_ >= 0 and d_ < bd_:
                bd_, bi_ = d_, i_
        if bi_ >= 0 and bd_ < 30.0 and samples[bi_]["c"] < VW.LAT_C:
            crossings.append((bi_, sum(math.dist(a, b) for a, b in zip(r["pts"], r["pts"][1:])), r))
        else:
            keep_sr.append(r)
    taken = []
    for bi_, _L, r in sorted(crossings, key=lambda c: -c[1]):
        if all(abs(bi_ - t) * STEP >= THIN_CROSS for t in taken):
            taken.append(bi_)
            keep_sr.append(r)
    print("tiivistetyn välin poikkitiet: %d -> %d" % (len(crossings), len(taken)))
    side_roads = keep_sr
    SIDE_HW = {"secondary": 3.2, "tertiary": 3.2, "residential": 2.6, "service": 1.8}
    street_pts = []
    for r in side_roads:
        if r["kind"] != "road" or r["hw"] in ("footway", "cycleway", "path", "pedestrian", "steps"):
            continue
        hw_ = SIDE_HW.get(r["hw"], 2.2)
        for a, b in zip(r["pts"], r["pts"][1:]):
            for q in resample([tuple(a), tuple(b)], 1.0):
                street_pts.append((q, hw_))
    sgrid = Grid([q[0] for q in street_pts], 20.0)
    keep, dropped = [], []
    for bd in out_buildings:
        pts = [tuple(q) for q in bd["pts"]]
        c = (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
        rad = max(math.dist(c, q) for q in pts) + 3.2
        bb = bbox(pts)
        ci_, cj_ = int(c[0] // 20.0), int(c[1] // 20.0)
        rr_ = int(math.ceil(rad / 20.0))
        hit = any(math.dist(street_pts[qi][0], c) <= rad and (
                  pip(street_pts[qi][0], pts, bb) or
                  min(seg_dist(street_pts[qi][0], a, b2)[0] for a, b2 in zip(pts, pts[1:] + pts[:1])) < street_pts[qi][1] * 0.5)
                  for dj in range(-rr_, rr_ + 1) for di in range(-rr_, rr_ + 1)
                  for qi in sgrid.g.get((ci_ + di, cj_ + dj), ()))
        (dropped if hit else keep).append(bd if not hit else (bd["id"], bd["type"], bd["name"]))
    out_buildings = keep
    print("sivuteiden päältä pois", dropped)
    out_water = []
    parkings = []
    for f in feats:
        if f["kind"] != "parking":
            continue
        gp = [to_game(q) for q in f["pts"]]
        if all(q is not None for q in gp):
            parkings.append([[round(q[0], 2), round(q[1], 2)] for q in gp])

    # --- Maasto: saumaton tiivistys (tools/kartta/vaala_warp.py) koko alueelle, kaukomaasto horisonttiin. -------
    # Jokainen ruutu haetaan todellisesta paikasta tien näytteiden ja 1:1-ankkurien kehysten pehmeänä yhdistelmänä:
    # kartassa ei näy reunoja (keskustan ympyrä, lavan suorakaide, tyhjä kaukomaasto), ja vedet, pellot ja puut
    # osuvat kohdalleen. Tien muoto (piennar, oja, luiska) tehdään tien lähiruutuihin kuten ennenkin.
    gx = [smp["g"][0] for smp in samples]
    gz = [smp["g"][1] for smp in samples]
    town_c = (sx + town_off[0], sz + town_off[1])
    x0 = math.floor((min(min(gx), town_c[0] - TOWN_R, VL.AREA[0]) - MARGIN) / CELL) * CELL
    z0 = math.floor((min(min(gz), town_c[1] - TOWN_R, VL.AREA[1]) - MARGIN) / CELL) * CELL
    x1 = max(max(gx), town_c[0] + TOWN_R, VL.AREA[2]) + MARGIN
    z1 = max(max(gz), town_c[1] + TOWN_R, VL.AREA[3]) + MARGIN
    nx = int((x1 - x0) / CELL) + 1
    nz = int((z1 - z0) / CELL) + 1
    print("ruudukko %d x %d (%.0f x %.0f m)" % (nx, nz, nx * CELL, nz * CELL))
    INF = 1e9
    # Tien lähiruudut: reitti ja risteysten haarat (haaran alla tasainen tiepohja kuten reitillä).
    tsamp = list(samples)
    for b in branches:
        for q, rq in zip(b["pts"], b["real"]):
            tsamp.append({"g": (q[0], q[2]), "y": q[1], "hw": b["hw"], "s": b["s"], "r": tuple(rq), "bridge": False})
    near_d = {}
    near_i = {}
    rcell = int(SHAPE / CELL) + 1

    def stamp_near(si):
        p = tsamp[si]["g"]
        ci = int((p[0] - x0) / CELL)
        cj = int((p[1] - z0) / CELL)
        for j in range(max(cj - rcell, 0), min(cj + rcell + 1, nz)):
            zz = z0 + j * CELL - p[1]
            for i in range(max(ci - rcell, 0), min(ci + rcell + 1, nx)):
                xx = x0 + i * CELL - p[0]
                dd = xx * xx + zz * zz
                k = j * nx + i
                if dd < near_d.get(k, INF):
                    near_d[k] = dd
                    near_i[k] = si

    for si in list(range(0, n, 2)) + list(range(n, len(tsamp))):
        stamp_near(si)

    # Kehykset: reitti (6 m välein), haarat (siirtokehyksiä) ja 1:1-alueiden ankkurit.
    frames = {"g": [], "r": [], "d": [], "rd": [], "c": [], "y": [], "f": [], "bonus": []}

    def frame(g, r, dd, rdd, c, y, f, bonus):
        for key, v in zip(("g", "r", "d", "rd", "c", "y", "f", "bonus"), (g, r, dd, rdd, c, y, f, bonus)):
            frames[key].append(v)

    for i in range(0, n, 3):
        smp = samples[i]
        c = smp["c"]
        if S_R < smp["s"] < S_T:
            continue  # kaistalla kaistan omat kehykset
        frame(smp["g"], smp["r"], smp["dir"], smp["rdir"], c, h_game_s(smp["s"]), 1.0 if c >= 1.0 else 0.5, 0.0)
    dem_s = lambda q: float(VW.dem_at(fd, [q[0]], [q[1]], smooth=6)[0])  # noqa: E731
    # Kaistan kehykset: ruudukko pelin kaistalla, kaikki samaa lineaarista kuvausta (akseli u tiivistetty TOWN_K).
    nb = 0
    perp = (-u[1], u[0])
    for ag in list(np.arange(0.0, band_ga(BAND_W), 12.0)) + [band_ga(BAND_W)]:
        ra = band_ra(ag)
        kc = TOWN_K if ra <= BAND_W1 else EAST_K
        for lt in np.arange(-BAND_LAT, BAND_LAT + 0.1, 25.0):
            r = (b_pt[0] + u[0] * ra + perp[0] * lt, b_pt[1] + u[1] * ra + perp[1] * lt)
            gq = (b_pt[0] + west_off[0] + u[0] * ag + perp[0] * lt, b_pt[1] + west_off[1] + u[1] * ag + perp[1] * lt)
            # Kaukana akselilta kaistan kehykset häviävät naapureilleen (ei saumaa kaukomaisemaan).
            frame(gq, r, u, u, 1.0 / kc, dem_s(r), 1.0, -max(0.0, abs(lt) - 400.0))
            nb += 1
    print("kaistan kehyksiä", nb)
    for b in branches:
        for k in range(0, len(b["pts"]), 3):
            q, rq = b["pts"][k], b["real"][k]
            frame((q[0], q[2]), tuple(rq), (1.0, 0.0), (1.0, 0.0), 1.0, dem_s(rq), 1.0, 0.0)

    def anchors(cx, cz, rad, step, off, bonus, box=None, edge=None):
        m = 0
        for ax in np.arange(cx - rad, cx + rad + 0.1, step):
            for az in np.arange(cz - rad, cz + rad + 0.1, step):
                if (box is None and math.hypot(ax - cx, az - cz) > rad) or \
                        (box is not None and not (box[0] <= ax <= box[2] and box[1] <= az <= box[3])):
                    continue
                r = (ax - off[0], az - off[1])
                b = bonus
                if edge is not None:
                    # Kaistan reunalla ankkurit eivät saa etumatkaa kaistan yli (muuten ne peittäisivät joen).
                    e = edge(r)
                    if e < 0.0:
                        continue
                    b = min(bonus, e)
                frame((ax, az), r, (1.0, 0.0), (1.0, 0.0), 1.0, dem_s(r), 1.0, b)
                m += 1
        return m

    # Etumatka: ankkurit voittavat tienäytteet näin monen metrin päästä. Tiivistetty käytävä on pelissä vain n. 440 m,
    # joten mökin ja niemen ankkureilla etumatka on pieni (muuten ne peittäisivät käytävän).
    na = anchors(0.0, 0.0, MOKKI_1TO1, 30.0, (0.0, 0.0), 20.0)
    na += anchors(town_c[0], town_c[1], TOWN_R + 60.0, 50.0, town_off, 300.0, edge=gate_d)
    # Keskustan ympyrän joen länsipuoli (ennen tiivistystä keskustan ankkureilla) niemen siirrolla.
    na += anchors(sx + west_off[0], sz + west_off[1], TOWN_R + 60.0, 50.0, west_off, 300.0, edge=bridge_d)
    ar = VL.AREA
    na += anchors((ar[0] + ar[2]) / 2, (ar[1] + ar[3]) / 2, max(ar[2] - ar[0], ar[3] - ar[1]), 60.0, west_off, 60.0,
                  (ar[0] + 60.0, ar[1], ar[2], ar[3]), edge=bridge_d)
    # Joen länsipuoli niemen pohjoispuolella (järvi ja suot) niemen siirrolla, kuten ennen kaistaa.
    na += anchors(0.0, ar[1] - 450.0, 900.0, 60.0, west_off, 60.0, (-700.0, ar[1] - 900.0, ar[2], ar[1]), edge=bridge_d)
    # Niemen alueen keskustan puoli (radan eteläpuolen asuinalue) keskustan siirrolla.
    dx_, dz_ = town_off[0] - west_off[0], town_off[1] - west_off[1]
    na += anchors((ar[0] + ar[2]) / 2 + dx_, (ar[1] + ar[3]) / 2 + dz_, max(ar[2] - ar[0], ar[3] - ar[1]), 60.0, town_off,
                  60.0, (ar[0] + 60.0 + dx_, ar[1] + dz_, ar[2] + dx_, ar[3] + dz_), edge=gate_d)
    warp = VW.Warp(fd, **frames)
    print("kehyksiä %d (ankkureita %d)" % (len(frames["g"]), na))
    rc = VW.RealCodes(feats, fd.x0, fd.z0, fd.x0 + (fd.nx - 1) * fd.step, fd.z0 + (fd.nz - 1) * fd.step, oulu, RIVER_HALF)
    GX, GZ = np.meshgrid(x0 + np.arange(nx) * CELL, z0 + np.arange(nz) * CELL)
    RX, RZ, GROUND, ONE, CODE = warp.inv(GX, GZ, rc)
    RX, RZ, GROUND, ONE, CODE = (a.reshape(nz, nx) for a in (RX, RZ, GROUND, ONE, CODE))
    # Tiivistetyllä välillä korkeusmalli on tien suunnassa K-kertaisesti tiheämpi: pehmennetään (1:1-alueet ennallaan).
    GROUND = ONE * GROUND + (1.0 - ONE) * ndimage.gaussian_filter(GROUND, 2.0)
    # Oulujoen pinta korkeusmallista (tasoitettu vedenpinta joen keskiviivalla keskustassa).
    wl = sorted(fd.at(q[0], q[1]) for a, b in oulu for q in (a, b))
    water_level = wl[len(wl) // 2] if wl else min([smp["y"] - 0.6 for smp in samples if smp["bridge"]] or [121.0]) - 3.5
    # Tiivistetyllä välillä (tien vieren ulkopuolella) ohuet 1:22-suikaleet pois enemmistösuodattimella.
    road_near = np.zeros(nx * nz, bool)
    road_near[list(near_i.keys())] = True
    votes = np.stack([ndimage.uniform_filter((CODE == c).astype(np.float32), 7) for c in range(8)])
    CODE = np.where((ONE < 0.9) & ~road_near.reshape(nz, nx), votes.argmax(0), CODE).astype(np.uint8)
    # Pihat rakennusten ympärillä ja radat pelin kehyksessä.
    bmask = VW.game_raster([bd["pts"] for bd in out_buildings], x0, z0, nx, nz, CELL)
    bdist = ndimage.distance_transform_edt(~bmask) * CELL
    CODE[(bdist < 16.0) & (CODE == FOREST)] = YARD
    # Tiivistetyllä välillä taajamien pihamaat ilman taloja (talot jäivät pois tai ovat muualla) metsäksi.
    nl_box = (GX > NL_BOX[0]) & (GX < NL_BOX[2]) & (GZ > NL_BOX[1]) & (GZ < NL_BOX[3])
    CODE[(CODE == YARD) & ((ONE < 0.9) | nl_box) & (bdist > 30.0)] = FOREST
    rails = [r for r in side_roads if r["kind"] == "rail"]
    rail_m = VW.game_raster([], x0, z0, nx, nz, CELL, [r["pts"] for r in rails], 5.6)
    CODE[rail_m & (CODE != WATER)] = RAIL  # ratasillan alla vettä (ennen hiekkakaistale joen pohjassa)
    VW.flatten_water(CODE, GROUND, water_level, CELL)
    # Pienet maaläikät keskellä Oulujoki/Oulujärveä (muutama 4 m ruutu) olivat terävinä hiekkapyramideina: vedeksi.
    lab_, nl_ = ndimage.label(CODE != WATER)
    isl = 0
    for k_, sl in enumerate(ndimage.find_objects(lab_), start=1):
        m_ = lab_[sl] == k_
        if m_.sum() > 60:
            continue
        sl2 = tuple(slice(max(s_.start - 1, 0), s_.stop + 1) for s_ in sl)
        mm = lab_[sl2] == k_
        ring = ndimage.binary_dilation(mm) & ~mm
        sub_c = CODE[sl2]
        if ring.any() and np.all(sub_c[ring] == WATER) and np.all(np.abs(GROUND[sl2][ring] + 1.2 - water_level) < 0.05):
            sub_c[mm] = WATER
            GROUND[sl2][mm] = water_level - 1.2
            isl += 1
    print("pikkusaaret joessa vedeksi: %d" % isl)
    # Oulujärven lounainen lahti maaksi (lake_cut): ranta suota, sitten metsää, maa nousee loivasti rannasta.
    if os.environ.get("VAALA_DEBUG"):
        np.savez_compressed(os.environ["VAALA_DEBUG"] + "_vesi.npz", code=CODE, ground=GROUND, gx=GX, gz=GZ)
    # Vain järven selkään (kaakossa, x > LAKE_CUT_X) yhtyvä vesi: mökin omat järvet (Likanen) jäävät.
    lab, _nl = ndimage.label(CODE == WATER, structure=np.ones((3, 3)))
    sel_ = np.unique(lab[(GX > LAKE_CUT_X + 60.0) & (GZ > LAKE_CUT_Z) & (lab > 0)])
    LAKE_CUT = np.isin(lab, sel_[sel_ > 0]) & lake_cut(GX, GZ)
    # Tarkan alueen reunoilla Oulujärvi päättyy rantaan ennen reunaa, jos kaukomaasto reunan takana on maata (muuten
    # ranta olisi suora viiva tarkan alueen reunassa). Reunan takaa näytteet 32 m välein samalla kuvauksella.
    main_w = (CODE == WATER) & (np.abs(GROUND + 1.2 - water_level) < 0.05)
    xa, za = x0, z0
    xb, zb = x0 + (nx - 1) * CELL, z0 + (nz - 1) * CELL
    edge_cut = np.zeros_like(main_w)
    for side in ("w", "e", "n", "s"):
        if side in ("w", "e"):
            t_ = np.arange(za, zb + 1.0, 32.0)
            ox = np.full_like(t_, xa - 24.0 if side == "w" else xb + 24.0)
            oz = t_
        else:
            t_ = np.arange(xa, xb + 1.0, 32.0)
            ox = t_
            oz = np.full_like(t_, za - 24.0 if side == "n" else zb + 24.0)
        _r1, _r2, og, _o1, oc = warp.inv(ox, oz, rc)
        far_wet = (oc == WATER) & (np.abs(og - water_level) < 2.5)
        if side in ("w", "e"):
            wet_here = np.interp(GZ, t_, far_wet.astype(float)) > 0.5
            dist_edge = (GX - xa) if side == "w" else (xb - GX)
            along = GZ
        else:
            wet_here = np.interp(GX, t_, far_wet.astype(float)) > 0.5
            dist_edge = (GZ - za) if side == "n" else (zb - GZ)
            along = GX
        width = 90.0 + 45.0 * np.sin(along / 97.0 + 0.6) + 20.0 * np.sin(along / 31.0 + 1.7)
        edge_cut |= main_w & ~wet_here & (dist_edge < width)
    print("Oulujärvi rantaan ennen tarkan alueen reunaa: %d ruutua" % edge_cut.sum())
    LAKE_CUT |= edge_cut
    if LAKE_CUT.any():
        CODE[LAKE_CUT] = FOREST
        dist = ndimage.distance_transform_edt(CODE != WATER) * CELL  # matka uudelta rannalta
        GROUND[LAKE_CUT] = water_level + 0.4 + np.minimum(dist[LAKE_CUT] * 0.03, 5.0)
        CODE[LAKE_CUT & (dist < 40.0)] = BOG
    print("Oulujärven lounaislahti maaksi %d ruutua" % LAKE_CUT.sum())

    # --- Eteenpäin-kuvaus (todellinen -> peli) tarkan maaston ruudukosta: haarojen jatkeet ja mökin alue. ------
    fwd = VW.Forward(GX, GZ, RX, RZ)

    def ground_at(q):
        fx = min(max((q[0] - x0) / CELL, 0.0), nx - 1.001)
        fz = min(max((q[1] - z0) / CELL, 0.0), nz - 1.001)
        i, j = int(fx), int(fz)
        u, v = fx - i, fz - j
        return float(lerp(lerp(GROUND[j, i], GROUND[j, i + 1], u), lerp(GROUND[j + 1, i], GROUND[j + 1, i + 1], u), v))

    # Risteysten haarat jatkuvat OSM-linjaansa pitkin samalla kuvauksella kuin maasto (ennen 90 m:n jälkeen umpitie
    # ja tien penger jatkui metsässä paljaana harjanteena) tarkan alueen reunaan, veteen, taloon tai reitille asti.
    bld_near = ndimage.distance_transform_edt(~bmask) * CELL < 6.0
    route_g = Grid([smp["g"] for smp in samples], 20.0)
    for b in branches:
        rest = b.pop("rest", [])
        if len(rest) < 6:
            continue
        gp, err = fwd(rest)
        gp = ndimage.uniform_filter1d(gp, 9, axis=0, mode="nearest")  # 4 m ruudut sileäksi viivaksi
        end = np.array([b["pts"][-1][0], b["pts"][-1][2]])
        off0 = end - fwd([b["real"][-1]])[0][0]
        ext = []
        acc = 0.0
        prev = end
        for k in range(len(rest)):
            acc += 2.0
            q = gp[k] + off0 * max(0.0, 1.0 - acc / 60.0)
            i_, j_ = int(round((q[0] - x0) / CELL)), int(round((q[1] - z0) / CELL))
            if err[k] > 16.0 or not (15 <= i_ < nx - 15 and 15 <= j_ < nz - 15) or CODE[j_, i_] == WATER or bld_near[j_, i_]:
                break
            step_ = math.dist(q, prev)
            if step_ > 14.0:
                break  # kuvauksen hyppy (kehys vaihtui)
            ri_, rd_ = route_g.nearest((q[0], q[1]), 30.0)
            if ri_ >= 0 and abs(samples[ri_]["s"] - b["s"]) > 150.0:
                break  # palaisi reitille muualla
            if step_ < 1.8:
                continue
            ext.append((float(q[0]), float(q[1])))
            prev = q
        if len(ext) < 8:
            continue
        ext = resample([tuple(end)] + ext, 2.0)[1:]
        ys = ndimage.uniform_filter1d(np.array([ground_at(q) for q in ext]), 11, mode="nearest")
        for q, y in zip(ext, ys):
            b["pts"].append([round(q[0], 2), round(float(y), 2), round(q[1], 2)])
            tsamp.append({"g": q, "y": float(y), "hw": b["hw"], "s": b["s"], "r": None, "bridge": False})
            stamp_near(len(tsamp) - 1)
        print("haara %s jatkuu %.0f m" % (b["name"], 2.0 * len(ext)))

    # Mökin kävelyalue (mokki.gd, todellinen 1:1) mopomatkan kehykseen: paperikartan kohteet ja pelaajan paikka.
    MW = (-900.0, -2100.0, 20.0, 96, 141)  # x0, z0, askel, nx, nz todellisessa kehyksessä
    mx, mz = np.meshgrid(MW[0] + np.arange(MW[3]) * MW[2], MW[1] + np.arange(MW[4]) * MW[2])
    mg, merr = fwd(np.c_[mx.ravel(), mz.ravel()])
    mokki_warp = {"x0": MW[0], "z0": MW[1], "step": MW[2], "nx": MW[3], "nz": MW[4],
                  "g": [round(float(v), 1) for v in mg.ravel()]}
    for nm, q in (("Salmisen uimaranta", (16.0, -931.0)), ("Ranta-Rosvo", (-327.0, -1242.0)), ("Keskimmäisen laavu", (456.0, -1653.0)),
                  ("mökki", (0.0, 0.0))):
        g_, e_ = fwd([q])
        print("mökin kohde %s todellinen %s -> pelissä (%.0f, %.0f), virhe %.1f m" % (nm, q, g_[0][0], g_[0][1], e_[0]))
    print("mökin alueen kuvaus: virhe mediaani %.1f m, max %.1f m" % (float(np.median(merr)), float(merr.max())))
    if os.environ.get("VAALA_DEBUG"):
        # Vianetsintä: maankäyttö ja 1:1-osuus (punainen = tiivistetyn tien kehykset) kuvaksi.
        from PIL import Image
        pal = np.array([[90, 140, 60], [230, 200, 110], [180, 200, 200], [90, 140, 220], [200, 200, 160],
                        [200, 190, 160], [80, 80, 80], [120, 110, 100]], np.uint8)
        Image.fromarray(pal[np.minimum(CODE, 7)]).save(os.environ["VAALA_DEBUG"] + "_koodit.png")
        Image.fromarray((np.stack([1 - ONE, ONE * 0, ONE], 2) * 255).astype(np.uint8)).save(os.environ["VAALA_DEBUG"] + "_one.png")
    heights = [round(float(v), 3) for v in GROUND.ravel()]
    codes = CODE.ravel().tolist()
    print("maankäyttö", {nm: int((CODE == c).sum()) for nm, c in (("metsä", FOREST), ("pelto", FIELD), ("suo", BOG),
                                                                  ("vesi", WATER), ("piha", YARD), ("rata", RAIL))})
    # Tie: tasainen piennar, oja ja luiska luonnolliseen maahan.
    for k, si in near_i.items():
        i, j = k % nx, k // nx
        p = (x0 + i * CELL, z0 + j * CELL)
        in_town = math.dist(p, town_c) < TOWN_R
        dist = math.sqrt(near_d[k])
        smp = tsamp[si]
        hw = smp["hw"]
        ground = heights[k]
        code = codes[k]
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
                if code in (FOREST, BOG, WATER):
                    code = FIELD  # ojan pientareet nurmella
            else:
                h = lerp(y - 0.05, ground, smooth(ditch + 2.0, ditch + 22.0, dist))
                if code == WATER and h > ground + 0.5:
                    code = FIELD  # tien luiska rannassa
        heights[k] = round(h, 3)
        codes[k] = code

    # --- Neittävän järviseutu (NORTH_LAKES, kuvaus T): järvet maastoon, muut pikkujärvet alueella suoksi. ---------
    H2 = np.array(heights).reshape(nz, nx)
    C2 = np.array(codes, np.uint8).reshape(nz, nx)
    route_lines = [[smp["g"] for smp in samples]] + [[(q[0], q[2]) for q in b["pts"]] for b in branches]
    near_route = VW.game_raster([], x0, z0, nx, nz, CELL, route_lines, 2.0 * NL_ROAD)
    box = (GX > NL_BOX[0]) & (GX < NL_BOX[2]) & (GZ > NL_BOX[1]) & (GZ < NL_BOX[3])

    def nl_t(p):
        return (NL_C[0] + (p[0] - NL_REF[0]) * NL_S[0], NL_C[1] + (p[1] - NL_REF[1]) * NL_S[1])

    wl_lab, _nw = ndimage.label(C2 == WATER, structure=np.ones((3, 3)))
    wl_sizes = np.bincount(wl_lab.ravel())
    old_lakes = np.zeros_like(box)
    for k_, sl in enumerate(ndimage.find_objects(wl_lab), start=1):
        m_ = wl_lab[sl] == k_
        if wl_sizes[k_] > 3000 or box[sl][m_].mean() < 0.5:
            continue  # Oulujärvi ja Oulujoki sekä alueen ulkopuoliset
        old_lakes[sl] |= m_
    if old_lakes.any():
        # Alueen omat pikkujärvet suoksi: pohja täytetään ympäröivästä maasta (lähin rantaruutu) ja pehmennetään.
        near_idx = ndimage.distance_transform_edt(old_lakes, return_distances=False, return_indices=True)
        H2[old_lakes] = H2[near_idx[0], near_idx[1]][old_lakes] - 0.3
        soft = ndimage.binary_dilation(old_lakes, iterations=3)
        H2[soft] = ndimage.gaussian_filter(H2, 2.0)[soft]
        C2[old_lakes] = BOG
    mk = json.load(open(MOKKI_KARTTA))
    north_lakes = []
    nl_mask = np.zeros_like(box)
    for f in mk["features"]:
        if f["kind"] != "water" or f.get("name") not in NORTH_LAKES or len(f["pts"]) < 3:
            continue
        poly = [nl_t(q) for q in f["pts"]]
        m_ = VW.game_raster([poly], x0, z0, nx, nz, CELL) & ~near_route & (C2 != WATER)
        if m_.sum() < 20:
            continue
        d_out = ndimage.distance_transform_edt(~m_) * CELL
        ring = (~m_) & (d_out <= 40.0) & (C2 != BOG)
        lvl = float(np.percentile(H2[ring if ring.any() else (~m_) & (d_out <= 40.0)], 25)) - 0.5
        shore = (~m_) & (d_out < 45.0) & ~near_route
        t_ = np.sqrt(np.clip(d_out / 45.0, 0.0, 1.0))  # rannasta loivasti ylös, ei kuoppaa
        new_h = np.maximum(lvl + 0.15, lvl + 0.35 + (H2 - lvl - 0.35) * t_)
        H2[shore] = np.where(H2[shore] > lvl + 0.15, np.minimum(H2[shore], new_h[shore]), lvl + 0.15)
        H2[m_] = lvl - 1.2
        C2[m_] = WATER
        C2[shore & (d_out < 8.0) & (C2 == YARD)] = FOREST
        nl_mask |= m_
        cz_, cx_ = np.argwhere(m_).mean(0)
        north_lakes.append({"name": f["name"], "c": [round(float(x0 + cx_ * CELL), 1), round(float(z0 + cz_ * CELL), 1)],
                            "level": round(lvl, 2)})
    heights = [round(float(v), 3) for v in H2.ravel()]
    codes = C2.ravel().tolist()
    # Talot ja sivutiet pois järvistä.
    wet_g = ndimage.binary_dilation(nl_mask, iterations=1)

    def wet_at(q):
        i_, j_ = int(round((q[0] - x0) / CELL)), int(round((q[1] - z0) / CELL))
        return 0 <= i_ < nx and 0 <= j_ < nz and wet_g[j_, i_]

    out_buildings = [bd for bd in out_buildings if not any(wet_at(q) for q in bd["pts"])]
    cut_sr = []
    for r in side_roads:
        cur = []
        for q in r["pts"]:
            if wet_at(q):
                if len(cur) > 1:
                    cut_sr.append(dict(r, pts=cur))
                cur = []
            else:
                cur.append(q)
        if len(cur) > 1:
            cut_sr.append(dict(r, pts=cur))
    side_roads = cut_sr
    rails = [r for r in side_roads if r["kind"] == "rail"]
    print("Neittävän järviseutu:", [(nl["name"], nl["c"]) for nl in north_lakes],
          "| kohteet:", {nm: [round(v) for v in nl_t(q)] for nm, q in (("uimaranta", (16.0, -931.0)), ("Ranta-Rosvo", (-327.0, -1242.0)),
                                                                     ("laavu", (456.0, -1653.0)))})

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
    # Oulujoen ratasilta (teräsristikko, vaala.gd) samaan tasoon kuin tiesilta: kiskot joen yli kannen korkeudella ja
    # rannoilla nousu penkereellä (penger tehdään alikulun penkereen kanssa samalla tavalla).
    rb0, rb1 = bridges[-1]
    # Tiesillan lopullinen taso (vaala_silta_jarvi.py: suora viiva RAMP näytettä sillan päiden ulkopuolelta).
    bridge_y = (samples[max(rb0 - VS.RAMP, 0)]["y"] + samples[min(rb1 + VS.RAMP, n - 1)]["y"]) / 2.0
    bgrid_ = Grid([samples[k]["g"] for k in range(rb0, rb1 + 1)], 20.0)
    low = [(q[0], q[1]) for r in rails for q in r["pts"] if q[2] < water_level + 1.0 and bgrid_.nearest((q[0], q[1]), 150.0)[0] >= 0]
    river_ab = None
    if len(low) >= 2:
        river_ab = max(((a, b) for a in low for b in low), key=lambda ab: math.dist(ab[0], ab[1]))
        for r in rails:
            for q in r["pts"]:
                d_ = seg_dist((q[0], q[1]), river_ab[0], river_ab[1])[0]
                if d_ < RIVER_RAIL_RAMP:
                    q[2] = round(max(q[2], lerp(bridge_y, q[2], smooth(0.0, RIVER_RAIL_RAMP, d_))), 2)
        print("Oulujoen ratasilta %s - %s tasossa %.2f m" % ([round(v) for v in river_ab[0]], [round(v) for v in river_ab[1]], bridge_y))

    def near_river_rail(p, pad):
        return river_ab is not None and seg_dist(p, river_ab[0], river_ab[1])[0] < RIVER_RAIL_RAMP + pad
    if underpass is not None:
        us = samples[underpass["i"]]
        ug = us["g"]
        underpass["at"] = [round(ug[0], 2), round(ug[1], 2)]
        rd_ = underpass["rdir"]
        # Radan suunta pelissä: keskustan 1:1-alueella sama kuin todellinen.
        underpass["dir"] = [round(rd_[0], 4), round(rd_[1], 4)]
        underpass["road_y"] = round(us["y"], 2)
        underpass["hw"] = us["hw"]
        underpass["open"] = UNDER_OPEN
        underpass["slope"] = UNDER_SLOPE
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
                if math.dist((a[0], a[1]), ug) > 350.0 and math.dist((b[0], b[1]), ug) > 350.0 and \
                        not near_river_rail((a[0], a[1]), 40.0):
                    continue
                m = max(int(math.dist((a[0], a[1]), (b[0], b[1]))), 1)
                for t in range(m):
                    near_rail.append([lerp(a[0], b[0], t / m), lerp(a[1], b[1], t / m), lerp(a[2], b[2], t / m)])
        ng = Grid([(q[0], q[1]) for q in near_rail], 12.0)
        # Alikulun aukko: ajorata ja leveä piennar tien tasossa, sen takana penger nousee luiskana (UNDER_SLOPE) kannen
        # alle kuten videolla; vaala.gd _build_underpass: kansi pilareilla ja maatuet luiskien päällä.
        span = us["hw"] + UNDER_OPEN
        for j in range(nz):
            for i in range(nx):
                k = j * nx + i
                p = (x0 + i * CELL, z0 + j * CELL)
                if codes[k] == 255 or (math.dist(p, ug) > 360.0 and not near_river_rail(p, 30.0)):
                    continue
                if codes[k] == WATER or heights[k] < water_level + 0.3:
                    continue  # joki ja sen ranta jäävät ratasillan alle
                if river_ab is not None:
                    d_, t_ = seg_dist(p, river_ab[0], river_ab[1])
                    if d_ < 25.0 and 0.0 < t_ < 1.0:
                        continue  # sillan alla saaret ja rantatöyräät ennallaan (ei penkereen kärkiä joessa)
                qi, dr = ng.nearest(p, 16.0)
                if qi < 0:
                    continue
                top = near_rail[qi][2] - 0.1
                # Alikulun aukko: ajoradan kohta pysyy tien tasossa.
                rdist = math.sqrt(near_d.get(k, INF))
                if rdist < span:
                    continue
                emb = top - max(0.0, dr - 2.8) * 0.75
                emb = min(emb, us["y"] + 0.2 + (rdist - span) * UNDER_SLOPE)  # luiska aukon reunasta
                if emb > heights[k]:
                    heights[k] = round(emb, 3)
                    if dr < 2.8:
                        codes[k] = RAIL
                    elif codes[k] in (ROAD, SHOULDER, YARD, FOREST):
                        codes[k] = FIELD  # penkereen luiskat nurmella
        print("alikulku", underpass)
    # Kaukomaasto horisonttiin samalla kuvauksella; tarkan alueen alla hieman sen alapuolella (ettei rako näy).
    fx0 = x0 - FAR_MARGIN
    fz0 = z0 - FAR_MARGIN
    fnx = int((x0 + nx * CELL + FAR_MARGIN - fx0) / FAR_CELL) + 1
    fnz = int((z0 + nz * CELL + FAR_MARGIN - fz0) / FAR_CELL) + 1
    FX, FZ = np.meshgrid(fx0 + np.arange(fnx) * FAR_CELL, fz0 + np.arange(fnz) * FAR_CELL)
    _frx, _frz, FG, _fone, fcode = warp.inv(FX, FZ, rc)
    main_lake = (fcode == WATER) & (np.abs(FG - water_level) < 2.5)
    far_cut = main_lake & lake_cut(FX.ravel(), FZ.ravel())
    fcode = np.where(far_cut, FOREST, fcode)
    far_d = (ndimage.distance_transform_edt(far_cut.reshape(fnz, fnx)) * FAR_CELL).ravel()
    FG = np.where(far_cut, water_level + 0.4 + np.minimum(far_d * 0.03, 5.0), FG)
    main_lake &= ~far_cut
    FG = np.where(main_lake, water_level - 2.0, np.where(fcode == WATER, FG - 1.0, FG))
    far = [round(float(v), 2) for v in FG]
    for j in range(fnz):
        for i in range(fnx):
            x, z = fx0 + i * FAR_CELL, fz0 + j * FAR_CELL
            ci, cj = int((x - x0) / CELL), int((z - z0) / CELL)
            if 0 <= ci < nx and 0 <= cj < nz:
                far[j * fnx + i] = round(heights[cj * nx + ci] - 1.5, 2)

    with open(OUT_BIN, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, CELL))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(struct.pack("<iifff", fnx, fnz, fx0, fz0, FAR_CELL))
        f.write(struct.pack("<%df" % (fnx * fnz), *far))

    # --- Metsä: laserpuut käänteisotannalla samalla kuvauksella (vaala_warp.sample_trees). ---------------------
    rng = np.random.default_rng(1170)
    te, tn, th = laser.trees(rng, lambda a, b: np.zeros(len(a), bool))
    tsp = T.Species(args.cache, laser.e0, laser.n0, laser.e1, laser.n1)(rng, te, tn, th)
    tfx, tfz = T.tm_to_frame(te, tn)
    tfx, tfz = np.asarray(tfx, np.float64), np.asarray(tfz, np.float64)
    CODE2 = np.asarray(codes, np.uint8).reshape(nz, nx)
    ok = np.isin(CODE2, (FOREST, BOG, YARD))
    # Torin kiveys ja Gasthausin edusta (vaala.gd _build_tori, _gasthaus_front) aukeiksi.
    tori = [r["pts"] for r in side_roads if r.get("name") == "Vaalan tori"]
    gast = [bd["pts"] for bd in out_buildings if bd["id"] == GASTHAUS_ID]
    clear = VW.game_raster(tori, x0, z0, nx, nz, CELL)
    if gast:
        clear |= ndimage.distance_transform_edt(~VW.game_raster(gast, x0, z0, nx, nz, CELL)) * CELL < 14.0
    ok &= ~clear
    road_mask = VW.game_raster([], x0, z0, nx, nz, CELL, [[smp["g"] for smp in samples]], CELL)
    keep_small = ndimage.distance_transform_edt(~road_mask) * CELL < 250.0
    re_, rn_ = T.frame_to_tm(RX.ravel(), RZ.ravel())
    inside = laser.chm_at(re_, rn_, laser.covered) & ~LAKE_CUT.ravel()  # järvestä tullut maa: luonnollinen metsä
    tx, tz, thh, tss = VW.sample_trees(rng, tfx, tfz, np.asarray(th, np.float32), np.asarray(tsp, np.uint8), inside,
                                       GX.ravel(), GZ.ravel(), RX.ravel(), RZ.ravel(), ok.ravel(), keep_small.ravel())
    # Kaukomaaston metsä (tarkan alueen ulkopuolella) harvana: muutama puu kaukoruutua kohti.
    out_fine = (FX < x0) | (FX > x0 + (nx - 1) * CELL) | (FZ < z0) | (FZ > z0 + (nz - 1) * CELL)
    fsel = np.repeat(np.nonzero(out_fine.ravel() & (fcode.ravel() == FOREST))[0], 6)
    fpx = FX.ravel()[fsel] + rng.uniform(-FAR_CELL / 2, FAR_CELL / 2, len(fsel))
    fpz = FZ.ravel()[fsel] + rng.uniform(-FAR_CELL / 2, FAR_CELL / 2, len(fsel))
    _frx, _frz, fgy, _fone, fpc = warp.inv(fpx, fpz, rc)
    fok = (fpc == FOREST) | ((fpc == WATER) & lake_cut(fpx, fpz))
    fh = np.clip(rng.normal(17.0, 4.0, len(fsel)), 8.0, 26.0)
    fs = rng.choice([0, 1, 2], len(fsel), p=[0.6, 0.25, 0.15])
    ty = np.array([grid_h((float(a), float(b))) for a, b in zip(tx, tz)], np.float32)
    tx = np.concatenate([tx, fpx[fok]]).astype(np.float32)
    tz = np.concatenate([tz, fpz[fok]]).astype(np.float32)
    ty = np.concatenate([ty, fgy[fok] - 0.2]).astype(np.float32)
    thh = np.concatenate([thh, fh[fok]]).astype(np.float32)
    tss = np.concatenate([tss, fs[fok]]).astype(np.uint8)
    T.write_trees(OUT_TREES, tx, ty, tz, thh, tss, rng)

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
        "town_off": [round(town_off[0], 2), round(town_off[1], 2)], "lava_off": [round(west_off[0], 2), round(west_off[1], 2)],
        "s_t": round(S_T, 1), "town_k": TOWN_K,
        "siitari": [round(sx + town_off[0], 2), round(sz + town_off[1], 2)], "water_level": round(water_level, 2),
        "names": sorted({smp["name"] for smp in samples}),
        "road": [[round(smp["g"][0], 2), round(smp["y"], 2), round(smp["g"][1], 2), round(smp["s"], 1),
                  smp["hw"], 1 if smp["surf"] == "gravel" else 0, 1 if smp["bridge"] else 0] for smp in samples],
        "road_names": [smp["name"] for smp in samples],
        "bridges": bridges, "signs": signs, "branches": [{k2: v for k2, v in b.items() if k2 != "real"} for b in branches], "buildings": out_buildings, "side_roads": side_roads,
        "water": out_water, "parkings": parkings, "river_half": RIVER_HALF,
        "underpass": {k2: v for k2, v in underpass.items() if k2 not in ("real", "rdir")} if underpass else None,
        "mokki_warp": mokki_warp,
        "north_lakes": north_lakes,
        "mokki_map": {"ref": list(NL_REF), "c": list(NL_C), "s": list(NL_S), "blend": list(NL_BLEND)},
    }
    with open(OUT_JSON, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("kirjoitettu", OUT_JSON, os.path.getsize(OUT_JSON) // 1024, "kt;", OUT_BIN, os.path.getsize(OUT_BIN) // 1024, "kt;",
          "rakennuksia", len(out_buildings), "sivuteitä", len(side_roads), "kylttejä", len(signs))
    # Oulujärven lava oikealle paikalleen (tarkan alueen ulkopuolella): tontti, Pahalahdentie ja puut.
    VL.apply(args.cache)
    # Oulujoen silta suoraksi ja tasaiseksi, Oulujärvi kaukomaaston luoteiskulmaan.
    VS.apply()
    # K-Market Siitarin viereen, puut pois rakennuksista, parkeista ja teiltä.
    VK.apply()
    # Puut pois sivuteiltä, kaduilta, poluilta, radoilta ja parkkipaikoilta (tie.json on nyt valmis).
    PT.filter_vaala()


if __name__ == "__main__":
    main()
