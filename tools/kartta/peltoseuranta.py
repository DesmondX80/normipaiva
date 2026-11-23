"""Peltolohkot peltoseuranta-sovelluksesta (https://desmondx80.github.io/peltoseuranta/, fields.json: GeoJSON, CRS84,
ominaisuudet lohko_id, kasvilaji, pinta_ala) kylän karttakehykseen (px, kartta.py tm2px) -> scripts/map_tila.gd.

Hae ensin data:  curl -o fields.json https://desmondx80.github.io/peltoseuranta/fields.json
Ajo:  python3 -I tools/kartta/peltoseuranta.py fields.json 597884 598366 597885 597886 597887

Tulos: FIELDS = [{"id", "kasvi", "ha", "pts": [Vector2]}] (vakiolauseke: ei PackedVector2Array) lohkojen järjestyksessä. Pisteet 0,1 px:n tarkkuudella,
peräkkäiset alle 0,8 px:n päässä olevat pisteet yhdistetään ja suljettu viimeinen piste pudotetaan.
"""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kartta import tm35, tm2px  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    src = sys.argv[1]
    ids = [int(a) for a in sys.argv[2:]]
    d = json.load(open(src, encoding="utf-8"))
    by_id = {int(f["properties"]["lohko_id"]): f for f in d["features"]}
    rows = []
    for lid in ids:
        f = by_id[lid]
        g = f["geometry"]
        ring = g["coordinates"][0] if g["type"] == "Polygon" else g["coordinates"][0][0]
        pts = []
        for lon, lat in [(p[0], p[1]) for p in ring]:
            x, y = tm2px(*tm35(lat, lon))
            if pts and abs(pts[-1][0] - x) < 0.8 and abs(pts[-1][1] - y) < 0.8:
                continue
            pts.append((round(x, 1), round(y, 1)))
        if len(pts) > 2 and abs(pts[0][0] - pts[-1][0]) < 0.8 and abs(pts[0][1] - pts[-1][1]) < 0.8:
            pts.pop()
        p = f["properties"]
        rows.append((str(lid), p["kasvilaji"], p["pinta_ala"], pts))
        print(lid, p["kasvilaji"], p["pinta_ala"], "ha,", len(pts), "pistettä")
    out = os.path.join(ROOT, "scripts", "map_tila.gd")
    with open(out, "w", encoding="utf-8") as fh:
        fh.write("extends RefCounted\n")
        fh.write("## Altaantien tilan peltolohkot (Saloinen, kodin itäpuoli) kylän karttakehyksessä (px, map_data.gd).\n")
        fh.write("## Lähde: peltoseuranta-sovelluksen fields.json (desmondx80.github.io/peltoseuranta), muunnos\n")
        fh.write("## tools/kartta/peltoseuranta.py. Älä muokkaa käsin.\n\n")
        fh.write("const FIELDS := [\n")
        for lid, kasvi, ha, pts in rows:
            vs = ", ".join("Vector2(%g, %g)" % p for p in pts)
            fh.write('\t{"id": "%s", "kasvi": "%s", "ha": %s, "pts": [%s]},\n' % (lid, kasvi, ha, vs))
        fh.write("]\n")
    print("->", out)


if __name__ == "__main__":
    main()
