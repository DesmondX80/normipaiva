"""Karaoken ajoitus tunnarille (assets/music/normipaiva.mp3) -> tools/traileri/karaoke.json.

Sanat (LINES) on kuunneltu Whisperillä lauluraidasta ja tarkistettu käsin. Jokaisen sanan aika saadaan pakotetulla
kohdistuksella (CTC forced alignment): suomenkielinen wav2vec2-puhemalli kohdistaa tunnetut sanat kirjain kirjaimelta
lauluraitaan. Kohdistus tehdään laulujaksoittain (CHUNKS: laulu alkaa ja loppuu soittimien välissä).

Valmistelu (ks. LUEMINUT.md, Karaoke):
  1. Laulu erotetaan soittimista:  python -m demucs --two-stems=vocals -n htdemucs tunnari44.wav
  2. Laulu 16 kHz monoksi:         ffmpeg -i vocals.wav -ar 16000 -ac 1 vocals16k.wav
  3. pip install torch torchaudio transformers
Käyttö: python3 tools/traileri/karaoke_ajoitus.py vocals16k.wav > tools/traileri/karaoke.json
"""
import json
import re
import sys
import wave

import torch
import torchaudio.functional as F
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

MODEL = "jonatasgrosman/wav2vec2-large-xlsr-53-finnish"
MAX_WORD = 1.8  # sanan pisin kesto (s): rivin viimeinen merkki venyy kohdistuksessa soittimien päälle

# Laulujaksot (s): lauluraidan voimakkuudesta, ja kunkin jakson rivit.
CHUNKS = [
    (13.0, 49.0, [
        "Aamulla herään Järvikujalla,",
        "jääkaappi tyhjänä, kurkku on kuiva",
        "Ruosteinen pyörä se narisee pihalla,",
        "polkimet kirskuu ja matka on pitkä",
        "Päivi ei tiedä, Päivi ei nää,",
        "punainen Hyundai kulmalla kääntää",
        "Normipäivä Saloisissa,",
        "kuutonen kassissa, kotiin on kiire",
        "Normipäivä Saloisissa,",
        "kaljajemma kasvaa, ei Päivi sitä löydä",
    ]),
    (61.0, 112.0, [
        "Kassalla harmaapäät kolikoita laskee:",
        "viis senttiä, kymmenen ja Ässä-arpa vielä",
        "Ai niin, se paketti, ja jono ei liiku,",
        "Anna-Liisa hyllyn takaa jo Päiville soittaa",
        "Päivi jo tietää, Päivi jo nää,",
        "punainen Hyundai perässä kiitää",
        "Normipäivä Saloisissa,",
        "kuutonen kassissa, kotiin on kiire",
        "Normipäivä Saloisissa,",
        "kaljajemma kasvaa, ei Päivi sitä löydä",
        "Juntti tulee vastaan, karateklubin mies",
        "haastaa ja kassi heilahtaa",
        "Pellolla jyväjemmari traktorilla jahtaa,",
        "ja Pekka huutaa:",
        "”Neljätoista kyyhkyä, perkele!”",
    ]),
    (136.0, 181.0, [
        "Laavulla nuotio ja makkara paistuu,",
        "aurinko laskee Antinsuonkankaan taa",
        "Kun jemmassa on kakskytneljä,",
        "tallissa karburaattori säätöä saa",
        "Normipäivä Saloisissa,",
        "kuutonen kassissa, kotiin on kiire",
        "Normipäivä Saloisissa,",
        "huomenna taas sama,",
        "normipäivä vaan",
        "Normipäivä vaan",
    ]),
]


def spoken(word):
    """Sana mallin merkeiksi: isot kirjaimet (mallin sanasto), välimerkit pois (yhdysviiva = sanaväli)."""
    return re.sub(r"[^A-ZÄÖ ]", "", word.upper().replace("-", " ")).split()


def main():
    w = wave.open(sys.argv[1])
    rate = w.getframerate()
    pcm = torch.frombuffer(bytearray(w.readframes(w.getnframes())), dtype=torch.int16).float() / 32768.0
    proc = Wav2Vec2Processor.from_pretrained(MODEL)
    model = Wav2Vec2ForCTC.from_pretrained(MODEL).eval()
    vocab = proc.tokenizer.get_vocab()
    sep = vocab.get("|", vocab.get(" "))
    lines_out = []
    for t0, t1, lines in CHUNKS:
        audio = pcm[int(t0 * rate):int(t1 * rate)]
        inp = proc(audio.numpy(), sampling_rate=rate, return_tensors="pt")
        with torch.inference_mode():
            logits = model(inp.input_values).logits
        emission = torch.log_softmax(logits, dim=-1)
        sec_per_frame = (len(audio) / rate) / emission.shape[1]
        # Kohde: kaikki jakson sanat merkkeinä, sanojen välissä erotin. Muistiin, mikä merkki kuuluu mihinkin sanaan.
        words = []  # [rivi, näytettävä sana, puhutut osat]
        for li, line in enumerate(lines):
            for disp in line.split(" "):
                words.append([li, disp, spoken(disp)])
        targets, owner = [], []
        for wi, (_, _, parts) in enumerate(words):
            for pi, part in enumerate(parts):
                if targets:
                    targets.append(sep)
                    owner.append(-1)
                for ch in part:
                    targets.append(vocab[ch])
                    owner.append(wi)
        ali, _ = F.forced_align(emission, torch.tensor([targets], dtype=torch.int32), blank=vocab["<pad>"])
        ali = ali[0].tolist()
        # Kehys -> kohteen merkki: CTC-polku käy merkit järjestyksessä (toisto = sama merkki, tyhjä = blank).
        span = {}  # sanan indeksi -> [ensimmäinen kehys, viimeinen kehys]
        ti = -1
        prev = None
        for f, tok in enumerate(ali):
            if tok == vocab["<pad>"]:
                prev = None
                continue
            if tok != prev:
                ti += 1
            prev = tok
            o = owner[ti]
            if o >= 0:
                s = span.setdefault(o, [f, f])
                s[1] = f
        cur = None
        for wi, (li, disp, _) in enumerate(words):
            a = t0 + span[wi][0] * sec_per_frame
            b = t0 + (span[wi][1] + 1) * sec_per_frame
            if cur is None or cur["li"] != li:
                cur = {"li": li, "text": lines[li], "words": []}
                lines_out.append(cur)
            cur["words"].append([disp, round(a, 2), round(b, 2)])
    out = []
    for l in lines_out:
        for wd in l["words"]:
            wd[2] = round(min(wd[2], wd[1] + MAX_WORD), 2)  # venynyt loppu (soittimet jatkuvat) ei täytä riviä
        out.append({"text": l["text"], "start": l["words"][0][1], "end": l["words"][-1][2], "words": l["words"]})
    json.dump({"source": "assets/music/normipaiva.mp3", "model": MODEL, "lines": out}, sys.stdout, ensure_ascii=False,
              indent=1)
    print()


if __name__ == "__main__":
    main()
