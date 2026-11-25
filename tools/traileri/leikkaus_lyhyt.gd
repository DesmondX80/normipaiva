extends RefCounted
## Lyhyet trailerit ilman biisiä, pelin omilla äänillä (--set=juna, --set=mummo). Kaikki otokset ovat sekunteja (s), joten
## koko video on "prologia": musiikki ei soi. Kenttien selitys: leikkaus.gd.

## Junamatka Saloisista Raaheen: neljä katkelmaa pelin omasta välianimaatiosta (lähtö, ravintolavaunu, tarjoilu, Helena); kukin ajaa matkan alusta ja ohittaa alun (otokset_uusi.gd JUNA_ALKU).
const JUNA := [
	{"id": "m_juna_lahto", "g": "juna2", "s": 6.0, "sfx": 1.0},
	{"id": "m_juna_vaalaan", "g": "juna2", "s": 9.0, "sfx": 1.0},
	{"id": "m_juna_tarjoilu", "g": "juna2", "s": 9.0, "sfx": 1.0},
	{"id": "m_juna_helena", "g": "juna2", "s": 9.0, "sfx": 1.0},
	{"id": "loppu_logo", "g": "kortit", "s": 5.0, "logo": true},
]

## Kuolema Raahen K-Marketin rollaattorimummon keppiin ja Päivin puhelu (pelin oma wasted_phone-välianimaatio).
const MUMMO := [
	{"id": "v_mummo", "g": "vmummo", "s": 31.0, "sfx": 1.0},
	{"id": "loppu_logo", "g": "kortit", "s": 5.0, "logo": true},
]
