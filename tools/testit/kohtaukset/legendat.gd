extends Node
## Testikohtaukset (--scene=<nimi>), ryhmä "legendat": lavastetut legendaariset hetket. aja() palauttaa 0 = kohtaus ei kuulu ryhmään.
## Kohtaukset ottavat pelaajan tallennuksen talteen alussa ja palauttavat sen lopussa.
##
## pentti_eka: Pentin ensimmäinen kyyti (rikos/pentti.gd _kyyti): keinunta, liukuovi aukeaa, mummo pudottaa kassin,
##   Pentti ovelta ja nousu parkkipaikan ylle; hetki kirjataan aamulla (päiväkirjarivi), toinen kyyti ilman huipennusta.

const Main := preload("res://scripts/main.gd")
const Kuva := preload("res://tools/testit/kuva.gd")

const KOHTAUKSET := ["pentti_eka"]

var main: Main
var _viat := 0


func aja(scene: String, path: String, _nohud: bool) -> int:
	if not scene in KOHTAUKSET:
		return 0
	var saved := FileAccess.get_file_as_bytes(Main.SAVE_PATH)
	match scene:
		"pentti_eka":
			await _pentti(path)
	FileAccess.open(Main.SAVE_PATH, FileAccess.WRITE).store_buffer(saved)
	return 1


func _frames(n: int) -> void:
	for i in n:
		await main.get_tree().process_frame


func _shot(path: String, name: String) -> void:
	await Kuva.piirto()
	await Kuva.piirto()
	var p := path.replace(".png", "_%s.png" % name)
	Kuva.ruutu(main.get_viewport()).save_png(p)
	print("LEGENDA kuva ", p)


func _check(ok: bool, what: String) -> void:
	print("LEGENDA %s: %s" % [what, "OK" if ok else "EI"])
	if not ok:
		_viat += 1
		print("TESTI VIKA %s" % what)


## Kuvat ajallisesti (sekuntia alusta) ja odotus, kunnes välianimaatiot ovat ohi.
func _shots_until_done(path: String, shots: Array, max_s := 120.0) -> void:
	# Välianimaation oma kello (cutscene.gd _now_ms): testiajo voi kulkea hitaammin kuin seinäkello.
	var t0: float = main.cutscene._now_ms()
	for st in shots:
		# [nimi, s alusta] tai [nimi, vaihe, s vaiheen alusta] (cutscene.gd phase)
		if st.size() == 3:
			while main.cutscene.phase != st[1] and main.cutscene.busy:
				await _frames(1)
			var tp: float = main.cutscene._now_ms()
			while (main.cutscene._now_ms() - tp) / 1000.0 < float(st[2]) and main.cutscene.busy:
				await _frames(1)
		while st.size() == 2 and (main.cutscene._now_ms() - t0) / 1000.0 < float(st[1]) and main.cutscene.busy:
			await _frames(1)
		if not main.cutscene.busy:
			print("LEGENDA kuva %s jäi ottamatta: kohtaus loppui %.1f s" % [st[0], (main.cutscene._now_ms() - t0) / 1000.0])
			break
		await _shot(path, st[0])
	while main.cutscene.busy and (main.cutscene._now_ms() - t0) / 1000.0 < max_s:
		await _frames(1)
	await _frames(4)  # hidas ajo: päiväkirjarivi (3,5 s) ehtisi kadota pitkässä odotuksessa


func _pentti(path: String) -> void:
	if main.player != main.walker_out:
		main._toggle_mount()
	main._note.visible = false
	main.endings.counts.erase("pentin_kyyti")
	var pt: RefCounted = main.rikos_osa("pentti")
	pt.kyydit = 0
	pt.todistaja_pakko = 0
	var day0: int = main.day
	pt._kyyti()
	await _frames(2)
	_check(not main.endings.counts.has("pentin_kyyti"), "Pentti: ei kirjattu kyydin alussa")
	await _shots_until_done(path, [["keinunta", 4.0], ["hiljaisuus", "hiljaisuus", 1.2], ["ovi", "ovi", 1.0], ["kassi", "ovi", 2.8],
		["pentti", "pentti", 1.6], ["nousu", "nousu", 4.0]], 120.0)
	for i in 200:
		if main.day != day0:
			break
		await _frames(1)
	await _frames(4)
	print("LEGENDA Pentti aamu: päivä %d -> %d, kerrat %d, viesti '%s'" % [day0, main.day, int(main.endings.counts.get("pentin_kyyti", 0)), main._msg.text])
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 1, "Pentti: hetki kirjattiin")
	_check(not main._msg.text.contains("LEGENDAARINEN"), "Pentti: ei vanhaa ilmoitusta")
	await _shot(path, "aamu")
	# Toinen kyyti: ei huipennusta.
	pt._kyyti()
	await _frames(2)
	var seen_phase := false
	while main.cutscene.busy:
		if main.cutscene.phase != "":
			seen_phase = true
		await _frames(1)
	_check(not seen_phase, "Pentti: toisella kyydillä ei huipennusta")
	await _frames(60)
	_check(int(main.endings.counts.get("pentin_kyyti", 0)) == 2, "Pentti: toinen kyyti laskettiin hiljaa")
