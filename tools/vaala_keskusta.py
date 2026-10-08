#!/usr/bin/env python3
"""Vaalan keskustan siistintä mopomatkan dataan (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo: python3 tools/vaala_keskusta.py   (vaala_bake.py ajaa tämän lopuksi lavan jälkeen)

- K-Market Tervaportti siirretään oikealta paikaltaan (Vaalantie 26, n. 400 m Siitarista) Vaalantien varteen
  Siitarin lounaispuolelle, jotta kauppa ja sen seinän pankkiautomaatti ovat Siitarin vieressä. Uusi pohja on
  suorakaide pitkä sivu tielle päin (ovi ja kyltti tien puolella, vaala.gd), eteen parkkipaikka. Tontin ja
  parkkipaikan maasto pihaksi ja tasaiseksi, reunat liitetään ympäristöön pehmeästi.
- Gasthaus (OSM 534430535, torin laidalta) Siitaria vastapäätä tien toiselle puolelle (julkisivu tielle). Tori tien
  päähän: mopotie päättyy Siitarin pihalenkkiin, ja tori on lenkin kohdalla Siitarin vieressä (Siitari länsilaidalla),
  Zabuki torin itäpäädyssä tiski torille päin. Alta jäävät talot, polut ja parkki poistetaan, tontit ja tori
  tasoitetaan pihaksi. vaala.gd lukee Zabukin paikan ja julkisivut tie.json:sta ("keskusta": "zabuki",
  "gasthaus_face"), tori on "Vaalan tori".
- Puut pois rakennusten sisältä ja vierestä, parkkipaikoilta ja ajoradoilta: laserkeilauksen latvusmallin
  maksimeista tunnistuu "puiksi" myös kattoja, jotka kasvoivat pelissä seinien ja kattojen läpi. Siitarin ympäriltä
  raivataan piha, ettei ovi avaudu suoraan metsään.
Ajo on toistettavissa: K-Marketin ja Gasthausin alkuperäiset pohjat, poistetut talot ja polut, torin alkuperäinen
muoto ja muutettujen maastoruutujen alkuarvot ovat tie.json:ssa ("keskusta"), ja ne palautetaan ennen uutta ajoa.
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
KMARKET_ID = 225699583
SIITARI_ID = 225699578
SIITARI_YARD = 10.0  # Siitarin ympäriltä puut pois (ovi ja terassi eivät avaudu metsään)
KM_FROM_END = 68     # Vaalantien näyte (tien lopusta laskien), jonka kohdalle kauppa tulee (Siitarista n. 45 m lounaaseen)
KM_SIZE = (27.0, 18.0)  # julkisivu tielle x syvyys
KM_SETBACK = 28.0    # tien keskiviivasta rakennuksen keskelle (edessä parkkipaikka)
PARK_DEPTH = 12.0
BUILD_MARGIN = 2.0   # puut näin kauas seinistä
PARK_MARGIN = 1.0
ROAD_MARGIN = 1.5    # tien reunasta
GASTHAUS_ID = 534430535
GH_SETBACK = 9.0     # Gasthausin julkisivu näin kauas ajoradan reunasta (piha mopolle)
ZB_SIZE = (9.0, 5.0)  # Zabukin kioski (vaala.gd _build_zabuki): leveys x syvyys
# Tori Siitarin puolella tien päässä tien suuntaisessa kehyksessä (u tien suuntaan Siitarin kohdalta, v poispäin
# tiestä Siitarin puolelle): pihalenkki kulkee torin länsiosan halki, Siitari on sen länsilaidalla.
TORI_U = (18.0, 56.0)
TORI_V = (5.5, 26.0)
ZB_END = 2.0         # Zabukin takaseinä näin kauas torin itäreunasta
# Liikenneympyrä Zabukin jälkeen Vaalantien, Ratatien ja Koulutien risteykseen (samassa kehyksessä kuin tori); siitä
# oikealle Ratatietä rautatieasemalle, joka on todellisella paikallaan radan varressa (laituri PLAT_L x PLAT_W).
RB_U = 68.0
RB_R = 12.0
PLAT_L = 70.0
PLAT_W = 3.0
STATION_ID = 178199720  # Vaalan rautatieasema (OSM): pelin asema omalla paikallaan (vaala.gd _build_station)
OLD_STATION_ID = STATION_ID


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
    return math.hypot(p[0] - a[0] - ax * t, p[1] - a[1] - az * t)


def poly_dist(p, poly):
    """0 sisällä, muuten etäisyys reunasta."""
    if in_poly(p, poly):
        return 0.0
    return min(seg_dist(p, poly[i], poly[(i + 1) % len(poly)]) for i in range(len(poly)))


def bbox(poly, grow):
    xs = [q[0] for q in poly]
    zs = [q[1] for q in poly]
    return (min(xs) - grow, min(zs) - grow, max(xs) + grow, max(zs) + grow)


def rect(c, ax, az, hx, hz):
    return [[round(c[0] + ax[0] * sx * hx + az[0] * sz * hz, 2), round(c[1] + ax[1] * sx * hx + az[1] * sz * hz, 2)]
            for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]


def place_tori(tie, flatten):
    """Gasthaus Siitaria vastapäätä, tori tien päähän Siitarin viereen ja Zabuki torin itäpäätyyn."""
    road = tie["road"]
    sx, sz = tie["siitari"]
    # Siitarin kohta tiellä: näyte, jonka kohdalla Siitari on suoraan sivulla (tien lopun lenkki parkkiin pois).
    last = len(road) - 30
    ki = min(range(last - 120, last), key=lambda i: abs((sx - road[i][0]) * (road[i + 2][0] - road[i - 2][0])
                                                        + (sz - road[i][2]) * (road[i + 2][2] - road[i - 2][2])))
    a, b = road[ki - 4], road[ki + 4]
    L = math.hypot(b[0] - a[0], b[2] - a[2])
    ax = ((b[0] - a[0]) / L, (b[2] - a[2]) / L)  # tien suunta keskustaan
    away = (-ax[1], ax[0])                         # poispäin Siitarista
    rp = (road[ki][0], road[ki][2])
    if (sx - rp[0]) * away[0] + (sz - rp[1]) * away[1] > 0.0:
        away = (-away[0], -away[1])
    hw = road[ki][4]
    at = lambda u, v: (rp[0] + ax[0] * u + away[0] * v, rp[1] + ax[1] * u + away[1] * v)  # noqa: E731

    gh = next(b for b in tie["buildings"] if b["id"] == GASTHAUS_ID)
    gh_orig = gh["pts"]
    # Gasthausin mitat alkuperäisestä pohjasta: pisin sivu julkisivuksi tielle.
    pts = gh_orig[:-1] if gh_orig[0] == gh_orig[-1] else gh_orig
    e = max(zip(pts, pts[1:] + pts[:1]), key=lambda s: math.dist(s[0], s[1]))
    el = math.dist(e[0], e[1])
    eu = ((e[1][0] - e[0][0]) / el, (e[1][1] - e[0][1]) / el)
    us = [q[0] * eu[0] + q[1] * eu[1] for q in pts]
    vs = [-q[0] * eu[1] + q[1] * eu[0] for q in pts]
    gl, gw = max(us) - min(us), max(vs) - min(vs)
    gc = at(0.0, hw + GH_SETBACK + gw / 2.0)
    gh["pts"] = rect(gc, ax, away, gl / 2.0, gw / 2.0)
    tv = -(TORI_V[0] + TORI_V[1]) / 2.0  # Siitarin puoli on -away
    tc = at((TORI_U[0] + TORI_U[1]) / 2.0, tv)
    tori = rect(tc, ax, away, (TORI_U[1] - TORI_U[0]) / 2.0, (TORI_V[1] - TORI_V[0]) / 2.0)
    zu = TORI_U[1] - ZB_END - ZB_SIZE[1] / 2.0
    zc = at(zu, tv)
    face = (-ax[0], -ax[1])  # tiski länteen torille ja Siitarille päin

    # Tontit: Gasthaus pihoineen, tori ja Zabuki.
    g_lot = rect(at(0.0, hw + 1.0 + (GH_SETBACK - 1.0 + gw) / 2.0), ax, away, gl / 2.0 + 2.0, (GH_SETBACK - 1.0 + gw) / 2.0)
    z_lot = rect(zc, ax, away, ZB_SIZE[1] / 2.0 + 1.5, ZB_SIZE[0] / 2.0 + 1.5)
    lots = [g_lot, z_lot, tori]
    # Torin alle jäävät parkkipaikat pois (palautetaan uudessa ajossa).
    removed_parks = [pk for pk in tie["parkings"] if any(in_poly(q, tori) for q in pk) or any(in_poly(q, pk) for q in tori)]
    tie["parkings"] = [pk for pk in tie["parkings"] if pk not in removed_parks]
    keep = (SIITARI_ID, KMARKET_ID, GASTHAUS_ID)
    removed = []
    for bd in tie["buildings"]:
        if bd["id"] == GASTHAUS_ID:
            continue
        hit = any(in_poly(q, bd["pts"]) for p in lots for q in p) or \
            min(poly_dist(q, p) for p in lots for q in bd["pts"]) < 2.0
        if hit:
            if bd["id"] in keep:
                raise SystemExit("torin paikka osuu rakennukseen %s" % bd["id"])
            removed.append(bd)
    tie["buildings"] = [b for b in tie["buildings"] if b not in removed]

    # Polut ja pikkutiet tonttien kohdalta pois (pätkiksi); Vaalantie ja muut isot kadut eivät saa osua.
    cut_roads = []
    pieces = []
    tori_pts = None
    for k, sr in enumerate(tie["side_roads"]):
        if sr.get("name") == "Vaalan tori":
            tori_pts = sr["pts"]
            continue
        if sr["kind"] == "rail":
            continue
        dense = []
        for a2, b2 in zip(sr["pts"], sr["pts"][1:]):
            n = max(1, int(math.dist(a2[:2], b2[:2]) / 2.0))
            dense += [[a2[0] + (b2[0] - a2[0]) * t / n, a2[1] + (b2[1] - a2[1]) * t / n] for t in range(n + 1)]
        big = sr["hw"] in ("secondary", "tertiary", "primary")
        if not any(poly_dist(q, p) < (0.01 if big else 1.5) for p in lots for q in dense):
            continue
        if big:
            raise SystemExit("torin paikka osuu katuun %s" % sr.get("name", ""))
        cut_roads.append([k, sr])
        cur = []
        for a2, b2 in zip(sr["pts"], sr["pts"][1:]):
            n = max(1, int(math.dist(a2[:2], b2[:2]) / 2.0))
            for t in range(n + 1):
                q = [round(a2[0] + (b2[0] - a2[0]) * t / n, 2), round(a2[1] + (b2[1] - a2[1]) * t / n, 2)]
                if any(poly_dist(q, p) < 1.5 for p in lots):
                    if len(cur) > 1:
                        pieces.append(dict(sr, pts=cur, _kesk=1))
                    cur = []
                elif not cur or cur[-1] != q:
                    cur.append(q)
        if len(cur) > 1:
            pieces.append(dict(sr, pts=cur, _kesk=1))
    for k, _sr in reversed(cut_roads):
        del tie["side_roads"][k]
    tie["side_roads"] += pieces
    for sr in tie["side_roads"]:
        if sr.get("name") == "Vaalan tori":
            sr["pts"] = tori + [tori[0]]
    flat = flatten(lots, 8.0)
    print("Gasthaus Siitaria vastapäätä", [round(v, 1) for v in gc], "%.0f x %.0f m" % (gl, gw),
          "| Zabuki", [round(v, 1) for v in zc], "| tori", [round(v, 1) for v in tc], "%.1f m" % flat,
          "| poistettu talot", [b["id"] for b in removed], "| katkaistu polkuja", len(cut_roads), "| parkkeja pois", len(removed_parks))
    return {"zabuki": {"c": [round(zc[0], 2), round(zc[1], 2)], "face": [round(face[0], 4), round(face[1], 4)]},
            "gasthaus_face": [round(-away[0], 4), round(-away[1], 4)],
            "tori": {"gasthaus_pts": gh_orig, "removed": removed, "cut_roads": cut_roads, "tori_pts": tori_pts,
                     "parkings": removed_parks}}


def place_station(tie, flatten):
    """Liikenneympyrä Vaalantielle Zabukin jälkeen (Ratatie oikealle) ja rautatieasema todellisen asemarakennuksen
    paikalle radan varteen: laituri radan ja aseman väliin radan suuntaisesti, ovi kadun puolelle ja asfaltoitu
    ajotie lähimmältä kadulta ovelle. Rakennuksia ei siirretä."""
    road = tie["road"]
    sx, sz = tie["siitari"]
    last = len(road) - 30
    ki = min(range(last - 120, last), key=lambda i: abs((sx - road[i][0]) * (road[i + 2][0] - road[i - 2][0])
                                                        + (sz - road[i][2]) * (road[i + 2][2] - road[i - 2][2])))
    a, b = road[ki - 4], road[ki + 4]
    L = math.hypot(b[0] - a[0], b[2] - a[2])
    ax = ((b[0] - a[0]) / L, (b[2] - a[2]) / L)
    away = (-ax[1], ax[0])
    rp = (road[ki][0], road[ki][2])
    if (sx - rp[0]) * away[0] + (sz - rp[1]) * away[1] > 0.0:
        away = (-away[0], -away[1])
    rb_c = (rp[0] + ax[0] * RB_U + away[0] * 0.5, rp[1] + ax[1] * RB_U + away[1] * 0.5)
    st = next(bd for bd in tie["buildings"] if bd["id"] == STATION_ID)
    pts = st["pts"][:-1] if st["pts"][0] == st["pts"][-1] else st["pts"]
    c = (sum(q[0] for q in pts) / len(pts), sum(q[1] for q in pts) / len(pts))
    # Lähin pääradan kohta ja suunta.
    best = (1e9, None, None)
    for sr in tie["side_roads"]:
        if sr["kind"] != "rail":
            continue
        for p0, p1 in zip(sr["pts"], sr["pts"][1:]):
            d, t = seg_dist2(c, p0[:2], p1[:2])
            if d < best[0]:
                best = (d, (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t), (p1[0] - p0[0], p1[1] - p0[1]))
    _d, rpt, rdir = best
    rl = math.hypot(*rdir)
    ra = (rdir[0] / rl, rdir[1] / rl)
    n = (rpt[0] - c[0], rpt[1] - c[1])
    nl = math.hypot(*n)
    n = (n[0] / nl, n[1] / nl)  # asemalta radalle
    depth = max(abs((q[0] - c[0]) * n[0] + (q[1] - c[1]) * n[1]) for q in pts)
    pc = (rpt[0] - n[0] * (1.6 + 0.5 + PLAT_W / 2.0), rpt[1] - n[1] * (1.6 + 0.5 + PLAT_W / 2.0))
    platform = rect(pc, ra, n, PLAT_L / 2.0, PLAT_W / 2.0)
    door = (c[0] - n[0] * (depth + 0.4), c[1] - n[1] * (depth + 0.4))
    out = (-n[0], -n[1])
    # Ajotie lähimmältä kadulta oven eteen.
    best = (1e9, None)
    for sr in tie["side_roads"]:
        if sr["kind"] != "road" or sr["hw"] not in ("residential", "tertiary", "secondary"):
            continue  # kunnon katu (Ratatie, Asematie), joka jatkuu liikenneympyrään
        for p0, p1 in zip(sr["pts"], sr["pts"][1:]):
            d, t = seg_dist2(door, p0[:2], p1[:2])
            if d < best[0]:
                best = (d, (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t))
    front = (door[0] + out[0] * 6.0, door[1] + out[1] * 6.0)
    access = [best[1], front, (door[0] + out[0] * 1.5, door[1] + out[1] * 1.5)]
    a_lot = [list(q) for q in access]
    # Laiturin ja ajotien kohdalta polut pois.
    cut_roads = []
    pieces = []
    for k, sr in enumerate(tie["side_roads"]):
        if sr["kind"] == "rail" or sr.get("name") == "Vaalan tori":
            continue

        def gone(q):
            return math.dist(q[:2], rb_c) < RB_R - 0.5 or poly_dist(q, platform) < 1.0 or \
                (sr["hw"] in ("footway", "path", "cycleway", "track") and min(seg_dist(q, a_lot[i], a_lot[i + 1]) for i in range(2)) < 3.0)
        dense = []
        for a2, b2 in zip(sr["pts"], sr["pts"][1:]):
            m = max(1, int(math.dist(a2[:2], b2[:2]) / 2.0))
            dense += [[round(a2[0] + (b2[0] - a2[0]) * t / m, 2), round(a2[1] + (b2[1] - a2[1]) * t / m, 2)] for t in range(m + 1)]
        if not any(gone(q) for q in dense):
            continue
        cut_roads.append([k, sr])
        cur = []
        for q in dense:
            if gone(q):
                if len(cur) > 1:
                    pieces.append(dict(sr, pts=cur, _asema=1))
                cur = []
            elif not cur or cur[-1] != q:
                cur.append(q)
        if len(cur) > 1:
            pieces.append(dict(sr, pts=cur, _asema=1))
    for k, _sr in reversed(cut_roads):
        del tie["side_roads"][k]
    tie["side_roads"] += pieces
    tie["side_roads"].append({"kind": "road", "hw": "service", "name": "Aseman piha", "surface": "asphalt", "_asema": 1,
                              "pts": [[round(q[0], 2), round(q[1], 2)] for q in access]})
    flatten([rect(rb_c, ax, away, RB_R + 1.0, RB_R + 1.0)], 6.0)
    print("Liikenneympyrä", [round(v, 1) for v in rb_c], "| asema", [round(v, 1) for v in c], "radalta %.1f m" % nl,
          "| ajotie %.0f m kadulta" % best[0], "| katkaistu teitä", len(cut_roads))
    return {"id": STATION_ID, "pts": pts, "door": [round(door[0], 2), round(door[1], 2)], "out": [round(out[0], 4), round(out[1], 4)],
            "along": [round(ra[0], 4), round(ra[1], 4)], "platform": platform, "track": [],
            "roundabout": {"c": [round(rb_c[0], 2), round(rb_c[1], 2)], "r": RB_R}, "cut_roads": cut_roads, "old": None}


def seg_dist2(p, a, b):
    """Etäisyys janasta ja janan parametri t."""
    dx, dz = b[0] - a[0], b[1] - a[1]
    L2 = dx * dx + dz * dz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / L2))
    return math.hypot(p[0] - a[0] - dx * t, p[1] - a[1] - dz * t), t


def apply():
    tie = json.load(open(TIE))
    raw = open(MAASTO, "rb").read()
    nx, nz, x0, z0, cell = struct.unpack_from("<iifff", raw, 0)
    o = 20
    heights = list(struct.unpack_from("<%df" % (nx * nz), raw, o))
    o += nx * nz * 4
    codes = bytearray(raw[o:o + nx * nz])
    o += nx * nz
    rest = raw[o:]

    # --- Edellinen ajo pois. ---------------------------------------------------------------------------------
    prev = tie.pop("keskusta", None)
    if prev:
        for k, hv, cv in reversed(prev["cells"]):  # sama ruutu voi olla kahdesti: alkuperäinen arvo viimeiseksi
            heights[k] = hv
            codes[k] = cv
        if "asema" in prev:
            # Asema ensin pois (sen katkaisut ovat torin muutosten jälkeisessä listassa).
            st_ = prev["asema"]
            tie["side_roads"] = [r for r in tie["side_roads"] if not r.get("_asema")]
            for k, r in st_["cut_roads"]:
                tie["side_roads"].insert(k, r)
            if st_.get("old"):
                for b in tie["buildings"]:
                    if b["id"] == OLD_STATION_ID:
                        b.update(st_["old"])
        if "tori" in prev:
            # Torin muutokset ensin pois (K-Marketin sivutieindeksit viittaavat tilaan ennen niitä).
            t = prev["tori"]
            tie["side_roads"] = [r for r in tie["side_roads"] if not r.get("_kesk")]
            for k, r in t["cut_roads"]:
                tie["side_roads"].insert(k, r)
            for r in tie["side_roads"]:
                if r.get("name") == "Vaalan tori":
                    r["pts"] = t["tori_pts"]
            tie["buildings"] += t["removed"]
            tie["parkings"] += t.get("parkings", [])
            for b in tie["buildings"]:
                if b["id"] == GASTHAUS_ID:
                    b["pts"] = t["gasthaus_pts"]
        tie["parkings"] = [p for p in tie["parkings"] if p != prev["parking"]]
        for k, pts in prev["side_roads"]:
            tie["side_roads"][k]["pts"] = pts
        for b in tie["buildings"]:
            if b["id"] == KMARKET_ID:
                b["pts"] = prev["kmarket_pts"]

    km = next(b for b in tie["buildings"] if b["id"] == KMARKET_ID)
    orig_pts = km["pts"]

    # --- K-Market Siitarin viereen. --------------------------------------------------------------------------
    road = tie["road"]
    ki = len(road) - KM_FROM_END
    a, b = road[ki - 4], road[ki + 4]
    d = (b[0] - a[0], b[2] - a[2])
    L = math.hypot(*d)
    ax = (d[0] / L, d[1] / L)  # tien suunta
    az = (-ax[1], ax[0])       # poispäin tiestä (Siitarin puolelle)
    sx, sz = tie["siitari"]
    rp = (road[ki][0], road[ki][2])
    if (sx - rp[0]) * az[0] + (sz - rp[1]) * az[1] < 0.0:
        az = (-az[0], -az[1])
    c = (rp[0] + az[0] * KM_SETBACK, rp[1] + az[1] * KM_SETBACK)
    km["pts"] = rect(c, ax, az, KM_SIZE[0] / 2.0, KM_SIZE[1] / 2.0)
    pc = (c[0] - az[0] * (KM_SIZE[1] / 2.0 + PARK_DEPTH / 2.0), c[1] - az[1] * (KM_SIZE[1] / 2.0 + PARK_DEPTH / 2.0))
    parking = rect(pc, ax, az, KM_SIZE[0] / 2.0 + 4.0, PARK_DEPTH / 2.0)
    tie["parkings"].append(parking)

    # Tontti (rakennus + parkki) tasaiseksi, pehmeä liitos 8 m:llä; ruudut pihaksi. Ei saa osua muihin.
    lot = rect(((c[0] + pc[0]) / 2.0, (c[1] + pc[1]) / 2.0), ax, az, KM_SIZE[0] / 2.0 + 4.0,
               (KM_SIZE[1] + PARK_DEPTH) / 2.0)
    for other in tie["buildings"]:
        if other is not km and (min(poly_dist(q, lot) for q in other["pts"]) < 2.0
                                or any(in_poly(q, other["pts"]) for q in lot)):
            raise SystemExit("K-Marketin uusi paikka osuu rakennukseen %s %s" % (other["id"], other["name"]))
    # Rakennuksen läpi kulkevat sivutiet kiertämään lähemmän päädyn kautta (parkin poikki saa ajaa).
    moved_roads = []
    house = rect(c, ax, az, KM_SIZE[0] / 2.0 + 3.0, KM_SIZE[1] / 2.0 + 3.0)
    for k, sr in enumerate(tie["side_roads"]):
        dense = []
        for a, b in zip(sr["pts"], sr["pts"][1:]):
            n = max(1, int(math.dist(a[:2], b[:2]) / 2.0))
            dense += [[a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n] for t in range(n)]
        dense.append(sr["pts"][-1][:2])
        if not any(in_poly(q, house) for q in dense):
            continue
        moved_roads.append([k, sr["pts"]])
        out = []
        for q in dense:
            if in_poly(q, house):
                u = (q[0] - c[0]) * ax[0] + (q[1] - c[1]) * ax[1]
                v = (q[0] - c[0]) * az[0] + (q[1] - c[1]) * az[1]
                u = math.copysign(KM_SIZE[0] / 2.0 + 3.0, u)
                q = [c[0] + ax[0] * u + az[0] * v, c[1] + ax[1] * u + az[1] * v]
            out.append([round(q[0], 2), round(q[1], 2)])
        sr["pts"] = out
        print("sivutie kiertämään kaupan päädyn:", sr["hw"], sr.get("name", ""))
    cells = []

    def flatten(lots, yard=6.0):
        """Tontit tasaiseksi (yhteinen keskikorkeus), pehmeä liitos 8 m:llä; ruudut pihaksi yard m:n päähän."""
        bxs = [bbox(p, 12.0) for p in lots]
        fx0, fz0 = min(b[0] for b in bxs), min(b[1] for b in bxs)
        fx1, fz1 = max(b[2] for b in bxs), max(b[3] for b in bxs)
        inner = []
        near = []
        for j in range(max(0, int((fz0 - z0) / cell)), min(nz, int((fz1 - z0) / cell) + 2)):
            for i in range(max(0, int((fx0 - x0) / cell)), min(nx, int((fx1 - x0) / cell) + 2)):
                k = j * nx + i
                if codes[k] == OUTSIDE:
                    continue
                dd = min(poly_dist((x0 + i * cell, z0 + j * cell), p) for p in lots)
                if dd < 0.01:
                    inner.append(heights[k])
                if dd <= 8.0 and codes[k] not in (ROAD, RAIL, WATER):
                    near.append((k, dd))
        flat = sum(inner) / len(inner)
        for k, dd in near:
            cells.append([k, heights[k], codes[k]])
            t = max(0.0, (dd - 3.0) / 5.0)
            t = t * t * (3.0 - 2.0 * t)
            heights[k] = round(flat + (heights[k] - flat) * t, 3)
            if dd < yard and codes[k] != SHOULDER:
                codes[k] = YARD
        return flat

    flat = flatten([lot])
    tori = place_tori(tie, flatten)
    asema = place_station(tie, flatten)
    tie["keskusta"] = {"kmarket_pts": orig_pts, "parking": parking, "cells": cells, "side_roads": moved_roads}
    tie["keskusta"].update(tori)
    tie["keskusta"]["asema"] = asema

    with open(TIE, "w") as f:
        json.dump(tie, f, ensure_ascii=False, separators=(",", ":"))
    with open(MAASTO, "wb") as f:
        f.write(struct.pack("<iifff", nx, nz, x0, z0, cell))
        f.write(struct.pack("<%df" % (nx * nz), *heights))
        f.write(bytes(codes))
        f.write(rest)

    def ground(x, z):
        fx, fz = (x - x0) / cell, (z - z0) / cell
        i, j = min(max(int(fx), 0), nx - 2), min(max(int(fz), 0), nz - 2)
        u, v = min(max(fx - i, 0.0), 1.0), min(max(fz - j, 0.0), 1.0)
        q = j * nx + i
        if u + v <= 1.0:
            return heights[q] + (heights[q + 1] - heights[q]) * u + (heights[q + nx] - heights[q]) * v
        return heights[q + nx + 1] + (heights[q + nx] - heights[q + nx + 1]) * (1.0 - u) \
            + (heights[q + 1] - heights[q + nx + 1]) * (1.0 - v)

    def code_at(x, z):
        i, j = int(round((x - x0) / cell)), int(round((z - z0) / cell))
        return codes[j * nx + i] if 0 <= i < nx and 0 <= j < nz else OUTSIDE

    # --- Puut pois rakennuksista, parkeista ja teiltä. ---------------------------------------------------------
    G = 32.0
    grid = {}

    def add(kind, poly, grow):
        bx = bbox(poly, grow)
        for gi in range(int(math.floor(bx[0] / G)), int(math.floor(bx[2] / G)) + 1):
            for gj in range(int(math.floor(bx[1] / G)), int(math.floor(bx[3] / G)) + 1):
                grid.setdefault((gi, gj), []).append((kind, poly, grow))
    for bd in tie["buildings"]:
        add("poly", bd["pts"], SIITARI_YARD if bd["id"] == SIITARI_ID else BUILD_MARGIN)
    for sr in tie["side_roads"]:
        if sr.get("name") == "Vaalan tori":
            add("poly", [q[:2] for q in sr["pts"][:-1]], PARK_MARGIN)
    for p in tie["parkings"]:
        add("poly", p, PARK_MARGIN)
    # Asema, laituri, asemaraide ja liikenneympyrä (place_station) puista vapaiksi.
    ast = tie["keskusta"]["asema"]
    add("poly", ast["pts"], 3.0)
    add("poly", ast["platform"], 1.5)
    rbc = ast["roundabout"]["c"]
    rbr = ast["roundabout"]["r"]
    add("poly", [[rbc[0] + rbr * math.cos(k * math.pi / 8), rbc[1] + rbr * math.sin(k * math.pi / 8)] for k in range(16)], 1.5)
    for k in range(len(road) - 1):
        r0, r1 = road[k], road[k + 1]
        add("line", [(r0[0], r0[2]), (r1[0], r1[2])], r0[4] + ROAD_MARGIN)
    for sr in tie["side_roads"]:
        hw = 3.0 if sr["hw"] in ("secondary", "tertiary", "residential", "unclassified", "service") else 1.2
        for k in range(len(sr["pts"]) - 1):
            add("line", [tuple(sr["pts"][k][:2]), tuple(sr["pts"][k + 1][:2])], hw + 0.5)

    def blocked(x, z):
        if code_at(x, z) in (ROAD, RAIL):
            return True
        for kind, poly, grow in grid.get((int(math.floor(x / G)), int(math.floor(z / G))), ()):
            if kind == "poly":
                bx = bbox(poly, grow)
                if bx[0] <= x <= bx[2] and bx[1] <= z <= bx[3] and poly_dist((x, z), poly) < grow:
                    return True
            elif seg_dist((x, z), poly[0], poly[1]) < grow:
                return True
        return False

    buf = bytearray(open(PUUT, "rb").read())
    assert buf[:4] == b"ONP3"
    count, _W, _H, _fc, _nc, _ox, _oz, pnfx, pnfz, pnnx, pnnz = struct.unpack_from("<IIIffffIIII", buf, 4)
    t0 = 4 + 44 + (pnfx * pnfz + pnnx * pnnz) * 5 * 8
    removed = moved = 0
    changed = {k for k, _h, _c in cells}
    for n in range(count):
        q = t0 + n * 16
        x, y, z, h = struct.unpack_from("<ffff", buf, q)
        if h <= 0.0:
            continue
        if blocked(x, z):
            struct.pack_into("<f", buf, q + 12, 0.0)
            removed += 1
        elif int(round((z - z0) / cell)) * nx + int(round((x - x0) / cell)) in changed and abs(ground(x, z) - y) > 0.01:
            struct.pack_into("<f", buf, q + 4, ground(x, z))
            moved += 1
    with open(PUUT, "wb") as f:
        f.write(buf)
    print("K-Market Tervaportti", [round(v, 1) for v in c], "Siitarista %.0f m" % math.dist(c, (sx, sz)),
          "| tontti %.1f m, %d ruutua" % (flat, len(cells)), "| puita pois %d (yht. %d), korkeus uuteen maahan %d" % (
              removed, count, moved))


if __name__ == "__main__":
    apply()
