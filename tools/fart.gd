extends SceneTree
## Syntetisoi spurtin pieruäänet assets/sounds/fart_0–2.wav (tehty tätä peliä varten, ei äänitteitä). Ajo:
##   godot --headless --path . -s tools/fart.gd

const RATE := 22050
## Muunnelmat: [kesto s, perustaajuus Hz, huojunta Hz, pulssin leveys, suodatin Hz, siemen].
const VARIANTS := [
	[0.55, 92.0, 9.0, 0.22, 750.0, 11],
	[0.8, 74.0, 6.5, 0.18, 620.0, 23],
	[0.4, 118.0, 12.0, 0.28, 900.0, 37],
]


func _init() -> void:
	for i in VARIANTS.size():
		var v: Array = VARIANTS[i]
		var path := "res://assets/sounds/fart_%d.wav" % i
		_make(v[0], v[1], v[2], v[3], v[4], v[5]).save_to_wav(path)
		print("Kirjoitettu ", path)
	quit()


func _make(dur: float, f0: float, wobble: float, duty: float, cutoff: float, rng_seed: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var n := int(dur * RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase := 0.0
	var lp := 0.0
	var lp2 := 0.0
	var noise_lp := 0.0
	var jitter := 0.0
	var gate := 1.0
	var gate_t := 0.0
	var a_lp := exp(-TAU * cutoff / RATE)
	var a_noise := exp(-TAU * 400.0 / RATE)
	for s in n:
		var t := float(s) / RATE
		var k := t / dur
		# Sävel huojuu ja laskee loppua kohti; pieni satunnainen värinä tekee siitä lihaisan.
		jitter = lerpf(jitter, rng.randf_range(-1.0, 1.0), 0.002)
		var f := f0 * (1.0 + 0.16 * sin(TAU * wobble * t) + 0.12 * jitter) * (1.0 - 0.35 * k)
		phase = fmod(phase + f / RATE, 1.0)
		# Läppäävä pulssi (kapea) + saha: runsaasti yläsävelisiä, suodatetaan pehmeäksi.
		var raw := (1.0 if phase < duty else -duty / (1.0 - duty)) * 0.7 + (phase * 2.0 - 1.0) * 0.3
		noise_lp = lerpf(rng.randf_range(-1.0, 1.0), noise_lp, a_noise)
		raw += noise_lp * 0.5
		lp = lerpf(raw, lp, a_lp)
		lp2 = lerpf(lp, lp2, a_lp)
		# Verho: nopea alku, loppua kohti pärinää ja katkeilua.
		var env := minf(t / 0.015, 1.0) * pow(1.0 - k, 0.6)
		env *= 0.65 + 0.35 * pow(sin(TAU * wobble * 1.7 * t), 2.0)
		gate_t -= 1.0 / RATE
		if gate_t <= 0.0:
			gate_t = rng.randf_range(0.02, 0.06)
			gate = 1.0 if k < 0.55 or rng.randf() < 0.65 else 0.15
		env *= gate
		var y := clampf(lp2 * env * 2.6, -1.0, 1.0)
		data.encode_s16(s * 2, int(y * 32000.0))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = data
	return st
