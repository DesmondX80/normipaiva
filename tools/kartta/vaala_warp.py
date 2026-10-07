"""Vaalan mopomatkan saumaton tiivistys: pelin kehyksestä todelliseen kehykseen (vaala_bake.py).

Pelin jokainen maastopiste haetaan todellisesta paikasta, joka on tien näytteiden paikallisten kehysten pehmeä
painotettu yhdistelmä (softmax etäisyydestä). Näytteen kehys kuvaa pelin pisteen todelliseksi kuten ennenkin:
tien suunnassa tiivistyksen mukaan (c), sivusuunnassa 1:1. Lisäksi 1:1-alueilla (mökin piha, Vaalan keskusta,
Oulujärven lavan niemi) on siirtokehyksiä (ankkurit), joiden vaikutusalue on muita laajempi (bonus), joten ne
pysyvät tarkasti 1:1 ja tiivistetty käytävä liittyy niihin pehmeästi ilman reunoja. Kuvaus on jatkuva kaikkialla:
kartassa ei ole ympyrää, suorakaidetta eikä tyhjää kaukomaastoa, ja puut, vedet ja pellot osuvat samaan paikkaan
kuin maankäyttö (kaikki haetaan samalla kuvauksella).
"""
import math

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

FOREST, FIELD, BOG, WATER, YARD, SHOULDER, ROAD, RAIL = range(8)
SIGMA = 25.0       # kehysten liukuman leveys (m): mitä pienempi, sitä terävämpi siirtymä kehyksestä toiseen
REAL_CELL = 4.0    # todellisen kehyksen maankäyttö- ja puurasterin ruutu
# Tiivistetyllä välillä sivusuunta laajenee tiestä poispäin: 1:1 LAT0 m asti (tienvarren talot ja tiet kohdallaan),
# sitten kerroin kasvaa tasaisesti LAT_G:hen LAT1 m:iin mennessä. Kaukana maisema on tasaisemmin kutistettu eikä
# veny tien suunnassa 1:22 litistetyiksi juoviksi.
LAT0, LAT1, LAT_G = 110.0, 400.0, 8.0
LAT_C = 0.06  # sivulaajennus vain voimakkaasti tiivistetyillä kehyksillä (c < LAT_C), ei keskustan lievällä tiivistyksellä
_LAT_A = (LAT_G - 1.0) / (2.0 * (LAT1 - LAT0))
_LAT_F1 = LAT1 + _LAT_A * (LAT1 - LAT0) ** 2


def lat_out(x):
    """Pelin sivuetäisyys tiivistetyn tien kehyksessä -> todellinen (pariton, jatkuvasti derivoituva)."""
    a = np.abs(np.asarray(x, np.float64))
    t = np.clip(a - LAT0, 0.0, LAT1 - LAT0)
    y = np.where(a <= LAT1, a + _LAT_A * t * t, _LAT_F1 + LAT_G * (a - LAT1))
    return np.sign(x) * y


def lat_in(y):
    """lat_out käänteisenä (todellinen sivuetäisyys -> pelin)."""
    b = abs(y)
    if b <= LAT0:
        return y
    if b <= _LAT_F1:
        t = (-1.0 + math.sqrt(1.0 + 4.0 * _LAT_A * (b - LAT0))) / (2.0 * _LAT_A)
        return math.copysign(LAT0 + t, y)
    return math.copysign(LAT1 + (b - _LAT_F1) / LAT_G, y)


class Warp:
    """Kehykset: g = pelin piste, r = todellinen piste, d / rd = pelin / todellinen suunta, c = tiivistys (1 = 1:1),
    y = tien korkeus pelissä (ilman siltoja ja alikulkua), f = maaston korkeuserojen kerroin, bonus = etumatka."""

    def __init__(self, fd, g, r, d, rd, c, y, f, bonus):
        self.fd = fd
        self.g = np.asarray(g, np.float64)
        self.r = np.asarray(r, np.float64)
        self.d = np.asarray(d, np.float64)
        self.rd = np.asarray(rd, np.float64)
        self.c = np.asarray(c, np.float64)
        self.y = np.asarray(y, np.float64)
        self.f = np.asarray(f, np.float64)
        self.bonus = np.asarray(bonus, np.float64)
        self.q = self.f * dem_at(fd, self.r[:, 0], self.r[:, 1], smooth=6)

    def inv(self, px, pz, codes=None, chunk=8000, top=24):
        """Pelin pisteet (taulukot) todellisiksi: (rx, rz, maanpinta pelissä, 1:1-osuus, maankäyttö).
        Kehyksistä käytetään pisteen top vahvinta. Todellinen paikka on vahvimman kehyksen arvio (puut ja koodit
        samasta kohdasta), maanpinta kehysten omien arvioiden painotettu keskiarvo (jatkuva) ja maankäyttö (codes =
        RealCodes) kehysten painotettu enemmistö: kehysten vaihtuessa raja on yksi siisti käyrä eikä liukuman
        raidoitusta, jossa kilometrejä todellista maisemaa pyyhkäistäisiin kapeaan kaistaan."""
        px = np.asarray(px, np.float64).ravel()
        pz = np.asarray(pz, np.float64).ravel()
        n = len(px)
        rx = np.empty(n)
        rz = np.empty(n)
        ground = np.empty(n)
        one = np.empty(n)
        code = np.zeros(n, np.uint8)
        g, r, d, rd = self.g, self.r, self.d, self.rd
        top = min(top, len(g))
        rows = np.arange(chunk)[:, None]
        for a in range(0, n, chunk):
            b = min(a + chunk, n)
            m = b - a
            dx = px[a:b, None] - g[None, :, 0]
            dz = pz[a:b, None] - g[None, :, 1]
            s = -(np.sqrt(dx * dx + dz * dz) - self.bonus[None, :]) / SIGMA
            idx = np.argpartition(-s, top - 1, axis=1)[:, :top]
            rr = rows[:m]
            s = s[rr, idx]
            dx = dx[rr, idx]
            dz = dz[rr, idx]
            s -= s.max(1, keepdims=True)
            w = np.exp(s)
            w /= w.sum(1, keepdims=True)
            fd_, frd, fr, fc = d[idx], rd[idx], r[idx], self.c[idx]
            along = dx * fd_[..., 0] + dz * fd_[..., 1]
            lat = -dx * fd_[..., 1] + dz * fd_[..., 0]
            lat = np.where(fc < LAT_C, lat_out(lat), lat)
            k = along / fc
            ex = fr[..., 0] + frd[..., 0] * k - frd[..., 1] * lat
            ez = fr[..., 1] + frd[..., 1] * k + frd[..., 0] * lat
            best = np.argmax(w, 1)
            rx[a:b] = ex[rr[:, 0], best]
            rz[a:b] = ez[rr[:, 0], best]
            gi = self.y[idx] - self.q[idx] + self.f[idx] * dem_at(self.fd, ex, ez)
            ground[a:b] = (w * gi).sum(1)
            one[a:b] = (w * (fc >= LAT_C)).sum(1)  # lievä tiivistys (keskustan kaista) kuten 1:1
            if codes is not None:
                ci = codes.at(ex, ez)
                votes = np.stack([(w * (ci == c)).sum(1) for c in range(8)], 1)
                code[a:b] = np.argmax(votes, 1)
        return rx, rz, ground, one, code


def dem_at(fd, x, z, smooth=0):
    """Korkeusmalli (vaala_tarkka.FrameDem) taulukoille, bilineaarisesti."""
    if smooth and smooth not in fd._smooth:
        fd._smooth[smooth] = ndimage.gaussian_filter(fd.a, smooth)
    a = fd._smooth[smooth] if smooth else fd.a
    fx = np.clip((np.asarray(x, np.float64) - fd.x0) / fd.step, 0.0, fd.nx - 1.001)
    fz = np.clip((np.asarray(z, np.float64) - fd.z0) / fd.step, 0.0, fd.nz - 1.001)
    return ndimage.map_coordinates(a, [fz, fx], order=1, mode="nearest")


class RealCodes:
    """Maankäyttö todellisessa kehyksessä rasterina (REAL_CELL): metsä pohjana, pellot, suot, taajama pihana ja
    vedet (Oulujoki keskiviivastaan leveänä uomana)."""

    def __init__(self, feats, x0, z0, x1, z1, river_segs, river_half):
        self.x0, self.z0 = x0, z0
        self.w = int((x1 - x0) / REAL_CELL) + 1
        self.h = int((z1 - z0) / REAL_CELL) + 1
        img = Image.new("L", (self.w, self.h), FOREST)
        dr = ImageDraw.Draw(img)

        def px(pts):
            return [((p[0] - x0) / REAL_CELL, (p[1] - z0) / REAL_CELL) for p in pts]

        for kind, code in (("town", YARD), ("field", FIELD), ("bog", BOG), ("water", WATER)):
            for f in feats:
                if f["kind"] == kind and len(f["pts"]) >= 3:
                    dr.polygon(px(f["pts"]), fill=code)
        for a, b in river_segs:
            dr.line(px([a, b]), fill=WATER, width=int(2 * river_half / REAL_CELL) + 1)
        self.a = np.asarray(img, np.uint8)

    def at(self, x, z):
        i = np.clip(np.round((np.asarray(x) - self.x0) / REAL_CELL).astype(int), 0, self.w - 1)
        j = np.clip(np.round((np.asarray(z) - self.z0) / REAL_CELL).astype(int), 0, self.h - 1)
        return self.a[j, i]


def flatten_water(codes, ground, water_level, cell):
    """Vesialueet (8-naapuruus) tasaisiksi: pinta mediaanista (pääjärvi ja joki tarkalleen water_level), pohja 1,2 m
    pinnan alle. Rannan maa vähintään 0,15 m pinnan yläpuolelle, ettei vesi tulvi ruutujen yli. Palauttaa pinnat."""
    wet = codes == WATER
    lab, n = ndimage.label(wet, structure=np.ones((3, 3)))
    level = np.full(codes.shape, np.nan)
    for k, sl in enumerate(ndimage.find_objects(lab), start=1):
        m = lab[sl] == k
        lv = float(np.median(ground[sl][m]))
        if abs(lv - water_level) < 1.5 or m.sum() > 2000:
            lv = water_level
        level[sl][m] = lv
    ground[wet] = level[wet] - 1.2
    # Ranta: lähimmän vesiruudun pinta 2 ruudun säteellä.
    if n:
        idx = ndimage.distance_transform_edt(~wet, return_distances=False, return_indices=True)
        near_lv = level[idx[0], idx[1]]
        dist = ndimage.distance_transform_edt(~wet)
        shore = (~wet) & (dist <= 2.0)
        ground[shore] = np.maximum(ground[shore], near_lv[shore] + 0.15)
    return level


def game_raster(polys, x0, z0, nx, nz, cell, lines=(), width=0.0):
    """Pelin kehyksen monikulmiot ja viivat bool-rasteriksi ruudukon pisteisiin."""
    img = Image.new("1", (nx, nz), 0)
    dr = ImageDraw.Draw(img)
    for pts in polys:
        dr.polygon([((p[0] - x0) / cell, (p[1] - z0) / cell) for p in pts], fill=1)
    for pts in lines:
        dr.line([((p[0] - x0) / cell, (p[1] - z0) / cell) for p in pts], fill=1, width=max(1, int(round(width / cell))))
    return np.array(img, bool)


def sample_trees(rng, tx, tz, th, tsp, inside, gx, gz, rx, rz, ok, keep_small):
    """Puut (x, z, pituus, laji) pelin ruutuihin käänteisotannalla: ruutu (pelin piste gx, gz, todellinen rx, rz) saa todellisen kehyksen
    saman REAL_CELL-ruudun puut samoin siirtymin ruudun sisällä. 1:1-alueella metsä kopioituu sellaisenaan,
    tiivistetyllä välillä ruudut poimivat puita harvemmista kohdista, joten tiheys säilyy. inside = ruudun todellinen
    paikka on laserkeilattu; muualle luonnollinen metsä arvalla. ok = puu sallittu ruudussa, keep_small = pienet
    täydennyspuut mukaan (muualla vain yli 7 m puut)."""
    x0 = math.floor(tx.min() / REAL_CELL) * REAL_CELL
    z0 = math.floor(tz.min() / REAL_CELL) * REAL_CELL
    w = int((tx.max() - x0) / REAL_CELL) + 2
    key = ((tz - z0) // REAL_CELL).astype(np.int64) * w + ((tx - x0) // REAL_CELL).astype(np.int64)
    order = np.argsort(key, kind="stable")
    key = key[order]
    ox = (tx - x0)[order] % REAL_CELL
    oz = (tz - z0)[order] % REAL_CELL
    hh = th[order]
    sp = tsp[order]
    ck = ((rz - z0) // REAL_CELL).astype(np.int64) * w + ((rx - x0) // REAL_CELL).astype(np.int64)
    inside = np.asarray(inside, bool) & (rx >= tx.min()) & (rx <= tx.max()) & (rz >= tz.min()) & (rz <= tz.max())
    sel = ok & inside
    lo = np.searchsorted(key, ck[sel], "left")
    hi = np.searchsorted(key, ck[sel], "right")
    cnt = hi - lo
    cell_of = np.repeat(np.nonzero(sel)[0], cnt)
    starts = np.repeat(lo, cnt) + (np.arange(cnt.sum()) - np.repeat(np.cumsum(cnt) - cnt, cnt))
    out_x = gx[cell_of] - REAL_CELL / 2 + ox[starts]
    out_z = gz[cell_of] - REAL_CELL / 2 + oz[starts]
    out_h = hh[starts]
    out_s = sp[starts]
    small = (out_h < 7.0) & ~keep_small[cell_of]
    out_x, out_z, out_h, out_s, cell_of = out_x[~small], out_z[~small], out_h[~small], out_s[~small], cell_of[~small]
    # Laserin ulkopuolella: luonnollinen sekametsä (mänty, kuusi, koivu), noin 0,5 puuta ruudussa.
    rest = np.nonzero(ok & ~inside)[0]
    rest = rest[rng.random(len(rest)) < 0.5]
    fx = gx[rest] + rng.uniform(-2, 2, len(rest))
    fz = gz[rest] + rng.uniform(-2, 2, len(rest))
    fh = np.clip(rng.normal(16.0, 4.0, len(rest)), 6.0, 26.0)
    fs = rng.choice([0, 1, 2], len(rest), p=[0.6, 0.22, 0.18]).astype(np.uint8)
    x = np.concatenate([out_x, fx]).astype(np.float32)
    z = np.concatenate([out_z, fz]).astype(np.float32)
    h = np.concatenate([out_h, fh]).astype(np.float32)
    s = np.concatenate([out_s, fs]).astype(np.uint8)
    return x, z, h, s
