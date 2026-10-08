#!/usr/bin/env python3
"""Lirkuttelubiisi junan ravintolavaunun välikuvaan: assets/music/lirkuttelu.wav.

Ajo: venv/bin/python tools/lirkuttelu.py

Hidas romanttinen bossa nova F-duurissa (92 bpm, 16 tahtia, n. 42 s, saumaton silmukka): sähköpiano soittaa
sointuja bossa-rytmissä, kontrabasso pohjaa ja kvinttiä, harjat sihisevät kahdeksasosia ja vanne lyö bossan
klaavia; saksofonimainen melodia (lisäävä synteesi, viivästetty vibrato, henkäys) lirkuttelee päälle. Lopuksi
kevyt kaiku (Schroeder), jonka häntä taitetaan silmukan alkuun. Kaikki syntetisoidaan, ei ulkoisia näytteitä.
"""
import math
import os
import wave

import numpy as np
from scipy.signal import lfilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music", "lirkuttelu.wav")
SR = 32000
BPM = 92.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LEN = BARS * BAR

CHORDS = [["Fmaj7"], ["Gm7", "C7"], ["Fmaj7"], ["Am7", "D7"], ["Gm7"], ["C7"], ["Am7", "Dm7"], ["Gm7", "C7"],
          ["Fmaj7"], ["Bbmaj7"], ["Am7"], ["D7"], ["Gm7"], ["C7"], ["Fmaj7"], ["C7"]]
VOICING = {"Fmaj7": [57, 60, 64, 65], "Gm7": [58, 62, 65, 67], "C7": [58, 64, 67, 72], "Am7": [55, 60, 64, 67],
           "D7": [54, 60, 62, 66], "Dm7": [57, 60, 62, 65], "Bbmaj7": [57, 62, 65, 70]}
ROOT_NOTE = {"Fmaj7": 41, "Gm7": 43, "C7": 48, "Am7": 45, "D7": 50, "Dm7": 50, "Bbmaj7": 46}
# Melodia tahdeittain: (midi, iskuja); None = tauko.
MELODY = [
    [(69, 1.5), (67, 0.5), (69, 1), (72, 1)], [(70, 1.5), (69, 0.5), (67, 2)],
    [(65, 1), (69, 1), (72, 1), (76, 1)], [(74, 3), (None, 1)],
    [(74, 1.5), (72, 0.5), (70, 1), (69, 1)], [(67, 1.5), (69, 0.5), (70, 1), (72, 1)],
    [(69, 2), (65, 1), (69, 1)], [(67, 3), (None, 1)],
    [(72, 1.5), (69, 0.5), (72, 1), (77, 1)], [(74, 1.5), (72, 0.5), (69, 2)],
    [(76, 1), (74, 1), (72, 1), (69, 1)], [(69, 1.5), (66, 0.5), (69, 1), (72, 1)],
    [(70, 2), (74, 2)], [(76, 1.5), (74, 0.5), (72, 1), (70, 1)],
    [(69, 2), (67, 1), (65, 1)], [(67, 3), (None, 1)],
]


def hz(m):
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def env(n, a, d, s, r, sustain_n):
    """ADSR näytteinä: a, d, r sekunteja, s taso, sustain_n = soivan osan pituus näytteinä."""
    an, dn, rn = int(a * SR), int(d * SR), int(r * SR)
    e = np.zeros(n)
    k = 0
    for seg, length, v0, v1 in (("a", an, 0.0, 1.0), ("d", dn, 1.0, s)):
        L = min(length, n - k)
        if L > 0:
            e[k:k + L] = np.linspace(v0, v1, L, endpoint=False)
            k += L
    hold = max(0, min(sustain_n - k, n - k))
    e[k:k + hold] = s
    k += hold
    L = min(rn, n - k)
    if L > 0:
        e[k:k + L] = np.linspace(s, 0.0, L)
    return e


def add(buf, start, sig):
    i = int(start * SR)
    j = min(len(buf), i + len(sig))
    if j > i:
        buf[i:j] += sig[:j - i]


def ep_note(m, dur, vel):
    """Sähköpiano: kevyt FM (modulaatio vaimenee), kellomainen isku ja tremolo."""
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    idx = 1.6 * np.exp(-t * 6.0) + 0.25
    sig = np.sin(2 * math.pi * f * t + idx * np.sin(2 * math.pi * f * t))
    sig += 0.25 * np.sin(2 * math.pi * 2 * f * t) * np.exp(-t * 3.0)
    sig *= 1.0 + 0.12 * np.sin(2 * math.pi * 4.5 * t)
    return sig * env(n, 0.005, 0.4, 0.45, 0.6, int(dur * SR)) * vel


def bass_note(m, dur, vel):
    n = int((dur + 0.3) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    sig = np.sin(2 * math.pi * f * t) + 0.3 * np.sin(4 * math.pi * f * t) * np.exp(-t * 5.0)
    return sig * env(n, 0.01, 0.25, 0.6, 0.15, int(dur * SR)) * vel


def sax_note(m, dur, vel, rng):
    """Saksofonimainen ääni: harmoniset osasävelet (parittomat vahvempia), viivästetty vibrato ja henkäys."""
    n = int((dur + 0.35) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 1.0 + 0.006 * np.sin(2 * math.pi * 5.3 * t) * np.clip((t - 0.25) / 0.4, 0.0, 1.0)
    ph = 2 * math.pi * f * np.cumsum(vib) / SR
    bright = 0.6 + 0.4 * np.clip(t / 0.15, 0, 1)
    sig = np.zeros(n)
    for h in range(1, 9):
        amp = (1.0 / h) * (1.0 if h % 2 else 0.55) * (bright ** (h - 1))
        sig += amp * np.sin(h * ph)
    breath = lfilter([0.05], [1, -0.95], rng.standard_normal(n)) * 0.25
    sig = sig + breath
    return sig * env(n, 0.06, 0.2, 0.8, 0.25, int(dur * SR)) * vel


def brush(n, rng):
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    noise = noise - lfilter([1.0], [1, -0.85], noise) * 0.9  # ylipäästö: sihinä
    return noise * np.exp(-t * 18.0)


def rim(n):
    t = np.arange(n) / SR
    return (np.sin(2 * math.pi * 1700 * t) + 0.6 * np.sin(2 * math.pi * 820 * t)) * np.exp(-t * 60.0)


def kick(n):
    t = np.arange(n) / SR
    f = 55 + 60 * np.exp(-t * 30)
    return np.sin(2 * math.pi * np.cumsum(f) / SR) * np.exp(-t * 9.0)


def reverb(x):
    out = np.zeros_like(x)
    for d, g in ((1557, 0.78), (1617, 0.77), (1491, 0.79), (1422, 0.8)):
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        out += lfilter([1.0], a, x)
    out /= 4.0
    for d, g in ((225, 0.7), (556, 0.7)):
        b = np.zeros(d + 1)
        b[0] = -g
        b[d] = 1.0
        a = np.zeros(d + 1)
        a[0] = 1.0
        a[d] = -g
        out = lfilter(b, a, out)
    return out


def main():
    rng = np.random.default_rng(812)
    total = int((LEN + 3.0) * SR)
    ep = np.zeros(total)
    bass = np.zeros(total)
    drums = np.zeros(total)
    lead = np.zeros(total)
    for b in range(BARS):
        t0 = b * BAR
        chords = CHORDS[b]
        for ci, name in enumerate(chords):
            ct = t0 + ci * BAR / len(chords)
            span = 4.0 / len(chords)
            for hit, dur in ((0.0, 0.9), (1.5, 0.6), (2.5, 0.5), (3.5, 0.4)):
                if hit < span:
                    vel = 0.11 if hit == 0.0 else 0.08
                    for m in VOICING[name]:
                        add(ep, ct + hit * BEAT + rng.uniform(0, 0.012), ep_note(m, dur * BEAT, vel))
            r = ROOT_NOTE[name]
            pat = ((0.0, r, 1.4), (1.5, r + 7 if r + 7 <= 55 else r - 5, 0.4), (2.0, r, 1.4), (3.5, r + 7 if r + 7 <= 55 else r - 5, 0.4))
            for beat, m, dur in pat:
                if beat < span:
                    add(bass, ct + beat * BEAT, bass_note(m, dur * BEAT, 0.32))
        for k in range(8):
            add(drums, t0 + k * BEAT / 2, brush(int(0.12 * SR), rng) * (0.05 if k % 2 == 0 else 0.03))
        clave = (0.0, 1.5, 3.0) if b % 2 == 0 else (1.0, 2.5)
        for c in clave:
            add(drums, t0 + c * BEAT, rim(int(0.08 * SR)) * 0.08)
        for c in (0.0, 2.0):
            add(drums, t0 + c * BEAT, kick(int(0.3 * SR)) * 0.25)
        tb = t0
        for m, beats in MELODY[b]:
            if m is not None:
                add(lead, tb + 0.01, sax_note(m, beats * BEAT * 0.95, 0.14, rng))
            tb += beats * BEAT
    dry = ep + bass + drums + lead * 1.0
    wet = reverb(ep * 0.6 + lead * 0.9 + drums * 0.3)
    mix = dry + wet * 0.35
    # Silmukka: kaiun ja soivien äänten häntä LEN:n jälkeen alkuun.
    n = int(LEN * SR)
    loop = mix[:n].copy()
    tail = mix[n:]
    loop[:len(tail)] += tail
    loop = np.tanh(loop / max(np.max(np.abs(loop)), 1e-6) * 1.2) * 0.85
    pcm = (loop * 32767).astype("<i2")
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("kirjoitettu", OUT, "%.1f s, %d kt" % (len(loop) / SR, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
