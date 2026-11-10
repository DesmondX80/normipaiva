extends Label3D
## Puhekupla (B.bubble): kiinteän kokoinen teksti hahmon yläpuolella. Jos kupla (pitkä repliikki, kamera lähellä tai
## sisätilan yläkamera) menisi ruudun yläreunan yli, sitä lasketaan kameran suunnassa alemmas, joten kupla pysyy
## kokonaan ruudulla ja hahmon pää jää sen alle. Ei käytetä, jos koodi asettaa kuplan paikan itse joka ruudulla
## (guard = false, esim. välianimaatiot).

const LINE_PX := 46.0  # yhden rivin korkeus ruudulla (BUBBLE_FONT * BUBBLE_PIXEL * ruudun skaala)
const MARGIN := 10.0

## Kuplan näkyvyysraja kamerasta (m); 0 = ei rajaa. main.gd asettaa Vaalan matkan ajaksi: kaukaiset kuplat (kiinteä koko,
## ei syvyystestiä) eivät saa leijua tyhjän maiseman päällä.
static var far_limit := 0.0

var rest := Vector3.ZERO  # kuplan paikka hahmon kehyksessä ilman siirtoa
var guard := true
var voice := ""  # puhujan ääni ("paivi"); tyhjä = tekstin "Nimi: " -etuliite tai muu ääni
var _culled := false
var _spoken := ""
var _wrap_chars := 17.0  # merkkiä riville (leveys 520 px, fontti 40)

## Vuorottelu (guard-kuplat): lähekkäisten hahmojen kuplat eivät tule päällekkäin. Puhujan koodi asettaa tekstin kuten
## ennenkin; kupla näyttää sen heti, jos lähellä (VUORO_R) ei ole kuplaa, joka on näkynyt alle vähimmäisaikansa
## (_min_aika: luettava aika tekstin pituudesta). Muuten repliikki odottaa vuoroaan (enintään ODOTUS_MAX s). Kun odottanut
## repliikki tulee näkyviin, naapurin jo luettu kupla poistuu, ja odottanut repliikki näkyy vähimmäisajan ja poistuu
## itsestään (puhujan oma ajastin on jo voinut loppua). Puheääni kuuluu vasta, kun kupla näkyy.
const VUORO_R := 5.0
const ODOTUS_MAX := 8.0
static var _kaikki: Array = []  # guard-kuplat (vuorottelu)

var _mine := ""  # teksti, jonka kupla itse viimeksi asetti näkyviin
var _pending := ""  # puhujan uusi repliikki, joka odottaa vuoroaan
var _pending_t := 0.0
var _showing := ""
var _since := 0.0  # milloin _showing tuli näkyviin (s)
var _owner_cleared := false  # puhuja tyhjensi tekstin
var _delayed := false  # näkyvä repliikki odotti vuoroaan: poistuu itsestään vähimmäisajan jälkeen


func _enter_tree() -> void:
	if guard and not self in _kaikki:
		_kaikki.append(self)


func _exit_tree() -> void:
	_kaikki.erase(self)


static func _min_aika(t: String) -> float:
	return clampf(1.8 + 0.055 * t.length(), 2.0, 6.0)


static func _nyt() -> float:
	return Time.get_ticks_msec() / 1000.0


## Lähellä oleva toinen kupla, joka on näkynyt alle vähimmäisaikansa (sen vuoro on kesken).
func _vuoro_kesken() -> bool:
	for b in _kaikki:
		if b == self or not is_instance_valid(b) or b._showing == "" or not b.is_visible_in_tree():
			continue
		if b.global_position.distance_to(global_position) < VUORO_R and _nyt() - b._since < _min_aika(b._showing):
			return true
	return false


func _nayta(t: String) -> void:
	_showing = t
	_since = _nyt()
	_mine = t
	text = t


func _vuorottelu() -> void:
	var now := _nyt()
	if text != _mine:  # puhujan koodi vaihtoi tekstin
		if text == "":
			_owner_cleared = true
			_pending = ""
		else:
			_pending = text
			_pending_t = now
			_owner_cleared = false
			_delayed = false
		text = _mine  # näkyvä teksti pysyy, kunnes vuoro ratkaistaan alla
	if _showing != "":
		var done := now - _since >= _min_aika(_showing)
		if _pending != "" and not _vuoro_kesken():
			# Puhuja vaihtoi omaa repliikkiään: uusi heti, kun naapurin vuoro ei ole kesken.
			_delayed = false
			_nayta(_pending)
			_pending = ""
			return
		# Puhujan tyhjennys heti (kuten ennen); vuoroaan odottanut repliikki näkyy kuitenkin vähimmäisajan.
		if (_owner_cleared and (not _delayed or done)) or (_delayed and done):
			_nayta("")
			_showing = ""
			_owner_cleared = false
			_delayed = false
		return
	if _pending == "":
		return
	if now - _pending_t > ODOTUS_MAX:
		_pending = ""  # vanhentunut, ei enää ajankohtainen
		return
	if _vuoro_kesken():
		return
	_delayed = now - _pending_t > 0.05  # odotti vuoroaan
	# Naapurien jo luetut kuplat pois, ettei tule päällekkäin.
	for b in _kaikki:
		if b != self and is_instance_valid(b) and b._showing != "" and b.global_position.distance_to(global_position) < VUORO_R:
			b._nayta("")
			b._showing = ""
	_nayta(_pending)
	_pending = ""


func _process(_delta: float) -> void:
	if guard:
		_vuorottelu()
	if text != _spoken:
		_spoken = text
		if text != "":
			Sfx.speak(voice if voice != "" else "muu", text)
	if far_limit > 0.0 or _culled:
		var vc := get_viewport().get_camera_3d()
		_culled = far_limit > 0.0 and vc != null and vc.global_position.distance_to(global_position) > far_limit
		visible = not _culled
	if not guard or text == "":
		return
	position = rest
	var cam := get_viewport().get_camera_3d()
	if cam == null or cam.is_position_behind(global_position):
		return
	var sy := cam.unproject_position(global_position).y
	var lines := minf(ceilf(float(text.length()) / _wrap_chars) + float(text.count("\n")), 8.0)
	var need := lines * LINE_PX * get_viewport().get_visible_rect().size.y / 1080.0
	if sy - need >= MARGIN:
		return
	var vp_h := get_viewport().get_visible_rect().size.y
	var dist := cam.global_position.distance_to(global_position)
	var per_px := 2.0 * dist * tan(deg_to_rad(cam.fov) / 2.0) / vp_h
	global_position -= cam.global_transform.basis.y * ((MARGIN + need - sy) * per_px)
