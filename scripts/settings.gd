extends Node
## Asetukset, autoload "Settings": tallentuu user://settings.cfg. Yleiset asetukset (ikkuna, v-sync,
## äänet, renderöintiskaala) otetaan käyttöön täällä; pelikohtaiset (laatu, FOV) signaalilla.

signal changed

const PATH := "user://settings.cfg"
const QUALITY := ["Erittäin matala", "Matala", "Keski", "Korkea"]
## Grafiikkamoottori valitaan ennen kuin skriptit ajetaan, joten se tallennetaan user://override.cfg:hen
## (project.godot: application/config/project_settings_override) ja vaihtuu uudelleenkäynnistyksessä.
const OVERRIDE := "user://override.cfg"
const RENDERERS := ["Paras (Forward+)", "Yhteensopiva (OpenGL)"]
const RENDER_METHODS := ["forward_plus", "gl_compatibility"]

var values := {
	"fullscreen": false,
	"vsync": true,
	"quality": 3,  # 0 erittäin matala (ei auringon varjoja), 1 matala, 2 keski, 3 korkea
	"render_scale": 1.0,
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
}
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
