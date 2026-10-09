"""Kylän korkeusmalli: MML 2 m -lehdet -> assets/terrain/korkeus.json + korkeus_mml.i16 (kuten kyla.ps1).

Ajo:  python tools/kartta/kyla.py --lehdet C:/polku/lehtiin [--sheets R4132H R4134B R4141G R4143A]
Sen jälkeen: godot --headless --path . -s tools/bake_terrain.gd
"""
import argparse
import os
import struct
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from kartta import Mosaic  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lehdet", required=True)
    ap.add_argument("--sheets", nargs="+", default=["R4132H", "R4134B", "R4141G", "R4143A"])
    ap.add_argument("--out-dir", default=os.path.join(ROOT, "assets", "terrain"))
    a = ap.parse_args()
    # Mosaiikki kattaa kartan (px -320..1940 x -1220..4280) marginaaleineen: E 376..383 km, N 7165..7175 km.
    m = Mosaic(376000, 7175000, 3500, 5000)
    for sh in a.sheets:
        print(m.add(os.path.join(a.lehdet, sh + ".tif")))
    # Ruudukko täsmälleen pelin maastoruudukon pisteisiin (bake_terrain.gd: 5 m, alku w2(MAP_MIN) - 300 = px (-300, -1200)),
    # arvo suoraan 2 m mallista (bilineaarinen, ei keskiarvoa).
    px0, py0, step, nx, ny = -300, -1200, 5, 445, 1093
    vals = m.sample(px0, py0, step, nx, ny, 0)
    nan = 0
    out = bytearray()
    for v in vals:
        if v != v:
            nan += 1
            v = 0.0
        out += struct.pack("<h", round(v * 100))
    with open(os.path.join(a.out_dir, "korkeus_mml.i16"), "wb") as fh:
        fh.write(out)
    meta = ('{"source": "Maanmittauslaitoksen korkeusmalli 2 m (CC BY 4.0; lehdet ' + ", ".join(a.sheets) + ', Kapsin peili), N2000", '
            '"note": "Korkeudet tiedostossa korkeus_mml.i16: int16 senttimetreinä, rivi kerrallaan (nx arvoa / rivi). '
            'Ruudukko karttapikseleissä: px = px0 + i*dx, py = py0 + j*dy; pikselit -> ETRS-TM35FIN tools/kartta/kehys.ps1:n '
            'kehyksellä. Arvo suoraan 2 m mallista pelin maastoruudukon pisteissä.", '
            '"data": "korkeus_mml.i16", "nx": %d, "ny": %d, "px0": %d, "py0": %d, "dx": %d, "dy": %d}' % (nx, ny, px0, py0, step, step))
    with open(os.path.join(a.out_dir, "korkeus.json"), "w", encoding="utf-8", newline="") as fh:
        fh.write(meta)
    print("korkeus_mml.i16: %d x %d, puuttuvia %d" % (nx, ny, nan))


if __name__ == "__main__":
    main()
