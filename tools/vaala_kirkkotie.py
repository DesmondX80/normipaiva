#!/usr/bin/env python3
"""Vaalan tori, matkakeskus ja Zabuki käännetään tien varteen, K-Market siirtyy tien varteen ja Torintie jatkuu kirkolle
(assets/vaala/tie.json, maasto.bin, puut.bin).

Ajo kerran: venv/bin/python tools/vaala_kirkkotie.py   (viimeinen vaihe vaala_kmarket_ymparyra.py:n jälkeen)
Kuiva-ajo (ei kirjoita mitään, tulostaa osumat ja kuvan): venv/bin/python tools/vaala_kirkkotie.py --kuiva <kuva.png>
tie.json:iin merkitään "kirkkotie": true, ja uusi ajo kieltäytyy. Uusi lähtötilanne: git checkout assets/vaala.

Suunnat (x itään, z etelään): ympyrästä a = Torintien suunta (pohjoiseen-luoteeseen), td = Vaalantien jatke (koilliseen).
- Tori, matkakeskus ja Zabuki kääntyvät yhtenä ryhmänä 90 astetta vastapäivään torin keskipisteen ympäri: torin pitkä sivu on
  Torintien suuntainen, matkakeskus on sen länsireunalla julkisivu itään (torille ja tielle) ja Zabuki torin eteläpäässä.
  Ryhmä siirtyy sivuun (TORI_SIIRTO) niin, että Torintie kulkee torin vierestä.
- K-Market kääntyy 90 astetta myötäpäivään: pitkä sivu tien suuntaan, julkisivu (ovi ja parkkipaikka) tielle luoteeseen, tien
  kaakkoispuolelle. Vaalantie (kauppatie) jatkuu kaupan ohi.
- Torintie jatkuu torin ja matkakeskuksen ohi kirkon pihaan; kirkko (tie.json keskusta.kirkko, vaala.gd _build_kirkko) seisoo
  tien päässä torni tielle päin (Saloisten kirkon malli).
- Tontit tasoitetaan, puut pois, vapautuneet pihat takaisin maastoksi, tieltä ja tonteilta häviävät pienet talot.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vaala_keskusta as K  # noqa: E402
import vaala_lava as VL  # noqa: E402
import vaala_sahanranta as VS  # noqa: E402

TORI_SIIRTO = 19.0      # ryhmä sivuun Torintien akselilta (torin itäreuna 8 m akselista)
KM_SIZE = (27.0, 18.0)  # K-Market: pituus tien suuntaan x syvyys
KM_U = 96.0             # kaupan keskikohta Vaalantien jatkeella ympyrän keskipisteestä
KM_PARK = 12.0          # parkkipaikan syvyys kaupan edessä
KM_ROAD_HALF = 5.5      # tien keskiviivasta ajoradan ja pientareen reunaan
KM_ROAD_PAST = 134.0    # tie jatkuu kaupan takareunan ohi näin pitkälle (100 m entistä pidemmälle)
KIRKKO_LEN, KIRKKO_DEPTH = 22.0, 11.0   # kirkon laiva (torni sen päässä, vaala.gd _build_kirkko)
KIRKKO_TORNI = 5.4
KIRKKO_U = 192.0        # Torintien pää ympyrästä (100 m entistä pidemmälle)
KIRKKO_AT = 112.0       # kirkon kohta tiellä ympyrästä laskien
KIRKKO_SETBACK = 14.0   # tien keskiviivasta kirkon tornin etuseinään (väliin parkki)
RB_R = 12.0
KEEP = (225699578, K.KMARKET_ID, K.GASTHAUS_ID, 178199720, 225699572, 225699563)  # Siitari, K-Market, Gasthaus, asema, hotelli, kunnantalo


def unit(v):
    L = math.hypot(*v)
    return (v[0] / L, v[1] / L)


def rot_ccw(v):
    """90 astetta vastapäivää kartalla (x itään, z etelään): pohjoinen -> länsi -> etelä -> itä."""
    return (v[1], -v[0])


def rot_cw(v):
    return (-v[1], v[0])


def add(p, *terms):
    x, z = p
    for k, v in terms:
        x += k * v[0]
        z += k * v[1]
    return (x, z)


def dense(p, st=1.0):
    out = []
    for a, b in zip(p, p[1:] + p[:1]):
        n = max(1, int(math.dist(a, b) / st))
        out += [(a[0] + (b[0] - a[0]) * t / n, a[1] + (b[1] - a[1]) * t / n) for t in range(n)]
    return out


def near(a, b, m):
    da, db = dense(a), dense(b)
    return any(K.in_poly(q, b) for q in da) or any(K.in_poly(q, a) for q in db) or min(K.poly_dist(q, b) for q in da) < m


def main():
    dry = "--kuiva" in sys.argv
    tie = VS.load_tie()
    if tie.get("kirkkotie") and not dry:
        sys.exit("kirkkotie on jo tehty; uusi lähtötilanne: git checkout assets/vaala")
    if not tie.get("kmarket_ymparyra"):
        sys.exit("aja ensin vaala_kmarket_ymparyra.py")
    terr, trees = VS.Terrain(), VS.Trees()
    wl = tie["water_level"]
    kes = tie["keskusta"]

    c = tuple(kes["asema"]["roundabout"]["c"])
    road = tie["road"]
    td = unit((road[-1][0] - road[-8][0], road[-1][2] - road[-8][2]))     # Vaalantie ympyrään: suoraan eteen
    rt = (-td[1], td[0])                                                   # oikealle (kaakkoon)
    torintie = next(r for r in tie["side_roads"] if r.get("name") == "Torintie")
    a = unit((torintie["pts"][-1][0] - torintie["pts"][0][0], torintie["pts"][-1][1] - torintie["pts"][0][1]))  # Torintien suunta
    ar = rot_cw(a)        # akselin oikea puoli (itään)
    al = rot_ccw(a)       # akselin vasen puoli (länteen)

    # --- Tori, matkakeskus ja Zabuki: ryhmä käännetään torin keskipisteen ympäri ja siirretään sivuun. ---
    tori_old = next(r for r in tie["side_roads"] if r.get("name") == "Vaalan tori")
    tpts = [tuple(q) for q in tori_old["pts"][:-1]]
    tc0 = (sum(q[0] for q in tpts) / len(tpts), sum(q[1] for q in tpts) / len(tpts))
    shift = (al[0] * TORI_SIIRTO, al[1] * TORI_SIIRTO)

    def turn(p):
        d = rot_ccw((p[0] - tc0[0], p[1] - tc0[1]))
        return (tc0[0] + d[0] + shift[0], tc0[1] + d[1] + shift[1])

    mk0, zb0 = kes["matkakeskus"], kes["zabuki"]
    tori_new = [turn(q) for q in tpts]
    tc1 = turn(tc0)
    mk_c = turn(tuple(mk0["c"]))
    mk_face = rot_ccw(tuple(mk0["face"]))
    mk_ax = (-mk_face[1], mk_face[0])
    mk_rect = [(mk_c[0] + mk_ax[0] * sx * mk0["len"] / 2 + mk_face[0] * sz * mk0["depth"] / 2,
                mk_c[1] + mk_ax[1] * sx * mk0["len"] / 2 + mk_face[1] * sz * mk0["depth"] / 2) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    # Zabuki on matkakeskuksen sisällä: tiskiluukku +u-päädyssä (ulospäin mk_ax), asiakkaat seisovat päädyn edessä.
    zb_face = mk_ax
    zb_c = (mk_c[0] + mk_ax[0] * mk0["len"] / 2.0, mk_c[1] + mk_ax[1] * mk0["len"] / 2.0)
    zb_rect = [(zb_c[0] + mk_face[0] * sx * 6.0 + mk_ax[0] * sz * 4.5 + mk_ax[0] * 4.5, zb_c[1] + mk_face[1] * sx * 6.0 + mk_ax[1] * sz * 4.5 + mk_ax[1] * 4.5)
               for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    print("tori %s -> %s | matkakeskus %s -> %s julkisivu %s | Zabuki %s -> %s" % (
        [round(v, 1) for v in tc0], [round(v, 1) for v in tc1], mk0["c"], [round(v, 1) for v in mk_c], [round(v, 2) for v in mk_face],
        zb0["c"], [round(v, 1) for v in zb_c]))

    # --- Torintie: ympyrästä kirkon pihaan. ---
    arm0 = add(c, (RB_R - 0.5, a))
    arm1 = add(c, (KIRKKO_U, a))
    # --- Kirkko: tien vasemmalla (länsi)puolella, torni (julkisivu) tielle päin eli itään; laiva ja torni samalla akselilla. ---
    k_face = ar
    k_c = add(c, (KIRKKO_AT, a), (KIRKKO_SETBACK + KIRKKO_TORNI + 1.0 + KIRKKO_LEN / 2.0 - 0.4, al))
    k_rect = [(k_c[0] + k_face[0] * sx * (KIRKKO_LEN / 2.0 + KIRKKO_TORNI) + a[0] * sz * (KIRKKO_DEPTH / 2.0 + 1.5),
               k_c[1] + k_face[1] * sx * (KIRKKO_LEN / 2.0 + KIRKKO_TORNI) + a[1] * sz * (KIRKKO_DEPTH / 2.0 + 1.5)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    k_yard = [(k_c[0] + k_face[0] * sx * (KIRKKO_LEN / 2.0 + KIRKKO_TORNI + 3.0) + a[0] * sz * 18.0,
               k_c[1] + k_face[1] * sx * (KIRKKO_LEN / 2.0 + KIRKKO_TORNI + 3.0) + a[1] * sz * 18.0) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    k_park = K.rect(add(c, (KIRKKO_AT, a), (6.5 + (KIRKKO_SETBACK - 6.5) / 2.0 - 0.5, al)), a, ar, 8.0, (KIRKKO_SETBACK - 6.5) / 2.0 - 0.3)  # parkki tien ja kirkon välissä

    # --- K-Market: tien kaakkoispuolelle, julkisivu luoteeseen (-rt) tielle. ---
    km_face = (-rt[0], -rt[1])
    v_store = KM_ROAD_HALF + 1.0 + KM_PARK + KM_SIZE[1] / 2.0
    km_c = add(c, (KM_U, td), (v_store, rt))
    km_pts = K.rect(km_c, td, rt, KM_SIZE[0] / 2.0, KM_SIZE[1] / 2.0)
    km_park = K.rect(add(c, (KM_U, td), (KM_ROAD_HALF + 1.0 + KM_PARK / 2.0, rt)), td, rt, KM_SIZE[0] / 2.0 + 4.0, KM_PARK / 2.0)
    km_lot = K.rect(add(c, (KM_U, td), ((KM_ROAD_HALF + 1.0 + KM_PARK + KM_SIZE[1] / 2.0), rt)), td, rt, KM_SIZE[0] / 2.0 + 4.0,
                    (KM_PARK + KM_SIZE[1]) / 2.0)
    kt0 = add(c, (RB_R - 0.5, td))
    kt1 = add(c, (KM_U + KM_SIZE[0] / 2.0 + KM_ROAD_PAST, td))
    print("K-Market %s julkisivu %s, tie %.0f m" % ([round(v, 1) for v in km_c], [round(v, 2) for v in km_face], math.dist(kt0, kt1)))
    print("kirkko %s julkisivu %s, Torintie %.0f m" % ([round(v, 1) for v in k_c], [round(v, 2) for v in k_face], math.dist(arm0, arm1)))

    # --- Tieltä ja tonteilta poistuvat rakennukset (suojatut eivät saa osua). ---
    lane_t = VL.resample([arm0, arm1], 2.0)
    lane_k = VL.resample([kt0, kt1], 2.0)
    lots = [tori_new, mk_rect, zb_rect, k_rect, k_yard, [tuple(q) for q in km_lot], [tuple(q) for q in km_park], k_park]
    lots = [[tuple(q) for q in p] for p in lots]
    kept, removed = [], []
    km_old = next(b for b in tie["buildings"] if b["id"] == K.KMARKET_ID)
    for b in tie["buildings"]:
        pts = [tuple(q) for q in b["pts"]]
        if b is km_old:
            kept.append(b)
            continue
        hit = any(near(pts, p, 2.5) for p in lots) or min(VS.poly_dist(q, pts) for q in lane_t) < 5.5 \
            or min(VS.poly_dist(q, pts) for q in lane_k) < 5.5
        if hit:
            if b["id"] in KEEP:
                sys.exit("uusi paikka osuu suojattuun rakennukseen %s %s" % (b["id"], b.get("name")))
            removed.append(b)
        else:
            kept.append(b)
    print("poistuvat rakennukset:", [(b["id"], b["kind"], b.get("name") or b.get("addr")) for b in removed])
    old_km_c = VS.center([tuple(q) for q in km_old["pts"]])
    old_km_park = min(tie["parkings"], key=lambda p: math.dist(VS.center([tuple(q) for q in p]), old_km_c))  # K-Marketin edessä
    if math.dist(VS.center([tuple(q) for q in old_km_park]), old_km_c) > 25.0:
        sys.exit("K-Marketin vanhaa parkkia ei löytynyt")
    bad_pk = []
    for pk in tie["parkings"]:
        pp = [tuple(q) for q in pk]
        if pk is old_km_park:
            continue
        if any(near(pp, p, 1.0) for p in lots) or min(VS.poly_dist(q, pp) for q in lane_t + lane_k) < 5.0:
            bad_pk.append(pk)
    print("poistuvat parkkipaikat:", [p[0] for p in bad_pk])
    names = ["metsä", "pelto", "suo", "vesi", "piha", "piennar", "tie", "rata"]
    for nm, pl in (("kirkon piha", k_yard), ("kauppa", [tuple(q) for q in km_lot]), ("tori", tori_new), ("matkakeskus", mk_rect)):
        cnt = {}
        for i, j, q in terr.cells(K.bbox(pl, 0)):
            if K.in_poly(q, pl):
                cnt[names[terr.codes[j * terr.nx + i]] if terr.codes[j * terr.nx + i] < 8 else "ulko"] = cnt.get(names[terr.codes[j * terr.nx + i]] if terr.codes[j * terr.nx + i] < 8 else "ulko", 0) + 1
        print("maasto %s: %s" % (nm, cnt))
    cnt = {}
    for q in lane_t + lane_k:
        cc = terr.code(q)
        cnt[names[cc] if cc < 8 else "ulko"] = cnt.get(names[cc] if cc < 8 else "ulko", 0) + 1
    print("maasto teiden alla:", cnt)
    if dry:
        plot(tie, sys.argv[sys.argv.index("--kuiva") + 1], dict(tori=tori_new, mk=mk_rect, zb=zb_rect, kirkko=k_rect, yard=k_yard,
             km=km_pts, kmpark=km_park, kpark=k_park, lane_t=[arm0, arm1], lane_k=[kt0, kt1], removed=removed, c=c))
        return

    # --- Tie.json ---
    tie["buildings"] = kept
    tie["parkings"] = [p for p in tie["parkings"] if p is not old_km_park and p not in bad_pk] + [km_park, k_park]
    old_km_pts = [tuple(q) for q in km_old["pts"]]
    km_old["pts"] = km_pts
    km_old["door_to"] = [round(v, 2) for v in add(c, (KM_U, td), (KM_ROAD_HALF, rt))]  # ovi tielle päin
    tori_old["pts"] = [[round(q[0], 2), round(q[1], 2)] for q in tori_new + [tori_new[0]]]
    kes["matkakeskus"] = dict(mk0, c=[round(mk_c[0], 2), round(mk_c[1], 2)], face=[round(mk_face[0], 4), round(mk_face[1], 4)])
    kes["zabuki"] = dict(zb0, c=[round(zb_c[0], 2), round(zb_c[1], 2)], face=[round(zb_face[0], 4), round(zb_face[1], 4)])
    kes["kirkko"] = {"c": [round(k_c[0], 2), round(k_c[1], 2)], "face": [round(k_face[0], 4), round(k_face[1], 4)],
                     "len": KIRKKO_LEN, "depth": KIRKKO_DEPTH, "tower": KIRKKO_TORNI}
    torintie["pts"] = [[round(arm0[0], 2), round(arm0[1], 2)], [round(arm1[0], 2), round(arm1[1], 2)]]
    kauppatie = next(r for r in tie["side_roads"] if r.get("_kmarket"))
    kauppatie["pts"] = [[round(kt0[0], 2), round(kt0[1], 2)], [round(kt1[0], 2), round(kt1[1], 2)]]

    # --- Maasto: tontit tasaisiksi, tiet, vapautuneet pihat takaisin maastoksi; puut pois. ---
    # Vapautuneet tontit (vanha tori, matkakeskus, Zabuki, K-Market ja sen parkki) takaisin ympäröivään maahan, ellei uusi tontti,
    # tie tai talo ole siinä.
    old_lots = [tpts, [tuple(q) for q in K.rect(tuple(mk0["c"]), (-mk0["face"][1], mk0["face"][0]), tuple(mk0["face"]), mk0["len"] / 2.0, mk0["depth"] / 2.0)],
                [tuple(q) for q in K.rect(tuple(zb0["c"]), (-zb0["face"][1], zb0["face"][0]), tuple(zb0["face"]), K.ZB_SIZE[0] / 2.0 + 1.5, K.ZB_SIZE[1] / 2.0 + 3.0)],
                [tuple(q) for q in old_km_pts] , [tuple(q) for q in old_km_park]]
    new_lots = lots
    keep_pts = lane_t + lane_k + VL.resample([c, add(c, (60.0, rt))], 3.0)
    rev = 0
    for pl in old_lots:
        for i, j, q in terr.cells(K.bbox(pl, 6.0)):
            k = j * terr.nx + i
            if terr.codes[k] != VS.YARD or K.poly_dist(q, pl) > 2.6:
                continue
            if any(K.poly_dist(q, p) < 3.5 for p in new_lots) or any(math.dist(q, p) < 9.0 for p in keep_pts) \
                    or any(VS.poly_dist(q, b["pts"]) < 6.0 for b in tie["buildings"]) or math.dist(q, c) < RB_R + 8.0:
                continue
            neigh = []
            for a_ in range(16):
                for rad in (7.0, 10.0, 14.0):
                    cc = terr.code((q[0] + math.cos(a_ * math.tau / 16) * rad, q[1] + math.sin(a_ * math.tau / 16) * rad))
                    if cc in (VS.FOREST, VS.FIELD, VS.BOG):
                        neigh.append(cc)
            terr.codes[k] = max(set(neigh), key=neigh.count) if neigh else VS.FOREST
            terr.changed.add((i, j))
            rev += 1
    print("vapautunutta pihaa takaisin maaksi: %d ruutua" % rev)
    terr.flatten([tori_new, mk_rect, zb_rect], 8.0)
    terr.flatten([k_rect, k_yard], 8.0)
    terr.flatten([[tuple(q) for q in km_lot]], 8.0)
    terr.lane([arm0, arm1], wl)
    terr.lane([kt0, kt1], wl)
    pts = []
    for p in lots:
        xs, zs = [q[0] for q in p], [q[1] for q in p]
        gx = min(xs)
        while gx <= max(xs):
            gz = min(zs)
            while gz <= max(zs):
                if K.in_poly((gx, gz), p):
                    pts.append((gx, gz))
                gz += 2.0
            gx += 2.0
    near_t = trees.near_any(pts, 3.5) | trees.near_any(lane_t + lane_k, 6.5)
    print("puita pois %d" % int(near_t.sum()))
    trees.remove(near_t)
    trees.reground(terr)
    tie["kirkkotie"] = True
    VS.save_tie(tie)
    terr.save()
    trees.save()


def plot(tie, path, o):
    from PIL import Image, ImageDraw
    x0, x1, z0, z1, S = 660.0, 1010.0, -1160.0, -840.0, 5.0
    im = Image.new("RGB", (int((x1 - x0) * S), int((z1 - z0) * S)), (235, 230, 210))
    g = ImageDraw.Draw(im)
    P = lambda p: ((p[0] - x0) * S, (p[1] - z0) * S)
    rem = {b["id"] for b in o["removed"]}
    for b in tie["buildings"]:
        g.polygon([P(q) for q in b["pts"]], fill=(220, 60, 60) if b["id"] in rem else (150, 140, 140))
    for pk in tie["parkings"]:
        g.polygon([P(q) for q in pk], fill=(190, 190, 190))
    for r in tie["side_roads"]:
        if r["kind"] == "rail" or r.get("name") == "Vaalan tori":
            continue
        g.line([P(q) for q in r["pts"]], fill=(190, 190, 190), width=int(S * 6))
    g.polygon([P(q) for q in o["tori"]], fill=(200, 170, 150))
    g.line([P(q) for q in o["lane_t"]], fill=(60, 60, 60), width=int(S * 8))
    g.line([P(q) for q in o["lane_k"]], fill=(60, 60, 60), width=int(S * 8))
    for key, col in (("mk", (60, 90, 160)), ("zb", (30, 30, 30)), ("kirkko", (250, 250, 250)), ("km", (230, 120, 20))):
        g.polygon([P(q) for q in o[key]], fill=col, outline=(0, 0, 0))
    for key in ("kmpark", "kpark"):
        g.polygon([P(q) for q in o[key]], fill=(180, 180, 200))
    g.line([P(q) for q in o["yard"] + [o["yard"][0]]], fill=(0, 140, 0), width=2)
    cc = P(o["c"])
    g.ellipse([cc[0] - 12 * S, cc[1] - 12 * S, cc[0] + 12 * S, cc[1] + 12 * S], outline=(255, 0, 0), width=3)
    im.save(path)


if __name__ == "__main__":
    main()
