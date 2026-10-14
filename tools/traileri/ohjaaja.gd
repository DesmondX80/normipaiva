extends Node
## Trailerin ohjaaja: main.gd käynnistää tämän, kun komentorivillä on --trailer=id1,id2,... (ks. renderoi.gd).
## Jokainen otos lavastetaan (otokset.gd), annetaan asettua hetki ja kuvataan tarkalleen leikkauksen (leikkaus.gd)
## ruutumäärä. Ennen ensimmäistä otosta ja jokaisen otoksen jälkeen piirretään SEP_FRAMES ruutua täyttä magentaa:
## kokoa.gd erottaa niiden avulla otokset Movie Maker -tallenteesta (myös latausruudut jäävät pois).
## Esikatselu (--trailer-preview): ei tallennetta, vaan kuvat otoksen alusta, keskeltä ja lopusta kansioon --trailer-out.

const Otokset := preload("res://tools/traileri/otokset.gd")
const Teksti := preload("res://tools/traileri/teksti.gd")
const Leikkaus := preload("res://tools/traileri/leikkaus.gd")
const B := preload("res://scripts/build.gd")

const SEP_FRAMES := 4
const SEP_COLOR := Color(1, 0, 1)
const WARM_FRAMES := 24  # lavastuksen jälkeen ennen kuvausta (varjot, LOD ja fysiikka asettuvat)

var main: Node3D
var ids: PackedStringArray
var preview := false
var out_dir := ""

var cam: Camera3D
var overlay: CanvasLayer
var _sep: ColorRect
var _bars: Array[ColorRect] = []
var _texts: Control
var _bubbles: Array = []  # [Label3D, loppuaika]
var props: Array = []  # otoksen omat solmut (otokset.gd), poistetaan otoksen jälkeen
var _spec: Dictionary = {}
var _t := 0.0  # otoksen aika (s)


func _init(m: Node3D, shot_ids: PackedStringArray, prev: bool, out: String) -> void:
	main = m
	ids = shot_ids
	preview = prev
	out_dir = out
	process_priority = 1000  # kamera päivitetään vasta, kun hahmot ovat liikkuneet
	process_mode = Node.PROCESS_MODE_ALWAYS


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_quality()
	_build_overlay()
	cam = Camera3D.new()
	cam.far = 4000.0
	main.add_child(cam)
	var log := []
	await _separator()
	for id in ids:
		var shot := Leikkaus.shot(id)
		if shot.is_empty():
			push_error("Trailer: tuntematon otos " + id)
			continue
		var frames: int = Leikkaus.frames_of(id)
		print("TRAILER otos %s: %d ruutua" % [id, frames])
		seed(hash(id))  # sama otos näyttää samalta esikatselussa ja lopullisessa
		main.trailer_safe = true
		_spec = await Otokset.setup(main, id, self)
		main.trailer_safe = not _spec.get("lose", false)
		for i in int(_spec.get("warm", WARM_FRAMES)):
			_hide_hud()
			await get_tree().process_frame
		_apply_look()
		await _film(id, shot, frames)
		await _separator()
		_cleanup()
		log.append({"id": id, "frames": frames})
	var f := FileAccess.open(out_dir.path_join("ryhma_%s.json" % ids[0]), FileAccess.WRITE)
	f.store_string(JSON.stringify(log, "\t"))
	f.close()


## Kuvaus: tämä silmukka pyörii ruudun alussa (process_frame), joten painallukset (spec.keys) ja tick ehtivät
## pelin _processiin samalla ruudulla. Kamera ja tekstit päivitetään _processissa ruudun lopussa.
func _film(id: String, shot: Dictionary, frames: int) -> void:
	var n := Leikkaus.KIERROS_SNAPS if Leikkaus.kierros() else 3
	var snaps := []
	for k in n:
		snaps.append(int(k * (frames - 1) / float(n - 1)))
	_shot = shot
	_length = float(frames) / Leikkaus.FPS
	_filming = true
	for i in frames:
		_t = float(i) / Leikkaus.FPS
		_hide_hud()
		_keys()
		if _spec.has("tick"):
			_spec.tick.call(_t)
		_update_bubbles()
		if preview and i - 1 in snaps:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%d.png" % [id, snaps.find(i - 1)]))
		await get_tree().process_frame
	if preview:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("%s_%d.png" % [id, n - 1]))
	_filming = false
	for k in _spec.get("keys", []):
		Input.action_release(k[1])


var _shot: Dictionary = {}
var _length := 1.0
var _filming := false


func _process(_d: float) -> void:
	if _spec.is_empty():
		return
	_update_camera()
	if _filming:
		_update_texts(_shot, _t, _length)


## spec.keys: [[aika, toiminto, pito (s)]...]: painetaan ruudun alussa ajassa ja vapautetaan pidon jälkeen
## (pito 0 = yksi ruutu, kuten napautus).
var _taps: Array = []


## Napautus lavastuksen aikana (otokset.gd setup): odottaa ruudun alkuun, painaa ja vapauttaa seuraavalla ruudulla.
func tap_now(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().process_frame
	Input.action_release(action)


## Napautus nyt (otokset.gd tick): painetaan tällä ruudulla ja vapautetaan seuraavan alussa.
func tap(action: String) -> void:
	Input.action_press(action)
	_taps.append(action)


func _keys() -> void:
	for a in _taps:
		Input.action_release(a)
	_taps.clear()
	var dt := 1.0 / Leikkaus.FPS
	for k in _spec.get("keys", []):
		var hold: float = k[2] if k.size() > 2 else 0.0
		if _t >= k[0] - dt * 0.5 and _t < k[0] + dt * 0.5:
			Input.action_press(k[1])
		elif _t >= k[0] + maxf(hold, dt) - dt * 0.5 and _t < k[0] + maxf(hold, dt) + dt * 0.5:
			Input.action_release(k[1])


func _separator() -> void:
	_sep.visible = true
	for i in SEP_FRAMES:
		await get_tree().process_frame
	_sep.visible = false


func _cleanup() -> void:
	if get_tree().paused:
		get_tree().paused = false
	for c in _texts.get_children():
		c.queue_free()
	for b in _bars:
		b.visible = true
	for b in _bubbles:
		if is_instance_valid(b[0]):
			b[0].queue_free()
	_bubbles.clear()
	for p in props:
		if is_instance_valid(p):
			p.queue_free()
	props.clear()
	if _spec.has("done"):
		_spec.done.call()
	if not _fog0.is_empty():
		var env: Environment = get_viewport().find_world_3d().environment
		env.fog_depth_begin = _fog0[0]
		env.fog_depth_end = _fog0[1]
		env.fog_enabled = true
		_fog0 = []
	if main.cutscene._layer.visible and not main.cutscene.busy:
		main.cutscene._layer.visible = false
	_spec = {}
	_t = 0.0
	cam.attributes = null
	if cam.current:
		cam.clear_current(true)


# --- Kuvan laatu ja ilme -------------------------------------------------------

func _quality() -> void:
	var s: Node = main.get_node("/root/Settings")
	s.values.quality = 3
	s.values.view_distance = 3
	s.values.fullscreen = false
	s.values.vsync = false
	s.values.render_scale = 1.0 if preview else 2.0  # oletuksena 4× ylinäytteistys (2× leveys ja korkeus)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--trailer-ss="):  # ylinäytteistys: 1.0 = ei, 2.0 = oletus, 1.5 jos näytönohjaimen muisti loppuu
			s.values.render_scale = float(a.substr(13))
	s.apply()
	var win := get_window()
	win.msaa_3d = Viewport.MSAA_8X if not preview else Viewport.MSAA_4X
	win.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	if preview:
		return
	# Lopullinen video: pelin korkeintakin asetusta tarkempi, koska nopeudella ei ole väliä (Movie Maker).
	win.mesh_lod_threshold = 0.0  # täysi yksityiskohta kaukanakin
	win.positional_shadow_atlas_size = 8192
	RenderingServer.directional_shadow_atlas_set_size(8192, true)
	RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.positional_soft_shadow_filter_set_quality(RenderingServer.SHADOW_QUALITY_SOFT_ULTRA)
	RenderingServer.environment_set_ssao_quality(RenderingServer.ENV_SSAO_QUALITY_ULTRA, false, 0.5, 2, 50, 300)
	RenderingServer.environment_set_ssil_quality(RenderingServer.ENV_SSIL_QUALITY_ULTRA, false, 0.5, 4, 50, 300)
	RenderingServer.screen_space_roughness_limiter_set_active(true, 0.25, 0.18)
	if main._sun:
		main._sun.directional_shadow_max_distance = 300.0
		main._sun.shadow_blur = 1.2


## Elokuvamainen värimaailma: hieman kylläisempi ja kontrastikkaampi kuin pelissä, kevyt hehku.
var _fog0: Array = []
var _games := {}  # minipelien solmut skriptitiedoston mukaan (hide_games)


func _apply_look() -> void:
	var env: Environment = get_viewport().find_world_3d().environment
	if env == null:
		return
	env.adjustment_enabled = true
	env.adjustment_saturation = _spec.get("saturation", 1.14)
	env.adjustment_contrast = _spec.get("contrast", 1.06)
	env.adjustment_brightness = _spec.get("brightness", 1.0)
	env.glow_enabled = true
	env.glow_intensity = _spec.get("glow", 0.5)
	env.glow_bloom = 0.04
	if not preview:
		env.ssao_enabled = true
		env.ssao_intensity = 1.6
		env.ssil_enabled = true
	if _spec.has("fog"):  # esim. ilmakuvissa kauemmas (kerroin usvan alku- ja loppuetäisyydelle, 0 = ei usvaa)
		_fog0 = [env.fog_depth_begin, env.fog_depth_end]
		env.fog_enabled = _spec.fog > 0.0
		env.fog_depth_begin *= _spec.fog
		env.fog_depth_end *= _spec.fog


func _hide_hud() -> void:
	if not _spec.get("hud", false):
		main._hud.visible = false
	for f in _spec.get("hide_games", []):  # minipelien omat HUDit pois (otokset.gd)
		if not _games.has(f) or not is_instance_valid(_games[f]):
			_games[f] = Otokset._find(main, f)
		var g: Node = _games[f]
		if g == null:
			continue
		if g is CanvasLayer:  # koko minipeli on käyttöliittymää (karaoke): 3D-kuva näkyy alta
			g.visible = false
		for k in ["_hud", "_ui", "_layer"]:
			if g.get(k) is CanvasLayer:
				g.get(k).visible = false
	if main._msg:  # pelin ilmoitukset (voivat olla eri kerroksessa kuin HUD)
		main._msg.visible = _spec.get("hud", false)
	# Muut käyttöliittymän osat, joista osa on HUD-kerroksen ulkopuolella (mopon palkit, vihjeet, puhe-ikkuna).
	for n in ["_stamina_box", "_stat_bars", "_mopo_label", "_talk_box", "_talk_prompt", "_hint_bar", "_help_bar", "_clock_hud",
			"_minimap", "_compass", "_status", "_stats", "_sus_box", "_akku_label", "_akku_bar", "_fps_label"]:
		var c = main.get(n)
		if c is CanvasItem or c is CanvasLayer:
			c.visible = _spec.get("hud", false)
	if main._note:
		main._note.visible = _spec.get("note", false)


# --- Kamera -------------------------------------------------------------------

## spec.cam: Callable(t) -> [silmä, katsepiste] tai ei kameraa (pelin oma kamera jää). spec.fov: luku tai Callable(t).
func _update_camera() -> void:
	if not _spec.has("cam"):
		return
	var r: Array = _spec.cam.call(_t)
	var eye: Vector3 = r[0]
	var look: Vector3 = r[1]
	if eye.is_equal_approx(look):
		return
	var up := Vector3.UP if absf((look - eye).normalized().y) < 0.99 else Vector3.FORWARD
	cam.look_at_from_position(eye, look, up)
	if r.size() > 2:
		cam.rotate_object_local(Vector3.BACK, r[2])  # kallistus (dutch)
	var fov = _spec.get("fov", 50.0)
	cam.fov = fov.call(_t) if fov is Callable else fov
	if not cam.current:
		cam.current = true
	if _spec.has("dof") and cam.attributes == null:
		var at := CameraAttributesPractical.new()
		at.dof_blur_far_enabled = true
		at.dof_blur_far_distance = _spec.dof
		at.dof_blur_far_transition = _spec.dof * 1.5
		at.dof_blur_amount = 0.06
		cam.attributes = at


# --- Päällys: mustat palkit, tekstit, puhelin ----------------------------------

func _build_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 120
	add_child(overlay)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(root)
	for i in 2:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(bar)
		_bars.append(bar)
	_texts = Control.new()
	_texts.set_anchors_preset(Control.PRESET_FULL_RECT)
	_texts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_texts)
	_sep = ColorRect.new()
	_sep.color = SEP_COLOR
	_sep.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sep.visible = false
	root.add_child(_sep)
	_layout_bars()
	get_viewport().size_changed.connect(_layout_bars)


func _layout_bars() -> void:
	var s := get_viewport().get_visible_rect().size
	var h := maxf(0.0, (s.y - s.x / Leikkaus.ASPECT) / 2.0)
	_bars[0].position = Vector2.ZERO
	_bars[0].size = Vector2(s.x, h)
	_bars[1].position = Vector2(0, s.y - h)
	_bars[1].size = Vector2(s.x, h)


## Otoksen päällystekstit (leikkaus.gd "teksti", "nimi", "puhelin") rakennetaan ensimmäisellä ruudulla ja
## häivytetään ajan mukaan.
func _update_texts(shot: Dictionary, t: float, length: float) -> void:
	if _texts.get_child_count() == 0 and t == 0.0:
		Teksti.build_texts(_texts, shot, get_viewport().get_visible_rect().size)
		for b in _bars:
			b.visible = not shot.has("puhelin")  # pystyvideo käyttää koko korkeuden
	for c in _texts.get_children():
		if c.has_meta("anim"):
			c.get_meta("anim").call(c, t, length)


## Puhekupla hahmon päälle (otokset.gd): teksti näkyy sekunteina annetun ajan.
func bubble(who: Node3D, text: String, seconds := 2.6, height := 2.15) -> void:
	var b := B.bubble(who, Vector3(0, height, 0))
	b.text = text
	_bubbles.append([b, _t + seconds])


func _update_bubbles() -> void:
	for b in _bubbles:
		if is_instance_valid(b[0]) and _t >= b[1]:
			b[0].queue_free()


func now() -> float:
	return _t
