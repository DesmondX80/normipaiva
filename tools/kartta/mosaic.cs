using System;

// 2 m korkeusmallilehtien mosaiikki (Tiff.Info + Tiff.Window lehti kerrallaan) ja näytteistys kartan pikseliruudukkoon.
public static class Mosaic {
    public static float[] G; public static int W, H; public static double E0, N0;  // rivi 0 = pohjoisreuna N0

    public static void Init(double e0, double n0, int w, int h) {
        E0 = e0; N0 = n0; W = w; H = h; G = new float[w * h];
        for (int k = 0; k < G.Length; k++) G[k] = float.NaN;
    }

    // Kopioi viimeksi Tiff.Info:lla avatun lehden päällekkäinen osa mosaiikkiin.
    public static string Blit() {
        double se = Tiff.dtags[33922][3], sn = Tiff.dtags[33922][4];
        int sw = (int)Tiff.tags[256][0], sh = (int)Tiff.tags[257][0];
        int oi = (int)Math.Round((se - E0) / 2.0), oj = (int)Math.Round((N0 - sn) / 2.0);
        int i0 = Math.Max(0, oi), i1 = Math.Min(W, oi + sw), j0 = Math.Max(0, oj), j1 = Math.Min(H, oj + sh);
        if (i1 <= i0 || j1 <= j0) return "ei päällekkäisyyttä (lehti E " + se + " N " + sn + ")";
        var win = Tiff.Window(i0 - oi, j0 - oj, i1 - i0, j1 - j0);
        for (int j = j0; j < j1; j++) for (int i = i0; i < i1; i++) G[j * W + i] = win[(j - j0) * (i1 - i0) + (i - i0)];
        return "lehti E " + se + " N " + sn + " -> mosaiikki " + (i1 - i0) + " x " + (j1 - j0);
    }

    public static float At(double e, double n) {
        double fi = (e - E0 - 1.0) / 2.0, fj = (N0 - 1.0 - n) / 2.0;
        int i = (int)Math.Floor(fi), j = (int)Math.Floor(fj);
        if (i < 0 || j < 0 || i >= W - 1 || j >= H - 1) return float.NaN;
        double tx = fi - i, ty = fj - j;
        float a = G[j * W + i], b = G[j * W + i + 1], c = G[(j + 1) * W + i], d = G[(j + 1) * W + i + 1];
        return (float)((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty);
    }

    // Kartan pikseliruudukko (px0 + i*step, py0 + j*step) -> korkeudet. Pikseli -> TM35 kehyksen yhdenmuotoisuus-
    // muunnoksella (J_K = px (195, 765) = (jkE, jkN), mittakaava sc m/px, kierto rot). Arvo on keskiarvo
    // (2*avg+1)^2 mallin ruudusta (2 m), jottei yksittäinen oja tai penkka näy terävänä. Puuttuvat NaN.
    public static float[] Sample(double px0, double py0, double step, int nx, int ny, double jkE, double jkN, double sc, double rot, int avg) {
        var r = new float[nx * ny];
        double c = Math.Cos(rot), s = Math.Sin(rot);
        for (int j = 0; j < ny; j++) for (int i = 0; i < nx; i++) {
            double dx = px0 + i * step - 195, dy = py0 + j * step - 765;
            double e = jkE + sc * (dx * c - dy * s), n = jkN - sc * (dx * s + dy * c);
            double sum = 0; int cnt = 0;
            for (int dj = -avg; dj <= avg; dj++) for (int di = -avg; di <= avg; di++) {
                float v = At(e + di * 2.0, n + dj * 2.0);
                if (!float.IsNaN(v)) { sum += v; cnt++; }
            }
            r[j * nx + i] = cnt > 0 ? (float)(sum / cnt) : float.NaN;
        }
        return r;
    }
}
