extends Node3D
## Kalastus rannalta Saloisissa (Oravajärvi ja Haapajärven tekojärvi): pelaaja seisoo rannalla vapa kädessä.
## Onki: lyhyt heitto (pidä E, päästä), koho kellumaan, nykäisyssä E heti, ja pikku väsytys. Yksi mato per heitto.
## Virveli: pitkä heitto, sitten pidä E kelataksesi uistinta rantaa kohti: kala iskee kelatessa. Väsytys kuten
## mökin kalastuksessa (fish_game.gd): kireys vihreällä, liian kireä katkeaa, löysällä kala karkaa. F lopettaa.
## Legenda "Tekojärven Ukko" (ukko_legenda.gd): ukko_snap = jokin valtava katkaisee siiman (vihje), ukko_ready =
## Ukon lusikalla iltaisin Kaitasaaren kärjestä nousee itse Ukko: pitkä ja raskas väsytys, joka vetää kohti vettä.
## Maailman koordinaatit (main.gd:n lapsi). finished(catch): [{"nom", "name", "kg"}, ...].

signal finished(catch: Array)

const B := preload("res://scripts/build.gd")
const T := preload("res://scripts/terrain.gd")
const Looks := preload("res://scripts/looks.gd")
const Mokki := preload("res://scripts/mokki.gd")

const ONKI_CAST := Vector2(2.0, 8.0)
const VIRVELI_CAST := Vector2(6.0, 24.0)
const RETRIEVE := 1.6  # uistimen kelausnopeus (m/s)
const POWER := {"särki": 0.25, "ahven": 0.4, "lahna": 0.6, "made": 0.65, "hauki": 1.0}
const UKKO := {"nom": "ukko", "name": "Tekojärven Ukon", "kg": 18.4, "power": 1.5}
const JUNK_CHANCE := 0.07

var gear := "onki"        # onki | virveli
var lure := ""            # "" | "ukko" (Ukon kuparilusikka)
var place := "Oravajärvi"
var spot := Vector3.ZERO  # seisomapaikka rannalla
var dir := Vector3.FORWARD  # vedelle päin (vaakasuora)
var water: Callable       # func(p: Vector3) -> bool
var worms := 0            # onkimadot mukana (onki kuluttaa yhden heitossa)
var drunk := 0.0
var ukko_snap := false
var ukko_ready := false
var catch: Array = []
var snaps := 0            # Ukon katkaisemat siimat tällä kertaa
var ukko_caught := false
var stocked := false      # istutettu lampi (retki_lampi.gd): taimen ja kirjolohi, kala syö nopeasti, ei roskaa
var surface_y := NAN      # veden pinta, jos vesi ei ole maastossa (taskukohtaus); NAN = maaston korkeus

var _state := "idle"      # idle | charge | wait | retrieve | bite | reel | end
var _t := 0.0
var _charge := 0.0
var _bob := Vector3.ZERO
var _bite_at := 0.0
var _bite_chance := 0.0
var _fish := {}
var _dist := 0.0
var _tension := 0.3
var _slack_t := 0.0
var _surge := 0.0
var _surge_t := 0.0
var _end_t := 0.0
var _msg_t := 0.0
var _shake := 0.0
var _snap_at := -1.0
var _splashes: Array = []  # [MeshInstance3D, ikä]
var _shown: Node3D  # nostettu saalis siiman päässä
var _shown_t := 0.0

var _body: Node3D
var _rod: Node3D
var _float: Node3D
var _line: MeshInstance3D
var _line_mesh: ImmediateMesh
var _cam: Camera3D
var _ui: CanvasLayer
var _hint: Control
var _msg: Label
var _bag_label: Label
var _dist_label: Label
var _bar_bg: ColorRect
var _bar: ColorRect
var _green: ColorRect
var _needle: ColorRect
var _power: ColorRect


func _ready() -> void:
	dir = Vector3(dir.x, 0, dir.z).normalized()
	_body = Looks.make(self, Looks.player())
	Looks.add_cap(_body)
	_body.position = spot
	_body.rotation.y = B.yaw_to(dir)
	_body.play("Idle", 0.0)
	_rod = _build_rod(gear == "onki")
	add_child(_rod)  # paikka ja suunta joka ruudulla (_update_rod): kädet tarttuvat vapaan IK:lla
	_float = _build_bobber() if gear == "onki" else _build_lure(lure == "ukko")
	add_child(_float)
	_float.visible = false
	_line_mesh = ImmediateMesh.new()
	_line = MeshInstance3D.new()
	_line.mesh = _line_mesh
	_line.material_override = B.unshaded(Color(0.92, 0.92, 0.86, 0.85))
	add_child(_line)
	_cam = Camera3D.new()
	_cam.fov = 60.0
	_cam.far = 1500.0
	add_child(_cam)
	_cam.current = true
	_build_ui()
	if gear == "onki":
		_say("%s rannalla, onki kädessä. Matoja %d. Pidä %s: heiton pituus, päästä: heitto." % [place, worms, Settings.action_key("interact")], 4.0)
	elif stocked:
		_say("%s rannalla, onki kädessä. Istutettu kala syö vikkelästi. Matoja %d. Pidä %s: heiton pituus, päästä: heitto." % [place, worms, Settings.action_key("interact")], 4.5)
	elif lure == "ukko":
		_say("Ukon kuparilusikka siiman päässä. Ilta-aurinko, Kaitasaaren kärki. Nyt tai ei koskaan.", 4.5)
	else:
		_say("%s rannalla, virveli kädessä. Heitä kauas ja kelaa tasaisesti: kala iskee kelatessa." % place, 4.0)


# --- Rakennus -------------------------------------------------------------------------------

## Vapa käteen: onki on kolmeen osaan liitetty bambu, virvelissä tumma vapa, kela ja kahva. Kärki +Y:ssä.
func _build_rod(bamboo: bool) -> Node3D:
	var r := Node3D.new()
	var len := 3.2 if bamboo else 2.3
	if bamboo:
		var cane := Color(0.82, 0.72, 0.45)
		for i in 3:
			var h := len / 3.0
			B.mesh(r, B.cyl(0.016 - i * 0.004, 0.02 - i * 0.004, h, 6), Vector3(0, h * (i + 0.5), 0), cane.darkened(i * 0.06))
			B.mesh(r, B.cyl(0.023 - i * 0.004, 0.023 - i * 0.004, 0.03, 6), Vector3(0, h * i + 0.02, 0), cane.darkened(0.35))  # nivel
	else:
		B.mesh(r, B.cyl(0.006, 0.018, len, 6), Vector3(0, len / 2.0, 0), Color(0.15, 0.17, 0.2))
		B.mesh(r, B.cyl(0.024, 0.024, 0.32, 8), Vector3(0, 0.12, 0), Color(0.35, 0.22, 0.12))  # korkkikahva
		B.mesh(r, B.cyl(0.045, 0.045, 0.05, 12), Vector3(0.05, 0.36, 0), Color(0.75, 0.76, 0.8), Vector3(0, 0, 90))  # kela
		B.mesh(r, B.cyl(0.006, 0.006, 0.08, 4), Vector3(0.1, 0.36, 0), Color(0.2, 0.2, 0.22), Vector3(0, 0, 90))  # kampi
		for i in 3:
			B.mesh(r, B.cyl(0.012, 0.012, 0.01, 8), Vector3(0, 0.7 + i * 0.5, 0.02), Color(0.8, 0.8, 0.82))  # renkaat
	r.set_meta("len", len)
	return r


## Koho: punavalkoinen pallo ja keltainen tikku.
func _build_bobber() -> Node3D:
	var n := Node3D.new()
	B.mesh(n, B.sphere(0.06, 10), Vector3(0, 0.02, 0), Color(0.95, 0.15, 0.1))
	B.mesh(n, B.sphere(0.045, 10), Vector3(0, 0.08, 0), Color(0.96, 0.96, 0.96))
	B.mesh(n, B.cyl(0.007, 0.007, 0.12, 4), Vector3(0, 0.16, 0), Color(0.95, 0.88, 0.15))
	return n


## Lusikkauistin: kupera lehti, kiiltävä pinta ja kolmihaarakoukku. Ukon lusikka on vanhaa kuparia.
func _build_lure(copper: bool) -> Node3D:
	var n := Node3D.new()
	var col := Color(0.85, 0.48, 0.25) if copper else Color(0.85, 0.86, 0.9)
	var spoon := B.mesh(n, B.sphere(0.05, 10), Vector3(0, 0.03, 0), col)
	spoon.scale = Vector3(0.6, 0.18, 1.3)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.9
	mat.roughness = 0.25
	spoon.material_override = mat
	B.mesh(n, B.sphere(0.012, 6), Vector3(0, 0.05, -0.05), Color(0.9, 0.15, 0.1))  # punainen silmä
	B.mesh(n, B.cyl(0.004, 0.004, 0.06, 4), Vector3(0, 0.03, 0.08), Color(0.3, 0.3, 0.32), Vector3(90, 0, 0))  # koukku
	return n


func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 15
	add_child(_ui)
	_hint = preload("res://scripts/hint_bar.gd").new()
	_hint.compact = true
	_hint.centered = true
	_ui.add_child(_hint)
	_msg = _mk_label(Vector2(0, 90), 32, HORIZONTAL_ALIGNMENT_CENTER)
	_bag_label = _mk_label(Vector2(20, 14), 24, HORIZONTAL_ALIGNMENT_LEFT)
	_dist_label = _mk_label(Vector2(0, 470), 24, HORIZONTAL_ALIGNMENT_CENTER)
	_bar_bg = _rect(Color(0, 0, 0, 0.6), Vector2(390, 510), Vector2(500, 36))
	_green = _rect(Color(0.2, 0.7, 0.3, 0.8), Vector2(390 + 500 * 0.35, 510), Vector2(500 * 0.45, 36))
	_bar = _rect(Color(0.9, 0.2, 0.15, 0.8), Vector2(390 + 500 * 0.9, 510), Vector2(50, 36))
	_needle = _rect(Color(1, 1, 1), Vector2.ZERO, Vector2(6, 48))
	_power = _rect(Color(1.0, 0.8, 0.2), Vector2(390, 560), Vector2(0, 14))
	_show_bar(false)


func _rect(c: Color, pos: Vector2, size: Vector2) -> ColorRect:
	var r := ColorRect.new()
	r.color = c
	r.position = pos
	r.size = size
	_ui.add_child(r)
	return r


func _mk_label(pos: Vector2, size: int, align: HorizontalAlignment) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = Vector2(1280 if align == HORIZONTAL_ALIGNMENT_CENTER else 800, 60)
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	_ui.add_child(l)
	return l


func _show_bar(on: bool) -> void:
	for c in [_bar_bg, _green, _bar, _needle]:
		c.visible = on


func _say(text: String, t := 2.5) -> void:
	_msg.text = text
	_msg_t = t


func _surface(p: Vector3) -> float:
	if not is_nan(surface_y):
		return surface_y + 0.01
	return T.h(p.x, p.z) + 0.01


# --- Kulku ----------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_msg_t -= delta
	if _msg_t <= 0.0:
		_msg.text = ""
	_shake = maxf(0.0, _shake - delta * 2.0)
	_update_splashes(delta)
	match _state:
		"idle":
			var bait := gear != "onki" or worms > 0
			_hint.set_text("%s heitä (pidä pohjassa)   %s lopeta" % [Settings.cap("interact"), Settings.cap("mount")] if bait
				else "Madot loppu.   %s lopeta" % Settings.cap("mount"))
			if Input.is_action_just_pressed("interact") and bait:  # aloittava E (pohjassa) ei heitä heti
				_state = "charge"
				_charge = 0.0
			elif Input.is_action_just_pressed("interact") and not bait:
				_say("Ei yhtään matoa. Kauppa-autosta saa matopurkin.", 2.0)
		"charge":
			_charge = minf(_charge + delta * 0.8, 1.0)
			_power.size.x = 500.0 * _charge
			var rng := ONKI_CAST if gear == "onki" else VIRVELI_CAST
			_hint.set_text("%s päästä irti: heitto (%d m)" % [Settings.cap("interact"), roundi(lerpf(rng.x, rng.y, _charge))])
			_body.rotation.x = -_charge * 0.08
			if not Input.is_action_pressed("interact"):
				_cast()
		"wait":
			_hint.set_text("Katso kohoa...   %s nosta onki ylös" % Settings.cap("mount"))
			_float.position = _bob + Vector3(0, sin(_t * 2.0) * 0.015, 0)
			if _t >= _bite_at:
				_bite()
			elif fmod(_t, 2.6) < delta and randf() < 0.4:
				_float.position.y -= 0.04  # nypläys
				_splash(_bob, 0.25)
		"retrieve":
			_retrieve(delta)
		"bite":
			_float.position = _bob + Vector3(0, -0.12 + sin(_t * 30.0) * 0.04, 0)
			_hint.set_text("%s tartu!" % Settings.cap("interact"))
			if Input.is_action_just_pressed("interact"):
				_hook()
			elif _t > _bite_at:
				_miss(Mokki.FISH_MISS_LINES.pick_random() if gear == "onki" else "Kala tönäisi uistinta ja kääntyi pois.")
		"reel":
			_reel(delta)
		"end":
			_end_t -= delta
			if _end_t <= 0.0:
				finished.emit(catch)
				queue_free()
				return
	if _state in ["idle", "wait", "retrieve"] and Input.is_action_just_pressed("mount"):
		if _state == "idle":
			_state = "end"
			_end_t = 1.0
			_say("Kalat kassiin, vapa olalle." if not catch.is_empty() else "Tänään ei syöny.", 1.5)
		else:
			_reset("Nostit %s ylös." % ("kohon" if gear == "onki" else "uistimen"))
	if _state != "charge":
		_power.size.x = 0.0
		_body.rotation.x = lerpf(_body.rotation.x, 0.0, 0.2)
	_update_rod()
	_update_line()
	_update_camera(delta)
	var names := []
	for c in catch:
		names.append("%s %s kg" % [c.nom, ("%.1f" % c.kg).replace(".", ",")])
	var bag := "Saalis: " + (", ".join(names) if not names.is_empty() else "–")
	_bag_label.text = bag + ("   Matoja %d" % worms if gear == "onki" else "")


func _cast() -> void:
	var rng := ONKI_CAST if gear == "onki" else VIRVELI_CAST
	var d := lerpf(rng.x, rng.y, _charge) * randf_range(0.9, 1.05)
	var side := dir.cross(Vector3.UP)
	var aim := (dir + side * randf_range(-0.2, 0.2) * (1.0 + drunk)).normalized()
	_body.play("Punch_Cross", 0.05, 1.4)
	Sfx.play("whoosh", -6.0, 0.9)
	var p := spot + aim * d
	if not water.call(p) or not water.call(spot + aim * minf(d, 1.6)):
		_say("Heitto meni rantakaislikkoon! Uusi heitto.", 2.0)
		_state = "idle"
		return
	if gear == "onki":
		worms -= 1
	_bob = Vector3(p.x, _surface(p), p.z)
	_float.position = _bob
	_float.visible = true
	_splash(_bob, 0.6)
	Sfx.play("water", -8.0, 1.8)
	if gear == "onki":
		_state = "wait"
		_bite_at = _t + (randf_range(0.8, 3.0) if stocked else randf_range(2.5, 9.0))
		_fish = _pick_fish()
	else:
		_state = "retrieve"
		_bite_chance = 0.0
		_snap_at = -1.0
	_body.play("Idle", 0.3)


## Virveli: E kelaa uistinta rantaa kohti. Kala iskee kelatessa (todennäköisyys kasvaa kauempana ja tasaisella
## kelauksella). Ukon kohdalla: legendan vihje (siima katkeaa) tai huipennus (Ukko iskee).
func _retrieve(delta: float) -> void:
	_hint.set_text("%s kelaa uistinta (pidä pohjassa)   %s nosta ylös" % [Settings.cap("interact"), Settings.cap("mount")])
	var reeling := Input.is_action_pressed("interact")
	var to_me := Vector3(spot.x - _bob.x, 0, spot.z - _bob.z)
	var d := to_me.length()
	if reeling:
		_bob += to_me / maxf(d, 0.01) * RETRIEVE * delta
		_bob.y = _surface(_bob)
		_bite_chance += delta * (0.09 + d / 160.0)
	_float.position = _bob + Vector3(0, -0.03 + sin(_t * 12.0) * 0.01 * (1.0 if reeling else 0.0), 0)
	_float.rotation.y = atan2(to_me.x, to_me.z) + sin(_t * 9.0) * (0.5 if reeling else 0.1)
	if d < 1.6:
		_reset("Tyhjä heitto. Uistin rantaan.")
		return
	if not reeling:
		return
	if ukko_ready and d > 8.0 and _bite_chance > 0.35:
		_fish = UKKO.duplicate()
		_strike()
		return
	if ukko_snap and d > 8.0 and _bite_chance > 0.5 and randf() < delta * 0.6:
		# Jokin valtava iskee ja katkaisee siiman saman tien (legendan vihje).
		_fish = {"nom": "?", "power": 2.0, "snap": true}
		_strike()
		_snap_at = _t + 1.4
		return
	if randf() < delta * _bite_chance * 0.35:
		_fish = _pick_fish()
		_strike()


func _strike() -> void:
	Sfx.play("water", -2.0, 1.4 if _fish.get("power", 0.3) < 1.2 else 0.7)
	_splash(_bob, 1.0 if _fish.get("power", 0.3) < 1.2 else 2.4)
	_hook()


func _bite() -> void:
	_state = "bite"
	_bite_at = _t + lerpf(0.9, 0.6, drunk)
	Sfx.play("water", -2.0, 1.6)
	_splash(_bob, 0.5)
	_say("NYKÄISY! %s nyt!" % Settings.action_key("interact"), 1.0)


func _pick_fish() -> Dictionary:
	if stocked:
		return _pick_stocked()
	if randf() < JUNK_CHANCE:
		return {"junk": true, "power": 0.2}
	var shore := Vector2(_bob.x - spot.x, _bob.z - spot.z).length()
	var weights := {"särki": 4.0, "ahven": 3.0, "lahna": 1.0}
	if gear == "virveli":
		weights = {"ahven": 3.0, "hauki": 1.2 + shore / 12.0, "made": 0.4}
	var total := 0.0
	for k in weights:
		total += weights[k]
	var r := randf() * total
	var nom := "ahven"
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			nom = k
			break
	for f in Mokki.FISH:
		if f.nom == nom:
			var kg: float = f.kg * randf_range(0.5, 1.4) * (0.8 if gear == "onki" else 1.1)
			return {"nom": nom, "name": f.name, "kg": kg, "power": minf(POWER[nom] * clampf(kg / f.kg, 0.7, 1.3), 1.15)}
	return {"junk": true, "power": 0.2}


## Istutettu lampi: kirjolohi (tavallinen) tai taimen (harvinaisempi, väkevämpi).
func _pick_stocked() -> Dictionary:
	if randf() < 0.65:
		var kg := 1.2 * randf_range(0.6, 1.4)
		return {"nom": "kirjolohi", "name": "kirjolohen", "kg": kg, "power": 0.5}
	var tkg := 1.8 * randf_range(0.6, 1.5)
	return {"nom": "taimen", "name": "taimenen", "kg": tkg, "power": 0.75}


func _hook() -> void:
	_state = "reel"
	_dist = Vector2(_bob.x - spot.x, _bob.z - spot.z).length()
	if _fish.get("nom", "") == "ukko":
		_dist = maxf(_dist, 22.0)
	_tension = 0.5
	_slack_t = 0.0
	_surge_t = 0.8
	_show_bar(true)
	Sfx.play("alert", -6.0, 1.5 if _fish.get("power", 0.3) < 1.2 else 0.8)
	if _fish.get("nom", "") == "ukko":
		_say("UKKO! Vapa taipuu kaareksi. Pidä %s: kelaa. Älä päästä sitä kaislikkoon!" % Settings.action_key("interact"), 3.0)
	elif not _fish.get("snap", false):
		_say("Tärppi! Pidä %s: kelaa. Kireys vihreällä!" % Settings.action_key("interact"), 2.0)
	_body.play("Idle", 0.2)


## Väsytys: E kelaa (kireys nousee, kala lähestyy vihreällä), irti päästäminen löysää. Kala rimpuilee syöksyin.
## Ukko on raskas: syöksyt ovat rajuja ja vetävät pelaajaa kohti vettä (kamera tärisee).
func _reel(delta: float) -> void:
	var p: float = _fish.power
	var ukko: bool = _fish.get("nom", "") == "ukko"
	if _fish.get("snap", false):
		_tension = minf(_tension + delta * 1.2, 1.05)
		_needle.position = Vector2(390 + 500 * clampf(_tension, 0.0, 1.0) - 3, 504)
		_shake = 1.0
		_float.position = _bob + Vector3(sin(_t * 23.0) * 0.3, -0.2, cos(_t * 19.0) * 0.3)
		_hint.set_text("...!")
		if _t >= _snap_at:
			snaps += 1
			Sfx.play("rattle", -2.0, 0.7)
			_splash(_bob, 3.0)
			_end_reel(["PAM! Siima poikki kuin puuvillalanka. Jokin VALTAVA vei uistimen syvyyksiin.",
				"Siima ui suoraan järven keskelle ja katkesi. Tukki ei ui. Mikä tuo oli?"][mini(snaps - 1, 1)])
		return
	var reeling := Input.is_action_pressed("interact")
	_surge_t -= delta
	if _surge_t <= 0.0:
		_surge_t = randf_range(0.6, 2.2) / (0.5 + p)
		_surge = randf_range(0.4, 1.0) * p
		Sfx.play("water", -10.0 if not ukko else -2.0, randf_range(1.0, 1.4) if not ukko else 0.6)
		if ukko:
			_splash(_bob, 2.0)
			_shake = 0.8
	_surge = move_toward(_surge, 0.0, delta * 1.2)
	var wob := (sin(_t * 17.0) * 0.5 + sin(_t * 7.3)) * 0.04 * drunk
	# Ukko: syöksyt vetävät pitkään mutta eivät pidä kireyttä jatkuvasti punaisella, jotta tarkka pelaaja saa sen
	# maihin noin minuutissa ja huolimatonkin muutamassa (simuloitu: kireys 0,3, veto 0,45, kelaus 0,7).
	_tension += ((0.55 if reeling else -0.7) + _surge * (0.9 if not ukko else 0.3) + wob * 10.0) * delta
	_tension = clampf(_tension, 0.0, 1.05)
	var green := _tension >= 0.35 and _tension <= 0.8
	if reeling and green:
		_dist -= (3.4 - minf(p, 1.15) * 1.3) * delta * (0.7 if ukko else 1.0)
	_dist += _surge * (0.45 if ukko else 0.9) * delta
	_slack_t = _slack_t + delta if _tension < 0.15 else 0.0
	var to_me := Vector3(spot.x - _bob.x, 0, spot.z - _bob.z)
	var cur := to_me.length()
	if cur > 0.01:
		_bob += to_me / cur * (cur - maxf(_dist, 1.0))
	_bob.y = _surface(_bob)
	var wig := 0.1 * minf(p, 1.5)
	_float.position = _bob + Vector3(sin(_t * 9.0) * wig, -0.05, cos(_t * 11.0) * wig)
	if ukko:  # Ukko vetää: pelaaja nojaa taaksepäin ja liukuu kohti vettä syöksyissä
		_body.rotation.x = lerpf(_body.rotation.x, 0.18 - _surge * 0.25, 0.2)
	_needle.position = Vector2(390 + 500 * clampf(_tension, 0.0, 1.0) - 3, 504)
	_dist_label.text = "%.1f m" % maxf(_dist, 0.0)
	_hint.set_text("%s kelaa (pidä pohjassa, päästä: löysää) – pidä neula vihreällä" % Settings.cap("interact"))
	if _tension >= 1.0:
		Sfx.play("rattle", -4.0, 1.4)
		_end_reel("PAM! Siima katkesi." + (" Ukko pääsi. Se jäi kattomaan sinua pinnan alta." if ukko else
			(" Se oli iso..." if p > 0.7 else " Liian kireällä.")))
	elif _slack_t > 1.6:
		_end_reel("Siima löystyi ja kala karkasi." if not ukko else "Siima löystyi, ja Ukko sukelsi kaislikon alle.")
	elif _dist <= 1.0:
		_land()


func _land() -> void:
	if _fish.get("junk", false):
		Sfx.play("rattle", -4.0, 0.9)
		_end_reel("Vedit rantaan %s. Ei syötävää." % Mokki.FISH_JUNK.pick_random())
		return
	var ukko: bool = _fish.nom == "ukko"
	Sfx.play("win" if ukko else "win_small", -4.0)
	_splash(_bob, 1.2 if ukko else 0.6)
	catch.append({"nom": _fish.nom, "name": _fish.name, "kg": _fish.kg})
	_show_fish(_fish.nom, _fish.kg)
	if ukko:
		ukko_caught = true
		_show_bar(false)
		_float.visible = false
		_dist_label.text = ""
		_hint.set_text("")
		_say("TEKOJÄRVEN UKKO! %s kg haukea, kyljessä vanhoja uistimia kuin mitaleita. Tauno oli oikeassa." %
			("%.1f" % _fish.kg).replace(".", ","), 6.0)
		_state = "end"
		_end_t = 4.0
		return
	var big := " Komea!" if _fish.nom == "hauki" or _fish.kg > 1.2 else ""
	_end_reel("Sait %s! %s kg.%s" % [_fish.name, ("%.1f" % _fish.kg).replace(".", ","), big])


func _end_reel(text: String) -> void:
	_reset("")
	_say(text, 3.0)


func _miss(text: String) -> void:
	_reset(text)


func _reset(text: String) -> void:
	if text != "":
		_say(text, 2.0)
	_state = "idle"
	_float.visible = false
	_show_bar(false)
	_dist_label.text = ""
	_body.play("Idle", 0.2)


# --- Kuva -----------------------------------------------------------------------------------

## Vapa rinnan edessä kahdella kädellä, kärki järvelle päin ja ylös. Heitossa kärki nousee taakse, väsytyksessä
## se painuu kalan suuntaan. Kädet vavan kahvalle IK:lla (oikea alempana kelalla, vasen ylempänä).
var _tilt := 0.65
func _update_rod() -> void:
	var want := 0.65
	match _state:
		"charge":
			want = 0.65 + _charge * 0.9  # kärki taakse olan yli
		"reel":
			want = 0.65 - clampf(_tension, 0.0, 1.0) * 0.45
		"wait", "retrieve", "bite":
			want = 0.45
	_tilt = lerpf(_tilt, want, 0.25)
	var side := dir.cross(Vector3.UP).normalized()
	var axis := (dir * cos(_tilt) + Vector3.UP * sin(_tilt)).normalized()
	if _state == "charge":
		axis = (dir * cos(_tilt) + Vector3.UP * sin(_tilt)).normalized()
	var grip := spot + dir * 0.42 + side * 0.12 + Vector3(0, 1.0, 0)
	var x := side
	var z := x.cross(axis).normalized()
	_rod.global_transform = Transform3D(Basis(x, axis, z), grip - axis * 0.25)
	if _shown != null and _shown.get_meta("ukko", false):
		return
	var inv := _body.global_transform.affine_inverse()
	var hr := grip + axis * 0.1  # kelan kohta
	var hl := grip + axis * 0.55
	_body.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * hr, inv * (spot + side * 0.6 + Vector3(0, 0.9, 0)))
	_body.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * hl, inv * (spot - side * 0.6 + Vector3(0, 0.9, 0)))


## Siima vavan kärjestä kohoon tai uistimeen (löysä roikkuu, kireä suoristuu).
func _update_line() -> void:
	_line_mesh.clear_surfaces()
	if not _float.visible:
		return
	var tip := to_local(_rod.to_global(Vector3(0, float(_rod.get_meta("len")), 0)))
	var end := _float.position + Vector3(0, 0.12 if gear == "onki" else 0.03, 0)
	_line_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var sag := 0.5 if _state != "reel" else 0.08 + (1.0 - _tension) * 0.3
	var prev := tip
	for i in range(1, 13):
		var k := i / 12.0
		var q := tip.lerp(end, k) - Vector3(0, sin(k * PI) * sag, 0)
		_line_mesh.surface_add_vertex(prev)
		_line_mesh.surface_add_vertex(q)
		prev = q
	_line_mesh.surface_end()


## Kamera pelaajan takaa olan yli järvelle; kohon tai kalan ollessa vedessä katse niiden ja pelaajan väliin.
func _update_camera(delta: float) -> void:
	var side := dir.cross(Vector3.UP)
	var want := spot - dir * 3.4 + side * 1.3 + Vector3(0, 2.1, 0)
	var look := spot + dir * 7.0 + Vector3(0, 0.6, 0)
	if _float.visible:
		look = spot.lerp(_bob, 0.6) + Vector3(0, 0.5, 0)
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * _shake * 0.06
	_cam.position = (_cam.position.lerp(want, 1.0 - exp(-3.0 * delta)) if _t > 0.1 else want) + sh
	_cam.look_at(look, Vector3.UP)


## Roiske: valkoinen rengas leviää pinnalla ja muutama pisara hyppää.
func _splash(at: Vector3, size: float) -> void:
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.18
	tm.outer_radius = 0.24
	tm.rings = 20
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = B.unshaded(Color(0.92, 0.96, 1.0, 0.7))
	ring.position = at + Vector3(0, 0.02, 0)
	ring.scale = Vector3(1, 0.06, 1) * size
	add_child(ring)
	_splashes.append([ring, 0.0, size, []])
	for i in int(3 + size * 3):
		var d := B.mesh(self, B.sphere(0.025 * (0.6 + size * 0.3), 6), at, Color(0.9, 0.95, 1.0))
		d.material_override = B.unshaded(Color(0.9, 0.95, 1.0, 0.85))
		var a := randf() * TAU
		_splashes[-1][3].append([d, Vector3(cos(a) * randf_range(0.4, 1.2), randf_range(1.4, 2.8) * (0.6 + size * 0.3), sin(a) * randf_range(0.4, 1.2))])


## Saalis siiman päässä vavan kärjessä: lajin muoto ja väritys, koko painosta. Heiluu ja sätkii hetken.
func _show_fish(nom: String, kg: float) -> void:
	if _shown != null:
		_shown.queue_free()
	_shown = Node3D.new()
	_shown.set_meta("ukko", nom == "ukko")
	add_child(_shown)
	_shown_t = 4.5 if nom == "ukko" else 2.4
	var len := 1.3 if nom == "ukko" else clampf(0.16 + pow(kg, 0.33) * 0.32, 0.18, 1.0)
	var back := Color(0.35, 0.42, 0.3)
	var belly := Color(0.88, 0.86, 0.75)
	var fin := Color(0.75, 0.3, 0.2)
	match nom:
		"särki":
			back = Color(0.4, 0.45, 0.5)
			belly = Color(0.9, 0.9, 0.92)
		"ahven":
			back = Color(0.45, 0.55, 0.25)
			belly = Color(0.92, 0.85, 0.55)
			fin = Color(0.9, 0.35, 0.15)
		"lahna":
			back = Color(0.45, 0.4, 0.28)
			belly = Color(0.78, 0.68, 0.45)
			fin = Color(0.35, 0.3, 0.25)
		"hauki", "ukko":
			back = Color(0.3, 0.4, 0.22)
			belly = Color(0.85, 0.83, 0.62)
			fin = Color(0.78, 0.5, 0.26)
		"made":
			back = Color(0.35, 0.3, 0.2)
			belly = Color(0.7, 0.65, 0.5)
			fin = Color(0.3, 0.25, 0.18)
		"kirjolohi":  # harmaanvihreä selkä, hopeinen vatsa, punertava raita kyljessä ja mustat pilkut
			back = Color(0.42, 0.5, 0.45)
			belly = Color(0.92, 0.92, 0.9)
			fin = Color(0.55, 0.55, 0.5)
		"taimen":  # ruskea selkä, kellertävä vatsa, punaiset pilkut vaaleissa renkaissa
			back = Color(0.4, 0.3, 0.16)
			belly = Color(0.9, 0.8, 0.5)
			fin = Color(0.55, 0.4, 0.2)
	var slim := 0.55 if nom in ["hauki", "ukko", "made"] else (1.0 if nom == "lahna" else (0.65 if nom in ["kirjolohi", "taimen"] else 0.75))
	# Pää alaspäin roikkuva kala: pituus pystyakselilla. Selkä ja vatsa kahtena puolipallona, pyrstö ja evät.
	var body := B.mesh(_shown, B.sphere(0.5, 14), Vector3(0, -len * 0.5, 0), back)
	body.scale = Vector3(0.22 * slim, 1.0, 0.36 * slim) * len
	var bel := B.mesh(_shown, B.sphere(0.5, 14), Vector3(0, -len * 0.5, len * 0.03), belly)
	bel.scale = Vector3(0.2 * slim, 0.92, 0.33 * slim) * len
	# Pyrstö: kaksi ohutta lehteä V-muodossa ruumiin päässä; selkä- ja peräevä matalina ja ohuina.
	for sgn in [-1.0, 1.0]:
		var lobe := B.mesh(_shown, B.boxm(Vector3(0.012, 0.16, 0.07) * len * 1.3), Vector3(0, len * 0.06, sgn * len * 0.06), fin)
		lobe.rotation.x = sgn * 0.55
	B.mesh(_shown, B.boxm(Vector3(0.01, 0.2, 0.05) * len), Vector3(0, -len * 0.3, -len * 0.19 * slim), fin.darkened(0.15))  # selkäevä
	B.mesh(_shown, B.boxm(Vector3(0.01, 0.12, 0.04) * len), Vector3(0, -len * 0.22, len * 0.17 * slim), fin.lightened(0.1))  # peräevä
	B.mesh(_shown, B.sphere(0.016 * len + 0.006, 8), Vector3(0.09 * slim * len, -len * 0.86, len * 0.04), Color(0.95, 0.85, 0.2))  # silmä
	B.mesh(_shown, B.sphere(0.016 * len + 0.006, 8), Vector3(-0.09 * slim * len, -len * 0.86, len * 0.04), Color(0.95, 0.85, 0.2))
	if nom == "ahven":
		for k in 5:
			B.mesh(_shown, B.boxm(Vector3(0.23 * slim, 0.025, 0.36 * slim) * len), Vector3(0, -len * (0.25 + k * 0.11), -len * 0.02), back.darkened(0.45))
	if nom in ["hauki", "ukko"]:
		for k in 14:
			var a := k * 2.39
			B.mesh(_shown, B.sphere(0.018 * len + 0.004, 6), Vector3(cos(a) * 0.105 * slim * len, -len * (0.2 + (k % 7) * 0.09),
				-absf(sin(a)) * 0.17 * slim * len), Color(0.82, 0.8, 0.55))
	if nom == "kirjolohi" or nom == "taimen":
		# Kyljen kuviot ruumiin pintaan: sivu +X, korkeus pystyakselilla (ruumis on ellipsoidi pituus len).
		var spots_n := 12 if nom == "kirjolohi" else 9
		for k in spots_n:
			var d := (float(k % 6) / 5.0 - 0.5) * 0.7  # paikka ruumiin pituudella (-0.35..0.35)
			var f := sqrt(1.0 - 4.0 * d * d)
			var a2 := 0.5 + (k / 6) * 0.5 + (k % 3) * 0.25  # kulma kyljen ja selän välillä
			var sx := cos(a2) * 0.11 * slim * len * f
			var sz := -sin(a2) * 0.18 * slim * len * f
			var sp := Vector3(sx, -len * (0.5 + d), sz)
			if nom == "kirjolohi":
				B.mesh(_shown, B.sphere(0.012 * len + 0.003, 5), sp * 1.02, Color(0.1, 0.1, 0.12))
			else:
				B.mesh(_shown, B.sphere(0.014 * len + 0.004, 6), sp * 1.0, Color(0.95, 0.92, 0.7))
				B.mesh(_shown, B.sphere(0.009 * len + 0.003, 6), sp * 1.06, Color(0.85, 0.12, 0.1))
	if nom == "kirjolohi":  # punertava raita kyljessä: palasia ruumiin pintaa pitkin
		for k in 7:
			var d2 := (k / 6.0 - 0.5) * 0.6
			var f2 := sqrt(1.0 - 4.0 * d2 * d2)
			B.mesh(_shown, B.boxm(Vector3(0.012, 0.1, 0.06) * len), Vector3(0.11 * slim * len * f2 * 0.995, -len * (0.5 + d2), 0.0), Color(1.0, 0.5, 0.62))
	if nom == "ukko":  # kyljessä vanhoja uistimia kuin mitaleita
		for k in 3:
			var u := B.mesh(_shown, B.sphere(0.03, 8), Vector3(0.1 * len * slim, -len * (0.4 + k * 0.12), -0.02), [Color(0.85, 0.86, 0.9), Color(0.9, 0.7, 0.2), Color(0.85, 0.48, 0.25)][k])
			u.scale = Vector3(0.4, 0.2, 1.2)
	Sfx.play("water", -6.0, 1.6)


func _update_splashes(delta: float) -> void:
	if _shown != null:
		_shown_t -= delta
		# Pieni kala nostetaan siimassa silmien eteen, Ukkoa pidellään vaakatasossa rinnan edessä.
		var side := dir.cross(Vector3.UP).normalized()
		var big: bool = _shown.get_meta("ukko", false)
		var at := spot + dir * (0.75 if big else 0.6) + side * (0.0 if big else 0.25) + Vector3(0, 1.75 if not big else 1.2, 0)
		_shown.global_position = at
		var flap := sin(_t * 9.0) * 0.25 * clampf(_shown_t - 1.0, 0.0, 1.0)
		if big:  # pituus sivusuunnassa vaakatasossa rinnan edessä, kädet kalan alla; vapa laskettu maahan
			var yb := side.rotated(dir, flap * 0.3)
			var zb := dir.cross(yb).normalized()
			_shown.global_basis = Basis(dir, yb, zb)
			var c := at  # kalan keskikohta pelaajan edessä (origo pyrstössä, ruumis -Y:n suuntaan)
			_shown.global_position = c + yb * 0.65
			_rod.visible = false
			var inv := _body.global_transform.affine_inverse()
			_body.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * (c + side * 0.3 - Vector3(0, 0.08, 0)), inv * (spot + side * 0.6 + Vector3(0, 0.9, 0)))
			_body.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", inv * (c - side * 0.3 - Vector3(0, 0.08, 0)), inv * (spot - side * 0.6 + Vector3(0, 0.9, 0)))
		else:
			_shown.rotation = Vector3(flap, B.yaw_to(-dir) + sin(_t * 1.5) * 0.4, sin(_t * 6.0) * 0.12)
		if _shown_t <= 0.0:
			_shown.queue_free()
			_shown = null
	for s in _splashes:
		s[1] += delta
		var k: float = s[1] / 0.8
		var ring: MeshInstance3D = s[0]
		if is_instance_valid(ring):
			ring.scale = Vector3(1 + k * 4.0, 0.06, 1 + k * 4.0) * s[2]
			(ring.material_override as StandardMaterial3D).albedo_color.a = 0.7 * (1.0 - k)
		for dr in s[3]:
			var n: Node3D = dr[0]
			if is_instance_valid(n):
				dr[1].y -= 9.8 * delta
				n.position += dr[1] * delta
	for s in _splashes.filter(func(x): return x[1] >= 0.8):
		if is_instance_valid(s[0]):
			s[0].queue_free()
		for dr in s[3]:
			if is_instance_valid(dr[0]):
				dr[0].queue_free()
	_splashes = _splashes.filter(func(x): return x[1] < 0.8)
