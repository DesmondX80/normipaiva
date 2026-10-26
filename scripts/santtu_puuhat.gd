extends Node
## Santtu puuhastelee mökin pihalla: istuu kannolla kahvikupin kanssa, nousee välillä puuhapaikalle (hommien ja
## minipelien paikat) tekemään paikkaan liittyvää puuhaa ja palaa kannolle tai jatkaa seuraavaan paikkaan.
## Hommien katsominen (main.gd _santtu_watch) menee edelle: main.gd asettaa enabled = false, ja puuha keskeytyy.
## Santtu ei puuhaa paikassa, jossa pelaaja on (väistää), eikä tee tänään annettuja hommia itse (pending).
## mokki.gd:n lapsi; paikat mökin kehyksessä.

const B := preload("res://scripts/build.gd")
## Esineet hahmon kehyksessä (eivät käden luussa): onki osoittaa järvelle istuessa.
const BODY_PROPS := ["onki"]

## main.gd asettaa joka ruudulla: saako puuhata, pelaajan paikka mökin kehyksessä (INF = sisällä tai muualla)
## ja tänään tekemättä olevat Santun hommat.
var enabled := false
var player_local := Vector3.INF
var pending: Array = []

var mokki: Node3D
var _spots: Array = []
var _state := "home"  # home, go (kävelee paikalle), work (puuhaa), back (palaa kannolle)
var _t := 25.0  # home: aika seuraavaan puuhaan, work: aikaa jäljellä
var _spot := {}
var _step := 0
var _beat_t := 0.0
var _beat_back := -1.0
var _line_t := 0.0
var _work_t := 0.0
var _last_id := ""
var _hidden := false
var _ball: Node3D
var _woodpile: Node3D
var _woodpile_n := 0
var _fx: Array = []  # [node, ttl]


func _ready() -> void:
	_t = randf_range(20.0, 40.0)


# --- Puuhapaikat ----------------------------------------------------------------------------------

## Paikat (mökin kehys): at = seisomapaikka, look = katse, via = välipisteet (laiturille), anim = perusasento,
## beat = tahti (s), beat_anim = tahdissa toistettava liike, sound / fx = tahdin ääni ja efekti, prop = esine
## kädessä, task = Santun homma (ei puuhata, jos se on tänään pelaajan), use = pelaajan toimintopaikka [piste, säde].
func _build_spots() -> void:
	var M := mokki
	var chop: Vector3 = M.PUU_CHOP_LOCAL
	var saw: Vector3 = M.PUU_SAW_LOCAL
	var halko: Vector3 = M.HALKO_LOCAL
	var dock: Vector3 = M.DOCK_LOCAL
	var dock_in := [Vector3(dock.x - 1.8, 0, 28.0), Vector3(dock.x, 0, M.dock_body.position.z + 1.0)] if M.dock_body != null else []
	var dock_out := dock_in.duplicate()
	dock_out.reverse()
	var fix_z: float = M.dock_body.position.z + roundf((M.DOCK_FIX_LOCAL.z - M.dock_body.position.z) / 0.55) * 0.55 \
		if M.dock_body != null else M.DOCK_FIX_LOCAL.z
	var pump: Vector3 = M.pump_local()
	var lawn: Rect2 = M.LAWN_RECT
	var board: Vector3 = M.dart_board_center()
	var smoker := Vector3(-12.6, 0, 17.3)
	_spots = [
		{"id": "halko", "task": "puut", "use": [chop, 1.4], "weight": 1.2,
			"steps": [{"at": chop + Vector3(0, 0, -0.95), "look": chop, "anim": "Idle", "beat_anim": "Sword_Attack", "beat": 2.4,
				"sound": "axe", "fx": "halot", "prop": "kirves"}],
			"lines": ["Pari pölkkyä vielä, ni riittää saunaan.", "Kuivaa koivua. Halkeaa ku ajatus.", "Tällä kirveellä halkasin jo isän kanssa.",
				"Tasainen pää alas, vino ylös. Sitä ei unohda."]},
		{"id": "saha", "task": "puut", "use": [saw, 1.6],
			"steps": [{"at": saw + Vector3(-0.62, 0, 0.74), "look": saw + Vector3(0, 0, 0.7), "anim": "Idle", "beat_anim": "Push", "beat": 1.3,
				"sound": "saw", "fx": "puru", "prop": "saha"}],
			"lines": ["Pitkät vedot, ei hätäilyä.", "Saha on terävä. Mää teroitin sen ite.", "Reilu kolmekymmentä senttiä on hyvä pölkky."]},
		{"id": "syli", "use": [halko, 1.4], "weight": 0.8,
			"steps": [{"at": halko + Vector3(0, 0, -0.3), "look": halko + Vector3(0, 0, 1.0), "anim": "Idle", "once": "PickUp_Table", "dur": 2.4,
				"sound": "cloth", "prop_after": "halot"},
				{"at": Vector3(5.2, 0, 16.9), "look": Vector3(5.2, 0, 18.0), "anim": "Idle", "once": "PickUp_Table", "dur": 2.4,
				"sound": "cloth", "fx": "pino", "prop": "halot", "prop_after": ""}],
			"lines": ["Syli halkoja saunan seinälle. Talvella kiittää.", "Puita ei oo koskaan liikaa."]},
		{"id": "sauna", "task": "savusauna", "use": [M.SAUNA_LOCAL, 2.2],
			"steps": [{"at": Vector3(5.1, 0, 21.45), "look": Vector3(5.1, 0, 20.4), "anim": "Idle", "beat_anim": "Interact", "beat": 3.5,
				"sound": "water", "fx": "hoyry", "prop": "kiulu"}],
			"lines": ["Kiuas tarvii vähän vettä, ettei kivet halkea.", "Savusauna on mökin sydän.", "Tuo savun haju. Ei sitä voita mikään."]},
		{"id": "palju", "task": "palju", "use": [M.TUB_LOCAL, 1.7], "cond": "palju",
			"steps": [{"at": M.TUB_LOCAL + Vector3(1.35, 0, -0.5), "look": M.TUB_LOCAL, "anim": "Crouch_Idle", "beat": 6.0,
				"sound": "water"}],
			"lines": ["Vielä kylmää. Illaksi lämpiää.", "Vesi on kirkasta, järvivettä.", "Paljussa tähtiä katellessa, siinä on elämä."]},
		{"id": "savustin", "task": "savustus", "use": [M.KITCHEN_LOCAL, 1.6],
			"steps": [{"at": M.KITCHEN_LOCAL, "look": smoker, "anim": "Idle", "beat_anim": "Interact", "beat": 4.0,
				"sound": "door_close", "fx": "savu"}],
			"lines": ["Savustin on mun lempilapsi.", "Kahdeksankymmentä–sataankakskymmentä astetta, muista.",
				"Lepällä ja koivulla tulee parhaat maut."]},
		{"id": "tikka", "use": [M.DART_LOCAL, 1.8],
			"steps": [{"at": M.DART_LOCAL, "look": board, "anim": "Idle", "beat_anim": "Punch_Jab", "beat": 2.1,
				"sound": "whoosh", "fx": "tikka", "prop": "tikat"}],
			"lines": ["Melkein! Kakskymppi on tuolla ylhäällä.", "Harjottelen, ettet sää voita mua.", "Bullseye! No ei ihan.",
				"Tikka on keskittymislaji. Ja kaljalaji."]},
		{"id": "onki", "use": [dock, 2.2], "weight": 1.2,
			"steps": [{"via": dock_in, "at": dock + Vector3(0.45, 0, -0.2), "look": dock + Vector3(0.45, 0, 6.0), "anim": "Sitting_Idle",
				"sit_deck": true, "beat": 7.0, "sound": "water", "fx": "kala", "prop": "onki"}],
			"back": dock_out,
			"lines": ["Tärppää, tärppää... ei tärppää.", "Ahvenet on syvällä tänään.", "Onkiminen on meditaatiota.",
				"Täällä on hauki, jonka nimi on Pertti. Ei oo vielä saatu."]},
		{"id": "naputus", "task": "laituri", "use": [Vector3(dock.x, 0, fix_z - 0.6), 1.4],
			"steps": [{"via": dock_in, "at": Vector3(dock.x - 0.4, 0, fix_z + 0.3), "look": Vector3(dock.x + 0.5, 0, fix_z + 0.3),
				"anim": "Fixing_Kneeling", "beat": 1.3, "sound": "punch", "prop": "vasara"}],
			"back": dock_out,
			"lines": ["Naula päähän, ei peukaloon.", "Laituri on mun ylpeys.", "Tää lauta narisee. Naputellaan."]},
		{"id": "pingis", "use": [M.PINGIS_LOCAL, 1.8],
			"steps": [{"at": M.PINGIS_LOCAL + Vector3(1.4, 0, 0.0), "look": M.PINGIS_LOCAL + Vector3(4.0, 0, 0.0), "anim": "Idle",
				"beat": 0.55, "sound": "punch", "fx": "pallo", "prop": "maila"}],
			"lines": ["Pompotellaan. Syöttö on mun vahvuus.", "Kakskymmentä kertaa putkeen! Ei kun yheksäntoista.",
				"Haasta mut, jos uskallat."]},
		{"id": "huussi", "task": "huussi", "use": [M.HUUSSI_HATCH_LOCAL, 1.3], "weight": 0.6,
			"steps": [{"at": M.HUUSSI_LOCAL + Vector3(0, 0, 1.3), "look": M.HUUSSI_LOCAL, "anim": "Idle", "huussi": true, "dur": 14.0}],
			"lines": ["Mökkiradio soi... no, joku soi.", "Lehti on vuodelta 2009. Hyvä lehti.", "Tää on mökin paras paikka miettiä."]},
		{"id": "komposti", "task": "huussi", "use": [M.KOMPOSTI_LOCAL, 1.9],
			"steps": [{"at": M.KOMPOSTI_LOCAL + Vector3(1.25, 0, 0), "look": M.KOMPOSTI_LOCAL, "anim": "Idle", "beat_anim": "Push", "beat": 1.8,
				"sound": "rattle", "fx": "multa", "prop": "talikko"}],
			"lines": ["Komposti tarvii happea.", "Tästä tulee ensi kesänä perunamaa.", "Mullan tuoksu. Ihanaa."]},
		{"id": "nurmi", "task": "nurmi", "use": [M.LAWN_MOWER_LOCAL, 1.6],
			"steps": [{"at": Vector3(lawn.position.x + lawn.size.x * randf_range(0.3, 0.7), 0, lawn.position.y + lawn.size.y * randf_range(0.3, 0.7)),
				"look": Vector3(lawn.get_center().x + 3.0, 0, lawn.get_center().y), "anim": "Fixing_Kneeling", "beat": 4.0, "sound": "cloth"}],
			"lines": ["Voikukat pois, ennen ku ne leviää.", "Rikkaruohot on sitkeitä ku Saloisten mummot.", "Nurmikko on mökin käyntikortti."]},
		{"id": "ranni", "task": "ranni", "use": [M.LADDER_LOCAL, 1.5],
			"steps": [{"at": M.LADDER_LOCAL + Vector3(0.9, 0, -0.7), "look": M.LADDER_LOCAL + Vector3(0.0, 0, 0.8), "anim": "Idle",
				"beat_anim": "Interact", "beat": 5.0, "sound": "rattle"}],
			"lines": ["Tukossa taas. Koivu pudottaa kaiken rännin.", "Tikkaat on tukevat. Melkein.", "Ensi viikolla putsaan. Tai sää."]},
		{"id": "mopo", "use": [M.MOPO_LOCAL, 1.8], "cond": "mopo",
			"steps": [{"at": M.MOPO_LOCAL + Vector3(0.95, 0, 0.3), "look": M.MOPO_LOCAL, "anim": "Fixing_Kneeling", "beat": 1.9,
				"sound": "rattle", "fx": "mopo", "prop": "jakoavain"}],
			"lines": ["Karburaattori kaipaa säätöä.", "Paapelin mopo on vanhempi ku sää.", "Kun se käy, se käy. Melkein aina."]},
		{"id": "pumppu", "task": "palju", "use": [pump, 1.5],
			"steps": [{"at": pump + Vector3(0.9, 0, 0.1), "look": pump, "anim": "Fixing_Kneeling", "beat": 4.5, "sound": "rattle_hard",
				"prop": "jakoavain"}],
			"lines": ["Pumppu on oikukas. Ku Pertti-hauki.", "Bensaa on, kipinää ei.", "Pärähti! No ei sittenkään."]},
		{"id": "lava", "use": [M.HUNT_LOCAL, 2.4], "weight": 0.3,
			"steps": [{"at": M.HUNT_LOCAL + Vector3(0.0, 0, 1.0), "look": Vector3(M.HUNT_GLADE.x, 0, M.HUNT_GLADE.y), "anim": "Idle",
				"beat": 6.0, "prop": "kiikari"}],
			"lines": ["Metso näky! Tai kanto.", "Riistapolulla on jäniksen jälkiä.", "Hirviä ei ammuta. Ei oo lupaa."]},
	]


## Esine Santun käteen (mokki.gd santtu_prop).
static func prop_model(kind: String) -> Node3D:
	var n := Node3D.new()
	var wood := Color(0.72, 0.55, 0.32)
	var steel := Color(0.35, 0.35, 0.37)
	match kind:
		"kirves":
			B.mesh(n, B.cyl(0.02, 0.025, 0.7, 8), Vector3(0, 0.25, 0), wood)
			B.mesh(n, B.boxm(Vector3(0.16, 0.1, 0.03)), Vector3(0.05, 0.58, 0), steel)
		"saha":
			B.mesh(n, B.cyl(0.02, 0.02, 0.8, 8), Vector3(0, 0.25, 0.2), Color(0.95, 0.45, 0.05), Vector3(90, 0, 0))
			B.mesh(n, B.boxm(Vector3(0.005, 0.035, 0.78)), Vector3(0, -0.05, 0.2), Color(0.75, 0.76, 0.78))
		"halot":
			for k in 5:
				var h := B.mesh(n, B.cyl(0.06, 0.06, 0.4, 5), Vector3(-0.1 + (k % 3) * 0.1, -0.05 + (k / 3) * 0.1, -0.12),
					Color(0.72, 0.58, 0.38) if k % 2 else Color(0.62, 0.48, 0.3))
				h.rotation.z = PI / 2.0
		"kiulu":
			B.mesh(n, B.cyl(0.1, 0.13, 0.2, 10), Vector3(0, -0.12, 0), Color(0.55, 0.4, 0.25))
		"tikat":
			for k in 3:
				B.mesh(n, B.cyl(0.004, 0.004, 0.14, 4), Vector3(k * 0.012, 0.02, 0.05), Color(0.85, 0.15, 0.1), Vector3(90, 0, 0))
		"onki":
			# Hahmon eteen on -Z (B.yaw_to).
			var grip := Vector3(-0.18, 0.55, -0.3)
			var tip := Vector3(-0.25, 1.7, -2.7)
			B.tube(n, grip, tip, 0.012, Color(0.15, 0.15, 0.16))
			B.tube(n, tip, Vector3(-0.28, -0.6, -3.4), 0.002, Color(0.85, 0.85, 0.85))  # siima veteen
			B.mesh(n, B.sphere(0.025, 6), Vector3(-0.28, -0.5, -3.35), Color(0.9, 0.2, 0.1))  # koho
		"vasara":
			B.mesh(n, B.cyl(0.014, 0.017, 0.32, 8), Vector3(0, 0.1, 0), wood)
			B.mesh(n, B.boxm(Vector3(0.11, 0.035, 0.035)), Vector3(0, 0.27, 0), steel)
		"maila":
			B.mesh(n, B.cyl(0.2, 0.2, 0.015, 18), Vector3(0, 0.25, 0.05), Color(0.85, 0.72, 0.5), Vector3(90, 0, 0))
			B.mesh(n, B.boxm(Vector3(0.035, 0.16, 0.03)), Vector3(0, 0.0, 0.05), Color(0.5, 0.34, 0.18))
		"talikko":
			B.mesh(n, B.cyl(0.018, 0.02, 1.4, 6), Vector3(0, 0.1, 0.2), wood, Vector3(70, 0, 0))
			for k in 4:
				B.mesh(n, B.cyl(0.006, 0.006, 0.25, 4), Vector3(-0.06 + k * 0.04, -0.15, 0.85), steel, Vector3(70, 0, 0))
		"jakoavain":
			B.mesh(n, B.boxm(Vector3(0.025, 0.2, 0.012)), Vector3(0, 0.05, 0), Color(0.7, 0.7, 0.72))
		"kiikari":
			for sx in [-0.035, 0.035]:
				B.mesh(n, B.cyl(0.022, 0.022, 0.12, 8), Vector3(sx, 0.05, 0.05), Color(0.1, 0.1, 0.1), Vector3(90, 0, 0))
	return n


# --- Kulku ----------------------------------------------------------------------------------------

## Puuhaako Santtu jotain juuri nyt (E-juttu kertoo puuhasta).
func working() -> bool:
	return _state == "work" and not _spot.is_empty()


func chat_line() -> String:
	return (_spot.lines as Array).pick_random() if working() else ""


func current_id() -> String:
	return _spot.get("id", "") if _state in ["go", "work"] else ""


func _process(delta: float) -> void:
	if mokki == null or not mokki.built:
		return
	if _spots.is_empty():
		_build_spots()
	_fx_tick(delta)
	if not enabled:
		if _state != "home":
			_abort()
		return
	match _state:
		"home":
			# Minipelin tai hommien katsomisen jälkeen Santtu voi seistä muualla: takaisin kannolle.
			if mokki.santtu_arrived():
				mokki.santtu_go_home()
				return
			if mokki.santtu_out():
				return
			_t -= delta
			if _t <= 0.0:
				_pick()
		"go":
			if _player_in_use():
				_yield()
			elif mokki.santtu_arrived():
				_begin_step()
		"work":
			_work(delta)
		"back":
			if not mokki.santtu_out():
				_state = "home"
				_t = randf_range(40.0, 80.0)


func _ok(sp: Dictionary) -> bool:
	if sp.has("task") and sp.task in pending:
		return false
	if _near_player(sp.use[0], sp.use[1] + 2.5):
		return false
	match sp.get("cond", ""):
		"palju":
			return mokki.palju_level >= 0.9 and not mokki.pump_on
		"mopo":
			return mokki.mopo_parked != null and mokki.mopo_parked.visible
	return true


func _near_player(p: Vector3, r: float) -> bool:
	if player_local == Vector3.INF:
		return false
	return Vector2(player_local.x - p.x, player_local.z - p.z).length() < r


func _player_in_use() -> bool:
	return _near_player(_spot.use[0], _spot.use[1] + 0.4)


func _pick() -> void:
	var cands: Array = _spots.filter(func(sp): return sp.id != _last_id and _ok(sp))
	if cands.is_empty():
		_t = randf_range(15.0, 30.0)
		_go_home()
		return
	var total := 0.0
	for sp in cands:
		total += sp.get("weight", 1.0)
	var r := randf() * total
	for sp in cands:
		r -= sp.get("weight", 1.0)
		if r <= 0.0:
			_spot = sp
			break
	if _spot.is_empty() or not _spot in cands:
		_spot = cands[-1]
	_last_id = _spot.id
	_step = 0
	_go_step()


func _go_step() -> void:
	var st: Dictionary = _spot.steps[_step]
	var pts: Array = st.get("via", []).duplicate()
	pts.append(st.at)
	mokki.santtu_walk(pts, st.look)
	_state = "go"


func _begin_step() -> void:
	var st: Dictionary = _spot.steps[_step]
	_state = "work"
	_work_t = 0.0
	_t = st.get("dur", randf_range(18.0, 30.0))
	_beat_t = 0.6
	_beat_back = -1.0
	var s: Node3D = mokki.santtu
	s.rotation.y = B.yaw_to(st.look - s.position)
	s.play(st.anim, 0.3)
	if st.get("sit_deck", false):
		s.position.y = mokki.walk_y(s.position.x, s.position.z) - 0.22  # laiturin reunalla, jalat roikkuu
	if st.has("prop"):
		mokki.santtu_prop(st.prop)
	if st.has("once"):
		s.restart(st.once, 0.15)
		_beat_back = s.anim_length(st.once) * 0.9
		_sound(st.get("sound", ""), st.at)
		_beat_t = 999.0
	if st.has("fx") and st.has("once"):
		_effect(st.fx, st)
	if _step == 0 and _near_player(st.at, 30.0):
		_line_t = randf_range(4.0, 8.0)
		mokki.say((_spot.lines as Array).pick_random(), 3.8)
	else:
		_line_t = randf_range(8.0, 12.0)


func _work(delta: float) -> void:
	var st: Dictionary = _spot.steps[_step]
	var s: Node3D = mokki.santtu
	_work_t += delta
	_t -= delta
	if _player_in_use():
		_yield()
		return
	if st.get("huussi", false):
		_huussi_tick(st)
	if _beat_back >= 0.0:
		_beat_back -= delta
		if _beat_back < 0.0:
			s.play(st.anim, 0.25)
	_beat_t -= delta
	if _beat_t <= 0.0 and st.has("beat"):
		_beat_t = st.beat * randf_range(0.85, 1.15)
		if st.has("beat_anim"):
			s.restart(st.beat_anim, 0.12)
			_beat_back = minf(s.anim_length(st.beat_anim), st.beat * 0.8)
		_sound(st.get("sound", ""), st.at)
		if st.has("fx"):
			_effect(st.fx, st)
	if st.get("fx", "") == "pallo":
		_ball_tick()
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = randf_range(9.0, 14.0)
		if _near_player(st.at, 25.0):
			mokki.say((_spot.lines as Array).pick_random(), 3.8)
	if _t <= 0.0:
		_end_step(st)


func _end_step(st: Dictionary) -> void:
	if st.has("prop_after"):
		mokki.santtu_prop(st.prop_after)
	_hide_ball()
	if _step + 1 < (_spot.steps as Array).size():
		_step += 1
		_go_step()
		return
	if randf() < 0.6 and not _spot.has("back"):
		_pick()
	else:
		_go_home()


func _go_home() -> void:
	_hide_ball()
	_unhide()
	var via: Array = _spot.get("back", []).duplicate() if _state == "work" else []
	mokki.santtu_go_home(via)
	_state = "back"


## Pelaaja tuli puuhapaikalle: Santtu väistää.
func _yield() -> void:
	mokki.say(["No tee sää, mää meen kahville.", "Ai sää tuut tähän? Ole hyvä vaan.", "Jatka sää, mää lepään vähän."].pick_random(), 3.2)
	_go_home()


## Hommat tai minipeli vievät Santun: puuha pois (paikka jää main.gd:n ohjaukseen).
func _abort() -> void:
	_hide_ball()
	_unhide()
	mokki.santtu_prop("")
	_state = "home"
	_spot = {}
	_t = randf_range(20.0, 40.0)


func _unhide() -> void:
	if _hidden:
		_hidden = false
		mokki.santtu.visible = true


## Huussi: ovi auki, Santtu sisään, mökkiradio ja ovi kiinni.
func _huussi_tick(st: Dictionary) -> void:
	var s: Node3D = mokki.santtu
	if not _hidden and _work_t > 1.0 and _work_t < 12.0:
		_hidden = true
		s.visible = false
		_sound("door", st.at)
	if _hidden and _work_t > 5.0 and not _spot.has("_pieru"):
		_spot = _spot.duplicate()
		_spot["_pieru"] = true
		_sound("fart", st.at)
		if _near_player(st.at, 25.0):
			mokki.say((_spot.lines as Array).pick_random(), 3.8)
	if _hidden and _work_t >= 12.0:
		_unhide()
		_sound("door_close", st.at)
		s.play("Idle", 0.2)


# --- Äänet ja efektit -----------------------------------------------------------------------------

func _sound(name: String, at: Vector3) -> void:
	if name == "" or player_local == Vector3.INF:
		return
	if Vector2(player_local.x - at.x, player_local.z - at.z).length() > 30.0:
		return
	var g: Vector3 = mokki.to_global(Vector3(at.x, mokki.h(at.x, at.z) + 1.0, at.z))
	Sfx.play_at(g, name, -4.0, randf_range(0.9, 1.1) * (1.6 if name == "punch" else 1.0))


func _effect(kind: String, st: Dictionary) -> void:
	var M := mokki
	match kind:
		"halot":
			var top: Vector3 = M.PUU_CHOP_LOCAL + Vector3(0, M.h(M.PUU_CHOP_LOCAL.x, M.PUU_CHOP_LOCAL.z) + 0.6, 0)
			for sx in [-1.0, 1.0]:
				var half := B.mesh(M, B.cyl(0.07, 0.07, 0.36, 5), top, Color(0.86, 0.74, 0.54))
				var tw := half.create_tween().set_parallel()
				tw.tween_property(half, "position", top + Vector3(sx * 0.7, -0.45, randf_range(-0.2, 0.3)), 0.45)
				tw.tween_property(half, "rotation", Vector3(PI / 2.0, 0, sx * 1.2), 0.45)
				_fx.append([half, 5.0])
		"puru":
			_puff(st.look + Vector3(0, 0.75, 0), Color(0.82, 0.68, 0.45, 0.6), 0.05)
		"hoyry":
			_puff(Vector3(4.0, 1.4, 19.65), Color(0.95, 0.95, 0.95, 0.4), 0.18)
		"savu":
			_puff(Vector3(-13.15, 1.2, 17.3), Color(0.6, 0.6, 0.62, 0.45), 0.2)
		"multa":
			_puff(M.KOMPOSTI_LOCAL + Vector3(0.3, 0.7, 0), Color(0.25, 0.18, 0.1, 0.8), 0.06)
		"tikka":
			var c: Vector3 = M.dart_board_center()
			var hit := c + Vector3(randf_range(-0.14, 0.14), randf_range(-0.14, 0.14), -0.02)
			var from: Vector3 = M.santtu.position + Vector3(0, 1.6, 0)
			var dart := Node3D.new()
			M.add_child(dart)
			B.mesh(dart, B.cyl(0.004, 0.004, 0.13, 4), Vector3(0, 0, -0.06), Color(0.85, 0.15, 0.1), Vector3(90, 0, 0))
			dart.position = from
			dart.look_at_from_position(from, hit, Vector3.UP)
			var tw := dart.create_tween()
			tw.tween_property(dart, "position", hit, 0.3)
			_fx.append([dart, 6.0])
			if randf() < 0.3:
				get_tree().create_timer(0.6).timeout.connect(func() -> void:
					if working() and _near_player(st.at, 25.0):
						mokki.say(["Kolmoistuplakakskymppi! Melkein.", "Bullseye!", "Ohi... ei kertota kellekään."].pick_random(), 3.0))
		"kala":
			if randf() < 0.3:
				var p: Vector3 = M.santtu.position + Vector3(0, 0.4, 0)
				var fish := B.mesh(M, B.sphere(0.06, 8), p + Vector3(0, 0.0, 1.3), Color(0.55, 0.6, 0.5))
				fish.scale = Vector3(0.6, 0.7, 2.2)
				var tw := fish.create_tween()
				tw.tween_property(fish, "position", p + Vector3(0, 0.9, 0.6), 0.6)
				_fx.append([fish, 2.6])
				if _near_player(st.at, 30.0):
					mokki.say(["Ahven! Takasin järveen, pieni oli.", "Särki. Kissalle.", "Pertti? Ei, joku Pertin serkku."].pick_random(), 3.5)
		"pino":
			if _woodpile == null:
				_woodpile = Node3D.new()
				M.add_child(_woodpile)
				_woodpile.position = Vector3(5.2, M.h(5.2, 17.5), 17.5)
			if _woodpile_n < 15:
				for k in 3:
					var i := _woodpile_n
					var lg := B.mesh(_woodpile, B.cyl(0.07, 0.07, 0.4, 5), Vector3(-0.8 + (i % 6) * 0.32, 0.08 + (i / 6) * 0.15, 0),
						Color(0.72, 0.58, 0.38) if i % 2 else Color(0.62, 0.48, 0.3))
					lg.rotation.x = PI / 2.0
					_woodpile_n += 1
		"mopo":
			if randf() < 0.25:
				_sound("pedal_creak", st.at)
				if _near_player(st.at, 25.0):
					mokki.say(["Pärähti! Ja sammu.", "Käy se! Hetken.", "Ny se tykkää."].pick_random(), 3.0)


func _puff(at: Vector3, col: Color, size: float) -> void:
	var M := mokki
	var fx := CPUParticles3D.new()
	fx.position = Vector3(at.x, at.y + M.h(at.x, at.z), at.z)
	fx.one_shot = true
	fx.amount = 14
	fx.lifetime = 1.6
	fx.explosiveness = 0.8
	fx.direction = Vector3(0, 1, 0)
	fx.spread = 40.0
	fx.gravity = Vector3(0, 0.2, 0)
	fx.initial_velocity_min = 0.3
	fx.initial_velocity_max = 0.8
	fx.scale_amount_min = 0.8
	fx.scale_amount_max = 1.8
	var m := SphereMesh.new()
	m.radius = size
	m.height = size * 2.0
	m.material = B.unshaded(col)
	fx.mesh = m
	M.add_child(fx)
	fx.emitting = true
	_fx.append([fx, 2.5])


## Pingispallo pomppii Santun mailan yllä.
func _ball_tick() -> void:
	var s: Node3D = mokki.santtu
	if _ball == null:
		_ball = B.mesh(mokki, B.sphere(0.03, 8), Vector3.ZERO, Color(1.0, 0.6, 0.15))
	_ball.visible = true
	var fwd := Vector3(sin(s.rotation.y), 0, cos(s.rotation.y))
	var bounce := absf(sin(_work_t * PI / 0.55))
	_ball.position = s.position + fwd * 0.45 + Vector3(0, 1.05 + bounce * 0.55, 0)


func _hide_ball() -> void:
	if _ball != null:
		_ball.visible = false


func _fx_tick(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i][1] -= delta
		if _fx[i][1] <= 0.0:
			if is_instance_valid(_fx[i][0]):
				_fx[i][0].queue_free()
			_fx.remove_at(i)


## Testinäkymä (main.gd mokkipuuhat): Santtu suoraan puuhapaikalle id. Palauttaa false, jos paikkaa ei ole.
func debug_start(id: String) -> bool:
	if _spots.is_empty():
		_build_spots()
	for sp in _spots:
		if sp.id == id:
			_abort()
			_spot = sp
			_last_id = id
			_step = 0
			var st: Dictionary = sp.steps[0]
			mokki.santtu_teleport(st.at, st.look)
			mokki.santtu.position.y = mokki.walk_y(st.at.x, st.at.z)
			_begin_step()
			return true
	return false


func spot_ids() -> Array:
	if _spots.is_empty():
		_build_spots()
	return _spots.map(func(sp): return sp.id)


func spot_at(id: String) -> Vector3:
	for sp in _spots:
		if sp.id == id:
			return sp.steps[0].at
	return Vector3.ZERO
