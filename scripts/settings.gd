extends Node
## Asetukset, autoload "Settings": tallentuu user://settings.cfg. Yleiset asetukset (ikkuna, v-sync,
## äänet, renderöintiskaala) otetaan käyttöön täällä; pelikohtaiset (laatu, FOV) signaalilla.

signal changed

const PATH := "user://settings.cfg"
const QUALITY := ["Erittäin matala", "Matala", "Keski", "Korkea"]
## Näkyvyysetäisyys (m): kameran kaukoraja ja usva. Lyhyt etäisyys karsii kaukaisen maiseman piirtämisen kokonaan
## (maasto, talot, puut), mikä keventää eniten heikoilla näytönohjaimilla; usva peittää rajan.
const VIEW_NAMES := ["Lyhyt (200 m)", "Keski (350 m)", "Pitkä (550 m)", "Täysi (900 m)"]
const VIEW_DIST := [200.0, 350.0, 550.0, 900.0]
## Grafiikkamoottori valitaan ennen kuin skriptit ajetaan, joten se tallennetaan user://override.cfg:hen
## (project.godot: application/config/project_settings_override) ja vaihtuu uudelleenkäynnistyksessä.
const OVERRIDE := "user://override.cfg"
const RENDERERS := ["Paras (Forward+)", "Yhteensopiva (OpenGL)"]
const RENDER_METHODS := ["forward_plus", "gl_compatibility"]
## Vaihdettavat näppäimet: [toiminnot, nimi, oletusnäppäimet (enintään 2)]. Hyppy ja jarru ovat samassa näppäimessä
## (jalan hyppy, pyörällä jarru). Yksi näppäin voi olla vain yhdessä kohdassa: uusi sijoitus poistaa vanhan.
## Kolmas paikka on hiiren nappi (MOUSE_BASE + nappi): suositellut oletukset vasen = toiminto, oikea = hyppy/jarru,
## rullan painallus = pyörä, sivunapit = kartta ja reppu. Hiiren napit toimivat vain, kun hiiri on lukittu peliin
## eikä minipeli käytä hiirtä (_input), jotta valikoiden ja minipelien klikkaukset eivät laukaise toimintoja.
const MOUSE_BASE := 1 << 30
const SLOTS := 3
const KEY_ROWS := [
	[["forward"], "Eteen", [KEY_W, KEY_UP, 0]],
	[["back"], "Taakse", [KEY_S, KEY_DOWN, 0]],
	[["left"], "Vasemmalle", [KEY_A, KEY_LEFT, 0]],
	[["right"], "Oikealle", [KEY_D, KEY_RIGHT, 0]],
	[["sprint"], "Juoksu / spurtti", [KEY_SHIFT, 0, 0]],
	[["jump", "brake"], "Hyppy / jarru", [KEY_SPACE, 0, MOUSE_BASE + MOUSE_BUTTON_RIGHT]],
	[["interact"], "Toiminto", [KEY_E, 0, MOUSE_BASE + MOUSE_BUTTON_LEFT]],
	[["mount"], "Pyörän selkään / pois", [KEY_F, 0, MOUSE_BASE + MOUSE_BUTTON_MIDDLE]],
	[["eat"], "Syö", [KEY_T, 0, 0]],
	[["bell"], "Soittokello / kello", [KEY_Q, 0, 0]],
	[["map"], "Kartta", [KEY_M, 0, MOUSE_BASE + MOUSE_BUTTON_XBUTTON1]],
	[["inventory"], "Reppu", [KEY_I, KEY_TAB, MOUSE_BASE + MOUSE_BUTTON_XBUTTON2]],
	[["camera"], "Kamera (FPS / 3. persoona)", [KEY_V, 0, 0]],
	[["headphones"], "Kuulokkeet päähän / pois", [KEY_H, 0, 0]],
	[["next_song"], "Kuulokkeet: seuraava biisi", [KEY_N, 0, 0]],
	[["punch"], "Tappelu: lyönti", [KEY_J, 0, 0]],
	[["kick"], "Tappelu: potku", [KEY_K, 0, 0]],
	[["special"], "Tappelu: erikoisisku", [KEY_L, 0, 0]],
	[["drone_down"], "Drooni: alas", [KEY_C, KEY_CTRL, 0]],
	[["drone_home"], "Drooni: kotiin", [KEY_H, 0, 0]],
	[["drone_photo"], "Drooni: kuva", [KEY_P, KEY_ENTER, 0]],
]
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Hiiri vasen", MOUSE_BUTTON_RIGHT: "Hiiri oikea", MOUSE_BUTTON_MIDDLE: "Rullan painallus",
	MOUSE_BUTTON_WHEEL_UP: "Rulla ylös", MOUSE_BUTTON_WHEEL_DOWN: "Rulla alas", MOUSE_BUTTON_XBUTTON1: "Hiiri sivu 1",
	MOUSE_BUTTON_XBUTTON2: "Hiiri sivu 2"}
## Ohjeteksteissä oletuskirjain hakasulkeissa ([E]) vaihtuu käyttäjän valitsemaan näppäimeen.
const HINT_KEYS := {"E": "interact", "F": "mount", "T": "eat", "Q": "bell", "M": "map", "I": "inventory", "V": "camera",
	"J": "punch", "H": "headphones", "N": "next_song"}
const KEY_NAMES := {KEY_SPACE: "Välilyönti", KEY_UP: "Nuoli ylös", KEY_DOWN: "Nuoli alas", KEY_LEFT: "Nuoli vas.",
	KEY_RIGHT: "Nuoli oik.", KEY_SHIFT: "Shift", KEY_CTRL: "Ctrl", KEY_ALT: "Alt", KEY_TAB: "Tab", KEY_ENTER: "Enter",
	KEY_BACKSPACE: "Askelpalautin", KEY_CAPSLOCK: "Caps Lock"}

var values := {
	"fullscreen": false,
	"vsync": true,
	"quality": 3,  # 0 erittäin matala (ei auringon varjoja), 1 matala, 2 keski, 3 korkea
	"render_scale": 1.0,
	"view_distance": 3,  # VIEW_NAMES-indeksi
	"fov": 70.0,
	"show_fps": false,
	"show_guides": false,  # leijuvat paikkojen ja hahmojen nimet (B.guide)
	"vol_master": 0.9,
	"vol_sfx": 0.9,
	"vol_ambience": 0.8,
	"vol_music": 0.8,
	"mouse_sens": 1.0,
	"invert_y": false,
	"auto_recenter": true,
	"mouse_look": true,
	"mouse_steer": false,  # hiiri ohjaa kulkusuuntaa (FPS-tyyli), W/S eteen ja taakse
	"mouse_steer_indoor": false,  # sisätiloissa hiiri kääntää hahmoa (muuten W/A/S/D ruudun suuntiin, kursori vapaana)
	"keys": {},  # vaihdetut näppäimet: KEY_ROWS-rivin ensimmäinen toiminto -> [näppäin1, näppäin2, hiiri] (0 = ei mitään)
}
var _hint_re := RegEx.create_from_string(r"\[(Shift\+)?([A-Z])\]")
## Tosi, jos tämä käynnistys tallensi yhteensopivan grafiikan pysyväksi (Windowsin varakäynnistin).
var renderer_auto_saved := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["SFX", "Ambience", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		for k in values:
			values[k] = cfg.get_value("settings", k, values[k])
		# Vanha kolmiportainen laatu (0 matala – 2 korkea): siirretään asteikolle, jonka alussa on erittäin matala.
		if cfg.has_section_key("settings", "quality") and not cfg.has_section_key("settings", "quality_levels"):
			values.quality = mini(values.quality + 1, QUALITY.size() - 1)
	# Windowsin varakäynnistin (Normipaiva (yhteensopiva).bat) käynnistää OpenGL:llä: muistetaan valinta,
	# jotta jatkossa myös pelkkä Normipaiva.exe toimii koneilla, joilla Vulkan kaatuu.
	if OS.get_name() == "Windows" and renderer_current() == 1 and renderer_saved() != 1:
		set_renderer(1)
		renderer_auto_saved = true
	apply()
	apply_keys()


## Käytössä oleva grafiikkamoottori (RENDERERS-indeksi).
func renderer_current() -> int:
	return 1 if RenderingServer.get_current_rendering_method() == "gl_compatibility" else 0


## Seuraavalla käynnistyksellä käytettävä grafiikkamoottori.
func renderer_saved() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(OVERRIDE) != OK:
		return 0
	return maxi(0, RENDER_METHODS.find(cfg.get_value("rendering", "renderer/rendering_method", "forward_plus")))


func set_renderer(i: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(OVERRIDE)
	cfg.set_value("rendering", "renderer/rendering_method", RENDER_METHODS[i])
	cfg.save(OVERRIDE)


func get_v(key: String) -> Variant:
	return values[key]


func set_v(key: String, v: Variant) -> void:
	values[key] = v
	apply()
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.set_value("settings", "quality_levels", QUALITY.size())
	cfg.save(PATH)


## KEY_ROWS-rivin näppäimet [1, 2, 3] (fyysiset näppäinkoodit tai MOUSE_BASE + hiiren nappi, 0 = tyhjä). Vanhoissa
## tallennuksissa on kaksi paikkaa: kolmas (hiiri) tulee oletuksista.
func keys_of(row: int) -> Array:
	var d: Array = KEY_ROWS[row][2]
	var k: Array = (values.keys as Dictionary).get(KEY_ROWS[row][0][0], d)
	var out := []
	for i in SLOTS:
		out.append(int(k[i]) if k.size() > i else int(d[i]))
	return out


## Asettaa rivin paikkaan (0/1) näppäimen. Sama näppäin poistetaan muualta; palauttaa sen rivin nimen, jolta
## näppäin otettiin pois ("" jos ei miltään).
func bind_key(row: int, slot: int, code: int) -> String:
	var table := []
	for r in KEY_ROWS.size():
		table.append(keys_of(r))
	var moved := ""
	if code != 0:
		for r in table.size():
			for s in SLOTS:
				if table[r][s] == code and not (r == row and s == slot):
					table[r][s] = 0
					if r != row:
						moved = KEY_ROWS[r][1]
	table[row][slot] = code
	var d := {}
	for r in table.size():
		d[KEY_ROWS[r][0][0]] = table[r]
	values.keys = d
	apply_keys()
	save()
	return moved


func reset_keys() -> void:
	values.keys = {}
	apply_keys()
	save()


## Luo toiminnot ja asettaa niille valitut näppäimet.
func apply_keys() -> void:
	for r in KEY_ROWS.size():
		var ks := keys_of(r)
		for a in KEY_ROWS[r][0]:
			if not InputMap.has_action(a):
				InputMap.add_action(a)
			InputMap.action_erase_events(a)
			for k in ks:
				if k != 0 and k < MOUSE_BASE:  # hiiren napit: _input
					var ev := InputEventKey.new()
					ev.physical_keycode = k
					InputMap.action_add_event(a, ev)


func key_name(code: int) -> String:
	if code == 0:
		return "—"
	if code >= MOUSE_BASE:
		return MOUSE_NAMES.get(code - MOUSE_BASE, "Hiiri %d" % (code - MOUSE_BASE))
	if KEY_NAMES.has(code):
		return KEY_NAMES[code]
	return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(code))


## Hiiren napit toimintoihin, kun hiiri on lukittu peliin eikä minipeli tai valikko käytä hiirtä. Sisätiloissa ilman
## hiiriohjausta kursori on vapaana: silloin napit toimivat, kun kursori ei ole käyttöliittymän päällä. Rulla antaa
## vain painalluksen, joten se vapautetaan seuraavalla ruudulla.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or get_tree().paused or CamCtl.need_mouse or CamCtl.free_mouse:
		return
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not CamCtl.indoors or Touch.active or get_viewport().gui_get_hovered_control() != null:
			return
	var code: int = MOUSE_BASE + event.button_index
	var wheel: bool = event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT,
		MOUSE_BUTTON_WHEEL_RIGHT]
	for r in KEY_ROWS.size():
		if not code in keys_of(r):
			continue
		for a in KEY_ROWS[r][0]:
			if event.pressed:
				Input.action_press(a)
				if wheel:
					get_tree().process_frame.connect(Input.action_release.bind(a), CONNECT_ONE_SHOT)
			elif not wheel:
				Input.action_release(a)


## Ohjeiden näppäinhattu (hint_bar.gd) toiminnolle asetusten mukaan, esim. "[E]"; extra lisätään perään, esim.
## hiiren nappi, jota minipeli lukee itse: cap("interact", "Hiiri vasen") = "[E / Hiiri vasen]".
func cap(action: String, extra := "") -> String:
	return "[%s]" % (action_key(action) + (" / " + extra if extra != "" else ""))


## Kahden toiminnon pari samaan hattuun, esim. pair("left", "right") = "[A/D]".
func pair(a: String, b: String) -> String:
	return "[%s/%s]" % [action_key(a), action_key(b)]


## Toiminnon ensimmäisen näppäimen nimi ohjeisiin.
func action_key(action: String) -> String:
	for r in KEY_ROWS.size():
		if action in KEY_ROWS[r][0]:
			var ks := keys_of(r)
			for k in ks:
				if k != 0:
					return key_name(k)
			return "—"
	return "?"


## Vaihtaa ohjetekstin oletusnäppäimet ([E]) valittuihin.
func key_hint(s: String) -> String:
	if values.keys.is_empty() or not "[" in s:
		return s
	var out := ""
	var at := 0
	for m in _hint_re.search_all(s):
		var letter := m.get_string(2)
		if HINT_KEYS.has(letter):
			out += s.substr(at, m.get_start() - at) + "[" + m.get_string(1) + action_key(HINT_KEYS[letter]) + "]"
			at = m.get_end()
	return out + s.substr(at)


## Kameran kaukoraja valitulle näkyvyysetäisyydelle.
func view_far() -> float:
	return VIEW_DIST[clampi(int(values.view_distance), 0, VIEW_DIST.size() - 1)]


func apply() -> void:
	var win := get_window()
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	win.scaling_3d_scale = values.render_scale
	win.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][values.quality]
	for b in [["Master", "vol_master"], ["SFX", "vol_sfx"], ["Ambience", "vol_ambience"], ["Music", "vol_music"]]:
		var i := AudioServer.get_bus_index(b[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(values[b[1]], 0.0001)))
			AudioServer.set_bus_mute(i, values[b[1]] <= 0.001)
	changed.emit()
