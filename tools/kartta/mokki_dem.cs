using System;
using System.Collections.Generic;

// Mökin kartan korkeudet MML:n 2 m mallista (Mosaic): kaukoalueen ruudukko ja vesistöjen pinnat. Mökin kehys on
// metrejä osoitepisteestä (x itään, z etelään, 111 320 m/aste kuten tools/mokki_kartta.py).
public static class MokkiDem {
    public static double Lat0 = 64.5054523, Lon0 = 26.6672225, MPerDeg = 111320.0;

    static double[] Tm(double x, double z) {
        double lat = Lat0 - z / MPerDeg;
        double lon = Lon0 + x / (Math.Cos(Lat0 * Math.PI / 180.0) * MPerDeg);
        return Tm35.Fwd(lat, lon);
    }

    public static float At(double x, double z) { var t = Tm(x, z); return Mosaic.At(t[0], t[1]); }

    // Ruudukko x0 + i*step, z0 + j*step (rivi kerrallaan).
    public static float[] Grid(double x0, double z0, double step, int n) {
        var r = new float[n * n];
        for (int j = 0; j < n; j++) for (int i = 0; i < n; i++) r[j * n + i] = At(x0 + i * step, z0 + j * step);
        return r;
    }

    static bool Inside(double[] xs, double[] zs, double x, double z) {
        bool c = false;
        for (int i = 0, j = xs.Length - 1; i < xs.Length; j = i++)
            if ((zs[i] > z) != (zs[j] > z) && x < (xs[j] - xs[i]) * (z - zs[i]) / (zs[j] - zs[i]) + xs[i]) c = !c;
        return c;
    }

    // Vesistön pinta: korkeusmallin alin kohta järven sisällä (malli tasoittaa vedenpinnan) 2 m välein;
    // pienelle lammelle, jonka sisään ei osu näytteitä, rantaviivan alin kohta.
    public static double Level(double[] xs, double[] zs) {
        double x0 = double.MaxValue, x1 = double.MinValue, z0 = double.MaxValue, z1 = double.MinValue;
        for (int k = 0; k < xs.Length; k++) { x0 = Math.Min(x0, xs[k]); x1 = Math.Max(x1, xs[k]); z0 = Math.Min(z0, zs[k]); z1 = Math.Max(z1, zs[k]); }
        double best = double.MaxValue;
        for (double z = Math.Ceiling(z0 / 2) * 2; z <= z1; z += 2)
            for (double x = Math.Ceiling(x0 / 2) * 2; x <= x1; x += 2)
                if (Inside(xs, zs, x, z)) { float v = At(x, z); if (!float.IsNaN(v)) best = Math.Min(best, v); }
        if (best == double.MaxValue)
            for (int k = 0; k < xs.Length; k++) { float v = At(xs[k], zs[k]); if (!float.IsNaN(v)) best = Math.Min(best, v); }
        return best;
    }
}
