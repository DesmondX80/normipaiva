#!/usr/bin/env python3
"""K-Market Tervaportti liikenneympyrän suoraan eteen (assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_kmarket_ymparyra.py   (viimeinen vaihe vaala_apteekki.py:n jälkeen)
tie.json:iin merkitään "kmarket_ymparyra": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

- Vaalantieltä tullessa ympyrästä oikealle lähtee Aseman piha, vasemmalle Torintie ja suoraan uusi kaksikaistainen
  asfalttitie (Vaalantie, 8 m + piennar, keskiviiva) K-Marketin parkkipaikalle. Kauppa on tien päässä julkisivu ympyrään päin.
- Kauppa (OSM-rakennus Vaalantie 26) siirtyy Siitarin viereltä; vanha parkkipaikka poistuu ja tontti jää tasoitetuksi pihaksi.
  Muut rakennukset pysyvät paikoillaan (tontti mahtuu Vaalantie 18:n ja 20:n sekä vasemman puolen talojen väliin).
- Maasto tasoitetaan tien ja tontin alta, puut pois tieltä ja tontilta.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_keskusta as K  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

KM_SIZE = (27.0, 18.0)   # julkisivu x syvyys (kuten vaala_keskusta.py)
PARK_DEPTH = 12.0
PARK_PAD = 4.0           # parkki ja tontti kaupan leveyttä leveämpi tämän verran molemmin puolin
PARK_U = 74.0            # parkin alkureuna ympyrän keskipisteestä tien suuntaan (m)
RB_R = 12.0
ROAD_REACH = 6.5         # puut pois näin kauas tien keskiviivasta


def main():
    tie = VS.load_tie()
    if tie.get("kmarket_ymparyra"):
        sys.exit("kmarket_ymparyra on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("torisiirto") or not tie.get("apteekki"):
        sys.exit("aja ensin vaala_torisiirto.py ... vaala_apteekki.py")
    terr, trees = VS.Terrain(), VS.Trees()
    wl = tie["water_level"]

    # Suunta: Vaalantien loppu kohti ympyrää (kuten vaala_torisiirto.py); td = suoraan, rt = oikealle (x itään, z etelään).
    c = tuple(tie["keskusta"]["asema"]["roundabout"]["c"])
    road = tie["road"]
    d = (road[-1][0] - road[-8][0], road[-1][2] - road[-8][2])
    L = math.hypot(*d)
    td = (d[0] / L, d[1] / L)
    rt = (-td[1], td[0])

    def at(u, v=0.0):
        return (c[0] + td[0] * u + rt[0] * v, c[1] + td[1] * u + rt[1] * v)

    # Kauppa: parkki u PARK_U..+12, rakennus sen takana, julkisivu (ovi) ympyrään päin.
    u_b = PARK_U + PARK_DEPTH + KM_SIZE[1] / 2.0
    km = next(b for b in tie["buildings"] if b["id"] == K.KMARKET_ID)
    old_c = VS.center([tuple(q) for q in km["pts"]])
    km["pts"] = K.rect(at(u_b), rt, td, KM_SIZE[0] / 2.0, KM_SIZE[1] / 2.0)
    km["door_to"] = [round(c[0], 2), round(c[1], 2)]  # ovi ympyrään päin (vaala.gd _door: pääreitti on yli 60 m:n päässä)
    park_c = at(PARK_U + PARK_DEPTH / 2.0)
    parking = K.rect(park_c, rt, td, KM_SIZE[0] / 2.0 + PARK_PAD, PARK_DEPTH / 2.0)
    lot = K.rect(at((PARK_U + u_b + KM_SIZE[1] / 2.0) / 2.0 - 0.0), rt, td, KM_SIZE[0] / 2.0 + PARK_PAD,
                 (PARK_DEPTH + KM_SIZE[1]) / 2.0)

    # Vanha parkki pois (Siitarin vieressä); tontin ja tien alta ei saa osua muihin rakennuksiin.
    old_park = tie["keskusta"]["parking"]
    tie["parkings"] = [p for p in tie["parkings"] if p != old_park]
    tie["parkings"].append(parking)
    road_start, road_end = at(RB_R - 0.5), at(PARK_U)
    lane = VL.resample([road_start, road_end], 2.0)
    for b in tie["buildings"]:
        if b is km:
            continue
        pts = [tuple(q) for q in b["pts"]]
        hit = any(K.in_poly(q, [tuple(x) for x in lot]) for q in pts) or any(K.in_poly(q, pts) for q in lot) \
            or min(VS.poly_dist(q, pts) for q in lane) < 6.0 or min(VS.poly_dist(tuple(q), pts) for q in lot) < 2.0
        if hit:
            sys.exit("K-Marketin uusi paikka tai tie osuu rakennukseen %s %s" % (b["id"], b.get("addr")))
    for pk in tie["parkings"]:
        if pk is parking:
            continue
        if any(K.in_poly(tuple(q), [tuple(x) for x in lot]) for q in pk) or min(VS.poly_dist(q, [tuple(x) for x in pk]) for q in lane) < 5.5:
            sys.exit("parkkipaikka tiellä tai tontilla: %s" % (pk[0],))
    for r in tie["side_roads"]:
        if r["kind"] == "road" and r.get("name") not in ("Vaalan tori",) and any(
                min(math.dist(q[:2], p) for p in lane) < 9.0 for q in r["pts"]) and r.get("name") not in ("Torintie", "Aseman piha"):
            sys.exit("tie osuu sivutiehen %s" % r.get("name"))

    # Uusi tie: sama tyyli kuin Torintie (residential, asfaltti: 8 m, piennar ja keskiviiva = kaksikaistainen).
    tie["side_roads"].append({"kind": "road", "hw": "residential", "name": "Vaalantie", "surface": "asphalt", "_kmarket": 1,
                              "pts": [[round(road_start[0], 2), round(road_start[1], 2)], [round(road_end[0], 2), round(road_end[1], 2)]]})

    # Maasto ja puut.
    terr.flatten([[tuple(q) for q in lot]], 8.0)
    terr.lane([road_start, road_end], wl)
    pts = []
    xs, zs = [q[0] for q in lot], [q[1] for q in lot]
    gx = min(xs)
    while gx <= max(xs):
        gz = min(zs)
        while gz <= max(zs):
            if K.in_poly((gx, gz), [tuple(q) for q in lot]):
                pts.append((gx, gz))
            gz += 2.0
        gx += 2.0
    near_t = trees.near_any(lane, ROAD_REACH) | trees.near_any(pts, 3.5)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)

    print("K-Market siirtyi %s -> %s (ympyrästä %.0f m, tie %.0f m)" % (
        [round(v, 1) for v in old_c], [round(v, 1) for v in at(u_b)], u_b, PARK_U - RB_R + 0.5))
    tie["kmarket_ymparyra"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


if __name__ == "__main__":
    main()
