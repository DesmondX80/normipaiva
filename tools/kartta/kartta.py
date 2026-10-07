"""Karttatyökalujen Python-versio (vain standardikirjasto). Vastaa C#-apureita tm35.cs, tiff.cs, mosaic.cs,
osm.cs ja mokki_dem.cs sekä kehys.ps1:tä; ajoskriptit kyla.py, kyla_osm.py ja mokki.py tuottavat samat tiedostot
kuin PowerShell-versiot (ks. LUEMINUT.md).
"""
import math
import struct
import xml.etree.ElementTree as ET

# --- Lukujen muotoilu kuten .NET (double.ToString, InvariantCulture) ------------------------------------------


def fmt(v):
    """Luku merkkijonoksi kuten C#:n double.ToString(): kokonaisluku ilman desimaaleja, nolla aina "0"."""
    v = float(v)
    if v == 0:
        return "0"
    s = repr(v)
    if "e" in s or "E" in s:
        s = format(v, ".15g")
    if s.endswith(".0"):
        s = s[:-2]
    return s


def f32(v):
    """Pyöristys 32-bittiseksi liukuluvuksi (C#:n float)."""
    return struct.unpack("<f", struct.pack("<f", v))[0]


# --- ETRS-TM35FIN (JHS 197, Krüger-sarja) ---------------------------------------------------------------------


def tm35(lat_deg, lon_deg):
    """GRS80 -> ETRS-TM35FIN (E, N)."""
    a, f, k0, lon0, e0 = 6378137.0, 1 / 298.257222101, 0.9996, 27.0 * math.pi / 180, 500000
    n = f / (2 - f)
    a1 = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64)
    e = math.sqrt(f * (2 - f))
    h1 = n / 2 - 2.0 / 3 * n * n + 5.0 / 16 * n * n * n + 41.0 / 180 * n * n * n * n
    h2 = 13.0 / 48 * n * n - 3.0 / 5 * n * n * n + 557.0 / 1440 * n * n * n * n
    h3 = 61.0 / 240 * n * n * n - 103.0 / 140 * n * n * n * n
    h4 = 49561.0 / 161280 * n * n * n * n
    phi, lam = lat_deg * math.pi / 180, lon_deg * math.pi / 180
    q = _asinh(math.tan(phi)) - e * _atanh(e * math.sin(phi))
    beta = math.atan(math.sinh(q))
    eta0 = _atanh(math.cos(beta) * math.sin(lam - lon0))
    xi0 = math.asin(math.sin(beta) * math.cosh(eta0))
    xi = (xi0 + h1 * math.sin(2 * xi0) * math.cosh(2 * eta0) + h2 * math.sin(4 * xi0) * math.cosh(4 * eta0)
          + h3 * math.sin(6 * xi0) * math.cosh(6 * eta0) + h4 * math.sin(8 * xi0) * math.cosh(8 * eta0))
    eta = (eta0 + h1 * math.cos(2 * xi0) * math.sinh(2 * eta0) + h2 * math.cos(4 * xi0) * math.sinh(4 * eta0)
           + h3 * math.cos(6 * xi0) * math.sinh(6 * eta0) + h4 * math.cos(8 * xi0) * math.sinh(8 * eta0))
    return e0 + a1 * eta * k0, a1 * xi * k0


def _asinh(x):
    return math.log(x + math.sqrt(x * x + 1))


def _atanh(x):
    return 0.5 * math.log((1 + x) / (1 - x))


# --- Kylän kehys (kehys.ps1): kartan pikselit <-> TM35 --------------------------------------------------------

JK = tm35(64.6471763, 24.4603302)    # J_K Ketunperäntie / Tarpiontie = px (195, 765)
JP = tm35(64.6145888, 24.4910525)    # J_PATO Ketunperäntie / Patotie = px (1304, 3778)
_dpx, _dpy = 1304 - 195, 3778 - 765
_dmx, _dmy = JP[0] - JK[0], -(JP[1] - JK[1])
SC = math.sqrt((_dmx * _dmx + _dmy * _dmy) / (_dpx * _dpx + _dpy * _dpy))
ROT = math.atan2(_dmy, _dmx) - math.atan2(_dpy, _dpx)


def px2tm(x, y):
    dx, dy, c, s = x - 195, y - 765, math.cos(ROT), math.sin(ROT)
    return JK[0] + SC * (dx * c - dy * s), JK[1] - SC * (dx * s + dy * c)


def tm2px(e, n):
    mx, my, c, s = e - JK[0], JK[1] - n, math.cos(ROT), math.sin(ROT)
    return 195 + (mx * c + my * s) / SC, 765 + (-mx * s + my * c) / SC


# --- GeoTIFF (MML:n korkeusmalli: laatoitettu, LZW, float32) ---------------------------------------------------


def _lzw(src):
    out = bytearray()
    table = [bytes([i]) for i in range(256)] + [b"", b""]
    bitpos, nbits, prev = 0, 9, None
    total = len(src) * 8
    while True:
        if bitpos + nbits > total:
            break
        byte = bitpos >> 3
        chunk = int.from_bytes(src[byte:byte + 3].ljust(3, b"\0"), "big")
        code = (chunk >> (24 - (bitpos & 7) - nbits)) & ((1 << nbits) - 1)
        bitpos += nbits
        if code == 257:
            break
        if code == 256:
            del table[258:]
            nbits, prev = 9, None
            continue
        entry = table[code] if code < len(table) else prev + prev[:1]
        out += entry
        if prev is not None:
            table.append(prev + entry[:1])
        prev = entry
        nxt = len(table) + 1
        nbits = 12 if nxt >= 2048 else 11 if nxt >= 1024 else 10 if nxt >= 512 else 9
    return bytes(out)


class Tiff:
    """Yksi korkeusmallilehti. e0, n0 = vasemman yläkulman TM35-koordinaatit, 2 m pikselit."""

    def __init__(self, path):
        with open(path, "rb") as fh:
            self.f = fh.read()
        f = self.f
        ifd = struct.unpack_from("<I", f, 4)[0]
        n = struct.unpack_from("<H", f, ifd)[0]
        self.tags, self.dtags = {}, {}
        for i in range(n):
            e = ifd + 2 + i * 12
            tag, typ, cnt = struct.unpack_from("<HHI", f, e)
            size = 2 if typ == 3 else 4 if typ == 4 else 8 if typ in (12, 16) else 1
            off = e + 8 if cnt * size <= 4 else struct.unpack_from("<I", f, e + 8)[0]
            if typ == 12:
                self.dtags[tag] = struct.unpack_from("<%dd" % cnt, f, off)
            elif typ == 3:
                self.tags[tag] = struct.unpack_from("<%dH" % cnt, f, off)
            elif typ == 4:
                self.tags[tag] = struct.unpack_from("<%dI" % cnt, f, off)
        self.w, self.h = self.tags[256][0], self.tags[257][0]
        self.tw, self.th = self.tags[322][0], self.tags[323][0]
        self.tiles_x = (self.w + self.tw - 1) // self.tw
        self.e0, self.n0 = self.dtags[33922][3], self.dtags[33922][4]
        self._cache = {}

    def _tile(self, ti):
        t = self._cache.get(ti)
        if t is not None:
            return t
        off, ln = self.tags[324][ti], self.tags[325][ti]
        raw = self.f[off:off + ln]
        comp = self.tags[259][0]
        if comp == 5:
            dec = _lzw(raw)
        elif comp in (8, 32946):
            import zlib
            dec = zlib.decompress(raw)
        else:
            dec = raw
        pred = self.tags.get(317, (1,))[0]
        tw, th = self.tw, self.th
        if pred == 3:
            b = bytearray(dec)
            o2 = bytearray(len(b))
            for r in range(th):
                rb = r * tw * 4
                for i in range(1, tw * 4):
                    b[rb + i] = (b[rb + i] + b[rb + i - 1]) & 255
                for i in range(tw):
                    for k in range(4):
                        o2[rb + i * 4 + k] = b[rb + (3 - k) * tw + i]
            dec = bytes(o2)
        t = struct.unpack_from("<%df" % (tw * th), dec)
        self._cache[ti] = t
        return t

    def pixel(self, x, y):
        t = self._tile((y // self.th) * self.tiles_x + x // self.tw)
        return t[(y % self.th) * self.tw + x % self.tw]


class Mosaic:
    """Lehtien mosaiikki 2 m pikseleinä (rivi 0 = pohjoisreuna n0), kuten mosaic.cs; lehdet luetaan tarvittaessa."""

    def __init__(self, e0, n0, w, h):
        self.e0, self.n0, self.w, self.h = e0, n0, w, h
        self.sheets = []

    def add(self, path):
        t = Tiff(path)
        oi, oj = round((t.e0 - self.e0) / 2.0), round((self.n0 - t.n0) / 2.0)
        i0, i1 = max(0, oi), min(self.w, oi + t.w)
        j0, j1 = max(0, oj), min(self.h, oj + t.h)
        if i1 <= i0 or j1 <= j0:
            return "ei päällekkäisyyttä (lehti E %s N %s)" % (fmt(t.e0), fmt(t.n0))
        self.sheets.append((t, oi, oj, i0, i1, j0, j1))
        return "lehti E %s N %s -> mosaiikki %d x %d" % (fmt(t.e0), fmt(t.n0), i1 - i0, j1 - j0)

    def _g(self, i, j):
        for t, oi, oj, i0, i1, j0, j1 in self.sheets:
            if i0 <= i < i1 and j0 <= j < j1:
                return t.pixel(i - oi, j - oj)
        return float("nan")

    def at(self, e, n):
        fi, fj = (e - self.e0 - 1.0) / 2.0, (self.n0 - 1.0 - n) / 2.0
        i, j = math.floor(fi), math.floor(fj)
        if i < 0 or j < 0 or i >= self.w - 1 or j >= self.h - 1:
            return float("nan")
        tx, ty = fi - i, fj - j
        a, b, c, d = self._g(i, j), self._g(i + 1, j), self._g(i, j + 1), self._g(i + 1, j + 1)
        return f32((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty)

    def sample(self, px0, py0, step, nx, ny, avg):
        """Kylän karttapikseliruudukko -> korkeudet (kuten Mosaic.Sample)."""
        c, s = math.cos(ROT), math.sin(ROT)
        r = []
        for j in range(ny):
            for i in range(nx):
                dx, dy = px0 + i * step - 195, py0 + j * step - 765
                e, n = JK[0] + SC * (dx * c - dy * s), JK[1] - SC * (dx * s + dy * c)
                tot, cnt = 0.0, 0
                for dj in range(-avg, avg + 1):
                    for di in range(-avg, avg + 1):
                        v = self.at(e + di * 2.0, n + dj * 2.0)
                        if v == v:
                            tot += v
                            cnt += 1
                r.append(f32(tot / cnt) if cnt > 0 else float("nan"))
        return r


# --- Mökin korkeudet (mokki_dem.cs) ---------------------------------------------------------------------------

LAT0, LON0, M_PER_DEG = 64.5054523, 26.6672225, 111320.0


class MokkiDem:
    def __init__(self, mosaic):
        self.m = mosaic

    def at(self, x, z):
        lat = LAT0 - z / M_PER_DEG
        lon = LON0 + x / (math.cos(LAT0 * math.pi / 180.0) * M_PER_DEG)
        e, n = tm35(lat, lon)
        return self.m.at(e, n)

    def grid(self, x0, z0, step, n, nz=None):
        return [self.at(x0 + i * step, z0 + j * step) for j in range(nz or n) for i in range(n)]

    @staticmethod
    def _inside(xs, zs, x, z):
        c = False
        j = len(xs) - 1
        for i in range(len(xs)):
            if (zs[i] > z) != (zs[j] > z) and x < (xs[j] - xs[i]) * (z - zs[i]) / (zs[j] - zs[i]) + xs[i]:
                c = not c
            j = i
        return c

    def level(self, xs, zs):
        """Vesistön pinta: mallin alin kohta järven sisällä 2 m välein, pienelle lammelle rantaviivan alin kohta."""
        x0, x1, z0, z1 = min(xs), max(xs), min(zs), max(zs)
        best = math.inf
        z = math.ceil(z0 / 2) * 2
        while z <= z1:
            x = math.ceil(x0 / 2) * 2
            while x <= x1:
                if self._inside(xs, zs, x, z):
                    v = self.at(x, z)
                    if v == v:
                        best = min(best, v)
                x += 2
            z += 2
        if best == math.inf:
            for x, z in zip(xs, zs):
                v = self.at(x, z)
                if v == v:
                    best = min(best, v)
        return best


# --- OpenStreetMap (osm.cs) -----------------------------------------------------------------------------------


def _segdist(p, a, b):
    dx, dy = b[0] - a[0], b[1] - a[1]
    l2 = dx * dx + dy * dy
    t = max(0, min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) if l2 > 0 else 0
    qx, qy = a[0] + t * dx - p[0], a[1] + t * dy - p[1]
    return math.sqrt(qx * qx + qy * qy)


def _simplify(p, keep, eps):
    """Douglas-Peucker; keep[i] = piste säilytetään aina (risteys)."""
    m = [False] * len(p)
    m[0] = m[-1] = True
    if keep is not None:
        for i, k in enumerate(keep):
            if k:
                m[i] = True
    st, prev = [], 0
    for i in range(1, len(p)):
        if m[i]:
            st.append((prev, i))
            prev = i
    while st:
        s0, s1 = st.pop()
        best, bi = 0, -1
        for i in range(s0 + 1, s1):
            d = _segdist(p[i], p[s0], p[s1])
            if d > best:
                best, bi = d, i
        if bi >= 0 and best > eps:
            m[bi] = True
            st.append((s0, bi))
            st.append((bi, s1))
    return [i for i in range(len(p)) if m[i]]


def _clip_poly(poly, x0, y0, x1, y1):
    def inside(q, e):
        return q[0] >= x0 if e == 0 else q[0] <= x1 if e == 1 else q[1] >= y0 if e == 2 else q[1] <= y1

    def cut(a, b, e):
        if e == 0:
            t = (x0 - a[0]) / (b[0] - a[0])
        elif e == 1:
            t = (x1 - a[0]) / (b[0] - a[0])
        elif e == 2:
            t = (y0 - a[1]) / (b[1] - a[1])
        else:
            t = (y1 - a[1]) / (b[1] - a[1])
        return (a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]))

    o = poly
    for e in range(4):
        if not o:
            break
        inp, o = o, []
        for i in range(len(inp)):
            cur, pre = inp[i], inp[(i + len(inp) - 1) % len(inp)]
            ci, pi = inside(cur, e), inside(pre, e)
            if ci:
                if not pi:
                    o.append(cut(pre, cur, e))
                o.append(cur)
            elif pi:
                o.append(cut(pre, cur, e))
    return o


def _clip_line(p, x0, y0, x1, y1, keep):
    """Murtoviivan sisäpuoliset osat ja niiden keep-listat (ylityspisteet mukana, puolitushaulla)."""
    parts, keeps, cur, ck = [], [], None, None

    def ins(q):
        return x0 <= q[0] <= x1 and y0 <= q[1] <= y1

    for i in range(len(p)):
        a = ins(p[i])
        if i > 0:
            pa = ins(p[i - 1])
            if a != pa:
                lo, hi = (p[i - 1], p[i]) if pa else (p[i], p[i - 1])
                for _ in range(30):
                    mid = ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)
                    if ins(mid):
                        lo = mid
                    else:
                        hi = mid
                if pa:
                    cur.append(lo)
                    ck.append(True)
                    parts.append(cur)
                    keeps.append(ck)
                    cur = None
                else:
                    cur, ck = [lo], [True]
        if a:
            if cur is None:
                cur, ck = [], []
            cur.append(p[i])
            ck.append(keep[i])
    if cur is not None and len(cur) > 1:
        parts.append(cur)
        keeps.append(ck)
    return parts, keeps


def _self_intersects(p):
    n = len(p)

    def cr(a, b, c):
        return (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])

    for i in range(n):
        a, b = p[i], p[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = p[j], p[(j + 1) % n]
            d1, d2, d3, d4 = cr(c, d, a), cr(c, d, b), cr(a, b, c), cr(a, b, d)
            if (((d1 > 0) != (d2 > 0)) or d1 == 0 or d2 == 0) and (((d3 > 0) != (d4 > 0)) or d3 == 0 or d4 == 0):
                if (max(min(a[0], b[0]), min(c[0], d[0])) <= min(max(a[0], b[0]), max(c[0], d[0]))
                        and max(min(a[1], b[1]), min(c[1], d[1])) <= min(max(a[1], b[1]), max(c[1], d[1]))):
                    return True
    return False


def _round_pts(p):
    o = []
    for q in p:
        r = (float(round(q[0])), float(round(q[1])))
        if not o or o[-1] != r:
            o.append(r)
    if len(o) > 1 and o[0] == o[-1]:
        o.pop()
    return o


def _area(p):
    a = 0.0
    for i in range(len(p)):
        q, r = p[i], p[(i + 1) % len(p)]
        a += q[0] * r[1] - r[0] * q[1]
    return a / 2


def _v(p):
    return "Vector2(%s, %s)" % (fmt(round(p[0])), fmt(round(p[1])))


def _js(s):
    o = ['"']
    for ch in s or "":
        if ch in '"\\':
            o.append("\\")
        if ch >= " ":
            o.append(ch)
    o.append('"')
    return "".join(o)


class Osm:
    """OSM-ote (XML). local=True: mökin kehys (metrit osoitepisteestä), muuten kylän karttapikselit."""

    def __init__(self, path, local=False):
        self.node, self.node_tag, self.way, self.rels, self.node_use = {}, {}, {}, [], {}
        w = r = nid = None
        clat = math.cos(LAT0 * math.pi / 180.0)
        for ev, el in ET.iterparse(path, events=("start", "end")):
            tag = el.tag
            if ev == "end":
                if tag == "node":
                    nid = None
                if tag in ("node", "way", "relation"):
                    el.clear()
                continue
            if tag == "node":
                nid = el.get("id")
                lat, lon = float(el.get("lat")), float(el.get("lon"))
                if local:
                    self.node[nid] = ((lon - LON0) * clat * M_PER_DEG, -(lat - LAT0) * M_PER_DEG)
                else:
                    self.node[nid] = tm2px(*tm35(lat, lon))
                w = r = None
            elif tag == "way":
                w = {"id": el.get("id"), "nd": [], "tag": {}}
                self.way[w["id"]] = w
                r = nid = None
            elif tag == "relation":
                r = {"id": el.get("id"), "mem": [], "tag": {}}
                self.rels.append(r)
                w = nid = None
            elif tag == "nd":
                if w is not None:
                    w["nd"].append(el.get("ref"))
            elif tag == "member":
                if r is not None:
                    r["mem"].append((el.get("type"), el.get("ref"), el.get("role")))
            elif tag == "tag":
                k, v = el.get("k"), el.get("v")
                if w is not None:
                    w["tag"][k] = v
                elif r is not None:
                    r["tag"][k] = v
                elif nid is not None:
                    self.node_tag.setdefault(nid, {})[k] = v
        for x in self.way.values():
            for i in x["nd"]:
                self.node_use[i] = self.node_use.get(i, 0) + 1

    def summary(self):
        return "solmuja %d, teitä/alueita %d, relaatioita %d" % (len(self.node), len(self.way), len(self.rels))

    def pts(self, ids):
        return [self.node[i] for i in ids if i in self.node]

    def rings(self, r):
        segs = [list(self.way[m[1]]["nd"]) for m in r["mem"] if m[0] == "way" and m[2] != "inner" and m[1] in self.way]
        rings = []
        while segs:
            ring = segs.pop(0)
            grew = True
            while ring[0] != ring[-1] and grew:
                grew = False
                for i, s in enumerate(segs):
                    if s[0] == ring[-1]:
                        ring += s[1:]
                    elif s[-1] == ring[-1]:
                        ring += s[::-1][1:]
                    else:
                        continue
                    segs.pop(i)
                    grew = True
                    break
            if ring[0] == ring[-1]:
                rings.append(ring)
        return rings

    @staticmethod
    def _road_type(t):
        h = t.get("highway")
        if h is None or t.get("area") == "yes":
            return None
        if h in ("motorway", "trunk", "primary"):
            return "highway"
        if h in ("secondary", "tertiary", "unclassified"):
            return "road"
        if h in ("residential", "living_street"):
            return "street"
        if h == "service":
            return "street" if t.get("service") is None and t.get("name") is not None else None
        if h in ("track", "path", "bridleway", "cycleway"):
            return "path"
        if h == "footway":
            return None if t.get("footway") in ("sidewalk", "crossing") else "path"
        return None

    @staticmethod
    def _area_kind(t):
        v = t.get("natural")
        if v is not None:
            if v == "water":
                return "water"
            if v == "wood":
                return "forest"
            if v == "wetland":
                return "bog"
            if v in ("scrub", "heath"):
                return "forest"
        v = t.get("landuse")
        if v is not None:
            if v == "forest":
                return "forest"
            if v in ("farmland", "meadow"):
                return "field"
            if v in ("reservoir", "basin"):
                return "water"
        if "water" in t:
            return "water"
        return None

    def export_gd(self, out_path, x0, y0, x1, y1):
        """Kylän kartta GDScript-vakioina (scripts/map_osm.gd), kuten Osm.Export."""
        sb, log = [], []
        sb.append("extends RefCounted\n")
        sb.append("## GENEROITU (tools/kartta/kyla_osm.ps1 tai kyla_osm.py): kylän kartta OpenStreetMapista (© OpenStreetMap-tekijät, ODbL).\n")
        sb.append("## Koordinaatit kartan pikseleinä (ETRS-TM35FIN -> 1,22 m/px, ks. tools/kartta/kehys.ps1). Älä muokkaa käsin.\n\n")
        groups = {}
        for w in self.way.values():
            rt = self._road_type(w["tag"])
            if rt is None or len(w["nd"]) < 2:
                continue
            groups.setdefault(rt + "|" + (w["tag"].get("name") or ""), []).append(list(w["nd"]))
        sb.append("const ROADS := [\n")
        nroads = 0
        for key, segs in groups.items():
            rt, name = key.split("|", 1)
            chains = []
            while segs:
                c = segs.pop(0)
                grew = True
                while grew:
                    grew = False
                    for i, s in enumerate(segs):
                        if s[0] == c[-1]:
                            c += s[1:]
                        elif s[-1] == c[-1]:
                            c += s[::-1][1:]
                        elif s[-1] == c[0]:
                            c[0:0] = s[:-1]
                        elif s[0] == c[0]:
                            c[0:0] = s[::-1][:-1]
                        else:
                            continue
                        segs.pop(i)
                        grew = True
                        break
                chains.append(c)
            for c in chains:
                ids = [i for i in c if i in self.node]
                p = [self.node[i] for i in ids]
                keep = [self.node_use.get(i, 0) > 1 for i in ids]
                parts, keeps = _clip_line(p, x0, y0, x1, y1, keep)
                for part, kp in zip(parts, keeps):
                    ln = 0.0
                    for i in range(1, len(part)):
                        ln += math.sqrt((part[i][0] - part[i - 1][0]) ** 2 + (part[i][1] - part[i - 1][1]) ** 2)
                    if ln < (25 if rt == "path" else 10):
                        continue
                    idx = _simplify(part, kp, 2.0 if rt == "path" else 1.2)
                    hd = 0.8 if rt == "street" else 0.3 if rt == "road" else 0.0
                    sb.append('\t{"type": "%s", "name": "%s", "h": %s, "pts": [' % (rt, name.replace('"', ""), fmt(hd)))
                    sb.append(", ".join(_v(part[i]) for i in idx))
                    sb.append("]},\n")
                    nroads += 1
        sb.append("]\n\n")
        log.append("teitä %d" % nroads)

        areas = {"forest": [], "field": [], "bog": [], "water": []}
        skipped = [0]

        def add_area(kind, ids):
            p = self.pts(ids)
            if len(p) < 4:
                return
            p.pop()
            cp = _clip_poly(p, x0, y0, x1, y1)
            if len(cp) < 3 or abs(_area(cp)) < (40 if kind == "water" else 300):
                return
            for src, eps in ((cp, 1.0 if kind == "water" else 2.5), (cp, 0.8), (p, 2.5), (p, 0.8)):
                idx = _simplify(src + [src[0]], None, eps)
                sp = _round_pts([src[i] for i in idx[:-1]])
                if len(sp) >= 3 and not _self_intersects(sp):
                    areas[kind].append(sp)
                    return
            skipped[0] += 1

        for w in self.way.values():
            if len(w["nd"]) < 4 or w["nd"][0] != w["nd"][-1]:
                continue
            k = self._area_kind(w["tag"])
            if k is not None:
                add_area(k, w["nd"])
        for r in self.rels:
            if r["tag"].get("type") != "multipolygon":
                continue
            k = self._area_kind(r["tag"])
            if k is None:
                continue
            for ring in self.rings(r):
                add_area(k, ring)
        for kind, const in (("forest", "FORESTS"), ("field", "FIELDS"), ("bog", "BOGS"), ("water", "WATER")):
            sb.append("const %s := [\n" % const)
            for poly in areas[kind]:
                sb.append("\t[" + ", ".join(_v(q) for q in poly) + "],\n")
            sb.append("]\n\n")
            log.append("%s %d" % (kind, len(areas[kind])))
        if skipped[0] > 0:
            log.append("ohitettu (ei kolmioidu) %d" % skipped[0])

        sb.append("const STREAMS := [\n")
        nst = 0
        for w in self.way.values():
            ww = w["tag"].get("waterway")
            if ww not in ("stream", "river") and not (ww == "ditch" and w["tag"].get("name") is not None):
                continue
            p = self.pts(w["nd"])
            parts, _ = _clip_line(p, x0, y0, x1, y1, [False] * len(p))
            for part in parts:
                if len(part) < 2:
                    continue
                idx = _simplify(part, None, 2.0)
                sb.append("\t[" + ", ".join(_v(part[i]) for i in idx) + "],\n")
                nst += 1
        sb.append("]\n\n")
        log.append("puroja %d" % nst)

        sb.append("## Rakennukset: keskipiste, pitkän sivun suunta (rad, kartan x-akselista), pituus l ja syvyys d (px), kerrokset, tyyppi.\n")
        sb.append("const BUILDINGS := [\n")
        nb = 0
        for w in self.way.values():
            bt = w["tag"].get("building")
            if bt is None or len(w["nd"]) < 4:
                continue
            p = self.pts(w["nd"])
            if len(p) < 4:
                continue
            p.pop()
            cx = sum(q[0] for q in p) / len(p)
            cy = sum(q[1] for q in p) / len(p)
            if cx < x0 or cx > x1 or cy < y0 or cy > y1:
                continue
            best_a, bang, bl, bd, bcx, bcy = math.inf, 0.0, 0.0, 0.0, 0.0, 0.0
            for i in range(len(p)):
                a, b = p[i], p[(i + 1) % len(p)]
                ang = math.atan2(b[1] - a[1], b[0] - a[0])
                c, s = math.cos(ang), math.sin(ang)
                u0 = v0 = math.inf
                u1 = v1 = -math.inf
                for q in p:
                    u, v = q[0] * c + q[1] * s, -q[0] * s + q[1] * c
                    u0, u1, v0, v1 = min(u0, u), max(u1, u), min(v0, v), max(v1, v)
                ar = (u1 - u0) * (v1 - v0)
                if ar < best_a:
                    best_a = ar
                    um, vm = (u0 + u1) / 2, (v0 + v1) / 2
                    bcx, bcy = um * c - vm * s, um * s + vm * c
                    if u1 - u0 >= v1 - v0:
                        bang, bl, bd = ang, u1 - u0, v1 - v0
                    else:
                        bang, bl, bd = ang + math.pi / 2, v1 - v0, u1 - u0
            if bl * bd < 12:
                continue
            lv = 1
            lvs = w["tag"].get("building:levels")
            if lvs is not None and lvs.strip().lstrip("+-").isdigit():
                lv = int(lvs)
            while bang > math.pi / 2:
                bang -= math.pi
            while bang < -math.pi / 2:
                bang += math.pi
            sb.append('\t{"c": Vector2(%s, %s), "a": %s, "l": %s, "d": %s, "lv": %d, "t": "%s"},\n' % (
                fmt(round(bcx, 1)), fmt(round(bcy, 1)), fmt(round(bang, 3)), fmt(round(bl, 1)), fmt(round(bd, 1)), lv, bt))
            nb += 1
        sb.append("]\n")
        log.append("rakennuksia %d" % nb)
        with open(out_path, "w", encoding="utf-8", newline="") as fh:
            fh.write("".join(sb))
        return "\n".join(log)

    @staticmethod
    def _mokki_kind(t):
        if t.get("natural") == "water" or t.get("landuse") == "reservoir":
            return "water"
        if t.get("landuse") in ("farmland", "meadow", "grass"):
            return "field"
        if t.get("natural") == "wetland":
            return "bog"
        if t.get("natural") == "sand":
            return "sand"
        if t.get("landuse") == "forest" or t.get("natural") in ("wood", "scrub", "heath"):
            return "forest"
        if "highway" in t:
            return "road"
        if "building" in t:
            return "building"
        if "waterway" in t:
            return "stream"
        return None

    def mokki_features(self, level):
        """Mökin kohteet kartta.json-muodossa (JSON-taulukko merkkijonona), level(xs, zs) -> vesistön pinta."""
        items = []

        def add(kind, tags, fid, p):
            if len(p) < 2:
                return
            ftype = ""
            for k in ("highway", "building", "waterway", "natural"):
                if k in tags:
                    ftype = tags[k]
                    break
            if ftype == "yes" and kind != "building":
                ftype = ""
            s = '{"kind":%s,"name":%s,"type":%s,"id":%s,"pts":[' % (_js(kind), _js(tags.get("name", "")), _js(ftype), _js(fid))
            s += ",".join("[%s,%s]" % (fmt(round(q[0], 1)), fmt(round(q[1], 1))) for q in p)
            s += "]"
            if kind == "water":
                s += ',"level":' + fmt(round(level([q[0] for q in p], [q[1] for q in p]), 2))
            items.append(s + "}")

        for w in self.way.values():
            kind = self._mokki_kind(w["tag"])
            if kind is not None:
                add(kind, w["tag"], w["id"], self.pts(w["nd"]))
        for r in self.rels:
            if r["tag"].get("type") != "multipolygon":
                continue
            kind = self._mokki_kind(r["tag"])
            if kind is None:
                continue
            for k, ring in enumerate(self.rings(r)):
                add(kind, r["tag"], "r%s_%d" % (r["id"], k), self.pts(ring))
        return "[" + ",".join(items) + "]", len(items)
