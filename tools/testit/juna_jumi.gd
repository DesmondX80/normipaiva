extends Node3D
## Aikataulun juna ei jää seisomaan radalle eikä jää jonoon ikuisesti (train.gd): asemalle kutsuttu juna lähtee
## laiturilta, ja jos seuraava kutsutaan lähdön aikana (_pending), se tulee, kun edellinen on ajanut ohi.
## Juna ajetaan ilman pelimaailmaa suoralla radalla, aika kulkee simuloiduin askelin.
## Ajo: tools/testit/aja.sh --headless tscn tools/testit/juna_jumi.tscn

const Train := preload("res://scripts/train.gd")
const STEP := 0.1


func _ready() -> void:
	var path := PackedVector3Array()
	for i in 41:
		path.append(Vector3(i * 50.0, 0, 0))  # 2 km suora rata
	var tr := Train.new()
	tr.random = false
	add_child(tr)
	tr.setup(path)
	var stop_t := 1000.0
	tr.call_station(stop_t)
	# Ensimmäinen juna seisoo laiturilla, ja toinen kutsutaan, kun se on jo lähtenyt (kuten aikataulu tekee).
	var calls := 0
	var stopped_out := 0.0
	var worst_stuck := 0.0
	var saw_second := false
	for step in int(600.0 / STEP):
		tr._process(STEP)
		if tr._phase == "stop" and tr._dwell < STOP_DWELL_HALF and calls == 0:
			calls = 1
		if tr._phase == "out" and calls == 1:
			tr.call_station(stop_t)  # lähtevän aikana: jonoon
			calls = 2
		if calls == 2 and tr._phase == "stop" and tr._pending < 0.0:
			saw_second = true
			break
		# Lähtevä juna, joka ei liiku: seisoo radalla.
		if tr._phase == "out" and tr._speed > 0.0:
			var before := tr._s
			tr._process(STEP)
			if tr._s == before and tr._phase == "out":
				stopped_out += STEP
				worst_stuck = maxf(worst_stuck, stopped_out)
			else:
				stopped_out = 0.0
	if worst_stuck > 1.0:
		print("TESTI VIKA lähtevä juna seisoi radalla %.1f s (_s %.1f, _pending %.1f)" % [worst_stuck, tr._s, tr._pending])
	if not saw_second:
		print("TESTI VIKA jonoon kutsuttu toinen juna ei tullut laiturille (vaihe '%s', _pending %.1f)" % [tr._phase, tr._pending])
	if worst_stuck <= 1.0 and saw_second:
		print("JUNA OK: lähtevä juna ei jumita, jonoon kutsuttu juna tulee laiturille")
	get_tree().quit()


const STOP_DWELL_HALF := 15.0
