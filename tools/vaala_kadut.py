#!/usr/bin/env python3
"""Vaalan itäisen asuinalueen (Katjan talo, kolmiomittaus) kadut ja koulukeskuksen poisto (assets/vaala/tie.json,
maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_kadut.py   (viimeinen vaihe vaala_kirkkotie.py:n jälkeen)
Kuiva-ajo (ei kirjoita mitään, tulostaa osumat ja kuvan): venv/bin/python tools/vaala_kadut.py --kuiva <kuva.png>
tie.json:iin merkitään "kadut": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

Alueen talot (MML) on rivitetty aseman suuntaisiin riveihin, mutta alueella ei ollut yhtään katua, joten talot katsoivat
päätielle ja ovet jäivät metsän taakse. Kadut kulkevat rivien välissä aseman suunnassa U (rata) ja sitä vasten kohtisuoraan N:
- Vaalantie jatkuu pohjoisen rivin edessä (n -685) itään,
- Mäntytie yhdistää Vaalantien Kätkötiehen (u 1244),
- Rekkatie kulkee talorivien välissä (n -524),
- Pihlajatie sulkee kehän idässä (u 1480), Koivukuja ja Rinnetie ovat umpikatuja talojen väliin.
Kadut ovat kapeita asfalttikatuja (street 1, kuten Satamantie). Kadulle osuvat pienet talot (alle 45 m², ei nimeä) poistuvat,
isomman osuessa ajo pysähtyy. Maasto tasataan ja puut raivataan kadun reunoilta (kuten vaala_kirkkotie.py).

Koulukeskus (OSM 472392144, 256 m pitkä 33 kulman monikulmio) on pois (vaala_bake.py DROP_BUILDING_IDS).
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

U = (0.9525, -0.3047)  # aseman suunta (rata), x itään, z etelään
N = (0.3047, 0.9525)   # sitä vasten, etelään
STREET_HW = 2.75       # vaala.gd STREET_HALF
CLEAR = 1.6            # kadun reunasta talon seinään vähintään
NURMI_R = 10.0         # kadun vierus nurmeksi tähän asti
SMALL = 45.0           # tätä pienempi nimetön talo saa väistyä kadulta

# [nimi, [(u, n), ...]]
STREETS = [
    ("Vaalantie", [(1293.0, -681.0), (1480.0, -685.0)]),
    ("Mäntytie", [(1244.0, -664.0), (1244.0, -449.0)]),
    ("Rekkatie", [(1150.0, -524.0), (1480.0, -524.0)]),
    ("Pihlajatie", [(1480.0, -685.0), (1480.0, -524.0)]),
]


def xz(u, n):
    return (u * U[0] + n * N[0], u * U[1] + n * N[1])


def un(p):
    return (p[0] * U[0] + p[1] * U[1], p[0] * N[0] + p[1] * N[1])


def area(pts):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2.0


def nurmi():
    """Katujen vierukset nurmeksi: raivatun kadun reunan metsänpohja (ruskea hiekka) piha-nurmeksi NURMI_R m asti.
    Ajo kerran kaduilla (`--nurmi`), merkitään tie.json:iin "kadut_nurmi"."""
    tie = VS.load_tie()
    if not tie.get("kadut") or tie.get("kadut_nurmi"):
        sys.exit("aja ensin kadut, eikä nurmea ole vielä tehty")
    terr = VS.Terrain()
    lanes = [VL.resample([tuple(q[:2]) for q in r["pts"]], 3.0) for r in tie["side_roads"] if r.get("_kadut")]
    n = 0
    for lane in lanes:
        xs, zs = [q[0] for q in lane], [q[1] for q in lane]
        for i, j, q in terr.cells((min(xs) - NURMI_R, min(zs) - NURMI_R, max(xs) + NURMI_R, max(zs) + NURMI_R)):
            k = j * terr.nx + i
            if terr.codes[k] in (VS.FOREST, VS.SHOULDER) and min(math.dist(q, p) for p in lane) < NURMI_R:
                terr.codes[k] = VS.YARD
                terr.changed.add((i, j))
                n += 1
    print("nurmeksi %d ruutua" % n)
    tie["kadut_nurmi"] = True
    VS.save_tie(tie)
    terr.save()


def main():
    if "--nurmi" in sys.argv:
        return nurmi()
    dry = "--kuiva" in sys.argv
    tie = VS.load_tie()
    if tie.get("kadut") and not dry:
        sys.exit("kadut on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    terr, trees = VS.Terrain(), VS.Trees()
    wl = tie["water_level"]
    streets = [(name, [xz(*q) for q in pts]) for name, pts in STREETS]
    streets += extra_streets(tie)
    lanes = [VL.resample(p, 2.0) for _, p in streets]

    removed, blocked = [], []
    kept = []
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        d = min(VS.poly_dist(q, pts) for lane in lanes for q in lane)
        if d >= STREET_HW + CLEAR:
            kept.append(b)
        elif not b.get("name") and area(pts) < SMALL:
            removed.append(b)
        else:
            blocked.append((b["id"], b["type"], b.get("name"), round(area(pts)), round(d, 1)))
    print("poistuvat talot:", [(b["id"], round(area([tuple(q) for q in b["pts"]]))) for b in removed])
    if blocked:
        print("KADUN PÄÄLLÄ ISO TALO:", blocked)
    names = ["metsä", "pelto", "suo", "vesi", "piha", "piennar", "tie", "rata"]
    for (name, _), lane in zip(streets, lanes):
        cnt = {}
        for q in lane:
            cc = terr.code(q)
            cnt[names[cc] if cc < 8 else "ulko"] = cnt.get(names[cc] if cc < 8 else "ulko", 0) + 1
        print("katu %s %.0f m, maasto %s" % (name, sum(math.dist(a, b) for a, b in zip(lane, lane[1:])), cnt))
    if dry:
        plot(tie, sys.argv[sys.argv.index("--kuiva") + 1], streets, removed)
        return
    if blocked:
        sys.exit("siirrä katua")

    tie["buildings"] = kept
    for name, pts in streets:
        tie["side_roads"].append({"kind": "road", "hw": "residential", "name": name, "surface": "asphalt", "street": 1, "_kadut": 1,
                                  "pts": [[round(x, 2), round(z, 2)] for x, z in pts]})
        terr.lane(pts, wl)
    near = trees.near_any([q for lane in lanes for q in lane], 5.5)
    print("puita pois %d" % int(near.sum()))
    trees.remove(near)
    trees.reground(terr)
    tie["kadut"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


def extra_streets(tie):
    """Umpikadut talojen väliin: Koivukuja (Rekkatieltä pohjoiseen Katjan talolle) ja Rinnetie (Vaalantieltä etelään)."""
    out = []
    bl = [[un(q) for q in b["pts"]] for b in tie["buildings"]]
    for name, n0, n1, lo, hi in (("Koivukuja", -524.0, -562.0, 1276.0, 1345.0), ("Rinnetie", -685.0, -640.0, 1346.0, 1470.0)):
        best = None
        for u in range(int(lo), int(hi), 2):
            hit = 0
            for pts in bl:
                us = [p[0] for p in pts if min(n0, n1) - 3 <= p[1] <= max(n0, n1) + 3]
                if us and min(us) - (STREET_HW + CLEAR) < u < max(us) + (STREET_HW + CLEAR):
                    hit += 1
            if best is None or hit < best[0]:
                best = (hit, u)
        print("%s: u %d, osumia %d" % (name, best[1], best[0]))
        out.append((name, [xz(best[1], n0), xz(best[1], n1)]))
    return out



def plot(tie, path, streets, removed):
    from PIL import Image, ImageDraw
    x0, x1, z0, z1, S = 940.0, 1260.0, -1130.0, -830.0, 5.0
    im = Image.new("RGB", (int((x1 - x0) * S), int((z1 - z0) * S)), (235, 230, 210))
    g = ImageDraw.Draw(im)
    P = lambda p: ((p[0] - x0) * S, (p[1] - z0) * S)
    rem = {b["id"] for b in removed}
    for b in tie["buildings"]:
        g.polygon([P(q) for q in b["pts"]], fill=(220, 60, 60) if b["id"] in rem else (150, 140, 140))
    for r in tie["side_roads"]:
        if r["kind"] != "rail":
            g.line([P(q[:2]) for q in r["pts"]], fill=(190, 190, 190), width=int(S * 5))
    for name, pts in streets:
        g.line([P(q) for q in pts], fill=(40, 40, 40), width=int(S * 2 * STREET_HW))
    im.save(path)


if __name__ == "__main__":
    main()
