extends RefCounted
## Ruumiinosien elastisuus: yksi taulukko (PARTS) kontaktiratkaisijalle, hahmon verkolle ja testeille. Pehmeä osa (vatsa,
## rinnat, pakarat, reidet) painuu kiinteää pintaa vasten korkeintaan rajansa verran; luinen osa (kallo, sääri, polvi,
## kyynärpää, ranne, kämmen) ei painu lainkaan. Raja lasketaan kerran vaatemeshin rakennuksessa (CUSTOM0.w), ja
## varjostin (character.gdshader, vertex) painaa verteksit pinnalle: siirto = min(tunkeuma, raja) pinnan normaalia
## pitkin. `press` on varjostimen peili GDScriptinä (Pose.limb_points, testit): pidä kaavat samoina.
## Mitat ovat hahmon lepoasennon verkon yksiköitä (metrejä 1,8 m hahmolle). Ei riippuvuuksia (ei lataa character.gd:tä).

## Painumaraja osittain (m). 0 = luinen, ei painu. Skaalat (vatsa: belly, rinta: bust, reisi/pakara: bulk): part_limit.
const PARTS := {
	"kallo": 0.0, "saari": 0.0, "polvi": 0.0, "kyynarpaa": 0.0, "ranne": 0.0, "kammen": 0.0, "jalkatera": 0.0,
	"selka": 0.012, "kylki": 0.01, "olkavarsi": 0.01, "kyynarvarsi": 0.008, "pohje": 0.012, "reisi_etu": 0.01,
	"reisi": 0.025, "pakara": 0.03, "vatsa": 0.035, "rinta": 0.025,
}
## Hyllyntä liikkeessä: oma vaimennettu jousi jokaiselle osalle (Character._update_jiggle), ei hiusten jousta. Jousta ajaa
## luun pisteen (center lepoasennossa, verkon avaruus) kiihtyvyys; side = vaakakiihtyvyyden osuus (pääosin pystysuunta),
## max = suurin siirto (m) kertoimella 1 (jiggle_gain). Esikuva: rinnat 3–4 Hz, pieni vaimennus, viive (juoksussa ~50 mm
## isoilla); vatsa 4–6 Hz; pakarat ja reidet jäykkä pehmytkudos 10–15 Hz, lyhyt tärähdys askeleen iskusta.
const JIGGLE := {
	"rinta": {"bone": "spine_03", "center": Vector3(0.0, 1.29, 0.1), "hz": 3.5, "zeta": 0.12, "side": 0.35, "max": 0.03},
	"vatsa": {"bone": "spine_01", "center": Vector3(0.0, 1.1, 0.08), "hz": 5.0, "zeta": 0.2, "side": 0.5, "max": 0.025},
	"pakara": {"bone": "pelvis", "center": Vector3(0.0, 0.9, -0.08), "hz": 12.0, "zeta": 0.25, "side": 0.15, "max": 0.02},
}
const MAX_LIMIT := 0.05  # kovin raja kaikille osille (rinta Sinikalla)
const SPREAD := 1.0  # painuman leviäminen sivuille (osuus painumasta): pullistuma, tilavuus säilyy suunnilleen
## Pullistuma: litistyvän kohdan lähellä (pinnan yläpuolella HALO_H asti) liha työntyy sivulle HALO x raja.
const HALO := 0.9
const HALO_H := 0.08
const KNEE_R := 0.06
const ELBOW_R := 0.05
const WRIST_R := 0.04


## Osan painumaraja hahmon vartalolle (shape: belly, bulk, bust kuten Character.setup).
static func part_limit(part: String, shape: Dictionary) -> float:
	var base: float = PARTS.get(part, 0.0)
	var bulk: float = shape.get("bulk", 0.0)
	match part:
		"vatsa":
			return base * lerpf(0.5, 1.333, clampf(shape.get("belly", 0.0), 0.0, 1.0)) * (1.0 + 0.3 * bulk)
		"rinta":
			return minf(base * (1.0 + 0.6 * float(shape.get("bust", 0.0))), MAX_LIMIT)
		"reisi", "pakara", "reisi_etu":
			return base * (1.0 + 0.2 * bulk)
	return base


## Hyllynnän voimakkuus (0..1,25) vartalosta: rinta bust, vatsa belly (ja tukeva bulk), pakara curves, bulk ja belly.
static func jiggle_gain(part: String, shape: Dictionary) -> float:
	var bulk := maxf(float(shape.get("bulk", 0.0)), 0.0)
	match part:
		"rinta":
			return clampf(0.25 + 0.5 * float(shape.get("bust", 0.0)), 0.0, 1.25)
		"vatsa":
			return clampf(float(shape.get("belly", 0.0)) + 0.4 * bulk, 0.0, 1.2)
		"pakara":
			return clampf(0.4 + 0.3 * float(shape.get("curves", 0.0)) + 0.3 * bulk + 0.3 * float(shape.get("belly", 0.0)), 0.0, 1.2)
	return 0.0


## Verteksin hyllyntäpainot lepoasennossa (kasvot +Z): x = rinta, y = vatsa, z = pakara ja reiden yläosa (0..1). Vain
## paikasta (ei normaalista), jotta saumojen kaksoisverteksit saavat saman painon eikä pinta repeä. bust_w kuten limit.
static func jiggle_weights(p: Vector3, bust_w: float) -> Vector3:
	var ax := absf(p.x)
	var wr := clampf(bust_w, 0.0, 1.0) * lerpf(1.0, 0.5, smoothstep(1.28, 1.4, p.y))  # yläreuna kiinni rintakehässä
	var c := Vector3(0.0, 1.16, -0.02)  # vatsa: sama ellipsoidi kuin limit
	var q := (p - c) / Vector3(0.16, 0.2, 0.13)
	var wv := (1.0 - smoothstep(0.9, 1.3, q.length())) * smoothstep(-0.7, 0.1, q.z / maxf(q.length(), 0.001)) \
		* (1.0 - smoothstep(0.24, 0.32, ax)) * (1.0 - wr)
	var glute := (1.0 - smoothstep(-0.1, -0.03, p.z)) * exp(-pow((p.y - 0.88) / 0.11, 2.0)) * (1.0 - smoothstep(0.2, 0.26, ax))
	var thigh := smoothstep(0.5, 0.62, p.y) * (1.0 - smoothstep(0.8, 0.9, p.y)) * smoothstep(0.02, 0.06, ax)
	return Vector3(wr, wv, maxf(glute, 0.5 * thigh))


## Ratkaisijan suunniteltu upotus osalle: 0,8 x raja. Syvin kohta upotetaan lähes rajaansa, jolloin litistyvä alue (kaikki pisteet upotuksen sisällä) on laaja ja painuma näkyy; jää kuitenkin rajan sisään.
static func sink(part: String, shape: Dictionary) -> float:
	return 0.8 * part_limit(part, shape)


## Verteksin painumaraja lepoasennossa (kasvot +Z, T-asento). bone = pääluu, p ja n = lepoasennon paikka ja normaali,
## joints = luun nimi -> lepopaikka verkon avaruudessa (skinin bind-asennoista), bust_w = rintapainon (0..1)
## character.gd:n _bust:sta. Osien rajat sulautetaan pehmeästi, ettei painumaan tule porrasta.
static func limit(bone: String, p: Vector3, n: Vector3, shape: Dictionary, joints: Dictionary, bust_w := 0.0) -> float:
	var back := n.z < -0.3
	var front := n.z > 0.3
	var lim := 0.0
	var sfx := bone.right(2) if bone.ends_with("_l") or bone.ends_with("_r") else ""  # "_l" tai "_r"
	var stem := bone.trim_suffix(sfx)
	if stem.begins_with("spine") or stem == "pelvis":
		lim = part_limit("selka", shape) if back else part_limit("kylki", shape)
		if stem == "pelvis" and not front:  # pakara, lantion sivut ja alapinta (haarojen alus) painuvat
			lim = part_limit("pakara", shape)
		if stem != "pelvis":
			# Vatsa: sama ellipsoidi kuin Character._shape_offset (rintakehän alapuoli, edessä).
			var c := Vector3(0.0, 1.16, -0.02)
			var q := (p - c) / Vector3(0.16, 0.2, 0.13)
			var wv := (1.0 - smoothstep(0.9, 1.3, q.length())) * smoothstep(-0.7, 0.1, q.z / maxf(q.length(), 0.001)) \
				* (1.0 - smoothstep(0.24, 0.32, absf(p.x)))
			lim = lerpf(lim, part_limit("vatsa", shape), wv)
			lim = lerpf(lim, part_limit("rinta", shape), clampf(bust_w, 0.0, 1.0))
	elif stem == "thigh":
		lim = part_limit("reisi_etu", shape) if front else part_limit("reisi", shape)
		if not back and joints.has("calf" + sfx):  # polvi (takapinta pitää reiden rajan)
			lim = _near(lim, p, joints["calf" + sfx], KNEE_R, part_limit("polvi", shape))
	elif stem == "calf":
		lim = part_limit("saari", shape) if front else part_limit("pohje", shape)
		if not back and joints.has("calf" + sfx):  # polvi (takapinta pitää pohkeen rajan)
			lim = _near(lim, p, joints["calf" + sfx], KNEE_R, part_limit("polvi", shape))
	elif stem == "upperarm":
		lim = part_limit("olkavarsi", shape)
		if joints.has("lowerarm" + sfx):
			lim = _near(lim, p, joints["lowerarm" + sfx], ELBOW_R, part_limit("kyynarpaa", shape))
	elif stem == "lowerarm":
		lim = part_limit("kyynarvarsi", shape)
		if joints.has("lowerarm" + sfx):
			lim = _near(lim, p, joints["lowerarm" + sfx], ELBOW_R, part_limit("kyynarpaa", shape))
		if joints.has("hand" + sfx):
			lim = _near(lim, p, joints["hand" + sfx], WRIST_R, part_limit("ranne", shape))
	elif stem == "hand" or stem.begins_with("thumb") or stem.begins_with("index") or stem.begins_with("middle") \
			or stem.begins_with("ring") or stem.begins_with("pinky"):
		lim = part_limit("kammen", shape)
	elif stem == "foot" or stem == "ball" or stem.begins_with("toe"):
		lim = part_limit("jalkatera", shape)
	else:
		lim = part_limit("kallo", shape)  # pää, kaula, hartiat: luinen
	return minf(lim, MAX_LIMIT)


## Rajan siirtymä kohti arvoa v, kun p on lähellä nivelpistettä j (smoothstep reunalla, 1 -> 0 pehmeä ulkopuoli).
static func _near(lim: float, p: Vector3, j: Vector3, r: float, v: float) -> float:
	return lerpf(lim, v, 1.0 - smoothstep(r * 0.6, r, p.distance_to(j)))


## Painuma kontaktilaatikoilla boxes ([[Transform3D verkko -> laatikko, puolikoko Vector3], ...], aktiivinen pinta
## laatikon +Y). Palauttaa verteksin p uuden paikan verkon avaruudessa. Peilaa varjostimen vertex()-silmukan.
static func press(p: Vector3, nrm: Vector3, lim: float, boxes: Array, spread := SPREAD, halo := HALO, radial := 0.0, origin := Vector3.ZERO) -> Vector3:
	var out := p
	if lim <= 0.0:
		return out
	for b in boxes:
		out += displace(b[0], b[1], out, lim, nrm, spread, halo, radial, origin)  # laatikko kerrallaan (kuten varjostin)
	return out


## Yhden laatikon siirtymä (verkon avaruudessa); sama kuin press_disp varjostimessa. radial 1 (hiukset): leviäminen pinnan suuntaisesti
## pois pisteestä origin (verkon avaruus, pään keskus), 0 (vartalo): laatikon x-akselin suuntaan. nrm (verteksin normaali) on varattu, ei käytössä:
## hiuskortit ovat kaksipuolisia, joten normaalin etumerkistä leviäminen repeäisi.
static func displace(xf: Transform3D, h: Vector3, p: Vector3, lim: float, _nrm := Vector3.ZERO, spread := SPREAD, halo := HALO,
		radial := 0.0, origin := Vector3.ZERO) -> Vector3:
	var q := xf * p
	var pen := h.y - q.y
	var w := (1.0 - smoothstep(h.x, h.x + 0.02, absf(q.x))) * (1.0 - smoothstep(h.z, h.z + 0.02, absf(q.z))) \
		* (1.0 if q.y >= -h.y else 0.0) * deep_fade(pen, lim)
	var d := clampf(pen, 0.0, lim) * w
	var t := Vector3(q.x, 0.0, q.z)
	var tl := t.length()
	var sdir := Vector3(signf(q.x), 0.0, 0.0)
	var sfac := smoothstep(0.0, 0.02, absf(q.x))
	if radial > 0.0:
		var qo := xf * origin
		var dr := Vector3(q.x - qo.x, 0.0, q.z - qo.z)
		var dl := dr.length()
		dr = dr / dl if dl > 0.00001 else Vector3.ZERO
		sdir = sdir.lerp(dr, radial)
		sfac = lerpf(sfac, smoothstep(0.0, 0.02, dl), radial)
	var sp := sdir * sfac * (spread * d + halo * lim * w * (1.0 - smoothstep(0.0, HALO_H, maxf(-pen, 0.0)))) if tl > 0.0 or radial > 0.0 else Vector3.ZERO
	return xf.basis.transposed() * (Vector3(0.0, d, 0.0) + sp)


## Painuman syvyys (pinnan normaalia pitkin) verteksille p kaikista laatikoista: suurin d, testeille (K10, K13).
static func depth(p: Vector3, lim: float, boxes: Array) -> float:
	var best := 0.0
	for b in boxes:
		var q: Vector3 = (b[0] as Transform3D) * p
		var h: Vector3 = b[1]
		if absf(q.x) < h.x and absf(q.z) < h.z and q.y >= -h.y:
			best = maxf(best, (h.y - q.y) * deep_fade(h.y - q.y, lim))
	return best


## Liian syvällä oleva verteksi (pen > 1,5 x raja + 1 cm) ei ole pinnan alla vaan kappaleen reunan vieressä (esim. säären
## sivu istuimen reunalla): painuma häipyy 1 cm:n matkalla, ettei reunaa vasten ole portaita. Peilaa varjostimen press_disp.
static func deep_fade(pen: float, lim: float) -> float:
	return 1.0 - smoothstep(lim * 1.5 + 0.01, lim * 1.5 + 0.02, pen)


## Jousen askel (semi-implisiittinen Euler): x'' = -k x - c x' - a. Palauttaa [x, v]. Heilahdus (hiukset, hyllyntä).
static func spring_step(x: Vector3, v: Vector3, a: Vector3, k: float, c: float, dt: float) -> Array:
	v += (-k * x - c * v - a) * dt
	x += v * dt
	return [x, v]
