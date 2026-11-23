"""Kaisuan työkoneiden äänet (assets/sounds/kone_*.ogg): syntetisoitu tätä peliä varten, CC0. Jokainen on 3 s silmukka,
jonka loppu häivytetään ristiin alkuun (ei naksahdusta saumassa). Moottori soi erikseen (tractor_engine.ogg).

- kone_niitto: rumpuniittokoneen kiekot (perustaajuus 31 Hz yläsävelineen, kiekkojen sykintä) ja korsien suhina.
- kone_karho: karhottimen piikit: hampaiden kilahdukset 14 kertaa sekunnissa, roottorin humina ja heinän kahina.
- kone_paalain: paalaimen mäntä tömähtää 1,5 kertaa sekunnissa, sidontalaitteen naksahdus ja noukinpiikkien rapina.
- kone_maa: aura ja äes: mullan rouhinta (ruskea kohina, rakeiset kivenrapsahdukset) ja vannasten matala jyly.
- kone_kylvo: kylvökoneen syöttölaitteen tikitys ja siementen sihinä putkissa.
- kone_puinti: puimurin puintikoneisto: rummun jyly (68 Hz), olkien kahina ja olkipöydän kolke kolmesti sekunnissa.
- sade: tasainen sade (sadepäivä mökin seudulla): suhina, matala kohina ja satunnaiset pisaroiden napsahdukset.
Ajo: python3 -I tools/aanet/rakenna_tyokoneet.py <pelin kansio>
"""
import numpy as np, subprocess, sys, os

G = sys.argv[1]
SR = 44100
DUR = 3.0
N = int(SR * DUR)
FADE = int(0.25 * SR)
t = np.arange(N + FADE) / SR


def lp(x, a):
    """Yksinapainen alipäästö (a = 0..1, pieni = matala)."""
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def hp(x, a):
    return x - lp(x, a)


def noise(rng, n=None):
    return rng.uniform(-1, 1, len(t) if n is None else n).astype(np.float64)


def clicks(rng, rate, jitter, decay, tone, amp_var=0.4, n=None):
    """Kilahdukset (rate kpl/s): lyhyt vaimeneva kohina + sävy."""
    n = len(t) if n is None else n
    out = np.zeros(n)
    k = int(decay * 6 * SR)
    tt = np.arange(k) / SR
    env = np.exp(-tt / decay)
    tick = 0.0
    while tick < n / SR:
        i = int(tick * SR)
        nz = rng.uniform(-1, 1, k) * 0.6 + np.sin(2 * np.pi * tone * rng.uniform(0.9, 1.1) * tt) * 0.8
        g = 1.0 - amp_var * rng.random()
        seg = nz * env * g
        out[i:i + k] += seg[:max(0, min(k, n - i))]
        tick += (1.0 / rate) * (1.0 + rng.uniform(-jitter, jitter))
    return out


def thump(f0, tau, n):
    tt = np.arange(n) / SR
    f = 40 + (f0 - 40) * np.exp(-tt / 0.03)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.minimum(tt / 0.002, 1) * np.exp(-tt / tau)


def loop(x):
    """Silmukaksi: viimeinen FADE ristiin alkuun."""
    y = x[:N].copy()
    w = np.linspace(0, 1, FADE)
    y[:FADE] = x[N:N + FADE] * (1 - w) + x[:FADE] * w
    return y


def save(name, x, level_db):
    x = loop(x)
    x = x / (np.sqrt(np.mean(x ** 2)) + 1e-9) * 10 ** (level_db / 20)
    lim = 10 ** (-1 / 20)
    x = lim * np.tanh(x / lim)
    path = os.path.join(G, "assets/sounds", name + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "1", "-i", "-", "-c:a", "libvorbis",
                    "-q:a", "4", path], input=(x * 32767).astype(np.int16).tobytes(), check=True)
    print(name, "rms %.1f dB, huippu %.2f" % (20 * np.log10(np.sqrt(np.mean(x ** 2))), np.abs(x).max()))


def niitto(rng):
    base = sum(np.sin(2 * np.pi * 31 * h * t + rng.uniform(0, 6)) / h for h in range(1, 9))
    puls = 0.75 + 0.25 * np.sin(2 * np.pi * 9.3 * t)  # kiekkojen terät
    swish = hp(lp(noise(rng), 0.5), 0.08) * (0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t + 1.0))
    grass = clicks(rng, 60, 0.6, 0.004, 2600, 0.7) * 0.25
    return base * puls * 0.35 + swish * 0.9 + grass


def karho(rng):
    hum = lp(noise(rng), 0.02) * 4.0 + np.sin(2 * np.pi * 52 * t) * 0.15
    tines = clicks(rng, 14, 0.15, 0.012, 1900) * 0.7 + clicks(rng, 14, 0.15, 0.008, 3100) * 0.35
    rustle = hp(lp(noise(rng), 0.35), 0.1) * 0.35 * (0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 1.4 * t)))
    return hum + tines + rustle


def paalain(rng):
    n = len(t)
    out = np.zeros(n)
    k = int(0.35 * SR)
    period = 1.0 / 1.5
    tick = 0.0
    while tick < n / SR:
        i = int(tick * SR)
        th = thump(rng.uniform(85, 100), 0.06, k) * 1.4 + lp(rng.uniform(-1, 1, k), 0.15) * np.exp(-np.arange(k) / SR / 0.015) * 2.0
        out[i:i + k] += th[:max(0, min(k, n - i))]
        j = int((tick + period * 0.55) * SR)  # sidontalaitteen naksahdus männän välissä
        c = clicks(rng, 1, 0, 0.006, 2400, 0, int(0.05 * SR)) * 0.5
        out[j:j + len(c)] += c[:max(0, min(len(c), n - j))]
        tick += period
    pickup = clicks(rng, 22, 0.4, 0.006, 1500, 0.6) * 0.3 + hp(lp(noise(rng), 0.3), 0.1) * 0.25
    return out + pickup + lp(noise(rng), 0.02) * 2.0


def maa(rng):
    rumble = lp(lp(noise(rng), 0.01), 0.05) * 18.0  # vannasten jyly
    soil = lp(noise(rng), 0.12) * (0.6 + 0.4 * lp(np.abs(noise(rng)), 0.0008) * 3.0)  # mullan rouhinta
    grit = clicks(rng, 35, 0.9, 0.003, 3500, 0.9) * 0.35  # kivenrapsahdukset
    knock = clicks(rng, 2.2, 0.5, 0.03, 260, 0.5) * 0.5  # kivi vannasta vasten
    return rumble + soil * 1.2 + grit + knock


def kylvo(rng):
    ticks = clicks(rng, 18, 0.05, 0.004, 4200, 0.2) * 0.6
    hiss = hp(lp(noise(rng), 0.6), 0.25) * (0.5 + 0.2 * np.sin(2 * np.pi * 0.9 * t))
    seeds = clicks(rng, 120, 0.9, 0.0015, 6000, 0.9) * 0.18
    return ticks + hiss + seeds + lp(noise(rng), 0.02) * 1.5


def puinti(rng):
    drum = sum(np.sin(2 * np.pi * 68 * h * t + rng.uniform(0, 6)) / (h * h) for h in range(1, 6)) * 0.5
    roar = lp(noise(rng), 0.08) * 1.4
    straw = hp(lp(noise(rng), 0.4), 0.12) * 0.45 * (0.7 + 0.3 * np.sin(2 * np.pi * 3.0 * t))
    walkers = clicks(rng, 3.0, 0.05, 0.04, 180, 0.2) * 0.8 + clicks(rng, 3.0, 0.05, 0.01, 1200, 0.3) * 0.25
    return drum + roar + straw + walkers


def sade(rng):
    hiss = hp(lp(noise(rng), 0.45), 0.06) * (0.85 + 0.15 * lp(noise(rng), 0.0005) * 8.0)
    body = lp(noise(rng), 0.05) * 1.8
    drops = clicks(rng, 90, 1.0, 0.003, 3200, 0.95) * 0.3 + clicks(rng, 25, 1.0, 0.006, 1400, 0.9) * 0.25
    return hiss + body + drops


rng = np.random.default_rng(7)
for name, fn, db in [("kone_niitto", niitto, -17), ("kone_karho", karho, -18), ("kone_paalain", paalain, -16),
                     ("kone_maa", maa, -17), ("kone_kylvo", kylvo, -19), ("kone_puinti", puinti, -15), ("sade", sade, -20)]:
    save(name, fn(rng), db)
