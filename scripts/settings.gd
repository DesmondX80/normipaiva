extends Node
## Asetukset, autoload "Settings": tallentuu user://settings.cfg. Yleiset asetukset (ikkuna, v-sync,
## äänet, renderöintiskaala) otetaan käyttöön täällä; pelikohtaiset (laatu, FOV) signaalilla.

signal changed

const PATH := "user://settings.cfg"
const QUALITY := ["Matala", "Keski", "Korkea"]

var values := {
	"fullscreen": false,
	"vsync": true,
	"quality": 2,  # 0 matala, 1 keski, 2 korkea
	"render_scale": 1.0,
	"fov": 70.0,
	"show_fps": false,
	"vol_master": 0.9,
	"vol_sfx": 0.9,
	"vol_ambience": 0.8,
	"vol_music": 0.8,
	"mouse_sens": 1.0,
	"invert_y": false,
	"auto_recenter": true,
}


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
	apply()


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
	cfg.save(PATH)


func apply() -> void:
	var win := get_window()
	if not Engine.is_editor_hint() and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want:
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	win.scaling_3d_scale = values.render_scale
	win.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][values.quality]
	for b in [["Master", "vol_master"], ["SFX", "vol_sfx"], ["Ambience", "vol_ambience"], ["Music", "vol_music"]]:
		var i := AudioServer.get_bus_index(b[0])
		if i >= 0:
			AudioServer.set_bus_volume_db(i, linear_to_db(maxf(values[b[1]], 0.0001)))
			AudioServer.set_bus_mute(i, values[b[1]] <= 0.001)
	changed.emit()
