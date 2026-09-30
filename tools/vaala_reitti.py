#!/usr/bin/env python3
"""Mopomatkan data Paapelista Vaalan Siitariin (assets/vaala/reitti.json) OpenStreetMapista ja EU-DEM:stä.

Ajo: python3 tools/vaala_reitti.py   (verkkoyhteys: router.project-osrm.org, overpass-api.de, api.opentopodata.org)

- Reitti: OSRM:n ajoreitti mökin osoitepisteestä (Kaisuantie 62) Hotelli-Ravintola Siitarin pihaan (Vaalantie 12)
  koko tarkkuudella: Uutelanperäntie - Neittäväntie - Vuolijoentie - Vaalantie, n. 11,6 km.
- Tiet reitin varrelta tunnisteineen (nimi, luokka, päällyste), jotta pelin tie on oikean levyinen ja pintainen.
- Maankäyttö reitin ympäriltä (pellot, niityt, suot, vedet, asuinalueet), rautatie, rakennukset 200 m tiestä
  sekä Vaalan keskustan tiet ja rakennukset 600 m Siitarista.
- Korkeudet (EU-DEM 25 m) tien keskilinjalta 20 m välein ja 60 m molemmin puolin 100 m välein.
Koordinaatit metreinä mökin osoitepisteestä kuten assets/mokki/kartta.json: x itään, z etelään.
"""
import json
import math
import os
import time
import urllib.parse
import urllib.request

LAT0, LON0 = 64.5054523, 26.6672225  # Kaisuantie 62 (sama origo kuin mökin kartassa)
SIITARI = (64.5581658, 26.8363199)   # Vaalantie 12, rakennus OSM way 225699578
M_PER_DEG = 111320.0
UA = {"User-Agent": "normipaiva-vaala-reitti/1.0"}
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "vaala", "reitti.json")
OVERPASS = ["https://overpass-api.de/api/interpreter", "https://overpass.kumi.systems/api/interpreter",
            "https://maps.mail.ru/osm/tools/overpass/api/interpreter"]


def to_xz(lat, lon):
    return (round((lon - LON0) * math.cos(math.radians(LAT0)) * M_PER_DEG, 2), round(-(lat - LAT0) * M_PER_DEG, 2))


def to_latlon(x, z):
    return (LAT0 - z / M_PER_DEG, LON0 + x / (math.cos(math.radians(LAT0)) * M_PER_DEG))


def fetch(url, data=None, tries=6):
    for i in range(tries):
        try:
            req = urllib.request.Request(url, data=data, headers=UA)
            with urllib.request.urlopen(req, timeout=180) as r:
                return json.loads(r.read().decode())
        except Exception as e:  # palvelin ruuhkainen: odota ja yritä uudelleen
            print("  yritys", i + 1, "epäonnistui:", str(e)[:80])
            time.sleep(5 + i * 5)
    raise RuntimeError("haku epäonnistui: " + url[:80])


def overpass(q):
    body = urllib.parse.urlencode({"data": q}).encode()
    last = None
    for k in range(3):
        for url in OVERPASS:
            try:
                return fetch(url, body, tries=2)
            except RuntimeError as e:
                last = e
        time.sleep(20)
    raise last


def route():
    url = ("https://router.project-osrm.org/route/v1/driving/%f,%f;%f,%f?overview=full&geometries=geojson"
           "&steps=true" % (LON0, LAT0, SIITARI[1], SIITARI[0]))
    r = fetch(url)["routes"][0]
    pts = [to_xz(lat, lon) for lon, lat in r["geometry"]["coordinates"]]
    # Alkuun mökin pihatie (Kaisuantie on OSM:ssä track, jota autoreititin ei käytä).
    pts.insert(0, (0.0, 0.0))
    steps = []
    for s in r["legs"][0]["steps"]:
        lon, lat = s["maneuver"]["location"]
        steps.append({"name": s["name"], "type": s["maneuver"]["type"], "modifier": s["maneuver"].get("modifier", ""),
                      "at": to_xz(lat, lon), "dist": round(s["distance"], 1)})
    return pts, steps, r["distance"]


def resample(pts, step):
    out = [pts[0]]
    acc = 0.0
    for a, b in zip(pts, pts[1:]):
        d = math.dist(a, b)
        while acc + d >= step:
            t = (step - acc) / d
            a = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)
            d = math.dist(a, b)
            acc = 0.0
            out.append(a)
        acc += d
    out.append(pts[-1])
    return out


def dem(points):
    """EU-DEM 25 m korkeudet pisteille (enintään 100 per haku, 1 haku/s)."""
    out = []
    for i in range(0, len(points), 100):
        chunk = points[i:i + 100]
        locs = "|".join("%.6f,%.6f" % to_latlon(x, z) for x, z in chunk)
        d = fetch("https://api.opentopodata.org/v1/eudem25m?locations=" + urllib.parse.quote(locs))
        out += [round(r["elevation"] if r["elevation"] is not None else 0.0, 2) for r in d["results"]]
        time.sleep(1.1)
    return out


def main():
    print("reitti (OSRM)...")
    pts, steps, dist = route()
    print("  %.0f m, %d pistettä" % (dist, len(pts)))
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    s, w = to_latlon(min(xs) - 400, max(zs) + 400)
    n, e = to_latlon(max(xs) + 400, min(zs) - 400)
    bb = "%f,%f,%f,%f" % (s, w, n, e)
    sx, sz = to_xz(*SIITARI)
    ts, tw = to_latlon(sx - 600, sz + 600)
    tn, te = to_latlon(sx + 600, sz - 600)
    tbb = "%f,%f,%f,%f" % (ts, tw, tn, te)
    print("OSM (tiet, maankäyttö, rakennukset)...")
    q = f"""[out:json][timeout:170];
(
  way["highway"~"primary|secondary|tertiary|unclassified|residential|service|track"]({bb});
  way["landuse"~"farmland|meadow|grass|residential|commercial|retail|industrial"]({bb});
  way["natural"~"water|wetland|sand"]({bb}); relation["natural"="water"]({bb});
  way["waterway"~"river|stream|canal"]({bb});
  way["building"]({bb});
  way["railway"="rail"]({bb});
  way["highway"~"footway|cycleway|path|pedestrian"]({tbb});
  way["amenity"="parking"]({tbb});
);
out tags geom;"""
    osm = overpass(q)
    feats = []
    for el in osm["elements"]:
        t = el.get("tags", {})
        geoms = []
        if el["type"] == "way" and "geometry" in el:
            geoms = [el["geometry"]]
        elif el["type"] == "relation":
            geoms = [m["geometry"] for m in el.get("members", []) if m.get("role") == "outer" and "geometry" in m]
        for g in geoms:
            p = [to_xz(c["lat"], c["lon"]) for c in g]
            if "highway" in t:
                kind = "road"
            elif t.get("railway") == "rail":
                kind = "rail"
            elif "building" in t:
                kind = "building"
            elif "waterway" in t:
                kind = "river"
            elif t.get("natural") == "water":
                kind = "water"
            elif t.get("natural") == "wetland":
                kind = "bog"
            elif t.get("amenity") == "parking":
                kind = "parking"
            elif t.get("landuse") in ("farmland", "meadow", "grass"):
                kind = "field"
            else:
                kind = "town"
            f = {"kind": kind, "id": el["id"], "pts": p}
            for k in ("name", "highway", "surface", "building", "building:levels", "lanes", "maxspeed", "addr:street",
                      "addr:housenumber", "amenity", "shop", "roof:shape", "width"):
                if k in t:
                    f[k.replace(":", "_")] = t[k]
            feats.append(f)
    # Rakennukset vain tien varresta (200 m) ja keskustasta (600 m Siitarista).
    line_s = resample(pts, 25.0)
    def near_route(p, r):
        return any(abs(p[0] - q[0]) < r and abs(p[1] - q[1]) < r and math.dist(p, q) < r for q in line_s)
    keep = []
    for f in feats:
        if f["kind"] == "building":
            c = (sum(q[0] for q in f["pts"]) / len(f["pts"]), sum(q[1] for q in f["pts"]) / len(f["pts"]))
            if math.dist(c, (sx, sz)) > 600.0 and not near_route(c, 200.0):
                continue
        keep.append(f)
    feats = keep
    print("  %d kohdetta" % len(feats))
    print("korkeudet (EU-DEM 25 m)...")
    line = resample(pts, 20.0)
    hl = dem(line)
    side = []
    for a, b in zip(resample(pts, 100.0), resample(pts, 100.0)[1:]):
        dx, dz = b[0] - a[0], b[1] - a[1]
        L = math.hypot(dx, dz) or 1.0
        nx, nz = -dz / L, dx / L
        side += [(a[0] + nx * 60, a[1] + nz * 60), (a[0] - nx * 60, a[1] - nz * 60)]
    hs = dem(side)
    grid = [(sx + i * 25.0, sz + j * 25.0) for j in range(-12, 13) for i in range(-12, 13)]
    hg = dem(grid)
    out = {
        "source": "OpenStreetMap (ODbL), OSRM-reititys ja EU-DEM 25 m (Copernicus). Origo Kaisuantie 62, Vaala "
                  "(%.7f N, %.7f E); x itään, z etelään, metrejä. Tehty: tools/vaala_reitti.py." % (LAT0, LON0),
        "siitari": [sx, sz], "distance": round(dist, 1), "route": pts, "steps": steps,
        "line": [[round(p[0], 2), round(p[1], 2), h] for p, h in zip(line, hl)],
        "side": [[round(p[0], 2), round(p[1], 2), h] for p, h in zip(side, hs)],
        "town_dem": {"x0": sx - 300.0, "z0": sz - 300.0, "step": 25.0, "n": 25, "values": hg},
        "features": feats,
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    print("kirjoitettu", OUT, os.path.getsize(OUT) // 1024, "kt")


if __name__ == "__main__":
    main()
