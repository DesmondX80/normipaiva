using System;
using System.IO;
using System.IO.Compression;
using System.Collections.Generic;
using System.Text;

public static class Tiff {
    static byte[] f;
    static ushort U16(long o) { return BitConverter.ToUInt16(f, (int)o); }
    static uint U32(long o) { return BitConverter.ToUInt32(f, (int)o); }
    public static Dictionary<int, long[]> tags = new Dictionary<int, long[]>();
    public static Dictionary<int, double[]> dtags = new Dictionary<int, double[]>();

    public static string Info(string path) {
        f = File.ReadAllBytes(path);
        long ifd = U32(4);
        int n = U16(ifd);
        var sb = new StringBuilder();
        for (int i = 0; i < n; i++) {
            long e = ifd + 2 + i * 12;
            int tag = U16(e), type = U16(e + 2);
            long cnt = U32(e + 4);
            int sz = type == 3 ? 2 : type == 4 ? 4 : type == 12 ? 8 : type == 16 ? 8 : 1;
            long off = cnt * sz <= 4 ? e + 8 : U32(e + 8);
            if (type == 12) {
                var d = new double[cnt];
                for (int k = 0; k < cnt; k++) d[k] = BitConverter.ToDouble(f, (int)(off + k * 8));
                dtags[tag] = d;
                sb.AppendLine(tag + " dbl[" + cnt + "] " + string.Join(",", d.Length > 8 ? new double[] { d[0], d[1], d[2], d[3], d[4], d[5] } : d));
            } else if (type == 3 || type == 4) {
                var v = new long[cnt];
                for (int k = 0; k < cnt; k++) v[k] = type == 3 ? U16(off + k * 2) : U32(off + k * 4);
                tags[tag] = v;
                sb.AppendLine(tag + " int[" + cnt + "] " + (cnt > 8 ? v[0] + "," + v[1] + ".." : string.Join(",", v)));
            } else if (type == 2) {
                sb.AppendLine(tag + " str " + Encoding.ASCII.GetString(f, (int)off, (int)cnt));
            } else sb.AppendLine(tag + " type" + type + " cnt" + cnt);
        }
        return sb.ToString();
    }

    static byte[] Inflate(byte[] src) {
        using (var ms = new MemoryStream(src, 2, src.Length - 2))
        using (var ds = new DeflateStream(ms, CompressionMode.Decompress))
        using (var o = new MemoryStream()) { ds.CopyTo(o); return o.ToArray(); }
    }

    static byte[] Lzw(byte[] src, int expected) {
        var outp = new List<byte>(expected);
        var dict = new List<byte[]>();
        int bitPos = 0, codeLen = 9;
        Func<int> read = () => {
            int v = 0;
            for (int i = 0; i < codeLen; i++) {
                int bp = bitPos + i; if ((bp >> 3) >= src.Length) return 257;
                v = (v << 1) | ((src[bp >> 3] >> (7 - (bp & 7))) & 1);
            }
            bitPos += codeLen; return v;
        };
        Action reset = () => { dict.Clear(); for (int i = 0; i < 256; i++) dict.Add(new byte[] { (byte)i }); dict.Add(null); dict.Add(null); codeLen = 9; };
        reset();
        byte[] prev = null;
        while (true) {
            int c = read();
            if (c == 257) break;
            if (c == 256) { reset(); prev = null; continue; }
            byte[] entry;
            if (c < dict.Count) entry = dict[c];
            else { entry = new byte[prev.Length + 1]; Array.Copy(prev, entry, prev.Length); entry[prev.Length] = prev[0]; }
            outp.AddRange(entry);
            if (prev != null) {
                var ne = new byte[prev.Length + 1]; Array.Copy(prev, ne, prev.Length); ne[prev.Length] = entry[0]; dict.Add(ne);
            }
            prev = entry;
            int nxt = dict.Count + 1;
            if (nxt >= 4096) codeLen = 12; else if (nxt >= 2048) codeLen = 12; else if (nxt >= 1024) codeLen = 11; else if (nxt >= 512) codeLen = 10;
        }
        return outp.ToArray();
    }

    // Palauttaa (x0..x0+w, y0..y0+h) -ikkunan float-arvot rivijärjestyksessä.
    public static float[] Window(int x0, int y0, int w, int h) {
        int W = (int)tags[256][0];
        int comp = (int)tags[259][0];
        int pred = tags.ContainsKey(317) ? (int)tags[317][0] : 1;
        int tw = (int)tags[322][0], th = (int)tags[323][0];
        long[] offs = tags[324], lens = tags[325];
        int tilesX = (W + tw - 1) / tw;
        var res = new float[w * h];
        var cache = new Dictionary<int, float[]>();
        for (int y = 0; y < h; y++) for (int x = 0; x < w; x++) {
            int gx = x0 + x, gy = y0 + y;
            int ti = (gy / th) * tilesX + gx / tw;
            float[] t;
            if (!cache.TryGetValue(ti, out t)) {
                var raw = new byte[lens[ti]]; Array.Copy(f, offs[ti], raw, 0, (int)lens[ti]);
                byte[] dec = comp == 8 || comp == 32946 ? Inflate(raw) : comp == 5 ? Lzw(raw, tw * th * 4) : raw;
                if (pred == 3) {
                    var o2 = new byte[dec.Length];
                    for (int r = 0; r < th; r++) {
                        int rb = r * tw * 4;
                        for (int i = 1; i < tw * 4; i++) dec[rb + i] = (byte)(dec[rb + i] + dec[rb + i - 1]);
                        for (int i = 0; i < tw; i++) for (int b = 0; b < 4; b++) o2[rb + i * 4 + b] = dec[rb + (3 - b) * tw + i];
                    }
                    dec = o2;
                } else if (pred == 2) throw new Exception("pred2 float");
                t = new float[tw * th];
                for (int i = 0; i < tw * th; i++) t[i] = BitConverter.ToSingle(dec, i * 4);
                cache[ti] = t;
            }
            res[y * w + x] = t[(gy % th) * tw + gx % tw];
        }
        return res;
    }
}
