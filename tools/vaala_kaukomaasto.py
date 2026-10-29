#!/usr/bin/env python3
"""Painaa kaukomaaston muuttuneen tarkan maaston alle (alikulun leikkauksen "katto").

Ajo kerran: venv/bin/python tools/vaala_kaukomaasto.py   (vaala_sahanranta.py Terrain._sync_far tekee saman uusille ajoille).
Kaukomaaston kulmat painetaan ±fcell ympäristönsä matalimman tarkan pisteen alle; ajo on idempotentti.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__))))
import vaala_sahanranta as VS  # noqa: E402


def main():
    terr = VS.Terrain()
    # Muuttuneiksi katsotaan alikulun leikkauksen ympäristö (tien ja ratojen risteyksen tienoo).
    tie = VS.load_tie()
    u = tie.get("underpass2")
    if not u:
        sys.exit("ei alikulkua (underpass2)")
    cx, cz = u["at"]
    for j in range(terr.nz):
        for i in range(terr.nx):
            if abs(terr.x0 + i * terr.cell - cx) < 120.0 and abs(terr.z0 + j * terr.cell - cz) < 120.0:
                terr.changed.add((i, j))
    terr.save()


if __name__ == "__main__":
    main()
