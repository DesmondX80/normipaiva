"""Mökin kartta (assets/mokki/kartta.json) samoilla työkaluilla kuin kylä (kuten mokki.ps1, ks. LUEMINUT.md).

- OSM-kohteet (vedet, pellot, suot, hiekka, metsät, tiet, rakennukset, purot) otteesta --osm (2 x 2 km, esim.
  https://api.openstreetmap.org/api/0.6/map?bbox=26.64531,64.49602,26.68914,64.51488); ilman --osm:ia nykyiset
  kohteet säilyvät ja vain korkeudet ja pinnat lasketaan uudelleen.
- Korkeudet MML:n 2 m mallista (lehti R4333D): pihan tarkka ruudukko "dem" (300 x 300 m, 2 m) ja kaukoalue
  "dem_far" (2 x 2 km, 8 m).
- Vesistöjen pinnat ("level"): mallin tasoitettu vedenpinta järven sisältä.
Ajo:  python tools/kartta/mokki.py --lehdet C:/polku/lehtiin [--osm C:/polku/map.osm]
"""
import argparse
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kartta import Mosaic, MokkiDem, Osm, fmt  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PATH = os.path.join(ROOT, "assets", "mokki", "kartta.json")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lehdet", required=True)
    ap.add_argument("--osm", default="")
    ap.add_argument("--sheets", nargs="+", default=["R4333D"])
    ap.add_argument("--out", default=PATH, help="kohdetiedosto (oletus assets/mokki/kartta.json)")
    a = ap.parse_args()
    m = Mosaic(482000, 7158000, 3000, 3000)
    for sh in a.sheets:
        print(m.add(os.path.join(a.lehdet, sh + ".tif")))
    dem = MokkiDem(m)

    def grid_json(x0, step, n, extra):
        vals = dem.grid(x0, x0, step, n)
        return ('{"x0":' + fmt(x0) + ',"z0":' + fmt(x0) + ',"step":' + fmt(step) + ',"n":' + str(n) + extra
                + ',"values":[' + ",".join(fmt(round(v, 2)) for v in vals) + ']}')

    if a.osm:
        o = Osm(a.osm, local=True)
        print(o.summary())
        features, count = o.mokki_features(dem.level)
        print("OSM-kohteita %d" % count)
    else:
        with open(PATH, encoding="utf-8") as fh:
            txt = fh.read()
        d = json.loads(txt)
        levels = [fmt(round(dem.level([p[0] for p in f["pts"]], [p[1] for p in f["pts"]]), 2))
                  for f in d["features"] if f["kind"] == "water"]
        it = iter(levels)
        fi = txt.index('"features":')
        features = re.sub(r'"level":\s*-?[0-9.]+', lambda _m: '"level":' + next(it), txt[fi + 11:txt.rindex("}")])

    lik = re.search(r'\{"kind":"water","name":"Likanen"[^}]*"level":([0-9.]+)\}', features)
    water = lik.group(1) if lik else "125.34"
    dem_json = grid_json(-150, 2, 151, ',"water":' + water)
    far_json = grid_json(-1000, 8, 251, "")
    src = ("OpenStreetMap (ODbL) ja MML korkeusmalli 2 m (CC BY 4.0, lehti R4333D; ETRS-TM35FIN E 484017.9 N 7153382.0) "
           "koko alueella (dem 2 m, dem_far 8 m). Kaisuantie 62, Uutelanperä, Vaala: origo osoitepisteessa 64.5054523 N, "
           "26.6672225 E; x itaan, z etelaan, metreja. Tehty: tools/kartta/mokki.ps1.")
    out = '{"source":"' + src + '","dem":' + dem_json + ',"dem_far":' + far_json + ',"features":' + features + '}'
    with open(a.out, "w", encoding="utf-8", newline="") as fh:
        fh.write(out)
    chk = json.loads(out)
    kinds = {}
    for f in chk["features"]:
        kinds[f["kind"]] = kinds.get(f["kind"], 0) + 1
    print("kohteet: " + ", ".join("%s %d" % kv for kv in kinds.items()))
    print("pinnat: " + ", ".join("%s %s" % (f["name"], fmt(f["level"])) for f in chk["features"] if f["kind"] == "water"))
    print("kirjoitettu", a.out)


if __name__ == "__main__":
    main()
