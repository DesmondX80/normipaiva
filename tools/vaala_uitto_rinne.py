#!/usr/bin/env python3
"""Uiton saunan rinne loivemmaksi (assets/vaala/maasto.bin, puut.bin). Idempotentti: korkeudet asetetaan absoluuttisina.

vaala_sahanranta.py:n soften_uitto jätti pihan 2,6 m vedenpinnan yläpuolelle ja pudotuksen vesirajaan ~6 metriin
(~35 astetta, maasto 4 m ruudukossa): hahmo ja mopo luisuivat ja rinne näytti kumpuilevalta. Nyt piha on 1,6 m vedenpinnan
yläpuolella ja rinne laskee tasaisesti terassin reunalta vesirajaan; rannan vesiruudut muutetaan maaksi, jotta ranta\nsiirtyy kauemmas (vesiruutujen pohjaa ei saa nostaa: se määrää vedenpinnan).

Ajo: venv/bin/python tools/vaala_uitto_rinne.py   (testi: --scene=uittorinne, rinteen kulma lokiin)
"""
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tools", "kartta"))
import vaala_sahanranta as S  # noqa: E402

VL = S.VL
UITTO_YARD = 1.6      # piha vedenpinnan yläpuolella (m)
SHORE_V = 7.0         # rinne päättyy vesirajaan näin kaukana (m) pihan reunasta


def main():
    tie = S.load_tie()
    u = tie["uitto"]
    d = u["dir"]
    side = (d[1], -d[0])
    wl = tie["water_level"]
    ly = wl + UITTO_YARD
    terr, trees = S.Terrain(), S.Trees()
    pc, pr = u["park"], u["park_r"]
    yard = [[pc[0] + side[0] * math.cos(a) * pr[0] * 0.97 + d[0] * math.sin(a) * pr[1] * 0.97,
             pc[1] + side[1] * math.cos(a) * pr[0] * 0.97 + d[1] * math.sin(a) * pr[1] * 0.97]
            for a in [k * math.tau / 24 for k in range(24)]]
    terr.flatten([yard], 9.0, level=ly)
    root = (u["x"], u["z"])
    edge = -2.3  # terassin reuna rannan kehyksessä (saunan etuseinä v -4,7 + terassi 2,4)
    for i, j, q in terr.cells((root[0] - 34, root[1] - 34, root[0] + 34, root[1] + 34)):
        k = j * terr.nx + i
        if terr.codes[k] in (S.RAIL, S.ROAD, 255):
            continue
        rx, rz = q[0] - root[0], q[1] - root[1]
        uu, vv = rx * side[0] + rz * side[1], rx * d[0] + rz * d[1]
        wgt = 1.0 - VL.smooth(10.0, 16.0, abs(uu))
        if wgt <= 0.0 or vv < edge - 2.0:
            continue
        if vv >= edge + SHORE_V:
            continue  # vesiruutujen pohja pysyy: vedenpinta = lähimmän vesiruudun pohja + 1,2 (vaala.gd water_y, _build_water)
        # Rannan ruudut (aiemmin vettä) muutetaan maaksi, jotta rinne jatkuu loivana kauemmas järvelle.
        prof = VL.lerp(ly, wl + 0.05, VL.smooth(edge, edge + SHORE_V, vv))
        new = VL.lerp(terr.h[k], prof, wgt)
        code = S.YARD if (terr.codes[k] == S.WATER and wgt > 0.5) else terr.codes[k]
        if code == S.WATER:
            continue  # reunavyöhykkeen vesiruutu: pohja ennallaan
        terr.set(i, j, S.YARD if (wgt > 0.5 and code != S.SHOULDER) else code, new)
    terr.save()
    trees.reground(terr)
    trees.save()
    print("uiton rinne: piha %.2f m, vesiraja v=%.1f m" % (UITTO_YARD, edge + SHORE_V))


if __name__ == "__main__":
    main()
