extends RefCounted
## Oma mopo (#155): Sepon varastomyynnin pressun alla ollut 70-luvun mopo. Seppo myy sen vasta, kun pelaaja on
## ansainnut luottamuksen (ostoksia, marjoja, Nokia tai Kekkosen rintamerkki takaisin), ja hinta riippuu Sepon
## mielialasta. Mopo tulee talliin romuna: ketju ja ratas Huhtalan romuista, sytytys Autosähkö-Simolta, satula
## Sepon varastosta ja ajovalo Tokolan Aarolta (vanhan sähkömopon osat). Kokoaminen tallissa, sitten kaasarin
## säätö (carb_game.gd) ja potkukäynnistys (mopo_kick_game.gd). Ajossa (main.gd) mopo on pelaajan pyöräsolmu
## mopotilassa (player_bike.gd set_mopo): bensa kuluu, tyhjällä tankilla mopoa taluttaa. Seppo poisti rajoittimen
## vuonna 1979: ilman sitä mopo kulkee lujaa, mutta katsastus hylkää. Katsastukseen tarvitaan myös ajovalo.

const TRUST_NEED := 5
const PRICE := 45.0
const KEKKOS_ALE := 0.5  # Kekkosen rintamerkki palautettu: Seppo myy puoleen hintaan
const SATULA_HINTA := 6.0
const KETJU_HINTA := 4.0
const SYTYTYS_HINTA := 8.0
const BENSA_L := 1.6  # €/l
const TANK_L := 4.0
const DRAIN_S := 540.0  # täysi tankki: 9 minuuttia kaasu pohjassa
const MAX_FREE := 21.0  # ilman rajoitinta (m/s)
const MAX_LIMITED := 15.0  # rajoittimella: juuri ja juuri pyörää lujempaa
const PUSH_SPEED := 2.2  # tyhjä tankki: mopoa taluttaa

const PARTS := {
	"ketju": {"name": "Mopon ketju ja ratas", "low": "ketju ja ratas", "where": "Huhtalan romuista"},
	"sytytys": {"name": "Sytytyspuola ja tulppa", "low": "sytytys", "where": "Autosähkö-Simolta"},
	"satula": {"name": "Mopon satula", "low": "satula", "where": "Sepon varastosta"},
	"valo": {"name": "Ajovalo ja vilkut", "low": "ajovalo", "where": "Tokolan Aarolta (vanhan sähkömopon osat)"},
}
## Ilman näitä mopo ei kulje. Ajovalo tarvitaan vasta katsastukseen.
const RUN_PARTS := ["ketju", "sytytys", "satula"]

var trust := 0
var owned := false
var parts := {}  # osa -> true (hankittu)
var assembled := false  # ajoon tarvittavat osat paikallaan
var valo_on := false  # ajovalo asennettu
var carb_ok := false
var running := false  # potkaistu käyntiin: mopo on valmis
var rajoitin_have := false  # Seppo antoi rajoittimen laatikossa
var rajoitin := false  # rajoitin asennettu
var katsastettu := false
var kanisteri := false  # bensakanisteri tallissa (SEO)
var fuel := 0.0  # 0..1
var riding := false  # pelaaja liikkuu mopolla (pyörä jää talliin)
var rossi_best := 0.0
var seppo_kekkonen := false  # Kekkosen rintamerkki palautettu Sepolle
var _dry_said := false


func missing_run() -> Array:
	return RUN_PARTS.filter(func(k): return not parts.has(k))


func max_speed() -> float:
	return MAX_LIMITED if rajoitin else MAX_FREE


func price(mood_mult: float) -> float:
	return snappedf(PRICE * mood_mult * (KEKKOS_ALE if seppo_kekkonen else 1.0), 0.5)


## Katsastusmiehen hylkäyslista.
func faults() -> Array:
	var out: Array = []
	if not valo_on:
		out.append("ajovalo puuttuu, pimeellä ajat korvakuulolla")
	if not rajoitin:
		out.append("rajoitin puuttuu, tämähän kulkee kuin kelkka")
	if fuel <= 0.0:
		out.append("tankki tyhjä, eikä tätä kateta työntämällä")
	return out


## Ajon tikki (main.gd, pelaaja mopon selässä): bensa kuluu kaasulla, tyhjällä tankilla mopoa taluttaa.
## Palauttaa viestin, jos jotain sattui ("" = ei mitään).
func ride_tick(bike: Node3D, delta: float) -> String:
	bike.mopo_max = max_speed()
	var throttle: bool = bike.controls_enabled and Input.is_action_pressed("forward")
	if throttle and fuel > 0.0:
		var k := clampf(absf(bike.speed) / max_speed(), 0.2, 1.0)
		fuel = maxf(0.0, fuel - delta * k / DRAIN_S)
	bike.mopo_dry = fuel <= 0.0
	if fuel <= 0.0 and not _dry_said:
		_dry_said = true
		return "Pöö... pöpö... pö. Bensa loppu! Mopoa taluttaa. Bensaa SEO:lta tai kanisterista tallissa."
	if fuel > 0.0:
		_dry_said = false
	return ""


## Tehtävälista repun Tehtävät-lapulle: [teksti, valmis].
func tasks() -> Array:
	if not owned:
		return []
	if running:
		var notes := PackedStringArray()
		if fuel <= 0.0:
			notes.append("tankki tyhjä")
		if not katsastettu:
			notes.append("katsastamatta")
		return [["Oma mopo valmis (bensaa %d %%%s)" % [roundi(fuel * 100.0), ", " + ", ".join(notes) if not notes.is_empty() else ""], true]]
	var out: Array = [["Oma mopo: osat kasaan ja kunnostus autotallissa", false]]
	for k in PARTS:
		out.append(["  %s (%s)" % [PARTS[k].name, PARTS[k].where], parts.has(k)])
	out.append(["  Kaasarin säätö tallissa", carb_ok])
	out.append(["  Bensaa (SEO:n kanisteri) ja potkukäynnistys", running])
	return out


func save_to(cfg: ConfigFile) -> void:
	for k in ["trust", "owned", "parts", "assembled", "valo_on", "carb_ok", "running", "rajoitin_have", "rajoitin", "katsastettu",
			"kanisteri", "fuel", "riding", "rossi_best", "seppo_kekkonen"]:
		cfg.set_value("oma_mopo", k, get(k))


func load_from(cfg: ConfigFile) -> void:
	for k in ["trust", "owned", "parts", "assembled", "valo_on", "carb_ok", "running", "rajoitin_have", "rajoitin", "katsastettu",
			"kanisteri", "fuel", "riding", "rossi_best", "seppo_kekkonen"]:
		set(k, cfg.get_value("oma_mopo", k, get(k)))
