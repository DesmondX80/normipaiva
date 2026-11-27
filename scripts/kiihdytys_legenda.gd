extends CanvasLayer
## Legendaarinen hetki "kiihdytys" (Kiihdytyksen voittaja): mopojen kiihdytyksen (mopo_race.gd) ensimmäinen voitto
## lavastetaan Vaalantien suoralla. Vaiheet:
##   maali     maaliviiva hidastettuna tien vierestä: punainen keula ylittää viivan ensin, kuva pysähtyy salaman ajaksi,
##             lippu laskee ja vastustaja tulee perässä; renkaista savua
##   ilme      vastustajan lähikuva: pudistaa päätään ja katsoo tankkiinsa
##   keulinta  voittaja ajaa takaisin keula pystyssä toinen nyrkki ilmassa, mopopojat hurraavat ja töräyttävät torvea
##   tyonto    mopopoikien sääntö: hävinnyt työntää mopon takaisin Zabukille pää painuksissa, kaverit nauravat
##   otsikko   voittaja maaliviivalla nyrkki ylhäällä, katsojat ympärillä, kultainen otsikko ja aika
## Paikka ja hahmot tulevat kisasta (race: mopo_race.gd): rata, mopot ajajineen, lipputyttö ja lähettäjä. Koordinaatit
## ovat kisasolmun paikallisia; radan suunta d (_dir), sivu +s (_side) on katsojien puoli (lipputyttö), pelaajan kaista
## -LANE. Mopon etu on -Z, takapyörän kosketus mallissa (0, 0, 0,6) (mopo.gd). Hahmon etu -Z (Looks).

signal finished

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")
const Mopo := preload("res://scripts/mopo.gd")
const Room := preload("res://scripts/ilta_room.gd")

const T := {"maali": 4.6, "ilme": 3.6, "keulinta": 4.8, "tyonto": 4.2, "otsikko": 5.8}
const ORDER := ["maali", "ilme", "keulinta", "tyonto", "otsikko"]
const REAR := Vector3(0, 0, 0.6)  # takapyörän kosketus mopon mallissa
const SLOW := 2.6  # hidastuksen nopeus (m/s)
const FREEZE := 0.45  # kuva pysähtyy, kun keula ylittää viivan
const KEUL_V := 3.3  # keulinnan nopeus (m/s)

var race: Node3D
var lines := {}  # ilme, keuli, tyonto, sub (mopo_race.gd LEG_LINES)
var opp_short := "Pete"

var phase := ""
var _t := 0.0
var _cam: Camera3D
var _ui: Control
var _keys: Node
var _story := ""
var _bub := {}  # hahmo -> repliikki
var _once := {}
var _shake := 0.0
var _flash := 0.0
var _me_rider: Node3D
var _opp_rider: Node3D
var _flagger: Node3D
var _starter: Node3D
var _kid: Node3D
var _pusher: Node3D  # hävinnyt jalan, työntää mopoa
var push_grips := {}  # työntäjän kädet mopon kehyksessä ("_l"/"_r" -> kohta), testi mittaa
var _flag: Node3D
var _props: Array[Node3D] = []
var _smoke: Array = []  # [mesh, ikä, nopeus]
var _smoke_t := 0.0
var _s_me := 0.0
var _s_opp := 0.0
var _gap := 1.5
var _cross_t := -1.0  # pelaajan viivan ylitys (vaiheen aika)
var _opp_cross_t := -1.0
var _flag_down := 0.0  # 0 = lippu ylhäällä heiluu, 1 = laskettu


func _ready() -> void:
	layer = 6
	_cam = race._cam
	_me_rider = race._my_model.get_meta("rider")
	_opp_rider = race._opp_model.get_meta("rider")
	_flagger = race._flagger
	_starter = race._starter
	_ui = Control.new()
	_ui.anchor_right = 1.0
	_ui.anchor_bottom = 1.0
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.draw.connect(_draw_ui)
	add_child(_ui)
	_keys = preload("res://scripts/hint_bar.gd").new()
	_keys.compact = true
	_keys.centered = true
	add_child(_keys)
	_keys.set_text("%s ohita" % Settings.cap("interact"))
	var mt: float = race._me.time
	var ot: float = race._opp.time
	_gap = clampf((ot - mt) * 15.0, 0.8, 3.6) if ot > 0.0 and mt > 0.0 else 1.6
	# Ajajat satulan etureunaan ja kumarampaan, jotta kädet yltävät tangon kahvoihin (kisassa kädet leijuvat).
	for r in [_me_rider, _opp_rider]:
		r.position.z -= 0.2
		r.set_override("spine_01", Vector3.RIGHT, -0.6)
	_build_props()
	_begin("maali")


## Lippu lipputytön käteen, lähettäjä ja pikkupoika katsojiksi maalin luo, pikkupojan mopo parkkiin.
func _build_props() -> void:
	_flag = Node3D.new()
	race.add_child(_flag)
	_props.append(_flag)
	B.mesh(_flag, B.cyl(0.014, 0.014, 0.9, 8), Vector3(0, 0.45, 0), Color(0.55, 0.42, 0.25))
	B.mesh(_flag, B.cyl(0.024, 0.024, 0.03, 8), Vector3(0, 0.91, 0), Color(0.85, 0.85, 0.85))
	# Ruutulippu: 5 x 4 ruutua, kangas poispäin tangosta (+X), pieni laskos.
	var sq := 0.1
	for i in 5:
		for j in 4:
			var col := Color(0.06, 0.06, 0.07) if (i + j) % 2 == 0 else Color(0.96, 0.96, 0.94)
			var m := B.mesh(_flag, B.boxm(Vector3(sq, sq, 0.008)), Vector3(0.02 + sq * (i + 0.5), 0.88 - sq * (j + 0.5), 0.012 * sin(i * 1.7)), col)
			m.rotation.y = 0.12 * cos(i * 1.7)
	# Pikkupoika ja sen mopo (keltainen Tunturi kuten mopopojilla).
	_kid = Looks.make(race, {"shirt": Color(0.85, 0.72, 0.2), "pants": Color(0.2, 0.25, 0.42), "shoes": Color(0.9, 0.9, 0.9),
		"shoe": "lenkkari", "hair": "Hair_Buzzed", "hair_color": Color(0.35, 0.25, 0.15), "height": 1.62, "bulk": -0.4})
	_props.append(_kid)
	var mp := Node3D.new()
	race.add_child(mp)
	Mopo.build_model(mp)
	_recolor(mp, Color(0.15, 0.45, 0.75))
	_props.append(mp)
	_place_mopo(mp, race.DIST + 5.6, race.LANE + 3.9, -1.0, 0.0, 0.4)
	_stand(_starter, race.DIST + 2.4, race.LANE + 3.3)
	_stand(_kid, race.DIST + 4.1, race.LANE + 2.8)
	for c in [_starter, _kid]:
		c.play("Idle", 0.1)


func _recolor(root: Node3D, col: Color) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_override == B.mat(Color(0.72, 0.08, 0.06)):
			(n as MeshInstance3D).material_override = B.mat(col)


func _begin(p: String) -> void:
	phase = p
	_t = 0.0
	_bub.clear()
	match p:
		"maali":
			_s_me = race.DIST - 4.0
			_s_opp = _s_me - _gap
			_story = "Maaliviiva hidastettuna."
			race._engine.pitch_scale = 0.42
			race._engine.volume_db = -6.0
			race._engine.play()
		"ilme":
			race._engine.stop()
			_story = "%s ei usko silmiään." % opp_short
			_place_mopo(race._opp_model, race.DIST + 15.0, race.LANE, 1.0, 0.0)
			_place_mopo(race._my_model, race.DIST + 20.0, -race.LANE, 1.0, 0.0)
		"keulinta":
			_story = "Voittajan kunniakierros: keula pystyssä mopopoikien ohi."
			_flag_down = 0.0  # lippu taas ylös heilumaan
			_me_rider.set_override("spine_01", Vector3.RIGHT, -0.15)  # keulinnassa selkä suorana
			_opp_rider.clear_overrides()
			_opp_rider.set_override("spine_01", Vector3.RIGHT, -0.35)
			_opp_rider.visible = false
			_make_pusher()
			_place_mopo(race._opp_model, race.DIST + 17.0, race.LANE + 0.7, -1.0, 0.0)
			_pusher_follow(0.0)
			race._engine.pitch_scale = 1.25
			race._engine.volume_db = -9.0
			race._engine.play()
		"tyonto":
			race._engine.stop()
			_me_rider.clear_ik()
			_story = "Mopopoikien sääntö: hävinnyt työntää mopon takaisin Zabukille."
			_flag_down = 1.0  # lippu roikkuu kädessä
			_place_mopo(race._my_model, race.DIST - 9.0, 0.3, -1.0, 0.0)
			_pusher.play("Walk", 0.2, 0.7)
			for c in [_starter, _kid, _flagger]:
				c.clear_ik()
		"otsikko":
			race._engine.stop()
			_story = ""
			_flag_down = 0.0
			for c in [_starter, _kid, _flagger]:
				c.clear_ik()
			_place_mopo(race._my_model, race.DIST - 0.5, 0.0, 1.0, 0.0)
			_stand(_starter, race.DIST - 1.7, 1.9)
			_stand(_kid, race.DIST - 2.3, 2.9)
			_face(_starter, race._my_model.position)
			_face(_kid, race._my_model.position)
			_place_mopo(race._opp_model, race.DIST - 15.0, race.LANE + 0.7, -1.0, 0.0)
			_pusher.play("Walk", 0.2, 0.7)
			_me_rider.clear_ik()
			_me_rider.set_override("spine_01", Vector3.RIGHT, -0.2)  # voittaja suoristaa selkänsä, kasvot näkyvät
			Sfx.play("win", -4.0)


func _process(delta: float) -> void:
	_t += delta
	_shake = maxf(0.0, _shake - delta * 2.5)
	_flash = maxf(0.0, _flash - delta * 2.2)
	if Input.is_action_just_pressed("interact"):
		if phase != "otsikko":
			_begin("otsikko")
		elif _t > 1.2:
			_finish()
			return
	match phase:
		"maali":
			_step_maali(delta)
		"ilme":
			_step_ilme()
		"keulinta":
			_step_keulinta(delta)
		"tyonto":
			_step_tyonto(delta)
		"otsikko":
			_step_otsikko(delta)
	_update_flag()
	_update_smoke(delta)
	_ui.queue_redraw()
	if phase != "" and _t >= T[phase]:
		var i := ORDER.find(phase)
		if i == ORDER.size() - 1:
			_finish()
		else:
			_begin(ORDER[i + 1])


func _finish() -> void:
	if phase == "":
		return
	phase = ""
	race._engine.stop()
	for c in [_starter, _kid, _flagger, _me_rider, _opp_rider]:
		if is_instance_valid(c):
			c.clear_ik()
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	for s: Array in _smoke:
		(s[0] as Node3D).queue_free()
	_smoke.clear()
	finished.emit()
	queue_free()


# --- Vaiheet ------------------------------------------------------------------------

func _step_maali(delta: float) -> void:
	var dist: float = race.DIST
	var frozen := _cross_t >= 0.0 and _t - _cross_t < FREEZE
	if not frozen:
		_s_me += SLOW * delta
		_s_opp += SLOW * delta
	if _cross_t < 0.0 and _s_me + 0.58 >= dist:  # etupyörä viivalla
		_cross_t = _t
		_flash = 0.7
		_shake = 0.5
		Sfx.play("whoosh", -4.0, 0.6)
		_story = "Maaliviiva hidastettuna. Punainen keula ensin..."
	if _opp_cross_t < 0.0 and _s_opp + 0.58 >= dist:
		_opp_cross_t = _t
		_story = "...ja %s vasta perässä." % opp_short
	race._engine.pitch_scale = 0.05 if frozen else 0.42
	_flag_down = clampf((_t - _cross_t) / 0.35, 0.0, 1.0) if _cross_t >= 0.0 else 0.0
	_place_mopo(race._my_model, _s_me, -race.LANE, 1.0, 0.0)
	_place_mopo(race._opp_model, _s_opp, race.LANE, 1.0, 0.0)
	_grip(_me_rider, race._my_model)
	_grip(_opp_rider, race._opp_model)
	if not frozen:
		_puff(race._my_model, 0.07)
		_puff(race._opp_model, 0.07)
	# Kamera tien vierellä pelaajan puolella viivan kohdalla, matalalla, katsoo viivaa pitkin katsojien puolelle.
	var d := _eye_lat()
	var look := _P(dist + 0.4, 0.6, 0.95)
	_cam_at(_P(dist, -d, 0.55), look, _fov_for(d + 0.6, 1.95, 0.52))


func _eye_lat() -> float:
	return race.LANE + 5.0


func _step_ilme() -> void:
	var head := _bone_l(_opp_rider, "Head")
	var dv: Vector3 = race._dir(race.DIST + 15.0)
	var sv: Vector3 = race._side(race.DIST + 15.0)
	# Kamera ohjaustangon ulkopuolella vinosti edestä (tanko ja peilit eivät peitä kasvoja), pään korkeudella.
	var eye := head + dv * 1.7 - sv * 1.05 + Vector3(0, 0.02, 0)
	_cam_at(eye, head + Vector3(0, -0.22, 0), 40.0)
	_grip(_opp_rider, race._opp_model)
	if _t < 1.9:
		var k := clampf(_t / 0.3, 0.0, 1.0)
		_opp_rider.set_override("neck_01", Vector3.UP, sin(_t * 10.0) * 0.32 * k)
	else:
		var k := clampf((_t - 1.9) / 0.4, 0.0, 1.0)
		_opp_rider.set_override("neck_01", Vector3.RIGHT, -0.8 * k)  # katse tankkiin
	if _t > 0.4:
		_bub[_opp_rider] = "%s: %s" % [opp_short, lines.ilme]


func _step_keulinta(delta: float) -> void:
	var s: float = race.DIST + 13.0 - KEUL_V * _t
	var pitch := 0.42 * clampf(_t / 0.6, 0.0, 1.0) + 0.035 * sin(_t * 5.0)
	_place_mopo(race._my_model, s, 0.3, -1.0, pitch)
	_fist_up(_me_rider, 1.0)
	_grip(_me_rider, race._my_model, "_l")
	_puff(race._my_model, 0.07)
	for i in 2:
		var c: Node3D = [_starter, _kid][i]
		_cheer(c, _t + i * 0.37)
		_face(c, race._my_model.position)
	_cheer(_flagger, _t + 0.2, true)
	_face(_flagger, race._my_model.position)
	if _t > 2.3:  # pikkupoika on silloin seuraavan kameran kuvassa oikealla (lähettäjä jää reunan taakse)
		_bub[_kid] = "Pikkupoika: " + lines.keuli
	if _t > 1.4:
		if not _once.has("horn"):
			_once["horn"] = true
			Sfx.play("horn", -6.0, 1.3)
	# Kamera seuraa keulijaa matalalta vinosti edestä (4,4 m edellä, 1,8 m tien keskelle päin): keula ilmassa ja nyrkki
	# näkyvät, mopo keskellä ja isona (mopo ja ajaja 2,1 m = 55 % kuvan korkeudesta), katsojat oikealla reunalla.
	var mc: Vector3 = race._my_model.position + Vector3(0, 0.95, 0)
	var eye := _P(s - 4.4, 0.3 - 1.8, 0.7)
	_cam_at(eye, mc, _fov_for(eye.distance_to(mc), 2.1, 0.55))
	_pusher_follow(0.0)


func _step_tyonto(delta: float) -> void:
	var s: float = race.DIST + 2.6 - 0.95 * _t
	_place_mopo(race._opp_model, s, race.LANE + 0.7, -1.0, 0.0)
	_pusher_follow(_t)
	var chest := _bone_l(_pusher, "spine_03")
	_point(_starter, chest)
	_face(_starter, _pusher.position)
	_cheer(_kid, _t, false)
	_face(_kid, _pusher.position)
	_face(_flagger, _pusher.position)
	if _t > 0.6 and _t < 3.0:  # työntäjä ohittaa lähettäjän noin 3 s kohdalla ja peittää sen
		_bub[_starter] = "Lähettäjä: " + lines.tyonto
	elif _t >= 3.0:
		_bub.erase(_starter)
	var eye := _P(s - 4.6, race.LANE + 0.7 - 2.7, 1.45)
	_cam_at(eye, chest + Vector3(0, -0.05, 0), 46.0)


func _step_otsikko(delta: float) -> void:
	_fist_up(_me_rider, clampf(_t / 0.4, 0.0, 1.0))
	_grip(_me_rider, race._my_model, "_l")
	_cheer(_starter, _t)
	_cheer(_kid, _t + 0.4)
	_cheer(_flagger, _t + 0.2, true)
	_face(_flagger, race._my_model.position)
	var s: float = race.DIST - 15.0 - 0.6 * _t
	_place_mopo(race._opp_model, s, race.LANE + 0.7, -1.0, 0.0)
	_pusher_follow(_t)
	var look := _P(race.DIST - 1.2, 1.3, 0.85)
	var eye := _P(race.DIST + 7.0, -2.6, 2.0)
	_cam_at(eye, look, _fov_for(eye.distance_to(look), 2.1, 0.42))


# --- Hahmot ja rekvisiitta ----------------------------------------------------------

## Mopo paikalleen: origo radalla kohdassa s sivussa lat, suunta radan suuntaan (sign 1) tai vastaan (-1). Keulinta
## kiertää mallia takapyörän kosketuskohdan ympäri (kosketus pysyy tiessä).
func _place_mopo(m: Node3D, s: float, lat: float, sign: float, pitch: float, yaw_off := 0.0) -> void:
	var d: Vector3 = race._dir(s) * sign
	var yaw := atan2(-d.x, -d.z) + yaw_off
	var yb := Basis(Vector3.UP, yaw)
	var full := yb * Basis(Vector3.RIGHT, pitch)
	var origin := _P(s, lat, 0.02)
	var contact := origin + yb * REAR
	m.transform = Transform3D(full, contact - full * REAR)


func _stand(c: Node3D, s: float, lat: float) -> void:
	c.position = _P(s, lat, 0.0)


func _face(c: Node3D, at: Vector3) -> void:
	var v := at - c.position
	v.y = 0.0
	if v.length() > 0.05:
		c.rotation.y = B.yaw_to(v)


## Hävinnyt jalan: sama ulkonäkö kuin ajajalla, kävelee mopon vasemmalla puolella kädet tangossa.
func _make_pusher() -> void:
	if _pusher != null:
		return
	_pusher = Looks.make(race, (race.OPP_LOOK as Dictionary).duplicate(true))
	_props.append(_pusher)
	_pusher.play("Idle", 0.0)


func _pusher_follow(t: float) -> void:
	if _pusher == null:
		return
	var m: Node3D = race._opp_model
	var yb := Basis(Vector3.UP, m.rotation.y)
	_pusher.position = m.position + yb * Vector3(-0.45, 0, -0.26)  # kädet yltävät tankoon (olka-kahva alle 0,55 m)
	_pusher.position.y = m.position.y
	_pusher.rotation.y = m.rotation.y
	_pusher.set_override("neck_01", Vector3.RIGHT, -0.5)
	# Ulompi käsi tangon vasempaan kahvaan, mopon puoleinen käsi tangolle ohjainkannattimen viereen (mopon -X-puolella).
	var xr: float = m.to_local(_pusher.to_global(_pusher.bone_position("upperarm_r"))).x
	var xl: float = m.to_local(_pusher.to_global(_pusher.bone_position("upperarm_l"))).x
	var inner := "_r" if xr > xl else "_l"
	for lr in ["_l", "_r"]:
		var grip := Vector3(-0.08, 1.06, -0.46) if lr == inner else Vector3(-0.32, 1.08, -0.46)
		push_grips[lr] = grip
		var target := _pusher.to_local(race.to_global(m.position + yb * grip))
		var sh: Vector3 = _pusher.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		_pusher.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, target, sh + Vector3(s * 0.3, -0.45, 0.15))


## Ajajan kädet tangon kahvoihin (mopo.gd: kahvat (±0,32, 1,08, -0,46)); kumpi käsi mihin, lasketaan olan puolesta.
## skip: käsi ("_l"/"_r"), jota ei aseteta (nyrkki ilmassa).
func _grip(rider: Node3D, m: Node3D, skip := "") -> void:
	for lr in ["_l", "_r"]:
		if lr == skip:
			continue
		var sh: Vector3 = rider.bone_position("upperarm" + lr)
		var side := signf(m.to_local(rider.to_global(sh)).x)
		var target := rider.to_local(m.to_global(Vector3(0.3 * side, 1.08, -0.46)))
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		rider.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, target, sh + Vector3(s * 0.35, -0.3, 0.1))


## Toinen nyrkki ilmaan (vasen käsi), oikea pysyy kaasukahvassa.
func _fist_up(c: Node3D, w: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_l")
	var s := signf(sh.x) if sh.x != 0.0 else -1.0
	var rest: Vector3 = c.bone_position("hand_l")
	var up := sh + Vector3(s * 0.12, 0.56, -0.06)
	c.set_ik("arm_l", "upperarm_l", "lowerarm_l", "hand_l", rest.lerp(up, w), sh + Vector3(s * 0.45, 0.05, 0.25))


## Hurraus: kädet ilmaan ja pomppu tahdissa. flag_hand: oikea käsi pitää lippua (heiluu), vain vasen ylös.
func _cheer(c: Node3D, t: float, flag_hand := false) -> void:
	var bob := absf(sin(t * 6.0))
	for lr in ["_l", "_r"]:
		if flag_hand and lr == "_r":
			continue
		var sh: Vector3 = c.bone_position("upperarm" + lr)
		var s := signf(sh.x) if sh.x != 0.0 else (1.0 if lr == "_r" else -1.0)
		c.set_ik("arm" + lr, "upperarm" + lr, "lowerarm" + lr, "hand" + lr, sh + Vector3(s * 0.2, 0.46 + 0.08 * bob, -0.08),
			sh + Vector3(s * 0.45, 0.0, 0.25))
	if flag_hand:
		_flag_wave(c, t)


## Osoittaa kädellä kohdetta (oikea käsi), toinen lanteilla (animaatio).
func _point(c: Node3D, at_global: Vector3) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var dir := (c.to_local(at_global) - sh).normalized()
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", sh + dir * 0.55, sh + Vector3(s * 0.4, -0.35, 0.1))


## Lipputytön oikea käsi: lippu ylhäällä heiluu sivulta toiselle; _flag_down = 1 laskee sen eteen alas (maali).
func _flag_wave(c: Node3D, t: float) -> void:
	var sh: Vector3 = c.bone_position("upperarm_r")
	var s := signf(sh.x) if sh.x != 0.0 else 1.0
	var up := sh + Vector3(s * (0.1 + 0.22 * sin(t * 7.0)), 0.55, -0.12)
	var down := sh + Vector3(s * 0.22, -0.52, -0.12)  # käsi alas sivulle, lippu roikkuu
	var k := _flag_down * _flag_down * (3.0 - 2.0 * _flag_down)
	c.set_ik("arm_r", "upperarm_r", "lowerarm_r", "hand_r", up.lerp(down, k), sh + Vector3(s * 0.45, -0.1, 0.25))


## Lippu lipputytön oikeaan käteen: tanko jatkaa kyynärvartta.
func _update_flag() -> void:
	if phase != "keulinta" and phase != "otsikko":
		_flag_wave(_flagger, _t)
	var hand := _bone_l(_flagger, "hand_r")
	var elbow := _bone_l(_flagger, "lowerarm_r")
	var up := (hand - elbow).normalized()
	if up.length() < 0.5:
		up = Vector3.UP
	var fwd := Basis(Vector3.UP, _flagger.rotation.y) * Vector3(0, 0, -1)
	var x := up.cross(fwd).normalized()
	if x.length() < 0.5:
		x = Vector3.RIGHT
	var z := x.cross(up).normalized()
	_flag.transform = Transform3D(Basis(x, up, z), hand - up * 0.06)


# --- Savu (3D-pallot, haalistuvat) --------------------------------------------------

func _puff(m: Node3D, every: float) -> void:
	_smoke_t += get_process_delta_time()
	if _smoke_t < every:
		return
	_smoke_t = 0.0
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.85, 0.85, 0.83, 0.3)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	race.add_child(mi)
	mi.position = m.position + m.transform.basis * Vector3(randf_range(-0.1, 0.1), 0.12, 0.72)
	mi.scale = Vector3.ONE * 0.12
	var back := m.transform.basis * Vector3(0, 0, 1)
	_smoke.append([mi, 0.0, back * 0.6 + Vector3(randf_range(-0.2, 0.2), 0.35, randf_range(-0.2, 0.2))])


func _update_smoke(delta: float) -> void:
	for s: Array in _smoke:
		s[1] += delta
		var mi: MeshInstance3D = s[0]
		mi.position += (s[2] as Vector3) * delta
		var age: float = s[1]
		mi.scale = Vector3.ONE * (0.12 + 0.5 * minf(age / 0.9, 1.0))
		(mi.material_override as StandardMaterial3D).albedo_color.a = 0.3 * clampf(1.0 - age / 1.0, 0.0, 1.0)
	var keep: Array = []
	for s: Array in _smoke:
		if float(s[1]) < 1.0:
			keep.append(s)
		else:
			(s[0] as Node3D).queue_free()
	_smoke = keep


# --- Kamera ja apu ------------------------------------------------------------------

func _P(s: float, lat: float, y := 0.0) -> Vector3:
	return race._at(s) + race._side(s) * lat + Vector3(0, y, 0)


func _bone_l(c: Node3D, bone: String) -> Vector3:
	return race.to_local(c.to_global(c.bone_position(bone)))


func _cam_at(eye: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * 0.06 * _shake
	_cam.fov = fov
	_cam.look_at_from_position(race.to_global(eye + sh), race.to_global(look))


## Kuvakulma, jolla korkeus h etäisyydellä d täyttää osuuden frac kuvan korkeudesta.
func _fov_for(d: float, h: float, frac: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d * frac)))


# --- Piirto -------------------------------------------------------------------------

func _draw_ui() -> void:
	var vs := _ui.size
	var font := ThemeDB.fallback_font
	if _story != "":
		var r := Rect2(vs.x / 2.0 - 440, 24, 880, 52)
		Room.box(_ui, r)
		_ui.draw_string(font, r.position + Vector2(16, 33), _story, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 32, 19, Color(1.0, 0.92, 0.75))
	for c: Node3D in _bub:
		if is_instance_valid(c):
			Room.bubble(_ui, _cam, c, _bub[c], 90.0, 120.0)
	# Hidastuksen merkki ja maalikuvan aikaleima.
	if phase == "maali":
		var a := 0.6 + 0.4 * sin(_t * 6.0)
		_ui.draw_circle(Vector2(54, vs.y - 64), 9.0, Color(0.95, 0.15, 0.1, a))
		_ui.draw_string_outline(font, Vector2(72, vs.y - 56), "HIDASTUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 6, Color(0, 0, 0, 0.8))
		_ui.draw_string(font, Vector2(72, vs.y - 56), "HIDASTUS", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.95))
		if _cross_t >= 0.0:
			var tt := "%s s" % ("%.2f" % float(race._me.time)).replace(".", ",")
			_ui.draw_string_outline(font, Vector2(0, vs.y - 56), tt, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 40, 30, 8, Color(0, 0, 0, 0.85))
			_ui.draw_string(font, Vector2(0, vs.y - 56), tt, HORIZONTAL_ALIGNMENT_RIGHT, vs.x - 40, 30, Color(1.0, 0.85, 0.3))
	if phase == "otsikko":
		var a := clampf((_t - 0.7) / 0.8, 0.0, 1.0)
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.02, 0.05, 0.25 * a))
		var y := vs.y * 0.17
		_draw_checker(Vector2(vs.x / 2.0, y - 78.0), a)
		var title := "KIIHDYTYKSEN VOITTAJA"
		_ui.draw_string_outline(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 70, 12, Color(0.12, 0.04, 0.02, a))
		_ui.draw_string(font, Vector2(0, y), title, HORIZONTAL_ALIGNMENT_CENTER, vs.x, 70, Color(1.0, 0.82, 0.35, a))
		var sr := Rect2(vs.x / 2.0 - 400, vs.y - 158.0, 800, 84)
		_ui.draw_rect(sr, Color(0.05, 0.04, 0.03, 0.75 * a))
		var tt := "150 m · %s s" % ("%.2f" % float(race._me.time)).replace(".", ",")
		_ui.draw_string(font, sr.position + Vector2(0, 28), tt, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 20, Color(1.0, 0.85, 0.3, a))
		_ui.draw_multiline_string(font, sr.position + Vector2(18, 56), lines.sub, HORIZONTAL_ALIGNMENT_CENTER, sr.size.x - 36, 18, 2,
			Color(1.0, 0.94, 0.8, a))
	if _flash > 0.0:
		_ui.draw_rect(Rect2(Vector2.ZERO, vs), Color(1, 1, 1, _flash))


## Ruutulippunauha otsikon yllä: kaksi riviä ruutuja ääriviivoineen.
func _draw_checker(c: Vector2, a: float) -> void:
	var n := 14
	var sq := 18.0
	var x0 := c.x - n * sq / 2.0
	for i in n:
		for j in 2:
			var col := Color(0.08, 0.08, 0.09, a) if (i + j) % 2 == 0 else Color(0.97, 0.96, 0.92, a)
			_ui.draw_rect(Rect2(Vector2(x0 + i * sq, c.y + j * sq - sq), Vector2(sq, sq)), col)
	_ui.draw_rect(Rect2(Vector2(x0, c.y - sq), Vector2(n * sq, sq * 2)), Color(0.35, 0.18, 0.03, a), false, 3.0)
