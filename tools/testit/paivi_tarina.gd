extends RefCounted
## Luku 6 päiväkirjan Tarina-sivulla (#326 erä F): aja tools/testit/aja.sh scene riskit --riski=paivi_tarina.
## Mittaa quests.gd:n luvun ehdot (avautuminen, vihje, K-18 pois) ja ottaa kuvat Päivin ilmeestä tasoilla 0-3 ja K-18 pois.

var r: Node  # riskit.gd (_vika, _snap, _frames)
var main: Node3D


func _rivit(d: Dictionary) -> Array:
	for ch in d.chapters:
		if String(ch.title).begins_with("6."):
			return ch.rows
	return []


func run(riskit: Node) -> void:
	r = riskit
	main = riskit.main
	var k18_ennen: Variant = Settings.get_v("k18_pois")
	Settings.set_v("k18_pois", false)
	var po: Object = main.rikos_osa("paivi")
	var t: Object = main.tilat
	if _rivit(main.journal_data()).size() != 0:
		r._vika("luku 6 näkyy ennen jälkeä")
	t.first("juna_saloinen", 0.0)
	if _rivit(main.journal_data()).size() != 0:
		r._vika("luku 6 näkyy ennen jälkeä (juna ilman jälkeä)")
	t.first("paivi_jalki", 0.0)
	var d: Dictionary = main.journal_data()
	print("PTARINA jäljen jälkeen rivejä %d (odotus 2: jälki, selitys)" % _rivit(d).size())
	if _rivit(d).size() != 2:
		r._vika("rivejä %d, piti 2" % _rivit(d).size())
	if main.quests.hint_for("pekka", t.firsts, main.quest_flag) != "":
		r._vika("Pekan vihje ennen selitystä")
	t.first("paivi_selitys", 0.0)
	var h: String = main.quests.hint_for("pekka", t.firsts, main.quest_flag)
	print("PTARINA Pekan vihje: ", h)
	if h == "" or not main.quests.heard.has("p_tutkii"):
		r._vika("Pekan vihje ei merkitse vaihetta kuulluksi")
	d = main.journal_data()
	print("PTARINA selityksen ja vihjeen jälkeen rivejä %d (odotus 4)" % _rivit(d).size())
	if _rivit(d).size() != 4:
		r._vika("rivejä %d, piti 4" % _rivit(d).size())
	# K-18 pois: vain jälki, selitys, hyvitys
	Settings.set_v("k18_pois", true)
	d = main.journal_data()
	print("PTARINA K-18 pois rivejä %d (odotus 3)" % _rivit(d).size())
	if _rivit(d).size() != 3:
		r._vika("K-18 pois: rivejä %d, piti 3" % _rivit(d).size())
	if main.quests.hint_for("pekka", t.firsts, main.quest_flag) != "":
		r._vika("K-18 pois: Pekan vihje kuuluu")
	Settings.set_v("k18_pois", false)
	# Ilme epäluulon mukaan
	for e in [10.0, 40.0, 60.0, 90.0]:
		po.epaluulo = e
		d = main.journal_data()
		var il: int = -1
		for ch in d.chapters:
			if ch.has("ilme"):
				il = ch.ilme
		print("PTARINA epäluulo %.0f -> ilme %d" % [e, il])
		if il != po.ilme():
			r._vika("ilme %d != %d" % [il, po.ilme()])
		await _kuva("_tarina_ilme%d" % il, d)
	po.epaluulo = 40.0
	Settings.set_v("k18_pois", true)
	await _kuva("_tarina_k18pois", main.journal_data())
	Settings.set_v("k18_pois", k18_ennen)


func _kuva(suffix: String, d: Dictionary) -> void:
	var j: Control = main._journal
	if not j.visible:
		j.toggle()
	j._set_tab("tarina")
	j._data = d
	var sc := 0.0
	# vieritys niin, että luku 6 on ylhäällä: kokeilu, jolla rivit ennen lukua 6 ohitetaan
	for ch in d.chapters:
		if String(ch.title).begins_with("6."):
			break
		sc += 36.0 + 12.0 + ch.rows.size() * 30.0
	j._scroll = sc
	j.queue_redraw()
	await r._snap(suffix)
