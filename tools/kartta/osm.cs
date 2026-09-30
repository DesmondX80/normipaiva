using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Xml;

// OpenStreetMap-ote -> kylän kartta (scripts/map_osm.gd) tai mökin kohteet (kartta.json). Kylässä solmut muunnetaan
// ETRS-TM35FIN:iin (Tm35.Fwd) ja siitä kartan pikseleiksi kehyksen yhdenmuotoisuusmuunnoksella (J_K, J_PATO, ks. kehys.ps1).
// Python-versio: kartta.py (Osm).
public static class Osm {
    public class Way { public string Id; public List<string> Nd = new List<string>(); public Dictionary<string, string> Tag = new Dictionary<string, string>(); }
    public class Rel { public string Id; public List<string[]> Mem = new List<string[]>(); public Dictionary<string, string> Tag = new Dictionary<string, string>(); }

    static Dictionary<string, double[]> node = new Dictionary<string, double[]>();   // id -> px, py
    static Dictionary<string, Dictionary<string, string>> nodeTag = new Dictionary<string, Dictionary<string, string>>();
    static Dictionary<string, Way> way = new Dictionary<string, Way>();
    static List<Rel> rels = new List<Rel>();
    static Dictionary<string, int> nodeUse = new Dictionary<string, int>();
    static CultureInfo IC = CultureInfo.InvariantCulture;


    // Kartan kehys: px = J_K + R(-rot) * ((E, -N) - J_K) / sc
    static double jkE, jkN, sc, rot;
    public static void Frame(double e, double n, double scale, double rotation) { jkE = e; jkN = n; sc = scale; rot = rotation; }
    // Mökin kehys (Local): metrit osoitepisteestä, x itään ja z etelään, 111 320 m/aste (kuten tools/mokki_kartta.py).
    public static bool Local = false;
    public static double LLat0 = 64.5054523, LLon0 = 26.6672225;
    static double[] ToLocal(double lat, double lon) {
        return new[] { (lon - LLon0) * Math.Cos(LLat0 * Math.PI / 180.0) * 111320.0, -(lat - LLat0) * 111320.0 };
    }

    public static double[] ToPx(double e, double n) {
        double mx = e - jkE, my = jkN - n, c = Math.Cos(rot), s = Math.Sin(rot);
        return new[] { 195 + (mx * c + my * s) / sc, 765 + (-mx * s + my * c) / sc };
    }

    public static string Load(string path) {
        var rd = XmlReader.Create(path);
        Way w = null; Rel r = null; string nid = null;
        while (rd.Read()) {
            if (rd.NodeType == XmlNodeType.Element) {
                switch (rd.Name) {
                    case "node":
                        nid = rd.GetAttribute("id");
                        double lat = double.Parse(rd.GetAttribute("lat"), IC), lon = double.Parse(rd.GetAttribute("lon"), IC);
                        if (Local) node[nid] = ToLocal(lat, lon);
                        else { var t = Tm35.Fwd(lat, lon); node[nid] = ToPx(t[0], t[1]); }
                        w = null; r = null;
                        if (rd.IsEmptyElement) nid = null;
                        break;
                    case "way": w = new Way { Id = rd.GetAttribute("id") }; way[w.Id] = w; r = null; nid = null; break;
                    case "relation": r = new Rel { Id = rd.GetAttribute("id") }; rels.Add(r); w = null; nid = null; break;
                    case "nd": if (w != null) w.Nd.Add(rd.GetAttribute("ref")); break;
                    case "member": if (r != null) r.Mem.Add(new[] { rd.GetAttribute("type"), rd.GetAttribute("ref"), rd.GetAttribute("role") }); break;
                    case "tag":
                        string k = rd.GetAttribute("k"), v = rd.GetAttribute("v");
                        if (w != null) w.Tag[k] = v; else if (r != null) r.Tag[k] = v;
                        else if (nid != null) { if (!nodeTag.ContainsKey(nid)) nodeTag[nid] = new Dictionary<string, string>(); nodeTag[nid][k] = v; }
                        break;
                }
            } else if (rd.NodeType == XmlNodeType.EndElement && rd.Name == "node") nid = null;
        }
        foreach (var x in way.Values) foreach (var id in x.Nd) nodeUse[id] = (nodeUse.ContainsKey(id) ? nodeUse[id] : 0) + 1;
        return "solmuja " + node.Count + ", teitä/alueita " + way.Count + ", relaatioita " + rels.Count;
    }

    static string T(Way w, string k) { string v; return w.Tag.TryGetValue(k, out v) ? v : null; }

    // --- Geometria ---------------------------------------------------------------------------
    static List<double[]> Pts(IEnumerable<string> ids) { var o = new List<double[]>(); foreach (var id in ids) if (node.ContainsKey(id)) o.Add(node[id]); return o; }

    static double SegDist(double[] p, double[] a, double[] b) {
        double dx = b[0] - a[0], dy = b[1] - a[1], l2 = dx * dx + dy * dy;
        double t = l2 > 0 ? Math.Max(0, Math.Min(1, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dy) / l2)) : 0;
        double qx = a[0] + t * dx - p[0], qy = a[1] + t * dy - p[1];
        return Math.Sqrt(qx * qx + qy * qy);
    }

    // Douglas-Peucker; keep[i] = piste säilytetään aina (risteys).
    static List<int> Simplify(List<double[]> p, bool[] keep, double eps) {
        var m = new bool[p.Count]; m[0] = m[p.Count - 1] = true;
        for (int i = 0; i < p.Count; i++) if (keep != null && keep[i]) m[i] = true;
        var st = new Stack<int[]>();
        int prev = 0;
        for (int i = 1; i < p.Count; i++) if (m[i]) { st.Push(new[] { prev, i }); prev = i; }
        while (st.Count > 0) {
            var s = st.Pop(); double best = 0; int bi = -1;
            for (int i = s[0] + 1; i < s[1]; i++) { double d = SegDist(p[i], p[s[0]], p[s[1]]); if (d > best) { best = d; bi = i; } }
            if (bi >= 0 && best > eps) { m[bi] = true; st.Push(new[] { s[0], bi }); st.Push(new[] { bi, s[1] }); }
        }
        var o = new List<int>(); for (int i = 0; i < p.Count; i++) if (m[i]) o.Add(i); return o;
    }

    // Monikulmion rajaus suorakaiteeseen (Sutherland-Hodgman).
    static List<double[]> ClipPoly(List<double[]> poly, double x0, double y0, double x1, double y1) {
        Func<double[], int, bool> inside = (q, e) => e == 0 ? q[0] >= x0 : e == 1 ? q[0] <= x1 : e == 2 ? q[1] >= y0 : q[1] <= y1;
        Func<double[], double[], int, double[]> cut = (a, b, e) => {
            double t = e == 0 ? (x0 - a[0]) / (b[0] - a[0]) : e == 1 ? (x1 - a[0]) / (b[0] - a[0]) : e == 2 ? (y0 - a[1]) / (b[1] - a[1]) : (y1 - a[1]) / (b[1] - a[1]);
            return new[] { a[0] + t * (b[0] - a[0]), a[1] + t * (b[1] - a[1]) };
        };
        var o = poly;
        for (int e = 0; e < 4 && o.Count > 0; e++) {
            var inp = o; o = new List<double[]>();
            for (int i = 0; i < inp.Count; i++) {
                var cur = inp[i]; var pre = inp[(i + inp.Count - 1) % inp.Count];
                bool ci = inside(cur, e), pi = inside(pre, e);
                if (ci) { if (!pi) o.Add(cut(pre, cur, e)); o.Add(cur); } else if (pi) o.Add(cut(pre, cur, e));
            }
        }
        return o;
    }

    // Murtoviivan rajaus suorakaiteeseen: palauttaa sisäpuoliset osat (reunan ylityspisteet mukana).
    static List<List<double[]>> ClipLine(List<double[]> p, double x0, double y0, double x1, double y1, List<List<bool>> keepOut, bool[] keep) {
        var parts = new List<List<double[]>>(); List<double[]> cur = null; List<bool> ck = null;
        Func<double[], bool> ins = q => q[0] >= x0 && q[0] <= x1 && q[1] >= y0 && q[1] <= y1;
        for (int i = 0; i < p.Count; i++) {
            bool a = ins(p[i]);
            if (i > 0) {
                bool pa = ins(p[i - 1]);
                if (a != pa) {
                    // Ylityspiste: puolitushaku.
                    double[] lo = pa ? p[i - 1] : p[i], hi = pa ? p[i] : p[i - 1];
                    for (int k = 0; k < 30; k++) { var mid = new[] { (lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2 }; if (ins(mid)) lo = mid; else hi = mid; }
                    if (pa) { cur.Add(lo); ck.Add(true); parts.Add(cur); keepOut.Add(ck); cur = null; }
                    else { cur = new List<double[]> { lo }; ck = new List<bool> { true }; }
                }
            }
            if (a) { if (cur == null) { cur = new List<double[]>(); ck = new List<bool>(); } cur.Add(p[i]); ck.Add(keep[i]); }
        }
        if (cur != null && cur.Count > 1) { parts.Add(cur); keepOut.Add(ck); }
        return parts;
    }

    // Leikkaako (tai koskettaako) monikulmion kaksi ei-vierekkäistä sivua toisiaan: silloin se ei kolmioidu.
    static bool SelfIntersects(List<double[]> p) {
        int n = p.Count;
        Func<double[], double[], double[], double> cr = (a, b, c) => (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0]);
        for (int i = 0; i < n; i++) {
            var a = p[i]; var b = p[(i + 1) % n];
            for (int j = i + 2; j < n; j++) {
                if (i == 0 && j == n - 1) continue;
                var c = p[j]; var d = p[(j + 1) % n];
                double d1 = cr(c, d, a), d2 = cr(c, d, b), d3 = cr(a, b, c), d4 = cr(a, b, d);
                if (((d1 > 0) != (d2 > 0) || d1 == 0 || d2 == 0) && ((d3 > 0) != (d4 > 0) || d3 == 0 || d4 == 0)) {
                    // Rajaavat laatikot osuvat päällekkäin (kollineaariset tapaukset).
                    if (Math.Max(Math.Min(a[0], b[0]), Math.Min(c[0], d[0])) <= Math.Min(Math.Max(a[0], b[0]), Math.Max(c[0], d[0]))
                        && Math.Max(Math.Min(a[1], b[1]), Math.Min(c[1], d[1])) <= Math.Min(Math.Max(a[1], b[1]), Math.Max(c[1], d[1])))
                        return true;
                }
            }
        }
        return false;
    }

    static List<double[]> RoundPts(List<double[]> p) {
        var o = new List<double[]>();
        foreach (var q in p) {
            var r = new[] { Math.Round(q[0]), Math.Round(q[1]) };
            if (o.Count == 0 || o[o.Count - 1][0] != r[0] || o[o.Count - 1][1] != r[1]) o.Add(r);
        }
        if (o.Count > 1 && o[0][0] == o[o.Count - 1][0] && o[0][1] == o[o.Count - 1][1]) o.RemoveAt(o.Count - 1);
        return o;
    }

    static double Area(List<double[]> p) { double a = 0; for (int i = 0; i < p.Count; i++) { var q = p[i]; var r = p[(i + 1) % p.Count]; a += q[0] * r[1] - r[0] * q[1]; } return a / 2; }

    // Relaation ulkorenkaat: jäsenviivat ketjutetaan päätepisteistä.
    static List<List<string>> Rings(Rel r) {
        var segs = new List<List<string>>();
        foreach (var m in r.Mem) if (m[0] == "way" && m[2] != "inner" && way.ContainsKey(m[1])) segs.Add(new List<string>(way[m[1]].Nd));
        var rings = new List<List<string>>();
        while (segs.Count > 0) {
            var ring = segs[0]; segs.RemoveAt(0);
            bool grew = true;
            while (ring[0] != ring[ring.Count - 1] && grew) {
                grew = false;
                for (int i = 0; i < segs.Count; i++) {
                    var s = segs[i];
                    if (s[0] == ring[ring.Count - 1]) { ring.AddRange(s.Skip(1)); }
                    else if (s[s.Count - 1] == ring[ring.Count - 1]) { var rv = new List<string>(s); rv.Reverse(); ring.AddRange(rv.Skip(1)); }
                    else continue;
                    segs.RemoveAt(i); grew = true; break;
                }
            }
            if (ring[0] == ring[ring.Count - 1]) rings.Add(ring);
        }
        return rings;
    }

    // --- Luokittelu --------------------------------------------------------------------------
    static string RoadType(Way w) {
        string h = T(w, "highway"); if (h == null || T(w, "area") == "yes") return null;
        switch (h) {
            case "motorway": case "trunk": case "primary": return "highway";
            case "secondary": case "tertiary": case "unclassified": return "road";
            case "residential": case "living_street": return "street";
            case "service": string sv = T(w, "service"); return (sv == null && T(w, "name") != null) ? "street" : null;
            case "track": case "path": case "bridleway": return "path";
            case "cycleway": return "path";
            case "footway": string fw = T(w, "footway"); return (fw == "sidewalk" || fw == "crossing") ? null : "path";
        }
        return null;
    }

    static string AreaKind(Dictionary<string, string> t) {
        string v;
        if (t.TryGetValue("natural", out v)) { if (v == "water") return "water"; if (v == "wood") return "forest"; if (v == "wetland") return "bog"; if (v == "scrub" || v == "heath") return "forest"; }
        if (t.TryGetValue("landuse", out v)) {
            if (v == "forest") return "forest";
            if (v == "farmland" || v == "meadow") return "field";
            if (v == "reservoir" || v == "basin") return "water";
        }
        if (t.TryGetValue("water", out v)) return "water";
        return null;
    }

    // --- Vienti GDScriptiksi -------------------------------------------------------------------
    static string V(double[] p) { return "Vector2(" + Math.Round(p[0]).ToString(IC) + ", " + Math.Round(p[1]).ToString(IC) + ")"; }

    public static string Export(string outPath, double x0, double y0, double x1, double y1) {
        var sb = new StringBuilder();
        var log = new StringBuilder();
        sb.Append("extends RefCounted\n");
        sb.Append("## GENEROITU (tools/kartta/kyla_osm.ps1 tai kyla_osm.py): kylän kartta OpenStreetMapista (© OpenStreetMap-tekijät, ODbL).\n");
        sb.Append("## Koordinaatit kartan pikseleinä (ETRS-TM35FIN -> 1,22 m/px, ks. tools/kartta/kehys.ps1). Älä muokkaa käsin.\n\n");

        // Tiet: saman nimen ja tyypin pätkät ketjutetaan, risteyssolmut säilytetään yksinkertaistuksessa.
        var groups = new Dictionary<string, List<List<string>>>();
        foreach (var w in way.Values) {
            string rt = RoadType(w); if (rt == null || w.Nd.Count < 2) continue;
            string key = rt + "|" + (T(w, "name") ?? "");
            if (!groups.ContainsKey(key)) groups[key] = new List<List<string>>();
            groups[key].Add(new List<string>(w.Nd));
        }
        sb.Append("const ROADS := [\n");
        int nroads = 0;
        foreach (var kv in groups) {
            var segs = kv.Value; string rt = kv.Key.Split('|')[0], name = kv.Key.Substring(rt.Length + 1);
            // Ketjutus päätepisteistä.
            var chains = new List<List<string>>();
            while (segs.Count > 0) {
                var c = segs[0]; segs.RemoveAt(0); bool grew = true;
                while (grew) {
                    grew = false;
                    for (int i = 0; i < segs.Count; i++) {
                        var s = segs[i];
                        if (s[0] == c[c.Count - 1]) c.AddRange(s.Skip(1));
                        else if (s[s.Count - 1] == c[c.Count - 1]) { var rv = new List<string>(s); rv.Reverse(); c.AddRange(rv.Skip(1)); }
                        else if (s[s.Count - 1] == c[0]) { c.InsertRange(0, s.Take(s.Count - 1)); }
                        else if (s[0] == c[0]) { var rv = new List<string>(s); rv.Reverse(); c.InsertRange(0, rv.Take(rv.Count - 1)); }
                        else continue;
                        segs.RemoveAt(i); grew = true; break;
                    }
                }
                chains.Add(c);
            }
            foreach (var c in chains) {
                var ids = c.Where(id => node.ContainsKey(id)).ToList();
                var p = ids.Select(id => node[id]).ToList();
                var keep = ids.Select(id => nodeUse.ContainsKey(id) && nodeUse[id] > 1).ToArray();
                var kout = new List<List<bool>>();  // ClipLine lisää osat ja niiden keep-listat samassa järjestyksessä
                var parts = ClipLine(p, x0, y0, x1, y1, kout, keep);
                for (int pi = 0; pi < parts.Count; pi++) {
                    var part = parts[pi];
                    double len = 0; for (int i = 1; i < part.Count; i++) len += Math.Sqrt(Math.Pow(part[i][0] - part[i - 1][0], 2) + Math.Pow(part[i][1] - part[i - 1][1], 2));
                    if (len < (rt == "path" ? 25 : 10)) continue;
                    var idx = Simplify(part, kout[pi].ToArray(), rt == "path" ? 2.0 : 1.2);
                    double hd = rt == "street" ? 0.8 : rt == "road" ? 0.3 : 0.0;
                    sb.Append("\t{\"type\": \"" + rt + "\", \"name\": \"" + name.Replace("\"", "") + "\", \"h\": " + hd.ToString(IC) + ", \"pts\": [");
                    sb.Append(string.Join(", ", idx.Select(i => V(part[i]))));
                    sb.Append("]},\n");
                    nroads++;
                }
            }
        }
        sb.Append("]\n\n");
        log.AppendLine("teitä " + nroads);

        // Alueet: suljetut viivat ja multipolygonirelaatioiden ulkorenkaat.
        var areas = new Dictionary<string, List<List<double[]>>> { { "forest", new List<List<double[]>>() }, { "field", new List<List<double[]>>() }, { "bog", new List<List<double[]>>() }, { "water", new List<List<double[]>>() } };
        int skipped = 0;
        Action<string, List<string>> addArea = (kind, ids) => {
            var p = Pts(ids); if (p.Count < 4) return;
            p.RemoveAt(p.Count - 1);
            var cp = ClipPoly(p, x0, y0, x1, y1);
            if (cp.Count < 3 || Math.Abs(Area(cp)) < (kind == "water" ? 40 : 300)) return;
            // Rajattu ja yksinkertaistettu alue; jos se leikkaa itseään (kovera alue ylittää rajan monesti, jolloin
            // rajaus jättää nollaleveitä reunoja), kokeillaan tarkempaa ja lopuksi rajaamatonta aluetta.
            var tries = new List<Tuple<List<double[]>, double>> {
                Tuple.Create(cp, kind == "water" ? 1.0 : 2.5), Tuple.Create(cp, 0.8), Tuple.Create(p, 2.5), Tuple.Create(p, 0.8) };
            foreach (var t in tries) {
                var src = t.Item1;
                var idx = Simplify(src.Concat(new[] { src[0] }).ToList(), null, t.Item2);
                var sp = RoundPts(idx.Take(idx.Count - 1).Select(i => src[i]).ToList());
                if (sp.Count >= 3 && !SelfIntersects(sp)) { areas[kind].Add(sp); return; }
            }
            skipped++;
        };
        foreach (var w in way.Values) {
            if (w.Nd.Count < 4 || w.Nd[0] != w.Nd[w.Nd.Count - 1]) continue;
            string k = AreaKind(w.Tag); if (k != null) addArea(k, w.Nd);
        }
        foreach (var r in rels) {
            if (!r.Tag.ContainsKey("type") || r.Tag["type"] != "multipolygon") continue;
            string k = AreaKind(r.Tag); if (k == null) continue;
            foreach (var ring in Rings(r)) addArea(k, ring);
        }
        foreach (var kind in new[] { "forest", "field", "bog", "water" }) {
            sb.Append("const " + (kind == "forest" ? "FORESTS" : kind == "field" ? "FIELDS" : kind == "bog" ? "BOGS" : "WATER") + " := [\n");
            foreach (var poly in areas[kind]) sb.Append("\t[" + string.Join(", ", poly.Select(V)) + "],\n");
            sb.Append("]\n\n");
            log.AppendLine(kind + " " + areas[kind].Count);
        }
        if (skipped > 0) {
            log.AppendLine("ohitettu (ei kolmioidu) " + skipped);
        }

        // Purot ja ojat (nimetyt purot sekä nimetyt ojat).
        sb.Append("const STREAMS := [\n");
        int nst = 0;
        foreach (var w in way.Values) {
            string ww = T(w, "waterway"); if (ww != "stream" && ww != "river" && !(ww == "ditch" && T(w, "name") != null)) continue;
            var p = Pts(w.Nd); var kout = new List<List<bool>>();
            foreach (var part in ClipLine(p, x0, y0, x1, y1, kout, new bool[p.Count])) {
                if (part.Count < 2) continue;
                var idx = Simplify(part, null, 2.0);
                sb.Append("\t[" + string.Join(", ", idx.Select(i => V(part[i]))) + "],\n"); nst++;
            }
        }
        sb.Append("]\n\n");
        log.AppendLine("puroja " + nst);

        // Rakennukset: suunnattu rajaava suorakaide (pienin pinta-ala sivujen suunnista).
        sb.Append("## Rakennukset: keskipiste, pitkän sivun suunta (rad, kartan x-akselista), pituus l ja syvyys d (px), kerrokset, tyyppi.\n");
        sb.Append("const BUILDINGS := [\n");
        int nb = 0;
        foreach (var w in way.Values) {
            string bt = T(w, "building"); if (bt == null || w.Nd.Count < 4) continue;
            var p = Pts(w.Nd); if (p.Count < 4) continue; p.RemoveAt(p.Count - 1);
            double cx = p.Average(q => q[0]), cy = p.Average(q => q[1]);
            if (cx < x0 || cx > x1 || cy < y0 || cy > y1) continue;
            double bestA = double.MaxValue, bang = 0, bl = 0, bd = 0, bcx = 0, bcy = 0;
            for (int i = 0; i < p.Count; i++) {
                var a = p[i]; var b = p[(i + 1) % p.Count];
                double ang = Math.Atan2(b[1] - a[1], b[0] - a[0]), c = Math.Cos(ang), s = Math.Sin(ang);
                double u0 = double.MaxValue, u1 = double.MinValue, v0 = double.MaxValue, v1 = double.MinValue;
                foreach (var q in p) { double u = q[0] * c + q[1] * s, v = -q[0] * s + q[1] * c; u0 = Math.Min(u0, u); u1 = Math.Max(u1, u); v0 = Math.Min(v0, v); v1 = Math.Max(v1, v); }
                double ar = (u1 - u0) * (v1 - v0);
                if (ar < bestA) {
                    bestA = ar; double um = (u0 + u1) / 2, vm = (v0 + v1) / 2;
                    bcx = um * c - vm * s; bcy = um * s + vm * c;
                    if (u1 - u0 >= v1 - v0) { bang = ang; bl = u1 - u0; bd = v1 - v0; } else { bang = ang + Math.PI / 2; bl = v1 - v0; bd = u1 - u0; }
                }
            }
            if (bl * bd < 12) continue;
            int lv = 1; string lvs = T(w, "building:levels"); int lvp; if (lvs != null && int.TryParse(lvs, out lvp)) lv = lvp;
            while (bang > Math.PI / 2) bang -= Math.PI; while (bang < -Math.PI / 2) bang += Math.PI;
            sb.Append("\t{\"c\": Vector2(" + Math.Round(bcx, 1).ToString(IC) + ", " + Math.Round(bcy, 1).ToString(IC) + "), \"a\": " + Math.Round(bang, 3).ToString(IC)
                + ", \"l\": " + Math.Round(bl, 1).ToString(IC) + ", \"d\": " + Math.Round(bd, 1).ToString(IC) + ", \"lv\": " + lv + ", \"t\": \"" + bt + "\"},\n");
            nb++;
        }
        sb.Append("]\n");
        log.AppendLine("rakennuksia " + nb);
        File.WriteAllText(outPath, sb.ToString(), new UTF8Encoding(false));
        return log.ToString();
    }

    // --- Mökki: kohteet kartta.json-muodossa (kuten tools/mokki_kartta.py, lisäksi metsät) ---------------
    static string MokkiKind(Dictionary<string, string> t) {
        string v;
        if ((t.TryGetValue("natural", out v) && v == "water") || (t.TryGetValue("landuse", out v) && v == "reservoir")) return "water";
        if (t.TryGetValue("landuse", out v) && (v == "farmland" || v == "meadow" || v == "grass")) return "field";
        if (t.TryGetValue("natural", out v) && v == "wetland") return "bog";
        if (t.TryGetValue("natural", out v) && v == "sand") return "sand";
        if ((t.TryGetValue("landuse", out v) && v == "forest") || (t.TryGetValue("natural", out v) && (v == "wood" || v == "scrub" || v == "heath"))) return "forest";
        if (t.ContainsKey("highway")) return "road";
        if (t.ContainsKey("building")) return "building";
        if (t.ContainsKey("waterway")) return "stream";
        return null;
    }

    static string Js(string s) {
        var b = new StringBuilder("\"");
        foreach (char c in s ?? "") { if (c == '"' || c == '\\') b.Append('\\'); if (c >= ' ') b.Append(c); }
        return b.Append('"').ToString();
    }

    // Kohteet JSON-taulukkona. level(xs, zs) antaa vesistön pinnan (m), se lisätään vesikohteisiin kenttään "level".
    public static string MokkiFeatures(Func<double[], double[], double> level, out int count) {
        var items = new List<string>();
        Action<string, Dictionary<string, string>, string, List<double[]>> add = (kind, tags, id, p) => {
            if (p.Count < 2) return;
            string ftype = null;
            foreach (var k in new[] { "highway", "building", "waterway", "natural" }) { string v; if (tags.TryGetValue(k, out v)) { ftype = v; break; } }
            ftype = ftype ?? "";
            if (ftype == "yes" && kind != "building") ftype = "";
            string name; tags.TryGetValue("name", out name);
            var sb = new StringBuilder();
            sb.Append("{\"kind\":" + Js(kind) + ",\"name\":" + Js(name ?? "") + ",\"type\":" + Js(ftype) + ",\"id\":" + Js(id) + ",\"pts\":[");
            sb.Append(string.Join(",", p.Select(q => "[" + Math.Round(q[0], 1).ToString(IC) + "," + Math.Round(q[1], 1).ToString(IC) + "]")));
            sb.Append("]");
            if (kind == "water") sb.Append(",\"level\":" + Math.Round(level(p.Select(q => q[0]).ToArray(), p.Select(q => q[1]).ToArray()), 2).ToString(IC));
            sb.Append("}");
            items.Add(sb.ToString());
        };
        foreach (var w in way.Values) {
            string kind = MokkiKind(w.Tag); if (kind == null) continue;
            add(kind, w.Tag, w.Id, Pts(w.Nd));
        }
        foreach (var r in rels) {
            if (!r.Tag.ContainsKey("type") || r.Tag["type"] != "multipolygon") continue;
            string kind = MokkiKind(r.Tag); if (kind == null) continue;
            int k = 0;
            foreach (var ring in Rings(r)) add(kind, r.Tag, "r" + r.Id + "_" + (k++), Pts(ring));
        }
        count = items.Count;
        return "[" + string.Join(",", items) + "]";
    }

    // Apuri: nimettyjen kohteiden (solmut ja alueet) keskipisteet pikseleinä, esim. kaupat ja paikannimet.
    public static string Find(string key, string value) {
        var sb = new StringBuilder();
        foreach (var kv in nodeTag) { string v; if (kv.Value.TryGetValue(key, out v) && (value == "*" || v == value) && node.ContainsKey(kv.Key)) { var p = node[kv.Key]; string nm; kv.Value.TryGetValue("name", out nm); sb.AppendLine(string.Format(IC, "solmu {0} {1}: ({2:F0}, {3:F0})", v, nm, p[0], p[1])); } }
        foreach (var w in way.Values) { string v; if (w.Tag.TryGetValue(key, out v) && (value == "*" || v == value)) { var p = Pts(w.Nd); if (p.Count == 0) continue; string nm; w.Tag.TryGetValue("name", out nm); sb.AppendLine(string.Format(IC, "alue {0} {1}: ({2:F0}, {3:F0})", v, nm, p.Average(q => q[0]), p.Average(q => q[1]))); } }
        return sb.ToString();
    }

    public static string Junction(string a, string b) {
        var sa = new HashSet<string>(); var sbn = new HashSet<string>();
        foreach (var w in way.Values) { string n = T(w, "name"); if (n == a) foreach (var id in w.Nd) sa.Add(id); if (n == b) foreach (var id in w.Nd) sbn.Add(id); }
        var o = new StringBuilder();
        foreach (var id in sa) if (sbn.Contains(id) && node.ContainsKey(id)) o.AppendLine(string.Format(IC, "{0} / {1}: ({2:F1}, {3:F1})", a, b, node[id][0], node[id][1]));
        return o.ToString();
    }
}
