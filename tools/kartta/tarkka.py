"""Tarkka mallinnus mökille ja Vaalan mopomatkalle (sama aineisto ja tekniikka kuin Oulujärven norpissa):

- MML:n korkeusmalli 2 m (Kapsi), mosaiikki mielivaltaisista 6 x 6 km lehdistä
- MML:n maastotietokanta (Kapsi, shp): pellot, suot, vedet, rakennukset tyyppeineen, tiet päällysteineen, kivet
- MML:n laserkeilaus 2011 (Funet): yksittäiset puut latvusmallin paikallisista maksimeista (paikka, pituus,
  latvuksen säde) ja rakennusten korkeudet; latvuston aukot täydennetään vain laserin näkemään latvustoon
- Luken monilähteinen VMI 2023 (16 m, HTTP-aluepyynnöt): puulajien tilavuusosuudet

Riippuvuudet (venv): pip install -r tools/kartta/requirements.txt
Kehys: mökin osoitepisteen kehys (Kaisuantie 62, 64.5054523 N, 26.6672225 E; x itään, z etelään, metreinä
lon * 111 320 * cos(lat0), lat * 111 320) kuten assets/mokki/kartta.json ja assets/vaala/reitti.json.
"""
import json
import math
import os
import struct
import urllib.request
import zipfile

import imagecodecs
import laspy
import numpy as np
import shapefile
import tifffile
from pyproj import Transformer
from scipy import ndimage
from scipy.spatial import cKDTree

LAT0, LON0 = 64.5054523, 26.6672225
M_PER_DEG = 111320.0
KAPSI = "https://kartat.kapsi.fi/files/"
FUNET = "https://www.nic.funet.fi/index/geodata/"
UA = {"User-Agent": "normipaiva-kartta/1.0"}
VMI_THEMES = ["manty", "kuusi", "koivu", "muulp"]
PINE, SPRUCE, BIRCH, ASPEN, BUSH = range(5)

_to_tm = Transformer.from_crs(4326, 3067, always_xy=True)
_to_ll = Transformer.from_crs(3067, 4326, always_xy=True)


# --- Kehykset -------------------------------------------------------------------------------------------------

def frame_to_tm(x, z):
    """Mökin kehys -> ETRS-TM35FIN (E, N)."""
    x, z = np.asarray(x, float), np.asarray(z, float)
    lat = LAT0 - z / M_PER_DEG
    lon = LON0 + x / (math.cos(math.radians(LAT0)) * M_PER_DEG)
    return _to_tm.transform(lon, lat)


def tm_to_frame(e, n):
    lon, lat = _to_ll.transform(np.asarray(e, float), np.asarray(n, float))
    return (lon - LON0) * math.cos(math.radians(LAT0)) * M_PER_DEG, -(lat - LAT0) * M_PER_DEG


# --- Lataus ---------------------------------------------------------------------------------------------------

def fetch(url, path):
    if os.path.exists(path) and os.path.getsize(path) > 0:
        return path
    os.makedirs(os.path.dirname(path), exist_ok=True)
    print("haetaan", url)
    with urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=300) as r, open(path + ".part", "wb") as f:
        while True:
            b = r.read(1 << 20)
            if not b:
                break
            f.write(b)
    os.replace(path + ".part", path)
    return path


def ranged(url, a, b):
    req = urllib.request.Request(url, headers=dict(UA, Range="bytes=%d-%d" % (a, b - 1)))
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def sheet_of(e, n):
    """6 x 6 km korkeusmallilehden nimi ja lounaiskulma (E, N)."""
    rows = "KLMNPQRSTUVWX"
    r = int((n - 6570000) // 96000)
    col = int((e - 308000) // 192000) + 4
    name = rows[r] + str(col)
    e0, n0, w, h = 308000 + (col - 4) * 192000, 6570000 + r * 96000, 192000.0, 96000.0
    for _ in range(3):
        w, h = w / 2, h / 2
        cx, cy = int((e - e0) // w), int((n - n0) // h)
        name += str({(0, 0): 1, (0, 1): 2, (1, 0): 3, (1, 1): 4}[(cx, cy)])
        e0, n0 = e0 + cx * w, n0 + cy * h
    w, h = w / 4, h / 2
    cx, cy = int((e - e0) // w), int((n - n0) // h)
    return name + "ABCDEFGH"[cx * 2 + cy], e0 + cx * w, n0 + cy * h


# --- Korkeusmalli ---------------------------------------------------------------------------------------------

class Dem:
    """2 m korkeusmallin mosaiikki laatikolle (E/N). at(e, n) bilineaarisesti."""

    def __init__(self, cache, e0, n0, e1, n1):
        # Lehtijako: itä 308 000 + 6000 k (eli 2000 mod 6000), pohjoinen 6 570 000 + 6000 k.
        self.e0 = math.floor((e0 - 2000) / 6000) * 6000 + 2000
        self.n1 = math.ceil(n1 / 6000) * 6000
        e1 = math.ceil((e1 - 2000) / 6000) * 6000 + 2000
        n0 = math.floor(n0 / 6000) * 6000
        self.a = np.full((int((self.n1 - n0) / 2), int((e1 - self.e0) / 2)), np.nan, np.float32)
        for se in range(int(self.e0), int(e1), 6000):
            for sn in range(int(n0), int(self.n1), 6000):
                name, _, _ = sheet_of(se + 1, sn + 1)
                p = fetch(KAPSI + "korkeusmalli/hila_2m/etrs-tm35fin-n2000/%s/%s/%s.tif" % (name[:2], name[:3], name),
                          os.path.join(cache, "dem", name + ".tif"))
                j0 = int((self.n1 - (sn + 6000)) / 2)
                i0 = int((se - self.e0) / 2)
                self.a[j0:j0 + 3000, i0:i0 + 3000] = tifffile.imread(p)
        self.a[self.a < -100] = np.nan
        fill = np.isnan(self.a)
        if fill.any():
            idx = ndimage.distance_transform_edt(fill, return_distances=False, return_indices=True)
            self.a = self.a[tuple(idx)]

    def ij(self, e, n):
        return (np.asarray(e) - self.e0) / 2.0 - 0.5, (self.n1 - np.asarray(n)) / 2.0 - 0.5

    def at(self, e, n, smooth=0.0):
        i, j = self.ij(e, n)
        src = ndimage.gaussian_filter(self.a, smooth) if smooth > 0 else self.a
        return ndimage.map_coordinates(src, [np.atleast_1d(j), np.atleast_1d(i)], order=1, mode="nearest")


# --- Maastotietokanta -----------------------------------------------------------------------------------------

def mtk(cache, sheets, layer):
    """Tason (esim. "m_p") kohteet: [(luokka, teksti, renkaat [[(e, n)...]], tietue)]."""
    out = []
    for sh in sheets:
        z = fetch(KAPSI + "maastotietokanta/kaikki/etrs89/shp/%s/%s/%s.shp.zip" % (sh[:2], sh[:3], sh),
                  os.path.join(cache, "mtk", sh + ".zip"))
        base = os.path.join(cache, "mtk", sh)
        if not os.path.isdir(base):
            zipfile.ZipFile(z).extractall(base)
        p = os.path.join(base, "%s_%s_%s.shp" % (layer[0], sh, layer[2]))
        if not os.path.exists(p):
            continue
        for sr in shapefile.Reader(p, encoding="utf-8").iterShapeRecords():
            s = sr.shape
            if not s.points:
                continue
            parts = (list(s.parts) or [0]) + [len(s.points)]
            rec = sr.record.as_dict()
            out.append((rec["LUOKKA"], (rec.get("TEKSTI") or "").strip(),
                        [s.points[parts[k]:parts[k + 1]] for k in range(len(parts) - 1)], rec))
    return out


def ring_area(r):
    return sum(r[k][0] * r[k + 1][1] - r[k + 1][0] * r[k][1] for k in range(len(r) - 1)) / 2.0


def in_poly(poly, x, y):
    inside = np.zeros(len(x), bool)
    j = len(poly) - 1
    for i in range(len(poly)):
        xi, yi = poly[i]
        xj, yj = poly[j]
        inside ^= ((yi > y) != (yj > y)) & (x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-12) + xi)
        j = i
    return inside


BUILDING_KIND = {42211: "house", 42212: "house", 42221: "big", 42222: "big", 42231: "cottage", 42232: "cottage",
                 42241: "big", 42242: "big", 42251: "big", 42252: "big", 42261: "shed", 42262: "shed", 42270: "shed"}


# --- Laser ----------------------------------------------------------------------------------------------------

class Laser:
    """Laserkeilauksen latvusmalli (1 m) ja kasvillisuus-/kattopisteet lehdiltä (3 x 3 km neljännekset)."""

    def __init__(self, cache, dem, tiles):
        self.tiles = tiles
        es, ns = [], []
        for t in tiles:
            _, e0, n0 = sheet_of(*self._probe(t))
            q = int(t[-1]) - 1
            es.append(e0 + (q // 2) * 3000)
            ns.append(n0 + (q % 2) * 3000)
        self.e0, self.n0 = min(es), min(ns)
        self.e1, self.n1 = max(es) + 3000, max(ns) + 3000
        self.w, self.h = int(self.e1 - self.e0), int(self.n1 - self.n0)
        self.chm = np.zeros((self.h, self.w), np.float32)
        self.covered = np.zeros((self.h, self.w), bool)
        pts = []
        for t in tiles:
            d = "R433" if t.startswith("R433") else t[:4]
            p = fetch(FUNET + "mml/laserkeilaus/2008_latest/2011/%s/1/%s.laz" % (d, t), os.path.join(cache, "laz", t + ".laz"))
            las = laspy.read(p)
            x, y, z = np.asarray(las.x), np.asarray(las.y), np.asarray(las.z)
            ci = np.clip((x - self.e0).astype(int), 0, self.w - 1)
            cj = np.clip((self.n1 - y).astype(int), 0, self.h - 1)
            self.covered[cj, ci] = True
            keep = np.isin(np.asarray(las.classification), (1, 3, 13))
            x, y, z = x[keep], y[keep], z[keep]
            hag = z - dem.at(x, y)
            keep = (hag > 0.4) & (hag < 40.0)
            x, y, hag = x[keep], y[keep], hag[keep]
            pts.append(np.stack([x, y, hag], 1).astype(np.float64))
            np.maximum.at(self.chm, (np.clip((self.n1 - y).astype(int), 0, self.h - 1),
                                     np.clip((x - self.e0).astype(int), 0, self.w - 1)), hag.astype(np.float32))
            print("laser %s: %d pistettä" % (t, len(x)))
        self.pts = np.concatenate(pts)
        self.covered = ndimage.binary_closing(self.covered, iterations=4)
        self.filled = ndimage.grey_closing(self.chm, size=3)
        self.smooth = ndimage.gaussian_filter(self.filled, 0.8)

    @staticmethod
    def _probe(t):
        """Lehden nimi -> jokin piste sen sisältä (nimen purku kulkemalla jakoa)."""
        rows = "KLMNPQRSTUVWX"
        e0 = 308000 + (int(t[1]) - 4) * 192000
        n0 = 6570000 + rows.index(t[0]) * 96000
        w, h = 192000.0, 96000.0
        for c in t[2:5]:
            w, h = w / 2, h / 2
            q = int(c) - 1
            e0 += (q // 2) * w
            n0 += (q % 2) * h
        w, h = w / 4, h / 2
        k = "ABCDEFGH".index(t[5])
        return e0 + (k // 2) * w + 10, n0 + (k % 2) * h + 10

    def chm_at(self, e, n, src=None):
        src = self.smooth if src is None else src
        i = np.clip((np.asarray(e) - self.e0).astype(int), 0, self.w - 1)
        j = np.clip((self.n1 - np.asarray(n)).astype(int), 0, self.h - 1)
        return src[j, i]

    def building_height(self, ring):
        """Rakennuksen korkeus maasta laserista tai None: pienissä (alle 250 m²) harja (90. persentiili pohjan
        sisältä), isoissa (yleensä tasakatto) katon taso (mediaani), jotta katon ylle kurottavat puut eivät nosta."""
        e = [p[0] for p in ring]
        n = [p[1] for p in ring]
        if min(e) < self.e0 or max(e) > self.e1 or min(n) < self.n0 or max(n) > self.n1:
            return None
        if not hasattr(self, "_kd"):
            self._kd = cKDTree(self.pts[:, :2])
        c = (sum(e) / len(e), sum(n) / len(n))
        r = max(math.dist(c, p) for p in ring)
        idx = self._kd.query_ball_point(c, r)
        if len(idx) < 3:
            return None
        cand = self.pts[idx]
        inside = in_poly(np.array(ring), cand[:, 0], cand[:, 1])
        if inside.sum() < 3:
            return None
        roof = cand[inside, 2]
        roof = roof[roof > 1.5]
        if len(roof) < 3:
            return None
        return float(np.percentile(roof, 50 if abs(ring_area(ring)) > 250.0 else 90))

    def trees(self, rng, exclude, fill_mask=None):
        """Puut TM35:ssä: (e, n, pituus). exclude(e, n) -> bool-taulukko (ei puuta). fill_mask(e, n) -> missä
        latvuston aukot täydennetään (muualla vain valtapuut)."""
        s = self.smooth
        peak = ((s >= ndimage.maximum_filter(s, size=3)) & (s < 9.0) & (s >= 1.3)) | \
               ((s >= ndimage.maximum_filter(s, size=5)) & (s >= 9.0))
        pj, pi = np.nonzero(peak & self.covered)
        te = self.e0 + pi + 0.5 + rng.uniform(-0.3, 0.3, len(pi))
        tn = self.n1 - pj - 0.5 + rng.uniform(-0.3, 0.3, len(pi))
        th = self.filled[pj, pi]
        ok = ~exclude(te, tn)
        te, tn, th = te[ok], tn[ok], th[ok]
        n_dom = len(te)
        have = [np.stack([te, tn], 1)]
        adds = []
        for _ in range(4):
            step = 2.6
            ce, cn = np.meshgrid(np.arange(self.e0 + step / 2, self.e1, step), np.arange(self.n0 + step / 2, self.n1, step))
            ce = (ce + rng.uniform(-1.2, 1.2, ce.shape)).ravel()
            cn = (cn + rng.uniform(-1.2, 1.2, cn.shape)).ravel()
            hh = self.chm_at(ce, cn)
            sel = (hh >= 2.0) & self.chm_at(ce, cn, self.covered)
            if fill_mask is not None:
                sel &= fill_mask(ce, cn)
            ce, cn, hh = ce[sel], cn[sel], hh[sel]
            d, _ = cKDTree(np.concatenate(have)).query(np.stack([ce, cn], 1))
            sel = (d > 1.25 * (0.5 + 0.09 * hh)) & (rng.random(len(ce)) < 0.55)
            ce, cn, hh = ce[sel], cn[sel], hh[sel]
            ok = ~exclude(ce, cn)
            ce, cn, hh = ce[ok], cn[ok], hh[ok]
            have.append(np.stack([ce, cn], 1))
            adds.append((ce, cn, hh * rng.uniform(0.65, 1.0, len(hh))))
        e = np.concatenate([te] + [a[0] for a in adds])
        n = np.concatenate([tn] + [a[1] for a in adds])
        h = np.concatenate([th] + [a[2] for a in adds])
        print("laserpuita: valtapuita %d, täydennys %d" % (n_dom, len(e) - n_dom))
        return e, n, h


# --- VMI ------------------------------------------------------------------------------------------------------

def vmi_read(cache, theme, e0, n0, e1, n1):
    key = "%s_%d_%d_%d_%d" % (theme, e0, n0, e1, n1)
    path = os.path.join(cache, "vmi", key + ".npy")
    gpath = os.path.join(cache, "vmi", key + ".json")
    if os.path.exists(path) and os.path.exists(gpath):
        return np.load(path), json.load(open(gpath))
    url = FUNET + "luke/vmi/2023/%s_vmi1x_1923.tif" % theme
    h = ranged(url, 0, 131072)
    off = struct.unpack("<I", h[4:8])[0]
    tags = {}
    for k in range(struct.unpack("<H", h[off:off + 2])[0]):
        tag, typ, cnt = struct.unpack("<HHI", h[off + 2 + k * 12:off + 10 + k * 12])
        tags[tag] = (typ, cnt, h[off + 10 + k * 12:off + 14 + k * 12])

    def val(t):
        typ, cnt, v = tags[t]
        if typ == 3 and cnt == 1:
            return struct.unpack("<H", v[:2])[0]
        if typ == 4 and cnt == 1:
            return struct.unpack("<I", v)[0]
        o = struct.unpack("<I", v)[0]
        sz, fm = {3: (2, "H"), 4: (4, "I"), 12: (8, "d")}[typ]
        d = h[o:o + cnt * sz] if o + cnt * sz <= len(h) else ranged(url, o, o + cnt * sz)
        return struct.unpack("<%d%s" % (cnt, fm), d)

    W = val(256)
    tw, th = val(322), val(323)
    offs, cnts = val(324), val(325)
    ps = val(33550)[0]
    ox, oy = val(33922)[3], val(33922)[4]
    x0, x1 = int((e0 - ox) // ps), int((e1 - ox) // ps) + 1
    y0, y1 = int((oy - n1) // ps), int((oy - n0) // ps) + 1
    out = np.full((y1 - y0, x1 - x0), 32767, np.uint16)
    tx = (W + tw - 1) // tw
    for ty in range(y0 // th, (y1 - 1) // th + 1):
        for txi in range(x0 // tw, (x1 - 1) // tw + 1):
            k = ty * tx + txi
            t = np.frombuffer(imagecodecs.lzw_decode(ranged(url, offs[k], offs[k] + cnts[k])), "<u2")[:tw * th].reshape(th, tw)
            gy0, gx0 = ty * th, txi * tw
            ya, yb, xa, xb = max(y0, gy0), min(y1, gy0 + th), max(x0, gx0), min(x1, gx0 + tw)
            out[ya - y0:yb - y0, xa - x0:xb - x0] = t[ya - gy0:yb - gy0, xa - gx0:xb - gx0]
    geo = [ox + x0 * ps, oy - y0 * ps, ps]
    os.makedirs(os.path.dirname(path), exist_ok=True)
    np.save(path, out)
    json.dump(geo, open(gpath, "w"))
    return out, geo


class Species:
    """Puulaji VMI:n tilavuusosuuksista (16 m solut); metsämaan ulkopuolella (pihat, rannat) yleisjakauma."""

    def __init__(self, cache, e0, n0, e1, n1):
        self.v = {}
        for t in VMI_THEMES:
            self.v[t], self.geo = vmi_read(cache, t, e0 - 32, n0 - 32, e1 + 32, n1 + 32)

    def __call__(self, rng, e, n, hgt):
        gx0, gy0, ps = self.geo
        sh = self.v["manty"].shape
        i = np.clip(((np.asarray(e) - gx0) // ps).astype(int), 0, sh[1] - 1)
        j = np.clip(((gy0 - np.asarray(n)) // ps).astype(int), 0, sh[0] - 1)
        vols = np.stack([self.v[t][j, i].astype(np.float32) for t in VMI_THEMES], 1)
        vols[vols >= 32766] = 0.0
        tot = vols.sum(1)
        default = np.array([0.35, 0.2, 0.35, 0.1], np.float32)
        prob = np.where(tot[:, None] > 1.0, vols / np.maximum(tot, 1e-6)[:, None], default)
        young = hgt < 5.0
        prob[young] = prob[young] * 0.6 + np.array([0.15, 0.1, 0.5, 0.25]) * 0.4
        prob /= prob.sum(1, keepdims=True)
        sp = (rng.random(len(e))[:, None] > np.cumsum(prob, 1)).sum(1).astype(np.uint8)
        sp = np.minimum(sp, 3)
        sp[hgt < 2.2] = BUSH
        return sp


def crown_radius(sp, h):
    r = np.where(sp == SPRUCE, 0.35 + 0.085 * h, np.where(sp == PINE, 0.5 + 0.1 * h, 0.6 + 0.12 * h))
    return np.clip(r, 0.4, 5.0)


# --- Puudata peliin (scripts/forest.gd) -------------------------------------------------------------------------

def write_trees(path, x, y, z, h, sp, rng, far_chunk=256.0, near_chunk=64.0):
    """ONP3: puut lohkoittain (kaukolohko -> laji -> lähilohko) ja kaksi datatekstuuria kuten Oulujärven norpissa.
    Kehys on kohteen oma paikallinen kehys (pelin solmun x/z); y = maanpinnan korkeus pelin maastosta."""
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
    x, y, z, h, sp = x[order], y[order], z[order], h[order], sp[order]
    fkey = (fj * nfx + fi)[order]
    nkey = (nj * nnx + ni)[order]
    far_tab = np.zeros((nfx * nfz, 5, 2), np.uint32)
    near_tab = np.zeros((nnx * nnz, 5, 2), np.uint32)
    for tab, key in ((far_tab, fkey), (near_tab, nkey)):
        comb = key.astype(np.int64) * 5 + sp
        starts = np.nonzero(np.r_[True, comb[1:] != comb[:-1]])[0]
        counts = np.diff(np.r_[starts, len(comb)])
        k = comb[starts]
        tab[k // 5, k % 5, 0] = starts
        tab[k // 5, k % 5, 1] = counts
    W = 2048
    H = (len(x) + W - 1) // W
    t0 = np.zeros((H * W, 4), "<f4")
    t0[:len(x)] = np.stack([x, y, z, h], 1)
    t1 = np.zeros((H * W, 4), np.uint8)
    t1[:len(x), 0] = np.clip(np.round(crown_radius(sp, h) * 40), 1, 255)
    t1[:len(x), 1] = sp
    t1[:len(x), 2] = rng.integers(0, 256, len(x))
    t1[:len(x), 3] = rng.integers(0, 256, len(x))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"ONP3" + struct.pack("<IIIffffIIII", len(x), W, H, far_chunk, near_chunk, x0, z0, nfx, nfz, nnx, nnz))
        f.write(far_tab.tobytes())
        f.write(near_tab.tobytes())
        f.write(t0.tobytes())
        f.write(t1.tobytes())
    names = ["mänty", "kuusi", "koivu", "haapa/muu", "pensas"]
    print("%s: %d puuta (%s), %.1f Mt" % (os.path.relpath(path), len(x), ", ".join(
        "%s %d" % (names[k], (sp == k).sum()) for k in range(5)), os.path.getsize(path) / 1e6))
