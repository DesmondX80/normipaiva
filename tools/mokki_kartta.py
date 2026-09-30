#!/usr/bin/env python3
"""Mökin ympäristön karttadata (assets/mokki/kartta.json) OpenStreetMapista ja EU-DEM-korkeusmallista.

Ajo: python3 tools/mokki_kartta.py   (verkkoyhteys: overpass-api.de ja api.opentopodata.org, n. 2 min)
     python3 tools/mokki_kartta.py --levels   (vain vesistöjen pinnat uudelleen, ilman verkkohakuja)

- Kohteet 2 x 2 km neliöltä osoitepisteen (Kaisuantie 62, Uutelanperä, Vaala) ympäriltä: järvet ja lammet
  (myös multipolygonit), pellot ja niityt, suot, hiekka, tiet nimineen, rakennukset ja purot. Koordinaatit
  metreinä osoitepisteestä, x itään ja z etelään (sama kehys kuin ennen, 111 320 m/aste).
- Tarkka MML:n 2 m korkeusmalli (300 x 300 m, "dem") säilytetään sellaisenaan. Sen ulkopuolelle haetaan
  EU-DEM 25 m ("dem_far", 2 x 2 km, 25 m ruutu), joka sovitetaan 2 m mallin tasoon päällekkäiseltä alueelta.
  TARKENNUS: aja tämän jälkeen tools/kartta/mokki.ps1, joka korvaa "dem_far":n MML:n 2 m mallilla (8 m ruudukko,
  lehti R4333D kattaa koko alueen) ja laskee vesistöjen pinnat siitä uudelleen (EU-DEM antaa pienille lammille
  metrejä liian korkean pinnan).
- Jokaiselle vesistölle lasketaan pinnan korkeus ("level"): korkeusmallin alin kohta järven sisällä (malli
  tasoittaa vedenpinnan), pienille lammille rantaviivan alin kohta. Likasen pinta on 2 m mallin mittaama 125,34 m.
"""
import json
import math
import os
import statistics
import time
import urllib.parse
import urllib.request

LAT0, LON0 = 64.5054523, 26.6672225
HALF = 1000.0          # kohteet ja korkeusmalli +-1000 m
FAR_STEP = 25.0
M_PER_DEG = 111320.0
UA = {"User-Agent": "normipaiva-mokki-kartta/1.0"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "mokki", "kartta.json")


def to_xz(lat, lon):
    return ((lon - LON0) * math.cos(math.radians(LAT0)) * M_PER_DEG, -(lat - LAT0) * M_PER_DEG)


def to_latlon(x, z):
    return (LAT0 - z / M_PER_DEG, LON0 + x / (math.cos(math.radians(LAT0)) * M_PER_DEG))


def fetch(url, data=None):
    req = urllib.request.Request(url, data=data, headers=UA)
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())


def overpass():
    s, w = to_latlon(-HALF, HALF)
    n, e = to_latlon(HALF, -HALF)
    bb = f"{s},{w},{n},{e}"
    q = f"""[out:json][timeout:120];
(
  way["natural"="water"]({bb}); relation["natural"="water"]({bb}); way["landuse"="reservoir"]({bb});
  way["landuse"~"farmland|meadow|grass"]({bb});
  way["natural"~"wetland|sand"]({bb});
  way["highway"]({bb});
  way["building"]({bb});
  way["waterway"~"stream|ditch|river|drain"]({bb});
);
out geom;"""
    body = urllib.parse.urlencode({"data": q}).encode()
    for attempt in range(6):  # julkiset palvelimet ruuhkautuvat: vuorotellen ja odottaen
        url = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter"][attempt % 2]
        try:
            return fetch(url, body)
        except Exception as ex:
            print("  uusi yritys", url, ex)
            time.sleep(5 + attempt * 5)
    raise SystemExit("Overpass ei vastaa")


def rings_from_relation(rel):
    """Kokoaa multipolygonin outer-jäsenten viivat renkaiksi."""
    segs = [[(p["lat"], p["lon"]) for p in m["geometry"]] for m in rel.get("members", [])
            if m.get("role") == "outer" and "geometry" in m]
    rings = []
    while segs:
        ring = segs.pop(0)
        changed = True
        while ring[0] != ring[-1] and changed:
            changed = False
            for i, s in enumerate(segs):
                if s[0] == ring[-1]:
                    ring += s[1:]
                elif s[-1] == ring[-1]:
                    ring += s[::-1][1:]
                elif s[-1] == ring[0]:
                    ring = s[:-1] + ring
                elif s[0] == ring[0]:
                    ring = s[::-1][:-1] + ring
                else:
                    continue
                segs.pop(i)
                changed = True
                break
        rings.append(ring)
    return rings


def feature(kind, tags, fid, latlons):
    pts = [[round(x, 1), round(z, 1)] for x, z in (to_xz(a, b) for a, b in latlons)]
    ftype = tags.get("highway") or tags.get("building") or tags.get("waterway") or tags.get("natural") or ""
    return {"kind": kind, "name": tags.get("name", ""), "type": ftype if ftype != "yes" or kind == "building" else "",
            "id": str(fid), "pts": pts}


def kind_of(tags):
    if tags.get("natural") == "water" or tags.get("landuse") == "reservoir":
        return "water"
    if tags.get("landuse") in ("farmland", "meadow", "grass"):
        return "field"
    if tags.get("natural") == "wetland":
        return "bog"
    if tags.get("natural") == "sand":
        return "sand"
    if "highway" in tags:
        return "road"
    if "building" in tags:
        return "building"
    if "waterway" in tags:
        return "stream"
    return None


def elevations(points):
    out = []
    for k in range(0, len(points), 100):
        chunk = points[k:k + 100]
        locs = "|".join(f"{a:.6f},{b:.6f}" for a, b in chunk)
        for attempt in range(5):
            try:
                d = fetch("https://api.opentopodata.org/v1/eudem25m?locations=" + locs)
                break
            except Exception as ex:  # palvelu rajoittaa kutsuja: odota ja yritä uudelleen
                print("  uusi yritys", ex)
                time.sleep(3 + attempt * 3)
        out += [r["elevation"] if r["elevation"] is not None else float("nan") for r in d["results"]]
        print(f"  korkeudet {min(k + 100, len(points))}/{len(points)}")
        time.sleep(1.1)
    return out


def bilinear(dem, x, z):
    n = dem["n"]
    fx = min(max((x - dem["x0"]) / dem["step"], 0.0), n - 1.001)
    fz = min(max((z - dem["z0"]) / dem["step"], 0.0), n - 1.001)
    i, j = int(fx), int(fz)
    v = dem["values"]
    a = v[j * n + i] + (v[j * n + i + 1] - v[j * n + i]) * (fx - i)
    b = v[(j + 1) * n + i] + (v[(j + 1) * n + i + 1] - v[(j + 1) * n + i]) * (fx - i)
    return a + (b - a) * (fz - j)


def inside(poly, x, z):
    c = False
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, zi = poly[i]
        xj, zj = poly[j]
        if (zi > z) != (zj > z) and x < (xj - xi) * (z - zi) / (zj - zi) + xi:
            c = not c
        j = i
    return c


def set_levels(feats, inner, far):
    lim = -inner["x0"] - 10
    for f in feats:
        if f["kind"] != "water":
            continue
        if f["name"] == "Likanen":
            f["level"] = inner["water"]
            continue
        xs = [p[0] for p in f["pts"]]
        zs = [p[1] for p in f["pts"]]
        n = far["n"]
        hs = []
        for j in range(n):
            z = far["z0"] + j * far["step"]
            if z < min(zs) or z > max(zs):
                continue
            for i in range(n):
                x = far["x0"] + i * far["step"]
                if min(xs) <= x <= max(xs) and inside(f["pts"], x, z):
                    hs.append(far["values"][j * n + i])
        if not hs:
            hs = [bilinear(inner, x, z) if abs(x) < lim and abs(z) < lim else bilinear(far, x, z) for x, z in f["pts"]]
        f["level"] = round(min(hs) + 0.1, 2)


def main():
    old = json.load(open(OUT))
    inner = old["dem"]
    if "--levels" in os.sys.argv:
        set_levels(old["features"], inner, old["dem_far"])
        json.dump(old, open(OUT, "w"), ensure_ascii=False, separators=(",", ":"))
        print("Pinnat päivitetty:", [(f["name"], f["level"]) for f in old["features"] if f["kind"] == "water"])
        return
    print("OSM...")
    osm = overpass()
    feats = []
    for e in osm["elements"]:
        tags = e.get("tags", {})
        kind = kind_of(tags)
        if kind is None:
            continue
        if e["type"] == "way":
            feats.append(feature(kind, tags, e["id"], [(p["lat"], p["lon"]) for p in e["geometry"]]))
        elif e["type"] == "relation":
            for k, ring in enumerate(rings_from_relation(e)):
                feats.append(feature(kind, tags, f"r{e['id']}_{k}", ring))
    print(f"  {len(feats)} kohdetta")
    print("EU-DEM...")
    n = int(HALF * 2 / FAR_STEP) + 1
    grid = [(-HALF + i * FAR_STEP, -HALF + j * FAR_STEP) for j in range(n) for i in range(n)]
    vals = elevations([to_latlon(x, z) for x, z in grid])
    # Sovitus 2 m malliin: keskimääräinen ero päällekkäisellä alueella.
    lim = -inner["x0"] - 10
    diffs = [bilinear(inner, x, z) - v for (x, z), v in zip(grid, vals) if abs(x) < lim and abs(z) < lim and v == v]
    off = statistics.median(diffs)
    print(f"  sovitus {off:+.2f} m ({len(diffs)} pistettä)")
    mean = statistics.mean(v for v in vals if v == v)
    vals = [round((v if v == v else mean) + off, 2) for v in vals]
    far = {"x0": -HALF, "z0": -HALF, "step": FAR_STEP, "n": n, "values": vals}
    set_levels(feats, inner, far)
    src = ("OpenStreetMap (ODbL), MML korkeusmalli 2 m (CC BY 4.0, lehti R4333D; ETRS-TM35FIN E 484017.9 N 7153382.0) "
           "ja EU-DEM v1.1 25 m (Copernicus, opentopodata.org). Kaisuantie 62, Uutelanperä, Vaala: origo osoitepisteessa "
           f"{LAT0} N, {LON0} E; x itaan, z etelaan, metreja. Tehty: tools/mokki_kartta.py.")
    json.dump({"source": src, "dem": inner, "dem_far": far, "features": feats}, open(OUT, "w"), ensure_ascii=False,
              separators=(",", ":"))
    print("Kirjoitettu", OUT)


if __name__ == "__main__":
    main()
