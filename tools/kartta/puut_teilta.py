"""Puut pois teiltä, poluilta ja radoilta valmiista puutiedostoista (ONP3, scripts/forest.gd).

Leivonnat (mokki_puut.py, vaala_bake.py) karsivat puut päätieltä, mutta Vaalan sivuteille, kaduille, poluille ja
radoille sekä mökin pihatielle jäi puita. Tämä lukee valmiin puut.bin:n, poistaa puut, joiden runko on
piirretyn tien päällä tai alle MARGIN m sen reunasta, ja kirjoittaa tiedoston samassa muodossa (puiden
lajit, latvukset ja satunnaisluvut säilyvät). Tienleveydet samat kuin pelin piirrossa (mokki.gd _build_waters_and_roads
ja _build_yard_extras, vaala.gd _build_side_roads ja päätie). Ei tarvitse laserkeilauksen välimuistia.

Ajo: venv/bin/python tools/kartta/puut_teilta.py [--mokki] [--vaala]  (oletus molemmat)
Leivonnat ajavat tämän lopuksi itse (filter_mokki / filter_vaala).
"""
import argparse
import json
import math
import os
import struct

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MOKKI_TREES = os.path.join(ROOT, "assets", "mokki", "puut.bin")
MOKKI_MAP = os.path.join(ROOT, "assets", "mokki", "kartta.json")
VAALA_TREES = os.path.join(ROOT, "assets", "vaala", "puut.bin")
VAALA_ROAD = os.path.join(ROOT, "assets", "vaala", "tie.json")

MARGIN = 0.8  # rungon etäisyys tien reunasta vähintään (latvus saa ulottua tien ylle)
SPECIES = 5

# scripts/mokki.gd: mökin kehys karttakehyksessä ja pihatie taksipysäkiltä mökin taakse.
YARD_C = (1.0, 2.35)
YARD_ROT_DEG = 17.6
MOKKI_DRIVE = [((-7.0, -29.0), (1.0, -4.5), 1.6)]


def read_onp3(path):
    with open(path, "rb") as f:
        b = f.read()
    assert b[:4] == b"ONP3", path
    n, W, H, far_chunk, near_chunk, x0, z0, nfx, nfz, nnx, nnz = struct.unpack("<IIIffffIIII", b[4:48])
    off = 48 + (nfx * nfz + nnx * nnz) * SPECIES * 8
    t0 = np.frombuffer(b, "<f4", W * H * 4, off).reshape(-1, 4)[:n].copy()
    t1 = np.frombuffer(b, np.uint8, W * H * 4, off + W * H * 16).reshape(-1, 4)[:n].copy()
    return t0, t1, far_chunk, near_chunk


def write_onp3(path, t0, t1, far_chunk, near_chunk):
    """Sama lohkojako kuin tarkka.write_trees (kaukolohko -> laji -> lähilohko), puukohtaiset tavut säilyvät."""
    x, z, sp = t0[:, 0], t0[:, 2], t1[:, 1].astype(np.int64)
    x0 = math.floor(x.min() / far_chunk) * far_chunk
    z0 = math.floor(z.min() / far_chunk) * far_chunk
    nfx = int(math.ceil((x.max() - x0 + 0.01) / far_chunk))
    nfz = int(math.ceil((z.max() - z0 + 0.01) / far_chunk))
    r = int(far_chunk / near_chunk)
    nnx, nnz = nfx * r, nfz * r
    fi = ((x - x0) // far_chunk).astype(int)
    fj = ((z - z0) // far_chunk).astype(int)
    ni = ((x - x0) // near_chunk).astype(int)
    nj = ((z - z0) // near_chunk).astype(int)
    order = np.lexsort((nj * nnx + ni, sp, fj * nfx + fi))
    t0, t1, sp = t0[order], t1[order], sp[order]
    fkey = (fj * nfx + fi)[order]
    nkey = (nj * nnx + ni)[order]
    far_tab = np.zeros((nfx * nfz, SPECIES, 2), np.uint32)
    near_tab = np.zeros((nnx * nnz, SPECIES, 2), np.uint32)
    for tab, key in ((far_tab, fkey), (near_tab, nkey)):
        comb = key.astype(np.int64) * SPECIES + sp
        starts = np.nonzero(np.r_[True, comb[1:] != comb[:-1]])[0]
        counts = np.diff(np.r_[starts, len(comb)])
        k = comb[starts]
        tab[k // SPECIES, k % SPECIES, 0] = starts
        tab[k // SPECIES, k % SPECIES, 1] = counts
    W = 2048
    H = (len(t0) + W - 1) // W
    a = np.zeros((H * W, 4), "<f4")
    a[:len(t0)] = t0
    bb = np.zeros((H * W, 4), np.uint8)
    bb[:len(t0)] = t1
    with open(path, "wb") as f:
        f.write(b"ONP3" + struct.pack("<IIIffffIIII", len(t0), W, H, far_chunk, near_chunk, x0, z0, nfx, nfz, nnx, nnz))
        f.write(far_tab.tobytes())
        f.write(near_tab.tobytes())
        f.write(a.tobytes())
        f.write(bb.tobytes())


def road_mask(x, z, segments, cell=4.0):
    """True puille, jotka ovat alle (puolileveys + MARGIN) m jostain janasta. segments = [(a, b, half), ...].
    Janat ruudukkoon, jotta jokaista puuta ei verrata jokaiseen janaan."""
    bad = np.zeros(len(x), bool)
    gx = np.floor(x / cell).astype(np.int64)
    gz = np.floor(z / cell).astype(np.int64)
    key = gx * 1_000_003 + gz
    order = np.argsort(key)
    skey = key[order]
    for (ax, az), (bx, bz), half in segments:
        w = half + MARGIN
        i0, i1 = int(math.floor((min(ax, bx) - w) / cell)), int(math.floor((max(ax, bx) + w) / cell))
        j0, j1 = int(math.floor((min(az, bz) - w) / cell)), int(math.floor((max(az, bz) + w) / cell))
        idx = []
        for i in range(i0, i1 + 1):
            lo = np.searchsorted(skey, i * 1_000_003 + j0)
            hi = np.searchsorted(skey, i * 1_000_003 + j1, side="right")
            if hi > lo:
                idx.append(order[lo:hi])
        if not idx:
            continue
        idx = np.concatenate(idx)
        px, pz = x[idx], z[idx]
        dx, dz = bx - ax, bz - az
        t = np.clip(((px - ax) * dx + (pz - az) * dz) / max(dx * dx + dz * dz, 1e-9), 0.0, 1.0)
        d = np.hypot(px - ax - dx * t, pz - az - dz * t)
        bad[idx[d < w]] = True
    return bad


def polyline(pts, half):
    return [(tuple(pts[k]), tuple(pts[k + 1]), half) for k in range(len(pts) - 1)]


def mokki_segments():
    k = json.load(open(MOKKI_MAP, encoding="utf-8"))
    b = math.radians(YARD_ROT_DEG)

    def to_local(p):
        dx, dz = p[0] - YARD_C[0], p[1] - YARD_C[1]
        return (dx * math.cos(b) + dz * math.sin(b), -dx * math.sin(b) + dz * math.cos(b))

    segs = list(MOKKI_DRIVE)
    for f in k["features"]:
        if f["kind"] != "road":
            continue
        t = f.get("type")
        half = 3.2 if t in ("tertiary", "secondary") else (0.6 if t in ("path", "footway") else
            (2.6 if t == "unclassified" else (1.4 if t == "service" else 1.8)))
        half = max(half, 1.2)  # polulla kulkijalle tilaa
        segs += polyline([to_local(p) for p in f["pts"]], half)
    return segs


def vaala_segments():
    d = json.load(open(VAALA_ROAD, encoding="utf-8"))
    road = d["road"]  # [x, y, z, s, puolileveys, ...]
    segs = [((road[i][0], road[i][2]), (road[i + 1][0], road[i + 1][2]), road[i][4]) for i in range(len(road) - 1)]
    for br in d["branches"]:
        segs += polyline([(p[0], p[2]) for p in br["pts"]], br.get("hw", 2.6))
    for r in d["side_roads"]:
        hw, half = r["hw"], 2.2
        if r["kind"] == "rail":
            half = 1.6
        elif hw in ("footway", "cycleway", "path", "pedestrian"):
            half = 1.3
        elif hw in ("secondary", "tertiary", "residential") or r["surface"] in ("asphalt", "paved"):
            half = 3.2 if hw in ("secondary", "tertiary") else 2.6
        elif hw == "service":
            half = 1.8
        segs += polyline([(p[0], p[1]) for p in r["pts"]], half)
    return segs


def in_poly(poly, x, z):
    """Pisteet monikulmion sisällä (parillisuussääntö)."""
    inside = np.zeros(len(x), bool)
    n = len(poly)
    for k in range(n):
        ax, az = poly[k]
        bx, bz = poly[(k + 1) % n]
        cross = (az > z) != (bz > z)
        xi = ax + (z - az) * (bx - ax) / ((bz - az) if bz != az else 1e-9)
        inside ^= cross & (x < xi)
    return inside


def filter_file(path, segs, label, polys=()):
    t0, t1, fc, nc = read_onp3(path)
    bad = road_mask(t0[:, 0], t0[:, 2], segs)
    for poly in polys:
        xs, zs = [p[0] for p in poly], [p[1] for p in poly]
        near = (t0[:, 0] > min(xs)) & (t0[:, 0] < max(xs)) & (t0[:, 2] > min(zs)) & (t0[:, 2] < max(zs))
        if near.any():
            bad[near] |= in_poly(poly, t0[near, 0], t0[near, 2])
    names = ["mänty", "kuusi", "koivu", "haapa/muu", "pensas"]
    gone = ", ".join("%s %d" % (names[s], int((bad & (t1[:, 1] == s)).sum())) for s in range(SPECIES))
    print("%s: %d puuta, teiltä ja poluilta pois %d (%s)" % (label, len(t0), int(bad.sum()), gone))
    if bad.any():
        write_onp3(path, t0[~bad], t1[~bad], fc, nc)


def filter_mokki():
    filter_file(MOKKI_TREES, mokki_segments(), "mökki")


def filter_vaala():
    parkings = json.load(open(VAALA_ROAD, encoding="utf-8")).get("parkings", [])
    filter_file(VAALA_TREES, vaala_segments(), "Vaala", parkings)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mokki", action="store_true")
    ap.add_argument("--vaala", action="store_true")
    a = ap.parse_args()
    both = not a.mokki and not a.vaala
    if a.mokki or both:
        filter_mokki()
    if a.vaala or both:
        filter_vaala()


if __name__ == "__main__":
    main()
