# Päivin repliikit uudelleen avoimella puhemallilla (Chatterbox Multilingual, MIT, Resemble AI) malliäänen pohjalta:
# malli matkii malliäänen soinnin ja tyylin (vihainen mutta himokas), suomeksi. Tiedostot samoilla nimillä kuin ennen
# (assets/aanet/paivi/<repliikin tiiviste>.mp3, ks. audio.gd voice_key), joten pelin koodi ei muutu.
#
# Asennus (kerran, erillinen ympäristö, ei pelin mukana):
#   uv venv -p python3.11 ~/chatterbox && uv pip install -p ~/chatterbox/bin/python chatterbox-tts "setuptools<81"
# Käyttö:
#   ~/chatterbox/bin/python tools/aanet/paivi_aani.py <malliääni.wav|m4a> [--testi] [--vain "repliikki" ...]
#   --testi: neljä testirepliikkiä tiedostoon .claude/tyo/paivi_testi.mp3 (ei kosketa peliin)
#   --vain: vain annetut repliikit (lisätään myös hakemisto.json:iin)
#   Pelin malliääni: tools/aanet/paivi_malliaani.ogg (lähde docs/tekijanoikeudet.md).
#   ilman: kaikki hakemisto.json:n paivi/-repliikit uudelleen (vanhat korvataan), sitten `godot --import`.
import argparse, hashlib, json, os, re, subprocess, sys, tempfile, time

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
VOICES = os.path.join(ROOT, "assets", "aanet")
TESTI = ["Auton alle! Mopolla! Taas!", "Koko yö neulan kanssa keittiön pöydällä!",
	"Ja kenen kanssa se tanssii?! Kuka toi blondi on?!",
	"MISSÄ SE MAITO ON?! Koko yö kolmiomittaamassa, eikä ees maitoa!"]
EXAGGERATION = 0.85  # tunteen voimakkuus (0,5 = neutraali)
CFG = 0.25  # pienempi = vapaampi, hitaampi rytmi
TEMPERATURE = 0.8


def voice_key(text: str) -> str:
	"""Sama kuin audio.gd voice_key: SHA-1 riisutusta tekstistä, 12 ensimmäistä merkkiä."""
	return hashlib.sha1(text.strip().encode("utf-8")).hexdigest()[:12]


def spoken(text: str) -> str:
	"""Puhuttava muoto: VERSAALIT tavallisiksi (malli ei tavaa niitä), muuten sama kuin ruudulla."""
	return re.sub(r"\b[A-ZÄÖÅ]{2,}\b", lambda m: m.group(0).capitalize() if m.start() == 0 else m.group(0).lower(), text)


def to_wav(src: str, dst: str) -> None:
	subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-ac", "1", "-ar", "24000", dst], check=True)


def main() -> None:
	ap = argparse.ArgumentParser()
	ap.add_argument("malliaani")
	ap.add_argument("--testi", action="store_true")
	ap.add_argument("--vain", nargs="*", default=None)
	a = ap.parse_args()
	import torch, torchaudio as ta
	from chatterbox.mtl_tts import ChatterboxMultilingualTTS
	torch.set_num_threads(os.cpu_count() or 4)
	tmp = tempfile.mkdtemp()
	ref = os.path.join(tmp, "malli.wav")
	to_wav(a.malliaani, ref)
	m = ChatterboxMultilingualTTS.from_pretrained(device="cpu")
	if a.testi:
		lines = TESTI
	elif a.vain:
		lines = a.vain
	else:
		idx = json.load(open(os.path.join(VOICES, "hakemisto.json"), encoding="utf-8"))
		lines = [t for k, t in sorted(idx.items()) if k.startswith("paivi/")]
	outs = []
	for i, text in enumerate(lines):
		t0 = time.time()
		torch.manual_seed(1000 + i)
		wav = m.generate(spoken(text), language_id="fi", audio_prompt_path=ref, exaggeration=EXAGGERATION,
			cfg_weight=CFG, temperature=TEMPERATURE)
		w = os.path.join(tmp, "r%03d.wav" % i)
		ta.save(w, wav, m.sr)
		if a.testi:
			outs.append(w)
		else:
			dst = os.path.join(VOICES, "paivi", voice_key(text) + ".mp3")
			subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", w, "-af",
				"silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse",
				"-ar", "22050", "-ac", "1", "-c:a", "libmp3lame", "-b:a", "48k", dst], check=True)
			if a.vain:  # uusi repliikki hakemistoon (kuten audio.gd _synthesize)
				ip = os.path.join(VOICES, "hakemisto.json")
				idx = json.load(open(ip, encoding="utf-8")) if os.path.exists(ip) else {}
				idx["paivi/" + voice_key(text)] = text.strip()
				with open(ip, "w", encoding="utf-8") as f:
					json.dump(idx, f, ensure_ascii=False, indent="\t", sort_keys=True)
		print("%d/%d %.0f s: %s" % (i + 1, len(lines), time.time() - t0, text), flush=True)
	if a.testi:
		sil = os.path.join(tmp, "tauko.wav")
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "lavfi", "-t", "0.9", "-i", "anullsrc=r=24000:cl=mono", sil],
			check=True)
		lst = os.path.join(tmp, "lista.txt")
		with open(lst, "w") as f:
			for w in outs:
				f.write("file '%s'\nfile '%s'\n" % (w, sil))
		out = os.path.join(ROOT, ".claude", "tyo", "paivi_testi.mp3")
		os.makedirs(os.path.dirname(out), exist_ok=True)
		subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "concat", "-safe", "0", "-i", lst, "-ar", "24000", "-c:a",
			"libmp3lame", "-b:a", "96k", out], check=True)
		print("testi:", out)


if __name__ == "__main__":
	main()
