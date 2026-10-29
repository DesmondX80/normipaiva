#!/usr/bin/env python3
"""Satamantie uusiksi: kapea asfalttikatu K-Marketin kohdalta Vaalantieltä radan yli satamaan ja Uiton saunalle
(assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_satamatie.py   (viimeinen vaihe vaala_kierros.py:n jälkeen)
tie.json:iin merkitään "satamatie": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Vanha Satamantie Aseman pihan taitteesta (840, -800) tasoristeyksen yli Satamantien mutkaan (864,9, -564) poistuu
  kokonaan: tie, sen pohja (piha-koodi takaisin ympäröivään maahan) ja tasoristeys.
- Uusi Satamantie lähtee Vaalantieltä K-Marketin länsipuolelta, ylittää radan tasoristeyksellä ja liittyy vanhaan
  Satamantiehen (864,9, -564). Kiertotie Zabukilta asemalle (Aseman piha, Ratatie, Veturitallintie, Kätkötie) jää.
- Uusi katu on Saloisten "street": 5,5 m, ei piennarta eikä keskiviivaa ("street": 1 tie.jsonissa, vaala.gd _side_style).
  Satamantie, Sahanrannantie ja Uitontie ovat kaikki tätä katua.
- Tielle jäävät pienet rakennukset (talot ja vajat) poistetaan; puut pois tieltä.
"""
import json
import math
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "tools"))
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
START = (672.0, -790.0)        # Vaalantien näyte K-Marketin länsipuolella
JOIN_OLD = 7                   # vanhan Satamantien piste (864,9, -564), johon uusi katu liittyy
CLEAR = 5.0                    # rakennus vähintään näin kauas keskiviivasta (katu 5,5 m + tilaa)
TREE_CLEAR = 5.0
OLD_LANE = 3.5                 # vanhan tien pohjan puolileveys (vaala_sahanranta.py lane)
KEEP_ROADS = ("Aseman piha", "Ratatie", "Veturitallintie", "Kätkötie", "Vaalan tori", "Pahalahdentie")


def main():
    tie = VS.load_tie()
    if tie.get("satamatie"):
        sys.exit("satamatie on jo tehty (satamatie: true); uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("kierros"):
        sys.exit("aja ensin vaala_kierros.py")
    terr, trees = VS.Terrain(), VS.Trees()
    wl = tie["water_level"]

    sat = next(r for r in tie["side_roads"] if r["name"] == "Satamantie")
    old = [tuple(p) for p in sat["pts"]]
    old_north = old[:JOIN_OLD + 1]
    tail = old[JOIN_OLD:]

    # Uusi linja: Vaalantieltä suoraan liittymään.
    road = tie["road"]
    s0 = min(road, key=lambda r: math.dist((r[0], r[2]), START))
    new = [(s0[0], s0[2])]
    new += [(new[0][0] + (tail[0][0] - new[0][0]) * k / 40.0, new[0][1] + (tail[0][1] - new[0][1]) * k / 40.0)
            for k in range(1, 41)]
    lane = VL.resample(new, 3.0)
    lane = lane[:-1] + [tail[0]]
    print("uusi Satamantie %.0f m, alku %s" % (sum(math.dist(a, b) for a, b in zip(lane, lane[1:])), [round(v) for v in lane[0]]))

    # Vanha pohja pois: piha-koodi takaisin ympäröivään maahan (ei kiinteiden teiden eikä uuden linjan lähellä).
    keep = [VL.resample([tuple(q[:2]) for q in r["pts"]], 3.0) for r in tie["side_roads"]
            if r["kind"] == "road" and r["name"] in KEEP_ROADS]
    keep_pts = [q for ln in keep for q in ln]
    dense_old = VL.resample(old_north, 2.0)
    near_new = VL.resample(lane, 2.0)
    reverted = 0
    xs, zs = [q[0] for q in dense_old], [q[1] for q in dense_old]
    for i, j, q in terr.cells((min(xs) - 6, min(zs) - 6, max(xs) + 6, max(zs) + 6)):
        k = j * terr.nx + i
        if terr.codes[k] != YARD or VL.line_dist(q, dense_old) > OLD_LANE + 0.6:
            continue
        if any(math.dist(q, p) < 7.0 for p in keep_pts) or VL.line_dist(q, near_new) < 7.0:
            continue
        if any(VS.poly_dist(q, b["pts"]) < 6.0 for b in tie["buildings"]):
            continue  # pihojen ja rakennusten tasaukset jäävät
        neigh = []
        for a in range(16):
            for rad in (7.0, 10.0):
                c = terr.code((q[0] + math.cos(a * math.tau / 16) * rad, q[1] + math.sin(a * math.tau / 16) * rad))
                if c in (FOREST, FIELD, BOG):
                    neigh.append(c)
        terr.codes[k] = max(set(neigh), key=neigh.count) if neigh else FOREST
        terr.changed.add((i, j))
        reverted += 1
    print("vanhaa pohjaa takaisin maaksi: %d ruutua" % reverted)

    # Rakennukset ja pysäköinti uuden linjan tieltä.
    dense = VL.resample(lane, 2.0)
    kept = []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        if b["id"] in VS.PROTECT or b.get("name") or b["kind"] == "big":
            if min(VS.poly_dist(p, pts) for p in dense) < CLEAR:
                sys.exit("suojattu rakennus tiellä: %s %s" % (b["kind"], b.get("name")))
            kept.append(b)
        elif min(VS.poly_dist(p, pts) for p in dense) < CLEAR:
            print("rakennus pois: %s %s (%.0f, %.0f)" % (b["kind"], b.get("name") or "", pts[0][0], pts[0][1]))
        else:
            kept.append(b)
    tie["buildings"] = kept
    for pk in tie["parkings"] + tie["keskusta"]["tori"]["parkings"]:
        if min(VS.poly_dist(p, [tuple(q) for q in pk]) for p in dense) < CLEAR:
            sys.exit("parkkipaikka tien päällä: %s" % pk[0])

    # Uusi pohja (tasoristeys nousee kiskojen korkeudelle).
    terr.lane(lane, wl)

    # Tiet: vanha pohjoispää pois, uusi tilalle; kaikki Satamantien tiet kapeaksi asfalttikaduksi.
    sat["pts"] = [[round(x, 2), round(z, 2)] for x, z in lane + tail[1:]]
    for r in tie["side_roads"]:
        if r["name"] in ("Satamantie", "Sahanrannantie", "Uitontie"):
            r["hw"], r["surface"], r["street"] = "residential", "asphalt", 1

    # Puut pois tieltä, muuttuneen maan puut uuteen korkeuteen.
    near = trees.near_any(VL.resample(lane, 2.0), TREE_CLEAR)
    print("puita pois %d" % int(near.sum()))
    trees.remove(near)
    trees.reground(terr)

    tie["satamatie"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
