extends RefCounted
## Seuraintalon tanssien biisit (tanssi_game.gd): Saloisten Saapasjalkojen äänitteet ja pelin tunnari ja niistä tehdyt
## nuottiradat; tanssiin arvotaan yksi.
## Iskut on mitattu äänitteestä (tools/tanssibiisi.py), koska Sunon biisin tempo heittelee hieman: nuotti osuu aina
## oikeaan iskuun. Osat (alkusoitto, säkeistö, kertosäe) on tunnistettu äänitteen stereokuvasta (säkeistössä laulaja
## yksin keskellä, kertosäkeessä koko bändi ja kuoro leveänä) ja sointujen toistosta; HEI!-huudon iskun voi siirtää.
## Tahti = 4 iskua; osien ja tuplien numerot ovat tahteja (0 = ensimmäinen isku), hei on iskun numero ja huuto sen teksti.

const SONGS := [
	{
		"title": "Pihalla tavataan",
		"file": "res://assets/music/tanssit/pihalla_tavataan.mp3",
		"bpm": 112.0,
		"end": 56.0,  # tanssi loppuu (s): ensimmäisen kertosäkeen HEI! ja kaksi tahtia perään
		"fade": 2.5,  # musiikki häipyy ennen loppua (s)
		# Osat: [alkutahti, nimi, nuotti joka n:nnellä iskulla]
		"osat": [[0, "Alkusoitto", 0], [2, "Alkusoitto", 2], [8, "Säkeistö", 1], [16, "Kertosäe!", 1], [24, "Loppusoitto", 0]],
		"tuplat": [17, 19, 21, 22],  # kertosäkeen tahdit, joissa 3. iskun perään tuplasteppi (kahdeksasosa)
		"hei": [96],  # "pihalla tavataan, kun humppa loppuu! HEI!" (tahti 24)
		"huuto": "HEI!",
		"beats": [
			0.14, 0.81, 1.37, 1.83, 2.37, 2.93, 3.46, 3.88, 4.41, 4.95, 5.50, 6.04, 6.57, 7.11, 7.66, 8.20,
			8.71, 9.24, 9.80, 10.33, 10.87, 11.42, 11.96, 12.49, 13.03, 13.58, 14.12, 14.68, 15.21, 15.74, 16.30, 16.83,
			17.37, 17.93, 18.46, 19.02, 19.55, 20.09, 20.64, 21.18, 21.71, 22.27, 22.80, 23.36, 23.89, 24.45, 25.01, 25.54,
			26.08, 26.63, 27.19, 27.72, 28.26, 28.82, 29.35, 29.91, 30.44, 30.98, 31.53, 32.09, 32.62, 33.13, 33.72, 34.25,
			34.81, 35.36, 35.92, 36.46, 36.99, 37.55, 38.08, 38.61, 39.17, 39.71, 40.26, 40.82, 41.35, 41.89, 42.45, 42.96,
			43.54, 44.09, 44.63, 45.16, 45.72, 46.25, 46.79, 47.35, 47.88, 48.44, 48.97, 49.50, 50.06, 50.62, 51.15, 51.69,
			52.22, 52.78, 53.34, 53.87, 54.43, 54.98, 55.52, 56.08, 56.61, 57.14, 57.70,
		],
	},
	{
		"title": "Rasvanappi",
		"file": "res://assets/music/tanssit/rasvanappi.mp3",
		"bpm": 129.0,  # letkajenkka
		"end": 44.3,  # ensimmäisen kertosäkeen HEP! ja kaksi tahtia perään
		"fade": 2.5,
		# Tahti 13: "Mää kuiskaan: Rasvanappi!" yksin hiljaa, bändi tauolla: ei askelia.
		"osat": [[0, "Alkusoitto", 0], [2, "Alkusoitto", 2], [6, "Säkeistö", 1], [13, "Shh... Rasvanappi!", 0],
			[14, "Kertosäe!", 1], [22, "Loppusoitto", 0]],
		"tuplat": [],  # 129 iskua/min: kahdeksasosat olisivat liian tiheitä
		"hei": [88],  # "nuole sormi, sää oot se! HEP!" (tahti 22)
		"huuto": "HEP!",
		"beats": [
			0.21, 0.67, 1.11, 1.58, 2.04, 2.51, 2.97, 3.44, 3.88, 4.34, 4.78, 5.25, 5.71, 6.18, 6.64, 7.11,
			7.57, 8.03, 8.48, 8.94, 9.40, 9.87, 10.33, 10.80, 11.26, 11.73, 12.17, 12.63, 13.10, 13.56, 14.00, 14.47,
			14.93, 15.37, 15.86, 16.30, 16.76, 17.23, 17.69, 18.16, 18.60, 19.06, 19.55, 20.02, 20.48, 20.92, 21.39, 21.85,
			22.27, 22.78, 23.24, 23.71, 24.17, 24.64, 25.10, 25.52, 25.98, 26.45, 26.89, 27.38, 27.84, 28.31, 28.77, 29.21,
			29.68, 30.14, 30.60, 31.05, 31.51, 31.97, 32.44, 32.88, 33.34, 33.81, 34.27, 34.71, 35.18, 35.64, 36.11, 36.57,
			37.04, 37.48, 37.94, 38.41, 38.87, 39.33, 39.80, 40.24, 40.70, 41.17, 41.61, 42.07, 42.54, 43.00, 43.47, 43.93,
			44.40, 44.84, 45.30, 45.77,
		],
	},
	{
		"title": "Normipäivä",
		"file": "res://assets/music/normipaiva.mp3",  # pelin tunnari
		"bpm": 152.0,
		"end": 50.5,  # ensimmäinen kertosäe loppuu 48 s ("kaljajemma kasvaa, ei Päivi sitä löydä")
		"fade": 2.5,
		# Sanojen ajat karaokeversiosta (normipaiva_sanat_lyhyt.json) + 11,3 s (lyhyestä versiosta on leikattu alkusoitto): säkeistö
		# alkaa 13,7 s ja kertosäe 35,3 s. Nopea tempo: säkeistössä askel joka toisella iskulla.
		"osat": [[0, "Alkusoitto", 0], [4, "Alkusoitto", 4], [8, "Säkeistö", 2], [22, "Kertosäe!", 1], [30, "Loppusoitto", 0]],
		"tuplat": [],
		"hei": [87, 103],  # kertosäkeen "Normipäivä Saloisissa" (35,3 ja 41,7 s)
		"huuto": "NORMIPÄIVÄ!",
		"beats": [
			0.37, 0.74, 1.11, 1.53, 1.93, 2.32, 2.74, 3.13, 3.53, 3.92, 4.32, 4.71, 5.13, 5.53, 5.92, 6.32,
			6.71, 7.11, 7.52, 7.92, 8.31, 8.71, 9.10, 9.52, 9.94, 10.33, 10.73, 11.12, 11.52, 11.91, 12.33, 12.72,
			13.10, 13.49, 13.89, 14.30, 14.72, 15.12, 15.51, 15.91, 16.30, 16.70, 17.11, 17.51, 17.90, 18.32, 18.72, 19.11,
			19.53, 19.92, 20.32, 20.71, 21.13, 21.52, 21.92, 22.34, 22.73, 23.13, 23.52, 23.94, 24.33, 24.75, 25.15, 25.54,
			25.96, 26.35, 26.73, 27.14, 27.56, 27.96, 28.37, 28.77, 29.16, 29.56, 29.95, 30.37, 30.77, 31.16, 31.58, 31.97,
			32.37, 32.79, 33.20, 33.60, 33.99, 34.39, 34.78, 35.18, 35.57, 35.97, 36.36, 36.78, 37.18, 37.57, 37.99, 38.38,
			38.78, 39.17, 39.59, 39.98, 40.36, 40.77, 41.17, 41.56, 41.96, 42.35, 42.77, 43.17, 43.56, 43.98, 44.37, 44.77,
			45.16, 45.58, 45.98, 46.37, 46.79, 47.18, 47.58, 47.97, 48.37, 48.79, 49.18, 49.57, 49.99, 50.39, 50.78, 51.18,
			51.59, 51.99, 52.38, 52.78, 53.20, 53.59, 53.99,
		],
	},
]


## Nuottirata: [aika, "A"/"D"/"HEI", tila 0] aikajärjestyksessä. A ja D vuorottelevat, HEI! korvaa iskun nuotin.
static func chart(song: Dictionary) -> Array:
	var beats: Array = song.beats
	var out := []
	var n := 0
	for i in beats.size():
		var t: float = beats[i]
		if t > float(song.end):
			break
		if i in song.hei:
			out.append([t, "HEI", 0])
			continue
		var every := 0
		for o in song.osat:
			if i >= int(o[0]) * 4:
				every = int(o[2])
		if every == 0 or (i % every) != 0:
			continue
		out.append([t, "A" if n % 2 == 0 else "D", 0])
		n += 1
		if i % 4 == 2 and int(i / 4.0) in song.tuplat and i + 1 < beats.size():
			out.append([(t + float(beats[i + 1])) * 0.5, "A" if n % 2 == 0 else "D", 0])
			n += 1
	return out


## Osan nimi hetkellä t (HUD).
static func osa(song: Dictionary, t: float) -> String:
	var name := ""
	for o in song.osat:
		var i := int(o[0]) * 4
		if i < song.beats.size() and t >= float(song.beats[i]):
			name = o[1]
	return name
