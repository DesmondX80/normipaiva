extends Node3D
## Tappelija Street Fighter -tilaan: liike X-akselilla, hyppy, torjunta ja laaja liikevalikoima.
## Ohjaus tulee cmd-sanakirjasta, jonka fight.gd täyttää joka ruutu (pelaaja tai tekoäly):
## attack = perusliike ("punch" / "kick" / "bag" / "wave"), ja suunta valitsee muunnelman:
##   alas + lyönti = pystykoukku, alas + potku = jalkapyyhkäisy, eteen + potku = kiertopotku,
##   ilmassa potku = lentopotku, ilmassa lyönti = ilmalyönti.

const B := preload("res://scripts/build.gd")
const Looks := preload("res://scripts/looks.gd")

const GRAVITY := 20.0
const WALK := 2.8
const JUMP := 7.0
const STAGE := 7.0

## startup / active / recover sekunteina, range metreinä, lunge = syöksy eteen, launch = nosto ilmaan,
## stun = vastustajan tainnutus, low = osuu vain maassa olevaan.
const ATTACKS := {
	"punch": {"startup": 0.07, "active": 0.1, "recover": 0.14, "range": 1.25, "dmg": 6.0, "push": 1.8, "lunge": 2.8},
	"kick": {"startup": 0.13, "active": 0.14, "recover": 0.24, "range": 1.7, "dmg": 10.0, "push": 3.4, "lunge": 3.2},
	"uppercut": {"startup": 0.1, "active": 0.14, "recover": 0.32, "range": 1.15, "dmg": 12.0, "push": 1.5, "lunge": 1.8,
		"launch": 7.5, "stun": 0.7},
	"sweep": {"startup": 0.1, "active": 0.14, "recover": 0.3, "range": 1.8, "dmg": 8.0, "push": 1.2, "lunge": 2.0,
		"launch": 2.5, "stun": 0.9, "low": true},
	"spin": {"startup": 0.16, "active": 0.2, "recover": 0.3, "range": 1.9, "dmg": 15.0, "push": 5.0, "lunge": 4.5},
	"flykick": {"startup": 0.04, "active": 0.4, "recover": 0.12, "range": 1.5, "dmg": 13.0, "push": 4.0},
	"airpunch": {"startup": 0.05, "active": 0.14, "recover": 0.1, "range": 1.25, "dmg": 7.0, "push": 2.2},
	"bag": {"startup": 0.3, "active": 0.14, "recover": 0.35, "range": 1.5, "dmg": 22.0, "push": 5.5, "lunge": 3.0},
	"wave": {"startup": 0.4, "active": 0.05, "recover": 0.4, "range": 0.0, "dmg": 14.0, "push": 3.0},
	# Kaljan heitto (eteen + L): tölkki lentää kaaressa (fight.spawn_can), osuma kaataa.
	"throw": {"startup": 0.22, "active": 0.05, "recover": 0.3, "range": 0.0, "dmg": 26.0, "push": 5.5, "launch": 6.0, "stun": 0.9},
}
const ATTACK_ANIMS := {
	"punch": "Punch_Jab", "kick": "Punch_Cross", "uppercut": "Punch_Cross", "sweep": "Crouch_Idle",
	"spin": "Punch_Cross", "flykick": "Jump", "airpunch": "Punch_Jab", "bag": "Punch_Cross", "wave": "Spell_Simple_Shoot",
	"throw": "Punch_Cross",
}

var fight: Node3D
var opponent: Node3D
var display_name := ""
var special := "bag"
var hp := 100.0
var max_hp := 100.0
var dmg_mult := 1.0
var facing := 1.0
var state := "idle"  # idle, walk, attack, block, hit, ko
var cmd := {"move": 0.0, "jump": false, "block": false, "attack": ""}

var body: Node3D
var _t := 0.0
var _attack := ""
var _hit_done := false
var _stun := 0.0
var _vel := Vector2.ZERO
var _bag: MeshInstance3D
var _can: MeshInstance3D  # kaljatölkki kädessä ennen heittoa
var _celebrating := false


func setup(look: Dictionary) -> void:
	body = Looks.make(self, look)
	var bag := Node3D.new()
	_bag = B.mesh(bag, B.boxm(Vector3(0.26, 0.34, 0.18)), Vector3(0, -0.2, 0), Color(1.0, 0.45, 0.0))
	body.attach("hand_r", bag, Vector3(0, -0.05, 0))
	_bag.visible = false
	var can := Node3D.new()
	_can = B.mesh(can, B.cyl(0.033, 0.033, 0.12, 10), Vector3(0, -0.06, 0), Color(0.8, 0.75, 0.2))
	body.attach("hand_r", can, Vector3(0, -0.02, 0))
	_can.visible = false


## Voittajan tuuletus.
func celebrate() -> void:
	_celebrating = true
	body.clear_overrides()
	body.rotation = Vector3.ZERO
	body.play("Dance", 0.3)


func reset(x: float) -> void:
	position = Vector3(x, 0, 0)
	hp = max_hp
	state = "idle"
	_vel = Vector2.ZERO
	_celebrating = false
	body.clear_overrides()
	body.rotation = Vector3.ZERO
	body.play("Idle", 0.0)


func on_ground() -> bool:
	return position.y <= 0.001


func update(delta: float) -> void:
	_t += delta
	if state != "ko" and state != "attack":
		facing = signf(opponent.position.x - position.x) if absf(opponent.position.x - position.x) > 0.05 else facing

	match state:
		"idle", "walk", "block":
			if cmd.attack != "":
				_start_attack(_variant(cmd.attack))
			elif cmd.block and on_ground():
				state = "block"
				_vel.x = 0.0
			elif cmd.jump and on_ground():
				_vel = Vector2(cmd.move * 3.6, JUMP)
				state = "idle"
			elif on_ground():
				_vel.x = cmd.move * WALK
				state = "walk" if absf(_vel.x) > 0.1 else "idle"
		"attack":
			var a: Dictionary = ATTACKS[_attack]
			if on_ground():
				_vel.x = move_toward(_vel.x, 0.0, 16.0 * delta)
			if _attack == "flykick" and not on_ground():
				_vel = Vector2(facing * 6.5, minf(_vel.y, -3.5))
			if _t >= a.startup and not _hit_done:
				if _attack == "throw":
					_hit_done = true
					fight.spawn_can(self)
				elif _attack == "wave":
					_hit_done = true
					fight.spawn_wave(self)
				elif _t <= a.startup + a.active:
					_hit_done = _try_hit(a)
			if _t >= a.startup + a.active + a.recover or (_attack == "flykick" and on_ground() and _t > 0.1):
				state = "idle"
				body.rotation = Vector3.ZERO
		"hit":
			_vel.x = move_toward(_vel.x, 0.0, 10.0 * delta)
			if _t >= _stun and on_ground():
				state = "idle"
		"ko":
			_vel.x = move_toward(_vel.x, 0.0, 6.0 * delta)

	if not on_ground() or _vel.y > 0.0:
		_vel.y -= GRAVITY * delta
	position.x = clampf(position.x + _vel.x * delta, -STAGE, STAGE)
	var was_air := position.y > 0.05
	position.y = maxf(0.0, position.y + _vel.y * delta)
	if on_ground() and _vel.y < 0.0:
		if was_air and _vel.y < -3.0:
			fight.spawn_dust(position)
		_vel.y = 0.0
	_pose(delta)


## Perusliike + suunta -> varsinainen liike.
func _variant(base: String) -> String:
	if base in ["wave", "bag", "throw"]:
		return base
	if not on_ground():
		return "flykick" if base == "kick" else "airpunch"
	if cmd.block:
		return "uppercut" if base == "punch" else "sweep"
	if base == "kick" and signf(cmd.move) == facing and absf(cmd.move) > 0.3:
		return "spin"
	return base


func _start_attack(kind: String) -> void:
	state = "attack"
	_attack = kind
	_t = 0.0
	_hit_done = false
	var a: Dictionary = ATTACKS[kind]
	if on_ground():
		_vel.x = facing * a.get("lunge", 0.0)
	if kind == "uppercut":
		_vel.y = 3.0
	Sfx.play("whoosh", -4.0 if kind in ["spin", "flykick", "uppercut"] else -6.0, randf_range(0.8, 1.2))
	if kind != "wave" and kind != "throw":
		fight.spawn_swoosh(self, kind)


## Osumatarkistus koko aktiivisen ikkunan ajan; palauttaa true kun osui.
func _try_hit(a: Dictionary) -> bool:
	var dx: float = opponent.position.x - position.x
	var dy: float = opponent.position.y - position.y
	if a.get("low", false) and not opponent.on_ground():
		return false
	if signf(dx) == facing and absf(dx) <= a.range and absf(dy) < 1.4:
		var blocked: bool = opponent.take_hit(a.dmg * dmg_mult, facing, a.push, a.get("launch", 0.0), a.get("stun", 0.32))
		fight.on_hit(self, opponent, blocked, _attack)
		return true
	return false


## Palauttaa true jos torjuttiin. launch nostaa ilmaan (pystykoukku), stun pidentää tainnutusta.
func take_hit(dmg: float, dir: float, push: float, launch := 0.0, stun := 0.32) -> bool:
	if state == "ko":
		return false
	if state == "block" and signf(facing) == -signf(dir):
		hp = maxf(1.0, hp - dmg * 0.15)
		_vel.x = dir * push * 0.5
		return true
	hp = maxf(0.0, hp - dmg)
	_vel.x = dir * push
	if launch > 0.0:
		_vel.y = launch
	elif push >= 3.0:
		_vel.y = 3.2 + push * 0.3  # kova osuma nostaa ilmaan
	_t = 0.0
	body.rotation = Vector3.ZERO
	if hp <= 0.0:
		state = "ko"
		_vel.y = maxf(_vel.y, 4.5)
	else:
		state = "hit"
		_stun = stun
	return false


func _pose(delta: float) -> void:
	var k := 1.0 - exp(-18.0 * delta)
	rotation.y = lerp_angle(rotation.y, -PI / 2.0 if facing > 0.0 else PI / 2.0, k)
	_bag.visible = state == "attack" and _attack == "bag"
	_can.visible = state == "attack" and _attack == "throw" and _t < ATTACKS.throw.startup
	if _celebrating:
		return
	var thigh_r := 0.0
	var thigh_l := 0.0
	var spine := 0.0
	var arm_r := 0.0
	var spin := 0.0
	match state:
		"idle":
			body.play("Idle", 0.15)
			arm_r = 0.4  # nyrkit koholla
		"walk":
			# Taaksepäin kävellessä animaatio toistetaan takaperin.
			body.play("Walk", 0.15, 1.9 * signf(_vel.x) * facing)
		"block":
			body.play("Crouch_Idle", 0.1)
		"attack":
			var a: Dictionary = ATTACKS[_attack]
			var total: float = a.startup + a.active + a.recover
			var anim_name: String = ATTACK_ANIMS[_attack]
			body.play(anim_name, 0.05, body.anim_length(anim_name) / total * 0.8)
			# Liikkeen vaihe 0..1..0: nousee aktiiviseen ikkunaan asti ja laskee palautuksessa.
			var hit_end: float = a.startup + a.active
			var ph := clampf(_t / hit_end, 0.0, 1.0) if _t < hit_end else clampf(1.0 - (_t - hit_end) / a.recover, 0.0, 1.0)
			var swing := sin(ph * PI * 0.5)
			match _attack:
				"punch", "airpunch":
					spine = -0.35 * swing
					arm_r = 0.5 * swing
				"kick":
					thigh_r = 1.85 * swing
					spine = 0.45 * swing
				"uppercut":
					arm_r = 1.6 * swing
					spine = 0.35 * swing
					thigh_l = 0.5 * swing
				"sweep":
					thigh_r = 1.4 * swing
					spine = -0.5 * swing
					spin = PI * clampf(_t / hit_end, 0.0, 1.0)
				"spin":
					thigh_r = 1.7 * swing
					spine = 0.5 * swing
					spin = TAU * clampf(_t / (hit_end + 0.05), 0.0, 1.0)
				"flykick":
					thigh_r = 1.9
					thigh_l = -0.6
					spine = 0.35
				"throw":
					spine = -0.4 * swing
					arm_r = 1.5 * swing
				"bag":
					spine = -0.5 * swing
					arm_r = 1.0 * swing
		"hit":
			body.play("Hit_Chest", 0.05, 1.6)
			spine = 0.5
		"ko":
			body.play("Death01", 0.1, 1.3)
	if not on_ground() and state in ["idle", "walk"]:
		body.play("Jump", 0.1)
	body.rotation.y = spin
	body.set_override("thigh_r", Vector3.RIGHT, thigh_r)
	body.set_override("thigh_l", Vector3.RIGHT, thigh_l)
	body.set_override("spine_01", Vector3.RIGHT, spine)
	body.set_override("upperarm_r", Vector3.RIGHT, arm_r)
