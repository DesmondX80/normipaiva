extends Node
## Päivin vanha kännykkä (#16): löytyy kodin makuuhuoneen yöpöydältä. Soittaa iskelmiä (iskelmat.gd: vanhat
## 78 kierroksen levyt Raita-kokoelmasta ja kansioon lisätyt biisit, esim. Eräät Jormat) pienestä kaiuttimesta:
## oma ääniväylä "Puhelin" (Music-väylän alla, joten Musiikki-asetus pätee) kaistanpäästöllä ja säröllä, jotta
## ääni on ohut ja rätisevä kuin taskusta. P esiin ja soimaan / tauko ja taskuun, N seuraava biisi (kun kuulokkeet
## eivät ole päässä), U voimakkuus (neljä pykälää). Soidessa puhelin näkyy ruudun oikeassa alakulmassa: näytöllä
## biisi, aika, taajuuspalkit ja voimakkuus, kaiuttimesta nousee nuotteja. Kuulokkeet tai pelin oma musiikki
## (välikuvat, lavan tanssit) tauottavat puhelimen. Puhelin on minikartan vasemmalla puolella. main.gd: found tallennukseen ja näppäimet (_phone_keys).

const Iskelmat := preload("res://scripts/iskelmat.gd")
const MG := preload("res://scripts/mg_draw.gd")

const BUS := "Puhelin"
const VOLUMES := [-16.0, -10.0, -5.0, 0.0]
const VOL_NAMES := ["hiljaa", "normaali", "kovaa", "täysillä"]

var found := false
var on := false  # soi (tai odottaa, että muu musiikki loppuu)
var volume := 2
var title := ""
var headphones: Node  # main.gd: kuulokkeiden ollessa päässä puhelin on tauolla
var _player: AudioStreamPlayer
var _list: Array[String] = []
var _idx := -1
var _layer: CanvasLayer
var _view: Control
var _t := 0.0
var _shake := 0.0
var _press := ""  # painettu näppäin (välähtää näytössä)
var _press_t := 0.0
var _notes: Array = []  # [paikka, nopeus, ikä, merkki]
var _bars := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0])
var _show := 0.0  # 0 = taskussa, 1 = esillä (liukuu)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(BUS) < 0:
		AudioServer.add_bus()
		var bi := AudioServer.bus_count - 1
		AudioServer.set_bus_name(bi, BUS)
		AudioServer.set_bus_send(bi, "Music")
		var bp := AudioEffectBandPassFilter.new()  # pieni kaiutin: ei bassoa eikä diskanttia
		bp.cutoff_hz = 1700.0
		bp.resonance = 0.35
		AudioServer.add_bus_effect(bi, bp)
		var dist := AudioEffectDistortion.new()
		dist.mode = AudioEffectDistortion.MODE_CLIP
		dist.drive = 0.25
		dist.post_gain = -3.0
		AudioServer.add_bus_effect(bi, dist)
	_player = AudioStreamPlayer.new()
	_player.bus = BUS
	_player.finished.connect(next)
	add_child(_player)
	_list = Iskelmat.playlist()
	_layer = CanvasLayer.new()
	_layer.layer = 5
	add_child(_layer)
	_view = Control.new()
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.draw.connect(_draw_phone)
	_layer.add_child(_view)


## P: esiin ja soimaan, tai tauko ja taskuun. Palauttaa false, jos puhelinta ei ole.
func toggle() -> bool:
	if not found:
		return false
	on = not on
	if on:
		if _player.stream == null:
			next()
		_player.stream_paused = false
	else:
		_player.stream_paused = true
	_bump("ok")
	return true


func next() -> void:
	if _list.is_empty():
		title = ""
		return
	_idx = (_idx + 1) % _list.size()
	_player.stream = Iskelmat.stream(_list[_idx])
	_player.volume_db = VOLUMES[volume]
	_player.play()
	_player.stream_paused = not on
	title = Iskelmat.title(_list[_idx])
	_bump("next")


## main.gd: puhelin näkyy vain HUDin kanssa (ei välikuvissa, valikoissa eikä minipeleissä).
func set_shown(v: bool) -> void:
	_layer.visible = v


func volume_up() -> void:
	volume = (volume + 1) % VOLUMES.size()
	_player.volume_db = VOLUMES[volume]
	_bump("vol")


## Soiko puhelin juuri nyt kuuluvasti (ei tauolla muun musiikin takia).
func audible() -> bool:
	return on and _player.playing and not _player.stream_paused


func _bump(key: String) -> void:
	_press = key
	_press_t = 0.25
	_shake = 1.0
	Sfx.play("pickup", -14.0, 1.6)


## Kuulokkeet päässä, pelin oma musiikki tai valikon tauko: puhelin vaikenee siksi aikaa.
func _process(delta: float) -> void:
	_t += delta
	_press_t = maxf(_press_t - delta, 0.0)
	_shake = maxf(_shake - delta * 5.0, 0.0)
	var theme_on: bool = Sfx._music != null and Sfx._music.playing
	var hp_on: bool = headphones != null and headphones.on
	if _player.stream != null:
		_player.stream_paused = not on or theme_on or hp_on or get_tree().paused
	var want := 1.0 if on and not hp_on else 0.0
	_show = move_toward(_show, want, delta * 4.0)
	var playing := audible()
	for i in _bars.size():
		var target := 0.0
		if playing:
			target = 0.35 + 0.65 * absf(sin(_t * (5.0 + i * 1.7) + i * 2.1)) * (0.5 + 0.5 * absf(sin(_t * 2.3 + i)))
		_bars[i] = lerpf(_bars[i], target, minf(delta * 14.0, 1.0))
	if playing and randf() < delta * 2.5:
		_notes.append([Vector2(randf_range(-14, 14), 0), Vector2(randf_range(-18, 18), randf_range(-55, -35)), 0.0,
			["♪", "♫"].pick_random()])
	for n in _notes:
		n[0] += n[1] * delta
		n[2] += delta
	_notes = _notes.filter(func(n: Array) -> bool: return n[2] < 1.6)
	_view.queue_redraw()


# --- Piirto -------------------------------------------------------------------------------------------------------

func _draw_phone() -> void:
	if _show <= 0.001:
		return
	var vs := _view.size
	var w := 150.0
	var h := 300.0
	var slide := 1.0 - pow(1.0 - _show, 3.0)
	var shake := Vector2(sin(_t * 70.0), cos(_t * 63.0)) * 3.0 * _shake
	var o := Vector2(vs.x - w - 248.0, vs.y - h * slide + 40.0 * slide - 6.0) + shake  # alareuna jää ruudun alle
	var body := Rect2(o, Vector2(w, h))
	var font := ThemeDB.fallback_font
	# Varjo, runko (tumma petrooli, vaalea yläreuna, tumma alareuna) ja ääriviiva.
	MG.box(_view, body, Color(0.16, 0.26, 0.3), 30, 10)
	_view.draw_polygon(PackedVector2Array([o + Vector2(14, 6), o + Vector2(w - 14, 6), o + Vector2(w - 4, h * 0.45),
		o + Vector2(4, h * 0.45)]), PackedColorArray([Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.0),
		Color(1, 1, 1, 0.0)]))
	_view.draw_polygon(PackedVector2Array([o + Vector2(4, h * 0.6), o + Vector2(w - 4, h * 0.6), o + Vector2(w - 16, h - 4),
		o + Vector2(16, h - 4)]), PackedColorArray([Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.3),
		Color(0, 0, 0, 0.3)]))
	MG.box(_view, body, Color(0, 0, 0, 0), 30, 0, MG.OUTLINE, 3)
	# Antennin nysä vasemmassa yläkulmassa ja kuuloke (raot).
	MG.box(_view, Rect2(o + Vector2(18, -22), Vector2(20, 30)), Color(0.1, 0.12, 0.13), 7, 0, MG.OUTLINE, 2)
	_view.draw_line(o + Vector2(23, -16), o + Vector2(23, 2), Color(1, 1, 1, 0.25), 2.0)
	for k in 4:
		var y := o.y + 18.0 + k * 5.0
		_view.draw_line(Vector2(o.x + w / 2.0 - 18 + k * 3.0, y), Vector2(o.x + w / 2.0 + 18 - k * 3.0, y), Color(0.05, 0.07, 0.08), 2.5)
	# Näyttö: vihreä LCD upotettuna harmaaseen kehykseen, sisävarjo ylhäällä.
	var bez := Rect2(o + Vector2(14, 44), Vector2(w - 28, 104))
	MG.box(_view, bez, Color(0.55, 0.6, 0.62), 12, 0, MG.OUTLINE, 2)
	var lcd := Rect2(bez.position + Vector2(8, 8), bez.size - Vector2(16, 16))
	var lit := Color(0.66, 0.78, 0.42)
	MG.grad_rect(_view, lcd, lit.darkened(0.1), lit.lightened(0.08))
	_view.draw_rect(Rect2(lcd.position, Vector2(lcd.size.x, 4)), Color(0, 0, 0, 0.18))
	var ink := Color(0.12, 0.2, 0.1)
	# Kenttä- ja akkupalkit.
	for k in 4:
		_view.draw_rect(Rect2(lcd.position + Vector2(4 + k * 4, 14 - k * 3), Vector2(3, 3 + k * 3)), ink)
	_view.draw_rect(Rect2(lcd.position + Vector2(lcd.size.x - 20, 6), Vector2(14, 8)), ink, false, 1.5)
	_view.draw_rect(Rect2(lcd.position + Vector2(lcd.size.x - 6, 8), Vector2(2, 4)), ink)
	_view.draw_rect(Rect2(lcd.position + Vector2(lcd.size.x - 18, 8), Vector2(7, 4)), ink)
	# Biisin nimi juoksevana tekstinä, esittäjä ja aika.
	var parts := title.split(" – ", true, 1)
	var song := parts[0] if parts.size() > 0 else ""
	var who := parts[1] if parts.size() > 1 else ""
	var lw := lcd.size.x - 8.0
	var tw := font.get_string_size(song, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	var scroll := 0.0
	if tw > lw:
		scroll = fmod(_t * 22.0, tw + 30.0)
	var clip_y := lcd.position.y + 34.0
	for rep in ([0.0, tw + 30.0] if tw > lw else [0.0]):
		var x: float = lcd.position.x + 4.0 - scroll + rep
		_draw_clipped(font, Vector2(x, clip_y), song, 14, ink, lcd)
	_draw_clipped(font, lcd.position + Vector2(4, 50), who, 10, ink, lcd)
	var pos := _player.get_playback_position() if _player.stream != null else 0.0
	var tstr := "%d:%02d" % [floori(pos / 60.0), int(pos) % 60]
	_view.draw_string(font, lcd.position + Vector2(4, lcd.size.y - 6), ("▶ " if audible() else "❚❚ ") + tstr,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ink)
	# Taajuuspalkit ja voimakkuuspykälät.
	for i in _bars.size():
		var bh := 2.0 + _bars[i] * 16.0
		_view.draw_rect(Rect2(lcd.position + Vector2(lcd.size.x - 46 + i * 6, lcd.size.y - 4 - bh), Vector2(4, bh)), ink)
	for k in VOLUMES.size():  # voimakkuus: nousevat palkit ajan oikealla puolella
		var vh := 3.0 + k * 2.0
		var r := Rect2(lcd.position + Vector2(44 + k * 4.0, lcd.size.y - 6 - vh), Vector2(3, vh))
		_view.draw_rect(r, ink if k <= volume else Color(ink, 0.25))
	if _press_t > 0.0:
		_view.draw_rect(lcd, Color(1, 1, 0.8, _press_t * 0.8))  # taustavalo välähtää painalluksesta
	# Näppäimet: valintanapit, pyöreä navinäppäin ja numerot. Painettu näppäin painuu.
	var ky := o.y + 158.0
	var cx := o.x + w / 2.0
	_key(Rect2(Vector2(o.x + 16, ky), Vector2(36, 16)), "P", _press == "ok")
	_key(Rect2(Vector2(o.x + w - 52, ky), Vector2(36, 16)), "N", _press == "next")
	MG.ball(_view, Vector2(cx, ky + 10), 13.0, Color(0.72, 0.75, 0.72) if _press != "vol" else Color(0.55, 0.58, 0.55), 0.35)
	_view.draw_string(font, Vector2(cx - 4, ky + 15), "U", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.15, 0.17, 0.18))
	var labels := ["1", "2", "3", "4", "5", "6", "7", "8", "9", "*", "0", "#"]
	for i in 12:
		var kr := Rect2(Vector2(o.x + 18 + (i % 3) * 39.0, ky + 32 + int(i / 3) * 24.0), Vector2(34, 18))
		if kr.end.y > vs.y + 4:
			continue
		_key(kr, labels[i], false)
	# Tarra: Päivin sydän.
	var hc := Vector2(o.x + w - 22, o.y + 34)
	_view.draw_circle(hc + Vector2(-3, 0), 4.0, Color(0.9, 0.2, 0.35))
	_view.draw_circle(hc + Vector2(3, 0), 4.0, Color(0.9, 0.2, 0.35))
	_view.draw_colored_polygon(PackedVector2Array([hc + Vector2(-7, 1), hc + Vector2(7, 1), hc + Vector2(0, 9)]), Color(0.9, 0.2, 0.35))
	# Nuotit nousevat kaiuttimesta.
	for n in _notes:
		var a: float = 1.0 - n[2] / 1.6
		var p: Vector2 = o + Vector2(w / 2.0, 10) + n[0]
		_view.draw_string_outline(font, p, n[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color(0, 0, 0, a * 0.8))
		_view.draw_string(font, p, n[3], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1.0, 0.85, 0.4, a))


func _key(r: Rect2, label: String, down: bool) -> void:
	var col := Color(0.78, 0.8, 0.76)
	if down:
		r.position.y += 2
		col = col.darkened(0.2)
	else:
		MG.box(_view, Rect2(r.position + Vector2(0, 3), r.size), Color(0.05, 0.07, 0.08), 7)
	MG.box(_view, r, col, 7, 0, MG.OUTLINE, 2)
	_view.draw_line(r.position + Vector2(6, 3), r.position + Vector2(r.size.x - 6, 3), Color(1, 1, 1, 0.55), 1.5)
	_view.draw_string(ThemeDB.fallback_font, r.position + Vector2(0, r.size.y - 4), label, HORIZONTAL_ALIGNMENT_CENTER,
		r.size.x, 11, Color(0.15, 0.17, 0.18))


## Juokseva teksti näytön sisällä: merkit, jotka menisivät näytön reunan yli, jätetään piirtämättä.
func _draw_clipped(font: Font, at: Vector2, text: String, size: int, col: Color, clip: Rect2) -> void:
	var x := at.x
	for ch in text:
		var cw := font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		if x >= clip.position.x + 2 and x + cw <= clip.end.x - 2:
			_view.draw_string(font, Vector2(x, at.y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		x += cw
