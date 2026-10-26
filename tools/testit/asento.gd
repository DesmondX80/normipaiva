## Hahmon asennon ja kalusteen tarkistus testikohtauksiin (CLAUDE.md "Hahmojen asennot ja kalusteet"):
## kuvat edestä, molemmista päädyistä, ylhäältä ja takaa koottuna yhdeksi kuvaksi sekä raajojen rako pintaan.
## Esimerkki: tools/testit/janttu_kuvat.gd.
##   const Asento := preload("res://tools/testit/asento.gd")
##   await Asento.views(cam, out, "uni", keskipiste, koko, etusuunta)
##   Asento.report(hahmo, self, [["upperarm_l", "lowerarm_l", "hand_l"]], ["pelvis", "spine_01", "spine_02", "spine_03"])

const Pose := preload("res://scripts/pose.gd")

const RAJA := 0.035  # luun keskilinjan pienin sallittu rako pintaan (raajan puolipaksuus hihan kanssa)


## Ottaa kuvat edestä, päädyistä, ylhäältä ja takaa ja kokoaa ne 3x2-ruudukoksi <out>/<prefix>_koottu.png
## (yksi kuva katsottavaksi). center = asetelman keskipiste, size = sen pituus metreinä, front = etusuunta
## (vaakataso, esim. Vector3(0, 0, -1) kun -Z on penkin etupuoli).
static func views(cam: Camera3D, out: String, prefix: String, center: Vector3, size: float, front: Vector3) -> void:
	front = Vector3(front.x, 0, front.z).normalized()
	var side := front.cross(Vector3.UP).normalized()
	var d := size * 1.6
	var kulmat := [
		["edesta", center + front * d + Vector3(0, size * 0.35, 0)],
		["vino", center + (front + side * 0.8).normalized() * d + Vector3(0, size * 0.5, 0)],
		["paaty_a", center + side * d + Vector3(0, size * 0.15, 0)],
		["paaty_b", center - side * d + Vector3(0, size * 0.15, 0)],
		["ylhaalta", center + Vector3(0, d * 1.2, 0) + front * 0.01],
		["takaa", center - front * d + Vector3(0, size * 0.45, 0)],
	]
	var imgs := []
	for k in kulmat:
		cam.look_at_from_position(k[1], center, Vector3.UP if k[0] != "ylhaalta" else -front)
		for i in 3:
			await cam.get_tree().process_frame
		await RenderingServer.frame_post_draw
		imgs.append(cam.get_viewport().get_texture().get_image())
	var w: int = imgs[0].get_width() / 2
	var h: int = imgs[0].get_height() / 2
	var sheet := Image.create(w * 3, h * 2, false, imgs[0].get_format())
	for i in imgs.size():
		var im: Image = imgs[i]
		im.resize(w, h, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(im, Rect2i(0, 0, w, h), Vector2i((i % 3) * w, (i / 3) * h))
	sheet.save_png(out.path_join(prefix + "_koottu.png"))
	print("kuva ", prefix, "_koottu (", ", ".join(kulmat.map(func(k): return k[0])), ")")


## Tulostaa ketjujen (esim. olkavarsi -> kyynärvarsi -> käsi) raon pintaan, jonka muodostavat surface-luiden
## verkko (esim. vartalo). Rako alle RAJA = "LÄPI"; ensimmäisen luun alkupuolta ei lasketa (nivelen juuri).
## Palauttaa läpimenojen määrän (0 = kunnossa).
## Ilman näyttöä verkkoa ei paisteta, joten aja ikkunallisena.
static func report(ch: Node3D, space: Node3D, chains: Array, surface: Array) -> int:
	var pts := Pose.limb_points(ch, space, surface)
	if pts.is_empty():
		print("RAKO: ei pintaa (headless?), ei tarkistettu")
		return 0
	var bad := 0
	for chain in chains:
		var rows := Pose.clearance(ch, space, chain, pts)
		var low := INF
		for r in rows:
			if r[0] == chain[0] and r[1] < 0.5:
				continue  # nivelen juuri (olkapää, lonkka) on luonnostaan vartalon sisällä
			low = minf(low, r[2])
			if r[2] < RAJA:
				bad += 1
				print("RAKO LÄPI %s t=%.2f rako=%.3f m" % [r[0], r[1], r[2]])
		print("RAKO %s: pienin %.3f m (%d pistettä pinnan kohdalla)" % [chain[-1], low, rows.size()])
	return bad
