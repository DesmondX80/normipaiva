#!/usr/bin/env python3
"""Tanssibiisin iskut seuraintalon tanssien nuottirataan (scripts/tanssibiisit.gd "beats").

Ajo: venv/bin/python tools/tanssibiisi.py assets/music/tanssit/pihalla_tavataan.mp3 [loppu_s] [bpm]

Mittaa äänitteen iskut (librosa beat_track, aloitustempo bpm) ja tulostaa iskujen ajat sekunteina kappaleen
alusta loppu_s:iin asti GDScript-taulukkona. Sunon biisin tempo heittelee hieman, joten nuotit otetaan mitatuista
iskuista eikä tasaisesta tahdista. Tarvitsee: pip install librosa.
"""
import sys

import librosa
import numpy as np


def main() -> None:
    path = sys.argv[1]
    end = float(sys.argv[2]) if len(sys.argv) > 2 else 60.0
    bpm = float(sys.argv[3]) if len(sys.argv) > 3 else 112.0
    y, sr = librosa.load(path, sr=22050, mono=True)
    tempo, beats = librosa.beat.beat_track(y=y, sr=sr, units="time", start_bpm=bpm)
    beats = np.asarray(beats)
    beats = beats[beats <= end]
    print(f"# tempo {float(np.atleast_1d(tempo)[0]):.1f} bpm, {len(beats)} iskua, kesto {len(y) / sr:.1f} s")
    rows = []
    for i in range(0, len(beats), 16):
        rows.append("\t\t" + ", ".join(f"{b:.2f}" for b in beats[i:i + 16]) + ",")
    print('"beats": [\n' + "\n".join(rows) + "\n],")


if __name__ == "__main__":
    main()
