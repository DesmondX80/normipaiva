extends Node
## Kameranohjaus ulkona, autoload "CamCtl": V vaihtaa kolmannen persoonan ja FPS:n välillä,
## hiiri kiertää kameraa (klikkaa ikkunaa lukitaksesi hiiren, Esc vapauttaa).
## Kolmannessa persoonassa kamera palaa itsestään taakse, kun hiirtä ei liikuteta ja liikutaan.
## FPS:ssä pelaajan oma vartalo piilotetaan kerroksella 2.

const SENS := 0.0032
const HIDE_LAYER := 2  # pelaajan oma vartalo (bitti 2)
const RECENTER_AFTER := 1.8

var fps := false
var yaw := 0.0  # poikkeama suunnasta, jonne pelaaja katsoo
var pitch := -0.12
var _idle := 99.0
var _mode_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_mode_label = Label.new()
	_mode_label.add_theme_font_size_override("font_size", 22)
	_mode_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_mode_label.add_theme_constant_override("outline_size", 8)
	_mode_label.anchor_left = 0.5
	_mode_label.anchor_right = 0.5
	_mode_label.offset_left = -200
	_mode_label.offset_right = 200
	_mode_label.offset_top = 110
	_mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(_mode_label)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sens: float = SENS * Settings.get_v("mouse_sens")
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * inv, -1.2 if fps else -0.9, 1.1 if fps else 0.45)
		_idle = 0.0
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == KEY_V:
			fps = not fps
			yaw = 0.0
			pitch = 0.0 if fps else -0.12
			_show("FPS-näkymä" if fps else "Kolmas persoona")


func _process(delta: float) -> void:
	_idle += delta
	if _mode_label.modulate.a > 0.0:
		_mode_label.modulate.a = maxf(0.0, _mode_label.modulate.a - delta * 0.6)


func _show(text: String) -> void:
	_mode_label.text = text + "  (V vaihtaa · hiiri kääntää)"
	_mode_label.modulate.a = 2.0


## Piilottaa solmun meshit FPS-kameralta (asettaa ne kerrokselle 2).
func mark_own_body(node: Node) -> void:
	for mi in node.find_children("*", "VisualInstance3D", true, false):
		(mi as VisualInstance3D).layers = 1 << (HIDE_LAYER - 1)
	if node is VisualInstance3D:
		node.layers = 1 << (HIDE_LAYER - 1)


## Päivittää kameran. target = pelaajan juuri, eye = silmien paikka maailmassa, dist/height = 3. persoonan etäisyys.
func update_camera(cam: Camera3D, target: Node3D, eye: Vector3, dist: float, height: float, moving: bool,
		delta: float, snap := false, shake := Vector3.ZERO) -> void:
	var heading := target.global_rotation.y
	cam.fov = Settings.get_v("fov")
	if not fps and moving and _idle > RECENTER_AFTER and Settings.get_v("auto_recenter"):
		yaw = lerp_angle(yaw, 0.0, 1.0 - exp(-2.0 * delta))
		pitch = lerpf(pitch, -0.12, 1.0 - exp(-2.0 * delta))
	var full_mask := 0xFFFFF
	if fps:
		cam.cull_mask = full_mask & ~(1 << (HIDE_LAYER - 1))
		var basis := Basis(Vector3.UP, heading + yaw) * Basis(Vector3.RIGHT, pitch)
		var fwd := -(Basis(Vector3.UP, heading)).z
		cam.global_transform = Transform3D(basis, eye + fwd * 0.12 + shake * 0.3)
		cam.near = 0.05
		return
	cam.cull_mask = full_mask
	cam.near = 0.1
	var look_at_pt := target.global_position + Vector3.UP * (height * 0.5)
	var orbit := Basis(Vector3.UP, heading + yaw) * Basis(Vector3.RIGHT, pitch)
	var want := look_at_pt + orbit * Vector3(0, height * 0.35, dist)
	# Estä kameraa menemästä seinän tai puun sisään.
	var q := PhysicsRayQueryParameters3D.create(look_at_pt, want)
	if target is CollisionObject3D:
		q.exclude = [target.get_rid()]
	var hit := target.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		want = hit.position + (look_at_pt - want).normalized() * 0.3
	if snap:
		cam.global_position = want
	else:
		cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-8.0 * delta))
	cam.look_at(look_at_pt + shake, Vector3.UP)
