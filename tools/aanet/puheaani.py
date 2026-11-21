# Hahmojen repliikit avoimella puhemallilla (Chatterbox Multilingual, MIT, Resemble AI): malli matkii hahmon
# malliäänen (tools/aanet/malliaanet/, lähteet docs/tekijanoikeudet.md) soinnin, suomeksi. Tiedostot samoilla nimillä
# kuin pelin haku (assets/aanet/<paivi|muu>/<repliikin tiiviste>.mp3, ks. audio.gd voice_key), joten koodi ei muutu.
#
# Jokaisesta repliikistä tehdään EHDOKKAAT versiota, ja niistä valitaan se, jonka suomen puheentunnistus
# (wav2vec2-large-xlsr-53-finnish) kuulee lähimmäs tekstiä: puhemalli sotkee välillä tavuja, ja tämä karsii ne.
# Sävy tehdään jälkikäsittelynä (ks. SAVY): Päivi on vihainen ja huutaa huutomerkkirepliikit, pelaaja on ripityksessä
# nöyrä ja muut hahmot iloisia.
#
# Asennus (kerran, erillinen ympäristö, ei pelin mukana):
#   uv venv -p python3.11 ~/chatterbox && uv pip install -p ~/chatterbox/bin/python chatterbox-tts pyworld "setuptools<81"
# Käyttö:
#   ~/chatterbox/bin/python tools/aanet/puheaani.py [--ryhma paivi|muu|helena|...] [--vain "repliikki" ...] [--testi]
#   ilman valintoja: kaikki hakemisto.json:n repliikit uudelleen (vanhat korvataan), sitten `godot --headless --import`.
#   --vain: vain annetut repliikit (ryhmä --ryhma, oletus muu; lisätään myös hakemisto.json:iin)
#   --ehdokkaat N: versioita repliikkiä kohden (oletus 3; heikoille repliikeille enemmän)
#   --testi: valitut repliikit peräkkäin tiedostoon .claude/tyo/puhe_testi.mp3 (ei kosketa peliin)
import argparse, hashlib, json, os, re, subprocess, tempfile, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VOICES = os.path.join(ROOT, "assets", "aanet")
REFS = os.path.join(os.path.dirname(os.path.abspath(__file__)), "malliaanet")
EHDOKKAAT = 3
SR = 24000

## Hahmon malliääni ja puhetapa: exaggeration = tunteen voimakkuus (0,5 neutraali), cfg pienempi = vapaampi rytmi.
HAHMOT = {
	"paivi": {"ref": "paivi.ogg", "ex": 1.5, "cfg": 0.3},
	"pelaaja_nolo": {"ref": "pelaaja.flac", "ex": 0.3, "cfg": 0.5},  # Päivin ripitys puhelimessa: hiljainen ja nöyrä
	"pelaaja": {"ref": "pelaaja.flac", "ex": 0.8, "cfg": 0.4},  # junassa naisten seurassa: iloinen ja itsevarma
	"helena": {"ref": "helena.flac", "ex": 0.7, "cfg": 0.3},  # junan Helena: flirttaileva, hidas ja lämmin
	"marja": {"ref": "marja.flac", "ex": 0.9, "cfg": 0.4},
	"liisa": {"ref": "liisa.flac", "ex": 0.9, "cfg": 0.4},
	"tarjoilija": {"ref": "tarjoilija.flac", "ex": 0.7, "cfg": 0.4},
	"baarimikko": {"ref": "baarimikko.flac", "ex": 0.9, "cfg": 0.4},
	"ruukki": {"ref": "ruukki.flac", "ex": 0.9, "cfg": 0.4},  # Ruukin porukka Kapteenin Kulmassa
	"kapteeni": {"ref": "kapteeni.flac", "ex": 0.8, "cfg": 0.3},  # vanha merimies, hyväntuulinen kertoja
	"kuski": {"ref": "kuski.flac", "ex": 1.2, "cfg": 0.3},  # auton omistaja huomaa varkauden
	"anna_liisa": {"ref": "anna_liisa.flac", "ex": 0.9, "cfg": 0.4},  # naapuri (neighbor.gd)
}
## Ryhmä, jolla on oma hahmo (esim. "helena": assets/aanet/helena/), puhuu sillä äänellä. Muu-ryhmän repliikin puhuja
## valitaan tekstin alusta; puuttuva = "ruukki" (tavallinen mies).
PUHUJAT = [
	("Kyllä kulta", "pelaaja_nolo"), ("K-kyllä kulta", "pelaaja_nolo"), ("Joo... kyllä kulta", "pelaaja_nolo"),
	("No terve! Kapteenin Kulmaan", "baarimikko"), ("Ko mää olin nuori", "kapteeni"), ("Raahe oli aikoinaan", "kapteeni"),
	("Pekka seisoo torilla", "kapteeni"), ("HEI! MUN AUTO", "kuski"), ("Haloo?! Mun auto", "kuski"),
	("Kas, täällähän on väkeä", "anna_liisa"),
]
## Sävy jälkikäsittelynä (puhemallin exaggeration yksin muuttaa ääntä vähän): [sävelkorko kertaa, intonaation laajuus
## (1 = ennallaan, < 1 latteampi, > 1 eloisampi), ffmpeg-suodatin]. Päivi huutaa huutomerkkirepliikit ja puhuu muut
## kiukkuisesti; pelaaja on ripityksessä nöyrä (matalampi, latteampi, hitaampi, hiljaisempi ja pehmeämpi); Helena
## flirttailee (hieman matalampi, eloisa, hidas ja lämmin); muut ovat iloisia (korkeampi, eloisampi, kirkkaampi).
## Auton omistaja ilman: hänen huutonsa oli käsiteltynä yhtä epäselvä.
HUUTO_AF = "highshelf=f=1800:g=%.1f,acompressor=threshold=-22dB:ratio=5:attack=4:release=60:makeup=%.1f,alimiter=limit=0.95"
ILO = [1.06, 1.35, "highshelf=f=2500:g=2,alimiter=limit=0.95"]
SAVY = {
	"paivi": ([1.3, 1.0, HUUTO_AF % (6.0, 7.0)], [1.15, 1.0, HUUTO_AF % (3.0, 4.0)]),
	"pelaaja_nolo": ([0.93, 0.6, "atempo=0.9,highshelf=f=2500:g=-4,volume=-5dB"],) * 2,
	"helena": ([0.95, 1.25, "atempo=0.92,lowshelf=f=250:g=2,highshelf=f=3000:g=-2,alimiter=limit=0.95"],) * 2,
	"pelaaja": (ILO,) * 2, "marja": (ILO,) * 2, "liisa": (ILO,) * 2, "tarjoilija": (ILO,) * 2,
	"baarimikko": (ILO,) * 2, "ruukki": (ILO,) * 2, "kapteeni": (ILO,) * 2, "anna_liisa": (ILO,) * 2,
}


def voice_key(text: str) -> str:
	"""Sama kuin audio.gd voice_key: SHA-1 riisutusta tekstistä, 12 ensimmäistä merkkiä."""
	return hashlib.sha1(text.strip().encode("utf-8")).hexdigest()[:12]


def spoken(text: str) -> str:
	"""Puhuttava muoto: VERSAALIT tavallisiksi (malli ei tavaa niitä), muuten sama kuin ruudulla."""
	return re.sub(r"\b[A-ZÄÖÅ]{2,}\b", lambda m: m.group(0).capitalize() if m.start() == 0 else m.group(0).lower(), text)


def speaker(group: str, text: str) -> str:
	if group in HAHMOT:
		return group
	return next((h for alku, h in PUHUJAT if text.startswith(alku)), "ruukki")


def tone(who: str, text: str):
	levels = SAVY.get(who)
	if levels is None:
		return None
	return levels[0] if "!" in text else levels[1]


def words(s: str) -> list:
	return re.sub(r"[^a-zåäö ]", " ", s.lower()).split()


def wer(ref: list, hyp: list) -> float:
	d = list(range(len(hyp) + 1))
	for i, a in enumerate(ref, 1):
		p = d[:]
		d[0] = i
		for j, b in enumerate(hyp, 1):
			d[j] = min(p[j] + 1, d[j - 1] + 1, p[j - 1] + (a != b))
	return d[-1] / max(1, len(ref))


def trim(y, margin=0.08, fade=0.02):
	"""Hiljaisuus alusta ja lopusta: raja 40 dB äänitteen huipun alla (20 ms ikkunat), reunaan marginaali ja häivytys.
	ffmpegin silenceremove kiinteällä -45 dB:n rajalla leikkasi hiljaa loppuvan viimeisen tavun ("vahvempaa" -> "vahve")."""
	import numpy as np
	y = np.asarray(y, dtype=np.float64)
	n = int(0.02 * SR)
	rms = np.array([np.sqrt(np.mean(y[i:i + n] ** 2)) for i in range(0, max(1, len(y) - n), n)])
	loud = np.nonzero(rms > rms.max() * 0.01)[0]
	if len(loud) == 0:
		return y
	a = max(0, loud[0] * n - int(margin * SR))
	b = min(len(y), (loud[-1] + 1) * n + int(margin * SR))
	y = y[a:b].copy()
	f = min(int(fade * SR), len(y) // 2)
	y[:f] *= np.linspace(0, 1, f)
	y[len(y) - f:] *= np.linspace(1, 0, f)
	return y


def apply_tone(y, level):
	"""Sävelkorko ja intonaation laajuus WORLD-vokooderilla (formantit paikallaan, ääni ei muutu piipittäväksi),
	sitten loput ffmpeg-suodattimella."""
	import numpy as np, pyworld as pw, soundfile as sf
	y = y.astype(np.float64)
	f0, t = pw.harvest(y, SR, f0_floor=80, f0_ceil=600)
	v = f0 > 0
	if v.any():  # laajuus logaritmisesti puhujan keskikorkeuden ympäri
		mid = np.mean(np.log(f0[v]))
		f0[v] = np.exp(mid + level[1] * (np.log(f0[v]) - mid))
	z = pw.synthesize(f0 * level[0], pw.cheaptrick(y, f0, t, SR), pw.d4c(y, f0, t, SR), SR)
	tmp = tempfile.mkdtemp()
	sf.write(os.path.join(tmp, "a.wav"), z / max(1e-6, np.abs(z).max()) * 0.8, SR)
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(tmp, "a.wav"), "-af",
		level[2], os.path.join(tmp, "b.wav")], check=True)
	return sf.read(os.path.join(tmp, "b.wav"))[0]


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("--ryhma", default=None, help="paivi, muu tai hahmon oma ryhmä (esim. helena)")
	ap.add_argument("--testi", action="store_true")
	ap.add_argument("--vain", nargs="*", default=None)
	ap.add_argument("--ehdokkaat", type=int, default=EHDOKKAAT)
	a = ap.parse_args()
	import numpy as np, soundfile as sf, torch, librosa
	from chatterbox.mtl_tts import ChatterboxMultilingualTTS
	from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor
	_load = torch.load  # mallitiedostot on tallennettu CUDA-laitteelta: ladataan ensin muistiin, sitten laitteelle
	torch.load = lambda *x, **k: _load(*x, **{**k, "map_location": "cpu"})
	dev = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
	m = ChatterboxMultilingualTTS.from_pretrained(device=torch.device(dev))
	asr_name = "jonatasgrosman/wav2vec2-large-xlsr-53-finnish"
	asr_proc, asr = Wav2Vec2Processor.from_pretrained(asr_name), Wav2Vec2ForCTC.from_pretrained(asr_name).eval()

	def hear(y) -> list:
		y16 = librosa.resample(np.asarray(y, dtype=np.float32), orig_sr=SR, target_sr=16000)
		with torch.no_grad():
			ids = asr(asr_proc(y16, sampling_rate=16000, return_tensors="pt").input_values).logits.argmax(-1)
		return words(asr_proc.batch_decode(ids)[0])

	ip = os.path.join(VOICES, "hakemisto.json")
	idx = json.load(open(ip, encoding="utf-8")) if os.path.exists(ip) else {}
	if a.vain:
		lines = [(a.ryhma or "muu", t.strip()) for t in a.vain]
	else:
		lines = [(k.split("/")[0], t) for k, t in sorted(idx.items()) if a.ryhma in (None, k.split("/")[0])]
	tmp = tempfile.mkdtemp()
	refs = {}
	outs = []
	for i, (group, text) in enumerate(lines):
		t0 = time.time()
		who = speaker(group, text)
		h = HAHMOT[who]
		if who not in refs:
			refs[who] = os.path.join(tmp, who + ".wav")
			subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", os.path.join(REFS, h["ref"]), "-ac", "1", "-ar", str(SR),
				refs[who]], check=True)
		level = tone(who, text)
		best = None
		for n in range(a.ehdokkaat):
			torch.manual_seed(1000 + 17 * i + n)
			y = m.generate(spoken(text), language_id="fi", audio_prompt_path=refs[who], exaggeration=h["ex"],
				cfg_weight=h["cfg"], temperature=0.8)[0].cpu().numpy()
			if level is not None:
				y = apply_tone(y, level)
			score = wer(words(text), hear(y))
			if best is None or score < best[0]:
				best = (score, y)
			if score == 0.0:
				break
		w = os.path.join(tmp, "r%03d.wav" % i)
		sf.write(w, best[1], SR)
		if a.testi:
			outs.append(w)
		else:
			dst = os.path.join(VOICES, group, voice_key(text) + ".mp3")
			os.makedirs(os.path.dirname(dst), exist_ok=True)
			sf.write(w, trim(best[1]), SR)
			subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-ar", "22050", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "48k", dst], check=True)
			idx[group + "/" + voice_key(text)] = text
		print("%d/%d %.0f s %s wer %.2f: %s" % (i + 1, len(lines), time.time() - t0, who, best[0], text), flush=True)
	if a.testi:
		sil = os.path.join(tmp, "tauko.wav")
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-t", "0.9", "-i", "anullsrc=r=%d:cl=mono" % SR, sil],
			check=True)
		lst = os.path.join(tmp, "lista.txt")
		with open(lst, "w") as f:
			for w in outs:
				f.write("file '%s'\nfile '%s'\n" % (w, sil))
		out = os.path.join(ROOT, ".claude", "tyo", "puhe_testi.mp3")
		os.makedirs(os.path.dirname(out), exist_ok=True)
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-c:a", "libmp3lame",
			"-b:a", "96k", out], check=True)
		print("testi:", out)
	else:
		with open(ip, "w", encoding="utf-8") as f:
			json.dump(idx, f, ensure_ascii=False, indent="\t", sort_keys=True)


if __name__ == "__main__":
	main()
