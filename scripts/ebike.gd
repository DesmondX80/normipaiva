extends RefCounted
## Saloislainen sähköpyörä (#107): tavallinen pyörä muutetaan sähköpyöräksi osilla sieltä täältä ja kasataan
## autotallin työpöydällä (ebike_game.gd) ruuveilla, jeesusteipillä, nippusiteillä tai rautalangalla.
## Osat: napamoottori (Seuranmäen kirppiksen huutokauppa), akku (Pekan Makitan akut sieniä vastaan), ohjain ja
## kaasukahva (Tokolan vanha varasto) ja johdot (Arto kaljaa vastaan). Tarvikkeet K-Marketin rautahyllystä ja
## autotallin työkalutaululta. Kiinnitystapa ratkaisee kestävyyden: ruuvattu pysyy, teipattu irtoaa kuopissa,
## nippuside harvemmin ja rautalanka pitää mutta kolisee (teinit kiinnostuvat). Johdot ilman sähköteippiä
## oikosulkevat vedessä. Akku tyhjenee ajossa ja latautuu kotona (main.gd).

const PARTS := {
	"moottori": {"name": "Napamoottori", "low": "napamoottori", "where": "Seuranmäen kirppiksen huutokaupasta"},
	"akku": {"name": "Makitan akut", "low": "akku", "where": "Pekalta sieniä vastaan"},
	"ohjain": {"name": "Ohjain ja kaasukahva", "low": "ohjain ja kaasukahva", "where": "Tokolan vanhasta varastosta"},
	"johdot": {"name": "Johdot ja liittimet", "low": "johdot", "where": "Artolta kaljaa vastaan"},
}
## Liitokset kasausjärjestyksessä: mikä osa minne.
const JOINTS := ["moottori", "akku", "ohjain", "kaasu", "johdot"]
const JOINT_NAMES := {
	"moottori": "napamoottori takanapaan", "akku": "akku tarakalle", "ohjain": "ohjain runkoon",
	"kaasu": "kaasukahva tankoon", "johdot": "johdot ja liitokset",
}
const JOINT_SHORT := {"moottori": "napamoottori", "akku": "akku", "ohjain": "ohjain", "kaasu": "kaasukahva", "johdot": "johdot"}
## Kiinnitys -> nimi ja tarvike (supplies-avain).
const FASTENERS := {
	"ruuvi": {"name": "ruuvit", "supply": "ruuvit"},
	"teippi": {"name": "jeesusteippi", "supply": "teippi"},
	"nippu": {"name": "nippusiteet", "supply": "nippu"},
	"rautalanka": {"name": "rautalanka", "supply": "rautalanka"},
	"sahkoteippi": {"name": "sähköteippi", "supply": "sahkoteippi"},
}
## Johdot eristetään teipillä, muut osat kiinnitetään millä tahansa muulla.
const JOINT_FASTENERS := ["ruuvi", "teippi", "nippu", "rautalanka"]
const WIRE_FASTENERS := ["sahkoteippi", "teippi"]
## Tarvikkeet ja niiden nimet repussa (yksi käyttökerta = yksi liitos).
const SUPPLIES := {
	"ruuvit": "Ruuveja ja muttereita", "teippi": "Jeesusteippi", "nippu": "Nippusiteitä", "sahkoteippi": "Sähköteippi",
	"rautalanka": "Rautalankaa",
}
## Irtoamisherkkyys kiinnityksittäin (teippi = 1).
const LOOSEN := {"teippi": 1.0, "nippu": 0.35}
## Akku: täydellä n. 8 minuuttia täysillä ajoa, spurtti kuluttaa tuplasti. Tallissa latautuu 10 minuutissa.
const DRAIN_S := 480.0
const GARAGE_CHARGE_S := 600.0

var started := false  # idea syntynyt (työpöytä tai napamoottorin osto)
var parts := {}  # osa -> true
var supplies := {"ruuvit": 0, "teippi": 0, "nippu": 0, "sahkoteippi": 0, "rautalanka": 0}
var board_taken := false  # autotallin työkalutaulun puolikas teippirulla ja ruuvipurkki otettu
var joints := {}  # liitos -> kiinnitys
var loose := {}  # liitos -> true (irronnut ajossa)
var shorted := false
var battery := 1.0
var _root_hits := 0
var _rattle_t := 0.0


func built() -> bool:
	return joints.size() == JOINTS.size()


func has_all_parts() -> bool:
	for k in PARTS:
		if not parts.has(k):
			return false
	return true


func missing_parts() -> Array:
	return PARTS.keys().filter(func(k): return not parts.has(k))


## Avustus toimii: kaikki kiinni, ei oikosulkua ja akussa virtaa.
func working() -> bool:
	return built() and loose.is_empty() and not shorted and battery > 0.0


## Liitokset, jotka pitää tehdä (uudelleen) työpöydällä: kasaamattomat, irronneet ja oikosulussa johdot.
func todo() -> Array:
	var out: Array = []
	for j in JOINTS:
		if not joints.has(j) or loose.has(j) or (j == "johdot" and shorted):
			out.append(j)
	return out


func fasteners_for(joint: String) -> Array:
	return WIRE_FASTENERS if joint == "johdot" else JOINT_FASTENERS


func fasten(joint: String, kind: String) -> void:
	joints[joint] = kind
	loose.erase(joint)
	if joint == "johdot":
		shorted = false


## Tienvarsikorjaus jeesusteipillä: irronnut osa teipataan takaisin (kiinnitys muuttuu teipiksi).
func tape_loose() -> String:
	if loose.is_empty() or supplies.teippi <= 0:
		return ""
	var j: String = loose.keys()[0]
	supplies.teippi -= 1
	fasten(j, "teippi")
	return j


## Ajon tikki (main.gd, pelaaja pyörän selässä): avustus, akun kulutus, irtoaminen ja oikosulku.
## Palauttaa viestin, jos jotain sattui ("" = ei mitään).
func ride_tick(bike: Node3D, delta: float) -> String:
	if not built():
		bike.assist = 0.0
		bike.heavy = false
		bike.set_ebike({})
		return ""
	var speed: float = absf(bike.speed)
	var k := clampf(speed / bike.MAX_SPEED, 0.0, 1.0)
	var pedal: bool = bike.controls_enabled and Input.is_action_pressed("forward")
	bike.assist = 1.0 if working() else 0.0
	bike.heavy = battery <= 0.0 or loose.has("akku")
	if bike.assist > 0.0 and pedal and speed > 0.5:
		battery = maxf(0.0, battery - delta * k * (2.0 if bike.sprinting else 1.0) / DRAIN_S)
		if battery <= 0.0:
			return "Akku loppu! Raskas pyörä, poljetaan omin voimin. Lataus kotona yön yli."
	var msg := ""
	var bump: float = bike.terrain_bump()
	var hits: int = bike.root_hits
	var new_hits := hits - _root_hits
	_root_hits = hits
	for j in JOINTS:
		var kind: String = joints.get(j, "")
		if loose.has(j) or not LOOSEN.has(kind):
			continue
		# Kuopat ja metsä irrottavat teippiä, kova vauhti asfaltillakin vähän. Juurakko voi irrottaa kerralla.
		var rate: float = LOOSEN[kind] * (bump * 0.06 + maxf(0.0, k - 0.85) * 0.02) * k
		var hit: bool = new_hits > 0 and randf() < 0.2 * LOOSEN[kind]
		if hit or randf() < rate * delta:
			loose[j] = true
			msg = _loose_text(j)
			break
	if msg == "" and joints.get("johdot", "") == "teippi" and not shorted and speed > 0.5 \
			and bike.surface in ["water", "bog"]:
		shorted = true
		msg = "PSSST! Johdot kastuivat ja oikosulku! Jeesusteippi ei eristä. Sähköteippiä ja korjaus autotallissa."
	if "rautalanka" in joints.values() and speed > 2.0:
		_rattle_t -= delta * (1.0 + bump * 20.0)
		if _rattle_t <= 0.0:
			_rattle_t = randf_range(0.6, 1.6)
			Sfx.play("rattle", -12.0, randf_range(1.2, 1.5))  # rautalanka kolisee
	bike.set_ebike({"joints": joints, "loose": loose})
	return msg


func _loose_text(j: String) -> String:
	match j:
		"akku":
			return "KOLKS! Akku irtosi ja roikkuu tarakalla johtojen varassa. Avustus poikki!"
		"moottori":
			return "Napamoottori löystyi ja kolisee! Avustus poikki."
		"ohjain":
			return "Ohjain irtosi rungosta ja heiluu johtojen varassa. Avustus poikki!"
		"kaasu":
			return "Kaasukahva pyörii tangossa tyhjää. Avustus poikki!"
	return "Johdot irtosivat! Avustus poikki."


## Tallissa akku latautuu (main.gd kutsuu, kun pyörä on autotallissa).
func charge(delta: float) -> void:
	if built():
		battery = minf(1.0, battery + delta / GARAGE_CHARGE_S)


## Tehtävälista repun Tehtävät-lapulle: [teksti, valmis].
func tasks() -> Array:
	if not started:
		return []
	if built():
		var probs := PackedStringArray()
		for j in loose:
			probs.append("%s irti" % JOINT_SHORT[j])
		if shorted:
			probs.append("oikosulku")
		if probs.is_empty():
			return [["Sähköpyörä valmis (akku %d %%)" % roundi(battery * 100.0), true]]
		return [["Sähköpyörä: %s (teippaa tai korjaa tallissa)" % ", ".join(probs), false]]
	var out: Array = [["Sähköpyörä: osat kasaan ja kasaus autotallin työpöydällä", false]]
	for k in PARTS:
		out.append(["  %s (%s)" % [PARTS[k].name, PARTS[k].where], parts.has(k)])
	return out


func save_to(cfg: ConfigFile) -> void:
	cfg.set_value("sahkopyora", "aloitettu", started)
	cfg.set_value("sahkopyora", "osat", parts)
	cfg.set_value("sahkopyora", "tarvikkeet", supplies)
	cfg.set_value("sahkopyora", "taulu", board_taken)
	cfg.set_value("sahkopyora", "liitokset", joints)
	cfg.set_value("sahkopyora", "irti", loose)
	cfg.set_value("sahkopyora", "oikosulku", shorted)
	cfg.set_value("sahkopyora", "akku", battery)


func load_from(cfg: ConfigFile) -> void:
	started = cfg.get_value("sahkopyora", "aloitettu", false)
	parts = cfg.get_value("sahkopyora", "osat", {})
	var s: Dictionary = cfg.get_value("sahkopyora", "tarvikkeet", {})
	for k in supplies:
		supplies[k] = int(s.get(k, 0))
	board_taken = cfg.get_value("sahkopyora", "taulu", false)
	joints = cfg.get_value("sahkopyora", "liitokset", {})
	loose = cfg.get_value("sahkopyora", "irti", {})
	shorted = cfg.get_value("sahkopyora", "oikosulku", false)
	battery = cfg.get_value("sahkopyora", "akku", 1.0)
