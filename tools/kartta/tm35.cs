using System;

public static class Tm35 {
    // GRS80 -> ETRS-TM35FIN (Krüger-sarja, JHS 197).
    public static double[] Fwd(double latDeg, double lonDeg) {
        double a = 6378137.0, f = 1 / 298.257222101, k0 = 0.9996, lon0 = 27.0 * Math.PI / 180, E0 = 500000;
        double n = f / (2 - f);
        double A1 = a / (1 + n) * (1 + n * n / 4 + n * n * n * n / 64);
        double e = Math.Sqrt(f * (2 - f));
        double h1 = n / 2 - 2.0 / 3 * n * n + 5.0 / 16 * n * n * n + 41.0 / 180 * n * n * n * n;
        double h2 = 13.0 / 48 * n * n - 3.0 / 5 * n * n * n + 557.0 / 1440 * n * n * n * n;
        double h3 = 61.0 / 240 * n * n * n - 103.0 / 140 * n * n * n * n;
        double h4 = 49561.0 / 161280 * n * n * n * n;
        double phi = latDeg * Math.PI / 180, lam = lonDeg * Math.PI / 180;
        double Q = Asinh(Math.Tan(phi)) - e * Atanh(e * Math.Sin(phi));
        double beta = Math.Atan(Math.Sinh(Q));
        double eta0 = Atanh(Math.Cos(beta) * Math.Sin(lam - lon0));
        double xi0 = Math.Asin(Math.Sin(beta) * Math.Cosh(eta0));
        double xi = xi0 + h1 * Math.Sin(2 * xi0) * Math.Cosh(2 * eta0) + h2 * Math.Sin(4 * xi0) * Math.Cosh(4 * eta0)
            + h3 * Math.Sin(6 * xi0) * Math.Cosh(6 * eta0) + h4 * Math.Sin(8 * xi0) * Math.Cosh(8 * eta0);
        double eta = eta0 + h1 * Math.Cos(2 * xi0) * Math.Sinh(2 * eta0) + h2 * Math.Cos(4 * xi0) * Math.Sinh(4 * eta0)
            + h3 * Math.Cos(6 * xi0) * Math.Sinh(6 * eta0) + h4 * Math.Cos(8 * xi0) * Math.Sinh(8 * eta0);
        return new double[] { E0 + A1 * eta * k0, A1 * xi * k0 };
    }
    static double Asinh(double x) { return Math.Log(x + Math.Sqrt(x * x + 1)); }
    static double Atanh(double x) { return 0.5 * Math.Log((1 + x) / (1 - x)); }
}
