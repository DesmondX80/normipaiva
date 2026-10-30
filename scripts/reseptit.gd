extends RefCounted
## Huumeiden jatkamisen askartelureseptit (klaffipoyta.gd) ja reseptikirjan (journal.gd) piirtäminen.
## Minecraft-tyyliin muoto ratkaisee: 3×3-ruudukon täytetyt ruudut rajataan pienimpään suorakulmioon ja verrataan kuvioon
## (D = huume, A = jatke, . = tyhjä; paikka ruudukossa ei ratkaise). Huume voi olla mikä tahansa jatkoaste, jos jatkokertoja
## ei tule yli rajan. Tulos: sama huume, jatkoaste + cuts, `yield` annosta (teho 0,5^aste, main.gd _laake_pot).
## Jatke on apteekin Burana/Panadol (reppu) tai K-auton tarvike (sokeri, turbohiiva): halvempi jatke jatkaa rutkasti
## (aste +2, neljä annosta), mutta jäädään helpommin kiinni (main.gd TEINI_KIINNI).

const RECIPES := {
	"oksi_burana": {"name": "Oksikodoni + Burana", "drug": "opiaatti", "agent": "burana", "pattern": [["D"], ["A"]], "mirror": false,
		"cuts": 1, "yield": 2, "note": "Murskaa tabletti ja sekoita Buranaan. Kaksi annosta, puolet teholla."},
	"perv_panadol": {"name": "Pervitiini + Panadol", "drug": "perv", "agent": "panadol", "pattern": [["D", "A"]], "mirror": true,
		"cuts": 1, "yield": 2, "note": "Panadol jauheeksi pervitiinin sekaan. Kaksi annosta, puolet teholla."},
	"perv_sokeri": {"name": "Pervitiini + Sokeri", "drug": "perv", "agent": "sokeri", "pattern": [["D", "."], [".", "A"]], "mirror": false,
		"cuts": 2, "yield": 4, "note": "Sokeri näyttää kristallilta. Neljä annosta, teho vain neljännes ja riski on suuri."},
	"oksi_turbo": {"name": "Oksikodoni + Turbohiiva", "drug": "opiaatti", "agent": "turbohiiva", "pattern": [[".", "A"], ["D", "."]], "mirror": false,
		"cuts": 2, "yield": 4, "note": "Hiivajauhe vie tilaa. Neljä annosta, teho vain neljännes ja riski on suuri."},
}
const IDS := ["oksi_burana", "perv_panadol", "perv_sokeri", "oksi_turbo"]
const NAMES := {"opiaatti": "Oksikodoni", "perv": "Pervitiini", "burana": "Burana", "panadol": "Panadol", "panacod": "Panacod",
	"tramal": "Tramal", "sokeri": "Sokeri", "turbohiiva": "Turbohiiva"}
const QUALITY := ["Puhdas", "Hyvä", "Laimea", "Heikko", "Roska"]


static func base(key: String) -> String:
	return key.get_slice("~", 0)


static func tier(key: String) -> int:
	return int(key.get_slice("~", 1)) if "~" in key else 0


## Etsii ruudukosta (9 avainta, "" = tyhjä) reseptin. Palauttaa {"id", "drug"} (huumeen avain) tai {}.
static func find(cells: Array, max_tier: int) -> Dictionary:
	var r0 := 9
	var r1 := -1
	var c0 := 9
	var c1 := -1
	for i in 9:
		if cells[i] != "":
			r0 = mini(r0, i / 3)
			r1 = maxi(r1, i / 3)
			c0 = mini(c0, i % 3)
			c1 = maxi(c1, i % 3)
	if r1 < 0:
		return {}
	for id in IDS:
		var rc: Dictionary = RECIPES[id]
		var pats: Array = [rc.pattern]
		if rc.mirror:
			pats.append(rc.pattern.map(func(row: Array) -> Array:
				var rev := row.duplicate()
				rev.reverse()
				return rev))
		for pat in pats:
			if pat.size() != r1 - r0 + 1 or pat[0].size() != c1 - c0 + 1:
				continue
			var drug = _fits(pat, cells, r0, c0, rc, max_tier)
			if drug != null:
				return {"id": id, "drug": drug}
	return {}


## Palauttaa huumeen avaimen, jos kuvio sopii; muuten null.
static func _fits(pat: Array, cells: Array, r0: int, c0: int, rc: Dictionary, max_tier: int):
	var drug := ""
	for r in pat.size():
		for c in pat[0].size():
			var sym: String = pat[r][c]
			var cell: String = cells[(r0 + r) * 3 + c0 + c]
			if sym == ".":
				if cell != "":
					return null
			elif sym == "D":
				if cell == "" or base(cell) != rc.drug or tier(cell) + int(rc.cuts) > max_tier:
					return null
				drug = cell
			elif cell != rc.agent:
				return null
	return drug


## Esineen kuva ruutuun: pilleripakkaus, pussi tai pakkaus; jatketulle teho-% kulmaan.
static func draw_item(ci: CanvasItem, r: Rect2, key: String, font: Font) -> void:
	var b := base(key)
	var inner := r.grow(-r.size.x * 0.14)
	var c := inner.get_center()
	match b:
		"opiaatti":  # läpipainoliuska: valkoiset tabletit hopeassa
			ci.draw_rect(inner, Color(0.78, 0.8, 0.84))
			ci.draw_rect(inner, Color(0.4, 0.42, 0.48), false, 2.0)
			for k in 6:
				var p := inner.position + Vector2(inner.size.x * (0.27 + 0.46 * (k % 2)), inner.size.y * (0.2 + 0.3 * (k / 2)))
				ci.draw_circle(p, inner.size.x * 0.12, Color(0.97, 0.97, 0.95))
				ci.draw_arc(p, inner.size.x * 0.12, 0.0, TAU, 14, Color(0.5, 0.52, 0.58), 1.5)
		"perv":  # minigrip-pussi, sinertävät kiteet
			ci.draw_rect(inner, Color(0.88, 0.93, 0.95, 0.9))
			ci.draw_rect(inner, Color(0.45, 0.55, 0.6), false, 2.0)
			ci.draw_line(inner.position + Vector2(0, inner.size.y * 0.16), inner.position + Vector2(inner.size.x, inner.size.y * 0.16), Color(0.8, 0.2, 0.25), 2.0)
			for k in 5:
				var q := c + Vector2((k - 2) * inner.size.x * 0.17, inner.size.y * (0.18 if k % 2 == 0 else 0.02))
				ci.draw_colored_polygon(PackedVector2Array([q + Vector2(0, -7), q + Vector2(6, 0), q + Vector2(0, 8), q + Vector2(-5, 1)]), Color(0.65, 0.9, 1.0))
		"burana":  # sinivalkoinen pakkaus
			ci.draw_rect(inner, Color(0.92, 0.94, 0.98))
			ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.4)), Color(0.15, 0.35, 0.75))
			ci.draw_rect(inner, Color(0.3, 0.35, 0.5), false, 2.0)
		"panadol":  # valkopunainen pakkaus
			ci.draw_rect(inner, Color(0.96, 0.96, 0.95))
			ci.draw_rect(Rect2(inner.position + Vector2(0, inner.size.y * 0.55), Vector2(inner.size.x, inner.size.y * 0.25)), Color(0.8, 0.15, 0.15))
			ci.draw_rect(inner, Color(0.45, 0.35, 0.35), false, 2.0)
		"sokeri":  # sokeripussi
			ci.draw_rect(inner, Color(0.97, 0.95, 0.88))
			ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.15, inner.size.y * 0.3), Vector2(inner.size.x * 0.7, inner.size.y * 0.3)), Color(0.9, 0.35, 0.3))
			ci.draw_rect(inner, Color(0.55, 0.5, 0.4), false, 2.0)
		"turbohiiva":  # hiivapussi
			ci.draw_rect(inner, Color(0.85, 0.7, 0.35))
			ci.draw_rect(Rect2(inner.position + Vector2(inner.size.x * 0.15, inner.size.y * 0.3), Vector2(inner.size.x * 0.7, inner.size.y * 0.3)), Color(0.2, 0.3, 0.2))
			ci.draw_rect(inner, Color(0.45, 0.35, 0.15), false, 2.0)
		_:  # muu lääkepakkaus
			ci.draw_rect(inner, Color(0.85, 0.88, 0.85))
			ci.draw_rect(Rect2(inner.position, Vector2(inner.size.x, inner.size.y * 0.3)), Color(0.2, 0.55, 0.38))
			ci.draw_rect(inner, Color(0.35, 0.4, 0.38), false, 2.0)
	var t := tier(key)
	if t > 0:
		var pct := "%d %%" % roundi(100.0 * pow(0.5, t))
		var fs := maxi(11, int(r.size.x * 0.2))
		ci.draw_string(font, r.position + Vector2(3, r.size.y - 4), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.15, 0.05, 0.05))
		ci.draw_string(font, r.position + Vector2(2, r.size.y - 5), pct, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.85, 0.3))
