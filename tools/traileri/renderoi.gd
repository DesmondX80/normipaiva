extends SceneTree
## Trailerin renderöinti yhdellä komennolla. Jokainen leikkaus.gd:n ryhmä kuvataan omalla pelin käynnistyksellä
## Movie Maker -tilassa (kiinteä 30 fps: ruudut ovat sulavia ja täysilaatuisia koneen tehoista riippumatta),
## ja lopuksi kokoa.gd liittää otokset ja miksaa tunnarin.
##
##   godot --path . -s tools/traileri/renderoi.gd -- [valinnat]
##     --out=KANSIO       tulokset (oletus: user://traileri)
##     --res=1920x1080    resoluutio (esim. 3840x2160 4K:lle)
##     --ss=2.0           ylinäytteistys (render_scale): 2.0 = oletus (4× pikseleitä), 1.5 jos näytönohjaimen muisti loppuu
##     --groups=ulko,mokki  vain nämä ryhmät (muuten kaikki); valmiit ryhmät ohitetaan, --again kuvaa uudelleen
##     --ids=i_ilma,i_koti  vain nämä otokset (kokeiluun)
##     --preview          ei videota: kuvat jokaisen otoksen alusta, keskeltä ja lopusta (esikatselu.png kokoaa)
##     --quality=0.95     MJPEG-laatu
## Pelin tallennus (user://normipaiva.cfg) varmuuskopioidaan ennen jokaista ajoa ja palautetaan sen jälkeen.

const Leikkaus := preload("res://tools/traileri/leikkaus.gd")
const SAVE := "user://normipaiva.cfg"
const OVERRIDE := "res://override.cfg"


func _initialize() -> void:
	var out := "user://traileri"
	var res := "1920x1080"
	var ss := "2.0"
	var quality := "0.95"
	var only: PackedStringArray = []
	var preview := false
	var again := false
	var only_ids: PackedStringArray = []
	var kierros := Leikkaus.kierros()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--res="):
			res = a.substr(6)
		elif a.begins_with("--ss="):
			ss = a.substr(5)
		elif a.begins_with("--quality="):
			quality = a.substr(10)
		elif a.begins_with("--groups="):
			only = a.substr(9).split(",")
		elif a == "--preview":
			preview = true
		elif a == "--again":
			again = true
		elif a.begins_with("--ids="):
			only_ids = a.substr(6).split(",")
	out = ProjectSettings.globalize_path(out)
	if preview:
		out = out.path_join("kierros" if kierros else "esikatselu")
	DirAccess.make_dir_recursive_absolute(out)
	var wh := res.split("x")
	var had_override := FileAccess.file_exists(OVERRIDE)
	if had_override:
		push_error("override.cfg on jo olemassa projektissa: siirrä se pois renderöinnin ajaksi.")
		quit(1)
		return
	var cfg := FileAccess.open(OVERRIDE, FileAccess.WRITE)
	cfg.store_string("[display]\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n\n[editor]\nmovie_writer/mjpeg_quality=%s\n"
		% [wh[0], wh[1], quality])
	cfg.close()
	var save := FileAccess.get_file_as_bytes(SAVE)
	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var groups := Leikkaus.groups()
	var t0 := Time.get_ticks_msec()
	for g in groups:
		if not only.is_empty() and not g in only:
			continue
		var ids: Array = groups[g]
		if not only_ids.is_empty():
			ids = ids.filter(func(i: String) -> bool: return i in only_ids)
			if ids.is_empty():
				continue
		var avi := out.path_join("%s.avi" % g)
		if not preview and not again and FileAccess.file_exists(avi) and FileAccess.file_exists(out.path_join("ryhma_%s.json" % ids[0])):
			print("Ohitetaan valmis ryhmä ", g)
			continue
		var args := ["--path", proj]
		if not preview:
			args += ["--write-movie", avi, "--fixed-fps", str(Leikkaus.FPS)]
		else:
			args += ["--fixed-fps", str(Leikkaus.FPS)]
		if g == "kortit":
			args += ["-s", "res://tools/traileri/kortti.gd", "--", "--trailer=" + ",".join(ids), "--out=" + out]
		else:
			args += ["--", "--shot=" + out.path_join("%s.png" % g), "--trailer=" + ",".join(ids), "--trailer-ss=" + ss]
		if preview:
			args.append("--trailer-preview")
		if kierros:
			args.append("--trailer-set=kierros")
		print("Ryhmä %s (%d otosta) ..." % [g, ids.size()])
		var t := Time.get_ticks_msec()
		var output := []
		var code := OS.execute(exe, args, output, true)
		var log := FileAccess.open(out.path_join("%s.log" % g), FileAccess.WRITE)
		log.store_string("\n".join(output))
		log.close()
		print("  valmis %.0f s (koodi %d)" % [(Time.get_ticks_msec() - t) / 1000.0, code])
		if not save.is_empty():
			FileAccess.open(SAVE, FileAccess.WRITE).store_buffer(save)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OVERRIDE))
	print("Kuvaus valmis %.1f min." % ((Time.get_ticks_msec() - t0) / 60000.0))
	if preview:
		OS.execute(exe, ["--path", proj, "--headless", "-s", "res://tools/traileri/kokoa.gd", "--", "--in=" + out, "--sheet"]
			+ (["--set=kierros"] if kierros else []), [], true)
		print("Esikatselu: ", out.path_join("esikatselu.png"))
	else:
		var output := []
		OS.execute(exe, ["--path", proj, "--headless", "-s", "res://tools/traileri/kokoa.gd", "--", "--in=" + out], output, true)
		print("\n".join(output))
	quit()
