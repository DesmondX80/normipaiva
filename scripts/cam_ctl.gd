extends Node
## Kameranohjaus ulkona, autoload "CamCtl": V vaihtaa kolmannen persoonan ja FPS:n välillä,
## hiiri kiertää kameraa ilman klikkausta: hiiri lukitaan aina kun peli pyörii ja ikkuna on aktiivinen
## (valikko ja kartta pysäyttävät pelin ja vapauttavat kursorin). Asetus "mouse_look" pois: hiiri jää vapaaksi
## ja kamera pysyy pelaajan takana, paitsi minipeleissä, joissa hiirellä tähdätään (need_mouse).
## Kolmannessa persoonassa kamera palaa itsestään taakse, kun hiirtä ei liikuteta ja liikutaan.
## FPS:ssä pelaajan oma vartalo piilotetaan kerroksella 2.

const SENS := 0.0032
const HIDE_LAYER := 2  # pelaajan oma vartalo (bitti 2)
const RECENTER_AFTER := 1.8

var fps := false
var yaw := 0.0  # poikkeama suunnasta, jonne pelaaja katsoo
var pitch := -0.12
var _idle := 99.0
var need_mouse := false  # minipeli tähtää hiirellä asetuksesta riippumatta
var free_mouse := false  # minipeli käyttää näkyvää kursoria (esim. PA-johtojen kytkentä)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and Settings.get_v("mouse_look"):
		var sens: float = SENS * Settings.get_v("mouse_sens")
		var inv := -1.0 if Settings.get_v("invert_y") else 1.0
		yaw -= event.relative.x * sens
		pitch = clampf(pitch - event.relative.y * sens * inv, -1.2 if fps else -0.9, 1.1 if fps else 0.45)
		_idle = 0.0
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_V:
			fps = not fps
			yaw = 0.0
			pitch = 0.0 if fps else -0.12


## Kosketusveto (Touch-autoload): kuten hiiren liike lukitulla hiirellä.
func touch_look(rel: Vector2) -> void:
	var sens: float = SENS * Settings.get_v("mouse_sens")
	var inv := -1.0 if Settings.get_v("invert_y") else 1.0
	yaw -= rel.x * sens
	pitch = clampf(pitch - rel.y * sens * inv, -1.2 if fps else -0.9, 1.1 if fps else 0.45)
	_idle = 0.0


func _process(delta: float) -> void:
	_idle += delta
	if Touch.active:
		return  # kosketusnäytöllä hiirtä ei lukita (napautukset toimivat hiiren klikkauksina valikoissa)
	if not get_tree().paused and DisplayServer.window_is_focused():
		var want := Input.MOUSE_MODE_CAPTURED if need_mouse or Settings.get_v("mouse_look") else Input.MOUSE_MODE_VISIBLE
		if free_mouse:
			want = Input.MOUSE_MODE_VISIBLE
		if Input.mouse_mode != want:
			Input.mouse_mode = want


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
	if not Settings.get_v("mouse_look") and not Touch.active:
		yaw = lerp_angle(yaw, 0.0, 1.0 - exp(-4.0 * delta))
		pitch = lerpf(pitch, 0.0 if fps else -0.12, 1.0 - exp(-4.0 * delta))
	elif not fps and moving and _idle > RECENTER_AFTER and Settings.get_v("auto_recenter"):
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
