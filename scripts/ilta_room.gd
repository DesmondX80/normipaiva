extends RefCounted
## Kolmiomittauksen iltakivojen yhteiset palat (lettukisa, karaoke; räsytuppi tekee samat omassa tiedostossaan):
## naisen olohuone (rasvanappi_hall.gd, valot päällä) talon yläpuolelle omalle näkyvyyskerrokselle, hahmo istumaan
## jakkaralle (bar_game.gd _seat -malli), seisova hahmo ja puhekupla käyttöliittymään puhujan pään kohdalle.

const Hall := preload("res://scripts/rasvanappi_hall.gd")
const Rasva := preload("res://scripts/rasvanappi_game.gd")
const Looks := preload("res://scripts/looks.gd")
const B := preload("res://scripts/build.gd")
const MG := preload("res://scripts/mg_draw.gd")

const WOOD := Color(0.55, 0.38, 0.22)


## Hallin näkyvyyskerros solmulle ja lapsille (kuten rasvanappi_hall.gd _set_layers; toimii myös saunalle ja pihalle).
static func set_layers(n: Node) -> void:
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers = Hall.LAYER
	if n is Light3D:
		(n as Light3D).light_cull_mask = Hall.LAYER
	for c in n.get_children():
		set_layers(c)


## Olohuone ankkurin yläpuolelle (250 m): halli on top_level, joten kameran ja esineiden paikat annetaan hallin
## omissa koordinaateissa (transform, ei global_transform).
static func hall(anchor: Node3D, style: Dictionary, sun: DirectionalLight3D) -> Node3D:
	var h := Hall.new()
	h.room = Rasva.ROOM
	h.door_y = Rasva.DOOR_Y
	h.style = style if not style.is_empty() else {"olohuone": true}
	anchor.get_parent().add_child(h)
	h.top_level = true
	h.global_transform = Transform3D(Basis(), anchor.global_position + Vector3(0, 250, 0))
	h.build(Rasva.OBST, [], {}, sun)
	return h


static func camera(h: Node3D) -> Camera3D:
	var cam := Camera3D.new()
	cam.fov = 50.0
	cam.cull_mask = Hall.LAYER
	cam.environment = h._env
	h.add_child(cam)
	return cam


## Hahmo istumaan: lantio kohtaan seat (hallin koordinaatit, lattiataso y = 0), kasvot suuntaan face (-Z on hahmon
## etu, bar_game.gd _seat). lift nostaa hahmoa, jotta Sitting_Idle-jalkaterät eivät mene lattiaan. Palauttaa hahmon.
static func seat(h: Node3D, look: Dictionary, at: Vector3, face: Vector3, lift := 0.08) -> Node3D:
	var c := Looks.make(h, look)
	c.rotation.y = atan2(-face.x, -face.z)
	c.play("Sitting_Idle", 0.0)
	c.anim.advance(0.01)
	var pel: Vector3 = c.basis * c.bone_position("pelvis")
	c.position = Vector3(at.x - pel.x, lift, at.z - pel.z)
	set_layers(c)
	return c


## Jakkara istuvan hahmon alle: kansi pakaroiden kohdalla (lantion luu noin 10 cm istuinpinnan yllä), mitattu hahmosta.
static func stool(h: Node3D, c: Node3D, at: Vector3) -> void:
	var sh: float = h.to_local(c.to_global(c.bone_position("pelvis"))).y - 0.1
	B.mesh(h, B.cyl(0.19, 0.19, 0.05, 16), Vector3(at.x, sh - 0.025, at.z), WOOD.lightened(0.1))
	for k in 3:
		var a := TAU * k / 3.0
		B.mesh(h, B.cyl(0.018, 0.022, sh - 0.05, 6), Vector3(at.x + cos(a) * 0.13, (sh - 0.05) / 2.0, at.z + sin(a) * 0.13),
			WOOD.darkened(0.2))
	set_layers(h)


## Seisova hahmo kohdassa at kasvot suuntaan face.
static func stand(h: Node3D, look: Dictionary, at: Vector3, face: Vector3, anim := "Idle") -> Node3D:
	var c := Looks.make(h, look)
	c.rotation.y = atan2(-face.x, -face.z)
	c.position = at
	c.play(anim, 0.0)
	set_layers(c)
	return c


## Puhekupla käyttöliittymään: laatikko puhujan pään yläpuolelle (projisoitu), ruudun sisään ja ylhäältä top_min:n
## alle; nokka osoittaa puhujan päähän.
static func bubble(ui: Control, cam: Camera3D, c: Node3D, text: String, top_min := 64.0, bottom_room := 200.0) -> void:
	if text == "" or c == null or cam == null:
		return
	var vs := ui.size
	var font := ThemeDB.fallback_font
	var head := cam.unproject_position(c.to_global(c.bone_position("Head")) + Vector3(0, 0.12, 0))
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	var w := minf(tw + 28.0, 360.0)
	var lines := clampi(ceili(tw * 1.08 / (w - 28.0)), 1, 3)
	var bh := 22.0 * lines + 18.0
	var r := Rect2(head.x - w / 2.0, head.y - bh - 34.0, w, bh)
	r.position.x = clampf(r.position.x, 10.0, vs.x - w - 10.0)
	r.position.y = clampf(r.position.y, top_min, vs.y - bh - bottom_room)
	var tail := head if head.y > r.end.y + 8.0 else Vector2(head.x, r.end.y + 24.0)
	MG.bubble(ui, r, tail, "", 18)
	ui.draw_multiline_string(font, r.position + Vector2(14, 27), text, HORIZONTAL_ALIGNMENT_CENTER, w - 28.0, 18, lines,
		Color(0.1, 0.08, 0.06))


## Kerronta- tai tilannelaatikko.
static func box(ui: Control, r: Rect2, col := Color(0.05, 0.04, 0.03, 0.8)) -> void:
	ui.draw_rect(r, col)
	ui.draw_rect(r, Color(1, 1, 1, 0.25), false, 1.0)


## Hahmon pään nyökkäys (syönti, laulu, hengitys): kaula eteen kulmalla a (rad).
static func nod(c: Node3D, a: float) -> void:
	c.set_override("neck_01", Vector3.RIGHT, a)
