extends SceneTree
## Trailerin kokoaminen (renderoi.gd ajaa): ryhmien Movie Maker -tallenteista (MJPEG-AVI) poimitaan otokset
## magentaerottimien välistä, ne järjestetään leikkaus.gd:n mukaan ja ääniraidaksi miksataan tunnari ja pelin äänet.
## Tulos: traileri.avi (MJPEG + PCM) ja traileri.wav. MP4:ksi (YouTube): ks. tulostettu ffmpeg-komento.
## Jos video kasvaisi yli 1,9 Gt (AVI-raja), ruudut kirjoitetaan JPEG-kuviksi kansioon ruudut/.
##   godot --path . --headless -s tools/traileri/kokoa.gd -- --in=KANSIO
##   --sheet: esikatselukuvista arkki per ryhmä (esikatselu_<ryhmä>.png: rivi per otos, alku | keski | loppu)

const Leikkaus := preload("res://tools/traileri/leikkaus.gd")
const RATE := 48000
const SPF := RATE / Leikkaus.FPS  # näytettä ruutua kohti (1600)
const AVI_LIMIT := 1_900_000_000

var dir := ""


func _initialize() -> void:
	var sheet := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--in="):
			dir = a.substr(5)
		elif a == "--sheet":
			sheet = true
	if sheet:
		_sheets()
	else:
		_assemble()
	quit()


# --- Esikatseluarkki ---------------------------------------------------------------------------------------------------

func _sheets() -> void:
	var tw := 384
	var th := 216
	var groups := Leikkaus.groups()
	for g in groups:
		var all: Array = groups[g].filter(func(i: String) -> bool: return FileAccess.file_exists(dir.path_join("%s_0.png" % i)))
		for page in ceili(all.size() / 8.0):
			_sheet_page(g, page, all.slice(page * 8, page * 8 + 8), tw, th)


func _sheet_page(g: String, page: int, ids: Array, tw: int, th: int) -> void:
	if true:
		var cols := 0
		while FileAccess.file_exists(dir.path_join("%s_%d.png" % [ids[0], cols])):
			cols += 1
		cols = maxi(cols, 1)
		var img := Image.create((tw + 4) * cols, (th + 4) * ids.size(), false, Image.FORMAT_RGB8)
		img.fill(Color(0.15, 0.15, 0.15))
		for r in ids.size():
			for c in cols:
				var p := dir.path_join("%s_%d.png" % [ids[r], c])
				if not FileAccess.file_exists(p):
					continue
				var s := Image.load_from_file(p)
				s.convert(Image.FORMAT_RGB8)
				s.resize(tw, th, Image.INTERPOLATE_BILINEAR)
				img.blit_rect(s, Rect2i(0, 0, tw, th), Vector2i(c * (tw + 4), r * (th + 4)))
		img.save_png(dir.path_join("esikatselu_%s_%d.png" % [g, page + 1]))
		print("arkki %s %d: %s" % [g, page + 1, ", ".join(ids)])


# --- AVI-luku ------------------------------------------------------------------------------------------------------------

## Palauttaa {"video": [[offset, koko]...], "audio": [[offset, koko]...], "w", "h"}.
func _read_avi(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	var r := {"video": [], "audio": [], "w": 0, "h": 0}
	_walk(f, f.get_length(), r)
	return r


func _walk(f: FileAccess, end: int, r: Dictionary) -> void:
	while f.get_position() + 8 <= end:
		var id := f.get_buffer(4).get_string_from_ascii()
		var sz := f.get_32()
		var start := f.get_position()
		if id == "RIFF" or id == "LIST":
			f.get_buffer(4)
			_walk(f, mini(start + sz, end), r)
		elif id == "00db":
			r.video.append([start, sz])
		elif id == "01wb":
			r.audio.append([start, sz])
		elif id == "avih":
			f.seek(start + 32)
			r.w = f.get_32()
			r.h = f.get_32()
		f.seek(start + sz + (sz & 1))


## Erotinruutu: magenta. JPEG on silloin pieni, joten raskas purku tehdään vain pienille ruuduille.
func _is_sep(f: FileAccess, chunk: Array, small: int) -> bool:
	if chunk[1] > small:
		return false
	f.seek(chunk[0])
	var img := Image.new()
	if img.load_jpg_from_buffer(f.get_buffer(chunk[1])) != OK:
		return false
	var s := img.get_size()
	for p in [Vector2i(s.x / 2, s.y / 2), Vector2i(s.x / 5, s.y / 3), Vector2i(s.x * 4 / 5, s.y * 2 / 3)]:
		var c := img.get_pixelv(p)
		if not (c.r > 0.85 and c.g < 0.2 and c.b > 0.85):
			return false
	return true


## Ryhmän otokset: id -> [[videochunk, audiochunk]...] ja tiedosto.
func _split_group(g: String, ids: Array) -> Dictionary:
	var path := dir.path_join("%s.avi" % g)
	if not FileAccess.file_exists(path):
		push_error("Puuttuu: " + path)
		return {}
	var avi := _read_avi(path)
	var f := FileAccess.open(path, FileAccess.READ)
	var small := int(avi.w * avi.h * 0.02) + 4096  # tasaväriruutu pakkautuu hyvin pieneksi
	var seps := []
	for i in avi.video.size():
		seps.append(_is_sep(f, avi.video[i], small))
	# Otos = erotinjaksojen välissä oleva yhtenäinen jakso.
	var segs := []
	var i := 0
	var n: int = avi.video.size()
	while i < n and not seps[i]:
		i += 1
	while i < n:
		while i < n and seps[i]:
			i += 1
		var a := i
		while i < n and not seps[i]:
			i += 1
		if i < n and i > a:
			segs.append([a, i])
	var res := {"file": path, "shots": {}}
	for k in ids.size():
		if k >= segs.size():
			push_error("Ryhmässä %s ei ole otosta %s" % [g, ids[k]])
			break
		var want := Leikkaus.frames_of(ids[k])
		var take := want + Leikkaus.in_frames(ids[k])  # pitkä otto: käytetään viimeiset want ruutua
		var seg: Array = segs[k]
		if absi(seg[1] - seg[0] - take) > 2:
			push_warning("Otos %s: %d ruutua, odotettiin %d" % [ids[k], seg[1] - seg[0], take])
		var start := maxi(seg[0], seg[1] - want)
		var frames := []
		for j in want:
			var idx := mini(start + j, seg[1] - 1)
			frames.append([avi.video[idx], avi.audio[idx] if idx < avi.audio.size() else null])
		res.shots[ids[k]] = frames
	return res


# --- Musiikki --------------------------------------------------------------------------------------------------------

## Tunnari 48 kHz:n stereona (PackedVector2Array).
func _music() -> PackedVector2Array:
	var s: AudioStream = load(Leikkaus.MUSIC)
	var pb := s.instantiate_playback()
	pb.start(0.0)
	var src := PackedVector2Array()
	var chunk := 4096
	var total := 0
	while total < int(s.get_length() * 50000.0):
		var b: PackedVector2Array = pb.mix_audio(1.0, chunk)
		src.append_array(b)
		total += chunk
	var src_rate := AudioServer.get_mix_rate()
	var outn := int(s.get_length() * RATE)
	var out := PackedVector2Array()
	out.resize(outn)
	var ratio := src_rate / float(RATE)
	for i in outn:
		var x := i * ratio
		var j := int(x)
		if j + 1 >= src.size():
			break
		out[i] = src[j].lerp(src[j + 1], x - j)
	return out


# --- Kokoaminen ------------------------------------------------------------------------------------------------------

func _assemble() -> void:
	var timeline := Leikkaus.timeline()
	var groups := Leikkaus.groups()
	var parts := {}
	for g in groups:
		var p := _split_group(g, groups[g])
		if not p.is_empty():
			parts[g] = p
	var files := {}
	for g in parts:
		files[g] = FileAccess.open(parts[g].file, FileAccess.READ)
	var music := _music()
	var total: int = timeline[-1].start + timeline[-1].frames
	var music_from: int = timeline[0].music_from
	print("Kesto %d ruutua (%.1f s), musiikki alkaa %.2f s" % [total, total / float(Leikkaus.FPS), music_from / float(Leikkaus.FPS)])

	# Arvioidaan koko ensimmäisen ryhmän ruutukoosta.
	var est := 0
	for g in parts:
		for id in parts[g].shots:
			for fr in parts[g].shots[id]:
				est += fr[0][1] + 8
	var to_avi := est + total * (SPF * 4 + 8) < AVI_LIMIT
	var w := 1920
	var h := 1080
	var avi: FileAccess
	var idx := StreamPeerBuffer.new()
	var movi_pos := 0
	if to_avi:
		var any: String = parts.keys()[0]
		var hdr := _read_avi(parts[any].file)
		w = hdr.w
		h = hdr.h
		avi = FileAccess.open(dir.path_join("traileri.avi"), FileAccess.WRITE)
		_write_header(avi, w, h, total)
		movi_pos = avi.get_position() - 4  # 'movi'-tunnisteen paikka (idx1-siirtymät tästä)
	else:
		DirAccess.make_dir_recursive_absolute(dir.path_join("ruudut"))
	var wav := PackedByteArray()
	wav.resize(total * SPF * 4)
	var blank := PackedByteArray()
	blank.resize(SPF * 4)
	var black := _black_jpeg(w, h)
	var peak := 0.0

	for e in timeline:
		var shot := Leikkaus.shot(e.id)
		var g: String = shot.g
		var frames: Array = parts.get(g, {}).get("shots", {}).get(e.id, [])
		if frames.is_empty():
			push_warning("Otos puuttuu, tilalle mustaa: " + e.id)
		var gain: float = shot.get("sfx", SFX_DEFAULT(e))
		for j in e.frames:
			var fi: int = e.start + j
			var jpeg := black
			var pcm := blank
			if j < frames.size():
				var f: FileAccess = files[g]
				f.seek(frames[j][0][0])
				jpeg = f.get_buffer(frames[j][0][1])
				if frames[j][1] != null:
					f.seek(frames[j][1][0])
					pcm = f.get_buffer(frames[j][1][1])
			# Ääni: tunnari + pelin äänet (otoksen alussa ja lopussa lyhyt ristihäivytys napsujen välttämiseksi).
			for s in SPF:
				var mi := (fi - music_from) * SPF + s
				var m := Vector2.ZERO
				if mi >= 0 and mi < music.size():
					m = music[mi] * Leikkaus.MUSIC_GAIN
				var x := Vector2.ZERO
				if s * 4 + 3 < pcm.size():
					x = Vector2(pcm.decode_s16(s * 4), pcm.decode_s16(s * 4 + 2)) / 32768.0
				var edge := minf(float(j * SPF + s), float((e.frames - j) * SPF - s)) / (RATE * 0.03)
				var v := m + x * gain * clampf(edge, 0.0, 1.0)
				v = Vector2(_soft(v.x), _soft(v.y))
				peak = maxf(peak, maxf(absf(v.x), absf(v.y)))
				wav.encode_s16((fi * SPF + s) * 4, int(v.x * 32767.0))
				wav.encode_s16((fi * SPF + s) * 4 + 2, int(v.y * 32767.0))
			var pcm_out := wav.slice(fi * SPF * 4, (fi + 1) * SPF * 4)
			if to_avi:
				_chunk(avi, idx, movi_pos, "00db", jpeg)
				_chunk(avi, idx, movi_pos, "01wb", pcm_out)
			else:
				var jf := FileAccess.open(dir.path_join("ruudut/%05d.jpg" % fi), FileAccess.WRITE)
				jf.store_buffer(jpeg)
		print("  %s: %d ruutua" % [e.id, e.frames])
	if to_avi:
		_finish(avi, idx, movi_pos, total)
	_write_wav(dir.path_join("traileri.wav"), wav)
	print("Huippu %.2f" % peak)
	var src := "traileri.avi" if to_avi else "-framerate 30 -i ruudut/%05d.jpg"
	if to_avi:
		src = "-i traileri.avi"
	print("Valmis: %s" % dir.path_join("traileri.avi" if to_avi else "ruudut"))
	print("MP4 (ffmpeg): cd \"%s\" && ffmpeg %s -i traileri.wav -map 0:v -map 1:a -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p -c:a aac -b:a 320k -shortest traileri.mp4"
		% [dir, src])


func SFX_DEFAULT(e: Dictionary) -> float:
	return Leikkaus.SFX_PRE if e.start < e.music_from else Leikkaus.SFX_MUSIC


## Pehmeä rajoitin: ei leikkaannu, vaikka musiikki ja tehosteet osuvat yhteen.
func _soft(x: float) -> float:
	return x if absf(x) < 0.8 else signf(x) * (0.8 + 0.2 * tanh((absf(x) - 0.8) / 0.2))


func _black_jpeg(w: int, h: int) -> PackedByteArray:
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	return img.save_jpg_to_buffer(0.9)


# --- AVI-kirjoitus (MJPEG + 16-bit PCM 48 kHz, kuten Godotin Movie Maker) ---------------------------------------------

func _fourcc(f: FileAccess, s: String) -> void:
	f.store_buffer(s.to_ascii_buffer())


func _write_header(f: FileAccess, w: int, h: int, n: int) -> void:
	_fourcc(f, "RIFF")
	f.store_32(0)  # paikataan lopuksi
	_fourcc(f, "AVI ")
	_fourcc(f, "LIST")
	f.store_32(4 + 64 + 12 + 64 + 48 + 12 + 64 + 24)
	_fourcc(f, "hdrl")
	_fourcc(f, "avih")
	f.store_32(56)
	for v in [1000000 / Leikkaus.FPS, 0, 0, 0x10, n, 0, 2, 1 << 20, w, h, 0, 0, 0, 0]:
		f.store_32(v)
	# Videovirta
	_fourcc(f, "LIST")
	f.store_32(4 + 64 + 48)
	_fourcc(f, "strl")
	_fourcc(f, "strh")
	f.store_32(56)
	_fourcc(f, "vids")
	_fourcc(f, "MJPG")
	for v in [0, 0, 0, 1, Leikkaus.FPS, 0, n, 1 << 20, 0xFFFFFFFF, 0]:
		f.store_32(v)
	f.store_16(0)
	f.store_16(0)
	f.store_16(w)
	f.store_16(h)
	_fourcc(f, "strf")
	f.store_32(40)
	f.store_32(40)
	f.store_32(w)
	f.store_32(h)
	f.store_16(1)
	f.store_16(24)
	_fourcc(f, "MJPG")
	for v in [w * h * 3, 0, 0, 0, 0]:
		f.store_32(v)
	# Äänivirta
	_fourcc(f, "LIST")
	f.store_32(4 + 64 + 24)
	_fourcc(f, "strl")
	_fourcc(f, "strh")
	f.store_32(56)
	_fourcc(f, "auds")
	f.store_32(0)
	for v in [0, 0, 0, 4, RATE * 4, 0, n * SPF, 12288, 0xFFFFFFFF, 4]:
		f.store_32(v)
	for v in [0, 0, 0, 0]:
		f.store_16(v)
	_fourcc(f, "strf")
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(RATE)
	f.store_32(RATE * 4)
	f.store_16(4)
	f.store_16(16)
	_fourcc(f, "LIST")
	f.store_32(0)  # paikataan lopuksi
	_fourcc(f, "movi")


func _chunk(f: FileAccess, idx: StreamPeerBuffer, movi_pos: int, id: String, data: PackedByteArray) -> void:
	var at := f.get_position()
	_fourcc(f, id)
	f.store_32(data.size())
	f.store_buffer(data)
	if data.size() & 1:
		f.store_8(0)
	idx.put_data(id.to_ascii_buffer())
	idx.put_u32(0x10)
	idx.put_u32(at - movi_pos)
	idx.put_u32(data.size())


func _finish(f: FileAccess, idx: StreamPeerBuffer, movi_pos: int, n: int) -> void:
	var movi_end := f.get_position()
	_fourcc(f, "idx1")
	f.store_32(idx.data_array.size())
	f.store_buffer(idx.data_array)
	var end := f.get_position()
	f.seek(movi_pos - 4)
	f.store_32(movi_end - movi_pos)
	f.seek(4)
	f.store_32(end - 8)
	f.close()


func _write_wav(path: String, pcm: PackedByteArray) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	_fourcc(f, "RIFF")
	f.store_32(36 + pcm.size())
	_fourcc(f, "WAVE")
	_fourcc(f, "fmt ")
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(RATE)
	f.store_32(RATE * 4)
	f.store_16(4)
	f.store_16(16)
	_fourcc(f, "data")
	f.store_32(pcm.size())
	f.store_buffer(pcm)
	f.close()
