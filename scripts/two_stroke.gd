extends AudioStreamPlayer
## Kaksitahtimopon pärinä syntetisoituna (AudioStreamGenerator): yksisylinterinen kone sytyttää kerran kierroksella,
## joten pamausten tahti on rpm / 60. Jokainen pamaus on vaimeneva purske pakoputken resonanssia ja suodatettua
## kohinaa, matala runko tulee pamausten tahdista. Käynti on epätasainen (voimakkuus ja väli heittelevät), ja välillä
## tulee ohilyönti, kuten vanhassa mopossa kuuluu. Kaasu nostaa kierroksia ja resonanssia ja tekee äänestä
## räkäisemmän. pop() = yksittäisiä köhäisyjä sammuneesta koneesta (potkukäynnistys).
## Käyttö: running = true / false, rpm-tavoite asetetaan target_rpm:llä (kierrokset liukuvat kohti), throttle 0..1.

const MIX := 11025.0  # lo-fi riittää ja säästää suoritinta (GDScript näyte kerrallaan)
const IDLE := 2400.0

var running := false
var target_rpm := IDLE
var throttle := 0.0
var level := 1.0  # kokonaisvoimakkuus (etäisyys, kuuluvuus)

var _pb: AudioStreamGeneratorPlayback
var _rpm := IDLE
var _phase := 0.0
var _env := 0.0
var _amp := 1.0
var _pt := 0.0  # aika pamauksesta (s)
var _res := 220.0
var _lp := 0.0
var _body := 0.0
var _pops: Array[float] = []  # köhäisyjen ajat (s) jäljellä
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX
	gen.buffer_length = 0.12
	stream = gen
	if bus == &"Master":
		bus = "SFX"
	play()
	_pb = get_stream_playback()


## Sammuneen koneen köhäisy: n paukahdusta epätasaisin välein.
func pop(n := 2) -> void:
	var t := 0.0
	for i in n:
		t += _rng.randf_range(0.07, 0.16)
		_pops.append(t)


func _process(delta: float) -> void:
	# Hiljaa ollessa generaattori pysähtyy kokonaan (ei lasketa hiljaisuutta näyte kerrallaan).
	var idle := not running and _pops.is_empty() and _env < 0.0005 and _rpm < 50.0
	if idle:
		if playing:
			stop()
		_rpm = 0.0
		return
	if not playing:
		play()
		_pb = get_stream_playback()
	if _pb == null:
		return
	_rpm = lerpf(_rpm, target_rpm if running else 0.0, 1.0 - exp(-(5.0 if target_rpm > _rpm else 2.5) * delta))
	for i in range(_pops.size() - 1, -1, -1):
		_pops[i] -= delta
	var frames := _pb.get_frames_available()
	var dt := 1.0 / MIX
	for f in frames:
		var fire := false
		if running and _rpm > 300.0:
			_phase += _rpm / 60.0 * dt
			if _phase >= 1.0:
				_phase -= 1.0
				fire = _rng.randf() > (0.06 if throttle < 0.5 else 0.02)  # ohilyönti
				# Epätasainen käynti: seuraava pamaus hieman aikaisemmin tai myöhemmin.
				_phase += _rng.randf_range(-0.08, 0.08)
		for i in range(_pops.size() - 1, -1, -1):
			if _pops[i] <= 0.0:
				_pops.remove_at(i)
				fire = true
		if fire:
			_env = 1.0
			_pt = 0.0
			_amp = _rng.randf_range(0.7, 1.0) * (1.0 + throttle * 0.3)
			_res = lerpf(180.0, 340.0, clampf(_rpm / 8000.0, 0.0, 1.0)) * _rng.randf_range(0.92, 1.08)
		_pt += dt
		_env *= 1.0 - dt * (55.0 - throttle * 20.0)
		var noise := _rng.randf_range(-1.0, 1.0)
		_lp += (noise - _lp) * (0.25 + throttle * 0.25)  # suodatettu kohina: räkäisyys kaasulla
		var ring := sin(TAU * _res * _pt) * exp(-_pt * 30.0)
		var s := _env * _amp * (0.75 * ring + 0.55 * _lp)
		# Matala runko: pamausten tahdin perustaajuus.
		_body = lerpf(_body, s, 0.08)
		s = s * 0.8 + _body * 1.6
		s = tanh(s * 1.8) * 0.6 * level
		_pb.push_frame(Vector2(s, s))
