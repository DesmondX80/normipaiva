"""Kylän kartta OpenStreetMapista -> scripts/map_osm.gd (kuten kyla_osm.ps1).

Hae ote ensin (ks. LUEMINUT.md), esim.
  https://api.openstreetmap.org/api/0.6/map?bbox=24.43,64.595,24.53,64.672  ->  map.osm
Ajo:  python tools/kartta/kyla_osm.py --osm C:/polku/map.osm
      python tools/kartta/kyla_osm.py --osm C:/polku/map.osm --pohjoinen
--pohjoinen vie vain pohjoisen laajennuksen (px y -960..-60) ja liittää sen olemassa olevan map_osm.gd:n osioiden
loppuun, jolloin vanhan alueen kohteet pysyvät täsmälleen ennallaan (tuore ote ketjuttaa ja pyöristää muutaman
vanhan kohteen hieman eri tavalla). Saumassa y = -60 kohteet leikataan samasta raakageometriasta kuin vanhassa.
"""
import argparse
import os
import re
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kartta import Osm  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", required=True)
    ap.add_argument("--out", default=os.path.join(ROOT, "scripts", "map_osm.gd"))
    ap.add_argument("--pohjoinen", action="store_true")
    a = ap.parse_args()
    o = Osm(a.osm)
    print(o.summary())
    if a.pohjoinen:
        tmp = os.path.join(tempfile.mkdtemp(), "pohjoinen.gd")
        print(o.export_gd(tmp, -60, -960, 1700, -60))
        _append_sections(a.out, tmp)
        return
    # Koko kartan alue: tiet, metsät, pellot, suot, vedet, purot ja rakennukset. Käsin tehdyt ovat vain laavu,
    # laavupolut ja pelipaikat (map_data.gd).
    print(o.export_gd(a.out, -60, -960, 1700, 4100))


# Saumakorjaukset: OSM:ssä Onnentie on kaksi erillistä tietä, ja jälkimmäinen alkaa vanhan rajauksen sisältä
# (749, -51). Vanha ote pudotti sen 9 px:n tyngän saumarajan sisäpuolelta, joten pohjoispäähän lisätään alkupiste.
SAUMA = [('"name": "Onnentie", "h": 0.8, "pts": [Vector2(747, -60)',
          '"name": "Onnentie", "h": 0.8, "pts": [Vector2(749, -51), Vector2(747, -60)')]


def _sections(s):
    return {m.group(1): m.group(2) for m in re.finditer(r"^const (\w+) := \[\n(.*?)^\]", s, re.S | re.M)}


def _append_sections(target, extra):
    """Liittää extra-tiedoston osioiden kohteet target-tiedoston samannimisten osioiden loppuun."""
    with open(target, encoding="utf-8") as fh:
        s = fh.read()
    with open(extra, encoding="utf-8") as fh:
        add = _sections(fh.read())
    for k, body in _sections(s).items():
        if not add.get(k, "").strip():
            continue
        body2 = body if body.endswith(",\n") else body.rstrip("\n") + ",\n"
        s = s.replace("const %s := [\n%s]" % (k, body), "const %s := [\n%s%s]" % (k, body2, add[k]), 1)
        print("%s: lisätty %d" % (k, add[k].count("\n")))
    for old, new in SAUMA:
        s = s.replace(old, new, 1)
    with open(target, "w", encoding="utf-8", newline="") as fh:
        fh.write(s)


if __name__ == "__main__":
    main()
