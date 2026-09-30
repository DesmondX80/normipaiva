"""Kylän kartta OpenStreetMapista -> scripts/map_osm.gd (kuten kyla_osm.ps1).

Hae ote ensin (ks. LUEMINUT.md), esim.
  https://api.openstreetmap.org/api/0.6/map?bbox=24.43,64.595,24.53,64.66  ->  map.osm
Ajo:  python tools/kartta/kyla_osm.py --osm C:/polku/map.osm
"""
import argparse
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kartta import Osm  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "scripts", "map_osm.gd"))
    a = ap.parse_args()
    o = Osm(a.osm)
    print(o.summary())
    # Koko kartan alue: tiet, metsät, pellot, suot, vedet, purot ja rakennukset. Käsin tehdyt ovat vain laavu,
    # laavupolut ja pelipaikat (map_data.gd).
    print(o.export_gd(a.out, -60, -60, 1700, 4100))


if __name__ == "__main__":
    main()
