#!/usr/bin/env python3
"""Lirkuttelubiisi junan ravintolavaunun välikuvaan: assets/music/lirkuttelu.wav.

Ajo: venv/bin/python tools/lirkuttelu.py

Hidas, pehmeä 70-luvun soul-balladi (inspiraationa Chefin "No Substitute"): Es-duuri, 66 bpm, 16 tahtia
(n. 58 s, saumaton silmukka). Sähköpiano soittaa pitkiä nonsointuja hiljaa, jousimatto kelluu taustalla,
lämmin basso liukuu, wah-kitara näppäilee vaimeasti takaiskuilla, rummut harjoilla (pehmeä potku, vanne 2 ja 4,
keinuvat hi-hatit) ja vaimea flyygelitorvimainen melodia soittaa harvakseltaan. Kaikki hiljaista ja väljää:
ei päällekäyvä. Lopuksi kevyt kaiku (Schroeder), jonka häntä taitetaan silmukan alkuun. Kaikki syntetisoidaan.
"""
import math
import os
import wave

import numpy as np
from scipy.signal import lfilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "music", "lirkuttelu.wav")
SR = 32000
BPM = 66.0
BEAT = 60.0 / BPM
BAR = 4 * BEAT
BARS = 16
LEN = BARS * BAR

CHORDS = [["Ebmaj9"], ["Gm7", "Cm9"], ["Fm9"], ["Bb13"], ["Ebmaj9"], ["Gm7", "Cm9"], ["Abmaj7"], ["Bb13"],
          ["Abmaj7"], ["Gm7"], ["Fm9"], ["Bb13"], ["Ebmaj9"], ["Cm9"], ["Fm9"], ["Bb13"]]
VOICING = {"Ebmaj9": [55, 58, 62, 65], "Gm7": [53, 58, 62, 65], "Cm9": [55, 58, 62, 63], "Fm9": [56, 60, 63, 67],
           "Bb13": [56, 62, 67, 68], "Abmaj7": [55, 60, 63, 67]}
ROOT_NOTE = {"Ebmaj9": 39, "Gm7": 43, "Cm9": 36, "Fm9": 41, "Bb13": 34, "Abmaj7": 44}
# Melodia tahdeittain: (midi, iskuja); None = tauko. Harva, paljon taukoja.
MELODY = [
    [(None, 1), (70, 1.5), (67, 0.5), (70, 1)], [(72, 2), (None, 2)],
    [(None, 1), (68, 1), (72, 1), (75, 1)], [(74, 3), (None, 1)],
    [(None, 1), (70, 1.5), (67, 0.5), (65, 1)], [(67, 2), (63, 2)],
    [(None, 1), (72, 1), (70, 1), (68, 1)], [(70, 3), (None, 1)],
    [(None, 1), (75, 1.5), (74, 0.5), (72, 1)], [(70, 2), (None, 2)],
    [(None, 1), (68, 1), (72, 1), (77, 1)], [(75, 1.5), (74, 0.5), (72, 2)],
    [(None, 1), (70, 1.5), (67, 0.5), (70, 1)], [(72, 1.5), (70, 0.5), (67, 2)],
    [(None, 1), (68, 1), (65, 1), (63, 1)], [(65, 3), (None, 1)],
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
    idx = 0.9 * np.exp(-t * 5.0) + 0.15
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


def pad_note(m, dur, vel, rng):
    """Jousimatto: kolme hieman epävireistä sahaa, alipäästö ja hidas nousu/lasku."""
    n = int((dur + 1.5) * SR)
    t = np.arange(n) / SR
    sig = np.zeros(n)
    for det in (-0.07, 0.0, 0.08):
        f = hz(m + det)
        sig += 2.0 * ((t * f + rng.uniform()) % 1.0) - 1.0
    sig = lfilter([0.06], [1, -0.94], sig)
    return sig * env(n, 0.9, 0.5, 0.8, 1.4, int(dur * SR)) * vel


def wah_note(m, dur, vel):
    """Wah-kitara: lyhyt näppäys, jonka resonanssisuodin aukeaa ja sulkeutuu (kaistanpäästön keskitaajuus liukuu)."""
    n = int((dur + 0.2) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    raw = 2.0 * ((t * f) % 1.0) - 1.0
    out = np.zeros(n)
    y1 = y2 = 0.0
    for i in range(0, n, 64):
        fc = 500.0 + 1300.0 * math.sin(min(t[i] / max(dur, 0.05), 1.0) * math.pi)
        r = 0.97
        th = 2 * math.pi * fc / SR
        a1, a2 = -2 * r * math.cos(th), r * r
        seg = raw[i:i + 64]
        o = np.empty(len(seg))
        for j, x in enumerate(seg):
            y = (1 - r) * x - a1 * y1 - a2 * y2
            y2, y1 = y1, y
            o[j] = y
        out[i:i + 64] = o
    return out * env(n, 0.004, 0.12, 0.3, 0.08, int(dur * SR)) * vel * 6.0


def horn_note(m, dur, vel, rng):
    """Vaimea flyygelitorvi: pehmeät osasävelet, hidas nousu ja viivästetty vibrato."""
    n = int((dur + 0.5) * SR)
    t = np.arange(n) / SR
    f = hz(m)
    vib = 1.0 + 0.004 * np.sin(2 * math.pi * 4.8 * t) * np.clip((t - 0.35) / 0.5, 0.0, 1.0)
    ph = 2 * math.pi * f * np.cumsum(vib) / SR
    sig = np.sin(ph) + 0.35 * np.sin(2 * ph) + 0.12 * np.sin(3 * ph) + 0.04 * np.sin(4 * ph)
    sig += lfilter([0.03], [1, -0.97], rng.standard_normal(n)) * 0.15
    return sig * env(n, 0.12, 0.3, 0.8, 0.4, int(dur * SR)) * vel


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
    total = int((LEN + 4.0) * SR)
    ep = np.zeros(total)
    pad = np.zeros(total)
    gtr = np.zeros(total)
    bass = np.zeros(total)
    drums = np.zeros(total)
    lead = np.zeros(total)
    swing = 0.62  # kahdeksasosien keinu
    for b in range(BARS):
        t0 = b * BAR
        chords = CHORDS[b]
        for ci, name in enumerate(chords):
            ct = t0 + ci * BAR / len(chords)
            span = 4.0 / len(chords)
            for m in VOICING[name]:
                add(ep, ct + rng.uniform(0, 0.03), ep_note(m, span * BEAT * 0.95, 0.07))
                add(pad, ct, pad_note(m + 12, span * BEAT, 0.035, rng))
            r = ROOT_NOTE[name]
            pat = ((0.0, r, 1.3), (1.5, r + 12, 0.4), (2.0 if span > 2 else 9, r + 7, 0.9), (3.5, r, 0.4))
            for beat, m, dur in pat:
                if beat < span:
                    add(bass, ct + beat * BEAT, bass_note(m, dur * BEAT, 0.3))
            for beat in (1.0, 3.0):  # wah takaiskuilla
                if beat < span:
                    add(gtr, ct + beat * BEAT + 0.01, wah_note(VOICING[name][-1], 0.35 * BEAT, 0.05))
        for k in range(8):
            off = (k // 2) * BEAT + (swing * BEAT if k % 2 else 0.0)
            add(drums, t0 + off, brush(int(0.09 * SR), rng) * (0.025 if k % 2 == 0 else 0.016))
        for c in (1.0, 3.0):
            add(drums, t0 + c * BEAT, rim(int(0.08 * SR)) * 0.035)
            add(drums, t0 + c * BEAT, brush(int(0.25 * SR), rng) * 0.04)
        for c in (0.0, 1.5 + swing - 0.5, 2.5):
            add(drums, t0 + c * BEAT, kick(int(0.35 * SR)) * 0.2)
        tb = t0
        for m, beats in MELODY[b]:
            if m is not None:
                add(lead, tb + 0.02, horn_note(m, beats * BEAT * 0.92, 0.07, rng))
            tb += beats * BEAT
    dry = ep + pad + gtr + bass + drums + lead
    wet = reverb(ep * 0.7 + pad * 0.8 + lead * 0.9 + gtr * 0.5 + drums * 0.2)
    mix = dry + wet * 0.45
    # Silmukka: kaiun ja soivien äänten häntä LEN:n jälkeen alkuun.
    n = int(LEN * SR)
    loop = mix[:n].copy()
    tail = mix[n:]
    loop[:len(tail)] += tail
    loop = loop / max(np.max(np.abs(loop)), 1e-6) * 0.6  # väljä taso, ei puristusta
    pcm = (loop * 32767).astype("<i2")
    with wave.open(OUT, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print("kirjoitettu", OUT, "%.1f s, %d kt" % (len(loop) / SR, os.path.getsize(OUT) // 1024))


if __name__ == "__main__":
    main()
