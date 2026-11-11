extends Node
## Kartan hahmomerkki pelialueen reunoilla (paperikartta ja minikartta): ruutupaikka vs. odotettu paikka ja kuvat.
## Ajo: tools/testit/aja.sh scene kartta_reuna    Kuvat: _<paikka>_paperi, _<paikka>_mini.

const M := preload("res://scripts/map_data.gd")
const Terrain := preload("res://scripts/terrain.gd")

var main: Node3D
var vikoja := 0


func _vika(t: String) -> void:
	vikoja += 1
	print("TESTI VIKA " + t)


func _frames(n := 4) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(suffix: String) -> void:
	await _frames(3)
	await RenderingServer.frame_post_draw
	if DisplayServer.get_name() == "headless":
		return
	var path := "user://kartta_reuna%s.png" % suffix
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shot="):
			path = a.substr(7).replace(".png", suffix + ".png")
	get_viewport().get_texture().get_image().save_png(path)


func run() -> void:
	var w: Node3D = main.walker_out
	if main.player != w:
		main._toggle_mount()
	main._msg.text = ""
	main._note.visible = false
	var lo := M.MAP_MIN
	var hi := M.SIZE
	var mid := (lo + hi) / 2.0
	var m := 4.0
	var spots := {
		"nw": Vector2(lo.x + m, lo.y + m), "ne": Vector2(hi.x - m, lo.y + m),
		"sw": Vector2(lo.x + m, hi.y - m), "se": Vector2(hi.x - m, hi.y - m),
		"w": Vector2(lo.x + m, mid.y), "e": Vector2(hi.x - m, mid.y),
		"n": Vector2(mid.x, lo.y + m), "s": Vector2(mid.x, hi.y - m),
		"keski": mid,
		"nw_ulko": Vector2(lo.x - 300.0, lo.y - 300.0), "se_ulko": Vector2(hi.x + 300.0, hi.y + 300.0),
	}
	var pm = main._paper
	# HUD on pois testikohtauksessa: oma minikartta, jolla on pääpelin tekstuuri, ruudun oikeassa alakulmassa.
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	var mini: Control = load("res://scripts/minimap.gd").new()
	mini.position = Vector2(1280 - 226, 720 - 226)
	mini.player = w
	mini.world = main.world
	layer.add_child(mini)
	await _frames(3)
	mini._village_tex = main._minimap._village_tex
	for k in spots:
		var wp := M.w2(spots[k])
		w.global_position = Vector3(wp.x, Terrain.h(wp.x, wp.y) + 0.4, wp.y)
		await _frames(6)
		pm.toggle()
		await _frames(4)
		var vs: Vector2 = pm._view.size
		var icon: Vector2 = pm._vpx(wp)
		var expect: Vector2 = (wp - pm._vcenter) * pm._vzoom + vs / 2.0
		var inside := Rect2(Vector2.ZERO, vs).grow(-4.0).has_point(icon)
		print("PAPERI %s maailma %s ruutu %s odotettu %s näkymä %s zoom %.2f näkyvissä %s" % [k, wp.snapped(Vector2.ONE), icon.snapped(Vector2.ONE), expect.snapped(Vector2.ONE), vs, pm._vzoom, inside])
		print("PAPERI %s merkki leikkautuisi ilman rajausta: %s (rajaus piirrossa, katso kuva)" % [k, not inside])
		await _snap("_%s_paperi" % k)
		pm.toggle()
		await _frames(3)
		# Minikartta: lähderajaus tekstuurissa.
		await _frames(3)
		var rm: float = mini.range_m
		var src_pos: Vector2 = (mini._origin - mini._village_origin) * mini.TEX_SCALE - Vector2.ONE * rm * mini.TEX_SCALE
		var src_end: Vector2 = src_pos + Vector2.ONE * 2.0 * rm * mini.TEX_SCALE
		var ts := Vector2.ZERO
		if mini._village_tex != null:
			ts = mini._village_tex.get_size()
		var over := maxf(maxf(-src_pos.x, -src_pos.y), maxf(src_end.x - ts.x, src_end.y - ts.y))
		print("MINI %s lähde %s - %s tekstuuri %s ylitys %.1f px" % [k, src_pos.snapped(Vector2.ONE), src_end.snapped(Vector2.ONE), ts, over])
		if mini._village_tex == null:
			print("MINI tekstuuri puuttuu (ei tarkistettu)")
		elif over > 0.0 and not k.ends_with("_ulko"):
			_vika("minikartan lähde ylittää tekstuurin %.0f px kohdassa %s" % [over, k])
		await _snap("_%s_mini" % k)
	print("KARTTA_REUNA valmis, %d vikaa" % vikoja)
