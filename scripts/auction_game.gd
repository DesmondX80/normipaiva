extends Node3D
## Huutokauppa Saloisten seuraintalon salissa (#114), pelataan salin lavan edessä: salin oma huutaja Erkki seisoo
## lavalla kohteen vieressä, ja yleisössä istuvat mummo Elvi, pelaaja ja ukko Veikkonen tuoleillaan. Erkki vilkuilee
## yleisöä vuorotellen (kääntyy ja valokeila osoittaa katsottavaa), ja huuto menee läpi vain, kun hän katsoo sinua
## (E). Huutaessa käsi ja numerolappu nousevat. Kilpailijat huutavat omaan kattohintaansa asti. Jokaisen huudon
## jälkeen Erkki laskee puhekuplassa "ensimmäisen kerran, toisen kerran... kolmannen kerran!" ja nuija kopahtaa:
## viimeinen huutaja voittaa. Huuto ei voi ylittää rahoja. F / Esc luovuttaa. Solmu lisätään salin
## (kirppis_interior.gd) lapseksi. finished(won, price).

signal finished(won: bool, price: float)

const MG := preload("res://scripts/mg_draw.gd")
const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const SLOTS := 3  # 0 = mummo vasemmalla, 1 = sinä, 2 = ukko oikealla
const GAZE_MIN := 0.7
const GAZE_MAX := 1.3
const CALL_STEP := 1.5  # sekuntia per "kerta"
const CALLS := ["Ensimmäisen kerran...", "Toisen kerran...", "Kolmannen kerran... MYYTY!"]
const ROW_Z := 3.0
const SEAT_X := [-1.7, 0.0, 1.7]
const ELVI := {"model": "female", "shirt": Color(0.6, 0.32, 0.5), "pants": Color(0.25, 0.22, 0.3), "shoes": Color(0.3, 0.25, 0.2),
	"hair": "Hair_Buns", "hair_color": Color(0.9, 0.9, 0.9), "height": 1.56, "skin": Color(0.96, 0.8, 0.74), "belly": 0.5}
const VEIKKONEN := {"shirt": Color(0.32, 0.36, 0.26), "pants": Color(0.25, 0.23, 0.2), "shoes": Color(0.2, 0.15, 0.1),
	"hair": "Hair_Buzzed", "hair_color": Color(0.6, 0.6, 0.58), "beard": true, "height": 1.74, "skin": Color(0.94, 0.72, 0.62),
	"belly": 0.6}

var lot := "Napamoottori"
var start_price := 5.0
var step := 1.0
var money := 20.0
var drunk := 0.0
## Kilpailijat: [nimi, kattohinta] paikoille 0 ja 2.
var rivals := [["Mummo Elvi", 12.0], ["Ukko Veikkonen", 18.0]]
var interior  # kirppis_interior.gd: Erkki, lavan kohde ja puhekuplat

var _hud: CanvasLayer
var _ui: Control
var _info: Label
var _keys: Control
var _tip: Label
var _done := false
var _t := 0.0
var _price := 0.0
var _leader := -1  # -1 = kukaan ei ole huutanut
var _gaze := 0
var _start_frame := -1  # aloitusruudun E (keskustelun "Huutamaan") ei ole huuto
var _gaze_t := 1.0
var _call := -1  # -1 = ei laskentaa, 0..2 kerrat
var _call_t := 0.0
var _rival_t := -1.0  # kilpailijan huuto tulossa (viive)
var _flash := 0.0
var _flash_slot := -1
var _bang := 0.0  # nuijan isku (MYYTY)

var _bidders: Array[Node3D] = []
var _paddles: Array[Node3D] = []
var _erkki: Node3D
var _erkki_yaw := 0.0
var _spot: SpotLight3D
var _spot_at := Vector3.ZERO
var _lot_model: Node3D
var _cam: Camera3D


func _ready() -> void:
	add_to_group("esc_lopettaa")  # Esc lopettaa pelin: taukovalikko ei aukea (menu.gd)
	_start_frame = Engine.get_process_frames()
	_build()
	_cam = Camera3D.new()
	_cam.fov = 50.0
	add_child(_cam)
	_cam.current = true
	_cam.look_at_from_position(to_global(Vector3(0.45, 3.0, 5.7)), to_global(Vector3(0.15, 1.0, -2.2)))
	_build_hud()
	_price = start_price
	_tip.text = "Erkki: \"%s! Lähtöhinta %s euroa, kuka aloittaa?\"" % [lot, _eur(start_price)]
	_erkki_say("%s! Lähtöhinta %s euroa!" % [lot.get_slice(",", 0), _eur(start_price)], 2.5)


# --- Rakennus ------------------------------------------------------------------

func _build() -> void:
	if interior != null:
		if interior.walker != null:
			interior.walker.visible = false
		var i: int = interior.person_index("huutaja")
		if i >= 0:
			_erkki = interior._people[i]
			_erkki_yaw = _erkki.rotation.y
	# Tuolirivi lavan edessä ja huutajat: mummo, pelaaja ja ukko istuvat kasvot lavalle.
	for k in SLOTS:
		var at := Vector3(SEAT_X[k], 0, ROW_Z)
		var wood := Color(0.45, 0.28, 0.16)
		B.mesh(self, B.boxm(Vector3(0.45, 0.05, 0.42)), at + Vector3(0, 0.45, 0), wood)
		B.mesh(self, B.boxm(Vector3(0.45, 0.45, 0.04)), at + Vector3(0, 0.7, 0.2), wood)
		for lx in [-0.19, 0.19]:
			for lz in [-0.17, 0.17]:
				B.mesh(self, B.boxm(Vector3(0.04, 0.45, 0.04)), at + Vector3(lx, 0.22, lz), wood.darkened(0.2))
		var c := Looks.make(self, [ELVI, Looks.player(), VEIKKONEN][k])
		if k == 1:
			Looks.add_cap(c)
		c.play("Sitting_Idle", 0.0)
		c.anim.advance(0.01)
		var pelvis: Vector3 = c.bone_position("pelvis")
		c.position = at + Vector3(-pelvis.x, 0.05, 0.06 - pelvis.z)
		if k == 0:
			Looks.hunch(c, 0.2)
		_bidders.append(c)
		# Numerolappu: valkoinen levy ja varsi, kädessä ylhäällä huutaessa ja sylissä muuten.
		var pad := Node3D.new()
		add_child(pad)
		B.mesh(pad, B.cyl(0.008, 0.008, 0.22, 5), Vector3(0, -0.11, 0), Color(0.45, 0.3, 0.15))
		var plate := B.sign_plate(pad, str(17 + k * 9), Color(0.98, 0.97, 0.92), Color(0.1, 0.1, 0.1), 0.14, 40, Color(0.8, 0.15, 0.1))
		plate.position = Vector3(0, 0.07, 0)

		_paddles.append(pad)
	# Valokeila katossa: osoittaa sitä, jota Erkki katsoo.
	_spot = SpotLight3D.new()
	_spot.position = Vector3(0, 3.6, 0.0)
	_spot.light_color = Color(1.0, 0.95, 0.7)
	_spot.light_energy = 6.0
	_spot.spot_range = 8.0
	_spot.spot_angle = 14.0
	add_child(_spot)
	_spot_at = Vector3(SEAT_X[0], 1.0, ROW_Z)
	# Kohde lavan pöydällä: salin napamoottori tai oma malli muille kohteille.
	if interior != null and interior._lot != null:
		if not lot.begins_with("Napamoottori"):
			interior._lot.visible = false
			_lot_model = Node3D.new()
			_lot_model.position = interior._lot.position
			add_child(_lot_model)
			if lot.begins_with("Moccamaster"):
				B.mesh(_lot_model, B.boxm(Vector3(0.2, 0.36, 0.22)), Vector3(0, 0.06, 0), Color(0.75, 0.1, 0.1))
				var pot := B.mesh(_lot_model, B.cyl(0.08, 0.09, 0.16, 12), Vector3(0, -0.04, 0.12), Color(0.75, 0.85, 0.9))
				pot.transparency = 0.4
			else:
				B.mesh(_lot_model, B.boxm(Vector3(0.5, 0.2, 0.32)), Vector3(0, -0.02, 0), Color(0.7, 0.55, 0.35))
				for k in 5:
					B.mesh(_lot_model, B.boxm(Vector3(0.08, 0.14, 0.2)), Vector3(-0.18 + k * 0.09, 0.12, 0), Color(0.08, 0.08, 0.08))
			var tag := B.sign_plate(_lot_model, lot.get_slice(",", 0).to_upper(), Color(0.98, 0.97, 0.92), Color(0.1, 0.1, 0.1), 0.09, 22,
				Color(0.8, 0.15, 0.1))
			tag.position = Vector3(0.35, 0.32, 0.25)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.layer = 6
	add_child(_hud)
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	_hud.add_child(_ui)
	_info = _label(26, 40.0, false)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	_hud.add_child(_keys)
	_tip = _label(24, -90.0, true)
	_tip.add_theme_color_override("font_color", Color(1.0, 0.9, 0.55))


func _label(fs: int, y: float, bottom: bool) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 7)
	l.anchor_right = 1.0
	if bottom:
		l.anchor_top = 1.0
		l.anchor_bottom = 1.0
	l.offset_top = y
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


static func _eur(v: float) -> String:
	return ("%.2f" % v).replace(".", ",") if fmod(v, 1.0) != 0.0 else str(int(v))


func _next_price() -> float:
	return _price + step if _leader >= 0 else start_price


func _erkki_say(text: String, t := 2.0) -> void:
	if interior != null and _erkki != null:
		interior.say(_erkki, text, t)


# --- Peli ----------------------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_bang = maxf(0.0, _bang - delta)
	_ui.queue_redraw()
	_animate(delta)
	if _done:
		return
	_flash = maxf(0.0, _flash - delta)
	if Input.is_action_just_pressed("mount") or Input.is_key_pressed(KEY_ESCAPE):
		_finish(false)
		return
	# Huutajan katse vaeltaa; johtajaa hän ei juuri katso (etsii korkeampaa huutoa).
	_gaze_t -= delta
	if _gaze_t <= 0.0:
		var opts: Array = []
		for i in SLOTS:
			if i != _gaze and i != _leader:
				opts.append(i)
		_gaze = opts.pick_random() if not opts.is_empty() else (_gaze + 1) % SLOTS
		_gaze_t = randf_range(GAZE_MIN, GAZE_MAX) * (1.0 - drunk * 0.3)
		# Katse kilpailijaan: tämä huutaa, jos kattohinta sallii (pieni viive, ettei ole liian robotti).
		if _gaze != 1 and _gaze != _leader:
			var r: Array = rivals[0 if _gaze == 0 else 1]
			if _next_price() <= r[1] and randf() < 0.7:
				_rival_t = randf_range(0.25, 0.55)
	if _rival_t > 0.0:
		_rival_t -= delta
		if _rival_t <= 0.0 and _gaze != 1 and _gaze != _leader:
			var r: Array = rivals[0 if _gaze == 0 else 1]
			if _next_price() <= r[1]:
				_bid(_gaze)
				_tip.text = "%s nostaa lappunsa. Erkki: \"%s euroa! Kuulinko %s?\"" % [r[0], _eur(_price), _eur(_price + step)]
	if Input.is_action_just_pressed("interact") and Engine.get_process_frames() != _start_frame:  # "Huutamaan"-E ei ole huuto
		_player_bid()
	# Kerrat: viimeisimmän huudon jälkeen huutaja laskee kolmeen.
	if _call >= 0:
		_call_t -= delta
		if _call_t <= 0.0:
			_call += 1
			_call_t = CALL_STEP
			if _call >= CALLS.size():
				_tip.text = "Erkki: \"MYYTY! %s, %s euroa.\" *KOPS*" % [_who(_leader), _eur(_price)]
				_erkki_say("MYYTY! *KOPS*", 2.0)
				Sfx.play("rattle_hard", -2.0, 0.7)
				_bang = 0.6
				if _erkki != null:
					_erkki.restart("Interact", 0.1)
				_done = true
				var won := _leader == 1
				get_tree().create_timer(1.6).timeout.connect(func() -> void:
					_restore()
					finished.emit(won, _price)
					queue_free())
				return
			_erkki_say(CALLS[_call], CALL_STEP)
			Sfx.play("rattle", -8.0, 0.8)
	_info.text = "%s · hinta %s € · rahaa %s €" % [lot, _eur(_price), _eur(money)]
	_keys.set_text("%s huuda (kun Erkki katsoo sinua)   %s luovuta" % [Settings.cap("interact"), Settings.cap("mount")])


func _player_bid() -> void:
	if _leader == 1:
		_tip.text = "Sinä johdat jo. Odota, ettei kukaan huuda yli."
		return
	var next := _next_price()
	if next > money + 0.001:
		_tip.text = "Rahat ei riitä %s euroon." % _eur(next)
		return
	if _gaze != 1:
		_tip.text = "Erkki ei huomannut! Huuda, kun hän katsoo sinuun päin."
		return
	_bid(1)
	_tip.text = "Erkki: \"%s euroa takarivistä! Kuulinko %s?\"" % [_eur(_price), _eur(_price + step)]


func _bid(slot: int) -> void:
	_price = _next_price()
	_leader = slot
	_call = 0
	_call_t = CALL_STEP * 1.3
	_flash = 0.7
	_flash_slot = slot
	_rival_t = -1.0
	_erkki_say("%s euroa! Kuulinko %s?" % [_eur(_price), _eur(_price + step)], 1.6)
	Sfx.play("pickup", -6.0, 1.3 if slot == 1 else 0.9)


func _who(slot: int) -> String:
	if slot == 1:
		return "Sinulle"
	return str(rivals[0 if slot == 0 else 1][0])


func _finish(won: bool) -> void:
	if _done:
		return
	_done = true
	_restore()
	finished.emit(won, _price)
	queue_free()


## Salin Erkki ja kohde ennalleen, kävelijä näkyviin.
func _restore() -> void:
	if _erkki != null:
		_erkki.rotation.y = _erkki_yaw
		_erkki.play(_erkki.get_meta("pose"), 0.3)
	if interior != null:
		if interior.walker != null:
			interior.walker.visible = true
		if interior._lot != null:
			interior._lot.visible = interior.mode == "kirppis" and interior.lot_visible


# --- Animaatio -----------------------------------------------------------------

## Erkki kääntyy katsottavaan ja valokeila liukuu tämän päälle; huutajan käsi ja lappu nousevat.
func _animate(delta: float) -> void:
	var target := Vector3(SEAT_X[_gaze], 1.0, ROW_Z)
	_spot_at = _spot_at.lerp(target, 1.0 - exp(-7.0 * delta))
	_spot.look_at(to_global(_spot_at), Vector3.UP)
	_spot.light_energy = 9.0 if _gaze == 1 and not _done else 6.0
	if _erkki != null and not _done:
		var to := target - _erkki.position
		var yaw := atan2(-to.x, -to.z)
		_erkki.rotation.y = lerp_angle(_erkki.rotation.y, yaw, 1.0 - exp(-6.0 * delta))
	for k in SLOTS:
		var c := _bidders[k]
		var up := clampf(_flash * 3.0, 0.0, 1.0) if k == _flash_slot else (0.25 if k == _leader else 0.0)
		var inv := c.transform.affine_inverse()
		var shoulder := c.position + Vector3(0.2, 1.05, 0.0)
		var hand := shoulder + Vector3(0.05, -0.45 + up * 0.85, -0.25 + up * 0.05)
		if up > 0.02:
			c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", inv * hand, inv * (hand + Vector3(0.5, -0.3, 0.3)))
		else:
			c.clear_ik()
		_paddles[k].visible = up > 0.02  # sylissä lappu ei näy
		_paddles[k].position = hand + Vector3(0, 0.12, 0)


# --- HUD -----------------------------------------------------------------------

func _draw_ui() -> void:
	var font := ThemeDB.fallback_font
	var sz := _ui.size
	MG.sign(_ui, Rect2(Vector2(sz.x * 0.5 - 100, 82), Vector2(200, 56)), "%s €" % _eur(_price), Color(0.08, 0.1, 0.08), Color(1.0, 0.88, 0.3), 36,
		Color(0.55, 0.4, 0.2))
	for i in SLOTS:
		var head := to_global(_bidders[i].position + Vector3(0, 1.35, 0))
		if _cam.is_position_behind(head):
			continue
		var p := _cam.unproject_position(head)
		var seen := i == 1 and _gaze == 1 and not _done
		var name: String = ("SINÄ · Erkki katsoo!" if seen else "SINÄ") if i == 1 else str(rivals[0 if i == 0 else 1][0])
		var nw := 230.0 if seen else 160.0
		MG.box(_ui, Rect2(p + Vector2(-nw / 2.0, 30), Vector2(nw, 30)), Color(0.1, 0.45, 0.2, 0.85) if seen else Color(0, 0, 0, 0.55), 8)
		_ui.draw_string(font, p + Vector2(-nw / 2.0, 52), name, HORIZONTAL_ALIGNMENT_CENTER, nw, 20, Color(0.75, 1.0, 0.75) if i == 1 else Color.WHITE)
		if i == _leader:
			MG.sign(_ui, Rect2(p + Vector2(-50, -40), Vector2(100, 30)), "JOHTAA", Color(0.95, 0.75, 0.15), Color(0.25, 0.1, 0.0), 18,
				Color(0.5, 0.3, 0.05))
