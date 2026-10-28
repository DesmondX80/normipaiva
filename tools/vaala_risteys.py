#!/usr/bin/env python3
"""Zabukin takainen liikenneympyrä tavalliseksi risteykseksi (assets/vaala/tie.json).

Ajo: python3 tools/vaala_risteys.py   (kerran vaala_sahanranta.py:n jälkeen; toistettava)
Vaalantie ja Aseman piha liitetään suoraan ympyrän paikalla (asema.roundabout.r = 0: vaala.gd ei piirrä rengasta,
saareketta eikä reunakiveä eikä rajaa ajoaluetta renkaaseen).
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TIE = os.path.join(ROOT, "assets", "vaala", "tie.json")

tie = json.load(open(TIE))
rb = tie["keskusta"]["asema"]["roundabout"]
if rb["r"] == 0:
    raise SystemExit("risteys on jo tehty")
vt = next(r for r in tie["side_roads"] if r["name"] == "Vaalantie" and len(r["pts"]) == 2 and r["pts"][0][0] > 770 and r["pts"][0][0] < 780)
piha = next(r for r in tie["side_roads"] if r["name"] == "Aseman piha")
# Vaalantie jatkuu Aseman pihan alkuun; Aseman piha alkaa risteyksestä (kulma pyöristetään yhdellä välipisteellä).
a, b = vt["pts"][-1], piha["pts"][0]
mid = [round((a[0] + b[0]) / 2.0 + 1.0, 2), round((a[1] + b[1]) / 2.0 + 1.5, 2)]
vt["pts"] = [vt["pts"][0], a, mid, b]
rb["r_old"] = rb["r"]
rb["r"] = 0
json.dump(tie, open(TIE, "w"), ensure_ascii=False, separators=(",", ":"))
print("risteys:", vt["pts"])
